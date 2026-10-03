extends SceneTree

const SANDBOX_SCENE := preload("res://scenes/movement/ground_movement_sandbox.tscn")
const TEST_RECORD_PATH := "user://cp405_runtime_records.jsonl"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_record()
	var sandbox := SANDBOX_SCENE.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	(sandbox.get_node("StageRunner") as PrototypeStageRunner).stage_limit = 1
	root.add_child(sandbox)
	var controls := sandbox.get_node("CanvasLayer/GroundMovementControls") as Control
	var recorder := sandbox.get_node("LocalTestRecorder") as LocalTestRecorder
	await process_frame

	recorder.configure_record_path_for_test(TEST_RECORD_PATH)
	recorder.clear_records()
	controls.begin_stage_from_main()
	if not _assert_true(FileAccess.file_exists(TEST_RECORD_PATH), "실행 시작 즉시 JSON Lines 생성"):
		return

	var section_times: Array[float] = [38.0, 34.0, 36.0, 41.0, 29.0]
	var cumulative := 0.0
	for index in section_times.size():
		cumulative += section_times[index]
		var metrics := _stage_metrics(
			section_times.slice(0, index + 1),
			cumulative,
			index == section_times.size() - 1
		)
		recorder.record_stage_metrics(metrics)

	var completed: Dictionary = recorder.summary_snapshot()
	if not _assert_equal(int(completed["run_count"]), 1, "한 번의 테스트 실행 집계"):
		return
	if not _assert_equal(int(completed["completed_run_count"]), 1, "완주 횟수 집계"):
		return
	if not _assert_equal(int(completed["section_completion_count"]), 5, "다섯 구간 이벤트 집계"):
		return
	if not _assert_true(is_equal_approx(float(completed["best_completion_s"]), 178.0), "최고 완료 시간 집계"):
		return

	controls.update_stage_metrics(_stage_metrics(section_times, 178.0, true))
	var result: Dictionary = controls.current_result_snapshot()
	var result_records: Dictionary = result.get("record_summary", {})
	if not _assert_equal(int(result_records.get("completed_run_count", 0)), 1, "결과 화면 로컬 기록 집계"):
		return

	recorder.start_run()
	_append_interrupted_line()
	recorder.reload_records_for_test()
	var recovered: Dictionary = recorder.summary_snapshot()
	if not _assert_equal(int(recovered["completed_run_count"]), 1, "중간 종료 뒤 이전 완주 줄 복구"):
		return
	if not _assert_equal(int(recovered["incomplete_run_count"]), 1, "중단된 실행 집계"):
		return
	if not _assert_equal(int(recovered["section_completion_count"]), 5, "손상된 마지막 줄 무시"):
		return
	recorder.start_run()
	var continued: Dictionary = recorder.summary_snapshot()
	if not _assert_equal(int(continued["run_count"]), 3, "손상된 줄 뒤에도 새 실행 기록"):
		return
	if not _assert_equal(int(continued["completed_run_count"]), 1, "새 기록 뒤 이전 완주 유지"):
		return

	controls.test_records_clear_requested.emit()
	if not _assert_true(not FileAccess.file_exists(TEST_RECORD_PATH), "설정의 기록 초기화"):
		return
	if not _assert_equal(int(recorder.summary_snapshot()["event_count"]), 0, "초기화 뒤 집계 비움"):
		return

	_remove_test_record()
	print("CP-405 runtime test: OK")
	quit(0)


func _stage_metrics(times: Array[float], elapsed_s: float, complete: bool) -> Dictionary:
	return {
		"stage_complete": complete,
		"stage_elapsed_s": elapsed_s,
		"stage_target_s": 180.0,
		"stage_actual_times": times.duplicate(),
		"stage_section_index": 5 if complete else times.size() + 1,
		"stage_section_count": 5,
		"stage_section_name": "완료" if complete else "테스트 구간",
		"stage_last_log": "스테이지 완료" if complete else "구간 진행",
	}


func _append_interrupted_line() -> void:
	var file := FileAccess.open(TEST_RECORD_PATH, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string("{\"schema_version\":1,\"event\":\"section_completed\"")
	file.flush()


func _remove_test_record() -> void:
	if FileAccess.file_exists(TEST_RECORD_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_RECORD_PATH))


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
