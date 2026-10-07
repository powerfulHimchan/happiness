extends "res://tests/gp130_runtime_test.gd"

const GP135_SAVE := "user://gp135_checkpoint.json"
const GP135_META := "user://gp135_meta.jsonl"
const GP135_RECORD := "user://gp135_records.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP135_SAVE
	legacy.save_path = GP135_META
	if phase in ["seed", "combat"]:
		store.clear_checkpoint()
		for path in [GP135_META, GP135_RECORD]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	var discoveries := AbilityDiscoveryStore.new()
	discoveries.save_path = "user://gp135_abilities.jsonl"
	if phase in ["seed", "combat"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(discoveries.save_path))
	sandbox.ability_discovery_store = discoveries
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP135_RECORD
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
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	weapons.sword_combat.set_physics_process(false)
	weapons.bow_combat.set_physics_process(false)
	weapons.sword_combat.set_process(false)
	weapons.bow_combat.set_process(false)
	player.set_physics_process(false)
	runner.set_process(false)
	match phase:
		"seed":
			if not await _test_village_codex("", false): return
			controls.begin_retry()
			if not _reach_relic_reward(): return
			var saved := store.load_checkpoint()
			if not await _test_relic_layout(): return
			if not _check(store.load_checkpoint() == saved and player.relic_state.is_empty() and is_equal_approx(player.potion_heal_ratio(), 0.25), "세 후보 비교·취소는 유물/회복률/저장 변경 없음"): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[2].get_center())
			_set_timers()
			var before := weapons.checkpoint_snapshot()
			var health := player.damage_receiver.health
			var potions := player.potions_remaining
			var gauge := ultimate.gauge
			store.save_path = "user://gp135_missing/checkpoint.json"
			_tap(controls.relic_reward_confirm_rect.get_center())
			store.save_path = GP135_SAVE
			if not _check(controls.current_screen_mode() == 15 and controls.selected_relic_offer == 2 and player.relic_state.is_empty() and is_equal_approx(player.potion_heal_ratio(), 0.25) and weapons.checkpoint_snapshot() == before and store.load_checkpoint() == saved, "샘의 이슬 저장 실패·기본 회복율/유물/대기시간/정상 파일 보존"): return
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(controls.current_screen_mode() == 9 and player.relic_state == {"id": PrototypeRelic.DEW_ID, "used": false} and is_equal_approx(player.potion_heal_ratio(), 0.35) and not controls.relic_offer_available and controls.movement_metrics.potion_heal_percent == 35 and String(controls.movement_metrics.relic_hud).contains("샘의 이슬"), "실제 셋째 유물 선택·35%·보유 HUD·보상 소비"): return
			if not _check(player.damage_receiver.health == health and player.potions_remaining == potions and ultimate.gauge == gauge and weapons.checkpoint_snapshot() == before and not sandbox._claim_relic_reward(PrototypeRelic.CLOCK_ID), "획득 즉시 치료/회복약 보충/대기시간 변경 없음·두 번째 유물 차단"): return
			var valid := store.load_checkpoint()
			for relic in [{"id": PrototypeRelic.DEW_ID, "used": true}, {"id": PrototypeRelic.DEW_ID, "used": 0}, {"id": PrototypeRelic.DEW_ID, "used": false, "extra": 1}]:
				var bad := valid.duplicate(true)
				bad.relic = relic
				if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == valid, "이슬 소비/타입/추가 필드 변조 거부·정상 저장 보호"): return
			if not await _test_dew_text(): return
			if not await _test_village_codex(PrototypeRelic.DEW_ID, false): return
		"resume":
			if not _check(player.relic_state.is_empty() and is_equal_approx(player.potion_heal_ratio(), 0.25), "재시작 전 이슬 자동 지급 없음"): return
			var saved := store.load_checkpoint()
			if not _check(legacy.spend_phoenix(String(saved.recorder.id)) == OK, "같은 도전 깃털 소비 저널 준비"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and player.relic_state == {"id": PrototypeRelic.DEW_ID, "used": false} and is_equal_approx(player.potion_heal_ratio(), 0.35) and player.potions_remaining == int(saved.player.potions_remaining) and controls.movement_metrics.potion_heal_percent == 35, "별도 프로세스 반복 이어하기·35%/개수 유지·깃털 저널 독립"): return
			if not await _test_village_codex(PrototypeRelic.DEW_ID, false): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			_tap(controls.stage_route_rects[0].get_center())
			var maximum := player.damage_receiver.max_health
			for remaining in [1, 0]:
				player.damage_receiver.health = 1
				_press_dew_potion()
				if not _check(player.potions_remaining == remaining and player.damage_receiver.health == 1 + ceili(maximum * 0.35) and not player.relic_state.used, "이슬 기본약 실제 모바일35%·한 개 소비·이슬 반복 지속"): return
			var health := player.damage_receiver.health
			_press_dew_potion()
			if not _check(player.damage_receiver.health == health and player.potions_remaining == 0, "소진 후 무료 회복 없음"): return
			if not _finish_stage() or not _check(store.load_checkpoint().player.potions_remaining == 0 and store.load_checkpoint().relic.id == PrototypeRelic.DEW_ID, "보스 완료 지점 이슬/소진 저장"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and player.potions_remaining == 0 and is_equal_approx(player.potion_heal_ratio(), 0.35), "보스 선택 재시작·소진 복원·보충 없음"): return
			if not _check(sandbox._resolve_boss_choice("rescue") and store.load_checkpoint().is_empty(), "실제 이슬 도전 보스 완주·저장 정리"): return
			controls.begin_retry()
			if not _check(player.relic_state.is_empty() and is_equal_approx(player.potion_heal_ratio(), 0.25) and player.potions_remaining == 2, "새 도전 이슬 제거·기본25%/2개"): return
			if not _reach_relic_reward(): return
			var old := store.load_checkpoint()
			old.erase("relic")
			if not _check(store.save_checkpoint(old) == OK, "유물 필드 없는 이전 저장 준비"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and player.relic_state.is_empty() and is_equal_approx(player.potion_heal_ratio(), 0.25), "이전 저장 유물 없음·25% 호환"): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[1].get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(player.relic_state.id == PrototypeRelic.CLOCK_ID and player.skill_recharge_multiplier() == 1.25 and is_equal_approx(player.potion_heal_ratio(), 0.25), "기존 시계추 실제 선택·25%·별도 효과"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("destroy"), "기존 저장 실제 보스 완주"): return
		"combat":
			if not _check(legacy.grant("gp135-apothecary", "rescue") == OK and legacy.select_potion_recipe(PrototypePotionRecipes.CONCENTRATED) == OK, "실제 구출 해금·농축 조제 준비"): return
			sandbox._update_boss_legacy_status()
			controls.begin_retry()
			if not _reach_relic_reward(): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[2].get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(player.potion_recipe == PrototypePotionRecipes.CONCENTRATED and player.potions_remaining == 1 and controls.movement_metrics.potion_heal_percent == 50, "실제 농축 조제·이슬50%·1개 유지"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _test_dew_combat(): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-135 runtime test: OK (" + phase + ")")
	quit(0)

func _resolve_growth() -> bool:
	for ignored in 12:
		if growth.awaiting_job_confirmation:
			_tap(controls.job_ultimate_rects[0].get_center())
			_tap(controls.job_confirm_rect.get_center())
		elif growth.choosing:
			var index := -1
			for i in growth.offered_cards.size():
				if growth.offered_cards[i].id not in ["potion_pouch", "nimble_evade"]: index = i
			if not _check(index >= 0, "유물 단독 검사에서 주머니/회피 제외 카드 선택"): return false
			_tap(controls.growth_card_rects[index].get_center())
		else:
			return true
	return _check(false, "성장 선택 대기 해소")

func _press_dew_potion() -> void:
	controls._handle_touch_released(7)
	var event := InputEventScreenTouch.new()
	event.index = 7
	event.position = controls.action_rects[&"recovery_potion"].get_center()
	event.pressed = true
	controls._input(event)
	controls._physics_process(0.01)
	controls._handle_touch_released(7)

func _test_dew_combat() -> bool:
	player.damage_receiver.max_health = 101
	player.damage_receiver.health = 101
	player.boss_legacy = {}
	player.memory_id = ""
	var gauge := ultimate.gauge
	_set_timers()
	var timers := weapons.checkpoint_snapshot()
	_press_dew_potion()
	if not _check(player.potions_remaining == 1, "만피에는 강화 농축 소비 없음"): return false
	player.damage_receiver.health = 1
	player._input_lock_remaining_s = 0.2
	_press_dew_potion()
	if not _check(player.damage_receiver.health == 1 and player.potions_remaining == 1, "피격 잠금에는 강화 회복약 사용 차단"): return false
	player._input_lock_remaining_s = 0
	controls.show_main_screen()
	_press_dew_potion()
	if not _check(player.damage_receiver.health == 1 and player.potions_remaining == 1, "메인에는 강화 회복약 사용 차단"): return false
	controls.screen_mode = GroundMovementControls.ScreenMode.COMBAT
	_press_dew_potion()
	if not _check(player.damage_receiver.health == 52 and player.potions_remaining == 0, "농축101×50% 정수 올림51·실제 회복"): return false
	player.set_potion_pouch_unlocked(true, true)
	if not _check(player.potions_capacity() == 2 and player.potions_remaining == 1 and controls.movement_metrics.potion_heal_percent == 50, "주머니 조합·1개 보충·농축 최대2·50% 유지"): return false
	player.damage_receiver.health = 95
	_press_dew_potion()
	if not _check(player.damage_receiver.health == 101 and player.potions_remaining == 0, "최대 체력 상한·부족6만 회복·1개 소비"): return false
	player.prepare_potions(PrototypePotionRecipes.BASIC)
	player.damage_receiver.health = 1
	_press_dew_potion()
	if not _check(player.damage_receiver.health == 37 and player.potions_remaining == 2 and player.potions_capacity() == 3 and controls.movement_metrics.potion_heal_percent == 35, "기본101×35% 올림36·주머니3개 중1개 소비·HUD35%"): return false
	player.damage_receiver.health = 1
	if not _check(player.collect_recovery_orb() and player.damage_receiver.health == 1 + ceili(101 * RecoveryOrbController.HEAL_RATIO), "회복 구슬 원래 회복률 독립"): return false
	player.apply_growth_health(0, 10)
	if not _check(player.damage_receiver.health == 11 + ceili(101 * RecoveryOrbController.HEAL_RATIO), "고정 휴식/성장 회복은 원래10"): return false
	if not _check(weapons.checkpoint_snapshot() == timers and ultimate.gauge == gauge and player.skill_recharge_multiplier() == 1 and is_equal_approx(player.ground_evade_cooldown_s(), 0.45), "스킬/기본 공격 대기시간·필살기·회피 독립"): return false
	player.damage_receiver.tick(2)
	var run_id := player.relic_run_id
	_hit_player(9999, "dew-is-not-phoenix")
	return _check(player.damage_receiver.dead and not player.relic_state.used and not legacy.phoenix_used(run_id) and store.load_checkpoint().is_empty() and not player.use_recovery_potion(), "이슬 치명타 정상 사망·부활/깃털 소비/사후 회복 없음")

func _test_dew_text() -> bool:
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_relic_reward_layout()
		for i in PrototypeRelic.OFFERS.size():
			var rect: Rect2 = controls.relic_reward_card_rects[i]
			for j in PrototypeRelic.OFFERS[i].lines.size():
				var line: String = PrototypeRelic.OFFERS[i].lines[j]
				var line_rect := Rect2(rect.position + Vector2(12, rect.size.y * (0.57 + j * 0.12)), Vector2(rect.size.x - 24, 30))
				var font_size := 19
				while font_size > 10 and ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > line_rect.size.x: font_size -= 1
				if not _check(rect.encloses(line_rect) and ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= line_rect.size.x, "세 후보 설명 줄 높이/글자 폭·두 화면비"): return false
		controls.show_main_screen()
		controls.show_village()
		controls.village_page = "relics"
		var snapshot: Dictionary = controls.village_snapshot()
		for i in snapshot.cards.size():
			var rect: Rect2 = snapshot.layout.cards[i]
			for j in snapshot.cards[i].lines.size():
				var line: String = snapshot.cards[i].lines[j]
				var line_rect := Rect2(rect.position + Vector2(12, rect.size.y * (0.44 + j * 0.08)), Vector2(rect.size.x - 24, rect.size.y * 0.08))
				var font_size := mini(18, maxi(12, int(line_rect.size.y * 0.8)))
				while font_size > 10 and ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > line_rect.size.x: font_size -= 1
				if not _check(rect.encloses(line_rect) and ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= line_rect.size.x, "세 유물 도감 설명 실제 축소 규칙·카드 내 포함"): return false
		controls.queue_redraw()
		await process_frame
	return true

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-135 failed: " + message)
		paused = false
		quit(1)
	return condition
