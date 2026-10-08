class_name BowProjectile
extends Node2D

## 활 기본 사격과 관통 화살이 공유하는 수동 충돌 투사체다.

signal hit_registered(
	target: PrototypeTarget,
	damage: int,
	result: int,
	projectile_id: String
)

const HIT_RADIUS_PX := 44.0
const HOMING_TURN_RATE_RAD_S := PI
const HOMING_DURATION_S := 1.0

var damage_handler: Callable
var projectile_id: String = ""
var attack_id: StringName = &""
var damage: int = 0
var speed_px_s: float = 0.0
var max_distance_px: float = 0.0
var max_hits: int = 1
var direction: Vector2 = Vector2.RIGHT
var tags: PackedStringArray = PackedStringArray()
var _travelled_px: float = 0.0
var _hit_target_keys: Dictionary = {}
var _hit_count: int = 0
var _tracking_target: WeakRef
var _tracking_generation: int = -1
var _tracking_remaining_s: float = 0.0

@onready var arrow_sprite: Sprite2D = $ArrowSprite


func configure(
	new_projectile_id: String,
	new_attack_id: StringName,
	new_damage: int,
	new_speed_mps: float,
	new_max_distance_m: float,
	new_max_hits: int,
	new_direction: Vector2,
	new_tags: PackedStringArray
) -> void:
	projectile_id = new_projectile_id
	attack_id = new_attack_id
	damage = new_damage
	speed_px_s = new_speed_mps * PrototypePlayer.PIXELS_PER_METER
	max_distance_px = new_max_distance_m * PrototypePlayer.PIXELS_PER_METER
	max_hits = maxi(1, new_max_hits)
	direction = new_direction.normalized() if new_direction.length_squared() > 0.001 else Vector2.RIGHT
	tags = new_tags


func _ready() -> void:
	add_to_group("bow_projectile")
	rotation = direction.angle()
	if attack_id == &"bow_homing": arrow_sprite.modulate = Color("65e6ae")


func set_tracking_target(target: PrototypeTarget) -> void:
	if not is_instance_valid(target): return
	_tracking_target = weakref(target)
	_tracking_generation = target.spawn_generation
	_tracking_remaining_s = HOMING_DURATION_S


func _steer(delta: float) -> void:
	if _tracking_target == null: return
	var target := _tracking_target.get_ref() as PrototypeTarget
	if not is_instance_valid(target) or target.is_queued_for_deletion() \
	or target.spawn_generation != _tracking_generation or not target.is_targetable() \
	or target.damage_receiver.dead or not Rect2(Vector2.ZERO, get_viewport_rect().size).grow(-20.0).has_point(target.get_global_transform_with_canvas() * Vector2.ZERO):
		_tracking_target = null
		_tracking_remaining_s = 0.0
		return
	var offset := target.global_position + PrototypeTarget.BODY_CENTER - global_position
	var tracking_delta := minf(maxf(0.0, delta), _tracking_remaining_s)
	if offset.length_squared() > 0.001:
		var turn := wrapf(offset.angle() - direction.angle(), -PI, PI)
		direction = direction.rotated(clampf(turn, -HOMING_TURN_RATE_RAD_S * tracking_delta, HOMING_TURN_RATE_RAD_S * tracking_delta)).normalized()
		rotation = direction.angle()
	_tracking_remaining_s = maxf(0.0, _tracking_remaining_s - tracking_delta)
	if _tracking_remaining_s <= 0.0: _tracking_target = null


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	_steer(delta)
	var previous_position := global_position
	var displacement := direction * minf(maxf(0.0, delta) * speed_px_s, maxf(0.0, max_distance_px - _travelled_px))
	global_position += displacement
	_travelled_px += displacement.length()
	_check_hits(previous_position, global_position)
	if _hit_count >= max_hits or _travelled_px >= max_distance_px or not _is_near_screen():
		queue_free()


func _check_hits(segment_start: Vector2, segment_end: Vector2) -> void:
	if _hit_count >= max_hits or is_queued_for_deletion():
		return
	for node in get_tree().get_nodes_in_group("targetable"):
		var target := node as PrototypeTarget
		if target == null or not target.is_targetable():
			continue
		if _hit_target_keys.has(target.target_key):
			continue
		var target_point := target.global_position + Vector2(0.0, -38.0)
		if _distance_to_segment(target_point, segment_start, segment_end) > HIT_RADIUS_PX:
			continue
		_hit_target_keys[target.target_key] = true
		var event := DamageEvent.new()
		event.event_id = StringName("%s:%s" % [projectile_id, target.target_key])
		event.attacker_id = &"player"
		event.attack_id = attack_id
		event.damage = damage
		event.stagger_s = 0.08
		event.tags = tags
		event.source_position = segment_start
		var result: int = damage_handler.call(target, event) if damage_handler.is_valid() else target.receive_damage(event)
		if result == DamageReceiver.Result.APPLIED:
			_hit_count += 1
		hit_registered.emit(target, damage, result, projectile_id)
		if _hit_count >= max_hits:
			return


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	if segment.length_squared() <= 0.001:
		return point.distance_to(start)
	var ratio := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * ratio)


func _is_near_screen() -> bool:
	var screen_position := get_global_transform_with_canvas() * Vector2.ZERO
	return Rect2(Vector2.ZERO, get_viewport_rect().size).grow(140.0).has_point(screen_position)
