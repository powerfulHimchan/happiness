class_name BowCombatController
extends Node2D

## CP-204 활 자동 사격, 관통 화살과 화살비를 관리한다.

signal combat_metrics_changed(metrics: Dictionary)
signal hit_registered(is_skill: bool, target: PrototypeTarget, damage: int)

enum Action {
	NONE,
	PIERCING_ARROW,
	ARROW_RAIN,
}

const SWORD_RANGE_M := 1.6
const CLOSE_DAMAGE_MULTIPLIER := 0.80
const PROJECTILE_SCENE := preload("res://scenes/combat/bow_projectile.tscn")

@export var weapon: WeaponDefinition
@export var skill_1: SkillDefinition
@export var skill_2: SkillDefinition

var active: bool = false
var basic_attack_count: int = 0
var skill_hit_count: int = 0
var total_damage: int = 0
var projectile_fired_count: int = 0
var near_damage_reduced_count: int = 0
var piercing_last_hit_count: int = 0
var last_combat_log: String = "활 공격 대기"
var last_event_id: String = "없음"
var _basic_remaining_s: float = 0.0
var _skill_1_cooldown_s: float = 0.0
var _skill_2_cooldown_s: float = 0.0
var _action: int = Action.NONE
var _action_elapsed_s: float = 0.0
var _next_skill_hit_index: int = 0
var _action_sequence: int = 0
var _rain_anchor: Vector2 = Vector2.ZERO
var _piercing_projectile_id: String = ""

@onready var player: PrototypePlayer = get_parent() as PrototypePlayer
@onready var target_selector: AutoTargetSelector = $"../AutoTargetSelector"
@onready var rain_marker: Sprite2D = $RainMarker


func _ready() -> void:
	rain_marker.visible = false
	player.evade_started.connect(_on_player_evade_started)
	player.player_died.connect(_on_player_interrupted.bind("사망"))
	player.fall_recovery_started.connect(_on_player_interrupted.bind("낙하"))
	_emit_metrics()


func _physics_process(delta: float) -> void:
	_basic_remaining_s = maxf(0.0, _basic_remaining_s - delta)
	_skill_1_cooldown_s = maxf(0.0, _skill_1_cooldown_s - delta)
	_skill_2_cooldown_s = maxf(0.0, _skill_2_cooldown_s - delta)
	if not active:
		_emit_metrics()
		return
	if _action != Action.NONE:
		_update_skill_action(delta)
	elif player.can_use_combat_action():
		_update_basic_attack()
	_emit_metrics()


func set_active(enabled: bool) -> void:
	if active == enabled:
		return
	active = enabled
	if not active:
		_finish_action("무기 전환으로 활 공격 중단")
	_emit_metrics()


func request_skill_1() -> void:
	if active:
		_start_skill(Action.PIERCING_ARROW, skill_1, _skill_1_cooldown_s)


func request_skill_2() -> void:
	if active:
		_start_skill(Action.ARROW_RAIN, skill_2, _skill_2_cooldown_s)


func reset_combat() -> void:
	basic_attack_count = 0
	skill_hit_count = 0
	total_damage = 0
	projectile_fired_count = 0
	near_damage_reduced_count = 0
	piercing_last_hit_count = 0
	last_combat_log = "활 공격 대기"
	last_event_id = "없음"
	_basic_remaining_s = 0.0
	_skill_1_cooldown_s = 0.0
	_skill_2_cooldown_s = 0.0
	_action_sequence = 0
	_finish_action("")
	for node in get_tree().get_nodes_in_group("bow_projectile"):
		node.queue_free()
	_emit_metrics()


func force_emit_metrics() -> void:
	_emit_metrics()


func current_metrics() -> Dictionary:
	return _build_metrics()


func _update_basic_attack() -> void:
	var target := target_selector.current_target
	if _basic_remaining_s > 0.0 \
	or not is_instance_valid(target) \
	or not target.is_targetable() \
	or not target_selector.is_target_on_screen(target):
		return

	_action_sequence += 1
	var target_point := target.global_position + Vector2(0.0, -38.0)
	var origin := _projectile_origin()
	var distance_m := origin.distance_to(target.closest_hit_point(origin)) / PrototypePlayer.PIXELS_PER_METER
	var shot_damage: int = int(weapon.damage[0])
	var close_reduced := distance_m <= SWORD_RANGE_M
	if close_reduced:
		shot_damage = roundi(float(shot_damage) * CLOSE_DAMAGE_MULTIPLIER)
		near_damage_reduced_count += 1
	var projectile_id := "player:bow_basic:%d" % _action_sequence
	_spawn_projectile(
		projectile_id,
		&"bow_basic",
		shot_damage,
		1,
		(target_point - origin).normalized(),
		PackedStringArray(["bow", "basic", "close_reduced" if close_reduced else "full_damage"])
	)
	_basic_remaining_s = float(weapon.attack_interval_s[0])
	basic_attack_count += 1
	last_combat_log = "기본 사격 · 피해 %d%s" % [
		shot_damage,
		" · 근접 -20%" if close_reduced else "",
	]


func _start_skill(action: int, definition: SkillDefinition, cooldown_remaining_s: float) -> void:
	if definition == null:
		last_combat_log = "활 스킬 데이터 없음"
		return
	if cooldown_remaining_s > 0.0:
		last_combat_log = "%s · %.1f초 대기" % [definition.display_name, cooldown_remaining_s]
		return
	if _action != Action.NONE:
		last_combat_log = "%s 사용 중" % _action_name()
		return
	if not player.can_use_combat_action():
		last_combat_log = "%s · 현재 사용 불가" % definition.display_name
		return

	_action = action
	_action_elapsed_s = 0.0
	_next_skill_hit_index = 0
	_action_sequence += 1
	_basic_remaining_s = maxf(_basic_remaining_s, definition.duration_s)
	if action == Action.PIERCING_ARROW:
		_skill_1_cooldown_s = definition.cooldown_s
		piercing_last_hit_count = 0
		_piercing_projectile_id = "player:bow_piercing:%d" % _action_sequence
	else:
		_skill_2_cooldown_s = definition.cooldown_s
		var target := target_selector.current_target
		_rain_anchor = (
			target.global_position
			if is_instance_valid(target)
			else player.global_position + Vector2(420.0 * float(player.facing_direction), 0.0)
		)
		rain_marker.global_position = _rain_anchor + Vector2(0.0, -92.0)
		rain_marker.visible = true

	player.begin_combat_action(0.0, definition.can_move, definition.can_turn)
	player.set_combat_evade_allowed(false)
	last_combat_log = "%s 시작 · 취소 %.2fs부터" % [
		definition.display_name,
		definition.evade_cancel_start_s,
	]


func _update_skill_action(delta: float) -> void:
	if not player.can_continue_combat_action():
		_finish_action("피격 또는 복귀로 활 스킬 중단")
		return
	_action_elapsed_s += delta
	var definition := _current_skill()
	if definition == null:
		_finish_action("활 스킬 데이터 오류")
		return
	if _action_elapsed_s >= definition.evade_cancel_start_s:
		player.set_combat_evade_allowed(true)

	while _next_skill_hit_index < definition.hit_times_s.size() \
	and _action_elapsed_s >= float(definition.hit_times_s[_next_skill_hit_index]):
		_execute_skill_hit(definition, _next_skill_hit_index)
		_next_skill_hit_index += 1
	if _action_elapsed_s >= definition.duration_s:
		_finish_action("%s 완료" % definition.display_name)


func _execute_skill_hit(definition: SkillDefinition, hit_index: int) -> void:
	if _action == Action.PIERCING_ARROW:
		var origin := _projectile_origin()
		var target := target_selector.current_target
		var direction := Vector2(float(player.facing_direction), 0.0)
		if is_instance_valid(target) and target_selector.is_target_on_screen(target):
			direction = (
				target.global_position + Vector2(0.0, -38.0) - origin
			).normalized()
		_spawn_projectile(
			_piercing_projectile_id,
			definition.skill_id,
			int(definition.damage[hit_index]),
			definition.max_targets,
			direction,
			PackedStringArray(["bow", "skill", "piercing"])
		)
		last_combat_log = "관통 화살 발사 · 피해 36 · 최대 3개체"
		return

	var applied_targets := 0
	for node in get_tree().get_nodes_in_group("targetable"):
		var rain_target := node as PrototypeTarget
		if rain_target == null or not rain_target.is_targetable():
			continue
		if not target_selector.is_target_on_screen(rain_target):
			continue
		var distance_m := _rain_anchor.distance_to(rain_target.global_position) / PrototypePlayer.PIXELS_PER_METER
		if distance_m > definition.hit_range_m:
			continue
		var event := DamageEvent.new()
		event.event_id = StringName("player:bow_arrow_rain:%d:%d:%s" % [
			_action_sequence,
			hit_index,
			rain_target.target_key,
		])
		event.attacker_id = &"player"
		event.attack_id = definition.skill_id
		event.damage = int(definition.damage[hit_index])
		event.stagger_s = 0.04
		event.tags = PackedStringArray(["bow", "skill", "area", "rain_hit"])
		event.source_position = _rain_anchor
		last_event_id = String(event.event_id)
		var result := rain_target.receive_damage(event)
		if result == DamageReceiver.Result.APPLIED:
			applied_targets += 1
			skill_hit_count += 1
			total_damage += event.damage
			hit_registered.emit(true, rain_target, event.damage)
	last_combat_log = "화살비 %d/6 · 피해 8 · %d개체" % [
		hit_index + 1,
		applied_targets,
	]


func _spawn_projectile(
	projectile_id: String,
	attack_id: StringName,
	damage: int,
	max_hits: int,
	direction: Vector2,
	tags: PackedStringArray
) -> void:
	var projectile := PROJECTILE_SCENE.instantiate() as BowProjectile
	projectile.configure(
		projectile_id,
		attack_id,
		damage,
		weapon.projectile_speed_mps,
		weapon.attack_range_m,
		max_hits,
		direction,
		tags
	)
	projectile.hit_registered.connect(_on_projectile_hit)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = _projectile_origin()
	projectile_fired_count += 1
	last_event_id = projectile_id


func _projectile_origin() -> Vector2:
	return player.global_position + Vector2(58.0 * float(player.facing_direction), -48.0)


func _on_projectile_hit(
	target: PrototypeTarget,
	damage: int,
	result: int,
	projectile_id: String
) -> void:
	if result == DamageReceiver.Result.APPLIED:
		total_damage += damage
		var is_skill := projectile_id == _piercing_projectile_id
		if is_skill:
			piercing_last_hit_count += 1
			skill_hit_count += 1
		hit_registered.emit(is_skill, target, damage)
	last_combat_log = "%s 적중 · 피해 %d · %s" % [
		target.target_key,
		damage,
		DamageReceiver.result_name(result),
	]


func _current_skill() -> SkillDefinition:
	if _action == Action.PIERCING_ARROW:
		return skill_1
	if _action == Action.ARROW_RAIN:
		return skill_2
	return null


func _action_name() -> String:
	var definition := _current_skill()
	return definition.display_name if definition != null else "자동 사격"


func _finish_action(reason: String) -> void:
	if _action != Action.NONE and not reason.is_empty():
		last_combat_log = reason
	_action = Action.NONE
	_action_elapsed_s = 0.0
	_next_skill_hit_index = 0
	rain_marker.visible = false
	player.end_combat_action()
	player.set_combat_evade_allowed(true)


func _on_player_evade_started() -> void:
	if _action != Action.NONE:
		_finish_action("회피로 활 스킬 취소")


func _on_player_interrupted(reason: String) -> void:
	if _action != Action.NONE:
		_finish_action("%s로 활 스킬 중단" % reason)


func _emit_metrics() -> void:
	combat_metrics_changed.emit(_build_metrics())


func _build_metrics() -> Dictionary:
	var target := target_selector.current_target
	return {
		"active_weapon_id": "bow",
		"weapon_name": weapon.display_name if weapon != null else "없음",
		"combat_action": _action_name(),
		"combo_next_hit": 1,
		"combo_reset_remaining_s": 0.0,
		"basic_attack_remaining_s": _basic_remaining_s,
		"skill_1_name": skill_1.display_name if skill_1 != null else "스킬 1",
		"skill_1_cooldown_s": _skill_1_cooldown_s,
		"skill_2_name": skill_2.display_name if skill_2 != null else "스킬 2",
		"skill_2_cooldown_s": _skill_2_cooldown_s,
		"combat_evade_cancel_ready": player.combat_evade_allowed,
		"basic_attack_count": basic_attack_count,
		"skill_hit_count": skill_hit_count,
		"combat_total_damage": total_damage,
		"combat_last_log": last_combat_log,
		"combat_last_event_id": last_event_id,
		"combat_target_health": target.health_summary() if is_instance_valid(target) else "대상 없음",
		"projectile_fired_count": projectile_fired_count,
		"near_damage_reduced_count": near_damage_reduced_count,
		"piercing_last_hit_count": piercing_last_hit_count,
	}
