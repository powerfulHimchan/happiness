extends SceneTree

const SANDBOX := preload("res://scenes/movement/ground_movement_sandbox.tscn")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var output := OS.get_environment("ROSTER_RENDER_DIR")
	if output.is_empty():
		printerr("Set ROSTER_RENDER_DIR to an absolute screenshot directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var scene := SANDBOX.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var runner: PrototypeStageRunner = scene.get_node("StageRunner")
	runner.set_stage_enabled(false)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var controls = scene.get_node("CanvasLayer/GroundMovementControls")
	controls.show_main_screen()
	controls.visible = false
	var player: PrototypePlayer = scene.get_node("Player")
	var camera: Camera2D = player.get_node("Camera2D")
	var count := 0
	for screen in [Vector2i(1280, 720), Vector2i(1280, 800)]:
		root.size = screen
		root.content_scale_size = Vector2i(1920, 1080)
		for route in RegionalEnemyRoster.REGULAR:
			for facing in [-1, 1]:
				runner.run_mode = "journey"
				runner.stage_limit = 10
				runner.route_id = route
				runner.stage_number = 9 if route == "city_gate" else 10 if route == "city_core" else 1
				runner.stage_enabled = true
				runner.reset_stage()
				runner._activate_wave_two()
				player.position = Vector2(1000 if facing < 0 else 2600, 780)
				camera.position.x = 800 if facing < 0 else -800
				camera.reset_smoothing()
				camera.force_update_scroll()
				var index := 0
				for enemy in runner._active_enemies:
					enemy.set_stage_spawn(Vector2(1320 + index * 300, 650 if enemy.regional_pattern != null and enemy.regional_pattern.airborne() else 780))
					enemy.reset_target()
					enemy._process(0.0)
					if enemy.regional_pattern != null:
						enemy._process(enemy.regional_pattern.warning_duration() * 0.4)
					else: enemy._process(0.15)
					index += 1
				if route in ["wind", "forest", "ruins", "festival"]:
					var elite := runner.armored_boar
					elite.set_stage_spawn(Vector2(2290, 780))
					elite.reset_target()
					elite.visible = true
					elite._process(0.5)
					elite._process(0.2)
				await process_frame
				await RenderingServer.frame_post_draw
				var path := "%s/%s_%dx%d_%d.png" % [output, route, screen.x, screen.y, facing]
				var error := root.get_texture().get_image().save_png(path)
				if error != OK:
					printerr("Screenshot failed: " + path)
					quit(1)
					return
				count += 1
	scene.free()
	print("Regional roster render: %d screens" % count)
	quit(0)
