class_name PrototypePlayer
extends CharacterBody2D

## CP-105 이동 액션과 낙하 복귀 모델.
## 100 px를 1 m로 환산해 기획 수치를 물리 좌표에 적용한다.

signal movement_metrics_changed(metrics: Dictionary)
signal fall_recovery_started

enum MobilityAction {
	NONE,
	GROUND_EVADE,
	AIR_DASH,
}

const PIXELS_PER_METER := 100.0
const MAX_SPEED_MPS := 5.5
const ACCELERATION_MPS2 := 40.0
const DECELERATION_MPS2 := 45.0
const TURN_ACCELERATION_MPS2 := 60.0
const GRAVITY_MPS2 := 28.0
const MAX_JUMP_HEIGHT_M := 2.2
const JUMP_SPEED_MPS := 11.1
const JUMP_RELEASE_VELOCITY_MULTIPLIER := 0.48
const COYOTE_TIME_S := 0.10
const JUMP_BUFFER_S := 0.12
const GROUND_EVADE_SPEED_MPS := 9.0
const GROUND_EVADE_DURATION_S := 0.24
const GROUND_EVADE_INVINCIBLE_S := 0.18
const GROUND_EVADE_COOLDOWN_S := 0.45
const AIR_DASH_SPEED_MPS := 9.5
const AIR_DASH_DURATION_S := 0.18
const MAX_HEALTH := 100
const FALL_DAMAGE_RATIO := 0.10
const FALL_BOUNDARY_Y := 1160.0
const FALL_RECOVERY_DELAY_S := 0.45
const RESPAWN_INPUT_LOCK_S := 0.20
const INPUT_DEAD_ZONE := 0.18
const STOP_EPSILON_MPS := 0.02

var move_input: float = 0.0
var move_input_vector: Vector2 = Vector2.ZERO
var facing_direction: int = 1
var stop_test_passed: bool = false
var reversal_test_passed: bool = false
var last_stop_time_s: float = 0.0
var last_stop_distance_m: float = 0.0
var jump_held: bool = false
var jump_count: int = 0
var last_jump_height_m: float = 0.0
var last_jump_assist: String = "대기"
var invincible: bool = false
var air_dash_available: bool = true
var ground_evade_count: int = 0
var air_dash_count: int = 0
var last_mobility_result: String = "대기"
var last_invincibility_log: String = "무적 로그 대기"
var health: int = MAX_HEALTH
var fall_count: int = 0
var last_fall_damage: int = 0
var last_fall_log: String = "낙하 기록 대기"
var last_safe_position: Vector2 = Vector2(960.0, 780.0)
var last_safe_label: String = "시작 지점"
var _stop_test_active: bool = false
var _stop_elapsed_s: float = 0.0
var _stop_distance_px: float = 0.0
var _last_input_sign: int = 0
var _reversal_test_active: bool = false
var _reversal_target_sign: int = 0
var _last_position_x: float = 0.0
var _coyote_remaining_s: float = 0.0
var _jump_buffer_remaining_s: float = 0.0
var _jump_requested_airborne: bool = false
var _jump_in_progress: bool = false
var _jump_start_y: float = 0.0
var _jump_peak_height_m: float = 0.0
var _mobility_action: int = MobilityAction.NONE
var _mobility_direction: Vector2 = Vector2.RIGHT
var _mobility_remaining_s: float = 0.0
var _invincible_remaining_s: float = 0.0
var _evade_cooldown_remaining_s: float = 0.0
var _invincibility_start_frame: int = -1
var _invincibility_end_frame: int = -1
var _fall_recovery_active: bool = false
var _fall_recovery_remaining_s: float = 0.0
var _input_lock_remaining_s: float = 0.0

@onready var avatar: Node2D = $Avatar
@onready var avatar_sprite: Sprite2D = $Avatar/Sprite2D


func _ready() -> void:
	_last_position_x = global_position.x
	_emit_metrics()


func _physics_process(delta: float) -> void:
	if _fall_recovery_active:
		_update_fall_recovery(delta)
		_update_avatar_action_visual()
		_emit_metrics()
		return

	_input_lock_remaining_s = maxf(0.0, _input_lock_remaining_s - delta)
	if global_position.y >= FALL_BOUNDARY_Y:
		_begin_fall_recovery()
		_emit_metrics()
		return

	var grounded_at_start := is_on_floor()
	_update_mobility_timers(delta)
	if grounded_at_start:
		air_dash_available = true
	_update_jump_windows(delta, grounded_at_start)

	if _mobility_action == MobilityAction.NONE:
		_try_execute_jump(grounded_at_start)
		_apply_standard_movement(delta, grounded_at_start)
	else:
		_apply_mobility_velocity()

	move_and_slide()
	if global_position.y >= FALL_BOUNDARY_Y:
		_begin_fall_recovery()
		_emit_metrics()
		return
	if not grounded_at_start and is_on_floor():
		air_dash_available = true
		if _mobility_action == MobilityAction.AIR_DASH:
			_finish_mobility_action()
	_update_jump_metrics(grounded_at_start)
	_update_movement_tests(delta)
	_update_avatar_action_visual()
	_emit_metrics()


func set_move_vector(input_vector: Vector2) -> void:
	if _is_input_locked():
		move_input = 0.0
		move_input_vector = Vector2.ZERO
		return
	move_input_vector = _apply_vector_dead_zone(input_vector.limit_length(1.0))
	var new_input := move_input_vector.x
	var new_sign := _direction_sign(new_input)

	if new_sign != 0:
		if _last_input_sign != 0 and new_sign != _last_input_sign \
			and _direction_sign(velocity.x) == _last_input_sign:
			_reversal_test_active = true
			_reversal_target_sign = new_sign
		if facing_direction != new_sign:
			facing_direction = new_sign
			avatar_sprite.flip_h = facing_direction < 0
		_last_input_sign = new_sign

	if absf(new_input) <= 0.001 and absf(move_input) > 0.001 \
		and absf(velocity.x) >= PIXELS_PER_METER:
		_stop_test_active = true
		_stop_elapsed_s = 0.0
		_stop_distance_px = 0.0
	elif absf(new_input) > 0.001:
		_stop_test_active = false

	move_input = new_input


func request_jump() -> void:
	if _is_input_locked():
		return
	jump_held = true
	_jump_buffer_remaining_s = JUMP_BUFFER_S
	_jump_requested_airborne = not is_on_floor()


func release_jump() -> void:
	jump_held = false
	if velocity.y < 0.0:
		velocity.y *= JUMP_RELEASE_VELOCITY_MULTIPLIER


func request_evade() -> void:
	if _is_input_locked():
		last_mobility_result = "복귀 중 입력 잠금"
		return
	if _mobility_action != MobilityAction.NONE:
		last_mobility_result = "동작 중 입력 무시"
		return

	if is_on_floor():
		if _evade_cooldown_remaining_s > 0.0:
			last_mobility_result = "지상 회피 재사용 대기"
			return
		_start_ground_evade()
		return

	if not air_dash_available:
		last_mobility_result = "공중 대시 사용 완료"
		return
	_start_air_dash()


func set_safe_spawn(spawn_position: Vector2, safe_label: String) -> void:
	if _fall_recovery_active or spawn_position.y >= FALL_BOUNDARY_Y:
		return
	last_safe_position = spawn_position
	last_safe_label = safe_label


func reset_movement_test(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	move_input = 0.0
	move_input_vector = Vector2.ZERO
	facing_direction = 1
	avatar_sprite.flip_h = false
	jump_held = false
	jump_count = 0
	last_jump_height_m = 0.0
	last_jump_assist = "대기"
	invincible = false
	air_dash_available = true
	ground_evade_count = 0
	air_dash_count = 0
	last_mobility_result = "대기"
	last_invincibility_log = "무적 로그 대기"
	health = MAX_HEALTH
	fall_count = 0
	last_fall_damage = 0
	last_fall_log = "낙하 기록 대기"
	last_safe_position = spawn_position
	last_safe_label = "시작 지점"
	stop_test_passed = false
	reversal_test_passed = false
	last_stop_time_s = 0.0
	last_stop_distance_m = 0.0
	_stop_test_active = false
	_stop_elapsed_s = 0.0
	_stop_distance_px = 0.0
	_last_input_sign = 0
	_reversal_test_active = false
	_reversal_target_sign = 0
	_last_position_x = global_position.x
	_coyote_remaining_s = 0.0
	_jump_buffer_remaining_s = 0.0
	_jump_requested_airborne = false
	_jump_in_progress = false
	_jump_start_y = global_position.y
	_jump_peak_height_m = 0.0
	_mobility_action = MobilityAction.NONE
	_mobility_direction = Vector2.RIGHT
	_mobility_remaining_s = 0.0
	_invincible_remaining_s = 0.0
	_evade_cooldown_remaining_s = 0.0
	_invincibility_start_frame = -1
	_invincibility_end_frame = -1
	_fall_recovery_active = false
	_fall_recovery_remaining_s = 0.0
	_input_lock_remaining_s = 0.0
	avatar.visible = true
	avatar_sprite.modulate = Color.WHITE
	_emit_metrics()


func _apply_standard_movement(delta: float, grounded: bool) -> void:
	var target_speed_px := move_input * MAX_SPEED_MPS * PIXELS_PER_METER
	var rate_mps2 := _movement_rate_mps2(target_speed_px)
	velocity.x = move_toward(
		velocity.x,
		target_speed_px,
		rate_mps2 * PIXELS_PER_METER * delta
	)

	if absf(move_input) <= 0.001 \
		and absf(velocity.x) < STOP_EPSILON_MPS * PIXELS_PER_METER:
		velocity.x = 0.0

	if not grounded or velocity.y < 0.0:
		velocity.y += GRAVITY_MPS2 * PIXELS_PER_METER * delta
	else:
		velocity.y = minf(velocity.y, 0.0)


func _movement_rate_mps2(target_speed_px: float) -> float:
	if absf(move_input) <= 0.001:
		return DECELERATION_MPS2
	if absf(velocity.x) > STOP_EPSILON_MPS * PIXELS_PER_METER \
		and _direction_sign(velocity.x) != _direction_sign(target_speed_px):
		return TURN_ACCELERATION_MPS2
	return ACCELERATION_MPS2


func _apply_dead_zone(axis: float) -> float:
	var magnitude := absf(axis)
	if magnitude <= INPUT_DEAD_ZONE:
		return 0.0
	var normalized := (magnitude - INPUT_DEAD_ZONE) / (1.0 - INPUT_DEAD_ZONE)
	return signf(axis) * clampf(normalized, 0.0, 1.0)


func _apply_vector_dead_zone(input_vector: Vector2) -> Vector2:
	var magnitude := input_vector.length()
	if magnitude <= INPUT_DEAD_ZONE:
		return Vector2.ZERO
	var normalized_magnitude := (magnitude - INPUT_DEAD_ZONE) / (1.0 - INPUT_DEAD_ZONE)
	return input_vector.normalized() * clampf(normalized_magnitude, 0.0, 1.0)


func _direction_sign(value: float) -> int:
	return int(signf(value))


func _start_ground_evade() -> void:
	var direction := _direction_sign(move_input)
	if direction == 0:
		direction = facing_direction
	facing_direction = direction
	avatar_sprite.flip_h = facing_direction < 0
	_mobility_action = MobilityAction.GROUND_EVADE
	_mobility_direction = Vector2(float(direction), 0.0)
	_mobility_remaining_s = GROUND_EVADE_DURATION_S
	_evade_cooldown_remaining_s = GROUND_EVADE_COOLDOWN_S
	ground_evade_count += 1
	last_mobility_result = "지상 회피"
	_begin_invincibility()


func _start_air_dash() -> void:
	var direction := move_input_vector
	if direction.length_squared() <= 0.001:
		direction = Vector2(float(facing_direction), 0.0)
	else:
		direction = direction.normalized()
	if absf(direction.x) > 0.05:
		facing_direction = _direction_sign(direction.x)
		avatar_sprite.flip_h = facing_direction < 0
	_mobility_action = MobilityAction.AIR_DASH
	_mobility_direction = direction
	_mobility_remaining_s = AIR_DASH_DURATION_S
	air_dash_available = false
	air_dash_count += 1
	last_mobility_result = "공중 대시"


func _apply_mobility_velocity() -> void:
	var speed_mps: float = AIR_DASH_SPEED_MPS
	if _mobility_action == MobilityAction.GROUND_EVADE:
		speed_mps = GROUND_EVADE_SPEED_MPS
	velocity = _mobility_direction * speed_mps * PIXELS_PER_METER


func _update_mobility_timers(delta: float) -> void:
	_evade_cooldown_remaining_s = maxf(0.0, _evade_cooldown_remaining_s - delta)
	if _mobility_remaining_s > 0.0:
		_mobility_remaining_s = maxf(0.0, _mobility_remaining_s - delta)
		if _mobility_remaining_s <= 0.0:
			_finish_mobility_action()

	if _invincible_remaining_s > 0.0:
		_invincible_remaining_s = maxf(0.0, _invincible_remaining_s - delta)
		if _invincible_remaining_s <= 0.0:
			_end_invincibility()


func _finish_mobility_action() -> void:
	if _mobility_action == MobilityAction.AIR_DASH:
		velocity.y = 0.0
	_mobility_action = MobilityAction.NONE
	_mobility_remaining_s = 0.0


func _begin_invincibility() -> void:
	invincible = true
	_invincible_remaining_s = GROUND_EVADE_INVINCIBLE_S
	_invincibility_start_frame = int(Engine.get_physics_frames())
	last_invincibility_log = "무적 시작 F%d" % _invincibility_start_frame


func _end_invincibility() -> void:
	invincible = false
	_invincibility_end_frame = int(Engine.get_physics_frames())
	last_invincibility_log = "무적 종료 F%d · %d프레임" % [
		_invincibility_end_frame,
		maxi(0, _invincibility_end_frame - _invincibility_start_frame),
	]


func _update_avatar_action_visual() -> void:
	if _input_lock_remaining_s > 0.0:
		avatar_sprite.modulate = Color("ff9f8f")
	elif invincible:
		avatar_sprite.modulate = Color("76f4ff")
	elif _mobility_action == MobilityAction.AIR_DASH:
		avatar_sprite.modulate = Color("ffd166")
	else:
		avatar_sprite.modulate = Color.WHITE


func _mobility_action_name() -> String:
	match _mobility_action:
		MobilityAction.GROUND_EVADE:
			return "지상 회피"
		MobilityAction.AIR_DASH:
			return "공중 대시"
	return "일반"


func _begin_fall_recovery() -> void:
	if _fall_recovery_active:
		return
	fall_count += 1
	last_fall_damage = int(round(MAX_HEALTH * FALL_DAMAGE_RATIO))
	health = maxi(1, health - last_fall_damage)
	last_fall_log = "낙하 %d회 · HP -%d" % [fall_count, last_fall_damage]
	_fall_recovery_active = true
	_fall_recovery_remaining_s = FALL_RECOVERY_DELAY_S
	_input_lock_remaining_s = FALL_RECOVERY_DELAY_S + RESPAWN_INPUT_LOCK_S
	_cancel_actions_for_recovery()
	velocity = Vector2.ZERO
	avatar.visible = false
	fall_recovery_started.emit()


func _update_fall_recovery(delta: float) -> void:
	_fall_recovery_remaining_s = maxf(0.0, _fall_recovery_remaining_s - delta)
	_input_lock_remaining_s = maxf(0.0, _input_lock_remaining_s - delta)
	if _fall_recovery_remaining_s > 0.0:
		return
	global_position = last_safe_position
	velocity = Vector2.ZERO
	_last_position_x = global_position.x
	_fall_recovery_active = false
	air_dash_available = true
	avatar.visible = true
	last_fall_log = "복귀 %s · HP %d/%d" % [last_safe_label, health, MAX_HEALTH]


func _cancel_actions_for_recovery() -> void:
	move_input = 0.0
	move_input_vector = Vector2.ZERO
	jump_held = false
	_jump_buffer_remaining_s = 0.0
	_jump_requested_airborne = false
	_jump_in_progress = false
	_mobility_action = MobilityAction.NONE
	_mobility_remaining_s = 0.0
	_invincible_remaining_s = 0.0
	invincible = false


func _is_input_locked() -> bool:
	return _fall_recovery_active or _input_lock_remaining_s > 0.0


func _recovery_state_name() -> String:
	if _fall_recovery_active:
		return "복귀 대기"
	if _input_lock_remaining_s > 0.0:
		return "입력 잠금"
	return "정상"


func _update_jump_windows(delta: float, grounded: bool) -> void:
	if grounded:
		_coyote_remaining_s = COYOTE_TIME_S
	else:
		_coyote_remaining_s = maxf(0.0, _coyote_remaining_s - delta)
	_jump_buffer_remaining_s = maxf(0.0, _jump_buffer_remaining_s - delta)


func _try_execute_jump(grounded: bool) -> void:
	if _jump_buffer_remaining_s <= 0.0 or _coyote_remaining_s <= 0.0:
		return

	if _jump_requested_airborne and grounded:
		last_jump_assist = "착지 버퍼"
	elif not grounded:
		last_jump_assist = "코요테"
	else:
		last_jump_assist = "일반"

	var launch_multiplier := 1.0 if jump_held else JUMP_RELEASE_VELOCITY_MULTIPLIER
	velocity.y = -JUMP_SPEED_MPS * PIXELS_PER_METER * launch_multiplier
	jump_count += 1
	_jump_in_progress = true
	_jump_start_y = global_position.y
	_jump_peak_height_m = 0.0
	_jump_buffer_remaining_s = 0.0
	_coyote_remaining_s = 0.0
	_jump_requested_airborne = false


func _update_jump_metrics(grounded_before_move: bool) -> void:
	if _jump_in_progress and not is_on_floor():
		_jump_peak_height_m = maxf(
			_jump_peak_height_m,
			(_jump_start_y - global_position.y) / PIXELS_PER_METER
		)
	if _jump_in_progress and not grounded_before_move and is_on_floor():
		last_jump_height_m = _jump_peak_height_m
		_jump_in_progress = false


func _jump_state_name() -> String:
	if is_on_floor():
		return "지상"
	if velocity.y < 0.0:
		return "상승"
	return "하강"


func _update_movement_tests(delta: float) -> void:
	var moved_px := absf(global_position.x - _last_position_x)
	_last_position_x = global_position.x

	if _stop_test_active:
		_stop_elapsed_s += delta
		_stop_distance_px += moved_px
		if is_zero_approx(velocity.x):
			_stop_test_active = false
			stop_test_passed = true
			last_stop_time_s = _stop_elapsed_s
			last_stop_distance_m = _stop_distance_px / PIXELS_PER_METER

	if _reversal_test_active and _direction_sign(velocity.x) == _reversal_target_sign:
		_reversal_test_active = false
		reversal_test_passed = true


func _emit_metrics() -> void:
	movement_metrics_changed.emit({
		"speed_mps": velocity.x / PIXELS_PER_METER,
		"target_speed_mps": move_input * MAX_SPEED_MPS,
		"input_axis": move_input,
		"facing": facing_direction,
		"position_m": global_position.x / PIXELS_PER_METER,
		"stop_passed": stop_test_passed,
		"reversal_passed": reversal_test_passed,
		"stop_time_s": last_stop_time_s,
		"stop_distance_m": last_stop_distance_m,
		"jump_state": _jump_state_name(),
		"jump_held": jump_held,
		"jump_count": jump_count,
		"jump_height_m": _jump_peak_height_m if _jump_in_progress else last_jump_height_m,
		"last_jump_height_m": last_jump_height_m,
		"last_jump_assist": last_jump_assist,
		"coyote_remaining_s": _coyote_remaining_s,
		"jump_buffer_remaining_s": _jump_buffer_remaining_s,
		"mobility_action": _mobility_action_name(),
		"invincible": invincible,
		"invincible_remaining_s": _invincible_remaining_s,
		"evade_cooldown_remaining_s": _evade_cooldown_remaining_s,
		"air_dash_available": air_dash_available,
		"ground_evade_count": ground_evade_count,
		"air_dash_count": air_dash_count,
		"last_mobility_result": last_mobility_result,
		"last_invincibility_log": last_invincibility_log,
		"invincibility_start_frame": _invincibility_start_frame,
		"invincibility_end_frame": _invincibility_end_frame,
		"health": health,
		"max_health": MAX_HEALTH,
		"fall_count": fall_count,
		"last_fall_damage": last_fall_damage,
		"last_fall_log": last_fall_log,
		"last_safe_position": last_safe_position,
		"last_safe_label": last_safe_label,
		"recovery_state": _recovery_state_name(),
		"input_locked": _is_input_locked(),
		"fall_recovery_remaining_s": _fall_recovery_remaining_s,
	})
