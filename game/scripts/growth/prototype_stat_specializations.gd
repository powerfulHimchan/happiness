class_name PrototypeStatSpecializations
extends RefCounted

const STYLES := ["precision","potency","armor","calm","barrier","ultimate"]
const LABELS := ["정밀 단련","치명 연마","수호 자세","평정의 조준","결계의 일격","결전의 일격"]
const LINES := [["이 무기 치명타 확률 +8%p","기본 공격·스킬·공격형 필살기"],["이 무기 치명타 피해 +25%p","총 치명타 피해 배율에 합산"],["이 무기를 사용 중일 때 방어력 +12","보조 무기로 보관 중에는 미적용"],["체력80% 이상: 이 무기 치명타 확률 +10%p","평정 경계는 실제 타격 시점에 판정"],["방벽 잔량: 이 무기 치명타 피해 +35%p","방벽이 소진되면 적용 종료"],["이 무기 공격형 필살기 치명타 피해 +40%p","기본 공격과 일반 스킬에는 미적용"]]
const COMMON: Array[Dictionary] = [
	{"id":"stat_iron_body","title":"강철의 체질","requires":["stat_defense"],"lines":["방어력 +20","모든 무기에서 적용"]},
	{"id":"stat_insight","title":"치명의 통찰","requires":["stat_critical_chance"],"lines":["치명타 확률 +5%p","모든 무기에서 적용"]},
	{"id":"stat_finisher","title":"치명의 극의","requires":["stat_critical_damage"],"lines":["치명타 피해 +40%p","모든 무기에서 적용"]},
	{"id":"stat_crisis_guard","title":"위기의 철벽","requires":["stat_iron_body"],"lines":["체력30% 이하: 방어력 +20","현재 체력 기준 · 회복하면 조건 재판정"]},
	{"id":"stat_calm_aim","title":"평정의 통찰","requires":["stat_insight"],"lines":["체력80% 이상: 치명타 확률 +8%p","모든 무기에서 적용"]},
	{"id":"stat_barrier_edge","title":"결계의 극의","requires":["stat_finisher","magic_barrier"],"lines":["방벽 잔량: 치명타 피해 +30%p","모든 무기에서 적용"]},
]
static var CARDS: Array[Dictionary] = definitions()

static func definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for family in PrototypeWeaponRewards.FAMILY_IDS:
		for index in STYLES.size():
			var style: String = STYLES[index]
			var requirements := [family+"_power",["stat_critical_chance","stat_critical_damage","stat_defense",family+"_stat_precision","magic_barrier","time_collector"][index]]
			result.append({"id":family+"_stat_"+style,"title":PrototypeWeaponRewards.family_name(family)+" · "+LABELS[index],"category":family,"lines":LINES[index].duplicate(),"requires":requirements,"max_rank":1,"tags":PrototypeWeaponMastery.TAGS[family].duplicate(),"stat_style":style,"ticket":771+result.size()})
	for definition in COMMON:
		var card := definition.duplicate(true)
		card.merge({"category":"common","max_rank":1,"tags":{"nature":0.75,"determination":0.75},"ticket":771+result.size()})
		result.append(card)
	return result

static func selected(ranks: Dictionary) -> Dictionary:
	var result := {}
	for card in CARDS:
		if int(ranks.get(card.id,0)) == 1: result[card.id] = 1
	return result

static func calm(health: int, maximum: int) -> bool:
	return health > 0 and maximum > 0 and health*5 >= maximum*4

static func crisis(health: int, maximum: int) -> bool:
	return health > 0 and maximum > 0 and health*10 <= maximum*3

static func bonuses(ranks: Dictionary,family: String,kind: String,health: int,maximum: int,barrier: int) -> Dictionary:
	var result := {"defense":0,"chance":0.0,"critical_damage":0.0}
	if health <= 0 or maximum <= 0: return result
	if ranks.has("stat_iron_body"): result.defense += 20
	if ranks.has("stat_insight"): result.chance += 5.0
	if ranks.has("stat_finisher"): result.critical_damage += 40.0
	if ranks.has("stat_crisis_guard") and crisis(health,maximum): result.defense += 20
	if ranks.has("stat_calm_aim") and calm(health,maximum): result.chance += 8.0
	if ranks.has("stat_barrier_edge") and barrier > 0: result.critical_damage += 30.0
	if family not in PrototypeWeaponRewards.FAMILY_IDS: return result
	if ranks.has(family+"_stat_precision"): result.chance += 8.0
	if ranks.has(family+"_stat_potency"): result.critical_damage += 25.0
	if ranks.has(family+"_stat_armor"): result.defense += 12
	if ranks.has(family+"_stat_calm") and calm(health,maximum): result.chance += 10.0
	if ranks.has(family+"_stat_barrier") and barrier > 0: result.critical_damage += 35.0
	if ranks.has(family+"_stat_ultimate") and kind == "ultimate": result.critical_damage += 40.0
	return result

static func condition_lines(ranks: Dictionary,active: String,health: int,maximum: int,barrier: int) -> Array[String]:
	var result: Array[String] = []
	for card in CARDS:
		if not ranks.has(card.id): continue
		var applies: bool = card.category == "common" or card.category == active
		var style := String(card.get("stat_style",""))
		if style == "calm" or card.id == "stat_calm_aim": applies = applies and calm(health,maximum)
		if style == "barrier" or card.id == "stat_barrier_edge": applies = applies and barrier > 0
		if card.id == "stat_crisis_guard": applies = applies and crisis(health,maximum)
		result.append(("적용 · " if applies else "대기 · ")+String(card.title)+( " (필살기 전용)" if style == "ultimate" else ""))
	return result
