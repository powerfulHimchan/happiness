extends SceneTree

const SANDBOX := preload("res://scenes/movement/ground_movement_sandbox.tscn")
var failures := 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var stage := SANDBOX.instantiate()
	stage.get_node("RecoveryOrbController").drop_chance = 0.0
	root.add_child(stage)
	current_scene = stage
	await process_frame
	stage.get_node("StageRunner").set_stage_enabled(false)
	stage.get_node("CombatFeedbackController").configure(0.0, false, false)
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	var guard = stage.get_node("Targets/HappinessGuardian")
	var player: PrototypePlayer = stage.get_node("Player")
	for pair in [[guard.body_sprite.texture, Vector2i(180, 152)], [guard.shield_sprite.texture, Vector2i(70, 88)], [BossHappinessGuardian.LANCE_TEXTURE, Vector2i(92, 24)]]:
		var image: Image = pair[0].get_image()
		_check(image.get_size() == pair[1] and image.get_pixel(0, 0).a == 0.0, "art extent and transparency")
	var warning: Transform2D = guard.warning_line.transform
	var ring: Transform2D = guard.warning_ring.transform
	var selection: Transform2D = guard.selection_sprite.transform
	var marker: Transform2D = guard.armor_marker.transform
	var health_bar: Rect2 = guard.health_bar.get_rect()
	for facing in [-1.0, 1.0]:
		guard.set_stage_spawn(Vector2(4450, 780))
		guard.visible = true
		guard.reset_target()
		player.position = guard.position + Vector2(facing * 300, 0)
		guard._charge_direction = facing
		for pose in ["idle", "charge-warning", "charge", "wave-warning", "wave", "lance-warning", "stun", "recovery", "phase", "dead"]:
			guard.phase = 2 if pose == "phase" else 1
			guard.current_pattern = 2 if pose.begins_with("wave") else 3 if pose == "lance-warning" else 1
			var state: int = {"idle":0,"charge-warning":1,"charge":2,"wave-warning":1,"wave":3,"lance-warning":1,"stun":4,"recovery":5,"phase":6,"dead":7}[pose]
			guard._set_state(state, "art test")
			guard._state_elapsed_s = 0.5 if state == 1 else 0.03
			var metrics: Dictionary = guard.current_metrics()
			guard._update_presentation(0.2)
			var body: Sprite2D = guard.body_sprite
			_check(body.flip_h == (facing > 0) and guard.shield_sprite.flip_h == body.flip_h, "body/shield facing: " + pose)
			var mirror: float = -facing
			var lower_sole := maxf((body.transform * Vector2(-36 * mirror, 69)).y, (body.transform * Vector2(47 * mirror, 69)).y)
			_check(is_equal_approx(lower_sole, 60.0), "grounded lower sole: " + pose)
			_check(guard.position == Vector2(4450,780) and guard.current_metrics() == metrics, "art cannot alter combat: " + pose)
			_check(guard.warning_line.transform == warning and guard.warning_ring.transform == ring and guard.selection_sprite.transform == selection and guard.armor_marker.transform == marker and guard.health_bar.get_rect() == health_bar, "telegraph/selection/HUD geometry: " + pose)
			if guard._shield_raised(): _check(guard._shield_drop == 0.0, "raised shield pose")
			elif state in [4,5,7]: _check(guard._shield_drop == 1.0, "lowered shield exposes recovery")
		guard.reset_target()
		guard._begin_next_pattern()
		_check(guard.state == 1 and guard.body_sprite.flip_h == (facing > 0), "immediate actual warning direction")
		guard._process(0.89)
		_check(guard.state == 1 and guard._shield_drop == 0.0, "full 0.9s warning before charge")
		guard._process(0.02)
		player.position.x = guard.position.x - facing * 300
		guard._process(0.01)
		_check(guard.state == 2 and guard.charge_count == 1 and guard.body_sprite.flip_h == (facing > 0), "charge remains locked after player crosses")
		for phase in [1,2]:
			guard.reset_target()
			player.position = guard.position + Vector2(facing * 300,0)
			if phase == 2:
				var transition := DamageEvent.new()
				transition.event_id = StringName("guardian-art:phase:%s" % facing)
				transition.damage = 360
				guard.receive_damage(transition)
				_check(guard.phase == 2 and guard.state == 6, "actual half-health transition")
				guard._process(0.75)
			guard.last_pattern = EliteArmoredBoar.Pattern.SHOCKWAVE
			guard._begin_next_pattern()
			guard._process((0.80 if phase == 2 else 1.10) - 0.01)
			_check(guard.lance_count == 0 and guard._lance_elapsed_s == -1.0, "no early lance or recoil")
			player.position.x = guard.position.x - facing * 300
			guard._process(0.4)
			_check(guard.state == 5 and guard.lance_count == 1 and get_nodes_in_group("enemy_projectile").size() == (3 if phase == 2 else 1), "real phase-specific lance count")
			_check(guard._lance_elapsed_s == 0.0 and guard.body_sprite.rotation * facing < 0.0 and guard.body_sprite.flip_h == (facing > 0), "actual shot drives long-frame recoil and facing")
			var frozen_body: Transform2D = guard.body_sprite.transform
			var frozen_shield: Transform2D = guard.shield_sprite.transform
			guard.set_enemy_time_scale(0.0)
			guard._process(0.2)
			_check(guard.body_sprite.transform == frozen_body and guard.shield_sprite.transform == frozen_shield and guard._lance_elapsed_s == 0.0, "zero slow freezes body/shield/flash")
			guard.set_enemy_time_scale(0.5)
			guard._process(0.1)
			_check(is_equal_approx(guard._lance_elapsed_s, 0.05), "half slow scales recoil")
			guard.set_enemy_time_scale(1.0)
			guard.process_mode = Node.PROCESS_MODE_PAUSABLE
			paused = true
			var elapsed: float = guard._visual_elapsed_s
			await process_frame
			await process_frame
			_check(guard._visual_elapsed_s == elapsed and guard._lance_elapsed_s == 0.05, "scene pause freezes effects")
			paused = false
			guard.process_mode = Node.PROCESS_MODE_INHERIT
			for shot in get_nodes_in_group("enemy_projectile"): shot.free()
		guard.reset_target()
		var hit := DamageEvent.new()
		hit.event_id = StringName("guardian-art:hit:%s" % facing)
		hit.damage = 1
		guard.receive_damage(hit)
		_check(guard.damage_receiver.health == 719 and guard.body_sprite.self_modulate.r > 1 and guard.shield_sprite.self_modulate == guard.body_sprite.self_modulate, "actual hit flashes body and shield")
		hit = DamageEvent.new()
		hit.event_id = StringName("guardian-art:dead:%s" % facing)
		hit.damage = 99999
		guard.receive_damage(hit)
		_check(guard.state == 7 and not guard.is_targetable() and not guard.warning_line.visible, "immediate defeat semantics")
		guard._process(0.45)
		_check(guard.body_sprite.self_modulate.a <= 0.26 and guard.shield_sprite.self_modulate.a <= 0.26, "body and shield fade together")
		guard.reset_target()
		_check(guard.body_sprite.self_modulate == Color.WHITE and guard.shield_sprite.self_modulate == Color.WHITE and guard.shield_sprite.modulate == Color.WHITE and guard._lance_elapsed_s == -1 and guard._shield_drop == 0.55, "respawn clears all visual state")
	for pair in [["ClockworkKnight","clockwork_knight_presentation"],["ArmoredBoar","armored_boar_presentation"],["Sera","sera_presentation"],["HappinessHeart","happiness_heart_presentation"]]:
		_check(stage.get_node("Targets/"+pair[0]).get_script().resource_path == "res://scripts/combat/%s.gd" % pair[1], "other actor unchanged: "+pair[0])
	stage.free()
	print("Guardian art runtime: %s (both directions, shield poses, floor, actual charge/lance, slow/pause, hit/death/reset)" % ("OK" if failures == 0 else "FAILED"))
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("Guardian art: " + label)
