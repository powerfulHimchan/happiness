extends SceneTree

const SANDBOX := preload("res://tests/fixtures/legacy_movement_sandbox.tscn")
var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage := SANDBOX.instantiate()
	root.add_child(stage)
	current_scene = stage
	await process_frame
	stage.get_node("CanvasLayer/GroundMovementControls").begin_retry("sword", 3, "standard", "roan")
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	var player: PrototypePlayer = stage.get_node("Player")
	for actor_name in ["LeafSlime", "SeedSack", "WindSpirit"]:
		var enemy: PrototypeEnemy = stage.get_node("Targets/" + actor_name)
		var sprite := enemy.body_sprite
		var original_texture := enemy._original_body_texture
		var image := original_texture.get_image()
		_check(image != null and image.get_pixel(0, 0).a == 0.0, "transparent SVG: " + actor_name)
		var opaque := 0
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a > 0.5: opaque += 1
		_check(opaque > 2500, "substantial readable silhouette: " + actor_name)
		var rest_scale := Vector2.ONE * float(EnemyVisualAnimation.BODY_SCALE[enemy.enemy_type])
		for direction in [-1, 1]:
			enemy.configure_route("grass")
			enemy.set_stage_spawn(Vector2(1100, 780 if enemy.enemy_type != 2 else 615))
			enemy.reset_target()
			enemy.visible = true
			player.global_position = Vector2(1100 + direction * (500 if enemy.enemy_type == 1 else 200), 780)
			var health := enemy.damage_receiver.health
			var origin := enemy.position
			var warning_transform := enemy.warning_line.transform
			var selection_transform := enemy.selection_sprite.transform
			var baseline := sprite.transform
			enemy._patrol_direction = direction
			enemy._update_body_animation(0.11)
			_check(sprite.transform != baseline and sprite.flip_h == (direction < 0), "idle motion and facing")
			_check(enemy.position == origin and enemy.damage_receiver.health == health and enemy.attack_count == 0, "render cannot move or attack")
			_check(enemy.warning_line.transform == warning_transform and enemy.selection_sprite.transform == selection_transform, "warning and selection unaffected")
			# The real controller enters its warning state, with the original timer.
			enemy._process(0.0)
			_check(enemy.state == PrototypeEnemy.State.WARNING and enemy.warning_line.visible, "real warning begins")
			var duration := [PrototypeEnemy.SLIME_WARNING_S, PrototypeEnemy.SEED_WARNING_S, PrototypeEnemy.WIND_WARNING_S][enemy.enemy_type] as float
			enemy._process(duration * 0.5)
			_check(enemy.attack_count == 0 and sprite.scale != rest_scale and sprite.flip_h == (direction < 0), "anticipation before actual attack")
			if enemy.enemy_type != 2:
				var pivot := sprite.transform * Vector2(0, EnemyVisualAnimation.FOOT_Y[enemy.enemy_type])
				_check(absf(pivot.y - 60.0) < 0.01, "ground anticipation keeps foot on player floor")
			# Time slow scales visual clocks exactly like the actor, including zero.
			enemy.set_enemy_time_scale(0.0)
			var paused_pose := sprite.transform
			var paused_time := enemy.visual_animation.elapsed_s
			enemy._process(0.1)
			_check(sprite.transform == paused_pose and enemy.visual_animation.elapsed_s == paused_time and enemy.attack_count == 0, "zero time scale freezes pose and attack")
			enemy.set_enemy_time_scale(0.5)
			enemy._process(0.04)
			_check(is_equal_approx(enemy.visual_animation.elapsed_s - paused_time, 0.02), "slow time controls animation")
			enemy.set_enemy_time_scale(1.0)
			enemy._process(duration * 0.5 - 0.019)
			_check(enemy.attack_count == 1, "one attack on original timing")
			if enemy.enemy_type == 1:
				_check(enemy.state == PrototypeEnemy.State.RECOVERY and enemy._projectile_sequence == 3 and enemy.visual_animation.shot_remaining_s > 0.0, "actual three-shot volley drives recoil")
			else:
				_check(enemy.state == PrototypeEnemy.State.ATTACK, "actual jump/dash pose")
			# Nonlethal and lethal real hits retain damage/targetability semantics.
			var hit := DamageEvent.new()
			hit.event_id = StringName(actor_name + str(direction))
			hit.damage = 1
			hit.source_position = player.global_position
			enemy.receive_damage(hit)
			_check(enemy.damage_receiver.health == health - 1 and sprite.self_modulate.r > 1.0, "real hit flash and unchanged damage")
			hit = DamageEvent.new()
			hit.event_id = StringName(actor_name + str(direction) + "dead")
			hit.damage = 10000
			enemy.receive_damage(hit)
			_check(enemy.state == PrototypeEnemy.State.DEAD and not enemy.is_targetable() and not enemy.warning_line.visible, "death immediately disables target and warning")
			enemy._process(0.4)
			_check(sprite.scale.y < rest_scale.y * 0.5 and sprite.self_modulate.a < 0.4, "death settles and fades without delaying defeat")
			enemy.reset_target()
			_check(sprite.scale == rest_scale and sprite.self_modulate == Color.WHITE and enemy.is_targetable() and enemy.visual_animation.shot_remaining_s == 0.0, "pooled respawn clears death and recoil")
			# Whole scene pause prevents body updates, not just enemy-time slow.
			enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
			paused = true
			paused_time = enemy.visual_animation.elapsed_s
			await process_frame
			await process_frame
			_check(enemy.visual_animation.elapsed_s == paused_time, "scene pause freezes animation")
			paused = false
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
		# Existing replacement actors keep their exact textures and transforms.
		for route in ["ruins", "festival", "forest", "grass"]:
			enemy.reset_target()
			enemy.configure_route(route)
			enemy._update_body_animation(0.12)
			var replacement: bool = (route == "ruins" and enemy.enemy_type == 1) or (route == "festival" and enemy.enemy_type != 2)
			if replacement:
				var expected: Texture2D = PrototypeEnemy.CLOCK_DOLL_TEXTURE if route == "ruins" else PrototypeEnemy.FESTIVAL_SOLDIER_TEXTURE if enemy.enemy_type == 0 else PrototypeEnemy.FESTIVAL_TURRET_TEXTURE
				_check(sprite.texture == expected and sprite.scale == Vector2.ONE and sprite.rotation == 0.0 and sprite.self_modulate == Color.WHITE, "route replacement art preserved")
			else:
				_check(sprite.texture == original_texture, "standard/forest art restored")
	stage.queue_free()
	await process_frame
	if failed: quit(1)
	else:
		print("Enemy art runtime: OK (3 silhouettes, actual attacks, facing, hit/death/reset, time scale, pause, route variants)")
		quit(0)

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
