extends SceneTree

const SANDBOX_SCENE := preload("res://scenes/movement/ground_movement_sandbox.tscn")
const TEST_RECORD_PATH := "user://cp406_runtime_records.jsonl"
const TEST_LAYOUT_PATH := "user://cp406_runtime_layout.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_files()
	var first := SANDBOX_SCENE.instantiate()
	first.get_node("RecoveryOrbController").drop_chance = 0.0
	(first.get_node("StageRunner") as PrototypeStageRunner).stage_limit = 1
	root.add_child(first)
	var controls := first.get_node("CanvasLayer/GroundMovementControls") as Control
	var recorder := first.get_node("LocalTestRecorder") as LocalTestRecorder
	await process_frame

	if not _assert_safe_ratio(controls, Vector2(1280.0, 720.0), "16:9 안전 영역"):
		return
	if not _assert_safe_ratio(controls, Vector2(2400.0, 1080.0), "20:9 안전 영역"):
		return

	recorder.configure_record_path_for_test(TEST_RECORD_PATH)
	recorder.clear_records()
	for run_index in 10:
		recorder.start_run()
		var completion_s := 180.0 - float(run_index)
		recorder.record_stage_metrics(_completed_metrics(completion_s))
	var summary: Dictionary = recorder.summary_snapshot()
	if not _assert_equal(int(summary["completed_run_count"]), 10, "치명적 오류 없는 10회 완주 집계"):
		return
	if not _assert_true(is_equal_approx(float(summary["best_completion_s"]), 171.0), "10회 중 최고 기록"):
		return

	controls.configure_layout_store_path_for_test(TEST_LAYOUT_PATH)
	controls.open_layout_editor()
	controls.set_control_opacity(0.72)
	if not _assert_true(controls.apply_layout_editor(), "조작 설정 저장"):
		return
	controls.advance_android_validation_time_for_test(20.0 * 60.0)
	controls.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	controls.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	var validation: Dictionary = controls.android_validation_snapshot()
	if not _assert_true(bool(validation["continuous_20m_reached"]), "20분 연속 실행 진단"):
		return
	if not _assert_true(bool(validation["background_resume_pass"]), "백그라운드 복귀 진단"):
		return
	if not _assert_true(bool(validation["ten_runs_reached"]), "10회 완주 진단"):
		return

	first.queue_free()
	await process_frame
	var second := SANDBOX_SCENE.instantiate()
	second.get_node("RecoveryOrbController").drop_chance = 0.0
	(second.get_node("StageRunner") as PrototypeStageRunner).stage_limit = 1
	root.add_child(second)
	var second_controls := second.get_node("CanvasLayer/GroundMovementControls") as Control
	var second_recorder := second.get_node("LocalTestRecorder") as LocalTestRecorder
	await process_frame
	second_controls.configure_layout_store_path_for_test(TEST_LAYOUT_PATH)
	second_controls.reload_control_layout_from_store()
	if not _assert_true(is_equal_approx(float(second_controls.control_layout_snapshot()["opacity"]), 0.72), "재실행 후 조작 설정 유지"):
		return
	second_recorder.configure_record_path_for_test(TEST_RECORD_PATH)
	var restored: Dictionary = second_recorder.summary_snapshot()
	if not _assert_equal(int(restored["completed_run_count"]), 10, "재실행 후 10회 완주 유지"):
		return
	if not _assert_true(is_equal_approx(float(restored["best_completion_s"]), 171.0), "재실행 후 최고 기록 유지"):
		return

	_remove_test_files()
	print("CP-406 runtime test: OK")
	quit(0)


func _assert_safe_ratio(controls: Control, viewport_size: Vector2, label: String) -> bool:
	controls.size = viewport_size
	controls.notification(Control.NOTIFICATION_RESIZED)
	var validation: Dictionary = controls.android_validation_snapshot()
	if not _assert_true(bool(validation["safe_area_pass"]), label):
		return false
	var safe: Rect2 = validation["safe_area"]
	if not _assert_true(safe.size.x > 0.0 and safe.size.y > 0.0, "%s 크기" % label):
		return false
	return true


func _completed_metrics(completion_s: float) -> Dictionary:
	var section_s := completion_s / 5.0
	return {
		"stage_complete": true,
		"stage_elapsed_s": completion_s,
		"stage_target_s": 180.0,
		"stage_actual_times": [section_s, section_s, section_s, section_s, section_s],
	}


func _remove_test_files() -> void:
	for path in [TEST_RECORD_PATH, TEST_LAYOUT_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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
