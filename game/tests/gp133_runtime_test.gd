extends "res://tests/gp131_runtime_test.gd"

const GP133_SAVE := "user://gp133_checkpoint.json"
const GP133_META := "user://gp133_meta.jsonl"
const GP133_RECORD := "user://gp133_records.jsonl"
const GP133_BOOK := "user://gp133_abilities.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP133_SAVE
	legacy.save_path = GP133_META
	book.save_path = GP133_BOOK
	if phase in ["seed", "combat"]:
		store.clear_checkpoint()
		for path in [GP133_META, GP133_RECORD, GP133_BOOK]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.ability_discovery_store = book
	sandbox.get_node("LocalTestRecorder").record_path = GP133_RECORD
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	recorder = sandbox.get_node("LocalTestRecorder")
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	for controller in [weapons.sword_combat, weapons.bow_combat]:
		controller.set_process(false)
		controller.set_physics_process(false)
	player.set_physics_process(false)
	runner.set_process(false)
	match phase:
		"seed":
			controls.begin_retry()
			player._evade_cooldown_remaining_s = 0.31
			if not await _choose_nimble(): return
			if not _check(player.nimble_evade_unlocked and is_equal_approx(player.ground_evade_cooldown_s(), 0.36) and is_equal_approx(player._evade_cooldown_remaining_s, 0.31) and growth.ranks.nimble_evade == 1 and book.snapshot().has("nimble_evade"), "실제 카드 해금·0.36초·기존 잔여 대기 유지·등급·발견"): return
			for ignored in 100:
				for card in growth._draw_cards():
					if not _check(card.id != "nimble_evade", "선택한 민첩 회피 후보 제외"): return
			if not _reject_card("nimble_evade") or not _check(is_equal_approx(player.ground_evade_cooldown_s(), 0.36), "중복 선택·추가 감소 차단"): return
			if not await _test_ground_evade(true, 60): return
			if not _finish_stage(): return
			var saved := store.load_checkpoint()
			store.save_path = "user://gp133_missing/checkpoint.json"
			if not _check(not sandbox._claim_weapon_reward("") and not runner.reward_claimed and player.nimble_evade_unlocked, "중간 저장 실패는 능력·보상 상태 보존"): return
			store.save_path = GP133_SAVE
			if not _check(store.load_checkpoint() == saved and sandbox._claim_weapon_reward(""), "정상 저장 보호·재시도"): return
			saved = store.load_checkpoint()
			var bad := saved.duplicate(true)
			bad.growth.ranks.nimble_evade = 2
			if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "최대1등급 저장 변조 거부"): return
			controls.show_main_screen()
			controls.show_village()
			if not await _test_book_layout(): return
			controls.ability_codex_page = 3
			if not _check(PrototypeAbilityCodex.definitions().size() == 16 and controls.village_snapshot().cards.filter(func(card: Dictionary) -> bool: return card.id == "nimble_evade" and card.open and card.status == "이번 도전 1등급").size() == 1, "16능력·여섯 페이지·민첩 실제 도감 표시"): return
		"resume":
			if not _check(not player.nimble_evade_unlocked and is_equal_approx(player.ground_evade_cooldown_s(), 0.45) and book.snapshot().has("nimble_evade"), "영구 발견은 시작 능력 지급 없음"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and player.nimble_evade_unlocked and is_equal_approx(player.ground_evade_cooldown_s(), 0.36), "별도 프로세스·반복 이어하기 단일 배율 복원"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not await _test_ground_evade(true, 30): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "두 번째 정예 저장"): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[1].get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(player.relic_state.id == PrototypeRelic.CLOCK_ID and player.skill_recharge_multiplier() == 1.25 and is_equal_approx(player.ground_evade_cooldown_s(), 0.36), "실제 시계추 획득은 회피 감소 중첩 없음"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and player.nimble_evade_unlocked and player.skill_recharge_multiplier() == 1.25, "민첩·시계추 함께 재시작 복원"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _test_ground_evade(true, 60): return
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("rescue"), "민첩 회피 도전 실제 보스 완주"): return
			controls.begin_retry()
			if not _check(not player.nimble_evade_unlocked and is_equal_approx(player.ground_evade_cooldown_s(), 0.45) and not growth.ranks.has("nimble_evade") and book.snapshot().has("nimble_evade"), "새 도전 원래 회피 복원·발견 유지"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward("") and not store.load_checkpoint().growth.ranks.has("nimble_evade"), "기존 카드만 보유한 이전 저장 준비"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and not player.nimble_evade_unlocked and is_equal_approx(player.ground_evade_cooldown_s(), 0.45), "이전 저장 기존 회피 호환"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _test_ground_evade(false, 60): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 저장 두 번째 통과"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("destroy"), "이전 저장 실제 완주"): return
		"combat":
			controls.begin_retry()
			if not await _test_ground_evade(false, 30): return
			if not await _choose_nimble(): return
			if not await _test_ground_evade(true, 30): return
			if not await _test_air_and_locks(): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-133 runtime test: OK (" + phase + ")")
	quit(0)

func _choose_nimble() -> bool:
	var chosen_seed := -1
	for candidate in 256:
		growth.rng.seed = candidate
		for card in growth._draw_cards():
			if card.id == "nimble_evade": chosen_seed = candidate
		if chosen_seed >= 0: break
	if not _check(chosen_seed >= 0, "실제 공용 민첩 회피 후보 등장"): return false
	growth.rng.seed = chosen_seed
	player.global_position.x = 1240
	runner._process(0.1)
	for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
	var index := -1
	for i in growth.offered_cards.size():
		if growth.offered_cards[i].id == "nimble_evade": index = i
	if not _check(index >= 0 and paused and growth.choosing, "실제 처치 레벨업·민첩 카드 UI"): return false
	var before := growth.checkpoint_snapshot()
	var cooldown := player._evade_cooldown_remaining_s
	var health := player.damage_receiver.health
	var potions := player.potions_remaining
	var equipment := weapons.checkpoint_snapshot()
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_growth_layout()
		var safe: Rect2 = controls.layout_snapshot().safe
		for rect in controls.growth_card_rects:
			if not _check(safe.encloses(rect) and not rect.intersects(controls.growth_reroll_rect), "두 화면비 실제 능력 선택 카드 안전 영역"): return false
		var chosen_rect: Rect2 = controls.growth_card_rects[index]
		var font_size := mini(26, int(chosen_rect.size.x / 12.0)) - 3
		for line in growth.offered_cards[index].lines:
			if not _check(ThemeDB.fallback_font.get_string_size(String(line), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= chosen_rect.size.x - 24, "두 화면비 실제 회피 카드 설명 글자 너비"): return false
		controls.queue_redraw()
		await process_frame
	book.save_path = "user://gp133_missing/abilities.jsonl"
	_tap(controls.growth_card_rects[index].get_center())
	if not _check(paused and growth.choosing and growth.checkpoint_snapshot() == before and not player.nimble_evade_unlocked and is_equal_approx(player._evade_cooldown_remaining_s, cooldown), "기록 실패는 능력·잔여 대기·등급·성향 미적용"): return false
	book.save_path = GP133_BOOK
	_tap(controls.growth_card_rects[index].get_center())
	return _check(not paused and not growth.choosing and player.nimble_evade_unlocked and player.damage_receiver.health == health and player.potions_remaining == potions and weapons.checkpoint_snapshot() == equipment, "재선택 성공·전투 재개·체력/회복약/양 무기 대기 독립")

func _press_nimble_evade() -> void:
	var event := InputEventScreenTouch.new()
	event.index = 6
	event.position = controls.action_rects[&"evade"].get_center()
	event.pressed = true
	controls._input(event)
	controls._physics_process(0.001)
	controls._handle_touch_released(6)
	player._emit_metrics()

func _test_ground_evade(unlocked: bool, fps: int) -> bool:
	var jobs_enabled := growth.jobs_enabled
	growth.jobs_enabled = false
	player.prepare_next_stage(Vector2(960, 780))
	player.set_physics_process(true)
	for ignored in 8: await physics_frame
	player.set_physics_process(false)
	if not _check(player.is_on_floor() and player.nimble_evade_unlocked == unlocked, "물리 바닥 착지·능력 보존"): return false
	player._evade_cooldown_remaining_s = 0
	player.move_input = -1
	player.move_input_vector = Vector2.LEFT
	var count := player.ground_evade_count
	var equipment := weapons.checkpoint_snapshot()
	var potions := player.potions_remaining
	var expected := 0.36 if unlocked else 0.45
	_press_nimble_evade()
	player._apply_mobility_velocity()
	if not _check(player.ground_evade_count == count + 1 and is_equal_approx(player._evade_cooldown_remaining_s, expected) and player.invincible and is_equal_approx(player._invincible_remaining_s, 0.18) and is_equal_approx(player._mobility_remaining_s, 0.24) and player.velocity.x == -900 and player.facing_direction == -1, "실제 모바일 지상 회피·0.36/0.45초·무적/동작/속도/방향 원본 유지"): return false
	if unlocked and not _check(controls._action_label(&"evade") == "회피 0.36", "실제 남은 회피 대기 HUD"): return false
	_press_nimble_evade()
	if not _check(player.ground_evade_count == count + 1, "동작 중 연속 입력 차단"): return false
	player._update_mobility_timers(0.17)
	var health := player.damage_receiver.health
	_hit_player(5, "nimble-protected-%d-%d" % [fps, count])
	if not _check(player.damage_receiver.health == health and player.invincible, "0.17초 실제 적 타격 무적 유지"): return false
	player._update_mobility_timers(0.02)
	player.damage_receiver.tick(1)
	_hit_player(5, "nimble-exposed-%d-%d" % [fps, count])
	if not _check(not player.invincible and player.damage_receiver.health == health - 5, "0.19초 실제 피해·무적 연장 없음"): return false
	player._update_mobility_timers(0.06)
	_press_nimble_evade()
	if not _check(player.ground_evade_count == count + 1 and player.last_mobility_result == "지상 회피 재사용 대기", "동작 종료 후에도 잔여 대기 차단"): return false
	var remaining := expected - 0.25 - 0.001
	while remaining > 0:
		var step := minf(remaining, 1.0 / fps)
		player._update_mobility_timers(step)
		remaining = maxf(0, remaining - step)
	_press_nimble_evade()
	if not _check(player.ground_evade_count == count + 1, "30/60 갱신 모두 재사용 직전 차단"): return false
	player._update_mobility_timers(0.002)
	player._emit_metrics()
	if unlocked and not _check(controls._action_label(&"evade") == "민첩 회피", "재사용 준비 HUD"): return false
	_press_nimble_evade()
	if not _check(player.ground_evade_count == count + 2 and is_equal_approx(player._evade_cooldown_remaining_s, expected), "30/60 갱신 모두 실제 새 회피 가능·배율 중첩 없음"): return false
	player._update_mobility_timers(expected + 0.01)
	player._emit_metrics()
	growth.jobs_enabled = jobs_enabled
	return _check(weapons.checkpoint_snapshot() == equipment and player.potions_remaining == potions, "지상 회피 감소는 양 무기 쿨다운·회복약 변경 없음")

func _press_nimble_jump() -> void:
	controls._handle_touch_released(4)
	_tap(controls.action_rects[&"jump"].get_center())
	controls._physics_process(0.001)
	await physics_frame
	await physics_frame

func _test_air_and_locks() -> bool:
	player.prepare_next_stage(Vector2(960, 780))
	player.set_physics_process(true)
	for ignored in 8: await physics_frame
	await _press_nimble_jump()
	controls._handle_touch_released(4)
	for ignored in 10: await physics_frame
	player.set_physics_process(false)
	if not _check(not player.is_on_floor(), "실제 점프 뒤 공중 상태"): return false
	player._evade_cooldown_remaining_s = 0.2
	var dashes := player.air_dash_count
	_press_nimble_evade()
	player._apply_mobility_velocity()
	if not _check(player.air_dash_count == dashes + 1 and not player.air_dash_available and not player.invincible and is_equal_approx(player._mobility_remaining_s, 0.18) and is_equal_approx(player.velocity.length(), 950), "공중 대시 1회·0.18초·9.5m/s·무적 없음 원본 유지"): return false
	player._update_mobility_timers(0.5)
	_press_nimble_evade()
	if not _check(player.air_dash_count == dashes + 1, "회피 대기 끝나도 공중 추가 대시 차단"): return false
	player.set_physics_process(true)
	for ignored in 150:
		await physics_frame
		if player.is_on_floor(): break
	player.set_physics_process(false)
	if not _check(player.is_on_floor() and player.air_dash_available and player.nimble_evade_unlocked, "실제 착지 대시 충전·성장 유지"): return false
	var evades := player.ground_evade_count
	player._input_lock_remaining_s = 0.2
	_press_nimble_evade()
	player._input_lock_remaining_s = 0
	player.set_combat_evade_allowed(false)
	_press_nimble_evade()
	player.set_combat_evade_allowed(true)
	if not _check(player.ground_evade_count == evades, "복귀/피격 잠금과 공격 취소 불가 구간은 민첩도 차단"): return false
	player.damage_receiver.tick(2)
	_hit_player(9999, "nimble-dead")
	player.request_evade()
	return _check(player.damage_receiver.dead and player.ground_evade_count == evades, "사망 플레이어 회피 차단")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-133 failed: " + message)
		paused = false
		quit(1)
	return condition
