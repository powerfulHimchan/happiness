class_name PrototypeRelic
extends RefCounted

const PHOENIX_ID := "phoenix_feather"
const CLOCK_ID := "clock_fragment"
const DEW_ID := "spring_dew"
const EMBER_ID := "dawn_ember"
const HOURGLASS_ID := "hourglass"
const HOURGLASS_GAUGE_MULTIPLIER := 1.25
const EMBER_DAMAGE_MULTIPLIER := 1.10
const DEW_POTION_BONUS := 0.10
const HEAL_RATIO := 0.50
const INVULNERABLE_S := 1.0
const CLOCK_RECHARGE_MULTIPLIER := 1.25
const OFFERS: Array[Dictionary] = [
	{"id": PHOENIX_ID, "name": "불사조 깃털", "lines": ["치명상 시 체력50% 부활", "도전당 1회 · 부활 보호1초", "새 도전에 가져갈 수 없음"]},
	{"id": CLOCK_ID, "name": "시계추 조각", "lines": ["검·활 스킬 대기 -20%", "10초→8초 · 보조 무기 적용", "새 도전에 가져갈 수 없음"]},
	{"id": DEW_ID, "name": "샘의 이슬", "lines": ["회복약 · 최대 체력 +10%p", "기본35% · 농축50% · 소분30%", "개수 유지 · 도전 중 지속"]},
	{"id": EMBER_ID, "name": "여명의 불씨", "lines": ["검·활 피해1.1배 · 반올림", "기본 공격·스킬·공격 필살기", "체력·게이지·대기 유지"]},
	{"id": HOURGLASS_ID, "name": "모래시계", "lines": ["전투 게이지 획득 +25%", "적중·정확 회피·시간 수집", "경로 보상 유지 · 최종 반올림"]},
]

static func valid_id(id: String) -> bool:
	return id in [PHOENIX_ID, CLOCK_ID, DEW_ID, EMBER_ID, HOURGLASS_ID]

static func valid_state(value: Variant) -> bool:
	return value is Dictionary and (value.is_empty() or (value.size() == 2 and value.get("id") is String and valid_id(value.id) and value.get("used") is bool and (value.id == PHOENIX_ID or not value.used)))

static func hud(state: Dictionary) -> String:
	if state.is_empty():
		return "유물 없음"
	if state.id == HOURGLASS_ID:
		return "모래시계 · 전투 게이지 +25%"
	if state.id == EMBER_ID:
		return "여명의 불씨 · 검·활 피해 1.1배"
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
		lines.append("조건: 두 번째 정예 뒤 선택")
		lines.append("기본5 · 스킬10 · 회피15" if offer.id == HOURGLASS_ID else "성장·장비 뒤 적용 · 감속 유지" if offer.id == EMBER_ID else "스킬만 적용 · 공격/회피 유지" if offer.id == CLOCK_ID else "구슬·휴식·흡수 회복 유지" if offer.id == DEW_ID else "소비한 깃털은 재부활 불가")
		var status := "이번 도전 · 사용 완료" if owned and bool(state.get("used", false)) else "이번 도전 · 보유 중" if owned else "미보유 · 효과 미리 보기"
		result.append({"id": offer.id, "name": offer.name, "open": owned, "status": status, "lines": lines})
	return result
