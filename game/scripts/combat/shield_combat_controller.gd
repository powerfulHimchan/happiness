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
	return definition != null and (definition.skill_id == &"shield_guard" or (definition.skill_id == &"shield_counter" and _action_elapsed_s < definition.hit_times_s[0]))

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
	if not active: return
	var direction := _line_direction if _action != Action.NONE else player.facing_direction
	var center := Vector2(45 * direction,-40)
	var color := Color("ffd58a") if _counter_armed else Color("b6e3ff")
	var angle := 0.0 if direction > 0 else PI
	if _is_guarding():
		draw_circle(center,48,Color(color,.16))
		draw_arc(center,50,angle-PI*.6,angle+PI*.6,24,color,3,true)
	var points := PackedVector2Array([center+Vector2(-19,-28),center+Vector2(19,-28),center+Vector2(23,7),center+Vector2(0,30),center+Vector2(-23,7)])
	draw_colored_polygon(points,Color("365d78"))
	points.append(points[0])
	draw_polyline(points,color,3,true)
	draw_line(center+Vector2(0,-18),center+Vector2(0,17),color,3,true)
	draw_line(center+Vector2(-12,-3),center+Vector2(12,-3),color,3,true)
	if _slash_remaining_s > 0: draw_arc(center,65,angle-PI*.5,angle+PI*.5,24,Color("ffe8be"),8,true)

func _update_slash_visual() -> void:
	slash_sprite.visible = false

func _show_slash(duration_s: float, _variant: int) -> void:
	_slash_remaining_s = duration_s
	queue_redraw()
