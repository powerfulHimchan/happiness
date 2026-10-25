class_name PrototypeCombatTactics
extends RefCounted

## GP-668–709. Persist choices in growth ranks; evaluate conditions at the existing damage/recharge boundary.
const STYLES := ["ground_skill", "air_basic", "barrier_basic", "barrier_skill", "calm_rhythm", "crisis_rhythm"]
const TITLES := {
	"sword": ["대지의 검술", "공중 발검", "검의 결계", "결계 검무", "평정의 검로", "역전의 검로"],
	"bow": ["대지의 궁술", "공중 사격", "시위의 결계", "결계 화살", "평정의 시위", "역전의 시위"],
	"fist": ["대지의 권법", "공중 권격", "주먹의 결계", "결계 권법", "평정의 호흡", "역전의 호흡"],
	"staff": ["대지의 주문", "공중 마력탄", "마력의 결계", "결계 주문", "평정의 주문", "역전의 주문"],
	"polearm": ["대지의 봉술", "공중 봉격", "장봉의 결계", "결계 봉무", "평정의 순환", "역전의 순환"],
	"shield": ["대지의 서약", "공중 방패격", "방패의 결계", "결계 강타", "평정의 서약", "역전의 서약"],
}
const LINES := [
	["지상 스킬 피해 ×1.15", "피해 계산 시 착지 상태 기준"],
	["공중 기본 공격 피해 ×1.20", "피해 계산 시 공중 상태 기준"],
	["방벽 잔량: 기본 공격 ×1.20", "같은 무기 결계 스킬과 택1"],
	["방벽 잔량: 스킬 피해 ×1.20", "같은 무기 결계 기본과 택1"],
	["체력80% 이상: 재충전 ×1.10", "같은 무기 역전과 택1 · 보조도 적용"],
	["체력30% 이하: 재충전 ×1.20", "같은 무기 평정과 택1 · 보조도 적용"],
]
const SUPPORT: Array[Dictionary] = [
	{"id":"evasive_barrier_master", "title":"회피 결계 완성", "requires":["evasive_barrier_boost"], "lines":["정확 회피 방벽 회복 8→11", "회피당 한 번 · 방벽 최대치까지"]},
	{"id":"restorative_barrier_master", "title":"회복 결계 완성", "requires":["restorative_barrier_boost"], "lines":["회복약 소비 시 방벽 회복 15→20", "체력 회복량·소지 개수 유지"]},
	{"id":"victory_resilience_master", "title":"승리의 재생", "requires":["victory_resilience"], "lines":["처치 체력 회복 4%→5%", "최대 체력 기준 · 원정 회복 규칙 적용"]},
	{"id":"orb_bloom_master", "title":"생명의 개화", "requires":["orb_bloom"], "lines":["회복 구슬 회복 25%→30%", "최대 체력 기준 · 소수 올림"]},
	{"id":"time_attunement_master", "title":"시간 공명", "requires":["time_attunement"], "lines":["적중 게이지 기본6/스킬12", "유물과 합산 · 최대100"]},
	{"id":"nimble_master", "title":"바람의 발걸음", "requires":["nimble_mastery"], "lines":["지상 회피 대기 추가 ×0.90", "민첩·숙련·유물과 곱연산 · 무적 유지"]},
]
static var CARDS: Array[Dictionary] = _build_cards()

static func _build_cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for family in PrototypeWeaponMastery.FAMILIES:
		for index in STYLES.size():
			var style: String = STYLES[index]
			var requires := [family+"_mastery_ground"] if style == "ground_skill" else [family+"_mastery_air"] if style == "air_basic" else [family+"_power", "magic_barrier"] if style.begins_with("barrier") else [family+"_mastery_rhythm"]
			var card := {"id":family+"_tactic_"+style, "title":TITLES[family][index], "category":family, "lines":LINES[index].duplicate(), "tags":PrototypeWeaponMastery.TAGS[family].duplicate(), "max_rank":1, "requires":requires, "tactic_style":style}
			var opposite := "barrier_skill" if style == "barrier_basic" else "barrier_basic" if style == "barrier_skill" else "crisis_rhythm" if style == "calm_rhythm" else "calm_rhythm" if style == "crisis_rhythm" else ""
			if not opposite.is_empty(): card.excludes = [family+"_tactic_"+opposite]
			result.append(card)
	for support in SUPPORT:
		var card := support.duplicate(true)
		card.merge({"category":"common", "tags":{"nature":0.75, "determination":0.75}, "max_rank":1})
		result.append(card)
	return result

static func selected(ranks: Dictionary) -> Dictionary:
	var result := {}
	for card in CARDS:
		if int(ranks.get(card.id,0)) == 1: result[card.id] = 1
	return result

static func active(style: String, grounded: bool, health: int, maximum: int, barrier: int) -> bool:
	if health <= 0 or maximum <= 0: return false
	match style:
		"ground_skill": return grounded
		"air_basic": return not grounded
		"barrier_basic", "barrier_skill": return barrier > 0
		"calm_rhythm": return health*5 >= maximum*4
		"crisis_rhythm": return health*10 <= maximum*3
	return false

static func damage_multiplier(ranks: Dictionary, family: String, kind: String, grounded: bool, health: int, maximum: int, barrier: int) -> float:
	if family not in PrototypeWeaponMastery.FAMILIES or kind not in ["basic","skill"]: return 1.0
	var value := 1.0
	for style in ["ground_skill","air_basic","barrier_basic","barrier_skill"]:
		if int(ranks.get(family+"_tactic_"+style,0)) != 1 or not active(style,grounded,health,maximum,barrier): continue
		if (kind == "basic" and style.ends_with("basic")) or (kind == "skill" and style.ends_with("skill")):
			value *= 1.15 if style == "ground_skill" else 1.20
	return value

static func recharge_multiplier(ranks: Dictionary, family: String, health: int, maximum: int) -> float:
	if family not in PrototypeWeaponMastery.FAMILIES: return 1.0
	if int(ranks.get(family+"_tactic_calm_rhythm",0)) == 1 and active("calm_rhythm",true,health,maximum,0): return 1.10
	if int(ranks.get(family+"_tactic_crisis_rhythm",0)) == 1 and active("crisis_rhythm",true,health,maximum,0): return 1.20
	return 1.0

static func condition_lines(ranks: Dictionary, family: String, grounded: bool, health: int, maximum: int, barrier: int) -> Array[String]:
	var result: Array[String] = []
	for card in CARDS:
		if card.category != family or not ranks.has(card.id): continue
		result.append(("적용 · " if active(card.tactic_style,grounded,health,maximum,barrier) else "대기 · ")+String(card.title))
	return result
