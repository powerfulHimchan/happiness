class_name PrototypeEnemy
extends PrototypeTarget

## CP-301 일반 적 세 종류의 경고, 공격, 빈틈과 사망 상태를 관리한다.

enum EnemyType {
	LEAF_SLIME,
	SEED_SACK,
	WIND_SPIRIT,
}

enum State {
	IDLE,
	WARNING,
	ATTACK,
	RECOVERY,
	DEAD,
}

const SEED_PROJECTILE_SCENE := preload("res://scenes/combat/enemy_seed_projectile.tscn")
const SLIME_WARNING_S := 0.35
const SLIME_RECOVERY_S := 0.80
const SEED_WARNING_S := 1.00
const SEED_RECOVERY_S := 1.00
const WIND_WARNING_S := 0.60
const WIND_RECOVERY_S := 1.20
const SLIME_DAMAGE := 8
const SEED_DAMAGE := 7
const WIND_DAMAGE := 10
const CONTACT_RADIUS_PX := 68.0

@export_enum("풀잎 슬라임", "씨앗 포대", "바람 정령") var enemy_type: int = EnemyType.LEAF_SLIME
@export var player_path: NodePath

var state: int = State.IDLE
var attack_count: int = 0
var hit_count: int = 0
var warning_count: int = 0
var last_enemy_log: String = "행동 대기"
var last_event_msec: int = -1
var _state_elapsed_s: float = 0.0
var _attack_cooldown_s: float = 0.0
var _spawn_position: Vector2
var _velocity: Vector2 = Vector2.ZERO
var _attack_direction: Vector2 = Vector2.LEFT
var _attack_distance_px: float = 0.0
var _attack_hit_consumed: bool = false
var _patrol_direction: float = -1.0
var _projectile_sequence: int = 0

@onready var player: PrototypePlayer = get_node(player_path) as PrototypePlayer
@onready var warning_ring: Sprite2D = $WarningRing
@onready var warning_line: Line2D = $WarningLine


func _ready() -> void:
	super._ready()
	_spawn_position = position
	add_to_group("prototype_enemy")
	warning_ring.visible = false
	warning_line.visible = false
	_set_state(State.IDLE, "%s 등장" % enemy_name())


func _process(delta: float) -> void:
	super._process(delta)
	if not is_targetable():
		if state != State.DEAD:
			_set_state(State.DEAD, "%s 처치" % enemy_name())
		return
	var scaled_delta := delta * enemy_time_scale()
	_attack_cooldown_s = maxf(0.0, _attack_cooldown_s - scaled_delta)
	_state_elapsed_s += scaled_delta
	match enemy_type:
		EnemyType.LEAF_SLIME:
			_update_leaf_slime(scaled_delta)
		EnemyType.SEED_SACK:
			_update_seed_sack(scaled_delta)
		EnemyType.WIND_SPIRIT:
			_update_wind_spirit(scaled_delta)
	_update_warning_visual()


func receive_damage(event: DamageEvent) -> int:
	var result := super.receive_damage(event)
	if result != DamageReceiver.Result.APPLIED:
		return result
	if not is_targetable():
		_set_state(State.DEAD, "%s 처치" % enemy_name())
		return result
	if enemy_type == EnemyType.SEED_SACK and event.tags.has("sword"):
		var away_sign := signf(global_position.x - event.source_position.x)
		if is_zero_approx(away_sign):
			away_sign = 1.0
		global_position.x += away_sign * 70.0
		_attack_cooldown_s = maxf(_attack_cooldown_s, SEED_RECOVERY_S)
		_set_state(State.RECOVERY, "씨앗 포대 근접 피격 · 1초 사격 중단")
	return result


func reset_target() -> void:
	super.reset_target()
	state = State.IDLE
	attack_count = 0
	hit_count = 0
	warning_count = 0
	last_enemy_log = "행동 대기"
	last_event_msec = Time.get_ticks_msec()
	_state_elapsed_s = 0.0
	_attack_cooldown_s = 0.0
	_velocity = Vector2.ZERO
	_attack_distance_px = 0.0
	_attack_hit_consumed = false
	_patrol_direction = -1.0
	_projectile_sequence = 0
	if warning_ring != null:
		warning_ring.visible = false
	if warning_line != null:
		warning_line.visible = false


func current_metrics() -> Dictionary:
	return {
		"enemy_key": target_key,
		"enemy_name": enemy_name(),
		"enemy_type": enemy_type,
		"enemy_state": state_name(),
		"enemy_warning": state == State.WARNING,
		"enemy_alive": is_targetable(),
		"enemy_attack_count": attack_count,
		"enemy_hit_count": hit_count,
		"enemy_warning_count": warning_count,
		"enemy_last_log": last_enemy_log,
		"enemy_event_msec": last_event_msec,
	}


func enemy_name() -> String:
	match enemy_type:
		EnemyType.LEAF_SLIME:
			return "풀잎 슬라임"
		EnemyType.SEED_SACK:
			return "씨앗 포대"
		EnemyType.WIND_SPIRIT:
			return "바람 정령"
	return "일반 적"


func state_name() -> String:
	match state:
		State.IDLE:
			return "대기"
		State.WARNING:
			return "경고"
		State.ATTACK:
			return "공격"
		State.RECOVERY:
			return "빈틈"
		State.DEAD:
			return "처치"
	return "알 수 없음"


func _update_leaf_slime(delta: float) -> void:
	match state:
		State.IDLE:
			position.x += _patrol_direction * 70.0 * delta
			if absf(position.x - _spawn_position.x) >= 70.0:
				_patrol_direction *= -1.0
			if _attack_cooldown_s <= 0.0 and _distance_to_player_m() <= 3.0:
				_begin_warning("풀잎 슬라임 점프 경고 · 0.35초")
		State.WARNING:
			if _state_elapsed_s >= SLIME_WARNING_S:
				var direction_sign := signf(player.global_position.x - global_position.x)
				_attack_direction = Vector2(direction_sign if not is_zero_approx(direction_sign) else -1.0, 0.0)
				_velocity = Vector2(_attack_direction.x * 320.0, -650.0)
				_begin_attack("풀잎 슬라임 점프 공격")
		State.ATTACK:
			_velocity.y += 1900.0 * delta
			position += _velocity * delta
			_try_contact_damage(SLIME_DAMAGE, &"slime_jump")
			if position.y >= _spawn_position.y:
				position.y = _spawn_position.y
				_velocity = Vector2.ZERO
				_begin_recovery("풀잎 슬라임 착지 · 0.8초 빈틈")
		State.RECOVERY:
			if _state_elapsed_s >= SLIME_RECOVERY_S:
				_attack_cooldown_s = 0.35
				_set_state(State.IDLE, "풀잎 슬라임 이동 재개")


func _update_seed_sack(delta: float) -> void:
	match state:
		State.IDLE:
			var horizontal_distance_m := absf(player.global_position.x - global_position.x) / PrototypePlayer.PIXELS_PER_METER
			if horizontal_distance_m < 4.0:
				var away := signf(global_position.x - player.global_position.x)
				position.x += (away if not is_zero_approx(away) else 1.0) * 160.0 * delta
			elif horizontal_distance_m > 7.0:
				position.x += signf(player.global_position.x - global_position.x) * 120.0 * delta
			elif _attack_cooldown_s <= 0.0:
				_begin_warning("씨앗 포대 조준 경고 · 1.0초")
		State.WARNING:
			_update_aim_line(520.0, Color("ffd166"))
			if _state_elapsed_s >= SEED_WARNING_S:
				_fire_seed_volley()
				_begin_recovery("씨앗탄 3발 발사 · 반격 1.0초")
		State.RECOVERY:
			if _state_elapsed_s >= SEED_RECOVERY_S:
				_attack_cooldown_s = 1.25
				_set_state(State.IDLE, "씨앗 포대 거리 유지 재개")


func _update_wind_spirit(delta: float) -> void:
	match state:
		State.IDLE:
			var target_y := player.global_position.y - 165.0
			position.y = move_toward(position.y, target_y, 130.0 * delta)
			if absf(player.global_position.x - global_position.x) > 780.0:
				position.x += signf(player.global_position.x - global_position.x) * 145.0 * delta
			if _attack_cooldown_s <= 0.0 and _distance_to_player_m() <= 9.0:
				_attack_direction = (
					player.global_position + Vector2(0.0, -42.0) - global_position
				).normalized()
				_begin_warning("바람 정령 직선 경고 · 0.6초")
		State.WARNING:
			_update_fixed_warning_line(_attack_direction * 850.0, Color.WHITE)
			if _state_elapsed_s >= WIND_WARNING_S:
				_begin_attack("바람 정령 돌진")
		State.ATTACK:
			var displacement := _attack_direction * 900.0 * delta
			position += displacement
			_attack_distance_px += displacement.length()
			_try_contact_damage(WIND_DAMAGE, &"wind_dash")
			if _attack_distance_px >= 850.0 or position.x <= 100.0 or position.x >= 4900.0:
				_begin_recovery("바람 정령 빗나감 · 1.2초 빈틈")
		State.RECOVERY:
			if _state_elapsed_s >= WIND_RECOVERY_S:
				_attack_cooldown_s = 0.55
				_set_state(State.IDLE, "바람 정령 부유 재개")


func _begin_warning(message: String) -> void:
	warning_count += 1
	_set_state(State.WARNING, message)


func _begin_attack(message: String) -> void:
	attack_count += 1
	_attack_distance_px = 0.0
	_attack_hit_consumed = false
	_set_state(State.ATTACK, message)


func _begin_recovery(message: String) -> void:
	_set_state(State.RECOVERY, message)


func _set_state(new_state: int, message: String) -> void:
	state = new_state
	_state_elapsed_s = 0.0
	last_enemy_log = message
	last_event_msec = Time.get_ticks_msec()
	if warning_ring != null:
		warning_ring.visible = new_state == State.WARNING and enemy_type != EnemyType.WIND_SPIRIT
	if warning_line != null:
		warning_line.visible = new_state == State.WARNING


func _fire_seed_volley() -> void:
	attack_count += 1
	var origin := global_position + Vector2(0.0, -54.0)
	var base_direction := (player.global_position + Vector2(0.0, -42.0) - origin).normalized()
	for angle_degrees in [-12.0, 0.0, 12.0]:
		_projectile_sequence += 1
		var projectile := SEED_PROJECTILE_SCENE.instantiate() as EnemySeedProjectile
		projectile.configure(
			"seed_sack:%d:%d" % [attack_count, _projectile_sequence],
			base_direction.rotated(deg_to_rad(angle_degrees)),
			SEED_DAMAGE
		)
		var projectile_parent := get_tree().current_scene
		if projectile_parent == null:
			projectile_parent = get_tree().root
		projectile_parent.add_child(projectile)
		projectile.global_position = origin


func _try_contact_damage(amount: int, attack_id: StringName) -> void:
	if _attack_hit_consumed or player == null or not player.can_continue_combat_action():
		return
	if global_position.distance_to(player.global_position + Vector2(0.0, -38.0)) > CONTACT_RADIUS_PX:
		return
	_attack_hit_consumed = true
	var was_evading := player.invincible
	var event := DamageEvent.new()
	event.event_id = StringName("%s:%d:player" % [target_key, attack_count])
	event.attacker_id = StringName(target_key)
	event.attack_id = attack_id
	event.damage = amount
	event.stagger_s = 0.14
	event.tags = PackedStringArray(["enemy", "contact", enemy_name()])
	event.source_position = global_position
	var result := player.receive_damage(event)
	if result == DamageReceiver.Result.APPLIED:
		hit_count += 1
		last_enemy_log = "%s 적중 · 피해 %d" % [enemy_name(), amount]
	elif was_evading and result == DamageReceiver.Result.INVULNERABLE_BLOCKED:
		_register_precise_evade()
		last_enemy_log = "%s 정확한 회피" % enemy_name()


func _register_precise_evade() -> void:
	var ultimate := get_tree().get_first_node_in_group("ultimate_controller") as UltimateController
	if ultimate != null:
		ultimate.register_precise_evade()


func _distance_to_player_m() -> float:
	return global_position.distance_to(player.global_position) / PrototypePlayer.PIXELS_PER_METER


func _update_aim_line(length_px: float, color: Color) -> void:
	var direction := (player.global_position + Vector2(0.0, -42.0) - global_position).normalized()
	_update_fixed_warning_line(direction * length_px, color)


func _update_fixed_warning_line(endpoint: Vector2, color: Color) -> void:
	warning_line.default_color = color
	warning_line.points = PackedVector2Array([Vector2(0.0, -42.0), endpoint])


func _update_warning_visual() -> void:
	if state != State.WARNING:
		return
	var pulse := 0.58 + sin(_state_elapsed_s * 22.0) * 0.28
	if warning_ring.visible:
		warning_ring.modulate.a = pulse
	if warning_line.visible:
		warning_line.modulate.a = pulse
