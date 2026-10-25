extends "res://tests/gp515_544_runtime_test.gd"

var tactic_id := ""
var tactic_card: Dictionary
var assertions := 0

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if args.size() > 0 else "catalog"
	tactic_id = args[1] if args.size() > 1 else "sword_tactic_barrier_skill"
	character = args[2] if args.size() > 2 else "roan"
	tactic_card = PrototypeAbilityCodex.profile(tactic_id)
	family = String(tactic_card.category) if tactic_card.category != "common" else "sword"
	mastery_style = "ground" if tactic_id.ends_with("basic") else "air"
	facing = 1 if character == "roan" else -1
	var prefix := "user://gp717_%s_%s" % [tactic_id,character]
	store.save_path = prefix+"_checkpoint.json"
	legacy.save_path = prefix+"_meta.jsonl"
	journal.save_path = prefix+"_story.jsonl"
	if phase not in ["resume","next"]:
		store.clear_checkpoint()
		for suffix in ["_meta.jsonl","_records.jsonl","_abilities.jsonl","_story.jsonl"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix+suffix))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.story_journal_store = journal
	mastery_book = AbilityDiscoveryStore.new()
	mastery_book.save_path = prefix+"_abilities.jsonl"
	sandbox.ability_discovery_store = mastery_book
	sandbox.get_node("RecoveryOrbController").drop_chance = 0
	sandbox.get_node("LocalTestRecorder").record_path = prefix+"_records.jsonl"
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	combat = weapons.combat_for(family)
	automatic_growth_card_id = family+"_power"
	growth.jobs_enabled = false
	for actor in [player,weapons,runner,sandbox.get_node("Player/UltimateController"),sandbox.get_node("ClockTrapController"),sandbox.get_node("RouteTerrain")]:
		actor.set_process(false)
		actor.set_physics_process(false)
	for id in PrototypeWeaponRewards.FAMILY_IDS:
		weapons.combat_for(id).set_process(false)
		weapons.combat_for(id).set_physics_process(false)
	sandbox.get_node("CombatFeedbackController").configure(0,false,false)
	if phase in ["resume","next"]:
		var saved := store.load_checkpoint()
		if not _check(not saved.is_empty(),"별도 프로세스 저장 존재"): return
		for ignored in 2:
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and player.combat_tactics == {tactic_id:1} and player.damage_receiver.health == saved.player.health and _weapons_restored(saved.weapons),"반복 복원·체력/두 무기/전술 중복 없음"): return
		if phase == "next":
			_tap(controls.stage_route_rects[0].get_center())
			if not _check(runner.stage_number == 2 and player.combat_tactics == {tactic_id:1},"다음 구간 유지"): return
			controls.show_main_screen()
			if not _check(controls.begin_retry(family,3,"standard",character,false,0,"bow" if family == "sword" else "sword") and player.combat_tactics.is_empty() and mastery_book.snapshot().has(tactic_id),"새 도전 임시 효과 초기화·영구 발견 유지"): return
		elif not _effects(): return
	else:
		if not _check(controls.begin_retry(family,5,"standard",character,false,0,"bow" if family == "sword" else "sword"),"새 도전 시작"): return
		if phase in ["catalog","render"]:
			if not _catalog_tactics() or not _unlock(tactic_id): return
			if not await _browse_ui(phase == "render"): return
		else:
			if not _selection(tactic_card) or not _effects(): return
			if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK,"실제 전술 체크포인트"): return
			if not _save_validation(): return
	paused = false
	sandbox.free()
	print("GP-668–717 runtime test: OK (%s %s %s; %d assertions)" % [phase,tactic_id,character,assertions])
	quit(0)

func _check(condition: bool,label: String) -> bool:
	assertions += 1
	return super._check(condition,label)

func _unlock(id: String) -> bool:
	if growth.ranks.has(id): return true
	var card := PrototypeAbilityCodex.profile(id)
	for required in card.get("requires",[]):
		if not _unlock(required): return false
	return _earn_card(id)

func _selection(card: Dictionary) -> bool:
	if not _check(not growth._card_available(card),"선행 없이 후보 제안 거부"): return false
	for required in card.requires:
		if not _unlock(required): return false
	var needed := growth.next_level_experience()-growth.experience
	growth.experience += needed
	growth.total_experience += needed
	growth._offer_next_level()
	growth.offered_cards.assign([card])
	sandbox._on_growth_choices_requested(growth.offered_cards,growth.level,growth.rerolls_remaining)
	var path := mastery_book.save_path
	mastery_book.save_path = "user://gp717_missing/abilities.jsonl"
	if not _check(not growth.choose_card(0) and player.combat_tactics.is_empty() and not growth.ranks.has(tactic_id) and growth.choosing,"영구 기록 실패시 효과/등급 보류"): return false
	mastery_book.save_path = path
	if not _check(growth.choose_card(0) and player.combat_tactics == {tactic_id:1} and mastery_book.snapshot().has(tactic_id) and not growth._card_available(card),"실제 카드 선택·1회 제한·영구 발견"): return false
	if not _resolve_growth(): return false
	for other in PrototypeCombatTactics.CARDS:
		if other.category in PrototypeWeaponRewards.FAMILY_IDS and other.category not in weapons.equipment:
			if not _check(not growth._card_available(other),"미휴대 계열 제외"): return false
	for excluded in card.get("excludes",[]):
		if not _check(not growth._card_available(PrototypeAbilityCodex.profile(excluded)),"같은 계열 상호 배제"): return false
	return true

func _effects() -> bool:
	var selection := player.combat_tactics.duplicate()
	var original_health := player.damage_receiver.health
	var original_barrier := player.damage_receiver.barrier_health
	var original_relic := player.relic_state.duplicate(true)
	var maximum := player.damage_receiver.max_health
	var style := String(tactic_card.get("tactic_style",""))
	for grounded in [false,true]:
		for health in [0,30,31,79,80,100]:
			for barrier in [0,1]:
				for weapon in PrototypeWeaponRewards.FAMILY_IDS:
					for kind in ["basic","skill","ultimate"]:
						var expected := 1.0
						if health > 0 and weapon == family:
							if style == "ground_skill" and grounded and kind == "skill": expected = 1.15
							if style == "air_basic" and not grounded and kind == "basic": expected = 1.20
							if style == "barrier_basic" and barrier > 0 and kind == "basic": expected = 1.20
							if style == "barrier_skill" and barrier > 0 and kind == "skill": expected = 1.20
						if not _check(is_equal_approx(PrototypeCombatTactics.damage_multiplier(selection,weapon,kind,grounded,health,100,barrier),expected),"계열·피해 종류·지상/공중·방벽/체력 경계"): return false
	for health in [30,31,79,80,100]:
		player.damage_receiver.health = health
		for barrier in [0,1]:
			player.damage_receiver.barrier_health = barrier
			for grounded in [true,false]:
				for kind in ["basic","skill","ultimate"]:
					player.combat_tactics.clear()
					var baseline := player.growth_damage_preview(1000,family,kind,grounded)
					player.combat_tactics = selection.duplicate()
					var factor := PrototypeCombatTactics.damage_multiplier(selection,family,kind,grounded,health,maximum,barrier)
					if not _check(player.growth_damage_preview(1000,family,kind,grounded) == roundi(snappedf(baseline*factor,.000000001)),"실제 피해 파이프라인·최종 반올림"): return false
		for clock in [false,true]:
			player.relic_state = {"id":PrototypeRelic.CLOCK_ID,"used":false} if clock else {}
			for weapon in weapons.equipment:
				var controller: Node = weapons.combat_for(weapon)
				controller.set_active(false)
				var rate := (1.25 if clock else 1.0)*PrototypeWeaponMastery.recharge_multiplier(player.weapon_mastery,weapon)
				if weapon == family:
					if style == "calm_rhythm" and health >= 80: rate *= 1.10
					if style == "crisis_rhythm" and health <= 30: rate *= 1.20
				controller._skill_1_cooldown_s = 10
				controller._skill_2_cooldown_s = 8
				controller._physics_process(1)
				if not _check(is_equal_approx(controller._skill_1_cooldown_s,10-rate) and is_equal_approx(controller._skill_2_cooldown_s,8-rate) and is_equal_approx(player.skill_recharge_multiplier(weapon),rate),"두 슬롯·비활성 무기 조건부 재충전·유물 중첩"): return false
	player.relic_state = original_relic
	player.damage_receiver.health = original_health
	player.damage_receiver.barrier_health = original_barrier
	if tactic_card.category != "common":
		if not _actual_hits(): return false
	else:
		var ultimate := sandbox.get_node("Player/UltimateController") as UltimateController
		match tactic_id:
			"evasive_barrier_master":
				if not _check(growth.evasive_barrier_amount() == 11,"정확 회피 방벽11"): return false
				player.damage_receiver.barrier_health = 0
				player.recover_barrier(growth.evasive_barrier_amount())
				if not _check(player.damage_receiver.barrier_health == 11,"실제 방벽 회복"): return false
			"restorative_barrier_master":
				player.damage_receiver.barrier_health = 0
				player.damage_receiver.health = 50
				var potions := player.potions_remaining
				if not _check(player.potion_barrier_recovery() == 20 and player.use_recovery_potion() and player.damage_receiver.barrier_health == 20 and player.potions_remaining == potions-1,"실제 회복약 소비·방벽20"): return false
			"victory_resilience_master":
				if not _check(growth.victory_recovery_amount() == ceili(maximum*.05),"처치 회복5%"): return false
				player.expedition = 2
				if not _check(player.scaled_health_recovery(growth.victory_recovery_amount()) == ceili(ceili(maximum*.05)*.75),"원정 회복75%·정수 올림"): return false
				player.expedition = 0
			"orb_bloom_master":
				if not _check(player.recovery_orb_heal_percent() == 30 and player.recovery_orb_heal_amount() == ceili(maximum*.30),"구슬 회복30%"): return false
			"time_attunement_master":
				ultimate.gauge = 0
				ultimate._on_weapon_hit(false,null,1)
				ultimate._on_weapon_hit(true,null,1)
				if not _check(ultimate.gauge == 18 and ultimate.weapon_hit_gauge_amount(false) == 6 and ultimate.weapon_hit_gauge_amount(true) == 12,"실제 적중 게이지6/12"): return false
			"nimble_master":
				if not _check(is_equal_approx(player.ground_evade_cooldown_s(),.45*.8*.9*.9),"회피 대기 곱연산·무적 시간 유지"): return false
	player.damage_receiver.health = original_health
	player.damage_receiver.barrier_health = original_barrier
	weapons._apply_active_weapon()
	return true

func _rebalance_ranks(saved: Dictionary) -> void:
	var total := 0
	for rank in saved.growth.ranks.values(): total += int(rank)
	saved.growth.level = total+1
	saved.growth.total_xp = int(saved.growth.xp)
	for i in range(1,total+1): saved.growth.total_xp += 20+(i-1)*5

func _save_validation() -> bool:
	var saved := store.load_checkpoint()
	if not _check(RunCheckpointStore.valid_state(saved),"전술 포함 정상 저장"): return false
	for required in tactic_card.requires:
		var bad := saved.duplicate(true)
		bad.growth.ranks.erase(required)
		_rebalance_ranks(bad)
		if not _check(not RunCheckpointStore.valid_state(bad),"모든 선행 조건 검증: "+required): return false
	for excluded in tactic_card.get("excludes",[]):
		var bad := saved.duplicate(true)
		bad.growth.ranks[excluded] = 1
		_rebalance_ranks(bad)
		if not _check(not RunCheckpointStore.valid_state(bad),"동시 보유 저장 거부"): return false
	var bad := saved.duplicate(true)
	bad.growth.ranks[tactic_id] = 2
	_rebalance_ranks(bad)
	if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved,"중복 등급 거부·정상 파일 보존"): return false
	return true

func _catalog_tactics() -> bool:
	if not _check(PrototypeCombatTactics.CARDS.size() == 42,"신규 성장42종"): return false
	var ids := {}
	for card in PrototypeCombatTactics.CARDS:
		if not _check(not ids.has(card.id) and not PrototypeAbilityCodex.profile(card.id).is_empty(),"고유 ID·성장/도감 연결"): return false
		ids[card.id] = true
		var display: Dictionary = PrototypeAbilityCodex.cards({},{}).filter(func(item: Dictionary) -> bool: return item.id == card.id)[0]
		for required in card.requires:
			if not _check(display.lines.any(func(line: String) -> bool: return line.contains(PrototypeAbilityCodex.profile(required).title)),"도감의 모든 선행 표시"): return false
		for excluded in card.get("excludes",[]):
			if not _check(display.lines.any(func(line: String) -> bool: return line.contains(PrototypeAbilityCodex.profile(excluded).title)),"도감의 상호 배제 표시"): return false
	return true

func _browse_ui(render: bool) -> bool:
	var output := OS.get_environment("TACTICS_RENDER_DIR")
	if not _unlock("sword_power") or not _unlock("magic_barrier") or not _earn_card("power") or not _earn_card("power"): return false
	var saved_files := _file_bytes()
	for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,800),Vector2i(2400,1080)]:
		root.size = dimensions
		await process_frame
		controls.size = controls.get_viewport_rect().size if render else Vector2(dimensions)
		controls._refresh_layout()
		var before: Dictionary = sandbox._capture_run_build()
		if not _check(controls.open_run_build() and paused,"조회 전투 정지"): return false
		for tab in 3:
			_tap(controls.run_build_snapshot().layout.tabs[tab].get_center())
			var filter_count := maxi(1,PrototypeRunBuildView.filter_labels(tab).size())
			var order_count := maxi(1,PrototypeRunBuildView.order_labels(tab).size())
			for filter_index in filter_count:
				for order_index in order_count:
					var snapshot: Dictionary = controls.run_build_snapshot()
					if not _check(snapshot.filter == filter_index and snapshot.order == order_index and snapshot.page == 0,"실제 분류/정렬 터치와 페이지 초기화"): return false
					var all := PrototypeRunBuildView.browse(tab,before,filter_index,order_index)
					if not _check(snapshot.count == all.size(),"필터 결과/페이지 일치"): return false
					var rectangles: Array = snapshot.layout.cards+snapshot.layout.tabs+[snapshot.layout.previous,snapshot.layout.next,snapshot.layout.back]
					if tab != 2: rectangles.append_array([snapshot.layout.filter,snapshot.layout.order])
					var safe := controls.layout_snapshot().safe as Rect2
					for i in rectangles.size():
						if not _check(safe.encloses(rectangles[i]),"모든 터치 안전 영역"): return false
						for j in range(i+1,rectangles.size()):
							if not _check(not rectangles[i].intersects(rectangles[j]),"필터·탭·카드·버튼 비중첩"): return false
					if tab == 0 and filter_index == 0 and order_index == 2:
						if not _check(all[0].id == "power","능력 등급 내림차순"): return false
					if tab == 1:
						if order_index == 1:
							for i in range(1,all.size()):
								if not _check(all[i-1].remaining <= all[i].remaining,"스킬 실제 대기순"): return false
						if filter_index > 0:
							for card in all:
								if not _check((card.weapon == before.active) == (filter_index == 1),"주/보조 계열 필터"): return false
						if order_index == 2:
							for card in all:
								if not _check(card.lines[1].contains(str(before.damage_stances[card.weapon].ground_basic)),"실제 자세별 피해 스냅샷"): return false
					if render and filter_index == 0:
						controls.queue_redraw()
						await process_frame
						await RenderingServer.frame_post_draw
						if not output.is_empty():
							DirAccess.make_dir_recursive_absolute(output)
							if not _check(root.get_texture().get_image().save_png(output+"/build_%d_%d_%dx%d.png" % [tab,order_index,dimensions.x,dimensions.y]) == OK,"실제 정보 화면 렌더"): return false
					if tab != 2: _tap(snapshot.layout.order.get_center())
				if tab != 2: _tap(controls.run_build_snapshot().layout.filter.get_center())
		if not _check(sandbox._capture_run_build() == before and _file_bytes() == saved_files,"열람·분류·정렬로 전투/모든 파일 무변경"): return false
		controls.close_run_build()
		controls._process(3.1)
		if not _check(not paused,"기존 카운트다운 복귀"): return false
	return true

func _file_bytes() -> Array:
	var values := []
	for file in [store.save_path,legacy.save_path,journal.save_path,mastery_book.save_path]:
		values.append(FileAccess.get_file_as_bytes(file) if FileAccess.file_exists(file) else PackedByteArray())
	return values
