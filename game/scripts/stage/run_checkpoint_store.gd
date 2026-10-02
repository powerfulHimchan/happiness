class_name RunCheckpointStore
extends RefCounted

## GP-105: 검증된 중간 완료 상태만 저장하고 이전 정상 파일로 복구한다.
const VERSION := 1
var save_path := "user://run_checkpoint.json"
var message := ""


func load_checkpoint() -> Dictionary:
	var state := _read(save_path)
	if not state.is_empty():
		message = "중간 저장 · 스테이지 %d 완료" % int(state.stage.number)
		return state
	state = _read(save_path + ".bak")
	if not state.is_empty():
		message = "이전 정상 저장 복구 · 스테이지 %d 완료" % int(state.stage.number)
		return state
	message = "저장 파일을 복구할 수 없습니다 · 새 도전을 시작하세요" if FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak") else ""
	return {}


func save_checkpoint(state: Dictionary) -> Error:
	if not valid_state(state):
		return ERR_INVALID_DATA
	var payload := JSON.stringify(state)
	var error := _write(save_path + ".tmp", JSON.stringify({"version": VERSION, "payload": payload, "sha256": payload.sha256_text()}))
	if error != OK:
		return error
	# 손상된 주 파일로 정상 백업을 덮어쓰지 않는다.
	var previous := _read(save_path)
	# 같은 정예의 보상 확정은 이전 스테이지 백업을 유지한다.
	if not previous.is_empty() and (not state.stage.has("reward_claimed") or previous.stage.number != state.stage.number):
		error = _write(save_path + ".bak", FileAccess.get_file_as_string(save_path))
		if error != OK:
			return error
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path + ".tmp"), ProjectSettings.globalize_path(save_path))
	if error == OK:
		message = "중간 저장 완료 · 앱을 종료해도 이어할 수 있습니다"
	return error


func clear_checkpoint() -> Error:
	var result: Error = OK
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
			if error != OK:
				result = error
	message = "" if result == OK else "중간 저장 삭제 실패"
	return result


func _write(path: String, contents: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(contents)
	file.flush()
	return file.get_error()


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1024 * 1024:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or envelope.get("version") != VERSION or not envelope.get("payload") is String or not envelope.get("sha256") is String:
		return {}
	var payload: String = envelope.payload
	if payload.sha256_text() != envelope.sha256:
		return {}
	if parser.parse(payload) != OK:
		return {}
	var state: Variant = parser.data
	return state if state is Dictionary and valid_state(state) else {}


static func _number(value: Variant, low: float, high: float, integer: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high and (not integer or float(value) == floorf(float(value)))


static func valid_state(state: Dictionary) -> bool:
	for key in ["stage", "growth", "player", "weapons", "ultimate", "recorder"]:
		if not state.get(key) is Dictionary:
			return false
	if state.has("boss_legacy") and (not state.boss_legacy is Dictionary or not BossLegacyStore.valid_active(state.boss_legacy, String(state.recorder.get("id", "")))):
		return false
	if not PrototypeMemoryAbilities.valid_id(state.get("memory_id", "")):
		return false
	var legacy: Dictionary = state.get("boss_legacy", {})
	var stage: Dictionary = state.stage
	if stage.has("reward_claimed") and not stage.reward_claimed is bool:
		return false
	# GP-105~107 저장은 추가 필드가 없으면 일반 등급·보상 완료로 해석한다.
	if state.weapons.has("equipment") and not PrototypeWeaponRewards.valid_equipment(state.weapons.equipment):
		return false
	if state.weapons.has("blueprints") and (not state.weapons.has("equipment") or not PrototypeWeaponRewards.valid_blueprints(state.weapons.blueprints, state.weapons.equipment)):
		return false
	if stage.has("reward_claimed") != state.weapons.has("equipment"):
		return false
	if not _number(stage.get("number"), 1, 3, true) or stage.get("limit") != 3 or not _valid_route(stage.get("route"), int(stage.number), legacy) or not _number(stage.get("elapsed"), 0, 1000000):
		return false
	if stage.has("boss_choice") and (not stage.boss_choice is String or stage.boss_choice not in ["", "rescue", "destroy"]):
		return false
	if int(stage.number) < 3 and stage.get("boss_choice", "") != "":
		return false
	if int(stage.number) == 3 and (not stage.has("boss_choice") or not state.weapons.has("equipment") or stage.get("reward_claimed") != true):
		return false
	if state.weapons.has("equipment"):
		var maximum_grade := int(stage.get("number", 0)) - (0 if stage.reward_claimed else 1)
		for grade in state.weapons.equipment.values():
			if float(grade) > maximum_grade:
				return false
	if not stage.get("history") is Array or stage.history.size() != int(stage.number) or not stage.get("sections") is Array or stage.sections.size() != 5:
		return false
	for index in stage.history.size():
		var entry: Variant = stage.history[index]
		if not entry is Dictionary or entry.get("stage") != index + 1 or not _valid_route(entry.get("route"), index + 1, legacy) or not _number(entry.get("elapsed_s"), 0, 1000000):
			return false
	if int(stage.number) == 3 and stage.history[-1].get("boss_choice") != stage.boss_choice:
		return false
	for duration in stage.sections:
		if not _number(duration, 0, 1000000):
			return false
	if not is_equal_approx(float(stage.elapsed), float(stage.history[-1].elapsed_s)) or stage.route != stage.history[-1].route:
		return false
	for assisted_stage in legacy.get("assisted_stages", []):
		if float(assisted_stage) > float(stage.number):
			return false
	var growth: Dictionary = state.growth
	if not _number(growth.get("level"), 1, 100, true) or not _number(growth.get("xp"), 0, 20 + (int(growth.level) - 1) * 5 - 1, true) or not _number(growth.get("total_xp"), 0, 100000, true) or not _number(growth.get("rerolls"), 0, 1, true) or not growth.get("ranks") is Dictionary or not growth.get("contributions") is Dictionary or not growth.get("recent") is Dictionary or growth.get("job") not in ["", "vanguard", "tracker"]:
		return false
	var spent := 0
	for level_index in range(1, int(growth.level)):
		spent += 20 + (level_index - 1) * 5
	if int(growth.total_xp) != spent + int(growth.xp):
		return false
	var valid_cards: Array[Dictionary] = PrototypeGrowthController.CARDS.duplicate(true)
	valid_cards.append_array(PrototypeJobRewards.cards_for(String(growth.job)))
	var ids: Array[String] = []
	for card in valid_cards:
		ids.append(String(card.id))
	var rank_count := 0
	for id in growth.ranks:
		if id not in ids or not _number(growth.ranks[id], 1, 99, true):
			return false
		rank_count += int(growth.ranks[id])
	if rank_count != int(growth.level) - 1:
		return false
	for source in PrototypeJobProgress.WEIGHTS:
		if not growth.contributions.get(source) is Dictionary:
			return false
		for tag in growth.contributions[source]:
			var cap: float = (10.0 if tag in PrototypeJobProgress.PRIMARY_TAGS else 6.0) * float(PrototypeJobProgress.WEIGHTS[source])
			if tag not in PrototypeJobProgress.TAG_NAMES or not _number(growth.contributions[source][tag], 0, cap + 0.00001):
				return false
	for tag in growth.recent:
		if tag not in PrototypeJobProgress.TAG_NAMES or not _number(growth.recent[tag], 0, 100):
			return false
	var player: Dictionary = state.player
	if not _number(player.get("max_health"), 100, 10000, true) or not _number(player.get("health"), 1, float(player.max_health), true):
		return false
	for key in ["common", "sword", "bow"]:
		if not _number(player.get(key), 0, 100):
			return false
	var ranks: Dictionary = growth.ranks
	var expected_max := 100 + PrototypeMemoryAbilities.health_bonus(String(state.get("memory_id", ""))) + (10 if legacy.get("choice") == "rescue" else 0) + int(ranks.get("vitality", 0)) * 20 + int(ranks.get("recovery", 0)) * 10 + int(ranks.get("vanguard_vigor", 0)) * 30 + int(ranks.get("tracker_breath", 0)) * 20
	var sword_bonus := int(ranks.get("sword_power", 0)) * 0.15 + int(ranks.get("vanguard_edge", 0)) * 0.20 + (0.10 if growth.job == "vanguard" else 0.0)
	var bow_bonus := int(ranks.get("bow_power", 0)) * 0.15 + int(ranks.get("tracker_focus", 0)) * 0.20 + (0.10 if growth.job == "tracker" else 0.0)
	if int(player.max_health) != expected_max or not is_equal_approx(float(player.common), int(ranks.get("power", 0)) * 0.10) or not is_equal_approx(float(player.sword), sword_bonus) or not is_equal_approx(float(player.bow), bow_bonus):
		return false
	if state.weapons.get("active") not in ["sword", "bow"]:
		return false
	for weapon in ["sword", "bow"]:
		if not state.weapons.get(weapon) is Dictionary:
			return false
		for key in ["_basic_remaining_s", "_skill_1_cooldown_s", "_skill_2_cooldown_s", "basic_attack_count", "skill_hit_count", "total_damage"]:
			if not _number(state.weapons[weapon].get(key), 0, 1000000):
				return false
	if not _number(state.ultimate.get("gauge"), 0, 100, true) or not state.ultimate.get("profile") is String:
		return false
	var candidates := PrototypeJobRewards.ultimates_for(String(growth.job))
	var profile_valid: bool = growth.job == "" and state.ultimate.profile == ""
	for candidate in candidates:
		profile_valid = profile_valid or candidate.id == state.ultimate.profile
	if not profile_valid or not state.recorder.get("id") is String or String(state.recorder.id).is_empty():
		return false
	return true


static func _valid_route(route: Variant, stage: int, legacy: Dictionary) -> bool:
	return route in ["meadow", "wind"] or (route == "clockwork" and stage == 2 and legacy.get("choice", "") == "destroy")
