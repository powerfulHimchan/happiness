class_name StaffCombatController
extends SwordCombatController

var _cast_direction := Vector2.RIGHT
var _lightning_anchor := Vector2.ZERO
var _lightning_flash: float = 0.0
var _lightning_radius_px: float = 180.0

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
	_lightning_radius_px = 160.0 if definition.skill_id == &"staff_thunder_echo" else 180.0
	_cast_direction = (_captured_target.global_position - player.global_position).normalized() if _valid_target(_captured_target) else Vector2(player.facing_direction,0)
	_lightning_anchor = _captured_target.global_position if _valid_target(_captured_target) else player.global_position + Vector2(250 * player.facing_direction,0)

func _execute_skill_hit(definition: SkillDefinition, hit_index: int) -> void:
	match definition.skill_id:
		&"staff_fireball": _spawn_bolt(definition.skill_id,int(definition.damage[hit_index]),_cast_direction,"fire",1,120)
		&"staff_ice_lance": _spawn_bolt(definition.skill_id,int(definition.damage[hit_index]),_cast_direction,"ice",3,0)
		&"staff_ember_volley": _spawn_bolt(definition.skill_id, int(definition.damage[hit_index]), _cast_direction, "fire", 1, 0, hit_index)
		&"staff_frost_ring":
			for node in get_tree().get_nodes_in_group("targetable"):
				var target := node as PrototypeTarget
				if target != null and target.is_targetable() and target.global_position.distance_to(player.global_position) <= definition.hit_range_m * PrototypePlayer.PIXELS_PER_METER:
					if _damage_target(target, definition.skill_id, int(definition.damage[hit_index]), 0.1, PackedStringArray(["staff", "skill", "ice"]), hit_index) == DamageReceiver.Result.APPLIED: skill_hit_count += 1
			_show_slash(SKILL_FLASH_S, hit_index)
		&"staff_lightning", &"staff_thunder_echo":
			for node in get_tree().get_nodes_in_group("targetable"):
				var target := node as PrototypeTarget
				if target != null and target.is_targetable() and target.global_position.distance_to(_lightning_anchor) <= _lightning_radius_px:
					if _damage_target(target,definition.skill_id,int(definition.damage[hit_index]),0.1,PackedStringArray(["staff","skill","lightning"]),hit_index) == DamageReceiver.Result.APPLIED: skill_hit_count += 1
			_lightning_flash = 0.22
	last_combat_log = "%s 발동" % definition.display_name
	queue_redraw()

func _spawn_bolt(id: StringName, base_damage: int, direction: Vector2, element: String, hits: int, radius: float, hit_index: int = 0) -> void:
	var bolt := StaffMagicBolt.new()
	bolt.projectile_id = "player:%s:%d:%d" % [id, _action_sequence, hit_index]
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
	_show_slash(BASIC_FLASH_S if id == &"staff_basic" else SKILL_FLASH_S, 0)

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
	if not active or player.damage_receiver.dead: return
	WeaponFamilyPresentation.draw_equipment(self, "staff", player.facing_direction, _action != Action.NONE or _slash_remaining_s > 0, _action_elapsed_s)
	var definition := _current_skill()
	if definition != null and definition.skill_id == &"staff_frost_ring":
		WeaponFamilyPresentation.draw_impact(self, "shield", player.facing_direction, 240, true, _slash_remaining_s)
	if (definition != null and definition.skill_id in [&"staff_lightning", &"staff_thunder_echo"]) or _lightning_flash > 0:
		var anchor := to_local(_lightning_anchor) + PrototypeTarget.BODY_CENTER
		var radius := _lightning_radius_px
		draw_arc(anchor, radius, 0, TAU, 48, Color("d4b7ff", 0.5), 2, true)
		if _lightning_flash > 0:
			var bolt := PackedVector2Array([anchor + Vector2(12,-320), anchor + Vector2(-18,-220), anchor + Vector2(20,-230), anchor + Vector2(-12,-110), anchor + Vector2(14,-120), anchor])
			draw_polyline(bolt, Color("bda0ff", .25), 20, true)
			draw_polyline(bolt, Color("fff0bc"), 5, true)

func _show_slash(duration_s: float, _variant: int) -> void:
	_slash_remaining_s = duration_s
	queue_redraw()

func _update_slash_visual() -> void:
	slash_sprite.visible = false
