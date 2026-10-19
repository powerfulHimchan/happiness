extends SceneTree

const SANDBOX := preload("res://scenes/movement/ground_movement_sandbox.tscn")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := SANDBOX.instantiate()
	stage.get_node("RecoveryOrbController").drop_chance = 0.0
	root.add_child(stage)
	current_scene = stage
	await process_frame
	stage.get_node("StageRunner").set_stage_enabled(false)
	stage.get_node("CombatFeedbackController").configure(0.0, false, false)
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	var knight = stage.get_node("Targets/ClockworkKnight")
	var player = stage.get_node("Player")
	var image: Image = knight.body_sprite.texture.get_image()
	_check(image.get_size() == Vector2i(180, 148) and image.get_pixel(0, 0).a == 0.0, "texture size and transparency")
	var warning: Transform2D = knight.warning_line.transform
	var ring: Transform2D = knight.warning_ring.transform
	var selection: Transform2D = knight.selection_sprite.transform
	var health_bar: Rect2 = knight.health_bar.get_rect()
	for facing in [-1.0, 1.0]:
		knight.set_stage_spawn(Vector2(4400, 780))
		knight.visible = true
		knight.reset_target()
		player.position = knight.position + Vector2(facing * 300, 0)
		knight._charge_direction = facing
		for pose in ["idle", "charge-warning", "charge", "wave-warning", "wave", "volley-warning", "stun", "phase", "dead"]:
			knight.phase = 2 if pose == "phase" else 1
			knight.current_pattern = 2 if pose.begins_with("wave") else 3 if pose == "volley-warning" else 1
			var state: int = {"idle": 0, "charge-warning": 1, "charge": 2, "wave-warning": 1, "wave": 3, "volley-warning": 1, "stun": 4, "phase": 6, "dead": 7}[pose]
			knight._set_state(state, "art test")
			knight._state_elapsed_s = 0.5 if state == 1 else 0.02
			knight._update_presentation(0.0)
			knight._update_presentation(0.45)
			var body: Sprite2D = knight.body_sprite
			_check(body.flip_h == (facing < 0.0), "facing: " + pose)
			var left_sole := body.transform * Vector2(-47 * facing, 68)
			var right_sole := body.transform * Vector2(52 * facing, 68)
			_check(absf(maxf(left_sole.y, right_sole.y) - 60.0) < 0.01, "lower sole touches floor without sinking: " + pose)
			_check(knight.position == Vector2(4400, 780) and knight.damage_receiver.health == 480 and knight.attack_count == 0, "art cannot move or attack: " + pose)
			_check(warning == knight.warning_line.transform and ring == knight.warning_ring.transform and selection == knight.selection_sprite.transform and health_bar == knight.health_bar.get_rect(), "telegraph/selection/HUD geometry: " + pose)
		knight.reset_target()
		knight._process(0.45)
		_check(knight.state == 1 and knight.warning_count == 1, "actual first warning")
		knight._process(0.30)
		var frozen: Transform2D = knight.body_sprite.transform
		var elapsed: float = knight._visual_elapsed_s
		knight.set_enemy_time_scale(0.0)
		knight._process(0.2)
		_check(knight.body_sprite.transform == frozen and knight._visual_elapsed_s == elapsed, "zero time scale freezes art")
		knight.set_enemy_time_scale(0.5)
		knight._process(0.1)
		_check(is_equal_approx(knight._visual_elapsed_s - elapsed, 0.05), "half time scale")
		knight.set_enemy_time_scale(1.0)
		knight._process(0.31)
		_check(knight.state == 2 and knight.charge_count == 1, "actual charge after original warning duration")
		player.position.x = knight.position.x - facing * 300
		knight._process(0.01)
		_check(knight.body_sprite.flip_h == (facing < 0), "charge direction stays locked when player crosses")
		# The real volley and recoil start together, even after a long frame.
		knight.reset_target()
		player.position = knight.position + Vector2(facing * 300, 0)
		knight.last_pattern = EliteArmoredBoar.Pattern.SHOCKWAVE
		knight._begin_next_pattern()
		knight._process(0.99)
		_check(knight.state == 1 and knight._volley_elapsed_s == -1.0 and get_nodes_in_group("enemy_projectile").is_empty(), "no shot/recoil during volley warning")
		player.position.x = knight.position.x - facing * 300
		knight._process(0.4)
		_check(knight.state == 5 and knight.volley_count == 1 and get_nodes_in_group("enemy_projectile").size() == 3, "actual volley count and recovery")
		_check(knight._volley_elapsed_s == 0.0 and knight.body_sprite.rotation * facing < 0.0 and knight.body_sprite.flip_h == (facing < 0), "event-driven recoil and locked volley facing")
		frozen = knight.body_sprite.transform
		knight.set_enemy_time_scale(0.0)
		knight._process(0.2)
		_check(knight.body_sprite.transform == frozen and knight._volley_elapsed_s == 0.0, "frozen recoil")
		knight.set_enemy_time_scale(1.0)
		knight.process_mode = Node.PROCESS_MODE_PAUSABLE
		knight.set_process(true)
		paused = true
		elapsed = knight._visual_elapsed_s
		await process_frame
		await process_frame
		_check(knight._visual_elapsed_s == elapsed and knight._volley_elapsed_s == 0.0, "scene pause freezes body and flash")
		paused = false
		knight.process_mode = Node.PROCESS_MODE_INHERIT
		knight._process(0.27)
		_check(is_zero_approx(knight.body_sprite.rotation), "recoil settles")
		for projectile in get_nodes_in_group("enemy_projectile"):
			projectile.free()
		var hit := DamageEvent.new()
		hit.event_id = StringName("knight-art:hit:%s" % facing)
		hit.damage = 1
		knight.receive_damage(hit)
		_check(knight.damage_receiver.health == 479 and knight.body_sprite.self_modulate.r > 1.0, "actual hit flash")
		hit = DamageEvent.new()
		hit.event_id = StringName("knight-art:dead:%s" % facing)
		hit.damage = 10000
		knight.receive_damage(hit)
		_check(knight.state == 7 and not knight.is_targetable() and not knight.warning_line.visible, "immediate defeat before visual collapse")
		knight._process(0.45)
		_check(knight.body_sprite.self_modulate.a <= 0.26, "defeat fade")
		knight.reset_target()
		_check(knight.body_sprite.self_modulate == Color.WHITE and knight.body_sprite.modulate == Color.WHITE and knight.body_sprite.scale == Vector2(1.2, 1.2) and knight._volley_elapsed_s == -1.0, "respawn clears all visual state")
	for pair in [["HappinessGuardian", "happiness_guardian_presentation"], ["Sera", "sera_presentation"], ["HappinessHeart", "happiness_heart_presentation"], ["ArmoredBoar", "armored_boar_presentation"]]:
		_check(stage.get_node("Targets/" + pair[0]).get_script().resource_path == "res://scripts/combat/%s.gd" % pair[1], "other actor script: " + pair[0])
	print("Clockwork knight art runtime: %s (both directions, poses, actual charge/volley, slow/pause, hit/death/reset)" % ("OK" if failures == 0 else "FAILED"))
	stage.free()
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("Clockwork knight art: " + label)
