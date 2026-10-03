extends "res://tests/gp110_runtime_test.gd"

const GP117_SAVE := "user://gp117_checkpoint.json"
const GP117_META := "user://gp117_meta.jsonl"
const GP117_RECORD := "user://gp117_records.jsonl"
const GP117_LAYOUT := "user://gp117_layout.json"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP117_SAVE
	legacy.save_path = GP117_META
	if phase == "seed":
		store.clear_checkpoint()
		for path in [GP117_META, GP117_RECORD, GP117_LAYOUT]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP117_RECORD
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
	match phase:
		"seed":
			if not await _test_layout(): return
			controls.begin_retry("sword")
			_press_potion()
			if not _check(player.potions_remaining == 2 and player.damage_receiver.health == 100, "만피에서는 회복·소비 없음"): return
			_damage_player(60)
			var hits := player.damage_receiver.applied_count
			_press_potion()
			if not _check(player.damage_receiver.health == 65 and player.potions_remaining == 1 and controls._action_label(&"recovery_potion") == "회복 1/2" and player.damage_receiver.applied_count == hits, "실제 피해 후 모바일 입력·25 회복·횟수 HUD·피격 집계 독립"): return
			controls._handle_touch_dragged(7, controls.action_rects[&"recovery_potion"].get_center())
			controls._physics_process(0.01)
			if not _check(player.potions_remaining == 1, "드래그·길게 누름은 반복 소비 없음"): return
			controls._handle_touch_released(7)
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			var saved := store.load_checkpoint()
			if not _check(not saved.is_empty() and saved.player.potions_remaining == 1, "성장·스테이지 회복 뒤에도 남은 1회 중간 저장"): return
			var before := player.damage_receiver.health
			if not _check(not sandbox._use_recovery_potion() and player.potions_remaining == 1 and player.damage_receiver.health == before, "보상·경로 일시정지에서 사용 금지"): return
			for invalid in [-1, 3, 0.5, true, "1"]:
				var bad := saved.duplicate(true)
				bad.player.potions_remaining = invalid
				if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "손상 횟수 거부·정상 저장 보호"): return
		"resume":
			if not _check(sandbox.continue_saved_run() and player.potions_remaining == 1 and controls.movement_metrics.potions_remaining == 1, "별도 프로세스 이어하기·횟수 HUD 복원"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _check(runner.stage_number == 2 and controls.current_screen_mode() == 0 and player.potions_remaining == 1, "다음 스테이지는 회복약 재충전 없음"): return
			player.damage_receiver.health = player.damage_receiver.max_health - 1
			_press_potion()
			controls._handle_touch_released(7)
			if not _check(player.potions_remaining == 0 and player.damage_receiver.health == player.damage_receiver.max_health, "최대 체력 초과 없이 마지막 1회 소비"): return
			_damage_player(10)
			var health := player.damage_receiver.health
			_press_potion()
			controls._handle_touch_released(7)
			if not _check(player.damage_receiver.health == health and player.potions_remaining == 0, "소진 뒤 회복 없음"): return
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			if not _check(store.load_checkpoint().player.potions_remaining == 0, "소진 상태도 저장"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and player.potions_remaining == 0, "소진 저장 재시작 복원"): return
			controls.begin_retry("bow")
			if not _check(player.potions_remaining == 2 and player.damage_receiver.health == 100, "새 도전만 두 회 충전·이전 성장 초기화"): return
			player.damage_receiver.max_health = 105
			player.damage_receiver.health = 40
			player._fall_recovery_active = true
			if not _check(not sandbox._use_recovery_potion() and player.potions_remaining == 2, "낙하 복귀 중 입력 잠금"): return
			player._fall_recovery_active = false
			player.begin_combat_action(0, false, false)
			if not _check(sandbox._use_recovery_potion() and player.damage_receiver.health == 67 and player._combat_action_active, "증가 최대 체력의 25% 올림·공격 상태 유지"): return
			player.end_combat_action()
			controls.open_layout_editor()
			var before := player.damage_receiver.health
			if not _check(controls.start_layout_test(), "배치 테스트 진입"): return
			_press_potion()
			controls._handle_touch_released(7)
			if not _check(player.potions_remaining == 1 and player.damage_receiver.health == before, "배치 연습은 실제 회복·소비 없음"): return
			controls.finish_layout_test()
			controls.cancel_layout_editor()
			player.damage_receiver.dead = true
			if not _check(not player.use_recovery_potion() and player.potions_remaining == 1, "회복약으로 사망 부활 없음"): return
			controls.begin_retry()
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			var old := store.load_checkpoint()
			old.player.erase("potions_remaining")
			if not _check(store.save_checkpoint(old) == OK, "GP-116 이전 회복약 없는 정상 저장 준비"): return
		"legacy-resume":
			if not _check(sandbox.continue_saved_run() and player.potions_remaining == 2 and controls.movement_metrics.potions_remaining == 2, "기존 저장은 미사용 두 회로 호환 복원"): return
		_:
			_check(false, "검사 단계 오류")
			return
	paused = false
	sandbox.free()
	print("GP-117 runtime test: OK (" + phase + ")")
	quit(0)

func _press_potion() -> void:
	controls._handle_touch_released(7)
	var event := InputEventScreenTouch.new()
	event.index = 7
	event.position = controls.action_rects[&"recovery_potion"].get_center()
	event.pressed = true
	controls._input(event)
	controls._physics_process(0.01)

func _damage_player(amount: int) -> void:
	player.damage_receiver.tick(1.0)
	var event := DamageEvent.new()
	event.event_id = StringName("gp117:hit:%d" % player.damage_receiver.applied_count)
	event.attacker_id = &"test"
	event.damage = amount
	event.tags = PackedStringArray(["test"])
	player.receive_damage(event)

func _test_layout() -> bool:
	controls.configure_layout_store_path_for_test(GP117_LAYOUT)
	controls.open_layout_editor()
	for preset in ["default", "left"]:
		for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
			controls.size = dimensions
			controls.select_control_preset(preset)
			var snapshot: Dictionary = controls.layout_snapshot()
			var rect: Rect2 = controls.action_rects[&"recovery_potion"]
			if not _check(snapshot.safe.encloses(rect) and controls.control_layout_snapshot().invalid_controls.is_empty(), "두 화면비·양손 프리셋 회복약 안전 영역·겹침 없음"): return false
			controls.queue_redraw()
			await process_frame
	controls.select_control_preset("default")
	controls.set_control_center_normalized(&"recovery_potion", Vector2(0.40, 0.70))
	if not _check(controls.apply_layout_editor(), "회복약 사용자 배치 저장"): return false
	controls.reload_control_layout_from_store()
	if not _check(controls.control_layout_snapshot().centers[&"recovery_potion"].is_equal_approx(Vector2(0.40, 0.70)), "회복약 사용자 좌표 복원"): return false
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GP117_LAYOUT))
	payload.active_layout.elements.erase("recovery_potion")
	var file := FileAccess.open(GP117_LAYOUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	controls.reload_control_layout_from_store()
	if not _check(controls.control_layout_snapshot().centers[&"recovery_potion"].is_equal_approx(Vector2(0.40, 0.85)), "기존 조작 저장은 누락된 회복약만 기본 위치로 복구"): return false
	return true

func _check(condition: bool, message: String) -> bool:
	if condition: return true
	push_error("GP-117 실패: " + message)
	paused = false
	quit(1)
	return false
