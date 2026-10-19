class_name PrototypeStageRunner
extends Node

## CP-303의 전진 2개, 웨이브 2개, 정예 1개 구간을 순서대로 진행한다.
## 180초는 측정 목표이며 제한 시간이 아니다. 구간 완료 조건만 다음 관문을 연다.

signal stage_metrics_changed(metrics: Dictionary)
signal stage_reset

enum Section {
	ADVANCE_ONE,
	WAVE_ONE,
	ADVANCE_TWO,
	WAVE_TWO,
	ELITE,
	COMPLETE,
}

const SECTION_NAMES: Array[String] = [
	"전진 1 · 이동/검",
	"웨이브 1 · 근접/원거리",
	"전진 2 · 발판/활",
	"웨이브 2 · 무기 전환",
	"정예 · 갑옷 멧돼지",
]
const SECTION_OBJECTIVES: Array[String] = [
	"첫 관문까지 전진",
	"풀잎 슬라임과 씨앗 포대 처치",
	"발판과 낙하 구간을 지나 전진",
	"검·활을 전환해 혼합 웨이브 처치",
	"돌진을 벽으로 유도해 정예 처치",
]
const SECTION_TARGET_SECONDS: Array[float] = [40.0, 35.0, 35.0, 40.0, 30.0]
const STAGE_TARGET_SECONDS := 180.0
const ADVANCE_ONE_X := 1230.0
const ADVANCE_TWO_X := 3830.0

@export var stage_enabled: bool = true
@export_range(1, 10) var stage_limit: int = 1

const ROUTES: Array[Dictionary] = [
	{"id": "meadow", "name": "풀숲 길", "lines": ["다리로 전진 · 가까운 혼합 전투", "첫 웨이브 · 슬라임 + 씨앗 포대", "체력 20 추가 회복"]},
	{"id": "wind", "name": "바람 길", "lines": ["징검 발판 · 흩어진 원거리 전투", "첫 웨이브 · 슬라임 + 바람 정령", "필살기 게이지 +25"]},
]
const RISK_ROUTE := {"id": "clockwork", "name": "태엽 폐허 · 위험", "lines": ["좁은 발판 · 적 체력 +20%", "첫 웨이브 · 세 종류의 적", "통과: 체력 +20 · 필살기 +50"]}
const FOREST_ROUTE := {"id": "forest", "name": "거꾸로 자란 숲", "lines": ["움직이는 덩굴 · 고정 쉼터", "연속 도약 · 넓은 씨앗 · 재돌진", "정예 통과: 회복+10 · 게이지+15"]}
const RUINS_ROUTE := {"id": "ruins", "name": "별시계 유적", "lines": ["멈춤·반복 발판과 시간 함정", "태엽 인형의 기억된 이중 사격", "정예 통과: 방벽+10 · 게이지+20"]}
const FESTIVAL_ROUTE := {"id": "festival", "name": "태엽 축제장", "lines": ["회전 놀이 발판 · 기계 승강대", "병정의 행진 돌진 · 포탑 부채탄", "정예 통과: 회복+15 · 게이지+10"]}
const CITY_GATE_ROUTE := {"id": "city_gate", "name": "행복의 나라 성문", "lines": ["9스테이지 · 하얀 성벽과 미소 짓는 주민", "성문 계단 · 혼합 전투와 행복의 수호기사", "통과 후 중심부로 이동"]}
const CITY_CORE_ROUTE := {"id": "city_core", "name": "행복의 나라 중심부", "lines": ["10스테이지 · 시계탑 회랑과 궁전 앞 광장", "혼합 웨이브 뒤 웃는 태엽 기사 전투", "승리 후 구출/파괴 선택"]}
const REGION_IDS := ["wind", "forest", "ruins", "festival"]
var expedition: int = 0
var run_mode: String = "standard"
var region_order: Array[String] = []
var region_rng := RandomNumberGenerator.new()
var stage_number: int = 1
var route_id: String = "meadow"
var skills_claimed: bool = false
var reward_claimed: bool = false
var boss_choice: String = ""
var final_boss_id: String = SeraEncounter.LEGACY
var heart_threshold: String = ""
var arrival_ending: String = ""
var heart_battle: String = ""
var final_ritual: Dictionary = {}
var final_record_ready: bool = false
var guardian_choice: String = ""
var completed_elapsed_s: float = 0.0
var stage_history: Array[Dictionary] = []

@onready var player: PrototypePlayer = get_node("../Player") as PrototypePlayer
@onready var route_terrain: PrototypeRouteTerrain = get_node("../RouteTerrain") as PrototypeRouteTerrain
@onready var clock_traps: ClockTrapController = get_node("../ClockTrapController") as ClockTrapController
@onready var leaf_slime: PrototypeEnemy = get_node("../Targets/LeafSlime") as PrototypeEnemy
@onready var seed_sack: PrototypeEnemy = get_node("../Targets/SeedSack") as PrototypeEnemy
@onready var wind_spirit: PrototypeEnemy = get_node("../Targets/WindSpirit") as PrototypeEnemy
@onready var armored_boar: EliteArmoredBoar = get_node("../Targets/ArmoredBoar") as EliteArmoredBoar
@onready var boss: BossClockworkKnight = get_node("../Targets/ClockworkKnight") as BossClockworkKnight
@onready var guardian: BossHappinessGuardian = get_node("../Targets/HappinessGuardian") as BossHappinessGuardian
@onready var sera: BossSera = get_node("../Targets/Sera") as BossSera
@onready var heart: BossHappinessHeart = get_node("../Targets/HappinessHeart") as BossHappinessHeart
@onready var gates: Array[StaticBody2D] = [
	get_node("../StageGates/GateA") as StaticBody2D,
	get_node("../StageGates/GateB") as StaticBody2D,
	get_node("../StageGates/GateC") as StaticBody2D,
	get_node("../StageGates/FinalGate") as StaticBody2D,
]

var current_section: int = Section.ADVANCE_ONE
var stage_elapsed_s: float = 0.0
var section_elapsed_s: float = 0.0
var section_actual_times: Array[float] = []
var stage_complete: bool = false
var failed: bool = false
var _active_enemies: Array[PrototypeTarget] = []
var _metric_elapsed_s: float = 0.0
var _last_stage_log: String = "스테이지 시작"
var _initial_positions: Dictionary = {}
var _initial_health: Dictionary = {}


func _ready() -> void:
	region_rng.randomize()
	for enemy in _all_combat_enemies():
		_initial_positions[enemy.get_path()] = enemy.position
		_initial_health[enemy.get_path()] = enemy.damage_receiver.max_health
	if stage_enabled:
		reset_run()
	else:
		_restore_combat_sandbox()


func _process(delta: float) -> void:
	if not stage_enabled or stage_complete:
		return
	stage_elapsed_s += delta
	section_elapsed_s += delta
	_metric_elapsed_s += delta

	if heart_battle == HeartEncounter.ACTIVE:
		if _active_enemy_count() == 0: _finish_heart_battle()
		elif _metric_elapsed_s >= 0.10:
			_metric_elapsed_s = 0.0
			_emit_metrics()
		return

	match current_section:
		Section.ADVANCE_ONE:
			if player.global_position.x >= ADVANCE_ONE_X:
				_finish_current_section()
		Section.WAVE_ONE, Section.WAVE_TWO, Section.ELITE:
			if _active_enemy_count() == 0:
				_finish_current_section()
		Section.ADVANCE_TWO:
			if player.global_position.x >= ADVANCE_TWO_X:
				_finish_current_section()

	if _metric_elapsed_s >= 0.10:
		_metric_elapsed_s = 0.0
		_emit_metrics()


func region_section() -> int:
	return RegionStageLayout.section(run_mode, stage_number, route_id)


func reset_stage() -> void:
	if not stage_enabled:
		return
	route_terrain.configure(stage_number, route_id, true, run_mode == JourneyRoutePlan.MODE, region_section())
	clock_traps.configure(stage_number, route_id, run_mode == JourneyRoutePlan.MODE, region_section())
	reward_claimed = false
	skills_claimed = false
	boss_choice = ""
	for projectile in get_tree().get_nodes_in_group("enemy_projectile"):
		projectile.queue_free()
	for enemy in _all_combat_enemies():
		if enemy is PrototypeEnemy:
			(enemy as PrototypeEnemy).expedition_patterns = expedition >= 3 and run_mode == JourneyRoutePlan.MODE
			(enemy as PrototypeEnemy).configure_route(route_id)
		if enemy is ExpeditionBoss:
			(enemy as ExpeditionBoss).expedition_patterns = expedition >= 4 and run_mode == JourneyRoutePlan.MODE
		enemy.damage_receiver.max_health = _enemy_health(enemy)
		enemy.reset_target()
		_deactivate_enemy(enemy)
	for gate_index in gates.size():
		_set_gate_closed(gate_index, true)
	current_section = Section.ADVANCE_ONE
	stage_elapsed_s = 0.0
	section_elapsed_s = 0.0
	section_actual_times.clear()
	stage_complete = false
	failed = false
	_active_enemies.clear()
	_metric_elapsed_s = 0.0
	_last_stage_log = "구간 1/5 시작 · 첫 관문까지 전진"
	stage_reset.emit()
	_emit_metrics()


func reset_run() -> void:
	if run_mode != JourneyRoutePlan.MODE: expedition = 0
	final_boss_id = SeraEncounter.ID if run_mode == JourneyRoutePlan.MODE else SeraEncounter.LEGACY
	heart_threshold = ""
	arrival_ending = ""
	heart_battle = ""
	final_ritual = {}
	final_record_ready = false
	guardian_choice = ""
	stage_number = 1
	route_id = "meadow"
	completed_elapsed_s = 0.0
	stage_history.clear()
	region_order.clear()
	if run_mode in ["regions", JourneyRoutePlan.MODE]:
		region_order.assign(REGION_IDS)
		for index in range(region_order.size() - 1, 0, -1):
			var other := region_rng.randi_range(0, index)
			var id := region_order[index]
			region_order[index] = region_order[other]
			region_order[other] = id
	if run_mode == JourneyRoutePlan.MODE:
		route_id = region_order[0]
	reset_stage()


func has_next_stage() -> bool:
	return stage_enabled and stage_complete and stage_number < stage_limit and not awaiting_guardian_choice()


func available_routes() -> Array[Dictionary]:
	if awaiting_guardian_choice(): return []
	if run_mode == JourneyRoutePlan.MODE:
		var offers: Array[Dictionary] = []
		for id in JourneyRoutePlan.candidates(stage_number, route_id, stage_history, region_order):
			var profile := route_profile(id)
			if id == JourneyRoutePlan.CORE and final_boss_id == SeraEncounter.ID:
				profile.lines = ["10스테이지 · 시계탑 회랑과 궁전 앞 광장", "혼합 웨이브 뒤 미소의 여왕 세라 전투", "승리 후 세라 구출/파괴 선택"]
			if id == "wind": profile.name = "바람꽃 평원"
			if stage_number < 8 and stage_number % 2 == 1:
				profile.name += " · " + String(RegionStageLayout.TITLES[id])
				profile.lines = [String(RegionStageLayout.DESCRIPTIONS[id]), "성장·장비·잔량 유지", "두 구간을 마치면 다음 지역 선택"]
			offers.append(profile)
		return offers
	if run_mode == "regions":
		var offers: Array[Dictionary] = []
		var visited := visited_regions()
		for id in region_order:
			if id in visited: continue
			var profile := route_profile(id)
			if id == "wind": profile.name = "바람꽃 평원"
			offers.append(profile)
			if offers.size() == 2: break
		return offers
	var routes: Array[Dictionary] = ROUTES.duplicate(true)
	if stage_number == 1 and player.boss_legacy.get("choice", "") == "destroy":
		routes.append(RISK_ROUTE.duplicate(true))
	routes.append(FOREST_ROUTE.duplicate(true))
	routes.append(RUINS_ROUTE.duplicate(true))
	routes.append(FESTIVAL_ROUTE.duplicate(true))
	return routes


func visited_regions() -> Array[String]:
	if run_mode == JourneyRoutePlan.MODE:
		return JourneyRoutePlan.completed_regions(stage_history)
	var visited: Array[String] = []
	for entry in stage_history:
		if entry.route in REGION_IDS and entry.route not in visited:
			visited.append(String(entry.route))
	return visited


func set_run_mode(mode: String) -> bool:
	if not valid_mode_length(mode, stage_limit): return false
	run_mode = mode
	return true


static func valid_mode_length(mode: String, count: int) -> bool:
	return (mode == "standard" and count in [1, 3, 5]) or (mode == "regions" and count == 5) or (mode == JourneyRoutePlan.MODE and count == JourneyRoutePlan.STAGES)


static func route_profile(id: String) -> Dictionary:
	for route in ROUTES + [RISK_ROUTE, FOREST_ROUTE, RUINS_ROUTE, FESTIVAL_ROUTE, CITY_GATE_ROUTE, CITY_CORE_ROUTE]:
		if route.id == id:
			return route.duplicate(true)
	return {}


func can_select_route(id: String) -> bool:
	for route in available_routes():
		if route.id == id:
			return true
	return false


func _enemy_health(enemy: PrototypeTarget) -> int:
	if enemy == heart: return BossHappinessHeart.BOSS_HEALTH
	if enemy == sera: return BossSera.BOSS_HEALTH
	if enemy == guardian:
		return BossHappinessGuardian.BOSS_HEALTH
	if enemy == boss:
		return BossClockworkKnight.BOSS_HEALTH * 2 if stage_limit == 10 else BossClockworkKnight.BOSS_HEALTH * 3 / 2 if stage_limit == 5 else BossClockworkKnight.BOSS_HEALTH
	var multiplier := (1.0 + 0.25 * (stage_number - 1)) * (1.20 if route_id == "clockwork" else 1.0)
	return roundi(float(_initial_health[enemy.get_path()]) * multiplier)


func uses_boss() -> bool:
	return stage_enabled and stage_limit in [3, 5, 10] and stage_number == stage_limit


func uses_guardian() -> bool:
	return stage_enabled and run_mode == JourneyRoutePlan.MODE and stage_number == 9 and route_id == JourneyRoutePlan.GATE


func uses_sera() -> bool:
	return uses_boss() and run_mode == JourneyRoutePlan.MODE and route_id == JourneyRoutePlan.CORE and final_boss_id == SeraEncounter.ID and not uses_heart()


func uses_heart() -> bool:
	return heart_battle in [HeartEncounter.ACTIVE, HeartEncounter.DEFEATED, HeartEncounter.SEEN]


func awaiting_boss_choice() -> bool:
	return uses_boss() and stage_complete and boss_choice.is_empty()


func awaiting_guardian_choice() -> bool:
	return uses_guardian() and stage_complete and guardian_choice.is_empty()


func final_enemy() -> PrototypeTarget:
	return heart if uses_heart() else sera if uses_sera() else guardian if uses_guardian() else boss if uses_boss() else armored_boar


func checkpoint_snapshot() -> Dictionary:
	var state := {"number": stage_number, "limit": stage_limit, "route": route_id, "elapsed": stage_elapsed_s, "history": stage_history.duplicate(true), "sections": section_actual_times.duplicate(), "reward_claimed": reward_claimed, "skills_claimed": skills_claimed, "boss_choice": boss_choice}
	if expedition > 0: state.expedition = expedition
	if run_mode in ["regions", JourneyRoutePlan.MODE]:
		state.run_mode = run_mode
		state.region_order = region_order.duplicate()
	if run_mode == JourneyRoutePlan.MODE: state.final_boss = final_boss_id
	if not heart_battle.is_empty() and final_boss_id == SeraEncounter.ID: state.heart_battle = HeartEncounter.PENDING if heart_battle == HeartEncounter.ACTIVE else heart_battle
	if not heart_threshold.is_empty() and final_boss_id == SeraEncounter.ID: state.heart_threshold = heart_threshold
	if not arrival_ending.is_empty() and final_boss_id == SeraEncounter.ID: state.arrival_ending = arrival_ending
	if not final_ritual.is_empty() and final_boss_id == SeraEncounter.ID: state.final_ritual = final_ritual.duplicate(true)
	if run_mode == JourneyRoutePlan.MODE and stage_number >= 9:
		state.guardian_choice = guardian_choice
	return state


func restore_checkpoint(state: Dictionary) -> void:
	expedition = int(state.get("expedition", 0))
	final_boss_id = SeraEncounter.boss_id(state)
	heart_threshold = String(state.get("heart_threshold", ""))
	arrival_ending = String(state.get("arrival_ending", ""))
	heart_battle = String(state.get("heart_battle", ""))
	final_ritual = state.get("final_ritual", {}).duplicate(true)
	final_record_ready = false
	run_mode = String(state.get("run_mode", "standard"))
	region_order.assign(state.get("region_order", []))
	stage_number = int(state.number)
	stage_limit = int(state.limit)
	route_id = String(state.route)
	stage_history.assign(state.history)
	guardian_choice = String(state.get("guardian_choice", GuardianDecision.LEGACY if run_mode == JourneyRoutePlan.MODE and stage_number >= 9 else ""))
	if run_mode == JourneyRoutePlan.MODE and stage_number >= 9:
		stage_history[8].guardian_choice = guardian_choice
	completed_elapsed_s = 0.0
	for entry in stage_history.slice(0, -1):
		completed_elapsed_s += float(entry.elapsed_s)
	reset_stage()
	reward_claimed = bool(state.get("reward_claimed", true))
	skills_claimed = bool(state.get("skills_claimed", true))
	boss_choice = String(state.get("boss_choice", ""))
	stage_elapsed_s = float(state.elapsed)
	section_actual_times.assign(state.sections)
	current_section = Section.COMPLETE
	stage_complete = true
	for index in gates.size():
		_set_gate_closed(index, false)
	_last_stage_log = "중간 저장에서 복귀 · 다음 경로를 선택하세요"
	_emit_metrics()


func start_heart_battle() -> bool:
	if heart_battle != HeartEncounter.PENDING or not stage_complete or boss_choice.is_empty(): return false
	_deactivate_all_combat_enemies()
	for shot in get_tree().get_nodes_in_group("enemy_projectile"): shot.queue_free()
	heart_battle = HeartEncounter.ACTIVE
	stage_complete = false
	current_section = Section.ELITE
	section_elapsed_s = 0
	_set_gate_closed(2, true)
	_set_gate_closed(3, true)
	route_terrain.heart_arena = true
	route_terrain.queue_redraw()
	player.prepare_next_stage(Vector2(4070, 780))
	player.set_safe_spawn(Vector2(4070, 780), "심장 의식의 방")
	_activate_enemy(heart, Vector2(4500, 780))
	_active_enemies.assign([heart])
	_last_stage_log = "행복의 심장 각성 · 지면 맥박/바늘/절단 경고 회피"
	_emit_metrics()
	return true


func _finish_heart_battle() -> void:
	_deactivate_all_combat_enemies()
	for shot in get_tree().get_nodes_in_group("enemy_projectile"): shot.queue_free()
	heart_battle = HeartEncounter.DEFEATED
	stage_complete = true
	current_section = Section.COMPLETE
	section_actual_times[-1] += section_elapsed_s
	section_elapsed_s = 0
	stage_history[-1].elapsed_s = stage_elapsed_s
	_set_gate_closed(2, false)
	_set_gate_closed(3, false)
	_last_stage_log = "행복의 심장 제압 · 승리 기록 대기"
	_emit_metrics()


func next_stage(next_route: String) -> bool:
	if not has_next_stage() or not can_select_route(next_route):
		return false
	completed_elapsed_s += stage_elapsed_s
	stage_number += 1
	route_id = next_route
	reset_stage()
	return true


func set_stage_enabled(enabled: bool) -> void:
	stage_enabled = enabled
	set_process(enabled)
	if enabled:
		reset_stage()
	else:
		_restore_combat_sandbox()


func force_emit_metrics() -> void:
	_emit_metrics()


func debug_set_stage_elapsed(value: float) -> void:
	stage_elapsed_s = maxf(0.0, value)
	_emit_metrics()


func is_gate_closed(gate_index: int) -> bool:
	if gate_index < 0 or gate_index >= gates.size():
		return false
	var shape := gates[gate_index].get_node("CollisionShape2D") as CollisionShape2D
	return not shape.disabled


func current_metrics() -> Dictionary:
	var display_index := mini(current_section, Section.ELITE)
	var section_name := "완료" if stage_complete else SECTION_NAMES[display_index]
	var objective := "출구 개방 · 완료 시간 기록" if stage_complete else SECTION_OBJECTIVES[display_index]
	if stage_number > 1 and not stage_complete:
		match current_section:
			Section.ADVANCE_TWO:
				objective = "풀숲 다리를 건너 전진" if route_id == "meadow" else "길게 점프해 바람 발판 건너기"
			Section.WAVE_ONE:
				objective = "슬라임과 씨앗 포대 처치" if route_id == "meadow" else "슬라임과 바람 정령 처치"
			Section.WAVE_TWO:
				objective = "가까운 혼합 웨이브 처치" if route_id == "meadow" else "활·점프로 흩어진 적 처치"
	if uses_boss() and current_section == Section.ELITE:
		section_name = "보스 · 웃는 태엽 기사"
		objective = "돌진·충격파·탄막 회피 · 벽 충돌 시 검 공격"
		if uses_sera():
			section_name = "보스 · " + BossSera.BOSS_NAME
			objective = "돌진 경고·지면 파문·빛살 틈 회피 · 공격 뒤 왕관 빈틈"
	if route_id == "clockwork" and not stage_complete:
		objective = ["첫 관문까지 전진", "강화된 슬라임·씨앗·바람 처치", "좁은 태엽 발판을 점프로 건너기", "강화된 혼합 웨이브 처치", "강화된 갑옷 멧돼지 처치"][display_index]
	if route_id == "forest" and not stage_complete and current_section != Section.ELITE:
		objective = ["숲 입구까지 전진", "연속 도약·다섯 씨앗 경고 회피", "움직이는 덩굴과 고정 쉼터 건너기", "공중 정령 재돌진·높낮이 혼합 전투"][display_index]
	if route_id == "ruins" and not stage_complete and current_section != Section.ELITE:
		objective = ["유적 입구까지 전진", "인형 이중 사격·시간 함정 회피", "멈춤·반복 발판과 고정 쉼터 건너기", "혼합 웨이브·시간 함정 회피"][display_index]
		if clock_traps.state != ClockTrapController.State.OFF:
			objective += " · " + clock_traps.status_text()
	if awaiting_boss_choice():
		objective = "승리 · 구출 또는 파괴를 선택하세요"
	if awaiting_guardian_choice():
		objective = "성문 승리 · 수호기사 구출 또는 파괴를 선택하세요"
	if route_id == "festival" and not stage_complete and current_section != Section.ELITE:
		objective = ["축제장 입구까지 전진", "병정 행진 돌진·포탑 부채탄 회피", "회전 발판·기계 승강대 건너기", "병정·포탑·공중 정령 혼합 전투"][display_index]
	if region_section() == 2 and not stage_complete:
		objective = RegionStageLayout.objective(route_id, display_index)
		if route_id == "ruins" and clock_traps.state != ClockTrapController.State.OFF: objective += " · " + clock_traps.status_text()
	var target_s := 0.0 if stage_complete else float(SECTION_TARGET_SECONDS[display_index])
	var visited := visited_regions()
	var route_name: String = route_profile(route_id).get("name", "알 수 없는 경로")
	if run_mode == "regions":
		route_name = "연습 구간" if stage_number == 1 else "바람꽃 평원" if route_id == "wind" else route_name
		objective += " · 지역 통과 %d/4" % visited.size()
	if run_mode == JourneyRoutePlan.MODE:
		route_name = "바람꽃 평원" if route_id == "wind" else route_name
		if stage_number <= 8: route_name += " · %d/2 구간" % (1 if stage_number % 2 == 1 else 2)
		if region_section() == 2: route_name += " · " + String(RegionStageLayout.TITLES[route_id])
		objective += " · 지역 완료 %d/4" % visited.size()
		if route_id == JourneyRoutePlan.GATE and not stage_complete:
			objective = CityGateLayout.objective(display_index)
		elif route_id == JourneyRoutePlan.CORE and not stage_complete and current_section != Section.ELITE:
			objective = CityCoreLayout.objective(display_index)
	if uses_guardian() and current_section == Section.ELITE:
		section_name = "보스 · " + BossHappinessGuardian.BOSS_NAME
		objective = "방패 돌진·충격파·빛의 창 회피 · 벽 충돌/공격 뒤 빈틈 공략"
	if uses_heart(): route_name = "행복의 심장"
	if expedition > 0: route_name += " · 원정 %d" % expedition
	if heart_battle == HeartEncounter.ACTIVE:
		section_name = "진 보스 · 행복의 심장"
		objective = "지면 맥박·부채 바늘·수평 절단 회피 · 핵 노출 공략"
	if expedition >= 4 and not stage_complete and (heart_battle == HeartEncounter.ACTIVE or current_section == Section.ELITE and final_enemy() is ExpeditionBoss):
		objective += " · 보스 빈틈 뒤 재공격 경고 확인"
	if expedition >= 3 and not stage_complete and current_section in [Section.WAVE_ONE, Section.WAVE_TWO]:
		objective += " · 일반 적 연속 공격 재경고 확인"
	if expedition > 0 and not stage_complete and current_section == Section.WAVE_TWO:
		objective += " · 추가 정예 갑옷 멧돼지 처치"
	var closed_gate_count := 0
	for gate_index in gates.size():
		if is_gate_closed(gate_index):
			closed_gate_count += 1
	return {
		"run_stage_number": stage_number,
		"run_stage_count": stage_limit,
		"run_route_id": route_id,
		"run_route_name": route_name,
		"run_mode": run_mode,
		"expedition": expedition,
		"run_visited_regions": visited,
		"run_remaining_regions": REGION_IDS.size() - visited.size() if run_mode in ["regions", JourneyRoutePlan.MODE] else 0,
		"run_region_section": region_section(),
		"run_route_terrain": "의식의 방" if uses_heart() else String(RegionStageLayout.DESCRIPTIONS[route_id]) if region_section() == 2 else CityGateLayout.TERRAIN_NAME if route_id == JourneyRoutePlan.GATE else CityCoreLayout.TERRAIN_NAME if route_id == JourneyRoutePlan.CORE else "회전 발판 · 기계 승강대" if route_id == "festival" else "멈춤·반복 시간 발판" if route_id == "ruins" else "움직이는 덩굴 · 고정 쉼터" if route_id == "forest" else "태엽 발판" if route_id == "clockwork" else ("연습 지형" if stage_number == 1 and run_mode != JourneyRoutePlan.MODE else ("평지 다리" if route_id == "meadow" else "징검 발판")),
		"run_complete": stage_complete and stage_number >= stage_limit and not awaiting_boss_choice() and heart_threshold != HeartThreshold.PENDING and arrival_ending != ArrivalEnding.PENDING and not HeartEncounter.blocks_completion(heart_battle) and not FinalRitual.blocks_completion(final_ritual) and (final_ritual.get("phase") != FinalRitual.SEEN or final_record_ready),
		"ending_id": String(final_ritual.get("choice", "")) if final_ritual.get("phase") == FinalRitual.SEEN else "",
		"arrival_ending": arrival_ending,
		"heart_battle": heart_battle,
		"heart_threshold": heart_threshold,
		"boss_choice_pending": awaiting_boss_choice(),
		"boss_choice": boss_choice,
		"final_boss": final_boss_id,
		"guardian_choice": guardian_choice,
		"guardian_choice_pending": awaiting_guardian_choice(),
		"boss_name": BossHappinessHeart.BOSS_NAME if uses_heart() else BossSera.BOSS_NAME if uses_sera() else BossHappinessGuardian.BOSS_NAME if uses_guardian() else BossClockworkKnight.BOSS_NAME if uses_boss() else "",
		"run_elapsed_s": completed_elapsed_s + stage_elapsed_s,
		"run_stage_history": stage_history.duplicate(true),
		"stage_enabled": stage_enabled,
		"stage_complete": stage_complete,
		"stage_failed": failed,
		"stage_section_index": 5 if stage_complete else current_section + 1,
		"stage_section_count": 5,
		"stage_section_name": section_name,
		"stage_objective": objective,
		"stage_elapsed_s": stage_elapsed_s,
		"stage_target_s": STAGE_TARGET_SECONDS,
		"stage_overtime": stage_elapsed_s > STAGE_TARGET_SECONDS,
		"stage_section_elapsed_s": section_elapsed_s,
		"stage_section_target_s": target_s,
		"stage_section_overtime": not stage_complete and section_elapsed_s > target_s,
		"stage_actual_times": section_actual_times.duplicate(),
		"stage_actual_summary": _actual_time_summary(),
		"stage_active_enemy_count": _active_enemy_count(),
		"stage_closed_gate_count": closed_gate_count,
		"stage_last_log": _last_stage_log,
	}


func _finish_current_section() -> void:
	section_actual_times.append(section_elapsed_s)
	var completed_index := current_section
	section_elapsed_s = 0.0
	current_section += 1
	_active_enemies.clear()

	match completed_index:
		Section.ADVANCE_ONE:
			_set_gate_closed(0, false)
			_activate_wave_one()
		Section.WAVE_ONE:
			_deactivate_all_combat_enemies()
			_set_gate_closed(1, false)
		Section.ADVANCE_TWO:
			_set_gate_closed(2, false)
			_activate_wave_two()
			if expedition > 0 and run_mode == JourneyRoutePlan.MODE:
				_activate_enemy(armored_boar, Vector2(4450.0, 780.0))
				_active_enemies.append(armored_boar)
		Section.WAVE_TWO:
			_deactivate_all_combat_enemies()
			_activate_elite()
		Section.ELITE:
			_deactivate_all_combat_enemies()
			_set_gate_closed(3, false)
			stage_complete = true
			if uses_boss():
				reward_claimed = true
				skills_claimed = true
			stage_history.append({"stage": stage_number, "route": route_id, "elapsed_s": stage_elapsed_s})

	if uses_boss() and stage_complete:
		stage_history[-1]["boss_choice"] = boss_choice
		if run_mode == JourneyRoutePlan.MODE: stage_history[-1].final_boss = final_boss_id
	if uses_guardian() and stage_complete:
		stage_history[-1].guardian_choice = guardian_choice
	if stage_complete:
		_last_stage_log = "스테이지 완료 · %s" % _format_seconds(stage_elapsed_s)
	else:
		_last_stage_log = "구간 %d/5 시작 · %s" % [
			current_section + 1,
			SECTION_OBJECTIVES[current_section],
		]
	_emit_metrics()


func _activate_wave_one() -> void:
	if route_id == JourneyRoutePlan.CORE:
		_activate_city_core_wave(1)
		return
	if route_id == JourneyRoutePlan.GATE:
		_activate_city_gate_wave(1)
		return
	if region_section() == 2:
		_activate_second_region_wave(1)
		return
	_activate_enemy(leaf_slime, Vector2(1510.0, 780.0))
	if route_id == "festival":
		_activate_enemy(seed_sack, Vector2(2050.0, 780.0))
		_active_enemies.assign([leaf_slime, seed_sack])
	elif route_id == "ruins":
		_activate_enemy(seed_sack, Vector2(1980.0, 780.0))
		_active_enemies.assign([leaf_slime, seed_sack])
	elif route_id == "forest":
		_activate_enemy(seed_sack, Vector2(1980.0, 650.0))
		_active_enemies.assign([leaf_slime, seed_sack])
	elif route_id == "clockwork":
		_activate_enemy(seed_sack, Vector2(1980.0, 780.0))
		_activate_enemy(wind_spirit, Vector2(1750.0, 540.0))
		_active_enemies.assign([leaf_slime, seed_sack, wind_spirit])
	elif route_id == "wind":
		_activate_enemy(wind_spirit, Vector2(1850.0, 590.0))
		_active_enemies.assign([leaf_slime, wind_spirit])
	else:
		_activate_enemy(seed_sack, Vector2(1900.0, 780.0))
		_active_enemies.assign([leaf_slime, seed_sack])
	clock_traps.start_wave(1)


func _activate_wave_two() -> void:
	if route_id == JourneyRoutePlan.CORE:
		_activate_city_core_wave(2)
		return
	if route_id == JourneyRoutePlan.GATE:
		_activate_city_gate_wave(2)
		return
	if region_section() == 2:
		_activate_second_region_wave(2)
		return
	if stage_number == 1 and run_mode != JourneyRoutePlan.MODE:
		_activate_enemy(leaf_slime, Vector2(4020.0, 780.0))
		_activate_enemy(seed_sack, Vector2(4380.0, 780.0))
		_activate_enemy(wind_spirit, Vector2(4200.0, 590.0))
	elif route_id == "festival":
		_activate_enemy(leaf_slime, Vector2(4030.0, 780.0))
		_activate_enemy(seed_sack, Vector2(4570.0, 780.0))
		_activate_enemy(wind_spirit, Vector2(4280.0, 560.0))
	elif route_id == "ruins":
		_activate_enemy(leaf_slime, Vector2(4020.0, 780.0))
		_activate_enemy(seed_sack, Vector2(4530.0, 780.0))
		_activate_enemy(wind_spirit, Vector2(4250.0, 560.0))
	elif route_id == "forest":
		_activate_enemy(leaf_slime, Vector2(4050.0, 780.0))
		_activate_enemy(seed_sack, Vector2(4470.0, 650.0))
		_activate_enemy(wind_spirit, Vector2(4250.0, 480.0))
	elif route_id == "meadow":
		_activate_enemy(leaf_slime, Vector2(4000.0, 780.0))
		_activate_enemy(seed_sack, Vector2(4180.0, 780.0))
		_activate_enemy(wind_spirit, Vector2(4380.0, 620.0))
	else:
		_activate_enemy(leaf_slime, Vector2(4050.0, 780.0))
		_activate_enemy(seed_sack, Vector2(4650.0, 780.0))
		_activate_enemy(wind_spirit, Vector2(4320.0, 540.0))
	_active_enemies.assign([leaf_slime, seed_sack, wind_spirit])
	clock_traps.start_wave(2)


func _activate_city_core_wave(number: int) -> void:
	var positions := CityCoreLayout.WAVE_ONE if number == 1 else CityCoreLayout.WAVE_TWO
	_activate_enemy(leaf_slime, positions.slime)
	_activate_enemy(seed_sack, positions.seed)
	_activate_enemy(wind_spirit, positions.wind)
	_active_enemies.assign([leaf_slime, seed_sack, wind_spirit])


func _activate_city_gate_wave(number: int) -> void:
	var positions := CityGateLayout.WAVE_ONE if number == 1 else CityGateLayout.WAVE_TWO
	_activate_enemy(leaf_slime, positions.slime)
	_activate_enemy(seed_sack, positions.seed)
	_activate_enemy(wind_spirit, positions.wind)
	_active_enemies.assign([leaf_slime, seed_sack, wind_spirit])


func _activate_second_region_wave(number: int) -> void:
	var positions := RegionStageLayout.wave(route_id, number)
	_activate_enemy(leaf_slime, positions.slime)
	_activate_enemy(seed_sack, positions.seed)
	_activate_enemy(wind_spirit, positions.wind)
	_active_enemies.assign([leaf_slime, seed_sack, wind_spirit])
	clock_traps.start_wave(number)


func _activate_elite() -> void:
	var enemy := final_enemy()
	_activate_enemy(enemy, Vector2(4450.0, 780.0))
	_active_enemies.assign([enemy])


func _activate_enemy(enemy: PrototypeTarget, spawn_position: Vector2) -> void:
	enemy.set_stage_spawn(spawn_position)
	enemy.damage_receiver.max_health = _enemy_health(enemy)
	enemy.reset_target()
	enemy.visible = true
	enemy.set_process(true)


func _deactivate_enemy(enemy: PrototypeTarget) -> void:
	enemy.set_selected(false)
	enemy.visible = false
	enemy.set_process(false)


func _deactivate_all_combat_enemies() -> void:
	clock_traps.stop()
	for enemy in _all_combat_enemies():
		_deactivate_enemy(enemy)


func _restore_combat_sandbox() -> void:
	route_terrain.configure(1, "meadow", false)
	clock_traps.configure(1, "meadow")
	for gate_index in gates.size():
		_set_gate_closed(gate_index, false)
	for enemy in _all_combat_enemies():
		if enemy in [boss, guardian, sera, heart]:
			_deactivate_enemy(enemy)
			continue
		if enemy is PrototypeEnemy:
			(enemy as PrototypeEnemy).configure_route("meadow")
		var initial_position: Vector2 = _initial_positions.get(enemy.get_path(), enemy.position)
		enemy.damage_receiver.max_health = int(_initial_health.get(enemy.get_path(), enemy.damage_receiver.max_health))
		enemy.set_stage_spawn(initial_position)
		enemy.reset_target()
		enemy.visible = true
		enemy.set_process(true)
	_active_enemies.clear()
	stage_complete = false
	failed = false
	_last_stage_log = "회귀 테스트용 자유 전투"
	_emit_metrics()


func _all_combat_enemies() -> Array[PrototypeTarget]:
	return [leaf_slime, seed_sack, wind_spirit, armored_boar, boss, guardian, sera, heart]


func _active_enemy_count() -> int:
	var alive_count := 0
	for enemy in _active_enemies:
		if enemy != null and enemy.is_targetable():
			alive_count += 1
	return alive_count


func _set_gate_closed(gate_index: int, closed: bool) -> void:
	var gate := gates[gate_index]
	var shape := gate.get_node("CollisionShape2D") as CollisionShape2D
	var visual := gate.get_node("GateVisual") as Polygon2D
	shape.set_deferred("disabled", not closed)
	visual.visible = closed


func _actual_time_summary() -> String:
	if section_actual_times.is_empty():
		return "기록 대기"
	var parts: Array[String] = []
	for index in section_actual_times.size():
		parts.append("%d %.1fs" % [index + 1, section_actual_times[index]])
	return " / ".join(parts)


func _format_seconds(value: float) -> String:
	var total_seconds := maxi(0, int(floor(value)))
	return "%d:%02d" % [int(total_seconds / 60), total_seconds % 60]


func _emit_metrics() -> void:
	stage_metrics_changed.emit(current_metrics())
