class_name WeaponCatalogBrowser
extends RefCounted

const FAMILIES := ["모든 계열","검","활","주먹","지팡이","장봉","방패"]
const GRADES := ["모든 등급","일반","희귀","영웅"]
const OWNERS := ["전체 장비","장착 중","미장착"]
const CONDITIONS := ["모든 조건","상시","평정","역전","결계","지상","공중"]
const ORDERS := ["목록순","이름순","기본 피해순","스킬 피해순"]

static func defaults() -> Dictionary:
	return {"family":0,"grade":0,"owner":0,"condition":0,"order":0}

static func toolbar(safe: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for index in 5: result.append(HeroStatusView.box(safe,.05+index*.182,.34,.172,.06))
	return result

static func score(card: Dictionary,equipment: Dictionary,blueprints: Dictionary,kind: String,context: Dictionary) -> Dictionary:
	var family := String(card.weapon)
	var held := equipment.duplicate()
	var designs := blueprints.duplicate()
	var carried := held.has(family) and PrototypeWeaponRewards.valid_equipment(held)
	if not carried:
		var other := "bow" if family != "bow" else "sword"
		held = {family:0,other:0}
		designs = {family:"",other:""}
	var before := PrototypeWeaponRewards.damage_multiplier(held,family,kind,designs,context)
	held[family] = int(card.grade)
	designs[family] = String(card.blueprint)
	return {"before":before,"after":PrototypeWeaponRewards.damage_multiplier(held,family,kind,designs,context),"carried":carried}

static func query(unlocked: Dictionary,equipment: Dictionary,blueprints: Dictionary,active: String,context: Dictionary,options: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in PrototypeWeaponRewards.codex_cards(unlocked,equipment,blueprints,active,context):
		var family := int(options.get("family",0))
		if family > 0 and entry.weapon != PrototypeWeaponRewards.FAMILY_IDS[family-1]: continue
		var grade := int(options.get("grade",0))
		if grade > 0 and int(entry.grade) != grade-1: continue
		var owner := int(options.get("owner",0))
		if (owner == 1 and not entry.equipped) or (owner == 2 and entry.equipped): continue
		var profile := PrototypeWeaponRewards.profile(entry.weapon,int(entry.grade),entry.blueprint)
		var condition := int(options.get("condition",0))
		if condition == 1 and not String(profile.condition).is_empty(): continue
		if condition > 1 and profile.condition != ConditionalWeaponDesigns.STYLES[condition-2]: continue
		var card := entry.duplicate(true)
		card.basic_score = score(card,equipment,blueprints,"basic",context)
		card.skill_score = score(card,equipment,blueprints,"skill",context)
		if card.basic_score.carried:
			card.lines.append("장비100 기준 · 기본%d→%d / 스킬%d→%d" % [roundi(card.basic_score.before*100),roundi(card.basic_score.after*100),roundi(card.skill_score.before*100),roundi(card.skill_score.after*100)])
		else: card.lines.append("장비100 기준 · 기본%d / 스킬%d · 휴대 시 비교" % [roundi(card.basic_score.after*100),roundi(card.skill_score.after*100)])
		result.append(card)
	var order := int(options.get("order",0))
	if order != 0:
		result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			if order == 1 and a.name != b.name: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0
			var left: float = a.basic_score.after if order == 2 else a.skill_score.after
			var right: float = b.basic_score.after if order == 2 else b.skill_score.after
			if order in [2,3] and not is_equal_approx(left,right): return left > right
			return a.id < b.id)
	return result

static func empty_card() -> Dictionary:
	return {"id":"","name":"표시할 무기 없음","open":false,"status":"필터를 바꿔 보세요","lines":["현재 조건에 맞는 장비가 없습니다","도감 조회는 장비를 변경하지 않습니다"]}
