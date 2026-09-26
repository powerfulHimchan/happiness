class_name UltimateController
extends Node

## CP-206 공용 필살기 새벽의 틈의 게이지와 선택적 시간 감속을 관리한다.

signal ultimate_metrics_changed(metrics: Dictionary)

const MAX_GAUGE := 100
const BASIC_HIT_GAIN := 4
const SKILL_HIT_GAIN := 8
const PRECISE_EVADE_GAIN := 12
const DURATION_S := 3.0
const ENEMY_TIME_SCALE := 0.15

var gauge: int = 0
var activation_count: int = 0
var basic_gauge_gain_count: int = 0
var skill_gauge_gain_count: int = 0
var precise_evade_count: int = 0
var last_ultimate_log: String = "게이지 충전 대기"
var _active: bool = false
var _remaining_s: float = 0.0

@onready var player: PrototypePlayer = get_parent() as PrototypePlayer
@onready var sword_combat: SwordCombatController = $"../SwordCombatController"
@onready var bow_combat: BowCombatController = $"../BowCombatController"


func _ready() -> void:
	add_to_group("ultimate_controller")
	sword_combat.hit_registered.connect(_on_weapon_hit)
	bow_combat.hit_registered.connect(_on_weapon_hit)
	_emit_metrics()


func _physics_process(delta: float) -> void:
	if _active:
		_remaining_s = maxf(0.0, _remaining_s - delta)
		_apply_enemy_time_scale(ENEMY_TIME_SCALE)
		if _remaining_s <= 0.0:
			_finish_ultimate()
	_emit_metrics()


func request_ultimate() -> void:
	if _active:
		last_ultimate_log = "새벽의 틈 사용 중 · %.1f초 남음" % _remaining_s
		_emit_metrics()
		return
	if gauge < MAX_GAUGE:
		last_ultimate_log = "게이지 부족 · %d%%" % gauge
		_emit_metrics()
		return
	if not player.can_continue_combat_action():
		last_ultimate_log = "현재 필살기 사용 불가"
		_emit_metrics()
		return

	gauge = 0
	_active = true
	_remaining_s = DURATION_S
	activation_count += 1
	last_ultimate_log = "새벽의 틈 발동 · 적 시간 15%%"
	_apply_enemy_time_scale(ENEMY_TIME_SCALE)
	_emit_metrics()


func register_precise_evade() -> void:
	if not player.invincible:
		return
	precise_evade_count += 1
	_add_gauge(PRECISE_EVADE_GAIN, "정확한 회피")


func reset_ultimate() -> void:
	gauge = 0
	activation_count = 0
	basic_gauge_gain_count = 0
	skill_gauge_gain_count = 0
	precise_evade_count = 0
	last_ultimate_log = "게이지 충전 대기"
	_active = false
	_remaining_s = 0.0
	_apply_enemy_time_scale(1.0)
	_emit_metrics()


func force_emit_metrics() -> void:
	_emit_metrics()


func _on_weapon_hit(is_skill: bool, _target: PrototypeTarget, _damage: int) -> void:
	if is_skill:
		skill_gauge_gain_count += 1
		_add_gauge(SKILL_HIT_GAIN, "스킬 적중")
	else:
		basic_gauge_gain_count += 1
		_add_gauge(BASIC_HIT_GAIN, "기본 공격 적중")


func _add_gauge(amount: int, reason: String) -> void:
	if amount <= 0:
		return
	var previous := gauge
	gauge = mini(MAX_GAUGE, gauge + amount)
	last_ultimate_log = "%s +%d · %d%%" % [reason, amount, gauge]
	if previous < MAX_GAUGE and gauge >= MAX_GAUGE:
		last_ultimate_log = "새벽의 틈 준비 완료"
	_emit_metrics()


func _finish_ultimate() -> void:
	_active = false
	_remaining_s = 0.0
	_apply_enemy_time_scale(1.0)
	last_ultimate_log = "새벽의 틈 종료 · 적 시간 정상화"


func _apply_enemy_time_scale(value: float) -> void:
	for node in get_tree().get_nodes_in_group("enemy_time_scaled"):
		if node.has_method("set_enemy_time_scale"):
			node.call("set_enemy_time_scale", value)


func _emit_metrics() -> void:
	var enemy_actor_count := get_tree().get_nodes_in_group("enemy_actor").size()
	var enemy_projectile_count := get_tree().get_nodes_in_group("enemy_projectile").size()
	ultimate_metrics_changed.emit({
		"ultimate_name": "새벽의 틈",
		"ultimate_gauge": gauge,
		"ultimate_gauge_ratio": float(gauge) / float(MAX_GAUGE),
		"ultimate_ready": gauge >= MAX_GAUGE and not _active,
		"ultimate_active": _active,
		"ultimate_remaining_s": _remaining_s,
		"ultimate_duration_s": DURATION_S,
		"enemy_time_scale": ENEMY_TIME_SCALE if _active else 1.0,
		"player_time_scale": 1.0,
		"player_projectile_time_scale": 1.0,
		"ultimate_enemy_actor_count": enemy_actor_count,
		"ultimate_enemy_projectile_count": enemy_projectile_count,
		"ultimate_activation_count": activation_count,
		"ultimate_basic_gain_count": basic_gauge_gain_count,
		"ultimate_skill_gain_count": skill_gauge_gain_count,
		"ultimate_precise_evade_count": precise_evade_count,
		"ultimate_last_log": last_ultimate_log,
	})
