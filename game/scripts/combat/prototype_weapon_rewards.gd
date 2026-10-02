class_name PrototypeWeaponRewards
extends RefCounted

## GP-108: 확정 성능의 검·활 등급과 보조 고유 효과를 정의한다.
const GRADE_NAMES := ["일반", "희귀", "영웅"]
const DAMAGE_BONUS := [0.0, 0.15, 0.30]
const UNIQUE_BONUS := [0.0, 0.10, 0.20]
const NAMES := {"sword": ["연습용 검", "풀잎 검", "새벽 검"], "bow": ["연습용 활", "씨앗 활", "바람 활"]}
const BACKUP_RATIO := 0.50
const BLUEPRINTS := {"clockwork_sword": {"weapon": "sword", "name": "태엽 검"}, "clockwork_bow": {"weapon": "bow", "name": "태엽 활"}}
const CLOCKWORK_DAMAGE := [0.0, 0.10, 0.20]
const CLOCKWORK_UNIQUE := [0.0, 0.25, 0.35]


static func valid_blueprints(value: Variant, equipment: Dictionary) -> bool:
	if not value is Dictionary or value.size() != 2:
		return false
	for weapon in ["sword", "bow"]:
		var id: Variant = value.get(weapon)
		if not id is String:
			return false
		if not id.is_empty() and (not BLUEPRINTS.has(id) or BLUEPRINTS[id].weapon != weapon or int(equipment.get(weapon, 0)) < 1):
			return false
	return true


static func valid_equipment(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2:
		return false
	for id in ["sword", "bow"]:
		var grade: Variant = value.get(id)
		if not (grade is int or grade is float) or not is_finite(float(grade)) or float(grade) != floorf(float(grade)) or grade < 0 or grade > 2:
			return false
	return true


static func profile(id: String, grade: int, blueprint: String = "") -> Dictionary:
	if id not in NAMES or grade < 0 or grade > 2:
		return {}
	var effect := "스킬" if id == "sword" else "기본 공격"
	if not blueprint.is_empty() and (not BLUEPRINTS.has(blueprint) or BLUEPRINTS[blueprint].weapon != id or grade < 1):
		return {}
	var damage: float = DAMAGE_BONUS[grade] if blueprint.is_empty() else CLOCKWORK_DAMAGE[grade]
	var unique: float = UNIQUE_BONUS[grade] if blueprint.is_empty() else CLOCKWORK_UNIQUE[grade]
	var weapon_name: String = NAMES[id][grade] if blueprint.is_empty() else BLUEPRINTS[blueprint].name
	return {"id": id if blueprint.is_empty() else blueprint, "weapon_id": id, "blueprint": blueprint, "grade": grade, "name": "%s %s" % [GRADE_NAMES[grade], weapon_name], "damage": damage, "unique": unique, "kind": "skill" if id == "sword" else "basic", "lines": ["무기 피해 +%d%%" % roundi(damage * 100), "%s 피해 +%d%%" % [effect, roundi(unique * 100)], "보조: %s +%.1f%%" % [effect, unique * BACKUP_RATIO * 100]]}


static func offers(stage: int, equipment: Dictionary, unlocked: Dictionary = {}, blueprints: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in ["sword", "bow"]:
		var item := profile(id, mini(stage, 2))
		item["previous_name"] = profile(id, int(equipment[id]), String(blueprints.get(id, ""))).name
		result.append(item)
	for blueprint in BLUEPRINTS:
		if unlocked.get(blueprint, false) != true:
			continue
		var weapon: String = BLUEPRINTS[blueprint].weapon
		var item := profile(weapon, mini(stage, 2), blueprint)
		item["previous_name"] = profile(weapon, int(equipment[weapon]), String(blueprints.get(weapon, ""))).name
		result.append(item)
	return result


static func damage_multiplier(equipment: Dictionary, id: String, kind: String, blueprints: Dictionary = {}) -> float:
	if kind not in ["basic", "skill"] or id not in ["sword", "bow"]:
		return 1.0
	var own := profile(id, int(equipment[id]), String(blueprints.get(id, "")))
	var other := "bow" if id == "sword" else "sword"
	var backup := profile(other, int(equipment[other]), String(blueprints.get(other, "")))
	return 1.0 + float(own.damage) + (float(own.unique) if own.kind == kind else 0.0) + (float(backup.unique) * BACKUP_RATIO if backup.kind == kind else 0.0)
