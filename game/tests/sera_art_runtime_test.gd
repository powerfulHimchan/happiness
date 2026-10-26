extends SceneTree

const SANDBOX := preload("res://tests/fixtures/legacy_movement_sandbox.tscn")
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
	var queen = stage.get_node("Targets/Sera")
	var player: PrototypePlayer = stage.get_node("Player")
	for texture in [BossSera.CALM_TEXTURE, BossSera.AWAKENED_TEXTURE, BossSera.SPARK_TEXTURE]:
		var image: Image = texture.get_image()
		_check(image.get_size() == (Vector2i(28,28) if texture == BossSera.SPARK_TEXTURE else Vector2i(160,180)) and image.get_pixel(0,0).a == 0.0, "art extent/transparency")
	var warning: Transform2D = queen.warning_line.transform
	var ring: Transform2D = queen.warning_ring.transform
	var selection: Transform2D = queen.selection_sprite.transform
	var health: Rect2 = queen.health_bar.get_rect()
	for facing in [-1.0, 1.0]:
		queen.set_stage_spawn(Vector2(4450,780))
		queen.visible = true
		queen.reset_target()
		player.position = queen.position + Vector2(facing * 300,0)
		queen._charge_direction = facing
		for pose in ["idle","dash-warning","dash","wave-warning","wave","ring-warning","stun","recovery","phase","dead"]:
			queen.phase = 2 if pose == "phase" else 1
			queen.current_pattern = 2 if pose.begins_with("wave") else 3 if pose == "ring-warning" else 1
			var state: int = {"idle":0,"dash-warning":1,"dash":2,"wave-warning":1,"wave":3,"ring-warning":1,"stun":4,"recovery":5,"phase":6,"dead":7}[pose]
			queen._set_state(state,"art test")
			queen._state_elapsed_s = 0.5 if state == 1 else 0.03
			var metrics: Dictionary = queen.current_metrics()
			queen._update_presentation(0.2)
			var body: Sprite2D = queen.body_sprite
			_check(body.flip_h == (facing > 0), "facing: " + pose)
			var mirror: float = -facing
			var lower_sole := maxf((body.transform * Vector2(-21 * mirror,84)).y, (body.transform * Vector2(22 * mirror,84)).y)
			_check(is_equal_approx(lower_sole,60.0), "grounded soles: " + pose)
			_check(queen.position == Vector2(4450,780) and queen.current_metrics() == metrics, "art cannot alter combat: " + pose)
			_check(queen.warning_line.transform == warning and queen.warning_ring.transform == ring and queen.selection_sprite.transform == selection and queen.health_bar.get_rect() == health, "telegraph/selection/HUD geometry: " + pose)
			_check(body.texture == (BossSera.AWAKENED_TEXTURE if queen.phase == 2 else BossSera.CALM_TEXTURE), "phase texture: " + pose)
		queen.reset_target()
		queen._begin_next_pattern()
		_check(queen.state == 1 and queen.body_sprite.flip_h == (facing > 0), "immediate warning direction")
		queen._process(0.84)
		_check(queen.state == 1, "full dash warning")
		queen._process(0.02)
		player.position.x = queen.position.x - facing * 300
		queen._process(0.01)
		_check(queen.state == 2 and queen.charge_count == 1 and queen.body_sprite.flip_h == (facing > 0), "actual dash keeps warning direction")
		for phase in [1,2]:
			queen.reset_target()
			player.position = queen.position + Vector2(facing * 300,0)
			if phase == 2:
				var transition := DamageEvent.new()
				transition.event_id = StringName("sera-art:phase:%s" % facing)
				transition.damage = 480
				queen.receive_damage(transition)
				_check(queen.phase == 2 and queen.state == 6 and queen.body_sprite.texture == BossSera.AWAKENED_TEXTURE, "actual half-health awakening")
				queen._process(0.76)
			queen.last_pattern = EliteArmoredBoar.Pattern.SHOCKWAVE
			queen._begin_next_pattern()
			queen._process((0.80 if phase == 2 else 1.10) - 0.01)
			_check(queen.ring_count == 0 and queen._ring_elapsed_s == -1.0, "no early ring/flash")
			player.position.x = queen.position.x - facing * 300
			queen._process(0.4)
			_check(queen.state == 5 and queen.ring_count == 1 and get_nodes_in_group("enemy_projectile").size() == 8, "actual eight-way ring")
			_check(queen._ring_elapsed_s == 0 and queen.body_sprite.rotation * facing < 0 and queen.body_sprite.flip_h == (facing > 0), "actual long-frame shot drives recoil/facing")
			var frozen: Transform2D = queen.body_sprite.transform
			queen.set_enemy_time_scale(0)
			queen._process(0.4)
			_check(queen.body_sprite.transform == frozen and queen._ring_elapsed_s == 0 and queen.ring_count == 1, "zero slow freezes art and follow-up")
			queen.set_enemy_time_scale(0.5)
			queen._process(0.1)
			_check(is_equal_approx(queen._ring_elapsed_s,0.05), "half slow scales effects")
			queen.set_enemy_time_scale(1)
			queen.process_mode = Node.PROCESS_MODE_PAUSABLE
			paused = true
			var elapsed: float = queen._visual_elapsed_s
			await process_frame
			await process_frame
			_check(queen._visual_elapsed_s == elapsed and queen._ring_elapsed_s == 0.05, "scene pause freezes effects")
			paused = false
			queen.process_mode = Node.PROCESS_MODE_INHERIT
			if phase == 2:
				queen._process(0.24)
				_check(queen.ring_count == 2 and get_nodes_in_group("enemy_projectile").size() == 16 and queen._ring_elapsed_s == 0 and queen._ring_rotation == PI/8.0, "delayed rotated second ring restarts actual flash")
			for shot in get_nodes_in_group("enemy_projectile"): shot.free()
		queen.reset_target()
		var hit := DamageEvent.new()
		hit.event_id = StringName("sera-art:hit:%s" % facing)
		hit.damage = 1
		queen.receive_damage(hit)
		_check(queen.damage_receiver.health == 959 and queen.body_sprite.self_modulate.r > 1, "actual hit flash")
		hit = DamageEvent.new()
		hit.event_id = StringName("sera-art:dead:%s" % facing)
		hit.damage = 99999
		queen.receive_damage(hit)
		_check(queen.state == 7 and not queen.is_targetable() and not queen.warning_line.visible and queen._ring_elapsed_s == -1, "immediate defeat clears flash")
		queen._process(0.5)
		_check(queen.body_sprite.self_modulate.a <= 0.26, "defeat fade")
		queen.reset_target()
		_check(queen.body_sprite.self_modulate == Color.WHITE and queen.body_sprite.texture == BossSera.CALM_TEXTURE and queen._ring_elapsed_s == -1 and queen._ring_rotation == 0, "respawn clears presentation")
	for pair in [["ClockworkKnight","clockwork_knight_presentation"],["ArmoredBoar","armored_boar_presentation"],["HappinessGuardian","happiness_guardian_presentation"],["HappinessHeart","happiness_heart_presentation"]]:
		_check(stage.get_node("Targets/"+pair[0]).get_script().resource_path == "res://scripts/combat/%s.gd" % pair[1], "other actor unchanged: "+pair[0])
	stage.free()
	print("Sera art runtime: %s (both directions, poses, floor, actual dash/rings, slow/pause, awakening, hit/death/reset)" % ("OK" if failures == 0 else "FAILED"))
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("Sera art: " + label)
