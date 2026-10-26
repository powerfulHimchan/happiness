class_name SupplyShopBrowser
extends RefCounted

const KINDS := ["모든 상품","회복·정비","무기 승급","스킬"]
const READY := ["모든 상태","구매 가능","구매 불가"]
const FAMILIES := ["모든 무기","주 무기","보조 무기"]
const ORDERS := ["목록순","낮은 가격순","높은 가격순","이름순"]
const KEYS := ["kind","ready","family","order"]
const COUNTS := [4,3,3,4]

static func defaults() -> Dictionary:
	return {"kind":0,"ready":0,"family":0,"order":0}

static func query(data: Dictionary,options: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var context: Dictionary = data.get("context",{})
	var held: Array = context.get("equipment",{}).keys()
	var active := String(context.get("active",""))
	var backup := ""
	for family in held:
		if family != active: backup = String(family)
	for item in data.get("cards",[]):
		var kind := int(options.get("kind",0))
		if kind > 0 and item.kind != ["service","weapon","skill"][kind-1]: continue
		var ready := int(options.get("ready",0))
		if (ready == 1 and not item.ready) or (ready == 2 and item.ready): continue
		var family := int(options.get("family",0))
		if family > 0 and not String(item.family).is_empty() and item.family != (active if family == 1 else backup): continue
		result.append(item.duplicate(true))
	var order := int(options.get("order",0))
	if order != 0:
		result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			if order in [1,2] and a.cost != b.cost: return int(a.cost) < int(b.cost) if order == 1 else int(a.cost) > int(b.cost)
			if order == 3 and a.name != b.name: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0
			return a.id < b.id)
	return result

static func ledger(shop: Dictionary,history: Array) -> Dictionary:
	var income := 0
	for stage in history:
		if int(stage.stage) <= int(shop.get("cleared",0)): income += RunSupplyShop.reward(String(stage.route))
	var tasks := 0
	var spent := 0
	var lines: Array[String] = []
	for action in shop.get("actions",[]):
		var name := "기술 재입고"
		var amount := RunSupplyShop.REROLL_COST
		var sign_label := "-"
		if String(action.id).begins_with(RunTasks.PREFIX):
			var task := RunTasks.definition(String(action.id).trim_prefix(RunTasks.PREFIX))
			name = String(task.name)
			amount = int(task.coins)
			tasks += amount
			sign_label = "+"
		else:
			if action.id != "reroll":
				var item := RunSupplyShop.product(action.id,int(action.stage))
				name = String(PrototypeSkillRewards.SKILLS[action.skill].display_name) if item.kind == "skill" else String(item.name)
				amount = int(item.cost)
			spent += amount
		lines.append("%d구간 · %s · %s%d전" % [action.stage,name,sign_label,amount])
	return {"route_income":income,"task_income":tasks,"spent":spent,"balance":int(shop.get("coins",0)),"lines":lines}

static func restock(shop: Dictionary,context: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if shop.is_empty() or int(shop.get("cleared",0)) <= 0: return ["새 도전의 첫 휴식부터 확인할 수 있습니다"]
	if RunSupplyShop.rerolled(shop,int(shop.cleared)): return ["이번 휴식은 이미 재입고했습니다"]
	var next := RunSupplyShop.stock(int(shop.seed),int(shop.cleared),1,context.skills)
	for offer in next:
		if String(offer.skill).is_empty(): continue
		var previous := RunSupplyShop.find_offer(shop,String(offer.id))
		var old := String(PrototypeSkillRewards.SKILLS[previous.skill].display_name)
		var fresh := String(PrototypeSkillRewards.SKILLS[offer.skill].display_name)
		lines.append(old+" → "+fresh)
	lines.append("확정 시10전 · 회복/승급 재고와 구매 이력 유지")
	return lines

static func details(item: Dictionary,data: Dictionary) -> Array[String]:
	if item.is_empty(): return ["보급소에서 상품을 먼저 선택하세요"]
	var lines: Array[String] = [String(item.name),("%d전 · 구매 후 잔액 %d전" % [item.cost,int(data.coins)-int(item.cost)] if int(data.coins) >= int(item.cost) else "%d전 · %d전 부족" % [item.cost,int(item.cost)-int(data.coins)])]
	for line in item.lines: lines.append(String(line))
	if item.kind == "skill":
		var context: Dictionary = data.context
		var fresh: Array = context.get("skill_damage",{}).get(item.skill,[])
		for slot in 2:
			var id: String = context.skills[item.family][slot]
			var current: Array = context.get("skill_damage",{}).get(id,[])
			lines.append("슬롯%d %s · 타격합 %d→%d" % [slot+1,PrototypeSkillRewards.SKILLS[id].display_name,total(current),total(fresh)])
		lines.append("타격합은 각 기본 타격의 합 · 발사 수/중복 범위/치명타 제외")
	lines.append(String(item.reason) if not item.ready else "구매 가능 · 상세 열람은 구매하지 않습니다")
	return lines

static func total(values: Array) -> int:
	var result := 0
	for value in values: result += int(value)
	return result
