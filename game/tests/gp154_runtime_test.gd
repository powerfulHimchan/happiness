extends "res://tests/gp153_runtime_test.gd"

const GP154_SAVE := "user://gp154_checkpoint.json"
const GP154_META := "user://gp154_meta.jsonl"
const GP154_RECORD := "user://gp154_records.jsonl"
const GP154_BOOK := "user://gp154_abilities.jsonl"
const VITALITY_ID := "orb_vitality"

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	store.save_path = GP154_SAVE
	legacy.save_path = GP154_META
	book.save_path = GP154_BOOK
	if phase in ["seed", "legacy-seed", "combat"]:
		store.clear_checkpoint()
		for path in [GP154_META, GP154_RECORD, GP154_BOOK]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.ability_discovery_store = book
	sandbox.get_node("LocalTestRecorder").record_path = GP154_RECORD
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	recorder = sandbox.get_node("LocalTestRecorder")
	ultimate = sandbox.get_node("Player/UltimateController")
	orbs = sandbox.get_node("RecoveryOrbController")
	orbs.set_physics_process(false)
	growth.jobs_enabled = false
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	_disable_live()
	match phase:
		"seed":
			controls.begin_retry("sword", 5)
			if not _test_vitality_gates(false): return
			if not await _choose_earned(MAGNET_ID): return
			if not _check(player.recovery_orb_heal_percent() == 10 and growth._card_available(PrototypeAbilityCodex.profile(VITALITY_ID)), "자석만으로는10%·선행 획득 후 강화 후보"): return
			# 선택 직전에 이미 떨어진 구슬도 다음 획득부터 현재 능력을 적용한다.
			orbs.orbs = [player.global_position]
			if not await _choose_earned(VITALITY_ID, true): return
			if not _check(player.orb_vitality_unlocked and player.recovery_orb_heal_percent() == 20 and player.recovery_orb_pickup_radius() == 152 and controls.movement_metrics.recovery_orb_heal_percent == 20, "실제 선택·회복20%·원래 자석 거리·현재 지표"): return
			if not _test_vitality_gates(true) or not await _test_vitality_view(): return
			player.damage_receiver.health = 1
			orbs.orbs[0] = player.global_position
			orbs._physics_process(0.02)
			if not _check(orbs.orbs.is_empty() and player.damage_receiver.health == 21 and orbs._popup_amount == 20, "선택 전에 떨어진 구슬 실제20회복·팝업"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "첫 정예 실제 보상"): return
			player.damage_receiver.health = 17
			player.potions_remaining = 1
			ultimate.gauge = 31
			weapons.sword_combat._skill_1_cooldown_s = 3.25
			weapons.bow_combat._skill_2_cooldown_s = 5.5
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "강화·자석·체력·약·게이지·양 대기 저장"): return
			if not _test_vitality_save(): return
			controls.show_main_screen()
			controls.show_village()
			if not await _test_book_layout(): return
			var card: Dictionary = PrototypeAbilityCodex.cards(book.snapshot(), growth.ranks).filter(func(item: Dictionary) -> bool: return item.id == VITALITY_ID)[0]
			if not _check(card.open and card.status == "이번 도전 1등급" and card.lines[0] == "회복 구슬: 최대 체력 20% 회복" and card.lines[2] == "조건: 구슬 자석 획득 후", "전체 도감·원본 효과/선행/실제 발견/현재 등급"): return
		"resume":
			if not _check(not player.orb_vitality_unlocked and player.recovery_orb_heal_percent() == 10 and book.snapshot().has(VITALITY_ID), "영구 발견만으로 새 능력 지급 없음"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and player.orb_vitality_unlocked and player.recovery_orb_heal_percent() == 20 and player.recovery_orb_pickup_radius() == 152 and player.damage_receiver.health == 17 and player.potions_remaining == 1 and ultimate.gauge == 31 and weapons.sword_combat._skill_1_cooldown_s == 3.25 and weapons.bow_combat._skill_2_cooldown_s == 5.5 and orbs.orbs.is_empty(), "별도 프로세스 반복 복원·회복 배율 중복/무료 회복/구슬 재생성 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _pickup_at(Vector2(100, 0), true) or not await _test_vitality_view(): return
			while not runner.awaiting_boss_choice():
				if not _finish_stage(): return
				if runner.awaiting_boss_choice(): break
				if not _check(sandbox._claim_weapon_reward(""), "정예 보상에서 강화 유지"): return
				_tap(controls.stage_route_rects[0].get_center())
			if not _check(runner.stage_number == 5 and store.load_checkpoint().growth.ranks[VITALITY_ID] == 1 and player.recovery_orb_heal_percent() == 20, "5단계 최종 저장·강화 유지"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and player.recovery_orb_heal_percent() == 20 and sandbox._resolve_boss_choice("rescue"), "최종 보스 선택 복원·완주"): return
			controls.begin_retry("bow", 3)
			if not _check(not player.orb_vitality_unlocked and player.recovery_orb_heal_percent() == 10 and player.recovery_orb_pickup_radius() == 76 and growth.ranks.is_empty() and book.snapshot().has(VITALITY_ID), "새 도전 기본 회복/거리·영구 발견 보존"): return
			if not _pickup_at(Vector2(76, 0), true): return
		"legacy-seed":
			controls.begin_retry("bow", 3)
			if not await _choose_earned(MAGNET_ID): return
			if not _pickup_at(Vector2(100, 0), true): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "기존 자석 저장 준비"): return
			if not _check(not store.load_checkpoint().growth.ranks.has(VITALITY_ID), "이전 자석 저장에 새 강화 없음"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and player.orb_magnet_unlocked and not player.orb_vitality_unlocked and player.recovery_orb_heal_percent() == 10 and player.recovery_orb_pickup_radius() == 152, "기존 자석 저장은10%·새 강화 소급 지급 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _pickup_at(Vector2(100, 0), true): return
		"combat":
			controls.begin_retry("sword", 3)
			if not await _choose_earned(MAGNET_ID) or not await _choose_earned(VITALITY_ID): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "새 전투 단계 준비"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _test_vitality_healing() or not await _test_magnet_combat(): return
		_:
			_check(false, "알 수 없는 단계")
			return
	paused = false
	sandbox.free()
	print("GP-154 runtime test: OK · " + phase)
	quit(0)

func _test_vitality_gates(owned: bool) -> bool:
	for ignored in 100:
		if not _check(not growth._draw_cards().any(func(card: Dictionary) -> bool: return card.id == VITALITY_ID), "선행 전/최대1등급 강화 후보 제외"): return false
	var before := growth.checkpoint_snapshot()
	var files := _files()
	var heal := player.recovery_orb_heal_percent()
	if not _reject_card(VITALITY_ID): return false
	return _check(growth.checkpoint_snapshot() == before and _files() == files and player.recovery_orb_heal_percent() == heal and player.orb_vitality_unlocked == owned, "위조/중복 선택 거부·회복/성향/저장 불변")

func _test_vitality_save() -> bool:
	var saved := store.load_checkpoint()
	for invalid in [null, true, "1", 0, 2, 0.5]:
		var bad := saved.duplicate(true)
		bad.growth.ranks[VITALITY_ID] = invalid
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "등급 변조 거부·정상 저장 보호"): return false
	var bad := saved.duplicate(true)
	bad.growth.ranks.erase(MAGNET_ID)
	bad.growth.ranks.vitality = int(bad.growth.ranks.get("vitality", 0)) + 1
	bad.player.max_health += 20
	if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "등급/최대 체력을 맞춰도 선행 없는 강화 저장 거부"): return false
	return _check(not saved.player.has("orb_vitality_unlocked") and not saved.player.has("recovery_orb_heal_percent"), "기존 등급만 저장·효과 중복 필드 없음")

func _pickup_at(offset: Vector2, collect: bool) -> bool:
	orbs.orbs = [player.global_position + offset]
	player._input_lock_remaining_s = 0.0
	player.damage_receiver.health = 1
	var percent := 20 if growth.ranks.has(VITALITY_ID) else 10
	var expected := ceili(float(player.damage_receiver.max_health * percent) / 100.0)
	var potions := player.potions_remaining
	var barrier := player.damage_receiver.barrier_health
	var collected := orbs.collected
	var healed := orbs.healed
	orbs._physics_process(0.02)
	if not _check(orbs.collected == collected + (1 if collect else 0) and orbs.orbs.size() == (0 if collect else 1) and player.damage_receiver.health == 1 + (expected if collect else 0) and orbs.healed == healed + (expected if collect else 0) and player.potions_remaining == potions and player.damage_receiver.barrier_health == barrier, "구슬 실제 회복·최대 체력 올림·집계·약/방벽 보존"): return false
	if collect and not _check(orbs._popup_amount == expected, "실제 회복량 팝업"): return false
	orbs._physics_process(0.02)
	return _check(player.damage_receiver.health == 1 + (expected if collect else 0) and orbs.healed == healed + (expected if collect else 0), "획득한 구슬 재회복/집계 중복 없음")

func _test_vitality_healing() -> bool:
	var maximum := player.damage_receiver.max_health
	for pair in [[100, 20], [101, 21], [105, 21], [110, 22], [120, 24], [300, 60]]:
		player.damage_receiver.max_health = pair[0]
		if not _pickup_at(Vector2(100, 0), true): return false
		if not _check(player.damage_receiver.health == 1 + pair[1] and player.recovery_orb_heal_amount() == pair[1], "현재 최대 체력 기반20%·정수 올림"): return false
	player.damage_receiver.max_health = maximum
	orbs.orbs = [player.global_position]
	player.damage_receiver.health = maximum - 1
	var healed := orbs.healed
	orbs._physics_process(0.02)
	if not _check(player.damage_receiver.health == maximum and orbs.healed == healed + 1 and orbs._popup_amount == 1, "체력 상한·실제1회복만 집계/팝업"): return false
	# 구슬 강화는 회복약과 이슬 유물의 조제 비율을 변경하지 않는다.
	for recipe in [PrototypePotionRecipes.BASIC, PrototypePotionRecipes.CONCENTRATED, PrototypePotionRecipes.PORTIONED]:
		for dew in [false, true]:
			player.relic_state = {"id": PrototypeRelic.DEW_ID, "used": false} if dew else {}
			player.prepare_potions(recipe)
			var count := player.potions_remaining
			var percent := roundi(float(PrototypePotionRecipes.profile(recipe).ratio) * 100) + (10 if dew else 0)
			player.damage_receiver.health = 1
			if not _check(player.use_recovery_potion() and player.damage_receiver.health == 1 + ceili(float(maximum * percent) / 100.0) and player.potions_remaining == count - 1 and player.recovery_orb_heal_percent() == 20, "세 조제/이슬의 회복약 비율·실제 소비 독립"): return false
			if not _pickup_at(Vector2(100, 0), true): return false
	player.relic_state = {}
	player.prepare_potions(PrototypePotionRecipes.BASIC)
	return true

func _test_vitality_view() -> bool:
	var files := _files()
	var before: Dictionary = sandbox._capture_run_build()
	if not _check(controls.open_run_build() and paused, "현재 도전 실제 조회"): return false
	var abilities := PrototypeRunBuildView.cards(0, controls.run_build_state)
	if not _check(abilities.any(func(card: Dictionary) -> bool: return card.id == VITALITY_ID), "보유 능력에 구슬 강화 표시"): return false
	var card: Dictionary = PrototypeRunBuildView.cards(2, controls.run_build_state).filter(func(item: Dictionary) -> bool: return item.id == "health")[0]
	if not _check(card.lines.has("회복 구슬 · 체력 20%% (+%d)" % player.recovery_orb_heal_amount()) and card.lines.has("회복 구슬 획득 거리 1.52m") and orbs.pickup_hint() == "회복 +20% · 자석 1.52m", "현재 도전·구슬 표기는 실제 회복량과 거리"): return false
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls.run_build_tab = 2
		controls.run_build_page = 0
		var view: Dictionary = controls.run_build_snapshot()
		for rect in view.layout.cards:
			if not _check(controls.layout_snapshot().safe.encloses(rect), "두 화면비 생존 카드 안전 영역"): return false
		var rect: Rect2 = view.layout.cards[1]
		for line in card.lines:
			if not _check(ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= rect.size.x - 24, "생존 상태 여덟 줄 설명 너비"): return false
		controls.queue_redraw()
		await process_frame
	if not _check(sandbox._capture_run_build() == before and _files() == files, "조회는 체력·효과·대기·저장 불변"): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(3.1)
	_disable_live()
	return _check(not paused and _files() == files, "3초 복귀·저장 보존")
