class_name PrototypeRelic
extends RefCounted

const IRON_LEAF_ID := "iron_leaf"
const LAST_SPARK_ID := "last_spark"
const SWORD_PENDANT_ID := "sword_pendant"
const BOW_PENDANT_ID := "bow_pendant"
const TEMPO_BELL_ID := "tempo_bell"
const SKILL_PRISM_ID := "skill_prism"
const DAWN_DIAL_ID := "dawn_dial"
const BARRIER_LENS_ID := "barrier_lens"
const PHOENIX_ID := "phoenix_feather"
const CLOCK_ID := "clock_fragment"
const DEW_ID := "spring_dew"
const EMBER_ID := "dawn_ember"
const HOURGLASS_ID := "hourglass"
const SEAL_ID := "guardian_seal"
const WIND_ID := "wind_knot"
const SEED_ID := "vital_seed"
const DUEL_ID := "duelist_emblem"
const RUNE_ID := "arcane_emblem"
const COMPASS_ID := "forest_compass"
const COIN_ID := "collector_coin"
const CUP_ID := "dawn_cup"
const RUNE_SKILL_MULTIPLIER := 1.20
const COMPASS_RADIUS_MULTIPLIER := 1.50
const COIN_DEFEAT_GAIN := 3
const CUP_POTION_BONUS := 0.05
const CHARM_ID := "crisis_charm"
const FEATHER_ID := "clear_feather"
const NECKLACE_ID := "life_necklace"
const WHISTLE_ID := "cheering_whistle"
const CHARM_DAMAGE_MULTIPLIER := 0.80
const FEATHER_BASIC_MULTIPLIER := 1.25
const NECKLACE_ABSORB_PERCENT := 5
const WHISTLE_EVADE_GAIN := 3
const REWARD_PAGE_SIZE := 5
const CODEX_PAGE_SIZE := 3
const SEAL_DAMAGE_MULTIPLIER := 0.90
const WIND_COOLDOWN_MULTIPLIER := 0.80
const SEED_ORB_BONUS := 5
const DUEL_BASIC_MULTIPLIER := 1.20
const HOURGLASS_GAUGE_MULTIPLIER := 1.25
const EMBER_DAMAGE_MULTIPLIER := 1.10
const DEW_POTION_BONUS := 0.10
const HEAL_RATIO := 0.50
const INVULNERABLE_S := 1.0
const CLOCK_RECHARGE_MULTIPLIER := 1.25
const OFFERS: Array[Dictionary] = [
	{"id": PHOENIX_ID, "name": "불사조 깃털", "lines": ["치명상 시 체력50% 부활", "도전당 1회 · 부활 보호1초", "새 도전에 가져갈 수 없음"]},
	{"id": CLOCK_ID, "name": "시계추 조각", "lines": ["모든 무기 스킬 대기 -20%", "10초→8초 · 보조 무기 적용", "새 도전에 가져갈 수 없음"]},
	{"id": DEW_ID, "name": "샘의 이슬", "lines": ["회복약 · 최대 체력 +10%p", "기본35% · 농축50% · 소분30%", "개수 유지 · 도전 중 지속"]},
	{"id": EMBER_ID, "name": "여명의 불씨", "lines": ["모든 무기 피해1.1배 · 반올림", "기본 공격·스킬·공격 필살기", "체력·게이지·대기 유지"]},
	{"id": HOURGLASS_ID, "name": "모래시계", "lines": ["전투 게이지 획득 +25%", "적중·정확 회피·시간 수집", "경로 보상 유지 · 최종 반올림"]},
	{"id": SEAL_ID, "name": "수호의 인장", "lines": ["받는 전투 피해 -10%", "방벽 흡수 전 · 최종 반올림", "최소1 피해 · 낙하 피해 유지"]},
	{"id": WIND_ID, "name": "바람의 매듭", "lines": ["지상 회피 대기 -20%", "민첩한 회피와 곱연산", "무적·동작·공중 대시 유지"]},
	{"id": SEED_ID, "name": "생명의 씨앗", "lines": ["회복 구슬 · 체력 +5%p", "기본15% · 구슬 강화25%", "드롭·거리·회복약 유지"]},
	{"id": DUEL_ID, "name": "결투의 문장", "lines": ["모든 무기 기본 공격1.2배", "성장·장비 뒤 최종 반올림", "스킬·필살기·공격 속도 유지"]},
	{"id": RUNE_ID, "name": "마력의 문장", "lines": ["모든 무기 스킬 피해1.2배", "기본 공격·필살기 유지", "성장·장비 뒤 최종 반올림"]},
	{"id": COMPASS_ID, "name": "숲의 나침반", "lines": ["회복 구슬 획득 거리1.5배", "구슬 자석·넓은 자석과 곱연산", "회복량·드롭 확률 유지"]},
	{"id": COIN_ID, "name": "수집가의 동전", "lines": ["실제 적 처치 게이지 +3", "시간 수집과 합산 · 최대100", "획득 즉시 충전하지 않음"]},
	{"id": CUP_ID, "name": "새벽의 잔", "lines": ["회복약 최대 체력 회복 +5%p", "기본30% · 농축45% · 소분25%", "숙련과 합산 · 개수 유지"]},
	{"id": CHARM_ID, "name": "위기의 부적", "lines": ["체력30% 이하: 전투 피해 -20%", "생존 본능과 곱연산 · 방벽 전에", "최소1 피해 · 낙하 피해 유지"]},
	{"id": FEATHER_ID, "name": "청명의 깃털", "lines": ["체력80% 이상: 기본 공격1.25배", "모든 무기 적용 · 적중 시 체력 기준", "스킬·필살기·공격 속도 유지"]},
	{"id": NECKLACE_ID, "name": "생명의 목걸이", "lines": ["모든 무기 실제 피해의5% 회복", "생명 흡수/강화와 +5%p 합산", "기본·스킬 적용 · 소수 누적"]},
	{"id": WHISTLE_ID, "name": "응원의 호루라기", "lines": ["정확 회피 게이지12 → 15", "실제 회피 판정마다 추가 +3", "회피 시간·경로 보상 유지"]},
	{"id": "iron_leaf", "name": "강철 잎", "lines": ["체력80% 이상: 전투 피해 -15%", "방벽 흡수 전 · 낙하 피해 유지", "도전 중 지속 · 하나만 보유"]},
	{"id": "last_spark", "name": "마지막 불꽃", "lines": ["체력30% 이하: 스킬 피해1.3배", "모든 무기 스킬 · 현재 체력 기준", "도전 중 지속 · 하나만 보유"]},
	{"id": "sword_pendant", "name": "검사의 펜던트", "lines": ["검 피해1.15배", "기본·스킬·공격 필살기 적용", "도전 중 지속 · 하나만 보유"]},
	{"id": "bow_pendant", "name": "궁수의 펜던트", "lines": ["활 피해1.15배", "기본·스킬·공격 필살기 적용", "도전 중 지속 · 하나만 보유"]},
	{"id": "tempo_bell", "name": "박자의 종", "lines": ["기본 공격 적중 게이지 +2", "모든 무기 · 게이지 최대100", "도전 중 지속 · 하나만 보유"]},
	{"id": "skill_prism", "name": "기술의 프리즘", "lines": ["스킬 적중 게이지 +3", "모든 무기 · 게이지 최대100", "도전 중 지속 · 하나만 보유"]},
	{"id": "dawn_dial", "name": "새벽의 시계판", "lines": ["필살기 감속 시간 +1초", "다음 발동부터 · 여운과 합산", "도전 중 지속 · 하나만 보유"]},
	{"id": "barrier_lens", "name": "방벽 렌즈", "lines": ["방벽 잔량이 있으면 스킬1.25배", "모든 무기 스킬 · 적중 시 잔량 기준", "도전 중 지속 · 하나만 보유"]},
	{"id": "fist_pendant", "name": "권갑 수련의 펜던트", "weapon": "fist", "damage_kind": "all", "multiplier": 1.15, "lines": ["권갑 피해1.15배", "기본·스킬·공격 필살기", "이번 도전 · 유물 하나만 보유"]},
	{"id": "fist_sigil", "name": "권갑 비전 문장", "weapon": "fist", "damage_kind": "skill", "multiplier": 1.3, "lines": ["권갑 스킬 피해1.3배", "다른 계열·기본·필살기 유지", "이번 도전 · 유물 하나만 보유"]},
	{"id": "staff_pendant", "name": "지팡이 수련의 펜던트", "weapon": "staff", "damage_kind": "all", "multiplier": 1.15, "lines": ["지팡이 피해1.15배", "기본·스킬·공격 필살기", "이번 도전 · 유물 하나만 보유"]},
	{"id": "staff_sigil", "name": "지팡이 비전 문장", "weapon": "staff", "damage_kind": "skill", "multiplier": 1.3, "lines": ["지팡이 스킬 피해1.3배", "다른 계열·기본·필살기 유지", "이번 도전 · 유물 하나만 보유"]},
	{"id": "polearm_pendant", "name": "장봉 수련의 펜던트", "weapon": "polearm", "damage_kind": "all", "multiplier": 1.15, "lines": ["장봉 피해1.15배", "기본·스킬·공격 필살기", "이번 도전 · 유물 하나만 보유"]},
	{"id": "polearm_sigil", "name": "장봉 비전 문장", "weapon": "polearm", "damage_kind": "skill", "multiplier": 1.3, "lines": ["장봉 스킬 피해1.3배", "다른 계열·기본·필살기 유지", "이번 도전 · 유물 하나만 보유"]},
	{"id": "shield_pendant", "name": "방패 수련의 펜던트", "weapon": "shield", "damage_kind": "all", "multiplier": 1.15, "lines": ["방패 피해1.15배", "기본·스킬·공격 필살기", "이번 도전 · 유물 하나만 보유"]},
	{"id": "shield_sigil", "name": "방패 비전 문장", "weapon": "shield", "damage_kind": "skill", "multiplier": 1.3, "lines": ["방패 스킬 피해1.3배", "다른 계열·기본·필살기 유지", "이번 도전 · 유물 하나만 보유"]},
]

static func family_profile(id: String) -> Dictionary:
	for offer in OFFERS:
		if offer.id == id and offer.has("weapon"): return offer
	return {}

static func family_damage_multiplier(id: String, family: String, kind: String) -> float:
	var relic := family_profile(id)
	if relic.is_empty() or relic.weapon != family or kind not in ["basic", "skill", "ultimate"]: return 1.0
	return float(relic.multiplier) if relic.damage_kind == "all" or relic.damage_kind == kind else 1.0


static func valid_id(id: String) -> bool:
	return OFFERS.any(func(offer: Dictionary) -> bool: return offer.id == id)

static func valid_state(value: Variant) -> bool:
	return value is Dictionary and (value.is_empty() or (value.size() == 2 and value.get("id") is String and valid_id(value.id) and value.get("used") is bool and (value.id == PHOENIX_ID or not value.used)))

static func hud(state: Dictionary) -> String:
	if state.is_empty():
		return "유물 없음"
	var family := family_profile(String(state.id))
	if not family.is_empty(): return String(family.name) + " · " + String(family.lines[0])
	if state.id == IRON_LEAF_ID: return "강철 잎 · 체력80% 이상: 전투 피해 -15%"
	if state.id == LAST_SPARK_ID: return "마지막 불꽃 · 체력30% 이하: 스킬 피해1.3배"
	if state.id == SWORD_PENDANT_ID: return "검사의 펜던트 · 검 피해1.15배"
	if state.id == BOW_PENDANT_ID: return "궁수의 펜던트 · 활 피해1.15배"
	if state.id == TEMPO_BELL_ID: return "박자의 종 · 기본 공격 적중 게이지 +2"
	if state.id == SKILL_PRISM_ID: return "기술의 프리즘 · 스킬 적중 게이지 +3"
	if state.id == DAWN_DIAL_ID: return "새벽의 시계판 · 필살기 감속 시간 +1초"
	if state.id == BARRIER_LENS_ID: return "방벽 렌즈 · 방벽 잔량이 있으면 스킬1.25배"
	if state.id == CHARM_ID: return "위기의 부적 · 위기 전투 피해 -20%"
	if state.id == FEATHER_ID: return "청명의 깃털 · 고체력 기본1.25배"
	if state.id == NECKLACE_ID: return "생명의 목걸이 · 생명 흡수 +5%p"
	if state.id == WHISTLE_ID: return "응원의 호루라기 · 정확 회피 +3"
	if state.id == RUNE_ID: return "마력의 문장 · 스킬 피해 1.2배"
	if state.id == COMPASS_ID: return "숲의 나침반 · 구슬 거리 1.5배"
	if state.id == COIN_ID: return "수집가의 동전 · 처치 게이지 +3"
	if state.id == CUP_ID: return "새벽의 잔 · 회복약 +5%p"
	if state.id == SEAL_ID: return "수호의 인장 · 받는 전투 피해 -10%"
	if state.id == WIND_ID: return "바람의 매듭 · 지상 회피 대기 -20%"
	if state.id == SEED_ID: return "생명의 씨앗 · 회복 구슬 +5%p"
	if state.id == DUEL_ID: return "결투의 문장 · 기본 공격 1.2배"
	if state.id == HOURGLASS_ID:
		return "모래시계 · 전투 게이지 +25%"
	if state.id == EMBER_ID:
		return "여명의 불씨 · 모든 무기 피해 1.1배"
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
		var detail: String = {
			IRON_LEAF_ID: "방벽 흡수 전 · 낙하 피해 유지",
			LAST_SPARK_ID: "모든 무기 스킬 · 현재 체력 기준",
			SWORD_PENDANT_ID: "기본·스킬·공격 필살기 적용",
			BOW_PENDANT_ID: "기본·스킬·공격 필살기 적용",
			TEMPO_BELL_ID: "모든 무기 · 게이지 최대100",
			SKILL_PRISM_ID: "모든 무기 · 게이지 최대100",
			DAWN_DIAL_ID: "다음 발동부터 · 여운과 합산",
			BARRIER_LENS_ID: "모든 무기 스킬 · 적중 시 잔량 기준",
			CHARM_ID: "타격 전 체력 기준 · 경직 유지", FEATHER_ID: "성장·장비 뒤 최종 반올림",
			NECKLACE_ID: "과잉 피해 제외 · 만피/조회 회복 없음", WHISTLE_ID: "기존 적중/처치 게이지 유지 · 최대100",
			RUNE_ID: "스킬만 강화 · 흡수는 실제 피해 기준", COMPASS_ID: "기본1.14m · 넓은 자석3.42m",
			COIN_ID: "처치당 한 번 · 선택 이후 적용", CUP_ID: "현재 최대 체력 기준 · 소수 올림",
			HOURGLASS_ID: "기본5 · 스킬10 · 회피15", EMBER_ID: "성장·장비 뒤 적용 · 감속 유지",
			CLOCK_ID: "스킬만 적용 · 공격/회피 유지", DEW_ID: "구슬·휴식·흡수 회복 유지",
			SEAL_ID: "파괴 핵 반영 후 적용 · 경직 유지", WIND_ID: "획득 전 회피의 남은 대기 유지",
			SEED_ID: "현재 최대 체력 기준 · 소수 올림", DUEL_ID: "보조 무기도 적용 · 근접 활 보정 유지",
		}.get(offer.id, "해당 계열만 적용 · 성장/장비 뒤 반올림" if offer.has("weapon") else "소비한 깃털은 재부활 불가")
		lines.append(detail)
		var status := "이번 도전 · 사용 완료" if owned and bool(state.get("used", false)) else "이번 도전 · 보유 중" if owned else "미보유 · 효과 미리 보기"
		result.append({"id": offer.id, "name": offer.name, "open": owned, "status": status, "lines": lines})
	return result
