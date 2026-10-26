extends SceneTree

const SANDBOX := preload("res://tests/fixtures/legacy_movement_sandbox.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sandbox := SANDBOX.instantiate()
	root.add_child(sandbox)
	await process_frame
	sandbox.process_mode = Node.PROCESS_MODE_DISABLED
	var player: PrototypePlayer = sandbox.get_node("Player")
	var sprite := player.avatar_sprite
	var collision: CapsuleShape2D = player.get_node("CollisionShape2D").shape
	var health := player.damage_receiver.health
	for id in PrototypeCharacters.IDS:
		if not _check(player.set_character(id), "character selection"): return
		var texture: AtlasTexture = sprite.texture
		var image := texture.atlas.get_image()
		if not _check(image != null and image.get_size() == Vector2i(1536, 1024), "exported atlas loads"): return
		if not _check(texture.get_size() == Vector2(720, 992) and texture.filter_clip, "matching frame size and isolated sampling"): return
		for point in [Vector2i(0, 0), Vector2i(768, 500), Vector2i(100, 500), Vector2i(1500, 1000)]:
			if not _check(image.get_pixelv(point).a < 0.02, "background and inter-character gap remain transparent"): return
		var chest_x := 500 if id == "roan" else 1200
		if not _check(image.get_pixel(chest_x, 500).a > 0.98, "character interior stays opaque"): return
		var feet_y := -1
		for y in range(1023, 0, -1):
			for x in range(int(texture.region.position.x), int(texture.region.end.x)):
				if image.get_pixel(x, y).a > 0.5:
					feet_y = y
					break
			if feet_y >= 0: break
		var local_feet := feet_y - texture.region.position.y + sprite.get_rect().position.y
		var world_feet := sprite.position.y + local_feet * sprite.scale.y
		if not _check(absf(world_feet - collision.height * 0.5) < 1.0, "visible boots align with collision floor"): return
		var size_before := sprite.get_rect().size * sprite.scale
		for direction in [-1, 1]:
			player.facing_direction = direction
			sprite.flip_h = direction < 0
			if not _check(sprite.texture == texture and sprite.get_rect().size * sprite.scale == size_before, "mirroring preserves frame and scale"): return
		if not _check(collision.radius == 36.0 and collision.height == 120.0 and player.damage_receiver.health == health, "art switch preserves collision and health"): return
	if not _check(PrototypeCharacters.appearance("roan").contains("은발") and PrototypeCharacters.appearance("lumi").contains("금발"), "selection descriptions match art"): return
	print("Character art runtime: OK")
	sandbox.queue_free()
	await process_frame
	quit(0)

func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error("Character art: " + description)
		quit(1)
	return condition
