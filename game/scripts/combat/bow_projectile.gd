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


func _physics_process(delta: float) -> void:
	var previous_position := global_position
	var displacement := direction * speed_px_s * delta
	global_position += displacement
	_travelled_px += displacement.length()
	_check_hits(previous_position, global_position)
	if _hit_count >= max_hits or _travelled_px >= max_distance_px or not _is_near_screen():
		queue_free()


func _check_hits(segment_start: Vector2, segment_end: Vector2) -> void:
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
		var result := target.receive_damage(event)
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
