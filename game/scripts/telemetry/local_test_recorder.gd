class_name LocalTestRecorder
extends Node

## CP-405 로컬 기기 테스트 기록을 JSON Lines로 즉시 저장한다.
## 각 이벤트를 한 줄씩 flush해 비정상 종료 뒤에도 완성된 이전 줄을 복구한다.

signal summary_changed(summary: Dictionary)

const SCHEMA_VERSION := 1
const DEFAULT_RECORD_PATH := "user://local_test_records.jsonl"
const SECTION_NAMES: Array[String] = ["전진 1", "웨이브 1", "전진 2", "웨이브 2", "정예"]

var record_path: String = DEFAULT_RECORD_PATH
var _summary: Dictionary = {}
var _active_run_id: String = ""
var _recorded_section_count: int = 0
var _active_run_completed: bool = false
var _run_sequence: int = 0
var _recorded_stage_number: int = 1
var _recorded_stage_completed: bool = false


func _ready() -> void:
	_reload_summary()
	_append_event("app_started", {})


func start_run(run_id: String = "") -> void:
	_run_sequence += 1
	_active_run_id = "%d-%d-%d" % [
		int(Time.get_unix_time_from_system()),
		Time.get_ticks_msec(),
		_run_sequence,
	]
	if not run_id.is_empty():
		_active_run_id = run_id
	_recorded_section_count = 0
	_recorded_stage_number = 1
	_recorded_stage_completed = false
	_active_run_completed = false
	_append_event("run_started", {
		"run_id": _active_run_id,
	})
	_append_section_started(0)


func checkpoint_snapshot() -> Dictionary:
	return {"id": _active_run_id}


func restore_checkpoint(state: Dictionary, stage_number: int) -> void:
	_active_run_id = String(state.id)
	_recorded_stage_number = stage_number
	_recorded_section_count = SECTION_NAMES.size()
	_recorded_stage_completed = true
	_active_run_completed = false
	_append_event("run_resumed", {"run_id": _active_run_id, "stage_number": stage_number})


func has_completed_run(run_id: String) -> bool:
	for event in _read_valid_events():
		if event.get("event") == "run_completed" and event.get("run_id") == run_id:
			return true
	return false


func record_stage_metrics(metrics: Dictionary) -> void:
	if _active_run_id.is_empty() or _active_run_completed:
		return
	var actual_times: Array = metrics.get("stage_actual_times", [])
	var stage_number := int(metrics.get("run_stage_number", 1))
	if stage_number != _recorded_stage_number:
		_recorded_stage_number = stage_number
		_recorded_section_count = 0
		_recorded_stage_completed = false
		_append_event("stage_started", {"run_id": _active_run_id, "stage_number": stage_number, "route": metrics.get("run_route_id", "meadow")})
		_append_section_started(0)
	while _recorded_section_count < actual_times.size():
		var section_index := _recorded_section_count
		_append_event("section_completed", {
			"run_id": _active_run_id,
			"section_index": section_index + 1,
			"stage_number": stage_number,
			"section_name": "보스" if section_index == 4 and not String(metrics.get("boss_name", "")).is_empty() else SECTION_NAMES[section_index],
			"duration_s": float(actual_times[section_index]),
			"stage_elapsed_s": float(metrics.get("stage_elapsed_s", 0.0)),
		})
		_recorded_section_count += 1
		if _recorded_section_count < SECTION_NAMES.size() \
		and not bool(metrics.get("stage_complete", false)):
			_append_section_started(_recorded_section_count)

	if bool(metrics.get("stage_complete", false)) and not _recorded_stage_completed:
		_recorded_stage_completed = true
		_append_event("stage_completed", {"run_id": _active_run_id, "stage_number": stage_number, "duration_s": metrics.get("stage_elapsed_s", 0.0), "route": metrics.get("run_route_id", "meadow")})
	if bool(metrics.get("run_complete", metrics.get("stage_complete", false))):
		_active_run_completed = _append_event("run_completed", {
			"run_id": _active_run_id,
			"completion_s": float(metrics.get("run_elapsed_s", metrics.get("stage_elapsed_s", 0.0))),
			"target_s": float(metrics.get("stage_target_s", 180.0)) * int(metrics.get("run_stage_count", 1)),
			"stage_count": int(metrics.get("run_stage_count", 1)),
			"stage_history": metrics.get("run_stage_history", []).duplicate(true),
			"section_times": actual_times.duplicate(),
			"boss_choice": String(metrics.get("boss_choice", "")),
			"boss_name": String(metrics.get("boss_name", "")),
		})


func clear_records() -> void:
	var absolute_path := ProjectSettings.globalize_path(record_path)
	if FileAccess.file_exists(record_path):
		DirAccess.remove_absolute(absolute_path)
	_active_run_id = ""
	_recorded_section_count = 0
	_active_run_completed = false
	_summary = _empty_summary()
	summary_changed.emit(summary_snapshot())


func summary_snapshot() -> Dictionary:
	return _summary.duplicate(true)


func configure_record_path_for_test(path: String) -> void:
	record_path = path
	_active_run_id = ""
	_recorded_section_count = 0
	_active_run_completed = false
	_reload_summary()


func reload_records_for_test() -> void:
	_reload_summary()


func _append_section_started(section_index: int) -> void:
	_append_event("section_started", {
		"run_id": _active_run_id,
		"section_index": section_index + 1,
		"stage_number": _recorded_stage_number,
		"section_name": SECTION_NAMES[section_index],
	})


func _append_event(event_name: String, fields: Dictionary) -> bool:
	var event := {
		"schema_version": SCHEMA_VERSION,
		"event": event_name,
		"unix_time": int(Time.get_unix_time_from_system()),
	}
	for key in fields:
		event[key] = fields[key]
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(record_path) else FileAccess.WRITE_READ
	var file := FileAccess.open(record_path, mode)
	if file == null:
		push_error("로컬 테스트 기록 파일을 열 수 없습니다: %s" % record_path)
		return false
	file.seek_end()
	var end_position := file.get_position()
	if end_position > 0:
		file.seek(end_position - 1)
		var last_byte := file.get_8()
		file.seek_end()
		if last_byte != 10:
			file.store_string("\n")
	file.store_line(JSON.stringify(event))
	file.flush()
	var succeeded := file.get_error() == OK
	file.close()
	_reload_summary()
	return succeeded


func _reload_summary() -> void:
	var events := _read_valid_events()
	var completed_times: Array[float] = []
	var run_ids: Dictionary = {}
	var completed_run_ids: Dictionary = {}
	var section_completion_count := 0
	var last_event := "기록 없음"
	var completion_by_stage_count: Dictionary = {}
	var boss_rescue_count := 0
	var boss_destroy_count := 0
	for event in events:
		var event_name := String(event.get("event", ""))
		var run_id := String(event.get("run_id", ""))
		if event_name == "run_started" and not run_id.is_empty():
			run_ids[run_id] = true
		elif event_name == "section_completed":
			section_completion_count += 1
		elif event_name == "run_completed" and not run_id.is_empty():
			if completed_run_ids.has(run_id):
				continue
			completed_run_ids[run_id] = true
			if event.get("boss_choice") == "rescue":
				boss_rescue_count += 1
			elif event.get("boss_choice") == "destroy":
				boss_destroy_count += 1
			var completion := float(event.get("completion_s", 0.0))
			completed_times.append(completion)
			var count_key := str(int(event.get("stage_count", 1)))
			var stats: Dictionary = completion_by_stage_count.get(count_key, {"completed_run_count": 0, "best_completion_s": 0.0, "total_completion_s": 0.0, "average_completion_s": 0.0})
			stats["completed_run_count"] += 1
			stats["total_completion_s"] += completion
			stats["average_completion_s"] = float(stats["total_completion_s"]) / int(stats["completed_run_count"])
			if float(stats["best_completion_s"]) <= 0.0 or completion < float(stats["best_completion_s"]):
				stats["best_completion_s"] = completion
			completion_by_stage_count[count_key] = stats
		last_event = event_name

	var total_completion_s := 0.0
	var best_completion_s := 0.0
	for completion_s in completed_times:
		total_completion_s += completion_s
		if best_completion_s <= 0.0 or completion_s < best_completion_s:
			best_completion_s = completion_s
	_summary = {
		"completion_by_stage_count": completion_by_stage_count,
		"boss_rescue_count": boss_rescue_count,
		"boss_destroy_count": boss_destroy_count,
		"event_count": events.size(),
		"run_count": run_ids.size(),
		"completed_run_count": completed_run_ids.size(),
		"incomplete_run_count": maxi(0, run_ids.size() - completed_run_ids.size()),
		"section_completion_count": section_completion_count,
		"best_completion_s": best_completion_s,
		"average_completion_s": total_completion_s / float(completed_times.size()) if not completed_times.is_empty() else 0.0,
		"latest_completion_s": completed_times[-1] if not completed_times.is_empty() else 0.0,
		"last_event": last_event,
		"record_path": record_path,
	}
	summary_changed.emit(summary_snapshot())


func _read_valid_events() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not FileAccess.file_exists(record_path):
		return events
	var file := FileAccess.open(record_path, FileAccess.READ)
	if file == null:
		return events
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var json := JSON.new()
		if json.parse(line) != OK:
			continue
		var parsed: Variant = json.data
		if parsed is Dictionary and int(parsed.get("schema_version", 0)) == SCHEMA_VERSION:
			events.append(parsed)
	return events


func _empty_summary() -> Dictionary:
	return {
		"completion_by_stage_count": {},
		"boss_rescue_count": 0,
		"boss_destroy_count": 0,
		"event_count": 0,
		"run_count": 0,
		"completed_run_count": 0,
		"incomplete_run_count": 0,
		"section_completion_count": 0,
		"best_completion_s": 0.0,
		"average_completion_s": 0.0,
		"latest_completion_s": 0.0,
		"last_event": "기록 없음",
		"record_path": record_path,
	}
