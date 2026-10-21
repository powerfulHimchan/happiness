class_name StaffCombatController
extends SwordCombatController

var _cast_direction := Vector2.RIGHT
var _lightning_anchor := Vector2.ZERO
var _lightning_flash: float = 0.0

func _physics_process(delta: float) -> void:
	_lightning_flash = maxf(0.0,_lightning_flash - delta)
	super._physics_process(delta)

func _update_basic_attack(_delta: float) -> void:
	var target := target_selector.current_target
	if not _valid_target(target) or _basic_remaining_s > 0: return
	_action_sequence += 1
	var aim := (target.global_position - player.global_position).normalized()
	_spawn_bolt(&"staff_basic",weapon.damage[0],aim,"magic",1,0)
	_basic_remaining_s = weapon.attack_interval_s[0]
	last_combat_log = "마법탄 발사 · 사거리7m · 피해22"

func _valid_target(target: PrototypeTarget) -> bool:
	return is_instance_valid(target) and target.is_targetable() and target.global_position.distance_to(player.global_position) <= weapon.attack_range_m * PrototypePlayer.PIXELS_PER_METER and (target.global_position.x - player.global_position.x) * player.facing_direction >= 0

func _start_skill(action: int, definition: SkillDefinition, cooldown_remaining_s: float, slot: int = 1) -> void:
	var sequence := _action_sequence
	super._start_skill(action,definition,cooldown_remaining_s,slot)
	if sequence == _action_sequence: return
	_cast_direction = (_captured_target.global_position - player.global_position).normalized() if _valid_target(_captured_target) else Vector2(player.facing_direction,0)
	_lightning_anchor = _captured_target.global_position if _valid_target(_captured_target) else player.global_position + Vector2(250 * player.facing_direction,0)

func _execute_skill_hit(definition: SkillDefinition, hit_index: int) -> void:
	match definition.skill_id:
		&"staff_fireball": _spawn_bolt(definition.skill_id,int(definition.damage[hit_index]),_cast_direction,"fire",1,120)
		&"staff_ice_lance": _spawn_bolt(definition.skill_id,int(definition.damage[hit_index]),_cast_direction,"ice",3,0)
		&"staff_lightning":
			for node in get_tree().get_nodes_in_group("targetable"):
				var target := node as PrototypeTarget
				if target != null and target.is_targetable() and target.global_position.distance_to(_lightning_anchor) <= 180:
					if _damage_target(target,definition.skill_id,int(definition.damage[hit_index]),0.1,PackedStringArray(["staff","skill","lightning"]),hit_index) == DamageReceiver.Result.APPLIED: skill_hit_count += 1
			_lightning_flash = 0.22
	last_combat_log = "%s 발동" % definition.display_name
	queue_redraw()

func _spawn_bolt(id: StringName, base_damage: int, direction: Vector2, element: String, hits: int, radius: float) -> void:
	var bolt := StaffMagicBolt.new()
	bolt.projectile_id = "player:%s:%d" % [id,_action_sequence]
	bolt.attack_id = id
	bolt.damage = player.growth_damage(base_damage,"staff","basic" if id == &"staff_basic" else "skill")
	bolt.direction = direction
	bolt.element = element
	bolt.max_hits = hits
	bolt.explosion_radius_px = radius
	bolt.damage_handler = player.deal_weapon_damage
	bolt.hit_registered.connect(_on_bolt_hit.bind(id == &"staff_basic"))
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = player.global_position + PrototypeTarget.BODY_CENTER
	projectile_fired_count += 1

func _on_bolt_hit(target: PrototypeTarget, damage: int, result: int, basic: bool) -> void:
	if result != DamageReceiver.Result.APPLIED: return
	if basic: basic_attack_count += 1
	else: skill_hit_count += 1
	total_damage += damage
	hit_registered.emit(not basic,target,damage)
	_emit_metrics()

func _clear_waves() -> void:
	super._clear_waves()
	for bolt in get_tree().get_nodes_in_group("staff_magic_bolt"): bolt.queue_free()
	_lightning_flash = 0.0

func _draw() -> void:
	if not active: return
	var center := Vector2(45 * player.facing_direction,-42)
	draw_line(center + Vector2(0,35),center - Vector2(0,35),Color("bfa0dc"),6,true)
	draw_circle(center - Vector2(0,35),11,Color("debcff"))
	if _action != Action.NONE and _current_skill().skill_id == &"staff_lightning" or _lightning_flash > 0:
		var anchor := to_local(_lightning_anchor) + PrototypeTarget.BODY_CENTER
		draw_arc(anchor,180,0,TAU,40,Color("e9d3ff",0.6),3,true)
		if _lightning_flash > 0: draw_line(anchor-Vector2(0,320),anchor,Color("fff0aa"),14,true)

func _update_slash_visual() -> void:
	slash_sprite.visible = false
