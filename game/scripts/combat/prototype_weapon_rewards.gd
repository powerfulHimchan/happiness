class_name PrototypeWeaponRewards
extends RefCounted

## GP-108: 확정 성능의 무기 등급과 보조 고유 효과를 정의한다.
const FAMILY_IDS := ["sword", "bow", "fist", "staff", "polearm", "shield"]

static func family_name(id: String) -> String:
	return {"sword": "검", "bow": "활", "fist": "주먹", "staff": "지팡이", "polearm": "장봉", "shield": "방패"}.get(id, "없음")

const GRADE_NAMES := ["일반", "희귀", "영웅"]
const DAMAGE_BONUS := [0.0, 0.15, 0.30]
const UNIQUE_BONUS := [0.0, 0.10, 0.20]
const NAMES := {"sword": ["연습용 검", "풀잎 검", "새벽 검"], "bow": ["연습용 활", "씨앗 활", "바람 활"], "fist": ["연습용 권갑", "철제 권갑", "새벽 권갑"], "staff": ["연습용 지팡이", "수정 지팡이", "여명 지팡이"], "polearm": ["연습용 장봉", "철목 장봉", "천공 장봉"], "shield": ["연습용 방패", "철벽 방패", "서약 방패"]}
const BACKUP_RATIO := 0.50
const CODEX_PAGE_SIZE := 3
const BLUEPRINTS := {"clockwork_sword": {"weapon": "sword", "name": "태엽 검"}, "clockwork_bow": {"weapon": "bow", "name": "태엽 활"}}
const GUARDIAN_DESIGNS := ["guardian_sword", "guardian_bow"]
const SERA_DESIGNS := ["sera_sword", "sera_bow"]
const PERMANENT_DESIGNS := ["clockwork_sword", "clockwork_bow"] + GUARDIAN_DESIGNS + SERA_DESIGNS
const CLOCKWORK_DAMAGE := [0.0, 0.10, 0.20]
const CLOCKWORK_UNIQUE := [0.0, 0.25, 0.35]
## GP-217–226: 영구 해금과 독립적인 정예 장비. 일반 등급은 없으며 두 무기의 순서를 보존한다.
const DESIGNS := {
	"duelist_sword": {"weapon": "sword", "name": "결투 검", "kind": "basic", "damage": [0.0, 0.05, 0.10], "unique": [0.0, 0.20, 0.35]},
	"hunter_bow": {"weapon": "bow", "name": "사냥 활", "kind": "basic", "damage": [0.0, 0.05, 0.10], "unique": [0.0, 0.20, 0.35]},
	"runic_sword": {"weapon": "sword", "name": "룬 검", "kind": "skill", "damage": [0.0, 0.05, 0.10], "unique": [0.0, 0.20, 0.35]},
	"spell_bow": {"weapon": "bow", "name": "주문 활", "kind": "skill", "damage": [0.0, 0.05, 0.10], "unique": [0.0, 0.20, 0.35]},
	"fencer_sword": {"weapon": "sword", "name": "연무 검", "kind": "basic", "damage": [0.0, 0.10, 0.20], "unique": [0.0, 0.15, 0.25]},
	"precision_bow": {"weapon": "bow", "name": "정밀 활", "kind": "skill", "damage": [0.0, 0.10, 0.20], "unique": [0.0, 0.15, 0.25]},
	"forged_sword": {"weapon": "sword", "name": "단련 검", "kind": "skill", "damage": [0.0, 0.20, 0.40], "unique": [0.0, 0.05, 0.10]},
	"sturdy_bow": {"weapon": "bow", "name": "견고한 활", "kind": "basic", "damage": [0.0, 0.20, 0.40], "unique": [0.0, 0.05, 0.10]},
	"balanced_sword": {"weapon": "sword", "name": "균형 검", "kind": "basic", "damage": [0.0, 0.25, 0.45], "unique": [0.0, 0.0, 0.05]},
	"balanced_bow": {"weapon": "bow", "name": "균형 활", "kind": "skill", "damage": [0.0, 0.25, 0.45], "unique": [0.0, 0.0, 0.05]},
	"guardian_sword": {"weapon": "sword", "name": "수호 검", "kind": "skill", "damage": [0.0, 0.15, 0.25], "unique": [0.0, 0.20, 0.30]},
	"guardian_bow": {"weapon": "bow", "name": "수호 활", "kind": "basic", "damage": [0.0, 0.15, 0.25], "unique": [0.0, 0.20, 0.30]},
	"sera_sword": {"weapon": "sword", "name": "약속의 검", "kind": "basic", "damage": [0.0, 0.20, 0.30], "unique": [0.0, 0.15, 0.25]},
	"sera_bow": {"weapon": "bow", "name": "왕관의 활", "kind": "skill", "damage": [0.0, 0.20, 0.30], "unique": [0.0, 0.15, 0.25]},
	"striker_fist": {"weapon": "fist", "name": "강격 권갑", "kind": "basic", "damage": [0, 0.05, 0.1], "unique": [0, 0.2, 0.35]},
	"weaver_fist": {"weapon": "fist", "name": "비전 권갑", "kind": "skill", "damage": [0, 0.05, 0.1], "unique": [0, 0.2, 0.35]},
	"balanced_fist": {"weapon": "fist", "name": "조화 권갑", "kind": "basic", "damage": [0, 0.25, 0.45], "unique": [0, 0, 0.05]},
	"striker_staff": {"weapon": "staff", "name": "강격 지팡이", "kind": "basic", "damage": [0, 0.05, 0.1], "unique": [0, 0.2, 0.35]},
	"weaver_staff": {"weapon": "staff", "name": "비전 지팡이", "kind": "skill", "damage": [0, 0.05, 0.1], "unique": [0, 0.2, 0.35]},
	"balanced_staff": {"weapon": "staff", "name": "조화 지팡이", "kind": "skill", "damage": [0, 0.25, 0.45], "unique": [0, 0, 0.05]},
	"striker_polearm": {"weapon": "polearm", "name": "강격 장봉", "kind": "basic", "damage": [0, 0.05, 0.1], "unique": [0, 0.2, 0.35]},
	"weaver_polearm": {"weapon": "polearm", "name": "비전 장봉", "kind": "skill", "damage": [0, 0.05, 0.1], "unique": [0, 0.2, 0.35]},
	"balanced_polearm": {"weapon": "polearm", "name": "조화 장봉", "kind": "basic", "damage": [0, 0.25, 0.45], "unique": [0, 0, 0.05]},
	"striker_shield": {"weapon": "shield", "name": "강격 방패", "kind": "basic", "damage": [0, 0.05, 0.1], "unique": [0, 0.2, 0.35]},
	"weaver_shield": {"weapon": "shield", "name": "비전 방패", "kind": "skill", "damage": [0, 0.05, 0.1], "unique": [0, 0.2, 0.35]},
	"balanced_shield": {"weapon": "shield", "name": "조화 방패", "kind": "skill", "damage": [0, 0.25, 0.45], "unique": [0, 0, 0.05]},
}

const EXPANSION_DESIGNS := ["striker_fist", "weaver_fist", "balanced_fist", "striker_staff", "weaver_staff", "balanced_staff", "striker_polearm", "weaver_polearm", "balanced_polearm", "striker_shield", "weaver_shield", "balanced_shield"]

static func design_profile(id: String) -> Dictionary:
	return DESIGNS.get(id, BLUEPRINTS.get(id, {}))

static func design_available(id: String, unlocked: Dictionary) -> bool:
	return id.is_empty() or (DESIGNS.has(id) and id not in GUARDIAN_DESIGNS and id not in SERA_DESIGNS) or unlocked.get(id, false) == true


static func valid_blueprints(value: Variant, equipment: Dictionary) -> bool:
	if not value is Dictionary or value.size() != 2:
		return false
	for weapon in equipment:
		var id: Variant = value.get(weapon)
		if not id is String:
			return false
		if not id.is_empty() and (design_profile(id).is_empty() or design_profile(id).weapon != weapon or int(equipment.get(weapon, 0)) < 1):
			return false
	return true


static func valid_equipment(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2:
		return false
	for id in value:
		if id not in FAMILY_IDS: return false
		var grade: Variant = value.get(id)
		if not (grade is int or grade is float) or not is_finite(float(grade)) or float(grade) != floorf(float(grade)) or grade < 0 or grade > 2:
			return false
	return true


static func profile(id: String, grade: int, blueprint: String = "") -> Dictionary:
	if id not in NAMES or grade < 0 or grade > 2:
		return {}
	var design := design_profile(blueprint)
	if not blueprint.is_empty() and (design.is_empty() or design.weapon != id or grade < 1):
		return {}
	var kind: String = String(design.get("kind", "skill" if id in ["sword", "staff", "shield"] else "basic"))
	var effect := "스킬" if kind == "skill" else "기본 공격"
	var damage: float = DAMAGE_BONUS[grade] if blueprint.is_empty() else float(design.get("damage", CLOCKWORK_DAMAGE)[grade])
	var unique: float = UNIQUE_BONUS[grade] if blueprint.is_empty() else float(design.get("unique", CLOCKWORK_UNIQUE)[grade])
	var weapon_name: String = NAMES[id][grade] if blueprint.is_empty() else String(design.name)
	return {"id": id if blueprint.is_empty() else blueprint, "weapon_id": id, "blueprint": blueprint, "grade": grade, "name": "%s %s" % [GRADE_NAMES[grade], weapon_name], "damage": damage, "unique": unique, "kind": kind, "lines": ["무기 피해 +%d%%" % roundi(damage * 100), "%s 피해 +%d%%" % [effect, roundi(unique * 100)], "보조: %s +%.1f%%" % [effect, unique * BACKUP_RATIO * 100]]}


static func offers(stage: int, equipment: Dictionary, unlocked: Dictionary = {}, blueprints: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in equipment:
		var item := profile(id, mini(stage, 2))
		item["previous_name"] = profile(id, int(equipment[id]), String(blueprints.get(id, ""))).name
		result.append(item)
	for blueprint in BLUEPRINTS:
		if unlocked.get(blueprint, false) != true or BLUEPRINTS[blueprint].weapon not in equipment:
			continue
		var weapon: String = BLUEPRINTS[blueprint].weapon
		var item := profile(weapon, mini(stage, 2), blueprint)
		item["previous_name"] = profile(weapon, int(equipment[weapon]), String(blueprints.get(weapon, ""))).name
		result.append(item)
	for design in DESIGNS:
		if not design_available(design, unlocked) or DESIGNS[design].weapon not in equipment: continue
		var weapon: String = DESIGNS[design].weapon
		var item := profile(weapon, mini(stage, 2), design)
		item["previous_name"] = profile(weapon, int(equipment[weapon]), String(blueprints.get(weapon, ""))).name
		result.append(item)
	return result


static func damage_multiplier(equipment: Dictionary, id: String, kind: String, blueprints: Dictionary = {}) -> float:
	if kind not in ["basic", "skill"] or id not in equipment:
		return 1.0
	var own := profile(id, int(equipment[id]), String(blueprints.get(id, "")))
	var other: String = equipment.keys().filter(func(family: String) -> bool: return family != id)[0]
	var backup := profile(other, int(equipment[other]), String(blueprints.get(other, "")))
	return 1.0 + float(own.damage) + (float(own.unique) if own.kind == kind else 0.0) + (float(backup.unique) * BACKUP_RATIO if backup.kind == kind else 0.0)


static func codex_cards(unlocked: Dictionary, equipment: Dictionary = {}, blueprints: Dictionary = {}, active_weapon: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var active := active_weapon in NAMES and valid_equipment(equipment) and valid_blueprints(blueprints, equipment)
	var entries: Array[Dictionary] = []
	for weapon in ["sword", "bow"]:
		var designs: Array[String] = [""]
		for id in BLUEPRINTS:
			if BLUEPRINTS[id].weapon == weapon: designs.append(String(id))
		for design in designs:
			for grade in GRADE_NAMES.size():
				var item := profile(weapon, grade, design)
				if item.is_empty(): continue
				entries.append(item)
	for design in DESIGNS:
		if design in EXPANSION_DESIGNS: continue
		for grade in [1, 2]:
			entries.append(profile(DESIGNS[design].weapon, grade, design))
	for weapon in ["fist", "staff", "polearm", "shield"]:
		for grade in GRADE_NAMES.size(): entries.append(profile(weapon, grade))
	# Append the new designs after all fifty original codex entries.
	for design in EXPANSION_DESIGNS:
		for grade in [1, 2]: entries.append(profile(DESIGNS[design].weapon, grade, design))
	for item in entries:
		var weapon: String = item.weapon_id
		var grade: int = item.grade
		var design: String = item.blueprint
		var available: bool = design_available(design, unlocked)
		var equipped: bool = active and equipment.has(weapon) and int(equipment[weapon]) == grade and blueprints[weapon] == design
		var status := "이번 도전 · 주 무기" if equipped and active_weapon == weapon else "이번 도전 · 보조 무기" if equipped else "획득 가능 · 효과 미리 보기" if available else "미해금 · 효과 미리 보기"
		var lines: Array[String] = []
		for line in item.lines: lines.append(String(line))
		var condition := "시작 무기 · 새 도전 기본 장비" if grade == 0 else "첫 정예 보상" if grade == 1 else "두 번째 정예 보상"
		if design in SERA_DESIGNS: condition = "세라 파괴로 해금 · " + condition
		if design in GUARDIAN_DESIGNS: condition = "수호기사 파괴로 해금 · " + condition
		if BLUEPRINTS.has(design): condition = "보스 파괴로 해금 · " + condition
		lines.append(condition)
		lines.append("장비 합산: 기본 +%.1f%% · 스킬 +%.1f%%" % [(damage_multiplier(equipment, weapon, "basic", blueprints) - 1.0) * 100, (damage_multiplier(equipment, weapon, "skill", blueprints) - 1.0) * 100] if equipped else "고유 효과는 피해 보너스에 합산")
		lines.append("성장·기억·거리 보정 전 · 필살기 제외")
		result.append({"id": "%s_%d" % [item.id, grade], "weapon": weapon, "blueprint": design, "grade": grade, "name": item.name, "open": available or equipped, "equipped": equipped, "status": status, "lines": lines})
	return result
