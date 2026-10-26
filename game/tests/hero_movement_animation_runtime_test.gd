extends SceneTree

const SANDBOX := preload("res://tests/fixtures/legacy_movement_sandbox.tscn")
var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sandbox := SANDBOX.instantiate()
	root.add_child(sandbox)
	await process_frame
	sandbox.get_node("CanvasLayer/GroundMovementControls").begin_retry("sword", 3, "standard", "roan")
	for node in sandbox.find_children("*", "", true, false):
		node.set_process(false)
		node.set_physics_process(false)
	sandbox.set_process(false)
	sandbox.set_physics_process(false)
	var player: PrototypePlayer = sandbox.get_node("Player")
	var sprite := player.avatar_sprite
	var animator := player.movement_animation
	for character in PrototypeCharacters.IDS:
		player.reset_movement_test(Vector2(960, 780))
		player.set_character(character)
		var health := player.damage_receiver.health
		var shape: CapsuleShape2D = player.get_node("CollisionShape2D").shape
		var image: Image = HeroMovementAnimation.SHEETS[character].get_image()
		_check(image != null and image.get_size() == Vector2i(1536, 1024), "sheet exported and loaded")
		_check(image.get_pixel(0, 0).a < 0.01, "transparent sheet background")
		for clip in HeroMovementAnimation.CLIPS:
			var data: Dictionary = HeroMovementAnimation.CLIPS[clip]
			var seen: Dictionary = {}
			for frame in data.frames.size():
				animator.apply_frame(sprite, character, clip, (frame + 0.1) / float(data.fps))
				var texture: AtlasTexture = sprite.texture
				seen[texture.region] = true
				_check(texture.get_size() == HeroMovementAnimation.FRAME_SIZE and texture.filter_clip, "stable padded frame and sampling")
				_check(Rect2(Vector2.ZERO, image.get_size()).encloses(texture.region), "frame fits atlas")
				# Bounds capture actual alpha, including poses crossing nominal grid cells.
				var bounds: Rect2 = HeroMovementAnimation.REGIONS[character][animator.frame_index]
				var opaque_count := 0
				for y in range(int(bounds.position.y), int(bounds.end.y), 4):
					for x in range(int(bounds.position.x), int(bounds.end.x), 4):
						if image.get_pixel(x, y).a > 0.5: opaque_count += 1
				_check(opaque_count > 300, "each frame contains a complete visible pose")
				if clip not in ["air_dash"]:
					var foot_y := texture.margin.position.y + bounds.size.y - HeroMovementAnimation.FRAME_SIZE.y * 0.5
					_check(absf(sprite.position.y + foot_y * sprite.scale.y - 60.0) < 0.1, "ground contact stays on collision floor")
				var texture_before := sprite.texture
				sprite.flip_h = true
				_check(sprite.texture == texture_before and sprite.scale.x > 0.0, "left facing preserves clip and scale")
				sprite.flip_h = false
			_check(seen.size() == data.frames.size(), "distinct frames for " + clip)
			if not data.loop:
				animator.apply_frame(sprite, character, clip, 100.0)
				_check(animator.frame_index == data.frames[-1], "one-shot holds last pose")
		_check(shape.radius == 36 and shape.height == 120 and player.damage_receiver.health == health, "art does not change collision or health")
		# Exercise state priorities and interruption without modifying gameplay state.
		animator.reset(sprite, character)
		_step(animator, sprite, character, true, Vector2.ZERO, 0, false, false, "idle")
		_step(animator, sprite, character, true, Vector2(550, 0), 0, false, false, "run")
		for i in 10: animator.update(sprite, character, 1.0 / 60.0, true, Vector2(550, 0), 0, false, false)
		_check(animator.frame_index != 2, "running advances across physics frames")
		_step(animator, sprite, character, false, Vector2(100, -600), 0, false, false, "jump")
		_step(animator, sprite, character, false, Vector2(100, 400), 0, false, false, "fall")
		_step(animator, sprite, character, true, Vector2.ZERO, 0, false, false, "land")
		_step(animator, sprite, character, false, Vector2(0, -500), 0, false, false, "jump")
		_step(animator, sprite, character, true, Vector2(900, 0), 1, false, false, "evade")
		_step(animator, sprite, character, false, Vector2(950, 0), 2, false, false, "air_dash")
		_step(animator, sprite, character, false, Vector2(950, 0), 2, true, false, "hit")
		_step(animator, sprite, character, false, Vector2.ZERO, 2, true, true, "death")
		animator.update(sprite, character, 2.0, false, Vector2.ZERO, 0, false, true)
		_check(animator.frame_index == 23, "death settles and does not loop")
		player.reset_movement_test(Vector2(960, 780))
		_check(animator.state == "idle" and animator.elapsed_s == 0 and sprite.scale == Vector2(0.16, 0.16), "retry clears death and restores transform")
		# Real player physics integration: floor, move, jump, dash, landing, evade, hit/death.
		player.set_character(character)
		for i in 30:
			player._physics_process(1.0 / 60.0)
			await physics_frame
		_check(player.is_on_floor(), "fixture reaches actual floor")
		player.set_move_vector(Vector2.RIGHT)
		for i in 10:
			player._physics_process(1.0 / 60.0)
			await physics_frame
		_check(animator.state == "run" and player.velocity.x > 0, "real movement selects run")
		player.request_jump()
		player._physics_process(1.0 / 60.0)
		_check(animator.state == "jump" and player.velocity.y < 0, "real jump selects ascent")
		player.request_evade()
		player._physics_process(1.0 / 60.0)
		_check(animator.state == "air_dash" and player.air_dash_count == 1, "real air dash selects dash")
		player.set_move_vector(Vector2.ZERO)
		var saw_fall := false
		var saw_land := false
		for i in 100:
			player._physics_process(1.0 / 60.0)
			await physics_frame
			saw_fall = saw_fall or animator.state == "fall"
			saw_land = saw_land or animator.state == "land"
		_check(saw_fall and saw_land and player.is_on_floor(), "real descent and landing are visible")
		player.request_evade()
		player._physics_process(1.0 / 60.0)
		_check(animator.state == "evade" and player.ground_evade_count == 1, "real ground evade selects roll")
		for i in 30:
			player._physics_process(1.0 / 60.0)
			await physics_frame
		var event := DamageEvent.new()
		event.event_id = "animation-hit-" + character
		event.damage = 10
		player.receive_damage(event)
		player._physics_process(1.0 / 60.0)
		_check(animator.state == "hit" and player.damage_receiver.health == 90, "real damage selects hit without changing damage")
		player.damage_receiver.tick(2.0)
		event = DamageEvent.new()
		event.event_id = "animation-death-" + character
		event.damage = 1000
		player.receive_damage(event)
		for i in 40: player._physics_process(1.0 / 60.0)
		_check(animator.state == "death" and animator.frame_index == 23 and player.velocity == Vector2.ZERO, "real death holds final pose")
		player.prepare_next_stage(Vector2(960, 780))
		_check(animator.state == "idle" and animator.elapsed_s == 0, "stage change clears previous pose")
	sandbox.queue_free()
	await process_frame
	if not failed: print("Hero movement animation runtime: OK")
	quit(1 if failed else 0)

func _step(animator: HeroMovementAnimation, sprite: Sprite2D, character: String,
		grounded: bool, motion: Vector2, mobility: int, hit: bool, dead: bool, expected: String) -> void:
	animator.update(sprite, character, 1.0 / 60.0, grounded, motion, mobility, hit, dead)
	_check(animator.state == expected, "state transition to " + expected)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("Hero animation: " + message)
