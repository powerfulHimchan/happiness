class_name PrototypeStageRunner
extends Node

## CP-303의 전진 2개, 웨이브 2개, 정예 1개 구간을 순서대로 진행한다.
## 180초는 측정 목표이며 제한 시간이 아니다. 구간 완료 조건만 다음 관문을 연다.

signal stage_metrics_changed(metrics: Dictionary)

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
const SECTION_TARGET_SECONDS := PackedFloat32Array([40.0, 35.0, 35.0, 40.0, 30.0])
const STAGE_TARGET_SECONDS := 180.0
const ADVANCE_ONE_X := 1230.0
const ADVANCE_TWO_X := 3830.0

@export var stage_enabled: bool = true

@onready var player: PrototypePlayer = get_node("../Player") as PrototypePlayer
@onready var leaf_slime: PrototypeEnemy = get_node("../Targets/LeafSlime") as PrototypeEnemy
@onready var seed_sack: PrototypeEnemy = get_node("../Targets/SeedSack") as PrototypeEnemy
@onready var wind_spirit: PrototypeEnemy = get_node("../Targets/WindSpirit") as PrototypeEnemy
@onready var armored_boar: EliteArmoredBoar = get_node("../Targets/ArmoredBoar") as EliteArmoredBoar
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


func _ready() -> void:
	for enemy in _all_combat_enemies():
		_initial_positions[enemy.get_path()] = enemy.position
	if stage_enabled:
		reset_stage()
	else:
		_restore_combat_sandbox()


func _process(delta: float) -> void:
	if not stage_enabled or stage_complete:
		return
	stage_elapsed_s += delta
	section_elapsed_s += delta
	_metric_elapsed_s += delta

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


func reset_stage() -> void:
	if not stage_enabled:
		return
	for projectile in get_tree().get_nodes_in_group("enemy_projectile"):
		projectile.queue_free()
	for enemy in _all_combat_enemies():
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
	_emit_metrics()


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
	var target_s := 0.0 if stage_complete else float(SECTION_TARGET_SECONDS[display_index])
	var closed_gate_count := 0
	for gate_index in gates.size():
		if is_gate_closed(gate_index):
			closed_gate_count += 1
	return {
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
		Section.WAVE_TWO:
			_deactivate_all_combat_enemies()
			_activate_elite()
		Section.ELITE:
			_deactivate_all_combat_enemies()
			_set_gate_closed(3, false)
			stage_complete = true

	if stage_complete:
		_last_stage_log = "스테이지 완료 · %s" % _format_seconds(stage_elapsed_s)
	else:
		_last_stage_log = "구간 %d/5 시작 · %s" % [
			current_section + 1,
			SECTION_OBJECTIVES[current_section],
		]
	_emit_metrics()


func _activate_wave_one() -> void:
	_activate_enemy(leaf_slime, Vector2(1510.0, 780.0))
	_activate_enemy(seed_sack, Vector2(1900.0, 780.0))
	_active_enemies.assign([leaf_slime, seed_sack])


func _activate_wave_two() -> void:
	_activate_enemy(leaf_slime, Vector2(4020.0, 780.0))
	_activate_enemy(seed_sack, Vector2(4380.0, 780.0))
	_activate_enemy(wind_spirit, Vector2(4200.0, 590.0))
	_active_enemies.assign([leaf_slime, seed_sack, wind_spirit])


func _activate_elite() -> void:
	_activate_enemy(armored_boar, Vector2(4450.0, 780.0))
	_active_enemies.assign([armored_boar])


func _activate_enemy(enemy: PrototypeTarget, spawn_position: Vector2) -> void:
	enemy.set_stage_spawn(spawn_position)
	enemy.reset_target()
	enemy.visible = true
	enemy.set_process(true)


func _deactivate_enemy(enemy: PrototypeTarget) -> void:
	enemy.set_selected(false)
	enemy.visible = false
	enemy.set_process(false)


func _deactivate_all_combat_enemies() -> void:
	for enemy in _all_combat_enemies():
		_deactivate_enemy(enemy)


func _restore_combat_sandbox() -> void:
	for gate_index in gates.size():
		_set_gate_closed(gate_index, false)
	for enemy in _all_combat_enemies():
		var initial_position: Vector2 = _initial_positions.get(enemy.get_path(), enemy.position)
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
	return [leaf_slime, seed_sack, wind_spirit, armored_boar]


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
	return "%d:%02d" % [total_seconds / 60, total_seconds % 60]


func _emit_metrics() -> void:
	stage_metrics_changed.emit(current_metrics())
