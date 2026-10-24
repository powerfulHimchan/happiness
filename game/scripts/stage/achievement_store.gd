class_name AchievementStore
extends RefCounted

## Separate append-only ledger. Successful gameplay saves never depend on this ledger.
var save_path := "user://permanent_achievements.jsonl"

static func valid_progress(value: Variant) -> bool:
	if not value is Dictionary or value.size() > PermanentAchievements.DEFINITIONS.size(): return false
	for id in value:
		if not id is String: return false
		var item := PermanentAchievements.definition(id)
		var amount: Variant = value[id]
		if item.is_empty() or not (amount is int or amount is float): return false
		if not is_finite(float(amount)) or float(amount) != floorf(float(amount)) or float(amount) < 0 or float(amount) > int(item.target): return false
	return true

func snapshot() -> Dictionary:
	var state := {"progress":{}, "title":""}
	if not FileAccess.file_exists(save_path): return state
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null: return state
	while not file.eof_reached():
		var line := file.get_line()
		if line.length() > 16384: continue
		var parser := JSON.new()
		if parser.parse(line) != OK: continue
		var envelope: Variant = parser.data
		if not envelope is Dictionary or not (envelope.get("version") is int or envelope.get("version") is float) or envelope.get("version") != 1 or not envelope.get("payload") is String or not envelope.get("sha256") is String: continue
		if envelope.sha256 != String(envelope.payload).sha256_text() or parser.parse(envelope.payload) != OK: continue
		var event: Variant = parser.data
		if not event is Dictionary: continue
		if event.get("event") == "progress" and valid_progress(event.get("progress")):
			for id in event.progress: state.progress[id] = maxi(int(state.progress.get(id, 0)), int(event.progress[id]))
		elif event.get("event") == "title" and event.get("id") is String:
			if event.id == "" or PermanentAchievements.earned(state, event.id): state.title = event.id
	file.close()
	return state

func observe(progress: Dictionary) -> Error:
	if not valid_progress(progress): return ERR_INVALID_DATA
	var current := snapshot()
	var changes := {}
	for id in progress:
		if int(progress[id]) > int(current.progress.get(id, 0)): changes[id] = int(progress[id])
	return OK if changes.is_empty() else _append({"event":"progress", "progress":changes})

func select_title(id: String) -> Error:
	var state := snapshot()
	if id != "" and not PermanentAchievements.earned(state, id): return ERR_INVALID_DATA
	return OK if id == state.title else _append({"event":"title", "id":id})

func _append(event: Dictionary) -> Error:
	var file := FileAccess.open(save_path, FileAccess.READ_WRITE if FileAccess.file_exists(save_path) else FileAccess.WRITE_READ)
	if file == null: return FileAccess.get_open_error()
	file.seek_end()
	if file.get_position() > 0:
		file.seek(file.get_position() - 1)
		var last := file.get_8()
		file.seek_end()
		if last != 10: file.store_string("\n")
	var payload := JSON.stringify(event)
	file.store_line(JSON.stringify({"version":1, "payload":payload, "sha256":payload.sha256_text()}))
	file.flush()
	var error := file.get_error()
	file.close()
	return error
