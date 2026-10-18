extends EliteArmoredBoar

## Boar-only presentation. Shared boss AI and combat timers remain in the base.
const BODY_SCALE := Vector2(1.35, 1.35)
const FOOT_Y := 59.0
var _visual_elapsed_s := 0.0
var _visual_state := -1
var _visual_facing := -1.0
var _presentation_ready := false


func _ready() -> void:
	super._ready()
	_presentation_ready = true
	_update_presentation(0.0)


func _process(delta: float) -> void:
	super._process(delta)
	_update_presentation(delta * enemy_time_scale())


func receive_damage(event: DamageEvent) -> int:
	var result := super.receive_damage(event)
	_update_presentation(0.0)
	return result


func reset_target() -> void:
	super.reset_target()
	_update_visual()
	_update_phase_visual()
	_visual_elapsed_s = 0.0
	_visual_state = -1
	_visual_facing = -1.0
	_update_presentation(0.0)


func _update_presentation(delta: float) -> void:
	if not _presentation_ready:
		return
	if _visual_state != state:
		_visual_elapsed_s = 0.0
		_visual_state = state
	else:
		_visual_elapsed_s += maxf(0.0, delta)
	if state == State.CHARGING or (state == State.WARNING and current_pattern == Pattern.CHARGE):
		_visual_facing = _charge_direction
	elif state == State.IDLE or (state == State.WARNING and current_pattern == Pattern.SHOCKWAVE):
		var direction := signf(player.global_position.x - global_position.x)
		if not is_zero_approx(direction):
			_visual_facing = direction
	var stretch := Vector2.ONE
	var angle := 0.0
	var offset := Vector2.ZERO
	var tint := Color.WHITE
	var t := _state_elapsed_s
	match state:
		State.IDLE:
			var moving := absf(player.global_position.x - global_position.x) > 6.0 * PrototypePlayer.PIXELS_PER_METER
			var breath := sin(_visual_elapsed_s * (12.0 if moving else 3.0))
			stretch = Vector2(1.0 + breath * 0.018, 1.0 - breath * 0.025)
			angle = breath * 0.025 * _visual_facing if moving else 0.0
		State.WARNING:
			var charge := current_pattern == Pattern.CHARGE
			var duration := _charge_warning_duration() if charge else _shockwave_warning_duration()
			var progress := clampf(t / duration, 0.0, 1.0)
			stretch = Vector2(1.0 + progress * 0.14, 1.0 - progress * 0.20) if charge else Vector2(1.0 - progress * 0.06, 1.0 + progress * 0.10)
			angle = progress * (0.07 if charge else -0.10) * _visual_facing
		State.CHARGING:
			stretch = Vector2(1.12, 0.84 + sin(t * 32.0) * 0.025)
			angle = 0.045 * _visual_facing
		State.SHOCKWAVE:
			# The second stomp coincides with phase two's actual wave at 0.22s.
			var stomp_time := t - 0.22 if phase == 2 and t >= 0.22 else t
			var impact := maxf(0.0, 1.0 - stomp_time / 0.20)
			stretch = Vector2(1.0 + impact * 0.20, 1.0 - impact * 0.28)
		State.STUNNED:
			stretch = Vector2(1.08, 0.82)
			angle = (0.06 + sin(t * 9.0) * 0.035) * _visual_facing
		State.RECOVERY:
			var settle := maxf(0.0, 1.0 - t / 0.30)
			stretch = Vector2(1.0 + settle * 0.07, 1.0 - settle * 0.10)
		State.PHASE_TRANSITION:
			stretch = Vector2(1.04, 0.94)
			offset.x = sin(t * 42.0) * 2.0
		State.DEAD:
			var collapse := clampf(_visual_elapsed_s / 0.38, 0.0, 1.0)
			stretch = Vector2(1.0 + collapse * 0.16, 1.0 - collapse * 0.65)
			tint.a = lerpf(1.0, 0.25, collapse)
	if phase == 2 and state != State.DEAD:
		tint = Color(1.12, 0.88, 0.78)
	if _hit_flash_remaining_s > 0.0 and state != State.DEAD:
		tint = Color(1.65, 1.65, 1.65)
		stretch *= Vector2(1.05, 0.95)
	body_sprite.flip_h = _visual_facing < 0.0
	body_sprite.scale = BODY_SCALE * stretch
	body_sprite.rotation = angle
	body_sprite.self_modulate = tint
	# Squash and lean around the player's floor (actor-local y=60).
	body_sprite.position = Vector2(0.0, 60.0) - Vector2(0.0, FOOT_Y * body_sprite.scale.y).rotated(angle) + offset
	queue_redraw()


func _draw() -> void:
	if not _presentation_ready:
		return
	if state == State.STUNNED:
		for index in 3:
			var orbit := _visual_elapsed_s * 4.0 + index * TAU / 3.0
			var center := Vector2(_visual_facing * 61.0 + cos(orbit) * 25.0, -95.0 + sin(orbit) * 8.0)
			var points := PackedVector2Array()
			for tip in 8:
				points.append(center + Vector2(0.0, -7.0 if tip % 2 == 0 else -2.8).rotated(tip * TAU / 8.0))
			draw_colored_polygon(points, Color("ffe39b"))
	elif state == State.CHARGING:
		for index in 3:
			var trail := fmod(_visual_elapsed_s * 3.0 + index / 3.0, 1.0)
			var center := Vector2(-_visual_facing * (103.0 + trail * 43.0), 53.0 - trail * 12.0)
			draw_circle(center, 3.0 + trail * 7.0, Color(0.82, 0.70, 0.49, (1.0 - trail) * 0.55))
