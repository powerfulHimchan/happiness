class_name PrototypeRouteAtlas
extends RefCounted

## GP-122: 실제 스테이지 통과를 기록하는 지도. 경로 선택 권한은 StageRunner가 판단한다.
const IDS := ["meadow", "wind", "clockwork"]

static func valid_ids(value: Variant) -> bool:
	if not value is Array:
		return false
	var seen: Array = []
	for id in value:
		if not id is String or id not in IDS or id in seen:
			return false
		seen.append(id)
	return true

static func cards(surveyed: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var profiles: Array[Dictionary] = PrototypeStageRunner.ROUTES.duplicate(true)
	profiles.append(PrototypeStageRunner.RISK_ROUTE)
	for route in profiles:
		var lines: Array[String] = []
		lines.assign(route.lines)
		lines.append("선택 시 보너스 · 통과 시 기본 20% 회복" if route.id != "clockwork" else "통과 시 기본 20% 회복에 보너스 추가")
		lines.append("2·3스테이지에서 선택" if route.id != "clockwork" else "파괴 핵 적용 도전의 2스테이지만")
		result.append({"id": route.id, "name": route.name, "open": true, "status": "답사 완료 · 통과 기록" if surveyed.has(route.id) else "미답사 · 실제 통과로 기록", "lines": lines})
	return result
