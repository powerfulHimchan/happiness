class_name EnemyVisualAnimation
extends RefCounted

## Presentation only: transform the body, never the actor or its warning/health UI.
const BODY_SCALE := [1.65, 1.40, 1.0]
const FOOT_Y := [43.0, 54.0, 0.0]
var elapsed_s := 0.0
var shot_remaining_s := 0.0
var last_state := -1
var _position := Vector2.ZERO
var _scale := Vector2.ONE
var _rotation := 0.0
var _flip := false
var _color := Color.WHITE

func bind(sprite: Sprite2D) -> void:
	_position = sprite.position
	_scale = sprite.scale
	_rotation = sprite.rotation
	_flip = sprite.flip_h
	_color = sprite.self_modulate

func reset(sprite: Sprite2D) -> void:
	elapsed_s = 0.0
	shot_remaining_s = 0.0
	last_state = -1
	_restore(sprite)

func shot() -> void:
	shot_remaining_s = 0.18

func _restore(sprite: Sprite2D) -> void:
	sprite.position = _position
	sprite.scale = _scale
	sprite.rotation = _rotation
	sprite.flip_h = _flip
	sprite.self_modulate = _color

func animate(sprite: Sprite2D, kind: int, state: int, delta: float, facing: int,
		moving: bool, hit: bool, enabled: bool, warning_progress: float) -> void:
	_restore(sprite)
	if not enabled:
		elapsed_s = 0.0
		shot_remaining_s = 0.0
		last_state = -1
		return
	if state != last_state:
		elapsed_s = 0.0
		last_state = state
	elapsed_s += maxf(delta, 0.0)
	shot_remaining_s = maxf(0.0, shot_remaining_s - maxf(delta, 0.0))
	var stretch := Vector2.ONE
	var offset := Vector2.ZERO
	var angle := 0.0
	var alpha := 1.0
	# PrototypeEnemy.State: idle, warning, attack, recovery, dead.
	match state:
		0:
			var wave := sin(elapsed_s * (11.0 if moving else 3.0))
			if kind == 0:
				stretch = Vector2(1.0 + wave * 0.055, 1.0 - wave * 0.055)
			elif kind == 1:
				angle = wave * (0.065 if moving else 0.015)
				offset.y = -absf(wave) * (3.0 if moving else 0.5)
			else:
				offset.y = sin(elapsed_s * 3.0) * 4.0
				angle = wave * 0.035
		1:
			var charge := clampf(warning_progress, 0.0, 1.0)
			if kind == 0:
				stretch = Vector2(1.0 + charge * 0.22, 1.0 - charge * 0.25)
			elif kind == 1:
				stretch = Vector2(1.0 + charge * 0.12, 1.0 - charge * 0.08)
				angle = -0.06 * charge * facing
			else:
				stretch = Vector2(1.0 - charge * 0.12, 1.0 + charge * 0.08)
				offset.x = -5.0 * charge * facing
		2:
			stretch = Vector2(0.86, 1.16) if kind == 0 else Vector2(1.20, 0.82)
			angle = 0.10 * facing if kind == 0 else 0.0
		3:
			var settle := maxf(0.0, 1.0 - elapsed_s / 0.28)
			stretch = Vector2(1.0 + settle * 0.18, 1.0 - settle * 0.18)
		4:
			var collapse := clampf(elapsed_s / 0.32, 0.0, 1.0)
			stretch = Vector2(1.0 + collapse * 0.18, 1.0 - collapse * 0.60)
			alpha = lerpf(1.0, 0.28, collapse)
			if kind == 2: offset.y = collapse * 16.0
	# A volley goes directly from warning to recovery; only an actual shot recoils.
	if shot_remaining_s > 0.0 and state != 4:
		var recoil := shot_remaining_s / 0.18
		stretch = Vector2(1.0 - recoil * 0.14, 1.0 + recoil * 0.10)
		offset.x = -7.0 * recoil * facing
	if hit and state != 4:
		stretch = Vector2(1.12, 0.88)
		angle = -0.08 * facing
		sprite.self_modulate = Color(1.65, 1.65, 1.65, 1.0)
	else:
		sprite.self_modulate = Color(_color, alpha)
	sprite.flip_h = facing < 0
	var rest_scale := _scale * float(BODY_SCALE[kind])
	sprite.scale = rest_scale * stretch
	sprite.rotation = _rotation + angle
	# Keep the ground pivot fixed while compressing or leaning. Wind floats freely.
	var foot := Vector2(0, float(FOOT_Y[kind]) * rest_scale.y)
	var pivot_offset := foot - Vector2(0, foot.y * stretch.y).rotated(angle) if kind != 2 else Vector2.ZERO
	var rest_position := Vector2(_position.x, 60.0 - foot.y) if kind != 2 else _position
	sprite.position = rest_position + pivot_offset + offset
