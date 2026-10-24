class_name RunSupplyShop
extends RefCounted

## Per-run, checkpointed supplies. Prices and coin earnings are reconstructed from a ledger.
const CLEAR_COINS := 40
const REROLL_COST := 10
const PAGE_SIZE := 3
const ROUTE_BONUS := {"meadow":0,"wind":5,"forest":5,"clockwork":10,"ruins":15,"festival":10,"city_gate":15,"city_core":0}
const SERVICES := {
	"heal": {"name":"따뜻한 식사","cost":20,"lines":["최대 체력의30% 회복","원정 회복 제한 적용"]},
	"potion": {"name":"회복약 보충","cost":25,"lines":["회복약1개 보충","현재 조제·최대 소지 유지"]},
	"gauge": {"name":"새벽시계 충전","cost":15,"lines":["필살기 게이지 +30","최대100 · 사용 중 효과 유지"]},
	"refresh": {"name":"기술 정비","cost":15,"lines":["두 휴대 무기의 스킬 대기 초기화","기본 공격 대기는 유지"]},
}

static func seed_for(run_id: String) -> int:
	var value := 17
	for index in run_id.length(): value = (value*31+run_id.unicode_at(index)) % 1000000007
	return value

static func create(run_id: String) -> Dictionary:
	return {"seed":seed_for(run_id),"cleared":0,"coins":0,"actions":[],"stock":[],"tasks":1}

static func reward(route: String) -> int:
	return CLEAR_COINS+int(ROUTE_BONUS.get(route,0))

static func rerolled(shop: Dictionary, stage: int) -> bool:
	return shop.get("actions",[]).any(func(action: Dictionary) -> bool: return int(action.stage) == stage and action.id == "reroll")

static func sold(shop: Dictionary, id: String) -> bool:
	return shop.get("actions",[]).any(func(action: Dictionary) -> bool: return int(action.stage) == int(shop.cleared) and action.id == id)

static func stock(seed: int, stage: int, roll: int, skills: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in SERVICES: result.append({"id":id,"skill":""})
	for family in PrototypeWeaponRewards.FAMILY_IDS:
		if not skills.has(family): continue
		result.append({"id":"weapon_"+family,"skill":""})
		var pool: Array = PrototypeSkillRewards.pool_for(family).filter(func(id: String) -> bool: return id not in skills[family])
		var offset := posmod(seed+stage*7+roll*3+PrototypeWeaponRewards.FAMILY_IDS.find(family),pool.size())
		for index in 2:
			result.append({"id":"skill_"+family+"_"+str(index),"skill":pool[posmod(offset+index,pool.size())]})
	return result

static func grant(shop: Dictionary, stage: Dictionary, skills: Dictionary) -> void:
	if shop.is_empty() or int(stage.number) >= int(stage.limit) or int(stage.number) <= int(shop.cleared): return
	# The stage runner only advances sequentially. No award on repeated metric notifications.
	for entry in stage.history:
		if int(entry.stage) > int(shop.cleared) and int(entry.stage) <= int(stage.number): shop.coins += reward(String(entry.route))
	shop.cleared = int(stage.number)
	shop.stock = stock(int(shop.seed),int(shop.cleared),0,skills)

static func product(id: String, stage: int) -> Dictionary:
	if SERVICES.has(id):
		var item: Dictionary = SERVICES[id].duplicate(true)
		item.merge({"id":id,"kind":"service","family":""})
		return item
	for family in PrototypeWeaponRewards.FAMILY_IDS:
		if id == "weapon_"+family:
			var grade := mini(stage,2)
			return {"id":id,"kind":"weapon","family":family,"name":PrototypeWeaponRewards.family_name(family)+" 승급","cost":40 if grade == 1 else 70,"grade":grade,"lines":[PrototypeWeaponRewards.profile(family,grade).name,"일반 설계로 승급 · 스킬 슬롯 유지"]}
		if id in ["skill_"+family+"_0","skill_"+family+"_1"]:
			return {"id":id,"kind":"skill","family":family,"name":PrototypeWeaponRewards.family_name(family)+" 기술 추천 "+("1" if id.ends_with("_0") else "2"),"cost":35,"lines":[]}
	return {}

static func find_offer(shop: Dictionary, id: String) -> Dictionary:
	for offer in shop.get("stock",[]):
		if offer.id == id: return offer
	return {}

static func blocked(shop: Dictionary, id: String, context: Dictionary) -> String:
	if shop.is_empty() or int(shop.cleared) <= 0: return "이전 저장 · 새 도전부터 이용"
	var offer := find_offer(shop,id)
	var item := product(id,int(shop.cleared))
	if item.is_empty() or offer.is_empty(): return "이번 재고에 없는 상품"
	if sold(shop,id): return "이번 휴식에서 구매 완료"
	if int(shop.coins) < int(item.cost): return "보급전 부족"
	if item.kind == "weapon":
		if not context.equipment.has(item.family): return "휴대하지 않은 무기"
		if int(context.equipment[item.family]) >= int(item.grade): return "같거나 높은 등급 보유"
	elif item.kind == "skill":
		if not context.skills.has(item.family): return "휴대하지 않은 무기"
		if offer.skill in context.skills[item.family]: return "이미 장착한 스킬"
	else:
		match id:
			"heal":
				if context.health >= context.max_health: return "체력이 가득합니다"
			"potion":
				if context.potions >= context.potion_capacity: return "회복약이 가득합니다"
			"gauge":
				if context.gauge >= 100: return "게이지가 가득합니다"
			"refresh":
				if context.cooldowns.values().all(func(pair: Array) -> bool: return float(pair[0]) <= 0 and float(pair[1]) <= 0): return "정비할 스킬 대기 없음"
	return ""

static func cards(shop: Dictionary, context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if shop.is_empty(): return result
	for offer in shop.stock:
		var item := product(String(offer.id),int(shop.cleared))
		if item.kind == "skill":
			item.name = PrototypeSkillRewards.SKILLS[offer.skill].display_name
			item.lines = PrototypeSkillRewards.lines(String(offer.skill),float(context.get("family_recharge",{}).get(item.family,1.0))).slice(0,3)
		elif item.kind == "weapon":
			item.lines.append("현재: "+PrototypeWeaponRewards.profile(item.family,int(context.equipment[item.family]),String(context.blueprints[item.family])).name)
		item.skill = offer.skill
		item.reason = blocked(shop,item.id,context)
		item.ready = item.reason.is_empty()
		result.append(item)
	return result

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= low and value <= high

static func valid_state(value: Variant, checkpoint: Dictionary) -> bool:
	if not value is Dictionary or value.size() != (6 if value.has("tasks") else 5): return false
	if value.has("tasks") and not _integer(value.tasks,1,1): return false
	if not checkpoint.get("weapons") is Dictionary or not checkpoint.weapons.get("equipment") is Dictionary: return false
	var stage: Dictionary = checkpoint.stage
	var expected := mini(int(stage.number),int(stage.limit)-1)
	if not _integer(value.get("seed"),0,1000000006) or int(value.seed) != seed_for(String(checkpoint.recorder.id)) or not _integer(value.get("cleared"),expected,expected) or not _integer(value.get("coins"),0,10000) or not value.get("actions") is Array or value.actions.size() > 9*11+RunTasks.DEFINITIONS.size() or not value.get("stock") is Array: return false
	var spent := 0
	var last := 0
	var seen := {}
	var ledger: Array = []
	var task_ids := {}
	for action in value.actions:
		if not action is Dictionary or action.size() != 4 or not _integer(action.get("stage"),1,expected) or not action.get("id") is String or not action.get("skill") is String or not _integer(action.get("slot"),-1,1): return false
		var number := int(action.stage)
		if number < last or (number == int(stage.number) and stage.get("reward_claimed",false) != true): return false
		last = number
		var key := str(number)+":"+String(action.id)
		if seen.has(key): return false
		seen[key] = true
		if String(action.id).begins_with(RunTasks.PREFIX):
			var task_state := checkpoint.duplicate()
			task_state.supplies = value.duplicate()
			task_state.supplies.actions = ledger
			task_state.stage = stage.duplicate()
			task_state.stage.history = stage.history.filter(func(entry: Dictionary) -> bool: return int(entry.stage) <= number)
			if not RunTasks.valid_receipt(action,value,task_state): return false
			if task_ids.has(action.id): return false
			task_ids[action.id] = true
			spent -= int(RunTasks.definition(String(action.id).trim_prefix(RunTasks.PREFIX)).coins)
		elif action.id == "reroll":
			if action.skill != "" or action.slot != -1: return false
			spent += REROLL_COST
		else:
			var item := product(action.id,number)
			if item.is_empty(): return false
			if item.kind in ["weapon","skill"] and not checkpoint.weapons.equipment.has(item.family): return false
			if item.kind == "skill":
				if int(action.slot) not in [0,1] or PrototypeSkillRewards.weapon_for(action.skill) != item.family: return false
			elif action.skill != "" or action.slot != -1: return false
			spent += int(item.cost)
		var earned := 0
		for entry in stage.history:
			if int(entry.stage) <= number: earned += reward(String(entry.route))
		if spent > earned: return false
		ledger.append(action)
	var earned := 0
	for entry in stage.history:
		if int(entry.stage) <= expected: earned += reward(String(entry.route))
	if int(value.coins) != earned-spent or value.stock.size() != 4+checkpoint.weapons.equipment.size()*3: return false
	seen.clear()
	var skills := {}
	for offer in value.stock:
		if not offer is Dictionary or offer.size() != 2 or not offer.get("id") is String or not offer.get("skill") is String or seen.has(offer.id): return false
		seen[offer.id] = true
		var item := product(offer.id,expected)
		if item.is_empty(): return false
		if item.kind in ["weapon","skill"] and not checkpoint.weapons.equipment.has(item.family): return false
		if item.kind == "skill":
			if PrototypeSkillRewards.weapon_for(offer.skill) != item.family or skills.has(offer.skill): return false
			skills[offer.skill] = true
		elif offer.skill != "": return false
	return SERVICES.keys().all(func(id: String) -> bool: return seen.has(id))
