class_name PrototypePotionRecipes
extends RefCounted

## GP-120: 다음 새 도전의 회복약 조제. 진행 중 도전에는 저장된 조제를 사용한다.
const BASIC := "basic"
const CONCENTRATED := "concentrated"
const PORTIONED := "portioned"
const IDS := [BASIC, CONCENTRATED, PORTIONED]
const RECIPES := {
	BASIC: {"name": "기본 회복약", "count": 2, "ratio": 0.25},
	CONCENTRATED: {"name": "농축 회복약", "count": 1, "ratio": 0.40},
	PORTIONED: {"name": "소분 회복약", "count": 3, "ratio": 0.20},
}

static func valid_id(value: Variant) -> bool:
	return value is String and value in IDS

static func available(id: String, memories: Dictionary) -> bool:
	return id == BASIC or (id == CONCENTRATED and memories.get("clockwork_guard", false) == true) or (id == PORTIONED and memories.get("core_echo", false) == true)

static func strategy(id: String) -> String:
	return "세 번 나누어 회복" if id == PORTIONED else "한 번에 크게 회복" if id == CONCENTRATED else "두 번 나누어 회복"

static func unlock_condition(id: String) -> String:
	return "태엽 기사 파괴로 소분 조제 해금" if id == PORTIONED else "태엽 기사 구출로 약초사 정착" if id == CONCENTRATED else "항상 제공"

static func profile(id: String) -> Dictionary:
	return RECIPES.get(id, RECIPES[BASIC]).duplicate()

static func summary(id: String) -> String:
	var recipe := profile(id)
	return "%s · %d개 · 체력 %d%%" % [recipe.name, recipe.count, roundi(float(recipe.ratio) * 100)]
