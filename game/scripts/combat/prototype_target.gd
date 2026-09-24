class_name PrototypeTarget
extends Node2D

## CP-201 자동 공격 대상 선택을 검증하기 위한 가벼운 표적.
## 충돌 물리는 아직 넣지 않고, 가장 가까운 피격점과 선택 표시만 제공한다.

@export var target_key: String = "target"
@export var body_color: Color = Color("79c96b")
@export var patrol_amplitude_px: float = 0.0
@export var patrol_period_s: float = 0.0
@export var patrol_phase_radians: float = 0.0

const BODY_CENTER := Vector2(0.0, -38.0)
const HIT_RADIUS_PX := 32.0

var _origin_position: Vector2
var _elapsed_s: float = 0.0
var _selected: bool = false
var _targetable: bool = true


func _ready() -> void:
	_origin_position = position
	add_to_group("targetable")
	queue_redraw()


func _process(delta: float) -> void:
	if patrol_amplitude_px <= 0.0 or patrol_period_s <= 0.0:
		return
	_elapsed_s += delta
	var phase := (_elapsed_s / patrol_period_s) * TAU + patrol_phase_radians
	position.x = _origin_position.x + sin(phase) * patrol_amplitude_px


func set_selected(selected: bool) -> void:
	if _selected == selected:
		return
	_selected = selected
	queue_redraw()


func is_targetable() -> bool:
	return _targetable and is_visible_in_tree()


func closest_hit_point(from_global: Vector2) -> Vector2:
	var center := global_position + BODY_CENTER
	var toward_center := center - from_global
	if toward_center.length_squared() <= 0.001:
		return center
	return center - toward_center.normalized() * HIT_RADIUS_PX


func reset_target() -> void:
	_elapsed_s = 0.0
	position = _origin_position
	_targetable = true
	set_selected(false)


func _draw() -> void:
	# 밝은 캐주얼 판타지 톤의 절차형 풀잎 슬라임 표적.
	draw_ellipse(Vector2(0.0, -3.0), Vector2(42.0, 11.0), Color("3f6f66"), 28)
	if _selected:
		draw_arc(BODY_CENTER, 43.0, 0.0, TAU, 48, Color.WHITE, 7.0, true)
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-11.0, -105.0),
				Vector2(11.0, -105.0),
				Vector2(0.0, -88.0),
			]),
			Color.WHITE
		)
		draw_arc(Vector2(0.0, -102.0), 15.0, 0.0, TAU, 24, Color("ffd166"), 4.0, true)

	draw_circle(BODY_CENTER, 38.0, body_color)
	draw_arc(BODY_CENTER, 38.0, 0.0, TAU, 40, body_color.lightened(0.24), 4.0, true)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-11.0, -73.0),
			Vector2(-2.0, -101.0),
			Vector2(9.0, -72.0),
		]),
		Color("70b85f")
	)
	draw_circle(Vector2(-13.0, -42.0), 5.5, Color("173147"))
	draw_circle(Vector2(13.0, -42.0), 5.5, Color("173147"))
	draw_arc(Vector2(0.0, -29.0), 11.0, 0.18, PI - 0.18, 16, Color("315b4c"), 3.0, true)


func draw_ellipse(center: Vector2, radii: Vector2, color: Color, segments: int) -> void:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
