class_name RegionalEnemyPattern
extends RefCounted

## Uses the actor's combat clock, damage receiver and life key. No independent
## timers survive stun, death, route changes, checkpoint reset or time stop.
var id: String
var aim := Vector2.LEFT
var origin := Vector2.ZERO
var returned: bool = false

func _init(species: String) -> void:
	id = species

func airborne() -> bool:
	return id in ["bird", "moth", "clown", "rewind_doll"]

func ranged() -> bool:
	return id in ["bird", "moth", "clown", "parade_doll"]

func reset() -> void:
	aim = Vector2.LEFT
	origin = Vector2.ZERO
	returned = false

func warning_duration() -> float:
	return 1.0 if ranged() else 0.75 if id == "rewind_doll" else 0.65

func distance() -> float:
	return 620.0 if ranged() else 300.0 if id == "rabbit" else 400.0 if id == "rewind_doll" else 220.0

func tick(e, delta: float) -> void:
	match e.state:
		0:
			if airborne(): e.position.y = e._spawn_position.y + sin(e._state_elapsed_s * 3.0) * 12.0
			if e._attack_cooldown_s <= 0.0 and e._distance_to_player_m() <= (9.0 if ranged() else 6.0):
				origin = e.position
				returned = false
				aim = (e.player.global_position + Vector2(0, -38) - (e.global_position + Vector2(0, -38))).normalized()
				if not ranged(): aim = Vector2(-1 if aim.x < 0 else 1, 0)
				e._attack_direction = aim
				e._combo_remaining = 1 if e.expedition_patterns else 0
				e._begin_warning("%s · %.2f초 경고" % [e.enemy_name(), warning_duration()])
		1:
			e.warning_line.points = PackedVector2Array([Vector2(0, -38), Vector2(0, -38) + aim * distance()])
			if e._state_elapsed_s >= warning_duration():
				if ranged():
					fire(e)
					e._begin_recovery("%s 사격 후 빈틈" % e.enemy_name())
				else: e._begin_attack("%s · %s" % [e.enemy_name(), "되감기 돌진" if id == "rewind_doll" else "뿔 돌진" if id == "rabbit" else "창 찌르기"])
		2:
			var step: float = minf((620.0 if id == "rabbit" else 500.0) * delta, distance() - e._attack_distance_px)
			e.position.x = clampf(e.position.x + aim.x * step, e.movement_bounds.x, e.movement_bounds.y)
			e._attack_distance_px += step
			if id == "rabbit": e.position.y = origin.y - sin(minf(e._attack_distance_px / distance(), 1.0) * PI) * 85.0
			e._try_contact_damage(11 if id == "mask_guard" else 9, StringName(id + "_strike"))
			if e._attack_distance_px >= distance() or e.position.x in [e.movement_bounds.x, e.movement_bounds.y]:
				e.position.y = origin.y
				e._begin_recovery("%s · 반격 기회" % e.enemy_name())
		3:
			if id == "rewind_doll" and not returned and e._state_elapsed_s >= 0.55:
				e.position = origin
				returned = true
				e.last_enemy_log = "되감기 인형 · 기록한 위치로 복귀"
			if e._combo_remaining > 0 and e._state_elapsed_s >= 0.6:
				e._combo_remaining -= 1
				origin = e.position
				returned = false
				aim = (e.player.global_position + Vector2(0, -38) - (e.global_position + Vector2(0, -38))).normalized()
				if not ranged(): aim = Vector2(-1 if aim.x < 0 else 1, 0)
				e._attack_direction = aim
				e._begin_warning("%s · 원정 연속 공격 %.2f초 경고" % [e.enemy_name(), warning_duration()])
			elif e._state_elapsed_s >= 1.2:
				e._attack_cooldown_s = 0.45
				e._set_state(0, "%s 행동 재개" % e.enemy_name())
	if e.state == 1:
		e.warning_line.visible = true
		e.warning_ring.visible = not airborne()

func fire(e) -> void:
	e.attack_count += 1
	e.visual_animation.shot()
	var angles: Array = [-18.0, 0.0, 18.0] if id in ["moth", "clown", "parade_doll"] else [0.0]
	for angle in angles:
		e._projectile_sequence += 1
		var p = e.SEED_PROJECTILE_SCENE.instantiate()
		p.configure("%s:%s:%d:%d" % [e.attack_life_key(), id, e.attack_count, e._projectile_sequence], aim.rotated(deg_to_rad(angle)), 8, 4.2 if id == "clown" else 5.5)
		p.attacker_id = StringName(id)
		p.attack_id = StringName(id + "_volley")
		p.damage_tags = PackedStringArray(["enemy", "projectile", id])
		p.projectile_texture = load("res://assets/enemies/%s_projectile.svg" % ("spore" if id == "moth" else "balloon" if id == "clown" else "flag" if id == "parade_doll" else "dandelion"))
		p.set_enemy_time_scale(e.enemy_time_scale())
		var parent = e.get_tree().current_scene
		if parent == null: parent = e.get_tree().root
		parent.add_child(p)
		p.global_position = e.global_position + Vector2(0, -38)
