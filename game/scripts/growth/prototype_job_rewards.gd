class_name PrototypeJobRewards
extends RefCounted

## GP-103: 발현한 직업의 카드 후보와 필살기 선택 데이터.
const CARDS: Array[Dictionary] = [
	{"id": "vanguard_edge", "job": "vanguard", "title": "선봉의 칼날", "category": "job", "lines": ["검 기본 공격·스킬", "피해 +20%"], "tags": {"strength": 2.5, "determination": 1.5}},
	{"id": "vanguard_vigor", "job": "vanguard", "title": "선봉의 기백", "category": "job", "lines": ["최대 체력 +30", "현재 체력 +30"], "tags": {"strength": 2.5, "determination": 1.5}},
	{"id": "tracker_focus", "job": "tracker", "title": "추적자의 집중", "category": "job", "lines": ["활 기본 공격·스킬", "피해 +20%"], "tags": {"shooting": 2.5, "nature": 1.5}},
	{"id": "tracker_breath", "job": "tracker", "title": "추적자의 호흡", "category": "job", "lines": ["최대 체력 +20", "체력 35 회복"], "tags": {"shooting": 2.5, "nature": 1.5}},
	{"id": "vanguard_dawn_edge", "job": "vanguard", "title": "여명의 칼날", "category": "job", "lines": ["검 공격·스킬·필살기", "피해 +30% · 1회 강화"], "tags": {"strength": 2.5, "determination": 1.5}, "max_rank": 1, "requires": ["vanguard_edge"]},
	{"id": "tracker_forest_aim", "job": "tracker", "title": "숲의 명중", "category": "job", "lines": ["활 공격·스킬·필살기", "피해 +30% · 1회 강화"], "tags": {"shooting": 2.5, "nature": 1.5}, "max_rank": 1, "requires": ["tracker_focus"]},
]

const ULTIMATES: Array[Dictionary] = [
	{"id": "vanguard_strike", "job": "vanguard", "name": "여명의 일격", "lines": ["주변 적 · 검 피해 60", "3초 동안 적 시간 15%"], "duration": 3.0, "slow": 0.15, "damage": 60, "weapon": "sword", "range": 260.0, "forward": false, "heal": 0},
	{"id": "vanguard_resolve", "job": "vanguard", "name": "불굴의 새벽", "lines": ["체력 40 회복", "5초 동안 적 시간 35%"], "duration": 5.0, "slow": 0.35, "damage": 0, "heal": 40},
	{"id": "tracker_volley", "job": "tracker", "name": "새벽의 일제사격", "lines": ["전방 화면 안 적 · 활 피해 45", "3초 동안 적 시간 15%"], "duration": 3.0, "slow": 0.15, "damage": 45, "weapon": "bow", "range": 800.0, "forward": true, "heal": 0},
	{"id": "tracker_breath", "job": "tracker", "name": "숲의 숨결", "lines": ["체력 30 회복", "5초 동안 적 시간 25%"], "duration": 5.0, "slow": 0.25, "damage": 0, "heal": 30},
]


static func cards_for(job_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card in CARDS:
		if card["job"] == job_id:
			result.append(card.duplicate(true))
	return result


static func ultimates_for(job_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ultimate in ULTIMATES:
		if ultimate["job"] == job_id:
			result.append(ultimate.duplicate(true))
	return result
