class_name EliteShockwave
extends Node2D

## 갑옷 멧돼지의 지면 충격파. 새벽의 틈 시간 감속 대상이다.

const HIT_RADIUS_PX := 54.0

var wave_id: String = ""
var direction_sign: float = -1.0
var damage: int = 12
var speed_px_s: float = 650.0
var max_distance_px: float = 1050.0
var enemy_time_scale: float = 1.0
var _travelled_px: float = 0.0

@onready var wave_sprite: Sprite2D = $WaveSprite


func configure(
	new_wave_id: String,
	new_direction_sign: float,
	new_damage: int,
	new_speed_mps: float = 6.5
) -> void:
	wave_id = new_wave_id
	direction_sign = signf(new_direction_sign)
	if is_zero_approx(direction_sign):
		direction_sign = -1.0
	damage = new_damage
	speed_px_s = new_speed_mps * PrototypePlayer.PIXELS_PER_METER


func _ready() -> void:
	add_to_group("enemy_time_scaled")
	add_to_group("enemy_projectile")
	wave_sprite.flip_h = direction_sign < 0.0
	_update_visual()


func _physics_process(delta: float) -> void:
	var previous_position := global_position
	var displacement := Vector2(direction_sign * speed_px_s * enemy_time_scale * delta, 0.0)
	global_position += displacement
	_travelled_px += displacement.length()
	if _try_hit_player(previous_position, global_position):
		queue_free()
		return
	if _travelled_px >= max_distance_px or global_position.x <= 80.0 or global_position.x >= 4920.0:
		queue_free()


func set_enemy_time_scale(value: float) -> void:
	enemy_time_scale = clampf(value, 0.0, 1.0)
	_update_visual()


func _try_hit_player(segment_start: Vector2, segment_end: Vector2) -> bool:
	var player := get_tree().get_first_node_in_group("prototype_player") as PrototypePlayer
	if player == null or not player.can_continue_combat_action():
		return false
	var hit_point := player.global_position + Vector2(0.0, -20.0)
	if _distance_to_segment(hit_point, segment_start, segment_end) > HIT_RADIUS_PX:
		return false
	var was_evading := player.invincible
	var event := DamageEvent.new()
	event.event_id = StringName("%s:player" % wave_id)
	event.attacker_id = &"armored_boar"
	event.attack_id = &"boar_shockwave"
	event.damage = damage
	event.stagger_s = 0.18
	event.tags = PackedStringArray(["enemy", "projectile", "shockwave"])
	event.source_position = segment_start
	var result := player.receive_damage(event)
	if was_evading and result == DamageReceiver.Result.INVULNERABLE_BLOCKED:
		var ultimate := get_tree().get_first_node_in_group("ultimate_controller") as UltimateController
		if ultimate != null:
			ultimate.register_precise_evade()
	return true


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	if segment.length_squared() <= 0.001:
		return point.distance_to(start)
	var ratio := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * ratio)


func _update_visual() -> void:
	if wave_sprite != null:
		wave_sprite.modulate = Color("b8e8ff") if enemy_time_scale < 1.0 else Color.WHITE
