extends SceneTree

const SCENE := preload("res://scenes/movement/ground_movement_sandbox.tscn")
var scene: Node2D
var runner: PrototypeStageRunner
var player: PrototypePlayer
var map: WindmillMeadow
var controls: Control
var checks := 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "flow"
	scene = SCENE.instantiate()
	scene.checkpoint_store.save_path = "user://windmill_%s_checkpoint.json" % phase
	scene.boss_legacy_store.save_path = "user://windmill_%s_legacy.jsonl" % phase
	scene.story_journal_store.save_path = "user://windmill_%s_story.jsonl" % phase
	scene.ability_discovery_store.save_path = "user://windmill_%s_abilities.jsonl" % phase
	scene.achievement_store.save_path = "user://windmill_%s_achievements.jsonl" % phase
	scene.get_node("LocalTestRecorder").record_path = "user://windmill_%s_records.jsonl" % phase
	for path in [scene.checkpoint_store.save_path,scene.boss_legacy_store.save_path,scene.story_journal_store.save_path,scene.ability_discovery_store.save_path,scene.achievement_store.save_path,scene.get_node("LocalTestRecorder").record_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	scene.get_node("RecoveryOrbController").drop_chance = 0.0
	root.add_child(scene)
	current_scene = scene
	await process_frame
	controls = scene.get_node("CanvasLayer/GroundMovementControls")
	runner = scene.get_node("StageRunner")
	player = scene.get_node("Player")
	if phase == "story":
		controls.begin_retry("bow",10,JourneyRoutePlan.MODE,"lumi",true)
		runner.region_order.assign(["wind","forest","ruins","festival"])
		runner.route_id = "wind"
		runner.reset_stage()
		scene._acknowledge_story("prologue")
	else:
		controls.begin_retry("sword",3)
	runner.set_process(false)
	map = runner.meadow
	scene.get_node("CombatFeedbackController").configure(0.0,false,false)
	for path in ["Player/PrototypeWeaponController","Player/SwordCombatController","Player/BowCombatController","Player/FistCombatController","Player/StaffCombatController","Player/PolearmCombatController","Player/ShieldCombatController"]:
		scene.get_node(path).set_process(false)
	if phase == "physics":
		if not await _physics_checks(): return
	elif phase == "journey":
		if not _journey_checks(): return
	elif phase == "render":
		if not await _render_checks(): return
	else:
		player.set_physics_process(false)
		map.set_physics_process(false)
		if not await _flow_checks(): return
	print("WINDMILL %s PASS (%d checks)" % [phase,checks])
	quit(0)

func _check(condition: bool, text: String) -> bool:
	checks += 1
	if condition: return true
	printerr("WINDMILL FAIL: " + text)
	quit(1)
	return false

func _visit(point: Vector2, delta: float = 0.1) -> void:
	player.position = point
	player.velocity = Vector2.ZERO
	runner._process(delta)

func _clear() -> void:
	# The broad combat suites verify damage/XP. This fixture isolates map progression
	# without opening growth choices halfway through a deterministic traversal.
	for enemy in runner._active_enemies:
		enemy.damage_receiver.health = 0
		enemy.damage_receiver.dead = true
		enemy._targetable = false
	runner._process(0.1)

func _land(point: Vector2) -> void:
	player.position = point
	player.velocity = Vector2.ZERO
	player.set_move_vector(Vector2.ZERO)
	player.set_physics_process(true)
	for frame in 5: await physics_frame
	player.set_physics_process(false)

func _flow_checks() -> bool:
	if not _check(map.active and (player.get_node("Camera2D") as Camera2D).limit_right == 42000,"production start uses long map and camera bounds"): return false
	if not _check(scene.get_node("LeftFloor").collision_layer == 0 and runner.route_terrain.platforms.is_empty(),"old colliders removed"): return false
	if not _check(runner.current_metrics().map_id == "windmill_meadow" and runner.current_metrics().stage_target_s == 300,"new map HUD target"): return false
	_visit(Vector2(2800,780))
	if not _check(map.encounter_id == "entry","optional roadside encounter"): return false
	_visit(Vector2(6200,360))
	if not _check(map.encounter_id == "ridge","upper route remains optional and starts its own fight"): return false
	_clear()
	player.damage_receiver.health = 50
	_visit(Vector2(7350,360))
	_visit(Vector2(7350,360))
	if not _check(player.damage_receiver.health == 70 and map.claimed == [0],"ridge reward granted exactly once: hp=%d claimed=%s cleared=%s" % [player.damage_receiver.health,map.claimed,map.cleared]): return false
	_visit(Vector2(11900,780))
	if not _check(map.encounter_id == "farm_a" and map.barriers[0].collision_layer == 1,"farm encounter physically locks arena"): return false
	_clear()
	var saved: Dictionary = scene.checkpoint_store.load_checkpoint()
	if not _check(not saved.is_empty() and saved.stage.has("windmill_resume") and saved.stage.history.is_empty(),"mid-map save keeps unfinished stage out of history"): return false
	var malformed := saved.duplicate(true)
	malformed.stage.windmill_resume.powered = true
	if not _check(not RunCheckpointStore.valid_state(malformed),"device cannot be forged without its battle"): return false
	malformed = saved.duplicate(true)
	malformed.erase("player")
	if not _check(not RunCheckpointStore.valid_state(malformed),"incomplete save rejected without a script error"): return false
	malformed = saved.duplicate(true)
	malformed.stage.windmill_resume.spawn = [27500,780]
	if not _check(not RunCheckpointStore.valid_state(malformed),"unpowered gap cannot be a resume point"): return false
	var save_path: String = scene.checkpoint_store.save_path
	scene.checkpoint_store.save_path = "user://windmill_missing_directory/progress/checkpoint.json"
	if not _check(scene._save_checkpoint(runner.current_metrics(),false) != OK,"save failure is reported"): return false
	scene.checkpoint_store.save_path = save_path
	if not _check(scene.checkpoint_store.load_checkpoint() == saved,"failed save preserves previous good checkpoint"): return false
	controls.show_main_screen()
	if not _check(scene.continue_saved_run() and not runner.stage_complete and runner.current_section == PrototypeStageRunner.Section.WAVE_ONE,"continue resumes combat map instead of rewards screen"): return false
	if not _check(map.claimed == [0] and player.damage_receiver.health == 70 and map.cleared.has("farm_a"),"health, one-time treasure and encounter persist"): return false
	player.set_physics_process(false)
	_visit(Vector2(14800,780)); _clear()
	if not _check(runner.current_section == PrototypeStageRunner.Section.ADVANCE_TWO,"farm exit after both battles"): return false
	_visit(Vector2(18500,300)); _clear()
	_visit(Vector2(20500,300))
	if not _check(map.claimed.has(1) and scene.get_node("Player/UltimateController").gauge >= 35,"exterior route treasure"): return false
	_visit(Vector2(22500,780)); _clear()
	_visit(Vector2(24950,120)); _clear()
	if not _check(not map.powered and map.bridge.collision_layer == 0,"bridge locked before device activation"): return false
	await _land(Vector2(25155,120))
	if not _check(player.is_on_floor(),"device is reachable on a real collision platform"): return false
	runner._process(0.9)
	if not _check(map.powered and map.bridge.collision_layer == 1,"standing next to cleared device opens bridge"): return false
	saved = scene.checkpoint_store.load_checkpoint()
	if not _check(not saved.is_empty() and saved.stage.windmill_resume.powered,"powered state written to disk"): return false
	controls.show_main_screen()
	if not _check(scene.continue_saved_run() and map.powered and map.bridge.collision_layer == 1,"powered bridge survives a second resume"): return false
	player.set_physics_process(false)
	_visit(Vector2(29200,780)); _clear()
	player.potions_remaining = 0
	_visit(Vector2(32850,230)); _visit(Vector2(32850,230))
	if not _check(player.potions_remaining == 1 and map.claimed.size() == 3,"cliff potion is one-time only"): return false
	_visit(Vector2(33900,780)); _clear()
	_visit(Vector2(37800,780))
	if not _check(map.encounter_id == "elite" and runner.armored_boar.arena_bounds == Vector2(37400,41000),"elite has local arena bounds"): return false
	runner.armored_boar.apply_pole_push(150)
	if not _check(runner.armored_boar.position.x >= 37400 and runner.armored_boar.position.x <= 41000,"elite knockback stays in the new arena"): return false
	_clear()
	if not _check(not runner.stage_complete,"elite defeat opens exit but player must traverse it"): return false
	_visit(Vector2(41600,780))
	if not _check(runner.stage_complete and runner.stage_history.size() == 1 and runner.section_actual_times.size() == 5,"stage clear preserves campaign milestone format"): return false
	saved = scene.checkpoint_store.load_checkpoint()
	if not _check(not saved.is_empty() and not saved.stage.has("windmill_resume"),"completed stage uses compatible reward checkpoint"): return false
	runner.stage_number = 2
	runner.route_id = "wind"
	runner.reset_stage()
	if not _check(not map.active and scene.get_node("LeftFloor").collision_layer == 1 and (player.get_node("Camera2D") as Camera2D).limit_right == 5000,"next map restores original geometry and camera"): return false
	if not _check(not (player.get_node("AutoTargetSelector") as AutoTargetSelector).visibility_filter.is_valid() and runner.armored_boar.arena_bounds == Vector2(120,4880),"next map restores combat bounds and targeting"): return false
	return true

func _physics_checks() -> bool:
	# Use the unmodified single-jump movement controller against actual colliders.
	player.double_jump_unlocked = false
	var pairs: Array[Array] = []
	var ground := WindmillMeadowLayout.surfaces()
	for index in range(ground.size()-1):
		var a := ground[index]
		var b := ground[index+1]
		if b.position.x-a.end.x <= 200 and a.position.y-b.position.y <= 160:
			pairs.append([a,b])
	var ledges := WindmillMeadowLayout.ledges()
	for index in range(ledges.size()-1):
		var a := ledges[index]
		var b := ledges[index+1]
		if b.position.x-a.end.x >= -20 and b.position.x-a.end.x <= 200 and a.position.y-b.position.y > 0 and a.position.y-b.position.y <= 160:
			pairs.append([a,b])
	for pair in pairs:
		if not await _jump_between(pair[0],pair[1]): return false
	# Wind and ray tests use physics, not coordinate-only state transitions.
	map.powered = true
	map.bridge.collision_layer = 1
	player.position = Vector2(28700,500)
	player.velocity = Vector2(0,120)
	await physics_frame
	await physics_frame
	map._physics_process(0.1)
	if not _check(player.velocity.y < 0,"unlocked wind applies upward force"): return false
	map.powered = false
	player.velocity = Vector2(0,120)
	map._physics_process(0.1)
	if not _check(player.velocity.y == 120,"unpowered wind does not apply force"): return false
	# A target below the ridge must be blocked by the ridge's collision surface.
	player.position = Vector2(6800,350)
	runner._activate_enemy(runner.seed_sack,Vector2(6800,840))
	await physics_frame
	if not _check(not map._target_visible(runner.seed_sack),"auto attacks cannot select through another floor"): return false
	player.position = Vector2(6600,350)
	runner.seed_sack.position = Vector2(6900,360)
	await physics_frame
	if not _check(map._target_visible(runner.seed_sack),"same-floor enemy remains selectable"): return false
	player.position = Vector2(6000,840)
	player.velocity = Vector2.ZERO
	player.set_safe_spawn(Vector2(5500,840),"개울 쉼터")
	var falls := player.fall_count
	player.position = Vector2(5100,1170)
	for frame in 60: await physics_frame
	if not _check(player.fall_count == falls+1 and player.position.distance_to(Vector2(5500,840)) < 20,"creek fall returns to local safe stone"): return false
	return true

func _jump_between(a: Rect2, b: Rect2) -> bool:
	player.set_move_vector(Vector2.ZERO)
	player.position = Vector2(a.end.x-55,a.position.y-60)
	player.velocity = Vector2.ZERO
	for frame in 5: await physics_frame
	var start_falls := player.fall_count
	player.request_jump()
	player.set_move_vector(Vector2.RIGHT)
	var landed := false
	for frame in 120:
		await physics_frame
		if player.position.x >= b.position.x+(250 if b.size.x > 2000 else 55): player.set_move_vector(Vector2.ZERO)
		if frame > 5 and player.is_on_floor() and player.position.y+60 <= b.position.y+5 and player.position.x >= b.position.x+10 and player.position.x < b.end.x-10:
			landed = true
			break
	player.release_jump()
	player.set_move_vector(Vector2.ZERO)
	return _check(landed and player.fall_count == start_falls,"single jump: %s -> %s (landed %s velocity=%s floor=%s falls=%d)" % [a,b,player.position,player.velocity,player.is_on_floor(),player.fall_count-start_falls])

func _journey_checks() -> bool:
	runner.run_mode = JourneyRoutePlan.MODE
	runner.stage_limit = 10
	runner.region_order.assign(["wind","forest","ruins","festival"])
	for data in [[1,"wind",true],[2,"wind",false],[3,"forest",false],[5,"wind",true],[9,"city_gate",false],[10,"city_core",false]]:
		runner.stage_number = int(data[0]); runner.route_id = String(data[1]); runner.reset_stage()
		if not _check(map.active == bool(data[2]),"journey scope: %s" % [data]): return false
	runner.set_stage_enabled(false)
	if not _check(not map.active and scene.get_node("LeftFloor").collision_layer == 1,"free combat keeps legacy movement course"): return false
	return true

func _render_checks() -> bool:
	var output := OS.get_environment("WINDMILL_RENDER_DIR")
	if not _check(not output.is_empty() and DisplayServer.get_name() != "headless","renderer is available"): return false
	DirAccess.make_dir_recursive_absolute(output)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	controls.visible = false
	var camera := player.get_node("Camera2D") as Camera2D
	for data in [["creek",6800,780],["farm",12600,700],["mill",24900,150],["wind",29000,400],["exit",39800,780],["mill_hud",24900,150]]:
		player.position = Vector2(data[1],data[2])
		controls.visible = data[0] == "mill_hud"
		runner.force_emit_metrics()
		map.powered = data[0] == "wind"
		map.bridge.collision_layer = 1 if map.powered else 0
		camera.reset_smoothing(); camera.force_update_scroll(); map.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		if not _check(root.get_texture().get_image().save_png(output+"/"+String(data[0])+".png") == OK,"render " + String(data[0])): return false
	return true
