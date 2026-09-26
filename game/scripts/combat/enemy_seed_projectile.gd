class_name EnemySeedProjectile
extends Node2D

## 씨앗 포대가 발사하는 적 투사체. 새벽의 틈 시간 감속 대상이다.

const HIT_RADIUS_PX := 48.0

var projectile_id: String = ""
var direction: Vector2 = Vector2.LEFT
var damage: int = 7
var speed_px_s: float = 550.0
var max_distance_px: float = 900.0
var enemy_time_scale: float = 1.0
var _travelled_px: float = 0.0

@onready var projectile_sprite: Sprite2D = $ProjectileSprite


func configure(
	new_projectile_id: String,
	new_direction: Vector2,
	new_damage: int = 7,
	new_speed_mps: float = 5.5,
	new_max_distance_m: float = 9.0
) -> void:
	projectile_id = new_projectile_id
	direction = new_direction.normalized() if new_direction.length_squared() > 0.001 else Vector2.LEFT
	damage = new_damage
	speed_px_s = new_speed_mps * PrototypePlayer.PIXELS_PER_METER
	max_distance_px = new_max_distance_m * PrototypePlayer.PIXELS_PER_METER


func _ready() -> void:
	add_to_group("enemy_time_scaled")
	add_to_group("enemy_projectile")
	rotation = direction.angle()
	_update_visual()


func _physics_process(delta: float) -> void:
	var previous_position := global_position
	var displacement := direction * speed_px_s * enemy_time_scale * delta
	global_position += displacement
	_travelled_px += displacement.length()
	if _try_hit_player(previous_position, global_position):
		queue_free()
		return
	if _travelled_px >= max_distance_px or not _is_near_screen():
		queue_free()


func set_enemy_time_scale(value: float) -> void:
	enemy_time_scale = clampf(value, 0.0, 1.0)
	_update_visual()


func _try_hit_player(segment_start: Vector2, segment_end: Vector2) -> bool:
	var player := get_tree().get_first_node_in_group("prototype_player") as PrototypePlayer
	if player == null or not player.can_continue_combat_action():
		return false
	var hit_point := player.global_position + Vector2(0.0, -42.0)
	if _distance_to_segment(hit_point, segment_start, segment_end) > HIT_RADIUS_PX:
		return false
	var was_evading := player.invincible
	var event := DamageEvent.new()
	event.event_id = StringName("%s:player" % projectile_id)
	event.attacker_id = &"seed_sack"
	event.attack_id = &"seed_volley"
	event.damage = damage
	event.stagger_s = 0.10
	event.tags = PackedStringArray(["enemy", "projectile", "seed"])
	event.source_position = segment_start
	var result := player.receive_damage(event)
	if was_evading and result == DamageReceiver.Result.INVULNERABLE_BLOCKED:
		_register_precise_evade()
	return true


func _register_precise_evade() -> void:
	var ultimate := get_tree().get_first_node_in_group("ultimate_controller") as UltimateController
	if ultimate != null:
		ultimate.register_precise_evade()


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	if segment.length_squared() <= 0.001:
		return point.distance_to(start)
	var ratio := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * ratio)


func _is_near_screen() -> bool:
	var screen_position := get_global_transform_with_canvas() * Vector2.ZERO
	return Rect2(Vector2.ZERO, get_viewport_rect().size).grow(180.0).has_point(screen_position)


func _update_visual() -> void:
	if projectile_sprite != null:
		projectile_sprite.modulate = Color("b8e8ff") if enemy_time_scale < 1.0 else Color.WHITE
