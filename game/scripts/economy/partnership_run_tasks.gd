class_name PartnershipRunTasks
extends RefCounted

## GP-961–1002: two-weapon and supply goals use the existing run counters/ledger.
static func definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for first in AdvancedRunTasks.FAMILIES.size():
		for second in range(first + 1, AdvancedRunTasks.FAMILIES.size()):
			var a: String = AdvancedRunTasks.FAMILIES[first]
			var b: String = AdvancedRunTasks.FAMILIES[second]
			var name: String = AdvancedRunTasks.NAMES[first] + "·" + AdvancedRunTasks.NAMES[second]
			for style in ["practice", "arsenal"]:
				var goals: Array[Dictionary] = []
				for family in [a, b]:
					goals.append(AdvancedRunTasks._goal("family_hits" if style == "practice" else "family_damage", 8 if style == "practice" else 600, PrototypeWeaponRewards.family_name(family) + (" 적중" if style == "practice" else " 피해"), family))
					if style == "arsenal": goals.append(AdvancedRunTasks._goal("family_grade", 1, PrototypeWeaponRewards.family_name(family) + " 등급", family))
				result.append({"id":"pair_" + a + "_" + b + "_" + style, "name":name + (" · 교차 수련" if style == "practice" else " · 함께 전진"), "kind":"compound", "category":"combat", "families":[a,b], "target":goals.size(), "coins":10 if style == "practice" else 15, "hint":"두 무기 각각 기술8적중" if style == "practice" else "두 무기 각각 피해600·희귀 이상", "goals":goals})
	var specs := [
		["meal_clock", "식사와 새벽시계", [_goal("supply_service",1,"식사","heal"),_goal("supply_service",1,"충전","gauge")], 5],
		["potion_workshop", "약방과 정비소", [_goal("supply_service",1,"회복약","potion"),_goal("supply_service",1,"정비","refresh")], 5],
		["recovery_plan", "든든한 회복 준비", [_goal("supply_service",1,"식사","heal"),_goal("supply_service",1,"회복약","potion")], 5],
		["battle_ready", "다시 전장으로", [_goal("supply_service",1,"충전","gauge"),_goal("supply_service",1,"정비","refresh")], 5],
		["all_services", "보급소 한 바퀴", [_goal("supply_service",1,"식사","heal"),_goal("supply_service",1,"회복약","potion"),_goal("supply_service",1,"충전","gauge"),_goal("supply_service",1,"정비","refresh")], 10],
		["maintained_journey", "꾸준한 재정비", [_goal("supply_services",4,"서비스 구매"),_goal("stage",3,"구간 완료")], 10],
		["varied_basket", "다채로운 장바구니", [_goal("supply_purchases",5,"상품 구매"),_goal("supply_variety",3,"서로 다른 상품")], 10],
		["supply_investment", "여정에 투자", [_goal("supply_spent",100,"사용한 보급전"),_goal("stage",3,"구간 완료")], 10],
		["long_investment", "긴 여정의 준비", [_goal("supply_spent",200,"사용한 보급전"),_goal("stage",5,"구간 완료")], 15],
		["stock_explorer", "새 재고 탐색", [_goal("supply_rerolls",2,"재입고"),_goal("supply_variety",4,"서로 다른 상품")], 10],
		["two_upgrades", "두 번의 담금질", [_goal("supply_upgrades",2,"무기 승급 구매"),_goal("stage",2,"구간 완료")], 10],
		["skill_basket", "전투의 선택지", [_goal("supply_skills",2,"스킬 구매"),_goal("supply_variety",3,"서로 다른 상품")], 10],
	]
	for spec in specs:
		var hints: Array[String] = []
		for goal in spec[2]: hints.append("%s%d" % [goal.label,goal.target])
		result.append({"id":"supply_trial_" + spec[0], "name":spec[1], "kind":"compound", "category":"trade", "target":spec[2].size(), "coins":spec[3], "hint":" + ".join(hints), "goals":spec[2]})
	return result

static func _goal(kind: String, target: int, label: String, key: String = "") -> Dictionary:
	return AdvancedRunTasks._goal(kind,target,label,key)

static func value(goal: Dictionary, state: Dictionary) -> int:
	var result := 0
	var distinct := {}
	for action in state.get("supplies",{}).get("actions",[]):
		var id := String(action.get("id",""))
		if id.begins_with(RunTasks.PREFIX): continue
		if id == "reroll":
			if goal.kind == "supply_rerolls": result += 1
			elif goal.kind == "supply_spent": result += RunSupplyShop.REROLL_COST
			continue
		var product := RunSupplyShop.product(id,int(action.get("stage",1)))
		if product.is_empty(): continue
		distinct[id] = true
		match goal.kind:
			"supply_service":
				if id == goal.key: result += 1
			"supply_services":
				if product.kind == "service": result += 1
			"supply_purchases": result += 1
			"supply_spent": result += int(product.cost)
			"supply_upgrades":
				if product.kind == "weapon": result += 1
			"supply_skills":
				if product.kind == "skill": result += 1
	return distinct.size() if goal.kind == "supply_variety" else result
