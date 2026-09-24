class_name PrototypePlayer
extends CharacterBody2D

## CP-103 지상 이동과 가변 점프 모델.
## 100 px를 1 m로 환산해 기획 수치를 물리 좌표에 적용한다.

signal movement_metrics_changed(metrics: Dictionary)

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
const INPUT_DEAD_ZONE := 0.18
const STOP_EPSILON_MPS := 0.02

var move_input: float = 0.0
var facing_direction: int = 1
var stop_test_passed: bool = false
var reversal_test_passed: bool = false
var last_stop_time_s: float = 0.0
var last_stop_distance_m: float = 0.0
var jump_held: bool = false
var jump_count: int = 0
var last_jump_height_m: float = 0.0
var last_jump_assist: String = "대기"
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

@onready var avatar_sprite: Sprite2D = $Avatar/Sprite2D


func _ready() -> void:
	_last_position_x = global_position.x
	_emit_metrics()


func _physics_process(delta: float) -> void:
	var grounded_at_start := is_on_floor()
	_update_jump_windows(delta, grounded_at_start)
	_try_execute_jump(grounded_at_start)

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

	if not grounded_at_start or velocity.y < 0.0:
		velocity.y += GRAVITY_MPS2 * PIXELS_PER_METER * delta
	else:
		velocity.y = minf(velocity.y, 0.0)

	move_and_slide()
	_update_jump_metrics(grounded_at_start)
	_update_movement_tests(delta)
	_emit_metrics()


func set_move_vector(input_vector: Vector2) -> void:
	var raw_axis := clampf(input_vector.x, -1.0, 1.0)
	var new_input := _apply_dead_zone(raw_axis)
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
	jump_held = true
	_jump_buffer_remaining_s = JUMP_BUFFER_S
	_jump_requested_airborne = not is_on_floor()


func release_jump() -> void:
	jump_held = false
	if velocity.y < 0.0:
		velocity.y *= JUMP_RELEASE_VELOCITY_MULTIPLIER


func reset_movement_test(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	move_input = 0.0
	facing_direction = 1
	avatar_sprite.flip_h = false
	jump_held = false
	jump_count = 0
	last_jump_height_m = 0.0
	last_jump_assist = "대기"
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
	_emit_metrics()


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


func _direction_sign(value: float) -> int:
	return int(signf(value))


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
	})
