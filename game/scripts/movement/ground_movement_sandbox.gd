extends Node2D

## CP-201 이동 트랙 위 자동 공격 대상 탐색과 표시 검증을 담당한다.

const TRACK_START := Vector2(960.0, 780.0)
const TRACK_LEFT := 100.0
const TRACK_RIGHT := 4900.0
const FLOOR_TOP := 840.0
const PRACTICE_PLATFORM_RECT := Rect2(1675.0, 660.0, 650.0, 40.0)
const LEFT_FLOOR_RECT := Rect2(0.0, FLOOR_TOP, 3300.0, 300.0)
const RIGHT_FLOOR_RECT := Rect2(3800.0, FLOOR_TOP, 1200.0, 300.0)
const FALL_ZONE_RECT := Rect2(3300.0, FLOOR_TOP, 500.0, 360.0)
const PRACTICE_SAFE_SPAWN := Vector2(2000.0, 600.0)
const RIGHT_SAFE_SPAWN := Vector2(4300.0, 780.0)

@onready var player: PrototypePlayer = $Player
@onready var target_selector: AutoTargetSelector = $Player/AutoTargetSelector
@onready var controls: Control = $CanvasLayer/GroundMovementControls


func _ready() -> void:
	controls.move_vector_changed.connect(player.set_move_vector)
	controls.jump_pressed.connect(player.request_jump)
	controls.jump_released.connect(player.release_jump)
	controls.evade_pressed.connect(player.request_evade)
	controls.reset_requested.connect(_reset_test)
	player.fall_recovery_started.connect(controls.release_all_inputs)
	player.movement_metrics_changed.connect(controls.update_movement_metrics)
	target_selector.target_metrics_changed.connect(controls.update_target_metrics)
	$LeftSafeZone.body_entered.connect(
		_on_safe_zone_entered.bind(TRACK_START, "시작 평지")
	)
	$PracticeSafeZone.body_entered.connect(
		_on_safe_zone_entered.bind(PRACTICE_SAFE_SPAWN, "연습 발판")
	)
	$RightSafeZone.body_entered.connect(
		_on_safe_zone_entered.bind(RIGHT_SAFE_SPAWN, "오른쪽 평지")
	)
	player.set_safe_spawn(TRACK_START, "시작 평지")
	controls.update_movement_metrics({
		"speed_mps": 0.0,
		"target_speed_mps": 0.0,
		"input_axis": 0.0,
		"facing": 1,
		"position_m": TRACK_START.x / PrototypePlayer.PIXELS_PER_METER,
		"stop_passed": false,
		"reversal_passed": false,
		"stop_time_s": 0.0,
		"stop_distance_m": 0.0,
		"jump_state": "지상",
		"jump_held": false,
		"jump_count": 0,
		"jump_height_m": 0.0,
		"last_jump_height_m": 0.0,
		"last_jump_assist": "대기",
		"coyote_remaining_s": 0.0,
		"jump_buffer_remaining_s": 0.0,
		"mobility_action": "일반",
		"invincible": false,
		"invincible_remaining_s": 0.0,
		"evade_cooldown_remaining_s": 0.0,
		"air_dash_available": true,
		"ground_evade_count": 0,
		"air_dash_count": 0,
		"last_mobility_result": "대기",
		"last_invincibility_log": "무적 로그 대기",
		"invincibility_start_frame": -1,
		"invincibility_end_frame": -1,
		"health": PrototypePlayer.MAX_HEALTH,
		"max_health": PrototypePlayer.MAX_HEALTH,
		"fall_count": 0,
		"last_fall_damage": 0,
		"last_fall_log": "낙하 기록 대기",
		"last_safe_position": TRACK_START,
		"last_safe_label": "시작 평지",
		"recovery_state": "정상",
		"input_locked": false,
		"fall_recovery_remaining_s": 0.0,
	})
	target_selector.force_scan()
	queue_redraw()


func _draw() -> void:
	# 카메라가 이동해도 화면을 채우는 넓은 임시 평원.
	draw_rect(Rect2(-700.0, -400.0, 6500.0, 1400.0), Color("b9ecf2"), true)
	draw_circle(Vector2(900.0, 160.0), 90.0, Color("fff3b0"))
	_draw_hills()
	draw_rect(LEFT_FLOOR_RECT, Color("6aa66b"), true)
	draw_rect(RIGHT_FLOOR_RECT, Color("6aa66b"), true)
	draw_rect(Rect2(LEFT_FLOOR_RECT.position, Vector2(LEFT_FLOOR_RECT.size.x, 18.0)), Color("b8d86f"), true)
	draw_rect(Rect2(RIGHT_FLOOR_RECT.position, Vector2(RIGHT_FLOOR_RECT.size.x, 18.0)), Color("b8d86f"), true)
	draw_rect(FALL_ZONE_RECT, Color("173147"), true)
	draw_rect(Rect2(FALL_ZONE_RECT.position, Vector2(FALL_ZONE_RECT.size.x, 14.0)), Color("f26b5e"), true)
	draw_rect(PRACTICE_PLATFORM_RECT, Color("507f5b"), true)
	draw_rect(Rect2(PRACTICE_PLATFORM_RECT.position, Vector2(PRACTICE_PLATFORM_RECT.size.x, 10.0)), Color("d9ef85"), true)
	_draw_track_markers()
	draw_string(
		ThemeDB.fallback_font,
		PRACTICE_PLATFORM_RECT.position + Vector2(145.0, -18.0),
		"코요테 / 착지 버퍼 연습 발판",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		22,
		Color("315b4c")
	)
	draw_string(
		ThemeDB.fallback_font,
		FALL_ZONE_RECT.position + Vector2(145.0, 58.0),
		"낙하 테스트",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		24,
		Color("ffb4a9")
	)


func _draw_hills() -> void:
	var far_hills := PackedVector2Array([
		Vector2(-700.0, 700.0),
		Vector2(100.0, 430.0),
		Vector2(650.0, 620.0),
		Vector2(1350.0, 360.0),
		Vector2(2150.0, 640.0),
		Vector2(3050.0, 390.0),
		Vector2(3900.0, 630.0),
		Vector2(4850.0, 410.0),
		Vector2(5800.0, 690.0),
		Vector2(5800.0, 840.0),
		Vector2(-700.0, 840.0),
	])
	draw_colored_polygon(far_hills, Color("8bcf9a"))


func _draw_track_markers() -> void:
	var marker_x := 500.0
	while marker_x <= 4500.0:
		draw_line(Vector2(marker_x, FLOOR_TOP - 34.0), Vector2(marker_x, FLOOR_TOP), Color("f4fff4"), 5.0)
		var label := "%d m" % int(marker_x / PrototypePlayer.PIXELS_PER_METER)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(marker_x - 22.0, FLOOR_TOP - 48.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			18,
			Color("315b4c")
		)
		marker_x += 500.0


func _reset_test() -> void:
	player.reset_movement_test(TRACK_START)
	for node in get_tree().get_nodes_in_group("targetable"):
		var target := node as PrototypeTarget
		if target != null:
			target.reset_target()
	target_selector.reset_selection()
	controls.release_all_inputs()


func _on_safe_zone_entered(
	body: Node2D,
	spawn_position: Vector2,
	safe_label: String
) -> void:
	if body != player:
		return
	player.set_safe_spawn(spawn_position, safe_label)
