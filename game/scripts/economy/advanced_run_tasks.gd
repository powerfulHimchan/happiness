class_name AdvancedRunTasks
extends RefCounted

## GP-618–659: conjunctive objectives derived from checkpointed gameplay, never UI visits.
const FAMILIES := ["sword", "bow", "fist", "staff", "polearm", "shield"]
const NAMES := ["검", "활", "주먹", "지팡이", "장봉", "방패"]
const STYLES := ["precision", "growth", "equipment", "discipline", "journey", "expert"]
const TITLES := ["실전 연마", "성장의 증명", "장비의 조화", "단련의 결실", "여정의 수련", "달인의 증명"]

static func _goal(kind: String, target: int, label: String, key: String = "") -> Dictionary:
	return {"kind":kind, "target":target, "label":label, "key":key}

static func definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in FAMILIES.size():
		var family: String = FAMILIES[index]
		for style in STYLES.size():
			var goals: Array[Dictionary] = [_goal("family_hits",[12,18,24,30,36,45][style],NAMES[index]+" 적중",family)]
			match style:
				0: goals.append(_goal("family_damage",600,"무기 피해",family))
				1: goals.append(_goal("level",6,"레벨"))
				2: goals.append(_goal("family_grade",1,"무기 등급",family))
				3: goals.append(_goal("rank",3,"무기 강화",family+"_power"))
				4: goals.append(_goal("stage",4,"구간 완료"))
				5:
					goals.append(_goal("family_damage",2500,"무기 피해",family))
					goals.append(_goal("family_grade",2,"무기 등급",family))
			var hints := ["12적중 + 피해600", "18적중 + 레벨6", "24적중 + 희귀 무기", "30적중 + 무기 강화3", "36적중 + 구간4완료", "45적중·피해2500·영웅"]
			result.append({"id":"trial_"+family+"_"+STYLES[style],"name":NAMES[index]+" · "+TITLES[style],"kind":"compound","category":"combat","family":family,"target":goals.size(),"coins":[5,5,10,10,10,15][style],"hint":hints[style],"goals":goals})
	var routes := ["meadow","wind","forest","ruins","festival","city_gate"]
	var names := ["풀숲의 성장", "바람의 기교", "숲의 깨달음", "별시계의 전투", "축제의 준비", "성문의 증명"]
	var second := [_goal("level",5,"레벨"),_goal("hits",20,"전체 기술 적중"),_goal("level",7,"레벨"),_goal("damage",2000,"전체 무기 피해"),_goal("equipment",2,"희귀 이상 무기"),_goal("level",10,"레벨")]
	var hints := ["풀숲2완료 + 레벨5", "바람2완료 + 기술20적중", "숲2완료 + 레벨7", "유적2완료 + 피해2000", "축제2완료 + 희귀2무기", "성문완료 + 레벨10"]
	for index in routes.size():
		var goals: Array[Dictionary] = [_goal("route",1 if index == 5 else 2,"지역 완료",routes[index]),second[index]]
		result.append({"id":"trial_route_"+routes[index],"name":names[index],"kind":"compound","category":"explore","route":routes[index],"target":2,"coins":15,"hint":hints[index],"goals":goals})
	return result

static func _value(goal: Dictionary, state: Dictionary) -> int:
	if String(goal.kind).begins_with("supply_"): return PartnershipRunTasks.value(goal,state)
	var weapons: Dictionary = state.get("weapons",{})
	var equipment: Dictionary = weapons.get("equipment",{})
	var growth: Dictionary = state.get("growth",{})
	var history: Array = state.get("stage",{}).get("history",[])
	match goal.kind:
		"family_hits", "family_damage":
			if not equipment.has(goal.key): return 0
			return int(weapons.get(goal.key,{}).get("skill_hit_count" if goal.kind == "family_hits" else "total_damage",0))
		"family_grade": return int(equipment.get(goal.key,0))
		"level": return int(growth.get("level",1))
		"rank": return int(growth.get("ranks",{}).get(goal.key,0))
		"stage": return history.size()
		"route": return history.filter(func(entry: Dictionary) -> bool: return entry.get("route","") == goal.key).size()
		"equipment": return equipment.values().filter(func(grade: Variant) -> bool: return int(grade) >= 1).size()
		"hits", "damage":
			var total := 0
			for family in equipment: total += int(weapons.get(family,{}).get("skill_hit_count" if goal.kind == "hits" else "total_damage",0))
			return total
	return 0

static func conditions(task: Dictionary, state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for goal in task.goals:
		result.append({"label":goal.label,"progress":clampi(_value(goal,state),0,int(goal.target)),"target":int(goal.target)})
	return result

static func progress(task: Dictionary, state: Dictionary) -> int:
	return conditions(task,state).filter(func(goal: Dictionary) -> bool: return goal.progress >= goal.target).size()

static func fraction(task: Dictionary, state: Dictionary) -> float:
	var total := 0.0
	for goal in conditions(task,state): total += float(goal.progress)/float(goal.target)
	return total/float(task.goals.size())

static func restriction(task: Dictionary, state: Dictionary) -> String:
	for family in task.get("families",[]):
		if not state.get("weapons",{}).get("equipment",{}).has(family): return "두 무기를 함께 휴대하는 새 도전에서 진행"
	if task.has("family") and not state.get("weapons",{}).get("equipment",{}).has(task.family): return "다른 무기의 새 도전에서 진행"
	var stage: Dictionary = state.get("stage",{})
	for goal in task.goals:
		if goal.kind == "stage" and int(goal.target) >= int(stage.get("limit",10)): return "더 긴 도전에서 진행"
		if goal.kind == "route":
			if goal.key == "meadow" and stage.get("run_mode","standard") in ["journey","regions"]: return "일반 도전에서 진행"
			if goal.key == "city_gate" and stage.get("run_mode","standard") != "journey": return "10스테이지 여정에서 진행"
			if goal.key != "meadow" and stage.get("run_mode","standard") != "journey" and int(stage.get("limit",10)) <= 3: return "5스테이지 도전부터 진행"
	return ""

static func valid_receipt(task: Dictionary, action: Dictionary, state: Dictionary) -> bool:
	# History is already cut to the receipt stage by the supply ledger validator.
	for goal in task.goals:
		if goal.kind in ["stage","route"] and int(action.stage) < int(goal.target): return false
		if goal.kind == "route" and goal.key == "city_gate" and int(action.stage) < 9: return false
	return progress(task,state) == task.goals.size()
