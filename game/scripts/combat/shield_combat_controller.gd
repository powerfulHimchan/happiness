class_name ShieldCombatController
extends SwordCombatController

var _counter_armed: bool = false
var guard_count: int = 0

func _ready() -> void:
	super._ready()
	player.shield_guard_multiplier = _guard_multiplier
	player.shield_guard_applied.connect(_on_guard_applied)

func _update_basic_attack(delta: float) -> void:
	var target := target_selector.current_target
	if not is_instance_valid(target) or target.global_position.distance_to(player.global_position) > 150 or (target.global_position.x-player.global_position.x) * player.facing_direction < 0:
		_update_combo_timeout(delta)
		return
	super._update_basic_attack(delta)

func _start_skill(action: int, definition: SkillDefinition, cooldown_remaining_s: float, slot: int = 1) -> void:
	var sequence := _action_sequence
	super._start_skill(action,definition,cooldown_remaining_s,slot)
	if sequence != _action_sequence: _counter_armed = false

func _is_guarding() -> bool:
	if not active or _action == Action.NONE or not player.can_continue_combat_action(): return false
	var definition := _current_skill()
	return definition != null and (definition.skill_id == &"shield_guard" or (definition.skill_id == &"shield_counter" and _action_elapsed_s < definition.hit_times_s[0]) or (definition.skill_id == &"shield_rush" and _action_elapsed_s < 0.32))

func _guard_multiplier(event: DamageEvent) -> float:
	if not _is_guarding() or event.damage <= 0 or not event.tags.has("enemy") or event.tags.has("hazard") or event.tags.has("trap"): return 1.0
	return 0.4 if (event.source_position.x-player.global_position.x) * _line_direction >= 0 else 1.0

func _on_guard_applied() -> void:
	guard_count += 1
	if _is_guarding() and _current_skill().skill_id == &"shield_counter": _counter_armed = true
	_emit_metrics()
	queue_redraw()

func _damage_target(target: PrototypeTarget, attack_id: StringName, damage: int, stagger_s: float, tags: PackedStringArray, hit_index: int) -> int:
	var counter := attack_id == &"shield_counter" and _counter_armed
	var result := super._damage_target(target,attack_id,60 if counter else damage,stagger_s,tags,hit_index)
	if result == DamageReceiver.Result.APPLIED and target is PrototypeEnemy and target.is_targetable():
		if counter: (target as PrototypeEnemy).apply_shield_stun(1.0)
		elif attack_id == &"shield_slam": (target as PrototypeEnemy).apply_shield_stun(1.2)
		elif attack_id == &"shield_ring" and hit_index == 1: (target as PrototypeEnemy).apply_shield_stun(0.8)
	return result

func _execute_skill_hit(definition: SkillDefinition, hit_index: int) -> void:
	super._execute_skill_hit(definition,hit_index)
	if definition.skill_id == &"shield_counter" and _counter_armed:
		last_combat_log = "응수 방어 성공 · 피해%d" % player.growth_damage(60,"shield","skill")

func _finish_action(reason: String) -> void:
	super._finish_action(reason)
	_counter_armed = false
	queue_redraw()

func reset_combat() -> void:
	guard_count = 0
	super.reset_combat()

func _build_metrics() -> Dictionary:
	var metrics := super._build_metrics()
	metrics["shield_guarding"] = _is_guarding()
	metrics["shield_counter_ready"] = _counter_armed
	metrics["shield_guard_count"] = guard_count
	return metrics

func _draw() -> void:
	if not active or player.damage_receiver.dead: return
	var direction := _line_direction if _action == Action.LINE_SLASH else player.facing_direction
	WeaponFamilyPresentation.draw_equipment(self, "shield", direction, _slash_remaining_s > 0 or _is_guarding(), _action_elapsed_s)
	var color := Color("ffd58a") if _counter_armed else Color("b6e3ff")
	if _is_guarding():
		var center := Vector2(62 * direction, -45)
		var angle := 0.0 if direction > 0 else PI
		draw_arc(center, 56, angle - PI * .6, angle + PI * .6, 32, Color(color, .18), 14, true)
		draw_arc(center, 56, angle - PI * .6, angle + PI * .6, 32, color, 3, true)
	WeaponFamilyPresentation.draw_impact(self, "shield", direction, 200 if _action == Action.SPIN_SLASH else 130, _action == Action.SPIN_SLASH, _slash_remaining_s)

func _update_slash_visual() -> void:
	slash_sprite.visible = false

func _show_slash(duration_s: float, _variant: int) -> void:
	_slash_remaining_s = duration_s
	queue_redraw()
