class_name StoryJournalStore
extends RefCounted

## 영구 수집은 체크섬 줄 저널로 보존하며 도전/테스트 기록과 독립적이다.
var save_path := "user://story_journal.jsonl"

func record_fragments(ids: Array) -> Error:
	if not PrototypeStory.valid_ids(ids): return ERR_INVALID_DATA
	var collected: Dictionary = snapshot().fragments
	var fresh: Array = []
	for id in ids:
		if not collected.has(id): fresh.append(id)
	return OK if fresh.is_empty() else _append({"event": "fragments", "ids": fresh})

func record_rewind(run_id: String) -> Error:
	if run_id.is_empty() or run_id.length() > 256: return ERR_INVALID_DATA
	return OK if snapshot().rewinds.has(run_id) else _append({"event": "rewind", "run_id": run_id})

func record_chronicle(run_id: String, id: String, character: String, ids: Array) -> Error:
	if run_id.is_empty() or run_id.length() > 256 or not PrototypeStory.CHRONICLES.has(id) or not PrototypeCharacters.valid_id(character) or not PrototypeStory.valid_ids(ids): return ERR_INVALID_DATA
	var prior: Dictionary = snapshot().completions
	if prior.has(run_id): return OK if prior[run_id] == {"id": id, "character": character} else ERR_INVALID_DATA
	return _append({"event": "chronicle", "run_id": run_id, "id": id, "character": character, "ids": ids})

func record_ending(run_id: String, id: String, character: String, choice: String) -> Error:
	if not ArrivalEnding.valid_record(id, run_id, character, choice): return ERR_INVALID_DATA
	var record := {"id": id, "character": character, "choice": choice}
	var prior: Dictionary = snapshot().ending_completions
	if prior.has(run_id): return OK if prior[run_id] == record else ERR_INVALID_DATA
	return _append({"event": "ending", "run_id": run_id, "id": id, "character": character, "choice": choice})

func record_secret(id: String) -> Error:
	if id != "clocktower_archive": return ERR_INVALID_DATA
	return OK if snapshot().secrets.has(id) else _append({"event": "secret", "id": id})

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
	file.store_line(JSON.stringify({"version": 1, "payload": payload, "sha256": payload.sha256_text()}))
	file.flush()
	var error := file.get_error()
	file.close()
	return error

func snapshot() -> Dictionary:
	var data := {"fragments": {}, "chronicles": {}, "rewinds": {}, "completions": {}, "rewind_count": 0, "endings": {}, "ending_completions": {}, "secrets": {}}
	if not FileAccess.file_exists(save_path): return data
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null: return data
	while not file.eof_reached():
		var raw := file.get_line()
		if raw.length() > 65536: continue
		var parser := JSON.new()
		if parser.parse(raw) != OK: continue
		var row: Variant = parser.data
		if not row is Dictionary or not (row.get("version") is int or row.get("version") is float) or row.version != 1 or not row.get("payload") is String or not row.get("sha256") is String: continue
		if row.sha256 != String(row.payload).sha256_text() or parser.parse(row.payload) != OK: continue
		var event: Variant = parser.data
		if not event is Dictionary or not event.get("event") is String: continue
		var run_id: String = event.get("run_id", "") if event.get("run_id") is String else ""
		if run_id.length() > 256: continue
		match event.event:
			"secret":
				if event.get("id") == "clocktower_archive": data.secrets.clocktower_archive = true
			"ending":
				if not ArrivalEnding.valid_record(event.get("id"), run_id, event.get("character"), event.get("choice")) or data.ending_completions.has(run_id): continue
				data.ending_completions[run_id] = {"id": event.id, "character": event.character, "choice": event.choice}
				if not data.endings.has(event.id): data.endings[event.id] = {"character": event.character, "choice": event.choice, "run_id": run_id}
			"fragments":
				if PrototypeStory.valid_ids(event.get("ids")):
					for id in event.ids: data.fragments[id] = true
			"rewind":
				if not run_id.is_empty(): data.rewinds[run_id] = true
			"chronicle":
				if run_id.is_empty() or not event.get("id") is String or not PrototypeStory.CHRONICLES.has(event.id) or not PrototypeCharacters.valid_id(event.get("character")) or not PrototypeStory.valid_ids(event.get("ids")) or data.completions.has(run_id): continue
				data.completions[run_id] = {"id": event.id, "character": event.character}
				if not data.chronicles.has(event.id): data.chronicles[event.id] = {"character": event.character, "run_id": run_id}
				for id in event.ids: data.fragments[id] = true
	file.close()
	data.rewind_count = data.rewinds.size()
	return data
