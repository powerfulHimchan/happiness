class_name PrototypeJobRewards
extends RefCounted

## GP-103: 발현한 직업의 카드 후보와 필살기 선택 데이터.
const CARDS: Array[Dictionary] = [
	{"id": "breaker_edge", "job": "breaker", "title": "파쇄의 칼날", "category": "job", "lines": ["검 공격·스킬·필살기", "피해 +30% · 도전당 1회"], "tags": {"strength": 2.5, "determination": 1.5}, "max_rank": 1},
	{"id": "breaker_vigor", "job": "breaker", "title": "파쇄자의 투지", "category": "job", "lines": ["최대 체력 +20 · 체력 +40", "도전당 1회"], "tags": {"strength": 2.5, "determination": 1.5}, "max_rank": 1},
	{"id": "storm_arrow", "job": "storm_archer", "title": "폭풍의 화살", "category": "job", "lines": ["활 공격·스킬·필살기", "피해 +25% · 도전당 1회"], "tags": {"shooting": 2.5, "nature": 1.5}, "max_rank": 1},
	{"id": "storm_breath", "job": "storm_archer", "title": "바람의 호흡", "category": "job", "lines": ["최대 체력 +20 · 체력 +40", "도전당 1회"], "tags": {"shooting": 2.5, "nature": 1.5}, "max_rank": 1},
	{"id": "dragon_flame", "job": "dragon_knight", "title": "용염의 칼날", "category": "job", "lines": ["검 공격·스킬·필살기", "피해 +20% · 도전당 1회"], "tags": {"strength": 2.5, "determination": 1.5}, "max_rank": 1},
	{"id": "dragon_heart", "job": "dragon_knight", "title": "용의 심장", "category": "job", "lines": ["최대 체력 +30 · 체력 +30", "도전당 1회"], "tags": {"strength": 2.5, "determination": 1.5}, "max_rank": 1},
	{"id": "vanguard_edge", "job": "vanguard", "title": "선봉의 칼날", "category": "job", "lines": ["검 기본 공격·스킬", "피해 +20%"], "tags": {"strength": 2.5, "determination": 1.5}},
	{"id": "vanguard_vigor", "job": "vanguard", "title": "선봉의 기백", "category": "job", "lines": ["최대 체력 +30", "현재 체력 +30"], "tags": {"strength": 2.5, "determination": 1.5}},
	{"id": "tracker_focus", "job": "tracker", "title": "추적자의 집중", "category": "job", "lines": ["활 기본 공격·스킬", "피해 +20%"], "tags": {"shooting": 2.5, "nature": 1.5}},
	{"id": "tracker_breath", "job": "tracker", "title": "추적자의 호흡", "category": "job", "lines": ["최대 체력 +20", "체력 35 회복"], "tags": {"shooting": 2.5, "nature": 1.5}},
	{"id": "vanguard_dawn_edge", "job": "vanguard", "title": "여명의 칼날", "category": "job", "lines": ["검 공격·스킬·필살기", "피해 +30% · 1회 강화"], "tags": {"strength": 2.5, "determination": 1.5}, "max_rank": 1, "requires": ["vanguard_edge"]},
	{"id": "tracker_forest_aim", "job": "tracker", "title": "숲의 명중", "category": "job", "lines": ["활 공격·스킬·필살기", "피해 +30% · 1회 강화"], "tags": {"shooting": 2.5, "nature": 1.5}, "max_rank": 1, "requires": ["tracker_focus"]},
	{"id": "warden_arrow", "job": "forest_warden", "title": "숲의 화살", "category": "job", "lines": ["활 공격·스킬·필살기 피해 +20%", "도전당 1회"], "tags": {"shooting": 2.5, "nature": 1.5}, "max_rank": 1, "job_effect": {"damage": 0.20}},
	{"id": "warden_roots", "job": "forest_warden", "title": "깊은 뿌리", "category": "job", "lines": ["최대 체력 +30 · 체력 +45", "도전당 1회"], "tags": {"shooting": 2.5, "nature": 1.5}, "max_rank": 1, "job_effect": {"health": 30, "heal": 45}},
	{"id": "dragon_inferno", "job": "dragon_knight", "title": "진홍의 용염", "category": "job", "lines": ["검 공격·스킬·필살기 피해 +30%", "용린의 가호와 하나만 선택"], "tags": {"strength": 2.5, "determination": 1.5}, "max_rank": 1, "requires": ["dragon_flame"], "excludes": ["dragon_aegis"], "job_effect": {"damage": 0.30}},
	{"id": "dragon_aegis", "job": "dragon_knight", "title": "용린의 가호", "category": "job", "lines": ["최대 체력 +40 · 체력 +50", "진홍의 용염과 하나만 선택"], "tags": {"strength": 2.5, "determination": 1.5}, "max_rank": 1, "requires": ["dragon_heart"], "excludes": ["dragon_inferno"], "job_effect": {"health": 40, "heal": 50}},
	{"id": "breaker_ruin", "job": "breaker", "title": "파멸의 칼날", "category": "job", "lines": ["검 공격·스킬·필살기 피해 +35%", "불굴의 파쇄와 하나만 선택"], "tags": {"strength": 2.5, "determination": 1.5}, "max_rank": 1, "requires": ["breaker_edge"], "excludes": ["breaker_endure"], "job_effect": {"damage": 0.35}},
	{"id": "breaker_endure", "job": "breaker", "title": "불굴의 파쇄", "category": "job", "lines": ["최대 체력 +40 · 체력 +50", "파멸의 칼날과 하나만 선택"], "tags": {"strength": 2.5, "determination": 1.5}, "max_rank": 1, "requires": ["breaker_vigor"], "excludes": ["breaker_ruin"], "job_effect": {"health": 40, "heal": 50}},
	{"id": "storm_tempest", "job": "storm_archer", "title": "천둥의 시위", "category": "job", "lines": ["활 공격·스킬·필살기 피해 +30%", "바람의 장막과 하나만 선택"], "tags": {"shooting": 2.5, "nature": 1.5}, "max_rank": 1, "requires": ["storm_arrow"], "excludes": ["storm_shelter"], "job_effect": {"damage": 0.30}},
	{"id": "storm_shelter", "job": "storm_archer", "title": "바람의 장막", "category": "job", "lines": ["최대 체력 +40 · 체력 +50", "천둥의 시위와 하나만 선택"], "tags": {"shooting": 2.5, "nature": 1.5}, "max_rank": 1, "requires": ["storm_breath"], "excludes": ["storm_tempest"], "job_effect": {"health": 40, "heal": 50}},
	{"id": "warden_thorns", "job": "forest_warden", "title": "가시의 맹세", "category": "job", "lines": ["활 공격·스킬·필살기 피해 +25%", "거목의 심장과 하나만 선택"], "tags": {"shooting": 2.5, "nature": 1.5}, "max_rank": 1, "requires": ["warden_arrow"], "excludes": ["warden_bloom"], "job_effect": {"damage": 0.25}},
	{"id": "warden_bloom", "job": "forest_warden", "title": "거목의 심장", "category": "job", "lines": ["최대 체력 +50 · 체력 +60", "가시의 맹세와 하나만 선택"], "tags": {"shooting": 2.5, "nature": 1.5}, "max_rank": 1, "requires": ["warden_roots"], "excludes": ["warden_thorns"], "job_effect": {"health": 50, "heal": 60}},
]

const ULTIMATES: Array[Dictionary] = [
	{"id": "breaker_crush", "job": "breaker", "name": "대지 파쇄", "lines": ["주변2m · 검 피해160", "2초 동안 적 시간20%"], "duration": 2.0, "slow": 0.20, "damage": 160, "weapon": "sword", "range": 200.0, "forward": false, "heal": 0},
	{"id": "breaker_roar", "job": "breaker", "name": "투지의 포효", "lines": ["주변3m · 검80 · 회복30", "4초 동안 적 시간30%"], "duration": 4.0, "slow": 0.30, "damage": 80, "weapon": "sword", "range": 300.0, "forward": false, "heal": 30},
	{"id": "storm_volley", "job": "storm_archer", "name": "폭풍 일제사격", "lines": ["전방10m · 활 피해120", "3초 동안 적 시간15%"], "duration": 3.0, "slow": 0.15, "damage": 120, "weapon": "bow", "range": 1000.0, "forward": true, "heal": 0},
	{"id": "storm_eye", "job": "storm_archer", "name": "폭풍의 눈", "lines": ["주변3m · 활50 · 회복45", "5초 동안 적 시간20%"], "duration": 5.0, "slow": 0.20, "damage": 50, "weapon": "bow", "range": 300.0, "forward": false, "heal": 45},
	{"id": "dragon_burst", "job": "dragon_knight", "name": "용염 폭발", "lines": ["주변3m · 검 피해120", "3초 동안 적 시간15%"], "duration": 3.0, "slow": 0.15, "damage": 120, "weapon": "sword", "range": 300.0, "forward": false, "heal": 0},
	{"id": "dragon_guard", "job": "dragon_knight", "name": "불꽃의 수호", "lines": ["체력50 · 주변3m 검40", "5초 동안 적 시간25%"], "duration": 5.0, "slow": 0.25, "damage": 40, "weapon": "sword", "range": 300.0, "forward": false, "heal": 50},
	{"id": "vanguard_strike", "job": "vanguard", "name": "여명의 일격", "lines": ["주변 적 · 검 피해 60", "3초 동안 적 시간 15%"], "duration": 3.0, "slow": 0.15, "damage": 60, "weapon": "sword", "range": 260.0, "forward": false, "heal": 0},
	{"id": "vanguard_resolve", "job": "vanguard", "name": "불굴의 새벽", "lines": ["체력 40 회복", "5초 동안 적 시간 35%"], "duration": 5.0, "slow": 0.35, "damage": 0, "heal": 40},
	{"id": "tracker_volley", "job": "tracker", "name": "새벽의 일제사격", "lines": ["전방 화면 안 적 · 활 피해 45", "3초 동안 적 시간 15%"], "duration": 3.0, "slow": 0.15, "damage": 45, "weapon": "bow", "range": 800.0, "forward": true, "heal": 0},
	{"id": "tracker_breath", "job": "tracker", "name": "숲의 숨결", "lines": ["체력 30 회복", "5초 동안 적 시간 25%"], "duration": 5.0, "slow": 0.25, "damage": 0, "heal": 30},
	{"id": "vanguard_shock", "job": "vanguard", "name": "새벽의 진동", "lines": ["주변2m · 검 피해90", "2초 동안 적 시간20%"], "duration": 2.0, "slow": 0.2, "damage": 90, "weapon": "sword", "range": 200.0, "forward": false, "heal": 0},
	{"id": "vanguard_mend", "job": "vanguard", "name": "수호의 파동", "lines": ["주변3m · 검30 · 회복25", "4초 동안 적 시간30%"], "duration": 4.0, "slow": 0.3, "damage": 30, "weapon": "sword", "range": 300.0, "forward": false, "heal": 25},
	{"id": "tracker_snipe", "job": "tracker", "name": "여명의 저격", "lines": ["전방10m · 활90 · 높이1m", "2초 동안 적 시간20%"], "duration": 2.0, "slow": 0.2, "damage": 90, "weapon": "bow", "range": 1000.0, "half_height": 100.0, "forward": true, "heal": 0},
	{"id": "tracker_shelter", "job": "tracker", "name": "숲의 안식", "lines": ["체력50 회복", "4초 동안 적 시간30%"], "duration": 4.0, "slow": 0.3, "damage": 0, "heal": 50},
	{"id": "warden_rain", "job": "forest_warden", "name": "숲의 화살비", "lines": ["주변3m · 활 피해90", "4초 동안 적 시간20%"], "duration": 4.0, "slow": 0.20, "damage": 90, "weapon": "bow", "range": 300.0, "forward": false, "heal": 0},
	{"id": "warden_sanctuary", "job": "forest_warden", "name": "숲의 안식처", "lines": ["주변3m · 활30 · 회복60", "5초 동안 적 시간30%"], "duration": 5.0, "slow": 0.30, "damage": 30, "weapon": "bow", "range": 300.0, "forward": false, "heal": 60},
	{"id": "dragon_lance", "job": "dragon_knight", "name": "용염의 창", "lines": ["전방6m · 검150 · 높이1m", "2초 동안 적 시간20%"], "duration": 2.0, "slow": 0.20, "damage": 150, "weapon": "sword", "range": 600.0, "half_height": 100.0, "forward": true, "heal": 0},
	{"id": "dragon_rekindle", "job": "dragon_knight", "name": "용의 재생", "lines": ["체력70 회복", "4초 동안 적 시간35%"], "duration": 4.0, "slow": 0.35, "damage": 0, "heal": 70},
	{"id": "breaker_rift", "job": "breaker", "name": "대지의 균열", "lines": ["전방5m · 검180 · 높이1.2m", "2초 동안 적 시간25%"], "duration": 2.0, "slow": 0.25, "damage": 180, "weapon": "sword", "range": 500.0, "half_height": 120.0, "forward": true, "heal": 0},
	{"id": "breaker_surge", "job": "breaker", "name": "파쇄의 격동", "lines": ["주변2.5m · 검100 · 회복20", "3초 동안 적 시간20%"], "duration": 3.0, "slow": 0.20, "damage": 100, "weapon": "sword", "range": 250.0, "forward": false, "heal": 20},
	{"id": "storm_snipe", "job": "storm_archer", "name": "천둥 저격", "lines": ["전방10m · 활180 · 높이0.8m", "2초 동안 적 시간20%"], "duration": 2.0, "slow": 0.20, "damage": 180, "weapon": "bow", "range": 1000.0, "half_height": 80.0, "forward": true, "heal": 0},
	{"id": "storm_restoration", "job": "storm_archer", "name": "고요한 바람", "lines": ["체력65 회복", "5초 동안 적 시간25%"], "duration": 5.0, "slow": 0.25, "damage": 0, "heal": 65},
	{"id": "warden_thorn_wave", "job": "forest_warden", "name": "가시 물결", "lines": ["전방7m · 활130 · 높이1.4m", "3초 동안 적 시간20%"], "duration": 3.0, "slow": 0.20, "damage": 130, "weapon": "bow", "range": 700.0, "half_height": 140.0, "forward": true, "heal": 0},
	{"id": "warden_renewal", "job": "forest_warden", "name": "거목의 숨결", "lines": ["체력85 회복", "4초 동안 적 시간35%"], "duration": 4.0, "slow": 0.35, "damage": 0, "heal": 85},
]


static func cards_for(job_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card in CARDS:
		if card["job"] == job_id or card["job"] == PrototypeJobProgress.base_job(job_id):
			result.append(card.duplicate(true))
	return result


static func ultimates_for(job_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ultimate in ULTIMATES:
		if ultimate["job"] == job_id:
			result.append(ultimate.duplicate(true))
	return result
