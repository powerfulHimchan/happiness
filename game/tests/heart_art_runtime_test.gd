extends SceneTree

const SANDBOX := preload("res://scenes/movement/ground_movement_sandbox.tscn")
var failures := 0
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var stage := SANDBOX.instantiate()
	stage.get_node("RecoveryOrbController").drop_chance = 0
	root.add_child(stage)
	current_scene = stage
	await process_frame
	stage.get_node("StageRunner").set_stage_enabled(false)
	stage.get_node("CombatFeedbackController").configure(0,false,false)
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	var heart = stage.get_node("Targets/HappinessHeart")
	var player: PrototypePlayer = stage.get_node("Player")
	for pair in [[heart.body_sprite.texture,Vector2i(240,230)],[heart.core_sprite.texture,Vector2i(96,100)]]:
		var img: Image = pair[0].get_image()
		_check(img.get_size() == pair[1] and img.get_pixel(0,0).a == 0,"art extent/transparency")
	var warning: Transform2D = heart.warning_line.transform
	var ring: Transform2D = heart.warning_ring.transform
	var selection: Transform2D = heart.selection_sprite.transform
	var health: Rect2 = heart.health_bar.get_rect()
	for direction in [-1.0,1.0]:
		heart.set_stage_spawn(Vector2(4450,780))
		heart.visible = true
		player.position = heart.position + Vector2(direction * 300,0)
		for phase in [1,2]:
			for pose in ["idle","wave-warning","wave","needles-warning","needles","beam-warning","beam","recovery","phase","dead"]:
				heart.reset_target()
				heart.phase = phase
				heart.current_pattern = 4 if pose.begins_with("needles") else 3 if pose.begins_with("beam") else 2
				var state: int = {"idle":0,"wave-warning":1,"wave":3,"needles-warning":1,"needles":5,"beam-warning":1,"beam":5,"recovery":5,"phase":6,"dead":7}[pose]
				heart._set_state(state,"art test")
				heart._state_elapsed_s = 0.5 if state == 1 else 0.03
				var metrics: Dictionary = heart.current_metrics()
				heart._update_presentation(0.2)
				_check(heart.position == Vector2(4450,780) and heart.current_metrics() == metrics,"art leaves combat unchanged: " + pose)
				_check(heart.core_sprite.position.is_equal_approx(heart.body_sprite.transform * Vector2(0,-3)),"core stays in shell: " + pose)
				_check(heart.warning_line.transform == warning and heart.warning_ring.transform == ring and heart.selection_sprite.transform == selection and heart.health_bar.get_rect() == health,"telegraph/selection/HUD geometry: " + pose)
			for pattern in [BossHappinessHeart.NEEDLES,BossHappinessHeart.BEAM]:
				heart.reset_target()
				heart.phase = phase
				heart.last_pattern = 2 if pattern == 4 else 4
				heart._begin_next_pattern()
				heart._process((0.72 if phase == 2 else 1.05) - 0.01)
				_check(heart.attack_count == 0 and heart._shot_elapsed_s == -1,"no early shot/flash")
				heart._process(0.4)
				_check(heart.state == 5 and heart.attack_count == 1 and heart._shot_elapsed_s == 0 and heart._shot_pattern == pattern,"actual shot drives long-frame recoil")
				if pattern == 4:
					_check(get_nodes_in_group("enemy_projectile").size() == (5 if phase == 2 else 3),"real phase-specific needle count")
				else: _check(heart.beam_count == 1 and is_equal_approx(heart._beam_flash_s,0.15),"existing beam duration retained")
				var body: Transform2D = heart.body_sprite.transform
				var core: Transform2D = heart.core_sprite.transform
				heart.set_enemy_time_scale(0)
				heart._process(1)
				_check(heart.body_sprite.transform == body and heart.core_sprite.transform == core and heart._shot_elapsed_s == 0,"zero slow freezes shell/core/effects")
				heart.set_enemy_time_scale(0.5)
				heart._process(0.1)
				_check(is_equal_approx(heart._shot_elapsed_s,0.05),"half slow scales effects")
				heart.set_enemy_time_scale(1)
				heart.process_mode = Node.PROCESS_MODE_PAUSABLE
				paused = true
				var elapsed: float = heart._visual_elapsed_s
				await process_frame
				await process_frame
				_check(heart._visual_elapsed_s == elapsed and heart._shot_elapsed_s == 0.05,"scene pause freezes core")
				paused = false
				heart.process_mode = Node.PROCESS_MODE_INHERIT
				for shot in get_nodes_in_group("enemy_projectile"): shot.free()
		heart.reset_target()
		var hit := DamageEvent.new()
		hit.event_id = StringName("heart-art:phase:%s" % direction)
		hit.damage = 600
		heart.receive_damage(hit)
		_check(heart.phase == 2 and heart.state == 6 and heart.body_sprite.self_modulate.r > 1 and heart.core_sprite.self_modulate == heart.body_sprite.self_modulate,"actual awakening and hit flash")
		hit = DamageEvent.new()
		hit.event_id = StringName("heart-art:dead:%s" % direction)
		hit.damage = 99999
		heart.receive_damage(hit)
		_check(heart.state == 7 and not heart.is_targetable() and heart._beam_flash_s == 0 and heart._shot_elapsed_s == -1,"immediate death clears beam/flash")
		heart._process(0.5)
		_check(heart.core_sprite.self_modulate.a <= 0.26 and heart.body_sprite.self_modulate.a <= 0.26,"shell/core fade together")
		heart.reset_target()
		_check(heart.body_sprite.modulate == Color.WHITE and heart.core_sprite.modulate == Color.WHITE and heart.core_sprite.self_modulate == Color.WHITE and heart._shot_elapsed_s == -1,"respawn clears all colors/effects")
	stage.free()
	print("Heart art runtime: %s (both sides/phases, poses, actual needles/beam, slow/pause, hit/death/reset)" % ("OK" if failures == 0 else "FAILED"))
	quit(0 if failures == 0 else 1)
func _check(condition: bool,label: String) -> void:
	if not condition:
		failures += 1
		push_error("Heart art: " + label)
