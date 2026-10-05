class_name AbilityDiscoveryStore
extends RefCounted

## 실제 선택한 능력을 도전 저장·보스 보상·진단 기록과 독립적으로 보존한다.
var save_path := "user://ability_discoveries.jsonl"

func snapshot() -> Dictionary:
	var found := {}
	if not FileAccess.file_exists(save_path): return found
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null: return found
	while not file.eof_reached():
		var parser := JSON.new()
		if parser.parse(file.get_line()) != OK: continue
		var envelope: Variant = parser.data
		if not envelope is Dictionary or envelope.get("version") != 1 or not envelope.get("payload") is String or envelope.get("sha256") != String(envelope.payload).sha256_text(): continue
		if parser.parse(envelope.payload) != OK: continue
		var event: Variant = parser.data
		if not event is Dictionary or event.get("event") != "abilities" or not PrototypeAbilityCodex.valid_ids(event.get("ids")): continue
		for id in event.ids: found[id] = true
	file.close()
	return found

func discover(ids: Variant) -> Error:
	if not PrototypeAbilityCodex.valid_ids(ids): return ERR_INVALID_DATA
	var found := snapshot()
	var missing: Array[String] = []
	for id in ids:
		if not found.has(id) and id not in missing: missing.append(id)
	if missing.is_empty(): return OK
	return _append({"event": "abilities", "ids": missing})

func _append(event: Dictionary) -> Error:
	var file := FileAccess.open(save_path, FileAccess.READ_WRITE if FileAccess.file_exists(save_path) else FileAccess.WRITE_READ)
	if file == null: return FileAccess.get_open_error()
	file.seek_end()
	var end := file.get_position()
	if end > 0:
		file.seek(end - 1)
		var last := file.get_8()
		file.seek_end()
		if last != 10: file.store_string("\n")
	var payload := JSON.stringify(event)
	file.store_line(JSON.stringify({"version": 1, "payload": payload, "sha256": payload.sha256_text()}))
	file.flush()
	var error := file.get_error()
	file.close()
	return error
