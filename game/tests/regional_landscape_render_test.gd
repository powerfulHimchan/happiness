extends SceneTree

## Manual graphics QA: run with a real renderer and LANDSCAPE_RENDER_DIR.
const SANDBOX := preload("res://scenes/movement/ground_movement_sandbox.tscn")
const CONTROLS := preload("res://scripts/movement/ground_movement_controls.gd")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var output := OS.get_environment("LANDSCAPE_RENDER_DIR")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		printerr("A real display and LANDSCAPE_RENDER_DIR are required")
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
	var controls: Control = scene.get_node("CanvasLayer/GroundMovementControls")
	controls.show_main_screen()
	controls.visible = false
	var player: PrototypePlayer = scene.get_node("Player")
	var camera: Camera2D = player.get_node("Camera2D")
	var count := 0
	var hud_count := 0
	for screen in [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1280, 800)]:
		root.size = screen
		root.content_scale_size = Vector2i(1920, 1080)
		for route in ["wind", "forest", "ruins", "clockwork", "festival", "city_gate"]:
			for section in ([1] if route in ["clockwork", "city_gate"] else [1, 2]):
				runner.run_mode = "journey"
				runner.stage_limit = 10
				runner.route_id = route
				runner.stage_number = 9 if route == "city_gate" else 2 if route == "clockwork" else section
				runner.stage_enabled = true
				runner.reset_stage()
				runner._activate_wave_one()
				for view in ["battle", "platforms"]:
					if route == "festival" and view == "platforms":
						runner.route_terrain._physics_process(1.25)
					player.position = Vector2(1620 if view == "battle" else 3500, 780)
					camera.position = Vector2.ZERO
					camera.reset_smoothing()
					camera.force_update_scroll()
					# Present an actual warning with combat actors at their real stage spawns.
					for enemy in runner._active_enemies:
						enemy.reset_target()
						enemy._process(0.0)
					var before: Dictionary = runner.checkpoint_snapshot().duplicate(true)
					var geometry: Dictionary = runner.route_terrain.layout_snapshot().duplicate(true)
					# Force cached canvas drawing and verify it changes no gameplay state.
					scene.queue_redraw()
					runner.route_terrain.queue_redraw()
					await process_frame
					await RenderingServer.frame_post_draw
					if before != runner.checkpoint_snapshot() or geometry != runner.route_terrain.layout_snapshot():
						printerr("Landscape redraw changed gameplay state: " + route)
						quit(1)
						return
					var path := "%s/%s_%d_%s_%dx%d.png" % [output, route, section, view, screen.x, screen.y]
					if root.get_texture().get_image().save_png(path) != OK:
						printerr("Screenshot failed: " + path)
						quit(1)
						return
					count += 1
					if screen == Vector2i(1280, 720) and section == (1 if route in ["clockwork", "city_gate"] else 2) and view == "battle":
						controls.set("screen_mode", CONTROLS.ScreenMode.COMBAT)
						controls.visible = true
						runner.force_emit_metrics()
						controls.queue_redraw()
						await process_frame
						await RenderingServer.frame_post_draw
						if root.get_texture().get_image().save_png("%s/%s_combat_hud.png" % [output, route]) != OK:
							quit(1)
							return
						controls.visible = false
						hud_count += 1
	# Revisit a new region, then return to diagnostic mode in the same scene.
	runner.set_stage_enabled(false)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/diagnostic_reset.png")
	scene.free()
	print("Regional landscape render: %d regional screens + %d combat HUD screens + diagnostic reset" % [count, hud_count])
	quit(0)
