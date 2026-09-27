extends SceneTree

const SANDBOX_SCENE := preload("res://scenes/movement/ground_movement_sandbox.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sandbox := SANDBOX_SCENE.instantiate()
	root.add_child(sandbox)
	var controls := sandbox.get_node("CanvasLayer/GroundMovementControls") as Control
	await process_frame

	if not _assert_equal(controls.current_screen_mode(), 2, "앱 시작 메인 화면"):
		return
	controls.size = Vector2(1280.0, 720.0)
	controls.notification(Control.NOTIFICATION_RESIZED)
	controls.open_layout_editor()
	if not _assert_equal(controls.current_screen_mode(), 3, "조작 배치 편집 진입"):
		return

	var initial: Dictionary = controls.control_layout_snapshot()
	if not _assert_equal((initial["touch_rects"] as Dictionary).size(), 7, "전체 조작 요소 7개"):
		return
	var safe: Rect2 = controls.layout_snapshot()["safe"]
	for rect_value in (initial["touch_rects"] as Dictionary).values():
		var rect: Rect2 = rect_value
		if not _assert_true(safe.encloses(rect), "조작 요소 안전 영역 포함"):
			return

	controls.select_layout_control(&"jump")
	controls.adjust_selected_control_size(1.0)
	var resized: Dictionary = controls.control_layout_snapshot()
	if not _assert_true(is_equal_approx(float((resized["scales"] as Dictionary)[&"jump"]), 1.40), "크기 상한 140퍼센트"):
		return
	controls.adjust_selected_control_size(-2.0)
	resized = controls.control_layout_snapshot()
	if not _assert_true(is_equal_approx(float((resized["scales"] as Dictionary)[&"jump"]), 0.70), "크기 하한 70퍼센트"):
		return
	controls.set_control_opacity(0.10)
	if not _assert_true(is_equal_approx(float(controls.control_layout_snapshot()["opacity"]), 0.30), "불투명도 하한 30퍼센트"):
		return
	controls.set_control_opacity(1.50)
	if not _assert_true(is_equal_approx(float(controls.control_layout_snapshot()["opacity"]), 1.00), "불투명도 상한 100퍼센트"):
		return

	var centers: Dictionary = controls.control_layout_snapshot()["centers"]
	controls.set_control_center_normalized(&"skill_1", centers[&"skill_2"])
	var invalid: Dictionary = controls.control_layout_snapshot()
	if not _assert_true(not bool(invalid["valid"]), "30퍼센트 이상 겹침 감지"):
		return
	if not _assert_true(not controls.apply_layout_editor(), "잘못된 배치 적용 차단"):
		return
	if not _assert_equal(controls.current_screen_mode(), 3, "적용 차단 후 편집 유지"):
		return

	controls.reset_layout_editor()
	if not _assert_true(bool(controls.control_layout_snapshot()["valid"]), "초기 배치 유효"):
		return
	if not _assert_true(controls.apply_layout_editor(), "유효 배치 적용"):
		return
	if not _assert_equal(controls.current_screen_mode(), 2, "적용 후 메인 복귀"):
		return

	controls.open_layout_editor()
	var before_cancel: Dictionary = controls.control_layout_snapshot()["centers"]
	controls.set_control_center_normalized(&"jump", Vector2(0.55, 0.72))
	controls.cancel_layout_editor()
	controls.open_layout_editor()
	var after_cancel: Dictionary = controls.control_layout_snapshot()["centers"]
	if not _assert_equal(after_cancel[&"jump"], before_cancel[&"jump"], "취소 시 원래 배치 복구"):
		return

	print("CP-401 runtime test: OK")
	quit(0)


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
