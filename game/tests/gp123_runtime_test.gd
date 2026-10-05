extends "res://tests/gp110_runtime_test.gd"

const GP123_SAVE := "user://gp123_checkpoint.json"
const GP123_META := "user://gp123_meta.jsonl"
const GP123_RECORD := "user://gp123_records.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP123_SAVE
	legacy.save_path = GP123_META
	if phase == "seed":
		store.clear_checkpoint()
		for path in [GP123_META, GP123_RECORD]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP123_RECORD
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
	weapons.sword_combat.set_process(false)
	weapons.bow_combat.set_process(false)
	runner.set_process(false)
	player.set_physics_process(false)
	match phase:
		"seed":
			controls.begin_retry()
			if not _check(not player.double_jump_unlocked and not player.air_jump_available and controls._action_label(&"jump") == "점프", "새 도전은 기존 1단 점프"): return
			if not await _test_jump(false): return
			player.set_physics_process(false)
			if not await _choose_air_jump(): return
			if not _check(player.double_jump_unlocked and player.air_jump_available and growth.ranks.get("air_jump") == 1 and player.damage_receiver.max_health == 100 and player.growth_common_bonus == 0.0 and weapons.sword_combat._skill_1_cooldown_s == 0.0, "실제 능력 카드 터치로 도약만 해금"): return
			for ignored in 100:
				for card in growth._draw_cards():
					if not _check(card.id != "air_jump", "해금한 공중 도약은 공용·무작위 후보 모두 제외"): return
			# 이미 선택한 카드가 남은 오래된 화면으로 다시 전달되어도 중복하지 않는다.
			growth.choosing = true
			for card in PrototypeGrowthController.CARDS:
				if card.id == "air_jump": growth.offered_cards = [card.duplicate(true)]
			if not _check(not growth.choose_card(0) and growth.ranks.air_jump == 1, "최대 1등급 카드 중복 선택 차단"): return
			growth.choosing = false
			growth.offered_cards.clear()
			if not await _test_jump(true): return
			if not await _test_recovery(): return
			player.set_physics_process(false)
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "공중 도약 도전 중간 저장"): return
			var saved := store.load_checkpoint()
			if not _check(saved.growth.ranks.air_jump == 1 and RunCheckpointStore.valid_state(saved), "성장 기록만으로 2단 점프 저장"): return
			var bad := saved.duplicate(true)
			bad.growth.ranks.air_jump = 2
			bad.growth.ranks.sword_power -= 1
			bad.player.sword -= 0.15
			if not _check(not RunCheckpointStore.valid_state(bad) and store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "총 등급 수를 맞춘 2등급 도약 변조 거부·정상 저장 보호"): return
		"resume":
			if not _check(sandbox.continue_saved_run() and player.double_jump_unlocked and player.air_jump_available and growth.ranks.air_jump == 1, "별도 프로세스 이어하기로 능력·사용 가능 복원"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _check(runner.stage_number == 2 and player.double_jump_unlocked and player.air_jump_available, "스테이지 이동은 해금 유지·공중 횟수 준비"): return
			if not await _test_jump(true): return
			player.set_physics_process(false)
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "두 번째 스테이지 통과 저장"): return
			if not _check(store.load_checkpoint().growth.ranks.air_jump == 1, "연속 스테이지에도 단일 도약 등급 유지"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and player.double_jump_unlocked, "두 번째 통과 저장 복원"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("rescue"), "도약 도전 실제 보스 완주"): return
			controls.begin_retry()
			if not _check(not player.double_jump_unlocked and not player.air_jump_available and player.double_jump_count == 0 and not growth.ranks.has("air_jump") and controls._action_label(&"jump") == "점프", "새 도전은 도약 해금·횟수·HUD 초기화"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "GP-122 형식 도약 없는 이전 저장 준비"): return
			if not _check(not store.load_checkpoint().growth.ranks.has("air_jump"), "이전 저장은 기존 카드와 스키마 그대로"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and not player.double_jump_unlocked and not player.air_jump_available, "이전 저장은 1단 점프로 호환"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _test_jump(false): return
			player.set_physics_process(false)
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 저장 두 번째 통과"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("destroy"), "이전 저장 실제 보스 완주"): return
			player.player_died.emit()
			controls.begin_retry()
			if not _check(not player.double_jump_unlocked and not player.air_jump_available, "사망 뒤 새 도전도 기존 점프 유지"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-123 runtime test: OK (" + phase + ")")
	quit(0)

func _choose_air_jump() -> bool:
	# 실제 두 적 처치의 첫 레벨업에서 도약을 제안하는 고정 난수 시드를 찾는다.
	var seed_found := -1
	for candidate in 128:
		growth.rng.seed = candidate
		for card in growth._draw_cards():
			if card.id == "air_jump": seed_found = candidate
		if seed_found >= 0: break
	if not _check(seed_found >= 0, "공용 후보에 공중 도약 등장"): return false
	growth.rng.seed = seed_found
	player.global_position.x = 1240
	runner._process(0.1)
	for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
	if not _check(growth.choosing and paused and growth.level == 2, "실제 처치 경험치 레벨업·전투 정지"): return false
	var index := -1
	for i in growth.offered_cards.size():
		if growth.offered_cards[i].id == "air_jump": index = i
	if not _check(index >= 0, "실제 제안된 도약 카드"): return false
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_growth_layout()
		var safe: Rect2 = controls.layout_snapshot().safe
		for rect in controls.growth_card_rects:
			if not _check(safe.encloses(rect) and not rect.intersects(controls.growth_reroll_rect), "두 화면비 도약 카드 안전 영역"): return false
		controls.queue_redraw()
		await process_frame
	_tap(controls.growth_card_rects[index].get_center())
	return _check(not paused and not growth.choosing, "도약 선택 후 전투 재개")

func _test_jump(unlocked: bool) -> bool:
	player.prepare_next_stage(Vector2(960, 780))
	player.set_physics_process(true)
	for ignored in 8: await physics_frame
	if not _check(player.is_on_floor(), "물리 바닥 착지"): return false
	var jumps := player.jump_count
	var doubles := player.double_jump_count
	await _press_jump()
	for ignored in 10: await physics_frame
	if not _check(not player.is_on_floor() and player.jump_count == jumps + 1 and player.double_jump_count == doubles and player.last_jump_assist == "일반", "실제 터치 첫 점프·코요테와 도약 구분"): return false
	controls._handle_touch_released(4)
	await _press_jump()
	if unlocked:
		if not _check(player.jump_count == jumps + 2 and player.double_jump_count == doubles + 1 and player.velocity.y < 0 and not player.air_jump_available and player.last_jump_assist == "공중 도약" and player._air_jump_flash_remaining_s > 0.0 and controls._action_label(&"jump") == "도약 0", "실제 공중 재점프·상승·1회 소비·HUD"): return false
		for ignored in 8: await physics_frame
		if not _check(player.jump_count == jumps + 2, "길게 누르기로 추가 도약 없음"): return false
		controls._handle_touch_released(4)
		await _press_jump()
		if not _check(player.jump_count == jumps + 2 and player.double_jump_count == doubles + 1, "세 번째 점프 차단"): return false
		controls._handle_touch_released(4)
		var dashes := player.air_dash_count
		player.request_evade()
		if not _check(player.air_dash_count == dashes + 1 and not player.air_jump_available, "2단 점프 뒤 공중 대시 가능·도약 충전 없음"): return false
	else:
		if not _check(player.jump_count == jumps + 1 and player.double_jump_count == doubles, "해금 전 공중 재점프 차단"): return false
	controls._handle_touch_released(4)
	for ignored in 150:
		await physics_frame
		if player.is_on_floor(): break
	if not _check(player.is_on_floor() and player.air_jump_available == unlocked and (controls._action_label(&"jump") == "2단 점프" if unlocked else controls._action_label(&"jump") == "점프"), "실제 착지로 충전·HUD 복원"): return false
	if unlocked:
		await _press_jump()
		controls._handle_touch_released(4)
		for ignored in 10: await physics_frame
		player.begin_combat_action(0, false, false)
		var before := player.jump_count
		await _press_jump()
		if not _check(player.jump_count == before and player.air_jump_available, "공격 동작 중 점프는 소비하지 않음"): return false
		controls._handle_touch_released(4)
		player.end_combat_action()
		await _press_jump()
		if not _check(player.jump_count == before + 1 and not player.air_jump_available, "공격 종료 후 공중 도약 사용"): return false
		controls._handle_touch_released(4)
	player.set_physics_process(false)
	player.prepare_next_stage(Vector2(960, 780))
	return true

func _test_recovery() -> bool:
	player.set_physics_process(true)
	player.air_jump_available = false
	player.global_position = Vector2(3380, 1120)
	player.velocity = Vector2.ZERO
	var falls := player.fall_count
	for ignored in 100:
		await physics_frame
		if player.fall_count > falls and not player._fall_recovery_active and not player._is_input_locked(): break
	if not _check(player.fall_count == falls + 1 and player.double_jump_unlocked and player.air_jump_available and player.is_on_floor(), "낙하 안전 복귀는 능력 보존·도약 충전"): return false
	player.set_physics_process(false)
	player._input_lock_remaining_s = 0.20
	var jumps := player.jump_count
	player.request_jump()
	if not _check(player._jump_buffer_remaining_s == 0.0 and player.jump_count == jumps and player.air_jump_available, "복귀/피격 입력 잠금은 도약 소비 없음"): return false
	player._input_lock_remaining_s = 0.0
	return true

func _press_jump() -> void:
	controls._handle_touch_released(4)
	_tap(controls.action_rects[&"jump"].get_center())
	controls._physics_process(0.001)
	await physics_frame
	await physics_frame

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-123 failed: " + message)
		paused = false
		quit(1)
	return condition
