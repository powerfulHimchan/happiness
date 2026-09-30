class_name UltimateController
extends Node

## CP-206 공용 필살기 및 GP-103 직업 필살기·선택적 시간 감속.

signal ultimate_metrics_changed(metrics: Dictionary)
signal precise_evade_registered
signal ultimate_activated

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
var selected_profile: Dictionary = {}
var _active_profile: Dictionary = {}
var last_burst_hits: int = 0

@onready var target_selector: AutoTargetSelector = $"../AutoTargetSelector"

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
		_apply_enemy_time_scale(float(_active_profile.get("slow", ENEMY_TIME_SCALE)))
		if _remaining_s <= 0.0:
			_finish_ultimate()
	_emit_metrics()


func request_ultimate() -> void:
	if _active:
		last_ultimate_log = "%s 사용 중 · %.1f초 남음" % [_ultimate_name(), _remaining_s]
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
	_active_profile = selected_profile.duplicate(true)
	_remaining_s = float(_active_profile.get("duration", DURATION_S))
	activation_count += 1
	last_burst_hits = 0
	last_ultimate_log = "%s 발동 · 적 시간 %d%%" % [_ultimate_name(), roundi(float(_active_profile.get("slow", ENEMY_TIME_SCALE)) * 100.0)]
	_apply_enemy_time_scale(float(_active_profile.get("slow", ENEMY_TIME_SCALE)))
	ultimate_activated.emit()
	_apply_job_effect()
	_emit_metrics()


func select_job_ultimate(job_id: String, ultimate_id: String) -> bool:
	if not selected_profile.is_empty():
		return false
	for candidate in PrototypeJobRewards.ultimates_for(job_id):
		if candidate["id"] == ultimate_id:
			selected_profile = candidate.duplicate(true)
			last_ultimate_log = "%s 선택 · 게이지 유지" % candidate["name"]
			_emit_metrics()
			return true
	return false


func _apply_job_effect() -> void:
	var healing := int(_active_profile.get("heal", 0))
	if healing > 0:
		player.apply_growth_health(0, healing)
	var base_damage := int(_active_profile.get("damage", 0))
	if base_damage <= 0:
		return
	var weapon := String(_active_profile["weapon"])
	for node in get_tree().get_nodes_in_group("combat_enemy"):
		var target := node as PrototypeTarget
		if not is_instance_valid(target) or not target.is_targetable() or target.damage_receiver.dead:
			continue
		var offset := target.global_position - player.global_position
		var radius := float(_active_profile["range"])
		if bool(_active_profile.get("forward", false)):
			if offset.x * player.facing_direction < 0.0 or absf(offset.x) > radius or absf(offset.y) > 220.0 or not target_selector.is_target_on_screen(target):
				continue
		elif offset.length() > radius:
			continue
		var event := DamageEvent.new()
		event.event_id = StringName("ultimate:%s:%d" % [get_instance_id(), activation_count])
		event.attacker_id = &"player"
		event.attack_id = StringName(_active_profile["id"])
		event.damage = player.growth_damage(base_damage, weapon)
		event.stagger_s = 0.30
		event.tags = PackedStringArray([weapon, "ultimate"])
		event.source_position = player.global_position
		if target.receive_damage(event) == DamageReceiver.Result.APPLIED:
			last_burst_hits += 1


func _ultimate_name() -> String:
	return String((_active_profile if _active else selected_profile).get("name", "새벽의 틈"))


func register_precise_evade() -> void:
	if not player.invincible:
		return
	precise_evade_count += 1
	precise_evade_registered.emit()
	_add_gauge(PRECISE_EVADE_GAIN, "정확한 회피")


func finish_stage_effect() -> void:
	if _active:
		_finish_ultimate()
	else:
		_apply_enemy_time_scale(1.0)
	_emit_metrics()


func grant_stage_gauge(amount: int) -> void:
	_add_gauge(amount, "경로 보상")


func reset_ultimate() -> void:
	gauge = 0
	activation_count = 0
	basic_gauge_gain_count = 0
	skill_gauge_gain_count = 0
	precise_evade_count = 0
	last_ultimate_log = "게이지 충전 대기"
	_active = false
	_remaining_s = 0.0
	selected_profile.clear()
	_active_profile.clear()
	last_burst_hits = 0
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
		last_ultimate_log = "%s 준비 완료" % _ultimate_name()
	_emit_metrics()


func _finish_ultimate() -> void:
	var finished_name := _ultimate_name()
	_active = false
	_remaining_s = 0.0
	_apply_enemy_time_scale(1.0)
	_active_profile.clear()
	last_ultimate_log = "%s 종료 · 적 시간 정상화" % finished_name


func _apply_enemy_time_scale(value: float) -> void:
	for node in get_tree().get_nodes_in_group("enemy_time_scaled"):
		if node.has_method("set_enemy_time_scale"):
			node.call("set_enemy_time_scale", value)


func _emit_metrics() -> void:
	var enemy_actor_count := get_tree().get_nodes_in_group("enemy_actor").size()
	var enemy_projectile_count := get_tree().get_nodes_in_group("enemy_projectile").size()
	ultimate_metrics_changed.emit({
		"ultimate_name": _ultimate_name(),
		"ultimate_selected_id": selected_profile.get("id", ""),
		"ultimate_burst_hits": last_burst_hits,
		"ultimate_gauge": gauge,
		"ultimate_gauge_ratio": float(gauge) / float(MAX_GAUGE),
		"ultimate_ready": gauge >= MAX_GAUGE and not _active,
		"ultimate_active": _active,
		"ultimate_remaining_s": _remaining_s,
		"ultimate_duration_s": float((_active_profile if _active else selected_profile).get("duration", DURATION_S)),
		"enemy_time_scale": float(_active_profile.get("slow", ENEMY_TIME_SCALE)) if _active else 1.0,
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
