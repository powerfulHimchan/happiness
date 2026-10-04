class_name PrototypeRelic
extends RefCounted

const PHOENIX_ID := "phoenix_feather"
const HEAL_RATIO := 0.50
const INVULNERABLE_S := 1.0

static func valid_state(value: Variant) -> bool:
	return value is Dictionary and (value.is_empty() or (value.size() == 2 and value.get("id") == PHOENIX_ID and value.get("used") is bool))

static func hud(state: Dictionary) -> String:
	if state.is_empty():
		return "유물 없음"
	return "불사조 깃털 · 사용 완료" if state.used else "불사조 깃털 · 부활 1회"
