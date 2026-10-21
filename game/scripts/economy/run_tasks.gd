class_name RunTasks
extends RefCounted

## Per-run objectives derive from existing checkpoint counters; viewing never awards coins.
const PREFIX := "task:"
const DEFINITIONS: Array[Dictionary] = [
	{"id":"first_steps","name":"첫 발걸음","kind":"stage","target":1,"coins":5,"hint":"스테이지1개 완료"},
	{"id":"steady_steps","name":"꾸준한 걸음","kind":"stage","target":3,"coins":10,"hint":"스테이지3개 완료"},
	{"id":"long_road","name":"긴 여정","kind":"stage","target":5,"coins":15,"hint":"스테이지5개 완료"},
	{"id":"toward_dawn","name":"새벽을 향해","kind":"stage","target":8,"coins":20,"hint":"스테이지8개 완료"},
	{"id":"meadow_scout","name":"풀숲 탐험가","kind":"route","route":"meadow","target":2,"coins":5,"hint":"풀숲 길2회 완료"},
	{"id":"wind_scout","name":"바람 탐험가","kind":"route","route":"wind","target":2,"coins":5,"hint":"바람 길2회 완료"},
	{"id":"forest_scout","name":"거꾸로 숲 탐험가","kind":"route","route":"forest","target":2,"coins":10,"hint":"거꾸로 자란 숲2회 완료"},
	{"id":"ruins_scout","name":"별시계 탐험가","kind":"route","route":"ruins","target":2,"coins":10,"hint":"별시계 유적2회 완료"},
	{"id":"festival_scout","name":"축제 탐험가","kind":"route","route":"festival","target":2,"coins":10,"hint":"태엽 축제장2회 완료"},
	{"id":"gate_scout","name":"성문 도착","kind":"route","route":"city_gate","target":1,"coins":15,"hint":"행복의 나라 성문 완료"},
	{"id":"damage_500","name":"첫 전투 성과","kind":"damage","target":500,"coins":5,"hint":"무기 누적 피해500"},
	{"id":"damage_1500","name":"힘을 모아서","kind":"damage","target":1500,"coins":10,"hint":"무기 누적 피해1,500"},
	{"id":"damage_3000","name":"전장을 가르는 힘","kind":"damage","target":3000,"coins":15,"hint":"무기 누적 피해3,000"},
	{"id":"skills_10","name":"기술의 시작","kind":"hits","target":10,"coins":5,"hint":"무기 기술 누적10회 적중"},
	{"id":"skills_30","name":"능숙한 기술","kind":"hits","target":30,"coins":10,"hint":"무기 기술 누적30회 적중"},
	{"id":"sword_training","name":"검의 수련","kind":"family","family":"sword","target":10,"coins":10,"hint":"검 기술10회 적중"},
	{"id":"bow_training","name":"활의 수련","kind":"family","family":"bow","target":10,"coins":10,"hint":"활 기술10회 적중"},
	{"id":"fist_training","name":"주먹의 수련","kind":"family","family":"fist","target":10,"coins":10,"hint":"주먹 기술10회 적중"},
	{"id":"staff_training","name":"지팡이의 수련","kind":"family","family":"staff","target":10,"coins":10,"hint":"지팡이 기술10회 적중"},
	{"id":"polearm_training","name":"장봉의 수련","kind":"family","family":"polearm","target":10,"coins":10,"hint":"장봉 기술10회 적중"},
	{"id":"shield_training","name":"방패의 수련","kind":"family","family":"shield","target":10,"coins":10,"hint":"방패 기술10회 적중"},
	{"id":"level_5","name":"성장의 기쁨","kind":"level","target":5,"coins":5,"hint":"레벨5 달성"},
	{"id":"level_10","name":"굳건한 성장","kind":"level","target":10,"coins":10,"hint":"레벨10 달성"},
	{"id":"first_job","name":"나의 길","kind":"job","target":1,"coins":10,"hint":"기본 또는 상위 직업 발현"},
	{"id":"advanced_job","name":"길의 완성","kind":"advanced","target":1,"coins":15,"hint":"상위 직업 진화"},
	{"id":"rare_pair","name":"두 무기의 준비","kind":"equipment","grade":1,"target":2,"coins":10,"hint":"휴대 무기2개 희귀 이상"},
	{"id":"hero_pair","name":"영웅의 장비","kind":"equipment","grade":2,"target":2,"coins":15,"hint":"휴대 무기2개 영웅 등급"},
	{"id":"shop_regular","name":"보급소 단골","kind":"purchases","target":3,"coins":5,"hint":"보급소 상품3개 구매"},
	{"id":"fresh_stock","name":"새로운 가능성","kind":"rerolls","target":2,"coins":5,"hint":"서로 다른 휴식에서 재입고2회"},
	{"id":"prepared_traveler","name":"빈틈없는 준비","kind":"services","target":3,"coins":5,"hint":"회복·충전·정비 서비스3개 구매"},
]

static func definition(id: String) -> Dictionary:
	for task in DEFINITIONS:
		if task.id == id: return task
	return {}

static func enabled(shop: Dictionary) -> bool:
	return shop.get("tasks",0) == 1

static func claimed(shop: Dictionary, id: String) -> bool:
	return shop.get("actions",[]).any(func(action: Dictionary) -> bool: return action.id == PREFIX+id)

static func progress(task: Dictionary, state: Dictionary) -> int:
	var weapons: Dictionary = state.get("weapons",{})
	var growth: Dictionary = state.get("growth",{})
	var history: Array = state.get("stage",{}).get("history",[])
	var actions: Array = state.get("supplies",{}).get("actions",[])
	var result := 0
	match task.kind:
		"stage": result = history.size()
		"route": result = history.filter(func(entry: Dictionary) -> bool: return entry.route == task.route).size()
		"damage", "hits":
			for family in weapons.get("equipment",{}): result += int(weapons.get(family,{}).get("total_damage" if task.kind == "damage" else "skill_hit_count",0))
		"family": result = int(weapons.get(task.family,{}).get("skill_hit_count",0)) if weapons.get("equipment",{}).has(task.family) else 0
		"level": result = int(growth.get("level",1))
		"job": result = 0 if String(growth.get("job","")).is_empty() else 1
		"advanced": result = 1 if PrototypeJobProgress.ADVANCED_JOBS.any(func(job: Dictionary) -> bool: return job.id == growth.get("job","")) else 0
		"equipment": result = weapons.get("equipment",{}).values().filter(func(grade: Variant) -> bool: return int(grade) >= int(task.grade)).size()
		"purchases": result = actions.filter(func(action: Dictionary) -> bool: return action.id != "reroll" and not String(action.id).begins_with(PREFIX)).size()
		"rerolls": result = actions.filter(func(action: Dictionary) -> bool: return action.id == "reroll").size()
		"services": result = actions.filter(func(action: Dictionary) -> bool: return action.id in ["heal","potion","gauge","refresh"]).size()
	return mini(result,int(task.target))

static func ready(shop: Dictionary, id: String, state: Dictionary) -> bool:
	var task := definition(id)
	return enabled(shop) and not task.is_empty() and not claimed(shop,id) and progress(task,state) >= int(task.target)

static func valid_receipt(action: Dictionary, shop: Dictionary, state: Dictionary) -> bool:
	if not enabled(shop) or action.skill != "" or int(action.slot) != -1: return false
	var task := definition(String(action.id).trim_prefix(PREFIX))
	if task.is_empty() or progress(task,state) < int(task.target): return false
	if task.kind in ["stage","route"] and int(action.stage) < int(task.target): return false
	if task.get("route","") == "city_gate" and int(action.stage) < 9: return false
	if task.kind == "advanced" and int(action.stage) < 7: return false
	return true

static func cards(state: Dictionary) -> Array[Dictionary]:
	var shop: Dictionary = state.get("supplies",{})
	var result: Array[Dictionary] = []
	for task in DEFINITIONS:
		var card: Dictionary = task.duplicate(true)
		card.progress = progress(task,state)
		card.claimed = claimed(shop,task.id)
		card.ready = enabled(shop) and not card.claimed and card.progress >= int(task.target)
		var stage: Dictionary = state.get("stage",{})
		var limit := int(stage.get("limit",10))
		var mode := String(stage.get("run_mode","standard"))
		var restriction := ""
		if task.kind == "family" and not state.get("weapons",{}).get("equipment",{}).has(task.family): restriction = "다른 무기의 새 도전에서 진행"
		elif task.kind == "stage" and int(task.target) >= limit: restriction = "더 긴 도전에서 진행"
		elif (task.kind == "advanced" and limit <= 7) or (task.get("route","") == "city_gate" and mode != "journey"): restriction = "10스테이지 여정에서 진행"
		elif task.kind == "route" and task.route != "meadow" and mode != "journey" and limit <= 3: restriction = "5스테이지 도전부터 진행"
		card.unavailable = not restriction.is_empty()
		card.status = "수령 완료" if card.claimed else "보상 수령 가능" if card.ready else restriction if card.unavailable else "진행 중"
		result.append(card)
	return result
