class_name TrainingEnemyProjectile
extends Node2D

## CP-206에서 적 투사체만 시간 감속되는지 확인하는 반복 훈련탄이다.

signal precise_evade_registered

const HIT_RADIUS_PX := 54.0

@export var player_path: NodePath
@export var speed_mps: float = 3.0
@export var damage: int = 12
@export var loop_left_x: float = 520.0
@export var loop_right_x: float = 2450.0

var enemy_time_scale: float = 1.0
var _spawn_position: Vector2
var _event_sequence: int = 0

@onready var player: PrototypePlayer = get_node(player_path) as PrototypePlayer
@onready var projectile_sprite: Sprite2D = $ProjectileSprite


func _ready() -> void:
	_spawn_position = global_position
	add_to_group("enemy_time_scaled")
	add_to_group("enemy_projectile")
	_update_visual()


func _physics_process(delta: float) -> void:
	var previous_position := global_position
	global_position.x += speed_mps * PrototypePlayer.PIXELS_PER_METER * enemy_time_scale * delta
	if _crossed_player(previous_position, global_position):
		_resolve_player_contact()
	if global_position.x >= loop_right_x:
		global_position.x = loop_left_x


func set_enemy_time_scale(value: float) -> void:
	enemy_time_scale = clampf(value, 0.0, 1.0)
	_update_visual()


func reset_projectile() -> void:
	global_position = _spawn_position
	enemy_time_scale = 1.0
	_event_sequence = 0
	_update_visual()


func _crossed_player(segment_start: Vector2, segment_end: Vector2) -> bool:
	if player == null or not player.can_continue_combat_action():
		return false
	var hit_point := player.global_position + Vector2(0.0, -42.0)
	return _distance_to_segment(hit_point, segment_start, segment_end) <= HIT_RADIUS_PX


func _resolve_player_contact() -> void:
	_event_sequence += 1
	var was_evading := player.invincible
	var event := DamageEvent.new()
	event.event_id = StringName("training_projectile:%d" % _event_sequence)
	event.attacker_id = &"training_projectile"
	event.attack_id = &"dawn_gap_speed_test"
	event.damage = damage
	event.stagger_s = 0.12
	event.tags = PackedStringArray(["enemy", "projectile", "training"])
	event.source_position = global_position
	var result := player.receive_damage(event)
	if was_evading and result == DamageReceiver.Result.INVULNERABLE_BLOCKED:
		precise_evade_registered.emit()
	global_position.x = loop_left_x


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	if segment.length_squared() <= 0.001:
		return point.distance_to(start)
	var ratio := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * ratio)


func _update_visual() -> void:
	if projectile_sprite == null:
		return
	projectile_sprite.modulate = Color("9bd7ff") if enemy_time_scale < 1.0 else Color.WHITE
