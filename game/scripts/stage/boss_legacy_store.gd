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


func claim(run_id: String, enabled: bool) -> Dictionary:
	if run_id.is_empty():
		return {"error": ERR_INVALID_DATA, "state": {}}
	var pending := pending_reward()
	if pending.is_empty():
		return {"error": OK, "state": {}}
	var error := _append({"event": "claim", "source": pending.source, "run_id": run_id, "enabled": enabled})
	return {"error": error, "state": {"choice": pending.choice, "source_run": pending.source, "run_id": run_id, "rescue_used": false, "assisted_stages": []} if error == OK and enabled else {}}


func restore_active(state: Dictionary) -> Dictionary:
	if state.is_empty():
		return {}
	var restored := state.duplicate(true)
	var usage: Dictionary = _load().usage.get(state.run_id, {})
	restored.rescue_used = state.rescue_used or usage.get("rescue", false)
	for stage in usage.get("stages", []):
		if stage not in restored.assisted_stages:
			restored.assisted_stages.append(stage)
	return restored


func spend_rescue(state: Dictionary) -> bool:
	if state.is_empty() or state.choice != "rescue" or restore_active(state).rescue_used:
		return false
	if _append({"event": "rescue", "run_id": state.run_id}) != OK:
		return false
	state.rescue_used = true
	return true


func spend_assist(state: Dictionary, stage: int) -> bool:
	if state.is_empty() or state.choice != "rescue" or stage in restore_active(state).assisted_stages:
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
	var result := {"pending": {}, "rewards": {}, "claims": {}, "usage": {}}
	if not FileAccess.file_exists(save_path):
		return result
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return result
	while not file.eof_reached():
		var envelope: Variant = JSON.parse_string(file.get_line())
		if not envelope is Dictionary or envelope.get("version") != 1 or not envelope.get("payload") is String or envelope.get("sha256") != String(envelope.payload).sha256_text():
			continue
		var event: Variant = JSON.parse_string(envelope.payload)
		if not event is Dictionary:
			continue
		var source: String = event.get("source", "") if event.get("source", "") is String else ""
		var run_id: String = event.get("run_id", "") if event.get("run_id", "") is String else ""
		match event.get("event"):
			"reward":
				if not source.is_empty() and event.get("choice") in ["rescue", "destroy"] and not result.rewards.has(source):
					result.rewards[source] = event.choice
					result.pending = {"source": source, "choice": event.choice}
			"claim":
				if not run_id.is_empty() and result.pending.get("source") == source and event.get("enabled") is bool:
					result.claims[run_id] = source
					result.pending = {}
			"rescue", "assist":
				if not result.claims.has(run_id):
					continue
				var usage: Dictionary = result.usage.get(run_id, {"rescue": false, "stages": []})
				if event.event == "rescue":
					usage.rescue = true
				elif event.get("stage") in [1, 2, 3] and event.stage not in usage.stages:
					usage.stages.append(event.stage)
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
		if stage not in [1, 2, 3] or stage in seen:
			return false
		seen.append(stage)
	return state.choice == "rescue" or (not state.rescue_used and seen.is_empty())


static func description(choice: String) -> String:
	match choice:
		"rescue": return "기사 동행 · 체력 +10 · 정예 지원 · 위기 회복 1회"
		"destroy": return "태엽핵 · 주는 피해 +10% · 받는 전투 피해 +10%"
	return "다음 도전 보상 없음"
