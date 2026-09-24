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

@onready var body_sprite: Sprite2D = $BodySprite
@onready var selection_sprite: Sprite2D = $SelectionSprite


func _ready() -> void:
	_origin_position = position
	add_to_group("targetable")
	body_sprite.modulate = body_color
	selection_sprite.visible = _selected


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
	selection_sprite.visible = selected


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
