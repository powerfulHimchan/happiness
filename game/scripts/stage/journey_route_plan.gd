class_name JourneyRoutePlan
extends RefCounted

## GP-307: 네 지역 각 두 구간, 성문, 중심부의 10스테이지 진행 규칙.
const MODE := "journey"
const STAGES := 10
const GATE := "city_gate"
const CORE := "city_core"

static func completed_regions(history: Array) -> Array[String]:
	var result: Array[String] = []
	for entry in history:
		if int(entry.stage) <= 8 and int(entry.stage) % 2 == 0 and entry.route not in result:
			result.append(String(entry.route))
	return result

static func candidates(number: int, route: String, history: Array, order: Array) -> Array[String]:
	if number >= STAGES: return []
	if number == 8: return [GATE]
	if number == 9: return [CORE]
	if number % 2 == 1: return [route]
	var visited := completed_regions(history)
	var result: Array[String] = []
	for id in order:
		if id not in visited:
			result.append(String(id))
			if result.size() == 2: break
	return result

static func valid_history(history: Array, order: Array) -> bool:
	var previous: Array = []
	for entry in history:
		var number := int(entry.stage)
		if number == 1:
			if entry.route != order[0]: return false
		elif entry.route not in candidates(number - 1, String(previous[-1].route), previous, order):
			return false
		previous.append(entry)
	return true
