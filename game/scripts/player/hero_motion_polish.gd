class_name HeroMotionPolish
extends RefCounted

## Presentation only. Never writes velocity, collision, damage, RNG or persistence.
const TRAIL_LIFETIME := 0.18
const TRAIL_INTERVAL := 0.035
const MAX_TRAILS := 6
const SWITCH_DURATION := 0.34
var clock_s := 0.0
var run_phase := 0.0
var trails: Array[Dictionary] = []
var trail_clock := 0.0
var last_mobility := 0
var hit_remaining := 0.0
var hit_direction := 1.0
var attack_elapsed := -1.0
var attack_direction := 1.0
var anticipating := false
var attack_family := "sword"
var switch_elapsed := -1.0
var switch_color := Color.WHITE

func reset(sprite: Sprite2D) -> void:
	clock_s = 0.0
	run_phase = 0.0
	trails.clear()
	trail_clock = 0.0
	last_mobility = 0
	hit_remaining = 0.0
	attack_elapsed = -1.0
	switch_elapsed = -1.0
	sprite.rotation = 0.0

func attack(family: String, direction: int, windup: bool) -> void:
	attack_family = family
	attack_direction = -1.0 if direction < 0 else 1.0
	anticipating = windup
	attack_elapsed = 0.0

func recoil(direction: float) -> void:
	hit_direction = -1.0 if direction < 0 else 1.0
	hit_remaining = 0.18
	attack_elapsed = -1.0

func switch_weapon(character: String) -> void:
	switch_elapsed = 0.0
	switch_color = Color("80e5f4") if character == "roan" else Color("f8d286")
	attack_elapsed = -1.0

func update(sprite: Sprite2D, delta: float, state: String, state_time: float,
		motion: Vector2, facing: int, mobility: int, combat: bool, interrupted: bool) -> void:
	var dt := maxf(0.0, delta)
	clock_s += dt
	run_phase = fposmod(run_phase + absf(motion.x) * dt * PI / 137.5, TAU)
	for trail in trails: trail.age += dt
	while not trails.is_empty() and float(trails[0].age) >= TRAIL_LIFETIME:
		trails.pop_front()
	hit_remaining = maxf(0.0, hit_remaining - dt)
	if attack_elapsed >= 0.0:
		attack_elapsed += dt
		if attack_elapsed >= (0.8 if anticipating else 0.24): attack_elapsed = -1.0
	if switch_elapsed >= 0.0:
		switch_elapsed += dt
		if switch_elapsed >= SWITCH_DURATION: switch_elapsed = -1.0
	if interrupted or state == "death":
		trails.clear()
		attack_elapsed = -1.0
		switch_elapsed = -1.0
		if state != "hit": hit_remaining = 0.0
	if mobility != 0: attack_elapsed = -1.0
	# Baseline is reapplied from the atlas on every update; no transform accumulation.
	var foot_y := HeroCombatAnimation.FOOT_Y - HeroCombatAnimation.FRAME_SIZE.y * 0.5 if combat else HeroMovementAnimation.FOOT_Y - HeroMovementAnimation.FRAME_SIZE.y * 0.5
	var anchor := sprite.position + Vector2(0.0, foot_y) * sprite.scale
	var stretch := Vector2.ONE
	var offset := Vector2.ZERO
	var angle := 0.0
	if not interrupted and state != "death":
		if not combat and attack_elapsed < 0.0:
			match state:
				"idle":
					var breath := sin(clock_s * 2.5) * 0.014
					stretch = Vector2(1.0 - breath * 0.4, 1.0 + breath)
				"run":
					offset.y = -absf(sin(run_phase)) * 2.8
					angle = float(facing) * minf(absf(motion.x) / 550.0, 1.0) * 0.045
					stretch = Vector2(1.0 + cos(run_phase * 2.0) * 0.018, 1.0 - cos(run_phase * 2.0) * 0.018)
				"jump", "fall":
					var speed := clampf(motion.y / 1100.0, -1.0, 1.0)
					stretch = Vector2(1.0 - absf(speed) * 0.035, 1.0 + absf(speed) * 0.055)
					angle = float(facing) * speed * 0.022
				"land":
					var squash := sin(clampf(state_time * 14.0 / 2.0, 0.0, 1.0) * PI)
					stretch = Vector2(1.0 + squash * 0.065, 1.0 - squash * 0.085)
		if attack_elapsed >= 0.0:
			var force := minf(attack_elapsed / 0.10, 1.0) * -0.45 if anticipating else pow(1.0 - clampf(attack_elapsed / 0.24, 0.0, 1.0), 2.0)
			var weight := 0.65 if attack_family in ["bow", "staff"] else 1.0
			angle = attack_direction * force * 0.055 * weight
			offset.x = attack_direction * force * 4.0 * weight
			stretch = Vector2(1.0 + absf(force) * 0.018, 1.0 - absf(force) * 0.018)
	if hit_remaining > 0.0 and state != "death":
		var recoil_weight := pow(hit_remaining / 0.18, 2.0)
		offset.x = hit_direction * 7.0 * recoil_weight
		angle = hit_direction * 0.065 * recoil_weight
	sprite.scale *= stretch
	sprite.rotation = angle
	sprite.position = anchor + offset - (Vector2(0.0, foot_y) * sprite.scale).rotated(angle)
	if mobility != 0 and not interrupted:
		if last_mobility != mobility: trail_clock = TRAIL_INTERVAL
		trail_clock += dt
		if trail_clock >= TRAIL_INTERVAL and dt > 0.0:
			trail_clock = fposmod(trail_clock, TRAIL_INTERVAL)
			trails.append({"texture":sprite.texture,"transform":sprite.global_transform,"flip":sprite.flip_h,"age":0.0,"air":mobility == 2})
			if trails.size() > MAX_TRAILS: trails.pop_front()
	else:
		trail_clock = 0.0
	last_mobility = mobility

func draw(canvas: Node2D) -> void:
	for trail in trails:
		var transform: Transform2D = canvas.global_transform.affine_inverse() * trail.transform
		if trail.flip: transform = transform * Transform2D(Vector2(-1,0), Vector2(0,1), Vector2.ZERO)
		canvas.draw_set_transform_matrix(transform)
		var texture: Texture2D = trail.texture
		var tint := Color("ffd98c") if trail.air else Color("8de5ee")
		tint.a = 0.28 * (1.0 - float(trail.age) / TRAIL_LIFETIME)
		canvas.draw_texture_rect(texture, Rect2(-texture.get_size() * 0.5, texture.get_size()), false, tint)
		canvas.draw_set_transform(Vector2.ZERO)
		if trail.air:
			var center: Vector2 = canvas.to_local(trail.transform.origin)
			canvas.draw_line(center + Vector2(-22,6), center + Vector2(22,6), Color(tint, tint.a * 0.6), 2.0, true)
	canvas.draw_set_transform(Vector2.ZERO)
	if switch_elapsed >= 0.0:
		var progress := switch_elapsed / SWITCH_DURATION
		var tint := Color(switch_color, sin(progress * PI) * 0.75)
		var center := Vector2(0,-36)
		canvas.draw_set_transform(center, progress * PI * 1.2, Vector2(1,0.55))
		canvas.draw_arc(Vector2.ZERO, 43.0 + progress * 22.0, 0.0, PI * 1.35, 32, tint, 2.5, true)
		canvas.draw_set_transform(Vector2.ZERO)
		for index in 3:
			var point := center + Vector2(52.0 + progress * 18.0,0).rotated(progress * PI * 1.2 + index * TAU / 3.0)
			canvas.draw_line(point - Vector2(4,0), point + Vector2(4,0), tint, 2.0, true)
			canvas.draw_line(point - Vector2(0,4), point + Vector2(0,4), tint, 2.0, true)
