class_name PrototypeRelic
extends RefCounted

const PHOENIX_ID := "phoenix_feather"
const CLOCK_ID := "clock_fragment"
const DEW_ID := "spring_dew"
const DEW_POTION_BONUS := 0.10
const HEAL_RATIO := 0.50
const INVULNERABLE_S := 1.0
const CLOCK_RECHARGE_MULTIPLIER := 1.25
const OFFERS: Array[Dictionary] = [
	{"id": PHOENIX_ID, "name": "불사조 깃털", "lines": ["치명적인 피해에서 체력 50%로 부활", "도전당 한 번 · 부활 후 1초 보호", "새 도전에는 가져갈 수 없습니다"]},
	{"id": CLOCK_ID, "name": "시계추 조각", "lines": ["검·활 스킬 재사용 대기 -20%", "예: 10초 → 8초 · 보조 무기 포함", "새 도전에는 가져갈 수 없습니다"]},
	{"id": DEW_ID, "name": "샘의 이슬", "lines": ["회복약 회복량 · 최대 체력 +10%p", "기본 25→35% · 농축 40→50%", "회복약 개수는 유지 · 도전 중 지속"]},
]

static func valid_id(id: String) -> bool:
	return id in [PHOENIX_ID, CLOCK_ID, DEW_ID]

static func valid_state(value: Variant) -> bool:
	return value is Dictionary and (value.is_empty() or (value.size() == 2 and value.get("id") is String and valid_id(value.id) and value.get("used") is bool and (value.id == PHOENIX_ID or not value.used)))

static func hud(state: Dictionary) -> String:
	if state.is_empty():
		return "유물 없음"
	if state.id == DEW_ID:
		return "샘의 이슬 · 회복약 +10%p"
	if state.id == CLOCK_ID:
		return "시계추 조각 · 스킬 대기 -20%"
	return "불사조 깃털 · 사용 완료" if state.used else "불사조 깃털 · 부활 1회"

static func codex_cards(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for offer in OFFERS:
		var owned: bool = state.get("id", "") == offer.id
		var lines: Array[String] = []
		for line in offer.lines: lines.append(String(line))
		lines.append("조건: 두 번째 정예 완료 후 하나 선택")
		lines.append("기본 공격·회피·필살기에는 적용하지 않음" if offer.id == CLOCK_ID else "회복 구슬·휴식·흡수 회복에는 적용 안 됨" if offer.id == DEW_ID else "사용한 깃털은 이 도전에서 재부활 불가")
		var status := "이번 도전 · 사용 완료" if owned and bool(state.get("used", false)) else "이번 도전 · 보유 중" if owned else "미보유 · 효과 미리 보기"
		result.append({"id": offer.id, "name": offer.name, "open": owned, "status": status, "lines": lines})
	return result
