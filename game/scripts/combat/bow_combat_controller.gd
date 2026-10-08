class_name BowCombatController
extends Node2D

## CP-204 활 자동 사격, 관통 화살과 화살비를 관리한다.

signal combat_metrics_changed(metrics: Dictionary)
signal hit_registered(is_skill: bool, target: PrototypeTarget, damage: int)

enum Action {
	NONE,
	PIERCING_ARROW,
	ARROW_RAIN,
	SPREAD_ARROW,
	FOCUS_ARROW,
	HOMING_ARROW,
}

const SWORD_RANGE_M := 1.6
const CLOSE_DAMAGE_MULTIPLIER := 0.80
const PROJECTILE_SCENE := preload("res://scenes/combat/bow_projectile.tscn")
const SPREAD_ANGLES_DEG := [-15.0, 0.0, 15.0]

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
var _action_slot: int = 0
var _action: int = Action.NONE
var _action_elapsed_s: float = 0.0
var _next_skill_hit_index: int = 0
var _action_sequence: int = 0
var _rain_anchor: Vector2 = Vector2.ZERO
var _piercing_projectile_id: String = ""
var _spread_direction := Vector2.RIGHT
var _homing_target: WeakRef
var _homing_generation: int = -1

@onready var player: PrototypePlayer = get_parent() as PrototypePlayer
@onready var target_selector: AutoTargetSelector = $"../AutoTargetSelector"
@onready var rain_marker: Sprite2D = $RainMarker


func _ready() -> void:
	rain_marker.visible = false
	player.evade_started.connect(_on_player_evade_started)
	player.player_died.connect(_on_player_interrupted.bind("사망"))
	player.phoenix_revived.connect(_on_player_interrupted.bind("부활"))
	player.fall_recovery_started.connect(_on_player_interrupted.bind("낙하"))
	_emit_metrics()


func _physics_process(delta: float) -> void:
	queue_redraw()
	_basic_remaining_s = maxf(0.0, _basic_remaining_s - delta)
	_skill_1_cooldown_s = maxf(0.0, _skill_1_cooldown_s - delta * player.skill_recharge_multiplier())
	_skill_2_cooldown_s = maxf(0.0, _skill_2_cooldown_s - delta * player.skill_recharge_multiplier())
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
		_start_skill(_skill_action(skill_1), skill_1, _skill_1_cooldown_s, 1)


func request_skill_2() -> void:
	if active:
		_start_skill(_skill_action(skill_2), skill_2, _skill_2_cooldown_s, 2)


func _skill_action(definition: SkillDefinition) -> int:
	if definition != null and definition.skill_id == &"bow_homing":
		return Action.HOMING_ARROW
	if definition != null and definition.skill_id == &"bow_focus":
		return Action.FOCUS_ARROW
	if definition != null and definition.skill_id == &"bow_spread":
		return Action.SPREAD_ARROW
	return Action.ARROW_RAIN if definition != null and definition.skill_id == &"bow_arrow_rain" else Action.PIERCING_ARROW


func _draw() -> void:
	if _action != Action.FOCUS_ARROW:
		return
	var ready := clampf(_action_elapsed_s / 0.70, 0.0, 1.0)
	var start := Vector2(58 * _spread_direction.x, -48)
	draw_line(start, start + _spread_direction * weapon.attack_range_m * PrototypePlayer.PIXELS_PER_METER, Color(1, 0.85, 0.4, 0.15 + ready * 0.4), 2 + ready * 3, true)
	draw_arc(start, 12 + ready * 8, 0, TAU, 24, Color("ffd166"), 3, true)


func prepare_next_stage() -> void:
	_finish_action("스테이지 이동 · 활 행동 정리")
	_emit_metrics()


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
		player.growth_damage(shot_damage, "bow"),
		" · 근접 -20%" if close_reduced else "",
	]


func _start_skill(action: int, definition: SkillDefinition, cooldown_remaining_s: float, slot: int = 1) -> void:
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

	_action_slot = slot
	_action = action
	_action_elapsed_s = 0.0
	_next_skill_hit_index = 0
	_action_sequence += 1
	_basic_remaining_s = maxf(_basic_remaining_s, definition.duration_s)
	if slot == 1:
		_skill_1_cooldown_s = definition.cooldown_s
	else:
		_skill_2_cooldown_s = definition.cooldown_s
	if action != Action.ARROW_RAIN:
		piercing_last_hit_count = 0
		_piercing_projectile_id = "player:bow_piercing:%d" % _action_sequence
		_spread_direction = Vector2(float(player.facing_direction), 0.0)
		if action == Action.HOMING_ARROW:
			target_selector.force_scan()
			var target := target_selector.current_target
			if is_instance_valid(target) and target.is_targetable() and not target.damage_receiver.dead and target_selector.is_target_on_screen(target):
				_homing_target = weakref(target)
				_homing_generation = target.spawn_generation
	else:
		var target := target_selector.current_target
		_rain_anchor = (
			target.global_position
			if is_instance_valid(target)
			else player.global_position + Vector2(420.0 * float(player.facing_direction), 0.0)
		)
		rain_marker.global_position = _rain_anchor + Vector2(0.0, -92.0)
		rain_marker.visible = true

	var velocity_x := 0.0
	if not is_zero_approx(definition.movement_distance_m) and definition.duration_s > 0.0:
		velocity_x = definition.movement_distance_m * PrototypePlayer.PIXELS_PER_METER / definition.duration_s * float(player.facing_direction)
	player.begin_combat_action(velocity_x, definition.can_move, definition.can_turn)
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
	if _action == Action.HOMING_ARROW:
		var target: PrototypeTarget = _homing_target.get_ref() as PrototypeTarget if _homing_target != null else null
		if not is_instance_valid(target) or target.is_queued_for_deletion() or target.spawn_generation != _homing_generation or not target.is_targetable() or target.damage_receiver.dead or not target_selector.is_target_on_screen(target):
			target = null
		var direction := _spread_direction
		if target != null:
			direction = (target.global_position + PrototypeTarget.BODY_CENTER - _projectile_origin()).normalized()
		_spawn_projectile("player:bow_homing:%d:%d" % [_action_sequence, hit_index], definition.skill_id, int(definition.damage[hit_index]), definition.max_targets, direction, PackedStringArray(["bow", "skill", "homing"]), target)
		last_combat_log = "추적 사격 · 피해 %d · 표적 고정" % player.growth_damage(int(definition.damage[hit_index]), "bow", "skill") if target != null else "추적 사격 · 표적 없음 · 정면 직진"
		return
	if _action == Action.SPREAD_ARROW:
		for i in SPREAD_ANGLES_DEG.size():
			_spawn_projectile("player:bow_spread:%d:%d:%d" % [_action_sequence, hit_index, i], definition.skill_id, int(definition.damage[hit_index]), definition.max_targets, _spread_direction.rotated(deg_to_rad(SPREAD_ANGLES_DEG[i])), PackedStringArray(["bow", "skill", "spread"]))
		last_combat_log = "산개 사격 · 화살 3발 · 각 피해 %d · 정면 30도" % player.growth_damage(int(definition.damage[hit_index]), "bow", "skill")
		return
	if _action in [Action.PIERCING_ARROW, Action.FOCUS_ARROW]:
		var origin := _projectile_origin()
		var target := target_selector.current_target
		var direction := Vector2(float(player.facing_direction), 0.0)
		if _action == Action.FOCUS_ARROW or definition.skill_id == &"bow_retreat":
			direction = _spread_direction
		elif is_instance_valid(target) and target_selector.is_target_on_screen(target):
			direction = (
				target.global_position + Vector2(0.0, -38.0) - origin
			).normalized()
		var projectile_id := "%s:%d" % [_piercing_projectile_id, hit_index]
		_spawn_projectile(
			projectile_id,
			definition.skill_id,
			int(definition.damage[hit_index]),
			definition.max_targets,
			direction,
			PackedStringArray(["bow", "skill", "piercing"])
		)
		last_combat_log = "%s %d타 · 피해 %d · 최대 %d개체" % [definition.display_name, hit_index + 1, player.growth_damage(int(definition.damage[hit_index]), "bow", "skill"), definition.max_targets]
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
		event.damage = player.growth_damage(int(definition.damage[hit_index]), "bow", "skill")
		event.stagger_s = 0.04
		event.tags = PackedStringArray(["bow", "skill", "area", "rain_hit"])
		event.source_position = _rain_anchor
		last_event_id = String(event.event_id)
		var result := player.deal_weapon_damage(rain_target, event)
		if result == DamageReceiver.Result.APPLIED:
			applied_targets += 1
			skill_hit_count += 1
			total_damage += event.damage
			hit_registered.emit(true, rain_target, event.damage)
	last_combat_log = "화살비 %d/6 · 피해 %d · %d개체" % [
		hit_index + 1,
		player.growth_damage(int(definition.damage[hit_index]), "bow", "skill"),
		applied_targets,
	]


func _spawn_projectile(
	projectile_id: String,
	attack_id: StringName,
	damage: int,
	max_hits: int,
	direction: Vector2,
	tags: PackedStringArray,
	tracking_target: PrototypeTarget = null
) -> void:
	var projectile := PROJECTILE_SCENE.instantiate() as BowProjectile
	projectile.configure(
		projectile_id,
		attack_id,
		player.growth_damage(damage, "bow", "skill" if tags.has("skill") else "basic"),
		weapon.projectile_speed_mps,
		weapon.attack_range_m,
		max_hits,
		direction,
		tags
	)
	projectile.damage_handler = player.deal_weapon_damage
	projectile.set_tracking_target(tracking_target)
	projectile.hit_registered.connect(_on_projectile_hit.bind(tags.has("skill")))
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = _projectile_origin()
	projectile_fired_count += 1
	last_event_id = projectile_id


func _projectile_origin() -> Vector2:
	return player.global_position + Vector2(58.0 * (_spread_direction.x if _action == Action.HOMING_ARROW else float(player.facing_direction)), -48.0)


func _on_projectile_hit(
	target: PrototypeTarget,
	damage: int,
	result: int,
	projectile_id: String,
	is_skill: bool = false
) -> void:
	if result == DamageReceiver.Result.APPLIED:
		total_damage += damage
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
	if _action != Action.NONE:
		return skill_1 if _action_slot == 1 else skill_2
	return null


func _action_name() -> String:
	var definition := _current_skill()
	return definition.display_name if definition != null else "자동 사격"


func _finish_action(reason: String) -> void:
	_homing_target = null
	_homing_generation = -1
	queue_redraw()
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
		"skill_1_cooldown_s": _skill_1_cooldown_s / player.skill_recharge_multiplier(),
		"skill_2_name": skill_2.display_name if skill_2 != null else "스킬 2",
		"skill_2_cooldown_s": _skill_2_cooldown_s / player.skill_recharge_multiplier(),
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
