extends BossHappinessHeart

## Floating machine shell and independent heart; the base owns combat.
const CORE_TEXTURE := preload("res://assets/happiness_heart_core.svg")
const BODY_SCALE := Vector2(0.80, 0.80)
var core_sprite: Sprite2D
var _effects: Node2D
var _presentation_ready := false
var _visual_state := -1
var _visual_elapsed_s := 0.0
var _shot_elapsed_s := -1.0
var _shot_pattern := 0

func _ready() -> void:
	super._ready()
	core_sprite = Sprite2D.new()
	core_sprite.name = "HeartCore"
	core_sprite.texture = CORE_TEXTURE
	core_sprite.z_index = 1
	add_child(core_sprite)
	_effects = Node2D.new()
	_effects.name = "HeartEffects"
	_effects.z_index = 1
	add_child(_effects)
	_effects.draw.connect(_draw_effects)
	_presentation_ready = true
	_update_presentation(0)

func _process(delta: float) -> void:
	if enemy_time_scale() <= 0: return
	var visual_delta := delta * enemy_time_scale()
	if _shot_elapsed_s >= 0: _shot_elapsed_s += visual_delta
	super._process(delta)
	_update_presentation(visual_delta)

func _set_state(new_state: int, message: String) -> void:
	super._set_state(new_state, message)
	if new_state in [State.DEAD, State.PHASE_TRANSITION]: _shot_elapsed_s = -1
	_update_presentation(0)

func _fire_needles() -> void:
	super._fire_needles()
	_shot_elapsed_s = 0
	_shot_pattern = NEEDLES
	_update_presentation(0)

func _fire_beam() -> void:
	super._fire_beam()
	_shot_elapsed_s = 0
	_shot_pattern = BEAM
	_update_presentation(0)

func receive_damage(event: DamageEvent) -> int:
	var result := super.receive_damage(event)
	_update_presentation(0)
	return result

func reset_target() -> void:
	super.reset_target()
	_update_visual()
	_update_phase_visual()
	_visual_state = -1
	_visual_elapsed_s = 0
	_shot_elapsed_s = -1
	_shot_pattern = 0
	_update_presentation(0)

func _update_presentation(delta: float) -> void:
	if not _presentation_ready: return
	if _visual_state != state:
		_visual_state = state
		_visual_elapsed_s = 0
	else: _visual_elapsed_s += maxf(0,delta)
	var t := _state_elapsed_s
	var stretch := Vector2.ONE
	var core_pulse := 1.0 + sin(_visual_elapsed_s * (7.0 if phase == 2 else 3.5)) * 0.035
	var angle := 0.0
	var offset := Vector2(0, sin(_visual_elapsed_s * 2.5) * 3.0)
	var tint := Color.WHITE
	match state:
		State.WARNING:
			var progress := clampf(t / (0.72 if phase == 2 else 1.05),0,1)
			core_pulse += progress * 0.12
			if current_pattern == Pattern.SHOCKWAVE:
				stretch = Vector2(1.0 - progress * 0.035,1.0 + progress * 0.06)
			elif current_pattern == NEEDLES: angle = sin(t * 18) * 0.025 * progress
		State.SHOCKWAVE:
			var impact_time := t - 0.22 if phase == 2 and t >= 0.22 else t
			var impact := maxf(0,1.0 - impact_time / 0.20)
			stretch = Vector2(1.0 + impact * 0.10,1.0 - impact * 0.12)
			offset.y += impact * 8.0
		State.RECOVERY:
			core_pulse += 0.15
			var recoil := maxf(0,1.0 - _shot_elapsed_s / 0.25) if _shot_elapsed_s >= 0 else 0.0
			stretch = Vector2(1.0 + recoil * 0.035,1.0 - recoil * 0.045)
			offset -= _aim * recoil * 5.0 if _shot_pattern == NEEDLES else Vector2.ZERO
		State.PHASE_TRANSITION:
			offset.x = sin(t * 37) * 2.0
			core_pulse += 0.12
		State.DEAD:
			var collapse := clampf(_visual_elapsed_s / 0.5,0,1)
			angle = collapse * 0.12
			offset.y = collapse * 22.0
			stretch = Vector2.ONE * (1.0 - collapse * 0.15)
			tint.a = lerpf(1,0.25,collapse)
	if _hit_flash_remaining_s > 0 and state != State.DEAD: tint = Color(1.6,1.6,1.6)
	body_sprite.flip_h = false
	body_sprite.scale = BODY_SCALE * stretch
	body_sprite.rotation = angle
	# The machine hovers; the core remains near the actual projectile origin.
	body_sprite.position = Vector2(0,-53.6) + offset
	body_sprite.self_modulate = tint
	core_sprite.position = body_sprite.transform * Vector2(0,-3)
	core_sprite.scale = body_sprite.scale * core_pulse
	core_sprite.rotation = angle
	core_sprite.modulate = body_sprite.modulate
	core_sprite.self_modulate = tint
	queue_redraw()
	_effects.queue_redraw()

func _draw() -> void:
	super._draw() # Keep the existing beam line and its exact 0.15s duration.
	if not _presentation_ready or state == State.DEAD: return
	draw_set_transform(Vector2(0,58),0,Vector2(1,0.16))
	draw_circle(Vector2.ZERO,63,Color(0.10,0.23,0.28,0.18))
	draw_set_transform(Vector2.ZERO)

func _draw_effects() -> void:
	if state == State.DEAD: return
	var center := core_sprite.position
	if state == State.RECOVERY:
		var alpha := 0.65 + sin(_visual_elapsed_s * 8) * 0.15
		for start in [0.2,PI + 0.2]:
			_effects.draw_arc(center,47,start,start + PI - 0.4,22,Color(1,0.91,0.64,alpha),2.5,true)
	if state == State.PHASE_TRANSITION:
		for i in 6:
			var direction := Vector2.RIGHT.rotated(i * TAU / 6 + _visual_elapsed_s)
			_effects.draw_line(center + direction * 43,center + direction * 58,Color("ffd49b"),2,true)
	if state == State.RECOVERY and _shot_elapsed_s >= 0 and _shot_elapsed_s < 0.18:
		var progress := _shot_elapsed_s / 0.18
		if _shot_pattern == NEEDLES:
			for i in range(-2,3) if phase == 2 else range(-1,2):
				var ray := _aim.rotated(i * 0.24)
				_effects.draw_line(Vector2(0,-56) + ray * (16 + progress * 14),Vector2(0,-56) + ray * (32 + progress * 26),Color(1,0.89,0.60,1-progress),2.5,true)
		elif _shot_pattern == BEAM:
			_effects.draw_circle(center,22 + progress * 28,Color(1,0.84,0.59,(1-progress)*0.23))
