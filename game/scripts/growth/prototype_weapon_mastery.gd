class_name PrototypeWeaponMastery
extends RefCounted

## GP-515–544. Only ranks are persisted; conditional effects are evaluated when damage is calculated.
const FAMILIES := ["sword", "bow", "fist", "staff", "polearm", "shield"]
const STYLES := ["ground", "air", "focus", "resolve", "rhythm"]
const TITLES := {
	"sword": ["대지의 검격", "비천 검무", "고요한 검심", "불굴의 검의", "유수 검법"],
	"bow": ["굳건한 사격", "하늘의 화살", "명경 조준", "최후의 시위", "속사의 호흡"],
	"fist": ["뿌리내린 권격", "승천 권법", "정심 권의", "역경의 주먹", "연권의 호흡"],
	"staff": ["대지의 마력탄", "천공 주문", "청명한 마력", "불굴의 주문", "원소 순환"],
	"polearm": ["반석 봉격", "비천 봉술", "고요한 봉심", "역경의 봉술", "윤회의 호흡"],
	"shield": ["대지 방패격", "천공 방패술", "명경의 서약", "최후의 수호", "서약의 순환"],
}
const TAGS := {
	"sword": {"strength": 2.5, "determination": 1.5},
	"bow": {"shooting": 2.5, "nature": 1.5},
	"fist": {"technique": 2.5, "chain": 1.5},
	"staff": {"magic": 2.5, "element": 1.5},
	"polearm": {"focus": 2.5, "harmony": 1.5},
	"shield": {"defense": 2.5, "faith": 1.5},
}
const LINES := [
	["지상 기본 공격 피해 ×1.20", "피해 계산 시 착지 상태 기준"],
	["공중 스킬 피해 ×1.25", "피해 계산 시 공중 상태 기준"],
	["체력80% 이상: 스킬 ×1.20", "같은 무기 결의와 택1"],
	["체력30% 이하: 공격·스킬 ×1.25", "같은 무기 집중과 택1"],
	["이 무기 스킬 재충전 ×1.15", "보조도 적용 · 시계추와 곱연산"],
]

static var CARDS: Array[Dictionary] = _build_cards()

static func _build_cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for family in FAMILIES:
		for index in STYLES.size():
			var style: String = STYLES[index]
			var card := {"id": family+"_mastery_"+style, "title": TITLES[family][index], "category": family, "lines": LINES[index].duplicate(), "tags": TAGS[family].duplicate(), "max_rank": 1, "requires": [family+"_power"]}
			if style in ["focus", "resolve"]:
				card.excludes = [family+"_mastery_"+("resolve" if style == "focus" else "focus")]
			result.append(card)
	return result

static func selected(ranks: Dictionary) -> Dictionary:
	var result := {}
	for card in CARDS:
		if int(ranks.get(card.id, 0)) == 1: result[card.id] = 1
	return result

static func damage_multiplier(ranks: Dictionary, family: String, kind: String, grounded: bool, health: int, maximum: int) -> float:
	if family not in FAMILIES or kind not in ["basic", "skill"]: return 1.0
	var prefix := family+"_mastery_"
	var value := 1.0
	if kind == "basic" and grounded and ranks.has(prefix+"ground"): value *= 1.20
	if kind == "skill" and not grounded and ranks.has(prefix+"air"): value *= 1.25
	if kind == "skill" and health*5 >= maximum*4 and ranks.has(prefix+"focus"): value *= 1.20
	if health*10 <= maximum*3 and ranks.has(prefix+"resolve"): value *= 1.25
	return value

static func recharge_multiplier(ranks: Dictionary, family: String) -> float:
	return 1.15 if family in FAMILIES and ranks.has(family+"_mastery_rhythm") else 1.0
