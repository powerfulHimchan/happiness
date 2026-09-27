extends SceneTree

const SANDBOX_SCENE := preload("res://scenes/movement/ground_movement_sandbox.tscn")
const TEST_SAVE_PATH := "user://cp402_runtime_test.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_save()
	var first := SANDBOX_SCENE.instantiate()
	root.add_child(first)
	var first_controls := first.get_node("CanvasLayer/GroundMovementControls") as Control
	await process_frame
	first_controls.configure_layout_store_path_for_test(TEST_SAVE_PATH)
	first_controls.open_layout_editor()
	first_controls.select_control_preset("left")
	var left_snapshot: Dictionary = first_controls.control_layout_snapshot()
	var left_centers: Dictionary = left_snapshot["centers"]
	var left_move: Vector2 = left_centers[&"move"]
	var left_jump: Vector2 = left_centers[&"jump"]
	if not _assert_true(left_move.x > 0.5, "왼손 프리셋 이동 패드 오른쪽"):
		return
	if not _assert_true(left_jump.x < 0.5, "왼손 프리셋 액션 버튼 왼쪽"):
		return
	if not _assert_true(first_controls.apply_layout_editor(), "왼손 프리셋 저장"):
		return
	if not _assert_true(FileAccess.file_exists(TEST_SAVE_PATH), "버전 JSON 파일 생성"):
		return

	first.queue_free()
	await process_frame
	var second := SANDBOX_SCENE.instantiate()
	root.add_child(second)
	var second_controls := second.get_node("CanvasLayer/GroundMovementControls") as Control
	await process_frame
	second_controls.configure_layout_store_path_for_test(TEST_SAVE_PATH)
	second_controls.reload_control_layout_from_store()
	var reloaded_left: Dictionary = second_controls.control_layout_snapshot()
	if not _assert_equal(String(reloaded_left["active_preset"]), "left", "재실행 후 왼손 프리셋 유지"):
		return
	var reloaded_centers: Dictionary = reloaded_left["centers"]
	if not _assert_equal(reloaded_centers[&"move"], left_centers[&"move"], "재실행 후 배치 좌표 유지"):
		return

	second_controls.open_layout_editor()
	second_controls.select_control_preset("default")
	second_controls.set_control_center_normalized(&"jump", Vector2(0.55, 0.90))
	second_controls.set_control_center_normalized(&"skill_1", Vector2(0.45, 0.60))
	second_controls.select_layout_control(&"skill_1")
	second_controls.adjust_selected_control_size(0.20)
	second_controls.set_control_opacity(0.70)
	var custom_before_save: Dictionary = second_controls.control_layout_snapshot()
	if not _assert_equal(String(custom_before_save["active_preset"]), "custom", "프리셋 수정 시 사용자 설정 전환"):
		return
	if not _assert_true(second_controls.apply_layout_editor(), "사용자 설정 저장"):
		return

	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var payload: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	if not _assert_equal(int(payload["schema_version"]), ControlLayoutStore.SCHEMA_VERSION, "저장 스키마 버전"):
		return
	var active_layout: Dictionary = payload["active_layout"]
	var elements: Dictionary = active_layout["elements"]
	var jump_element: Dictionary = elements["jump"]
	jump_element["center"] = "broken"
	elements["jump"] = jump_element
	file = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()

	second.queue_free()
	await process_frame
	var third := SANDBOX_SCENE.instantiate()
	root.add_child(third)
	var third_controls := third.get_node("CanvasLayer/GroundMovementControls") as Control
	await process_frame
	third_controls.configure_layout_store_path_for_test(TEST_SAVE_PATH)
	third_controls.reload_control_layout_from_store()
	var recovered: Dictionary = third_controls.control_layout_snapshot()
	var recovered_centers: Dictionary = recovered["centers"]
	if not _assert_equal(recovered_centers[&"jump"], Vector2(0.925, 0.815), "손상된 점프 요소만 기본값 복구"):
		return
	if not _assert_equal(recovered_centers[&"skill_1"], Vector2(0.45, 0.60), "정상 요소 사용자 좌표 유지"):
		return
	if not _assert_true(is_equal_approx(float((recovered["scales"] as Dictionary)[&"skill_1"]), 1.20), "정상 요소 크기 유지"):
		return
	if not _assert_true(is_equal_approx(float(recovered["opacity"]), 0.70), "사용자 불투명도 유지"):
		return
	if not _assert_true(String(recovered["store_message"]).contains("복구"), "요소 복구 안내"):
		return

	_remove_test_save()
	print("CP-402 runtime test: OK")
	quit(0)


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
