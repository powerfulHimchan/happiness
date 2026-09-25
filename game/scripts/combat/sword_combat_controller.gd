class_name SwordCombatController
extends Node2D

## CP-203 검 자동 3연격과 두 액티브 스킬의 실행 상태를 관리한다.

signal combat_metrics_changed(metrics: Dictionary)

enum Action {
	NONE,
	DASH_SLASH,
	SPIN_SLASH,
}

const COMBO_RESET_S := 0.90
const BASIC_FLASH_S := 0.11
const SKILL_FLASH_S := 0.16

@export var weapon: WeaponDefinition
@export var skill_1: SkillDefinition
@export var skill_2: SkillDefinition

var combo_index: int = 0
var basic_attack_count: int = 0
var skill_hit_count: int = 0
var total_damage: int = 0
var last_combat_log: String = "공격 대기"
var last_event_id: String = "없음"
var active: bool = true
var _basic_remaining_s: float = 0.0
var _combo_idle_s: float = 0.0
var _skill_1_cooldown_s: float = 0.0
var _skill_2_cooldown_s: float = 0.0
var _action: int = Action.NONE
var _action_elapsed_s: float = 0.0
var _next_skill_hit_index: int = 0
var _action_sequence: int = 0
var _captured_target: PrototypeTarget
var _slash_remaining_s: float = 0.0

@onready var player: PrototypePlayer = get_parent() as PrototypePlayer
@onready var target_selector: AutoTargetSelector = $"../AutoTargetSelector"
@onready var slash_sprite: Sprite2D = $SwordSlash


func _ready() -> void:
	slash_sprite.visible = false
	player.evade_started.connect(_on_player_evade_started)
	player.player_died.connect(_on_player_interrupted.bind("사망"))
	player.fall_recovery_started.connect(_on_player_interrupted.bind("낙하"))
	_emit_metrics()


func _physics_process(delta: float) -> void:
	_basic_remaining_s = maxf(0.0, _basic_remaining_s - delta)
	_skill_1_cooldown_s = maxf(0.0, _skill_1_cooldown_s - delta)
	_skill_2_cooldown_s = maxf(0.0, _skill_2_cooldown_s - delta)
	_slash_remaining_s = maxf(0.0, _slash_remaining_s - delta)
	_update_slash_visual()

	if not active:
		_emit_metrics()
		return
	if _action != Action.NONE:
		_update_skill_action(delta)
	elif player.can_use_combat_action():
		_update_basic_attack(delta)
	else:
		_update_combo_timeout(delta)
	_emit_metrics()


func request_skill_1() -> void:
	if not active:
		return
	_start_skill(Action.DASH_SLASH, skill_1, _skill_1_cooldown_s)


func request_skill_2() -> void:
	if not active:
		return
	_start_skill(Action.SPIN_SLASH, skill_2, _skill_2_cooldown_s)


func set_active(enabled: bool) -> void:
	if active == enabled:
		return
	active = enabled
	if not active:
		_finish_action("무기 전환으로 검 공격 중단")
		_slash_remaining_s = 0.0
		slash_sprite.visible = false
	_emit_metrics()


func reset_combat() -> void:
	combo_index = 0
	basic_attack_count = 0
	skill_hit_count = 0
	total_damage = 0
	last_combat_log = "공격 대기"
	last_event_id = "없음"
	_basic_remaining_s = 0.0
	_combo_idle_s = 0.0
	_skill_1_cooldown_s = 0.0
	_skill_2_cooldown_s = 0.0
	_action_sequence = 0
	_finish_action("")
	_emit_metrics()


func force_emit_metrics() -> void:
	_emit_metrics()


func current_metrics() -> Dictionary:
	return _build_metrics()


func _update_basic_attack(delta: float) -> void:
	var target := target_selector.current_target
	if not is_instance_valid(target) or not target.is_targetable():
		_update_combo_timeout(delta)
		return
	_combo_idle_s = 0.0
	if _basic_remaining_s > 0.0:
		return

	var hit_index := combo_index
	_action_sequence += 1
	var damage: int = int(weapon.damage[hit_index])
	var stagger_s := 0.18 if hit_index == 2 else 0.04
	var result := _damage_target(
		target,
		&"sword_basic",
		damage,
		stagger_s,
		PackedStringArray(["sword", "basic", "combo_%d" % (hit_index + 1)]),
		hit_index
	)
	_basic_remaining_s = float(weapon.attack_interval_s[hit_index])
	combo_index = (combo_index + 1) % weapon.damage.size()
	if result == DamageReceiver.Result.APPLIED:
		basic_attack_count += 1
		_show_slash(BASIC_FLASH_S, hit_index)
	last_combat_log = "기본 %d타 · 피해 %d · %s" % [
		hit_index + 1,
		damage,
		DamageReceiver.result_name(result),
	]


func _update_combo_timeout(delta: float) -> void:
	if combo_index == 0:
		_combo_idle_s = 0.0
		return
	_combo_idle_s += delta
	if _combo_idle_s < COMBO_RESET_S:
		return
	combo_index = 0
	_combo_idle_s = 0.0
	last_combat_log = "대상 없음 · 3연격 초기화"


func _start_skill(action: int, definition: SkillDefinition, cooldown_remaining_s: float) -> void:
	if definition == null:
		last_combat_log = "스킬 데이터 없음"
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
	_captured_target = target_selector.current_target
	_basic_remaining_s = maxf(_basic_remaining_s, definition.duration_s)
	_combo_idle_s = 0.0
	if action == Action.DASH_SLASH:
		_skill_1_cooldown_s = definition.cooldown_s
	else:
		_skill_2_cooldown_s = definition.cooldown_s

	var velocity_x := 0.0
	if definition.movement_distance_m > 0.0 and definition.duration_s > 0.0:
		velocity_x = (
			definition.movement_distance_m
			* PrototypePlayer.PIXELS_PER_METER
			/ definition.duration_s
			* float(player.facing_direction)
		)
	player.begin_combat_action(velocity_x, definition.can_move, definition.can_turn)
	player.set_combat_evade_allowed(false)
	last_combat_log = "%s 시작 · 취소 %.2fs부터" % [
		definition.display_name,
		definition.evade_cancel_start_s,
	]


func _update_skill_action(delta: float) -> void:
	if not player.can_continue_combat_action():
		_finish_action("피격 또는 복귀로 중단")
		return
	_action_elapsed_s += delta
	var definition := _current_skill()
	if definition == null:
		_finish_action("스킬 데이터 오류")
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
	var targets: Array[PrototypeTarget] = []
	if _action == Action.DASH_SLASH:
		if is_instance_valid(_captured_target) and _captured_target.is_targetable():
			targets.append(_captured_target)
	else:
		for node in get_tree().get_nodes_in_group("targetable"):
			var target := node as PrototypeTarget
			if target == null or not target.is_targetable():
				continue
			var distance_m := (
				player.global_position.distance_to(target.global_position)
				/ PrototypePlayer.PIXELS_PER_METER
			)
			if distance_m <= definition.hit_range_m:
				targets.append(target)

	var applied_targets := 0
	for target in targets:
		var result := _damage_target(
			target,
			definition.skill_id,
			int(definition.damage[hit_index]),
			0.16 if _action == Action.DASH_SLASH else 0.10,
			PackedStringArray(["sword", "skill", "hit_%d" % (hit_index + 1)]),
			hit_index
		)
		if result == DamageReceiver.Result.APPLIED:
			applied_targets += 1
			skill_hit_count += 1
	_show_slash(SKILL_FLASH_S, hit_index + 3)
	last_combat_log = "%s %d타 · 피해 %d · %d개체" % [
		definition.display_name,
		hit_index + 1,
		int(definition.damage[hit_index]),
		applied_targets,
	]


func _damage_target(
	target: PrototypeTarget,
	attack_id: StringName,
	damage: int,
	stagger_s: float,
	tags: PackedStringArray,
	hit_index: int
) -> int:
	var event := DamageEvent.new()
	event.event_id = StringName("player:%s:%d:%d:%s" % [
		String(attack_id),
		_action_sequence,
		hit_index,
		target.target_key,
	])
	event.attacker_id = &"player"
	event.attack_id = attack_id
	event.damage = damage
	event.stagger_s = stagger_s
	event.tags = tags
	event.source_position = player.global_position
	last_event_id = String(event.event_id)
	var result := target.receive_damage(event)
	if result == DamageReceiver.Result.APPLIED:
		total_damage += damage
	return result


func _show_slash(duration_s: float, variant: int) -> void:
	_slash_remaining_s = duration_s
	slash_sprite.visible = true
	slash_sprite.rotation = float(variant % 4) * 0.42 - 0.48
	if _action == Action.SPIN_SLASH:
		slash_sprite.scale = Vector2(1.55, 1.55)
	else:
		slash_sprite.scale = Vector2.ONE


func _update_slash_visual() -> void:
	if _slash_remaining_s <= 0.0:
		slash_sprite.visible = false
		return
	slash_sprite.visible = true
	var direction := float(player.facing_direction)
	slash_sprite.position = Vector2(88.0 * direction, -42.0)
	slash_sprite.flip_h = direction < 0.0
	if _action == Action.SPIN_SLASH:
		slash_sprite.rotation += 0.34 * direction


func _current_skill() -> SkillDefinition:
	if _action == Action.DASH_SLASH:
		return skill_1
	if _action == Action.SPIN_SLASH:
		return skill_2
	return null


func _action_name() -> String:
	var definition := _current_skill()
	return definition.display_name if definition != null else "자동 공격"


func _finish_action(reason: String) -> void:
	if _action != Action.NONE and not reason.is_empty():
		last_combat_log = reason
	_action = Action.NONE
	_action_elapsed_s = 0.0
	_next_skill_hit_index = 0
	_captured_target = null
	player.end_combat_action()
	player.set_combat_evade_allowed(true)


func _on_player_evade_started() -> void:
	if _action != Action.NONE:
		_finish_action("회피로 공격 취소")
	_slash_remaining_s = 0.0
	slash_sprite.visible = false


func _on_player_interrupted(reason: String) -> void:
	if _action != Action.NONE:
		_finish_action("%s로 공격 중단" % reason)


func _emit_metrics() -> void:
	combat_metrics_changed.emit(_build_metrics())


func _build_metrics() -> Dictionary:
	var target := target_selector.current_target
	return {
		"active_weapon_id": "sword",
		"weapon_name": weapon.display_name if weapon != null else "없음",
		"combat_action": _action_name(),
		"combo_next_hit": combo_index + 1,
		"combo_reset_remaining_s": maxf(0.0, COMBO_RESET_S - _combo_idle_s),
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
		"projectile_fired_count": 0,
		"near_damage_reduced_count": 0,
		"piercing_last_hit_count": 0,
	}
