class_name PrototypePotionRecipes
extends RefCounted

## GP-120: 다음 새 도전의 회복약 조제. 진행 중 도전에는 저장된 조제를 사용한다.
const BASIC := "basic"
const CONCENTRATED := "concentrated"
const IDS := [BASIC, CONCENTRATED]
const RECIPES := {
	BASIC: {"name": "기본 회복약", "count": 2, "ratio": 0.25},
	CONCENTRATED: {"name": "농축 회복약", "count": 1, "ratio": 0.40},
}

static func valid_id(value: Variant) -> bool:
	return value is String and value in IDS

static func available(id: String, memories: Dictionary) -> bool:
	return id == BASIC or (id == CONCENTRATED and memories.get("clockwork_guard", false) == true)

static func profile(id: String) -> Dictionary:
	return RECIPES.get(id, RECIPES[BASIC]).duplicate()

static func summary(id: String) -> String:
	var recipe := profile(id)
	return "%s · %d개 · 체력 %d%%" % [recipe.name, recipe.count, roundi(float(recipe.ratio) * 100)]
