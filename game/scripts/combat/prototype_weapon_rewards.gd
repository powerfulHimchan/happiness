class_name PrototypeWeaponRewards
extends RefCounted

## GP-108: 확정 성능의 검·활 등급과 보조 고유 효과를 정의한다.
const GRADE_NAMES := ["일반", "희귀", "영웅"]
const DAMAGE_BONUS := [0.0, 0.15, 0.30]
const UNIQUE_BONUS := [0.0, 0.10, 0.20]
const NAMES := {"sword": ["연습용 검", "풀잎 검", "새벽 검"], "bow": ["연습용 활", "씨앗 활", "바람 활"]}
const BACKUP_RATIO := 0.50


static func valid_equipment(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2:
		return false
	for id in ["sword", "bow"]:
		var grade: Variant = value.get(id)
		if not (grade is int or grade is float) or not is_finite(float(grade)) or float(grade) != floorf(float(grade)) or grade < 0 or grade > 2:
			return false
	return true


static func profile(id: String, grade: int) -> Dictionary:
	if id not in NAMES or grade < 0 or grade > 2:
		return {}
	var effect := "스킬" if id == "sword" else "기본 공격"
	return {"id": id, "grade": grade, "name": "%s %s" % [GRADE_NAMES[grade], NAMES[id][grade]], "damage": DAMAGE_BONUS[grade], "unique": UNIQUE_BONUS[grade], "kind": "skill" if id == "sword" else "basic", "lines": ["무기 피해 +%d%%" % roundi(DAMAGE_BONUS[grade] * 100), "%s 피해 +%d%%" % [effect, roundi(UNIQUE_BONUS[grade] * 100)], "보조: %s 피해 +%d%%" % [effect, roundi(UNIQUE_BONUS[grade] * BACKUP_RATIO * 100)]]}


static func offers(stage: int, equipment: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in ["sword", "bow"]:
		var item := profile(id, mini(stage, 2))
		item["previous_name"] = profile(id, int(equipment[id])).name
		result.append(item)
	return result


static func damage_multiplier(equipment: Dictionary, id: String, kind: String) -> float:
	if kind not in ["basic", "skill"] or id not in ["sword", "bow"]:
		return 1.0
	var own := profile(id, int(equipment[id]))
	var backup := profile("bow" if id == "sword" else "sword", int(equipment["bow" if id == "sword" else "sword"]))
	return 1.0 + float(own.damage) + (float(own.unique) if own.kind == kind else 0.0) + (float(backup.unique) * BACKUP_RATIO if backup.kind == kind else 0.0)
