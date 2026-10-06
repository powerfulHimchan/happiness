class_name PrototypeRelic
extends RefCounted

const PHOENIX_ID := "phoenix_feather"
const CLOCK_ID := "clock_fragment"
const HEAL_RATIO := 0.50
const INVULNERABLE_S := 1.0
const CLOCK_RECHARGE_MULTIPLIER := 1.25
const OFFERS: Array[Dictionary] = [
	{"id": PHOENIX_ID, "name": "불사조 깃털", "lines": ["치명적인 피해에서 체력 50%로 부활", "도전당 한 번 · 부활 후 1초 보호", "새 도전에는 가져갈 수 없습니다"]},
	{"id": CLOCK_ID, "name": "시계추 조각", "lines": ["검·활 스킬 재사용 대기 -20%", "예: 10초 → 8초 · 보조 무기 포함", "새 도전에는 가져갈 수 없습니다"]},
]

static func valid_id(id: String) -> bool:
	return id in [PHOENIX_ID, CLOCK_ID]

static func valid_state(value: Variant) -> bool:
	return value is Dictionary and (value.is_empty() or (value.size() == 2 and value.get("id") is String and valid_id(value.id) and value.get("used") is bool and (value.id != CLOCK_ID or not value.used)))

static func hud(state: Dictionary) -> String:
	if state.is_empty():
		return "유물 없음"
	if state.id == CLOCK_ID:
		return "시계추 조각 · 스킬 대기 -20%"
	return "불사조 깃털 · 사용 완료" if state.used else "불사조 깃털 · 부활 1회"
