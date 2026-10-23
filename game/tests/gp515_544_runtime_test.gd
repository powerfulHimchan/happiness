extends "res://tests/gp478_507_runtime_test.gd"

var mastery_id: String
var mastery_style: String
var mastery_book: AbilityDiscoveryStore
var mastery_prefix: String

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	mastery_id = args[1]
	character = args[2]
	family = mastery_id.get_slice("_", 0)
	mastery_style = mastery_id.get_slice("_", 2)
	facing = 1 if character == "roan" else -1
	mastery_prefix = "user://gp544_%s_%s" % [mastery_id, character]
	store.save_path = mastery_prefix+"_checkpoint.json"
	legacy.save_path = mastery_prefix+"_meta.jsonl"
	journal.save_path = mastery_prefix+"_story.jsonl"
	if phase not in ["resume", "next"]:
		store.clear_checkpoint()
		for suffix in ["_meta.jsonl", "_records.jsonl", "_abilities.jsonl", "_story.jsonl"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(mastery_prefix+suffix))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.story_journal_store = journal
	mastery_book = AbilityDiscoveryStore.new()
	mastery_book.save_path = mastery_prefix+"_abilities.jsonl"
	sandbox.ability_discovery_store = mastery_book
	sandbox.get_node("RecoveryOrbController").drop_chance = 0
	sandbox.get_node("LocalTestRecorder").record_path = mastery_prefix+"_records.jsonl"
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
	for actor in [player, weapons, runner, sandbox.get_node("Player/UltimateController"), sandbox.get_node("ClockTrapController"), sandbox.get_node("RouteTerrain")]:
		actor.set_process(false)
		actor.set_physics_process(false)
	for id in PrototypeWeaponRewards.FAMILY_IDS:
		weapons.combat_for(id).set_process(false)
		weapons.combat_for(id).set_physics_process(false)
	sandbox.get_node("CombatFeedbackController").configure(0,false,false)
	if phase in ["resume", "next"]:
		var saved := store.load_checkpoint()
		if not _check(not saved.is_empty(), "별도 프로세스 저장 존재"): return
		for ignored in 2:
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and player.weapon_mastery == {mastery_id:1} and _weapons_restored(saved.weapons) and player.damage_receiver.health == saved.player.health, "반복 복원·대기/체력/숙련 중복 없음"): return
		if phase == "next":
			_tap(controls.stage_route_rects[0].get_center())
			if not _check(not paused and runner.stage_number == 2 and player.weapon_mastery == {mastery_id:1}, "다음 구간 숙련 유지"): return
			controls.show_main_screen()
			if not _check(controls.begin_retry("sword",3,"standard",character,false,0,"bow") and player.weapon_mastery.is_empty() and mastery_book.snapshot().has(mastery_id), "새 도전 초기화·영구 발견 유지"): return
		elif not _effects(): return
	else:
		if not _check(controls.begin_retry(family,5,"standard",character,false,0,"bow" if family == "sword" else "sword"), "두 무기 도전 시작"): return
		var card := PrototypeAbilityCodex.profile(mastery_id)
		if not _check(not card.is_empty() and not growth._card_available(card), "선행 능력 없이 숙련 제안 금지"): return
		if not _earn_card(family+"_power"): return
		if not _selection(card): return
		if phase == "render":
			if not await _render_mastery(card): return
		else:
			if not _effects() or not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "숙련 중간 저장"): return
			if not _save_validation(): return
	paused = false
	sandbox.free()
	print("GP-515–544 runtime test: OK (%s %s %s)" % [phase,mastery_id,character])
	quit(0)

func _selection(card: Dictionary) -> bool:
	var needed := growth.next_level_experience()-growth.experience
	growth.experience += needed
	growth.total_experience += needed
	growth._offer_next_level()
	growth.offered_cards.assign([card])
	sandbox._on_growth_choices_requested(growth.offered_cards,growth.level,growth.rerolls_remaining)
	var path := mastery_book.save_path
	mastery_book.save_path = "user://gp544_missing/abilities.jsonl"
	if not _check(not growth.choose_card(0) and player.weapon_mastery.is_empty() and not growth.ranks.has(mastery_id) and growth.choosing, "발견 기록 실패 시 효과 없음·재시도 가능"): return false
	mastery_book.save_path = path
	if not _check(growth.choose_card(0) and player.weapon_mastery == {mastery_id:1} and mastery_book.snapshot().has(mastery_id) and not growth._card_available(card), "실제 선택·영구 발견·도전당1회"): return false
	if not _resolve_growth(): return false
	for other in PrototypeWeaponMastery.CARDS:
		if other.category not in weapons.equipment and not _check(not growth._card_available(other), "미휴대 계열 제외"): return false
	if mastery_style in ["focus", "resolve"]:
		if not _check(not growth._card_available(PrototypeAbilityCodex.profile(family+"_mastery_"+("resolve" if mastery_style == "focus" else "focus"))), "집중·결의 상호 배제"): return false
	return true

func _effects() -> bool:
	var selection := player.weapon_mastery.duplicate()
	var original_health := player.damage_receiver.health
	var original_relic := player.relic_state.duplicate(true)
	var maximum := player.damage_receiver.max_health
	for grounded in [false, true]:
		for health in [30,31,79,80,100]:
			for weapon in PrototypeWeaponRewards.FAMILY_IDS:
				for kind in ["basic","skill","ultimate"]:
					var expected := 1.0
					if weapon == family and kind != "ultimate":
						if mastery_style == "ground" and grounded and kind == "basic": expected = 1.20
						if mastery_style == "air" and not grounded and kind == "skill": expected = 1.25
						if mastery_style == "focus" and health >= 80 and kind == "skill": expected = 1.20
						if mastery_style == "resolve" and health <= 30: expected = 1.25
					if not _check(is_equal_approx(PrototypeWeaponMastery.damage_multiplier(selection,weapon,kind,grounded,health,100),expected), "다른 무기·기본/스킬/필살기·착지·체력 경계"): return false
	# Integrate with the full damage pipeline, including half-rounding boundaries.
	for health in [ceili(maximum*.3),ceili(maximum*.8),maximum]:
		player.damage_receiver.health = health
		for weapon in PrototypeWeaponRewards.FAMILY_IDS:
			for kind in ["basic","skill","ultimate"]:
				player.weapon_mastery.clear()
				var baseline := player.growth_damage(100,weapon,kind)
				player.weapon_mastery = selection.duplicate()
				var factor := PrototypeWeaponMastery.damage_multiplier(selection,weapon,kind,player.is_on_floor(),health,maximum)
				if not _check(player.growth_damage(100,weapon,kind) == roundi(snappedf(baseline*factor,.000000001)), "실제 성장 피해 계산"): return false
	player.damage_receiver.health = original_health
	for clock in [false,true]:
		player.relic_state = {"id":PrototypeRelic.CLOCK_ID,"used":false} if clock else {}
		for weapon in weapons.equipment:
			var controller: Node = weapons.combat_for(weapon)
			controller.set_active(false)
			var expected := (1.25 if clock else 1.0)*(1.15 if mastery_style == "rhythm" and weapon == family else 1.0)
			controller._skill_1_cooldown_s = 10
			controller._skill_2_cooldown_s = 8
			controller._physics_process(1)
			if not _check(is_equal_approx(controller._skill_1_cooldown_s,10-expected) and is_equal_approx(controller._skill_2_cooldown_s,8-expected) and is_equal_approx(controller._build_metrics().skill_1_cooldown_s,(10-expected)/expected), "주/보조 두 슬롯 재충전·시계추 곱연산·HUD"): return false
			var offers := PrototypeSkillRewards.offers(weapons.skills,0,player.skill_recharge_multiplier(),player.family_skill_recharge())
			for offer in offers:
				var rate := player.skill_recharge_multiplier(offer.weapon)
				if not _check(offer.lines[0].contains("%.1f초" % (PrototypeSkillRewards.SKILLS[offer.id].cooldown_s/rate)), "후보 교체 시간은 계열별 실제 값"): return false
		var codex := PrototypeSkillRewards.codex_cards(weapons.skills,player.skill_recharge_multiplier(),player.family_skill_recharge())
		for card in codex:
			var rate := player.skill_recharge_multiplier(card.weapon)
			if not _check(card.lines[0].contains("%.1f초" % (PrototypeSkillRewards.SKILLS[card.id].cooldown_s/rate)) and card.lines[-1].contains("시계추") == clock and card.lines[-1].contains("숙련") == (mastery_style == "rhythm" and card.weapon == family), "스킬 도감의 계열별 시간·시계추/숙련 설명"): return false
	player.relic_state = original_relic
	if not _actual_hits(): return false
	weapons._apply_active_weapon()
	return true

func _save_validation() -> bool:
	var saved := store.load_checkpoint()
	if not _check(RunCheckpointStore.valid_state(saved), "숙련 저장 검증"): return false
	for mutation in ["requires","rank","foreign","exclusive"]:
		if mutation == "exclusive" and mastery_style not in ["focus","resolve"]: continue
		var bad := saved.duplicate(true)
		match mutation:
			"requires": bad.growth.ranks.erase(family+"_power")
			"rank": bad.growth.ranks[mastery_id] = 2
			"foreign":
				var foreign := "staff" if family != "staff" else "shield"
				bad.growth.ranks.erase(mastery_id)
				bad.growth.ranks[foreign+"_mastery_"+mastery_style] = 1
			"exclusive":
				bad.growth.ranks[family+"_mastery_"+("resolve" if mastery_style == "focus" else "focus")] = 1
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "잘못된 숙련 저장 거부·정상 파일 보존: "+mutation): return false
	return true

func _render_mastery(card: Dictionary) -> bool:
	var before := store.load_checkpoint()
	var ranks := growth.ranks.duplicate()
	for dimensions in [Vector2(1280,720),Vector2(1600,720),Vector2(1280,800)]:
		root.size = Vector2i(dimensions)
		await process_frame
		controls.size = controls.get_viewport_rect().size
		controls._refresh_layout()
		growth.offered_cards.assign([card])
		sandbox._on_growth_choices_requested(growth.offered_cards,growth.level,growth.rerolls_remaining)
		await process_frame
		await RenderingServer.frame_post_draw
		if not _check(controls.layout_snapshot().safe.encloses(controls.growth_card_rects[0]), "숙련 선택 카드 안전 영역"): return false
		var output := OS.get_environment("HAPPINESS_RENDER_DIR")
		if not output.is_empty():
			if not _check(root.get_texture().get_image().save_png(output+"/"+mastery_id+"_"+character+"_"+str(int(dimensions.x))+"x"+str(int(dimensions.y))+".png") == OK, "숙련 실제 화면 렌더"): return false
	return _check(store.load_checkpoint() == before and growth.ranks == ranks, "화면 조회는 저장·성장 무변경")

func _actual_hits() -> bool:
	var was_paused := paused
	var position_before := player.global_position
	var velocity_before := player.velocity
	var health_before := player.damage_receiver.health
	paused = false
	for enemy in get_nodes_in_group("targetable"):
		enemy.visible = false
		enemy.set_process(false)
		enemy.set_physics_process(false)
	for grounded in [false,true]:
		player.global_position = Vector2(1400,780 if grounded else 500)
		player.velocity = Vector2(0,120 if grounded else 0)
		player.move_and_slide()
		if not _check(player.is_on_floor() == grounded,"실제 착지/공중 물리 상태"): return false
		player.damage_receiver.health = floori(player.damage_receiver.max_health*.3) if mastery_style == "resolve" else player.damage_receiver.max_health
		var kind := "basic" if mastery_style == "ground" else "skill"
		var attack := StringName(family+"_basic") if kind == "basic" else StringName(weapons.skills[family][0])
		var victim := _target_at("mastery_"+str(grounded),Vector2(120,0))
		var expected := player.growth_damage(100,family,kind)
		combat._action_sequence += 1
		if family == "bow":
			combat._spawn_projectile("gp544:"+str(grounded),attack,100,1,Vector2(facing,0),PackedStringArray(["bow",kind]))
			var arrow: BowProjectile = get_nodes_in_group("bow_projectile")[-1]
			arrow.set_physics_process(false)
			# In-flight damage is a launch snapshot, even after changing health.
			player.damage_receiver.health = player.damage_receiver.max_health if mastery_style == "resolve" else 1
			arrow._physics_process(.5)
			arrow.free()
		elif family == "staff":
			combat._spawn_bolt(attack,100,Vector2(facing,0),"magic",1,0)
			var bolt: StaffMagicBolt = get_nodes_in_group("staff_magic_bolt")[-1]
			bolt.set_physics_process(false)
			player.damage_receiver.health = player.damage_receiver.max_health if mastery_style == "resolve" else 1
			bolt._physics_process(.5)
			bolt.free()
		else:
			combat._damage_target(victim,attack,100,0,PackedStringArray([family,kind]),0)
		if not _check(victim.damage_receiver.health == 10000-expected,"실제 타격/투사체의 숙련 피해·생성 후 조건 변경"): return false
		victim.free()
	player.global_position = position_before
	player.velocity = velocity_before
	player.damage_receiver.health = health_before
	paused = was_paused
	return true
