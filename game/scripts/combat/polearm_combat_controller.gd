class_name PolearmCombatController
extends SwordCombatController

func _update_basic_attack(delta: float) -> void:
	var target := target_selector.current_target
	if not is_instance_valid(target) or not target.is_targetable() or not _in_basic_range(target):
		_update_combo_timeout(delta)
		return
	_combo_idle_s = 0.0
	if _basic_remaining_s > 0: return
	_action_sequence += 1
	var hit_index := combo_index
	for node in get_tree().get_nodes_in_group("targetable"):
		var victim := node as PrototypeTarget
		if victim == null or not victim.is_targetable() or not _in_basic_range(victim): continue
		if _damage_target(victim,&"polearm_basic",weapon.damage[hit_index],0.12,PackedStringArray(["polearm","basic"]),hit_index) == DamageReceiver.Result.APPLIED: basic_attack_count += 1
	_basic_remaining_s = weapon.attack_interval_s[hit_index]
	combo_index = (combo_index+1) % weapon.damage.size()
	_show_slash(BASIC_FLASH_S,hit_index)
	last_combat_log = "장봉 %d타 · 정면2.8m" % (hit_index+1)

func _in_basic_range(target: PrototypeTarget) -> bool:
	var offset := target.global_position - player.global_position
	return offset.x * player.facing_direction >= 0 and offset.x * player.facing_direction <= 280 and absf(offset.y) <= 80

func _damage_target(target: PrototypeTarget, attack_id: StringName, damage: int, stagger_s: float, tags: PackedStringArray, hit_index: int) -> int:
	var result := super._damage_target(target,attack_id,damage,stagger_s,tags,hit_index)
	if result == DamageReceiver.Result.APPLIED and target is PrototypeEnemy and target.is_targetable():
		var distance := 0.0
		match attack_id:
			&"polearm_basic": distance = 30.0 if hit_index == 1 else 0.0
			&"polearm_sweep": distance = 60.0
			&"polearm_thrust": distance = 100.0
			&"polearm_cycle": distance = 80.0 if hit_index == 2 else 0.0
		if distance > 0:
			var direction := signf(target.global_position.x - player.global_position.x)
			(target as PrototypeEnemy).apply_pole_push((float(player.facing_direction) if is_zero_approx(direction) else direction) * distance)
	return result

func _draw() -> void:
	if not active or _slash_remaining_s <= 0: return
	var center := Vector2(0,-38)
	var direction := _line_direction if _action == Action.LINE_SLASH else player.facing_direction
	if _action == Action.LINE_SLASH:
		draw_line(center,center+Vector2(400 * direction,0),Color("d7f6bb"),9,true)
	else:
		var full := _action == Action.SPIN_SLASH
		var radius := _current_skill().hit_range_m * 100 if full else 280.0
		var angle := 0.0 if direction > 0 else PI
		draw_arc(center,radius,0.0 if full else angle-PI*.4,TAU if full else angle+PI*.4,48,Color("ade3bb",.6),7,true)
		draw_line(center,center+Vector2(radius*direction,-25),Color("f4e5b5"),6,true)

func _update_slash_visual() -> void:
	slash_sprite.visible = false

func _show_slash(duration_s: float, _variant: int) -> void:
	_slash_remaining_s = duration_s
	queue_redraw()
