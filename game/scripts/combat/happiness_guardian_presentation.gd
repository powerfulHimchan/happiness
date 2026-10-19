extends BossHappinessGuardian

## Guardian-only body, articulated shield and effects; the base owns combat.
const SHIELD_TEXTURE := preload("res://assets/guardian_shield.svg")
const BODY_SCALE := Vector2(1.15, 1.15)
const FOOT_Y := 69.0
var shield_sprite: Sprite2D
var _effects: Node2D
var _presentation_ready := false
var _visual_state := -1
var _visual_elapsed_s := 0.0
var _visual_facing := -1.0
var _shield_drop := 0.55
var _lance_elapsed_s := -1.0


func _ready() -> void:
	super._ready()
	shield_sprite = Sprite2D.new()
	shield_sprite.name = "ShieldSprite"
	shield_sprite.texture = SHIELD_TEXTURE
	shield_sprite.z_index = 1
	add_child(shield_sprite)
	_effects = Node2D.new()
	_effects.name = "GuardianEffects"
	_effects.z_index = 1
	add_child(_effects)
	_effects.draw.connect(_draw_effects)
	_presentation_ready = true
	_update_presentation(0.0)


func _process(delta: float) -> void:
	var visual_delta := delta * enemy_time_scale()
	if _lance_elapsed_s >= 0.0:
		_lance_elapsed_s += visual_delta
	super._process(delta)
	_update_presentation(visual_delta)


func _set_state(new_state: int, message: String) -> void:
	super._set_state(new_state, message)
	_update_presentation(0.0)


func _update_warning() -> void:
	var before := lance_count
	super._update_warning()
	if lance_count > before:
		_lance_elapsed_s = 0.0
	_update_presentation(0.0)


func receive_damage(event: DamageEvent) -> int:
	var result := super.receive_damage(event)
	_update_presentation(0.0)
	return result


func reset_target() -> void:
	super.reset_target()
	_update_visual()
	_update_phase_visual()
	_visual_state = -1
	_visual_elapsed_s = 0.0
	_visual_facing = -1.0
	_shield_drop = 0.55
	_lance_elapsed_s = -1.0
	_update_presentation(0.0)


func _update_presentation(delta: float) -> void:
	if not _presentation_ready:
		return
	if _visual_state != state:
		_visual_state = state
		_visual_elapsed_s = 0.0
	else:
		_visual_elapsed_s += maxf(0.0, delta)
	if state in [State.WARNING, State.CHARGING]:
		_visual_facing = _charge_direction
	elif state == State.IDLE:
		var direction := signf(player.global_position.x - global_position.x)
		if not is_zero_approx(direction): _visual_facing = direction
	var stretch := Vector2.ONE
	var angle := 0.0
	var tint := Color.WHITE
	var offset := Vector2.ZERO
	var t := _state_elapsed_s
	match state:
		State.IDLE:
			var moving := absf(player.global_position.x - global_position.x) > 6.0 * PrototypePlayer.PIXELS_PER_METER
			var rhythm := sin(_visual_elapsed_s * (9.0 if moving else 2.4))
			stretch = Vector2(1.0 + rhythm * 0.012, 1.0 - rhythm * 0.018)
			angle = rhythm * 0.02 * _visual_facing if moving else 0.0
		State.WARNING:
			var duration := _charge_warning_duration() if current_pattern == Pattern.CHARGE else _shockwave_warning_duration() if current_pattern == Pattern.SHOCKWAVE else 0.80 if phase == 2 else 1.10
			var progress := clampf(t / duration, 0.0, 1.0)
			if current_pattern == Pattern.CHARGE:
				stretch = Vector2(1.0 + progress * 0.05, 1.0 - progress * 0.10)
				angle = 0.12 * progress * _visual_facing
			elif current_pattern == Pattern.SHOCKWAVE:
				stretch = Vector2(1.0 - progress * 0.035, 1.0 + progress * 0.055)
				angle = -0.045 * progress * _visual_facing
			else:
				angle = -0.045 * progress * _visual_facing
		State.CHARGING:
			stretch = Vector2(1.05, 0.92 + sin(t * 27.0) * 0.015)
			angle = 0.14 * _visual_facing
		State.SHOCKWAVE:
			var stomp_time := t - 0.22 if phase == 2 and t >= 0.22 else t
			var impact := maxf(0.0, 1.0 - stomp_time / 0.20)
			stretch = Vector2(1.0 + impact * 0.10, 1.0 - impact * 0.18)
		State.STUNNED:
			stretch = Vector2(1.04, 0.88)
			angle = (-0.09 + sin(t * 8.5) * 0.03) * _visual_facing
		State.RECOVERY:
			var recoil := maxf(0.0, 1.0 - _lance_elapsed_s / 0.28) if _lance_elapsed_s >= 0.0 else 0.0
			angle = -0.10 * recoil * _visual_facing
			stretch = Vector2(1.0 - recoil * 0.04, 1.0 + recoil * 0.02)
		State.PHASE_TRANSITION:
			stretch = Vector2(1.025, 0.975)
			offset.x = sin(t * 36.0) * 1.5
		State.DEAD:
			var collapse := clampf(_visual_elapsed_s / 0.45, 0.0, 1.0)
			stretch = Vector2(1.0 + collapse * 0.10, 1.0 - collapse * 0.60)
			angle = -0.16 * collapse * _visual_facing
			tint.a = lerpf(1.0, 0.25, collapse)
	if phase == 2 and state != State.DEAD: tint = Color(1.12, 0.94, 0.78)
	if _hit_flash_remaining_s > 0.0 and state != State.DEAD:
		tint = Color(1.6, 1.6, 1.6)
		stretch *= Vector2(1.03, 0.97)
	# This art faces left, matching the guardian's existing front-shield rule.
	body_sprite.flip_h = _visual_facing > 0.0
	body_sprite.scale = BODY_SCALE * stretch
	body_sprite.rotation = angle
	body_sprite.self_modulate = tint
	var mirror := -_visual_facing
	var left_sole := (Vector2(-36.0 * mirror, FOOT_Y) * body_sprite.scale).rotated(angle)
	var right_sole := (Vector2(47.0 * mirror, FOOT_Y) * body_sprite.scale).rotated(angle)
	body_sprite.position = Vector2(0.0, 60.0) - Vector2(0.0, FOOT_Y * body_sprite.scale.y).rotated(angle) + offset
	body_sprite.position.y = 60.0 - maxf(left_sole.y, right_sole.y)
	var drop_target := 0.0 if _shield_raised() else 0.55 if state == State.IDLE else 1.0
	_shield_drop = move_toward(_shield_drop, drop_target, maxf(0.0, delta) * 7.5)
	shield_sprite.flip_h = body_sprite.flip_h
	shield_sprite.scale = body_sprite.scale
	shield_sprite.rotation = angle - _visual_facing * _shield_drop * 0.14
	shield_sprite.position = body_sprite.position + (Vector2(48.0 * _visual_facing, 8.0 + _shield_drop * 15.0) * body_sprite.scale).rotated(angle)
	shield_sprite.modulate = body_sprite.modulate
	shield_sprite.self_modulate = tint
	queue_redraw()
	_effects.queue_redraw()


func _draw() -> void:
	if not _presentation_ready or state != State.CHARGING: return
	for index in 3:
		var trail := fmod(_visual_elapsed_s * 3.0 + index / 3.0, 1.0)
		var center := Vector2(-_visual_facing * (58.0 + trail * 40.0), 54.0 - trail * 8.0)
		draw_circle(center, 3.0 + trail * 6.0, Color(0.78, 0.77, 0.64, (1.0 - trail) * 0.5))


func _draw_effects() -> void:
	if state == State.STUNNED:
		for index in 3:
			var orbit := _visual_elapsed_s * 4.0 + index * TAU / 3.0
			var center := Vector2(cos(orbit) * 30.0, -112.0 + sin(orbit) * 7.0)
			var points := PackedVector2Array()
			for tip in 8:
				points.append(center + Vector2(0, -6.0 if tip % 2 == 0 else -2.5).rotated(tip * TAU / 8.0))
			_effects.draw_colored_polygon(points, Color("fff0b3"))
	if state == State.RECOVERY and _lance_elapsed_s >= 0.0 and _lance_elapsed_s < 0.18:
		var progress := _lance_elapsed_s / 0.18
		for index in 3:
			var ray := _lance_aim.rotated((index - 1) * 0.16)
			_effects.draw_line(Vector2(0, -48) + ray * (16 + progress * 16), Vector2(0, -48) + ray * (32 + progress * 28), Color(0.63, 1.0, 0.90, 1.0 - progress), 3.0, true)
