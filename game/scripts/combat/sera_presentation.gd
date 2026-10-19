extends BossSera

## Sera-only art and effects. BossSera continues to own every combat event.
const BODY_SCALE := Vector2.ONE
const FOOT_Y := 84.0
var _effects: Node2D
var _presentation_ready := false
var _visual_state := -1
var _visual_elapsed_s := 0.0
var _visual_facing := -1.0
var _ring_elapsed_s := -1.0
var _ring_rotation := 0.0


func _ready() -> void:
	super._ready()
	_effects = Node2D.new()
	_effects.name = "SeraEffects"
	_effects.z_index = 1
	add_child(_effects)
	_effects.draw.connect(_draw_effects)
	_presentation_ready = true
	_update_presentation(0.0)


func _process(delta: float) -> void:
	if enemy_time_scale() <= 0.0: return
	var visual_delta := delta * enemy_time_scale()
	# Advance before combat so an actual shot starts its flash at zero even
	# when a long frame crosses the end of the warning or delayed second ring.
	if _ring_elapsed_s >= 0.0: _ring_elapsed_s += visual_delta
	super._process(delta)
	_update_presentation(visual_delta)


func _set_state(new_state: int, message: String) -> void:
	super._set_state(new_state, message)
	if new_state in [State.DEAD, State.PHASE_TRANSITION]: _ring_elapsed_s = -1.0
	_update_presentation(0.0)


func _fire_ring(rotation_offset: float) -> void:
	super._fire_ring(rotation_offset)
	_ring_elapsed_s = 0.0
	_ring_rotation = rotation_offset
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
	_ring_elapsed_s = -1.0
	_ring_rotation = 0.0
	_update_presentation(0.0)


func _update_presentation(delta: float) -> void:
	if not _presentation_ready: return
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
	var offset_x := 0.0
	var tint := Color.WHITE
	var t := _state_elapsed_s
	match state:
		State.IDLE:
			var sway := sin(_visual_elapsed_s * 2.6)
			stretch = Vector2(1.0 + sway * 0.009, 1.0 - sway * 0.012)
			angle = sway * 0.012
		State.WARNING:
			var duration := _charge_warning_duration() if current_pattern == Pattern.CHARGE else _shockwave_warning_duration() if current_pattern == Pattern.SHOCKWAVE else 0.80 if phase == 2 else 1.10
			var progress := clampf(t / duration, 0.0, 1.0)
			if current_pattern == Pattern.CHARGE:
				stretch = Vector2(1.0 + progress * 0.04, 1.0 - progress * 0.08)
				angle = 0.12 * progress * _visual_facing
			else:
				stretch = Vector2(1.0 - progress * 0.025, 1.0 + progress * 0.045)
				angle = -0.035 * progress * _visual_facing
		State.CHARGING:
			stretch = Vector2(1.04, 0.94)
			angle = 0.15 * _visual_facing
		State.SHOCKWAVE:
			var impact_time := t - 0.22 if phase == 2 and t >= 0.22 else t
			var impact := maxf(0.0, 1.0 - impact_time / 0.20)
			stretch = Vector2(1.0 + impact * 0.08, 1.0 - impact * 0.15)
		State.STUNNED:
			stretch = Vector2(1.035, 0.90)
			angle = sin(t * 9.0) * 0.04
		State.RECOVERY:
			var recoil := maxf(0.0, 1.0 - _ring_elapsed_s / 0.24) if _ring_elapsed_s >= 0.0 else 0.0
			stretch = Vector2(1.0 - recoil * 0.04, 1.0 + recoil * 0.035)
			angle = -0.08 * recoil * _visual_facing
		State.PHASE_TRANSITION:
			offset_x = sin(t * 34.0) * 1.8
			stretch = Vector2(1.02, 0.98)
		State.DEAD:
			var collapse := clampf(_visual_elapsed_s / 0.50, 0.0, 1.0)
			stretch = Vector2(1.0 + collapse * 0.08, 1.0 - collapse * 0.55)
			angle = -0.12 * collapse * _visual_facing
			tint.a = lerpf(1.0, 0.25, collapse)
	if _hit_flash_remaining_s > 0.0 and state != State.DEAD:
		tint = Color(1.6, 1.6, 1.6)
		stretch *= Vector2(1.02, 0.98)
	body_sprite.flip_h = _visual_facing > 0.0
	body_sprite.scale = BODY_SCALE * stretch
	body_sprite.rotation = angle
	body_sprite.self_modulate = tint
	var mirror := -_visual_facing
	var left_sole := (Vector2(-21.0 * mirror, FOOT_Y) * body_sprite.scale).rotated(angle)
	var right_sole := (Vector2(22.0 * mirror, FOOT_Y) * body_sprite.scale).rotated(angle)
	body_sprite.position = Vector2(offset_x, 60.0) - Vector2(0.0, FOOT_Y * body_sprite.scale.y).rotated(angle)
	body_sprite.position.y = 60.0 - maxf(left_sole.y, right_sole.y)
	queue_redraw()
	_effects.queue_redraw()


func _draw() -> void:
	if not _presentation_ready or state != State.CHARGING: return
	for index in 3:
		var trail := fmod(_visual_elapsed_s * 3.0 + index / 3.0, 1.0)
		var center := Vector2(-_visual_facing * (48.0 + trail * 42.0), 48.0 - trail * 12.0)
		draw_circle(center, 2.0 + trail * 4.0, Color(0.75, 0.9, 0.84, (1.0 - trail) * 0.5))


func _draw_effects() -> void:
	if state == State.DEAD: return
	var crown := body_sprite.transform * Vector2(0.0, -70.0)
	if state == State.RECOVERY:
		# Broken brackets mark the same crown opening for either weapon.
		var pulse := 0.65 + sin(_visual_elapsed_s * 8.0) * 0.15
		for side in [-1.0, 1.0]:
			var corner := crown + Vector2(side * 36.0, -12.0)
			for end in [corner + Vector2(side * 8.0, 0), corner + Vector2(0, 14.0)]:
				_effects.draw_line(corner, end, Color(0.16, 0.25, 0.29, pulse), 4.5, true)
				_effects.draw_line(corner, end, Color(1, 0.90, 0.60, pulse), 2.5, true)
	if state == State.PHASE_TRANSITION:
		for index in 5:
			var direction := Vector2.UP.rotated((index - 2) * 0.48)
			var drift := fmod(_visual_elapsed_s * 1.8 + index * 0.17, 1.0)
			_effects.draw_circle(crown + direction * (15.0 + drift * 24.0), 2.2, Color(0.7, 1.0, 0.92, 1.0 - drift))
	if state == State.RECOVERY and _ring_elapsed_s >= 0.0 and _ring_elapsed_s < 0.18:
		var progress := _ring_elapsed_s / 0.18
		for index in 8:
			var direction := Vector2.RIGHT.rotated(index * TAU / 8.0 + _ring_rotation)
			_effects.draw_line(Vector2(0, -56) + direction * (12 + progress * 20), Vector2(0, -56) + direction * (24 + progress * 28), Color(1, 0.89, 0.56, 1.0 - progress), 2.5, true)
