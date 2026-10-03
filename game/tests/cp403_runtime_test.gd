extends SceneTree

const SANDBOX_SCENE := preload("res://scenes/movement/ground_movement_sandbox.tscn")
const TEST_SAVE_PATH := "user://cp403_runtime_test.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_save()
	var sandbox := SANDBOX_SCENE.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	root.add_child(sandbox)
	var controls := sandbox.get_node("CanvasLayer/GroundMovementControls") as Control
	await process_frame
	controls.configure_layout_store_path_for_test(TEST_SAVE_PATH)
	controls.size = Vector2(1280.0, 720.0)
	controls.notification(Control.NOTIFICATION_RESIZED)

	controls.open_layout_editor()
	controls.set_control_center_normalized(&"skill_1", Vector2(0.48, 0.62))
	var edited_center: Vector2 = (controls.control_layout_snapshot()["centers"] as Dictionary)[&"skill_1"]
	if not _assert_true(controls.start_layout_test(), "10초 배치 테스트 시작"):
		return
	if not _assert_equal(controls.current_screen_mode(), 4, "배치 테스트 화면 진입"):
		return
	if not _assert_true(sandbox.is_combat_environment_suspended(), "테스트 중 적·피해 환경 정지"):
		return

	var touch_rects: Dictionary = controls.control_layout_snapshot()["touch_rects"]
	var move_rect: Rect2 = touch_rects[&"move"]
	var jump_rect: Rect2 = touch_rects[&"jump"]
	_send_touch(controls, 0, move_rect.get_center(), true)
	_send_touch(controls, 1, jump_rect.get_center(), true)
	var active_test: Dictionary = controls.layout_test_snapshot()
	if not _assert_equal(int(active_test["peak_controls"]), 2, "두 조작 멀티터치 인식"):
		return
	if not _assert_equal(int((active_test["input_counts"] as Dictionary).get(&"move", 0)), 1, "이동 입력 표시"):
		return
	if not _assert_equal(int((active_test["input_counts"] as Dictionary).get(&"jump", 0)), 1, "점프 입력 표시"):
		return
	_send_touch(controls, 1, jump_rect.get_center(), false)
	_send_touch(controls, 0, move_rect.get_center(), false)

	controls.advance_mode_timer_for_test(10.0)
	if not _assert_equal(controls.current_screen_mode(), 3, "10초 종료 후 편집 화면 복귀"):
		return
	if not _assert_true(not sandbox.is_combat_environment_suspended(), "테스트 종료 후 환경 복구"):
		return
	if not _assert_true(not FileAccess.file_exists(TEST_SAVE_PATH), "테스트만으로 자동 저장하지 않음"):
		return
	var after_test_center: Vector2 = (controls.control_layout_snapshot()["centers"] as Dictionary)[&"skill_1"]
	if not _assert_equal(after_test_center, edited_center, "저장 전 편집 배치 유지"):
		return

	controls.cancel_layout_editor()
	controls.begin_stage_from_main()
	controls.open_layout_editor()
	if not _assert_true(sandbox.is_combat_environment_suspended(), "전투 중 편집 시 환경 정지"):
		return
	if not _assert_true(controls.apply_layout_editor(), "전투 중 배치 적용"):
		return
	if not _assert_equal(controls.current_screen_mode(), 5, "3초 전투 복귀 카운트다운"):
		return
	if not _assert_true(is_equal_approx(float(controls.layout_test_snapshot()["resume_remaining_s"]), 3.0), "복귀 카운트다운 3초"):
		return
	controls.advance_mode_timer_for_test(1.0)
	if not _assert_equal(controls.current_screen_mode(), 5, "카운트다운 중 전투 입력 차단"):
		return
	controls.advance_mode_timer_for_test(2.0)
	if not _assert_equal(controls.current_screen_mode(), 0, "카운트다운 후 전투 복귀"):
		return
	if not _assert_true(not sandbox.is_combat_environment_suspended(), "전투 환경 재개"):
		return

	_remove_test_save()
	print("CP-403 runtime test: OK")
	quit(0)


func _send_touch(controls: Control, pointer_id: int, position: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = pointer_id
	touch.position = position
	touch.pressed = pressed
	controls._input(touch)


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func _assert_equal(actual: Variant, expected: Variant, label: String) -> bool:
	if actual == expected:
		return true
	push_error("%s 실패: actual=%s expected=%s" % [label, actual, expected])
	quit(1)
	return false


func _assert_true(value: bool, label: String) -> bool:
	if value:
		return true
	push_error("%s 실패" % label)
	quit(1)
	return false
