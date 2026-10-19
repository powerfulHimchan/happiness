extends BossClockworkKnight

## Knight-only art. Gameplay, telegraphs and projectile origins belong to the base.
const BODY_SCALE := Vector2(1.20, 1.20)
const FOOT_Y := 68.0
var _presentation_ready := false
var _visual_elapsed_s := 0.0
var _visual_state := -1
var _visual_facing := -1.0
var _volley_elapsed_s := -1.0
var _volley_flash: Node2D


func _ready() -> void:
	super._ready()
	_volley_flash = Node2D.new()
	_volley_flash.name = "VolleyFlash"
	_volley_flash.z_index = 1
	add_child(_volley_flash)
	_volley_flash.draw.connect(_draw_volley_flash)
	_presentation_ready = true
	_update_presentation(0.0)


func _process(delta: float) -> void:
	var visual_delta := delta * enemy_time_scale()
	if _volley_elapsed_s >= 0.0:
		_volley_elapsed_s += visual_delta
	super._process(delta)
	_update_presentation(visual_delta)


func _fire_volley() -> void:
	super._fire_volley()
	# Recoil starts on the actual shot, including frames longer than its duration.
	_volley_elapsed_s = 0.0


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
	_volley_elapsed_s = -1.0
	_update_presentation(0.0)


func _update_presentation(delta: float) -> void:
	if not _presentation_ready:
		return
	if _visual_state != state:
		_visual_state = state
		_visual_elapsed_s = 0.0
	else:
		_visual_elapsed_s += maxf(0.0, delta)
	if state == State.CHARGING or state == State.WARNING:
		_visual_facing = _charge_direction
	elif state == State.IDLE:
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
			var rhythm := sin(_visual_elapsed_s * (11.0 if moving else 2.6))
			stretch = Vector2(1.0 + rhythm * 0.012, 1.0 - rhythm * 0.018)
			angle = rhythm * 0.025 * _visual_facing if moving else 0.0
		State.WARNING:
			if current_pattern == Pattern.CHARGE:
				var progress := clampf(t / _charge_warning_duration(), 0.0, 1.0)
				stretch = Vector2(1.0 + progress * 0.07, 1.0 - progress * 0.12)
				angle = progress * 0.13 * _visual_facing
			elif current_pattern == Pattern.SHOCKWAVE:
				var progress := clampf(t / _shockwave_warning_duration(), 0.0, 1.0)
				stretch = Vector2(1.0 - progress * 0.04, 1.0 + progress * 0.06)
				angle = -0.055 * progress * _visual_facing
			else:
				var progress := clampf(t / (0.75 if phase == 2 else 1.0), 0.0, 1.0)
				stretch = Vector2(1.0 + progress * 0.035, 1.0 - progress * 0.035)
				angle = -0.06 * progress * _visual_facing
		State.CHARGING:
			stretch = Vector2(1.06, 0.91 + sin(t * 30.0) * 0.018)
			angle = 0.16 * _visual_facing
		State.SHOCKWAVE:
			var stomp_time := t - 0.22 if phase == 2 and t >= 0.22 else t
			var impact := maxf(0.0, 1.0 - stomp_time / 0.20)
			stretch = Vector2(1.0 + impact * 0.12, 1.0 - impact * 0.20)
		State.STUNNED:
			stretch = Vector2(1.04, 0.88)
			angle = (-0.10 + sin(t * 8.0) * 0.045) * _visual_facing
		State.RECOVERY:
			var recoil := maxf(0.0, 1.0 - _volley_elapsed_s / 0.26) if _volley_elapsed_s >= 0.0 else 0.0
			stretch = Vector2(1.0 - recoil * 0.06, 1.0 + recoil * 0.025)
			angle = -0.12 * recoil * _visual_facing
		State.PHASE_TRANSITION:
			stretch = Vector2(1.025, 0.97)
			offset.x = sin(t * 38.0) * 1.7
		State.DEAD:
			var collapse := clampf(_visual_elapsed_s / 0.45, 0.0, 1.0)
			stretch = Vector2(1.0 + collapse * 0.12, 1.0 - collapse * 0.60)
			angle = -0.18 * collapse * _visual_facing
			tint.a = lerpf(1.0, 0.25, collapse)
	if phase == 2 and state != State.DEAD:
		tint = Color(1.12, 0.89, 0.74)
	if _hit_flash_remaining_s > 0.0 and state != State.DEAD:
		tint = Color(1.65, 1.65, 1.65)
		stretch *= Vector2(1.035, 0.965)
	body_sprite.flip_h = _visual_facing < 0.0
	body_sprite.scale = BODY_SCALE * stretch
	body_sprite.rotation = angle
	body_sprite.self_modulate = tint
	# Pivot around the feet, then rest the lower sole on the shared arena floor.
	# Checking both edges keeps a leaning boot from sinking into the platform.
	body_sprite.position = Vector2(0.0, 60.0) - Vector2(0.0, FOOT_Y * body_sprite.scale.y).rotated(angle) + offset
	var left_sole := (Vector2(-47.0 * _visual_facing, FOOT_Y) * body_sprite.scale).rotated(angle)
	var right_sole := (Vector2(52.0 * _visual_facing, FOOT_Y) * body_sprite.scale).rotated(angle)
	body_sprite.position.y = 60.0 - maxf(left_sole.y, right_sole.y)
	queue_redraw()
	_volley_flash.queue_redraw()


func _draw() -> void:
	if not _presentation_ready or state == State.DEAD:
		return
	if state == State.STUNNED:
		for index in 3:
			var orbit := _visual_elapsed_s * 4.0 + index * TAU / 3.0
			var center := Vector2(cos(orbit) * 33.0, -113.0 + sin(orbit) * 8.0)
			var points := PackedVector2Array()
			for tip in 8:
				points.append(center + Vector2(0, -6.0 if tip % 2 == 0 else -2.5).rotated(tip * TAU / 8.0))
			draw_colored_polygon(points, Color("ffe39b"))
	elif state == State.CHARGING:
		for index in 3:
			var trail := fmod(_visual_elapsed_s * 3.2 + index / 3.0, 1.0)
			var center := Vector2(-_visual_facing * (70.0 + trail * 44.0), 55.0 - trail * 9.0)
			draw_circle(center, 3.0 + trail * 6.0, Color(0.84, 0.73, 0.53, (1.0 - trail) * 0.5))


func _draw_volley_flash() -> void:
	if state == State.RECOVERY and _volley_elapsed_s >= 0.0 and _volley_elapsed_s < 0.18:
		var progress := _volley_elapsed_s / 0.18
		# A small flash at the real projectile origin, with no hit area.
		var center := Vector2(0.0, -48.0)
		for index in 5:
			var ray := _volley_aim.rotated((index - 2) * 0.20)
			_volley_flash.draw_line(center + ray * (12.0 + progress * 18.0), center + ray * (26.0 + progress * 27.0), Color(1.0, 0.87, 0.50, 1.0 - progress), 3.0, true)
