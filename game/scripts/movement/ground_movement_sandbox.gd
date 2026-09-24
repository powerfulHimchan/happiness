extends Node2D

## CP-102 지상 이동 검증 트랙과 UI 연결을 담당한다.

const TRACK_START := Vector2(520.0, 780.0)
const TRACK_LEFT := 100.0
const TRACK_RIGHT := 4900.0
const FLOOR_TOP := 840.0

@onready var player: PrototypePlayer = $Player
@onready var controls: Control = $CanvasLayer/GroundMovementControls


func _ready() -> void:
	controls.move_vector_changed.connect(player.set_move_vector)
	controls.reset_requested.connect(_reset_test)
	player.movement_metrics_changed.connect(controls.update_movement_metrics)
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
	})
	queue_redraw()


func _draw() -> void:
	# 카메라가 이동해도 화면을 채우는 넓은 임시 평원.
	draw_rect(Rect2(-700.0, -400.0, 6500.0, 1400.0), Color("b9ecf2"), true)
	draw_circle(Vector2(900.0, 160.0), 90.0, Color("fff3b0"))
	_draw_hills()
	draw_rect(Rect2(TRACK_LEFT - 100.0, FLOOR_TOP, TRACK_RIGHT - TRACK_LEFT + 200.0, 300.0), Color("6aa66b"), true)
	draw_rect(Rect2(TRACK_LEFT - 100.0, FLOOR_TOP, TRACK_RIGHT - TRACK_LEFT + 200.0, 18.0), Color("b8d86f"), true)
	_draw_track_markers()


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
	controls.release_all_inputs()
