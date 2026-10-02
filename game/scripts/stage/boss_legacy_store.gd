class_name BossLegacyStore
extends RefCounted

## 보상·소비를 별도 체크섬 저널로 보존한다. 중간 저장/테스트 기록 초기화와 독립적이다.
var save_path := "user://boss_legacy.jsonl"


func pending_reward() -> Dictionary:
	return _load().pending.duplicate(true)


func grant(source: String, choice: String) -> Error:
	if source.is_empty() or choice not in ["rescue", "destroy"]:
		return ERR_INVALID_DATA
	var data := _load()
	if data.rewards.has(source):
		return OK if data.rewards[source] == choice else ERR_INVALID_DATA
	return _append({"event": "reward", "source": source, "choice": choice})


func progress_snapshot() -> Dictionary:
	var data := _load()
	return {"pending": data.pending.duplicate(true), "unlocked": data.unlocked.duplicate(), "selected_memory": data.selected_memory, "blueprints": data.blueprints.duplicate(), "jobs": data.jobs.duplicate()}


func claim(run_id: String, enabled: bool, memory_id: String = "") -> Dictionary:
	var data := _load()
	if run_id.is_empty() or not PrototypeMemoryAbilities.available(memory_id, data.unlocked):
		return {"error": ERR_INVALID_DATA, "state": {}, "memory_id": ""}
	var pending: Dictionary = data.pending
	if pending.is_empty():
		var error: Error = OK
		if memory_id != data.selected_memory:
			error = _append({"event": "loadout", "run_id": run_id, "memory_id": memory_id})
		return {"error": error, "state": {}, "memory_id": memory_id}
	# 보상 소비와 영구 기억 선택은 하나의 정상 줄로 함께 확정한다.
	var error := _append({"event": "claim", "source": pending.source, "run_id": run_id, "enabled": enabled, "memory_id": memory_id})
	return {"error": error, "state": {"choice": pending.choice, "source_run": pending.source, "run_id": run_id, "rescue_used": false, "assisted_stages": []} if error == OK and enabled else {}, "memory_id": memory_id}


func restore_active(state: Dictionary) -> Dictionary:
	if state.is_empty():
		return {}
	var restored := state.duplicate(true)
	restored.assisted_stages = []
	for stage in state.assisted_stages:
		restored.assisted_stages.append(int(stage))
	var usage: Dictionary = _load().usage.get(state.run_id, {})
	restored.rescue_used = state.rescue_used or usage.get("rescue", false)
	for stage in usage.get("stages", []):
		if stage not in restored.assisted_stages:
			restored.assisted_stages.append(stage)
	return restored


func spend_rescue(state: Dictionary) -> bool:
	if state.is_empty() or state.choice != "rescue" or state.rescue_used or restore_active(state).rescue_used:
		return false
	if _append({"event": "rescue", "run_id": state.run_id}) != OK:
		return false
	state.rescue_used = true
	return true


func spend_assist(state: Dictionary, stage: int) -> bool:
	if state.is_empty() or state.choice != "rescue" or stage in state.assisted_stages or stage in restore_active(state).assisted_stages:
		return false
	if _append({"event": "assist", "run_id": state.run_id, "stage": stage}) != OK:
		return false
	state.assisted_stages.append(stage)
	return true


func _append(event: Dictionary) -> Error:
	var file := FileAccess.open(save_path, FileAccess.READ_WRITE if FileAccess.file_exists(save_path) else FileAccess.WRITE_READ)
	if file == null:
		return FileAccess.get_open_error()
	file.seek_end()
	var end := file.get_position()
	if end > 0:
		file.seek(end - 1)
		var last := file.get_8()
		file.seek_end()
		if last != 10:
			file.store_string("\n")
	var payload := JSON.stringify(event)
	file.store_line(JSON.stringify({"version": 1, "payload": payload, "sha256": payload.sha256_text()}))
	file.flush()
	var error := file.get_error()
	file.close()
	return error


func _load() -> Dictionary:
	var result := {"pending": {}, "rewards": {}, "claims": {}, "usage": {}, "unlocked": {}, "selected_memory": "", "blueprints": {}, "jobs": {}}
	if not FileAccess.file_exists(save_path):
		return result
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return result
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parser := JSON.new()
		if parser.parse(line) != OK:
			continue
		var envelope: Variant = parser.data
		if not envelope is Dictionary or envelope.get("version") != 1 or not envelope.get("payload") is String or envelope.get("sha256") != String(envelope.payload).sha256_text():
			continue
		if parser.parse(envelope.payload) != OK:
			continue
		var event: Variant = parser.data
		if not event is Dictionary:
			continue
		var source: String = event.get("source", "") if event.get("source", "") is String else ""
		var run_id: String = event.get("run_id", "") if event.get("run_id", "") is String else ""
		match event.get("event"):
			"job":
				if event.get("job_id") is String and not PrototypeJobProgress.profile(event.job_id).is_empty():
					result.jobs[event.job_id] = true
			"reward":
				if not source.is_empty() and event.get("choice") in ["rescue", "destroy"] and not result.rewards.has(source):
					result.rewards[source] = event.choice
					result.unlocked[PrototypeMemoryAbilities.CHOICE_IDS[event.choice]] = true
					if event.choice == "destroy":
						for blueprint in PrototypeWeaponRewards.BLUEPRINTS:
							result.blueprints[blueprint] = true
					result.pending = {"source": source, "choice": event.choice}
			"claim":
				if not run_id.is_empty() and result.pending.get("source") == source and event.get("enabled") is bool:
					if event.has("memory_id"):
						if not event.memory_id is String or not PrototypeMemoryAbilities.available(event.memory_id, result.unlocked):
							continue
						result.selected_memory = event.memory_id
					result.claims[run_id] = source
					result.pending = {}
			"loadout":
				if not run_id.is_empty() and event.get("memory_id") is String and PrototypeMemoryAbilities.available(event.memory_id, result.unlocked):
					result.selected_memory = event.memory_id
			"rescue", "assist":
				if not result.claims.has(run_id):
					continue
				var usage: Dictionary = result.usage.get(run_id, {"rescue": false, "stages": []})
				if event.event == "rescue":
					usage.rescue = true
				elif _valid_stage(event.get("stage")) and int(event.stage) not in usage.stages:
					usage.stages.append(int(event.stage))
				result.usage[run_id] = usage
	file.close()
	return result


static func valid_active(state: Dictionary, run_id: String) -> bool:
	if state.is_empty():
		return true
	if state.get("choice") not in ["rescue", "destroy"] or not state.get("source_run") is String or String(state.source_run).is_empty() or state.source_run == run_id or state.get("run_id") != run_id or not state.get("rescue_used") is bool or not state.get("assisted_stages") is Array:
		return false
	var seen: Array = []
	for stage in state.assisted_stages:
		if not _valid_stage(stage) or int(stage) in seen:
			return false
		seen.append(int(stage))
	return state.choice == "rescue" or (not state.rescue_used and seen.is_empty())


static func _valid_stage(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= 1 and float(value) <= 3


static func description(choice: String) -> String:
	match choice:
		"rescue": return "기사 동행 · 체력 +10 · 정예 지원 · 위기 회복 1회"
		"destroy": return "태엽핵 · 피해/피격 +10% · 2스테이지 위험 길 개방"
	return "다음 도전 보상 없음"


func discover_job(id: String) -> Error:
	if PrototypeJobProgress.profile(id).is_empty():
		return ERR_INVALID_DATA
	if _load().jobs.has(id):
		return OK
	return _append({"event": "job", "job_id": id})
