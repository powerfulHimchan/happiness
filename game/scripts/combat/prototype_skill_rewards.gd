class_name PrototypeSkillRewards
extends RefCounted

## 무기별 세 스킬 중 보유하지 않은 하나를 정예 휴식에서 제안한다.
const SKILLS := {
	"sword_dash": preload("res://data/skills/sword_dash.tres"),
	"sword_spin": preload("res://data/skills/sword_spin.tres"),
	"sword_crescent": preload("res://data/skills/sword_crescent.tres"),
	"bow_piercing": preload("res://data/skills/bow_piercing.tres"),
	"bow_arrow_rain": preload("res://data/skills/bow_arrow_rain.tres"),
	"bow_volley": preload("res://data/skills/bow_volley.tres"),
}
const POOLS := {"sword": ["sword_dash", "sword_spin", "sword_crescent"], "bow": ["bow_piercing", "bow_arrow_rain", "bow_volley"]}
const LABELS := {"sword_dash": "돌진", "sword_spin": "회전", "sword_crescent": "반달", "bow_piercing": "관통", "bow_arrow_rain": "화살비", "bow_volley": "연사"}

static func defaults() -> Dictionary:
	return {"sword": ["sword_dash", "sword_spin"], "bow": ["bow_piercing", "bow_arrow_rain"]}

static func valid_loadout(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2:
		return false
	for weapon in POOLS:
		if not value.get(weapon) is Array or value[weapon].size() != 2:
			return false
		if value[weapon][0] == value[weapon][1]:
			return false
		for id in value[weapon]:
			if not id is String or id not in POOLS[weapon]:
				return false
	return true

static func weapon_for(id: String) -> String:
	for weapon in POOLS:
		if id in POOLS[weapon]:
			return weapon
	return ""

static func lines(id: String) -> Array[String]:
	var definition: SkillDefinition = SKILLS[id]
	var result: Array[String] = ["재사용 %.0f초 · 동작 %.2f초" % [definition.cooldown_s, definition.duration_s]]
	result.append("타격 %d회 · 기본 피해 %d" % [definition.damage.size(), _total_damage(definition)])
	match id:
		"sword_dash": result.append("전방 대상 돌진 · 이동 3.5m")
		"sword_spin": result.append("주변 2m · 두 번 베기")
		"sword_crescent": result.append("주변 3m · 한 번 크게 베기")
		"bow_piercing": result.append("화살 1발 · 최대 3개체 관통")
		"bow_arrow_rain": result.append("대상 주변 2.4m · 범위 6타")
		"bow_volley": result.append("화살 3발 · 각 1개체 타격")
	return result

static func _total_damage(definition: SkillDefinition) -> int:
	var total := 0
	for damage in definition.damage:
		total += damage
	return total

static func offers(loadout: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for weapon in POOLS:
		for id in POOLS[weapon]:
			if id not in loadout[weapon]:
				result.append({"id": id, "weapon": weapon, "name": SKILLS[id].display_name, "lines": lines(id)})
	return result
