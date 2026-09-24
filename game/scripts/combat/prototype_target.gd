class_name PrototypeTarget
extends Node2D

## CP-203 검 공격을 실제로 받는 전투 표적.
## 명시적 스프라이트를 유지하면서 HP, 피격 점멸과 사망을 표시한다.

signal defeated(target: PrototypeTarget)

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
var _hit_flash_remaining_s: float = 0.0
var last_damage_log: String = "피해 기록 대기"

@onready var body_sprite: Sprite2D = $BodySprite
@onready var selection_sprite: Sprite2D = $SelectionSprite
@onready var health_bar: ProgressBar = $HealthBar
@onready var status_label: Label = $StatusLabel
@onready var damage_receiver: DamageReceiver = $DamageReceiver


func _ready() -> void:
	_origin_position = position
	add_to_group("targetable")
	body_sprite.modulate = body_color
	selection_sprite.visible = _selected
	_refresh_status()


func _process(delta: float) -> void:
	damage_receiver.tick(delta)
	_hit_flash_remaining_s = maxf(0.0, _hit_flash_remaining_s - delta)
	_update_visual()
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


func receive_damage(event: DamageEvent) -> int:
	var result := damage_receiver.try_receive(event)
	last_damage_log = "%s · %s · HP %d/%d" % [
		DamageReceiver.result_name(result),
		String(event.event_id) if event != null else "ID 없음",
		damage_receiver.health,
		damage_receiver.max_health,
	]
	if result == DamageReceiver.Result.APPLIED:
		_hit_flash_remaining_s = 0.12
		if damage_receiver.dead:
			_targetable = false
			set_selected(false)
			defeated.emit(self)
	_refresh_status()
	return result


func health_summary() -> String:
	return "%s %d/%d" % [
		target_key,
		damage_receiver.health,
		damage_receiver.max_health,
	]


func reset_target() -> void:
	_elapsed_s = 0.0
	position = _origin_position
	_targetable = true
	damage_receiver.reset()
	_hit_flash_remaining_s = 0.0
	last_damage_log = "피해 기록 대기"
	set_selected(false)
	_refresh_status()


func _refresh_status() -> void:
	if damage_receiver == null or health_bar == null or status_label == null:
		return
	health_bar.max_value = damage_receiver.max_health
	health_bar.value = damage_receiver.health
	status_label.text = (
		"처치"
		if damage_receiver.dead
		else "%d/%d" % [damage_receiver.health, damage_receiver.max_health]
	)


func _update_visual() -> void:
	if damage_receiver.dead:
		body_sprite.modulate = Color("52636d")
	elif _hit_flash_remaining_s > 0.0:
		body_sprite.modulate = Color.WHITE
	else:
		body_sprite.modulate = body_color
