extends Control

## CP-001/002 diagnostic scene.
## Verifies landscape scaling, safe area mapping, frame pacing and multi-touch IDs.

const BACKGROUND_COLOR := Color("102636")
const GRID_COLOR := Color("284556")
const PANEL_COLOR := Color("18394b")
const PANEL_BORDER_COLOR := Color("4f7180")
const TEXT_COLOR := Color("eef8fa")
const MUTED_TEXT_COLOR := Color("a9c4cd")
const SAFE_COLOR := Color("76d39b")
const ACTION_COLOR := Color("53a5db")
const ACTIVE_COLOR := Color("ffd166")
const DANGER_COLOR := Color("f07178")

const TOUCH_COLORS: Array[Color] = [
	Color("ffd166"),
	Color("62d6c8"),
	Color("76a9fa"),
	Color("c792ea"),
	Color("ff8fa3"),
	Color("f7b267"),
	Color("9be564"),
	Color("70d6ff")
]

var active_touches: Dictionary = {}
var peak_touch_count: int = 0
var total_touch_down_count: int = 0
var event_log: Array[String] = []
var redraw_accumulator: float = 0.0
var fps_60_rect := Rect2()
var fps_30_rect := Rect2()
var clear_rect := Rect2()
var test_zones: Array[Rect2] = []


func _ready() -> void:
	Engine.max_fps = 60
	_refresh_layout_rects()
	_append_log("진단 화면 준비 완료")
	_append_log("여러 손가락으로 아래 세 영역을 동시에 눌러보세요")
	queue_redraw()


func _process(delta: float) -> void:
	redraw_accumulator += delta
	if redraw_accumulator >= 0.20:
		redraw_accumulator = 0.0
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh_layout_rects()
		queue_redraw()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		active_touches.clear()
		_append_log("앱 비활성화로 활성 터치 초기화")
		queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			active_touches[touch_event.index] = touch_event.position
			peak_touch_count = maxi(peak_touch_count, active_touches.size())
			total_touch_down_count += 1
			_append_log("DOWN #%d  (%.0f, %.0f)" % [
				touch_event.index,
				touch_event.position.x,
				touch_event.position.y
			])
			_handle_diagnostic_action(touch_event.position)
		else:
			active_touches.erase(touch_event.index)
			_append_log("UP   #%d" % touch_event.index)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		active_touches[drag_event.index] = drag_event.position
		queue_redraw()


func _draw() -> void:
	var view_size := size
	draw_rect(Rect2(Vector2.ZERO, view_size), BACKGROUND_COLOR)
	_draw_grid(view_size)
	_draw_safe_area()
	_draw_header()
	_draw_test_zones()
	_draw_event_log()
	_draw_active_touches()


func _draw_grid(view_size: Vector2) -> void:
	var spacing := maxf(64.0, view_size.x / 16.0)
	var x := 0.0
	while x <= view_size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, view_size.y), GRID_COLOR, 1.0)
		x += spacing
	var y := 0.0
	while y <= view_size.y:
		draw_line(Vector2(0.0, y), Vector2(view_size.x, y), GRID_COLOR, 1.0)
		y += spacing


func _draw_safe_area() -> void:
	var safe_rect := _safe_area_in_viewport()
	draw_rect(safe_rect, Color(SAFE_COLOR, 0.06), true)
	draw_rect(safe_rect, SAFE_COLOR, false, 4.0)
	_draw_text("SAFE AREA", safe_rect.position + Vector2(18.0, 34.0), 22, SAFE_COLOR)


func _draw_header() -> void:
	var margin := _margin()
	var panel_rect := Rect2(margin, margin, size.x - margin * 2.0, minf(230.0, size.y * 0.28))
	draw_style_box(_panel_style(), panel_rect)

	_draw_text("Happiness Tale · Touch Diagnostics", panel_rect.position + Vector2(28.0, 48.0), 34)
	_draw_text(
		"Godot 4.7.2 target · Android landscape · GL Compatibility",
		panel_rect.position + Vector2(28.0, 82.0),
		21,
		MUTED_TEXT_COLOR
	)

	var safe_rect := _safe_area_in_viewport()
	var metrics := "FPS %d / limit %d   |   viewport %.0f×%.0f   |   safe %.0f,%.0f %.0f×%.0f" % [
		Engine.get_frames_per_second(),
		Engine.max_fps,
		size.x,
		size.y,
		safe_rect.position.x,
		safe_rect.position.y,
		safe_rect.size.x,
		safe_rect.size.y
	]
	_draw_text(metrics, panel_rect.position + Vector2(28.0, 124.0), 23)

	var touch_metrics := "활성 터치 %d   |   최대 동시 터치 %d   |   누른 횟수 %d   |   OS %s" % [
		active_touches.size(),
		peak_touch_count,
		total_touch_down_count,
		OS.get_name()
	]
	_draw_text(touch_metrics, panel_rect.position + Vector2(28.0, 164.0), 23)

	_draw_button(fps_60_rect, "60 FPS", Engine.max_fps == 60)
	_draw_button(fps_30_rect, "30 FPS", Engine.max_fps == 30)
	_draw_button(clear_rect, "기록 초기화", false)


func _draw_test_zones() -> void:
	var labels := ["ZONE A · 이동", "ZONE B · 점프", "ZONE C · 스킬"]
	for index in test_zones.size():
		var zone := test_zones[index]
		var is_pressed := _is_zone_pressed(zone)
		var fill := Color(ACTION_COLOR, 0.32 if is_pressed else 0.13)
		draw_rect(zone, fill, true)
		draw_rect(zone, ACTIVE_COLOR if is_pressed else ACTION_COLOR, false, 4.0)
		_draw_text_centered(labels[index], zone, 28, ACTIVE_COLOR if is_pressed else TEXT_COLOR)


func _draw_event_log() -> void:
	var margin := _margin()
	var available_top := minf(260.0, size.y * 0.31)
	var available_bottom := test_zones[0].position.y - 24.0 if not test_zones.is_empty() else size.y - margin
	var log_rect := Rect2(margin, available_top, minf(720.0, size.x * 0.48), maxf(120.0, available_bottom - available_top))
	draw_style_box(_panel_style(Color(PANEL_COLOR, 0.82)), log_rect)
	_draw_text("최근 입력", log_rect.position + Vector2(24.0, 38.0), 25)

	var line_y := log_rect.position.y + 76.0
	for line in event_log:
		if line_y > log_rect.end.y - 18.0:
			break
		_draw_text(line, Vector2(log_rect.position.x + 24.0, line_y), 20, MUTED_TEXT_COLOR)
		line_y += 31.0


func _draw_active_touches() -> void:
	for touch_index in active_touches:
		var position: Vector2 = active_touches[touch_index]
		var color := TOUCH_COLORS[int(touch_index) % TOUCH_COLORS.size()]
		draw_circle(position, 62.0, Color(color, 0.20))
		draw_arc(position, 62.0, 0.0, TAU, 48, color, 6.0, true)
		draw_circle(position, 20.0, color)
		_draw_text_centered(
			"#%d" % int(touch_index),
			Rect2(position - Vector2(45.0, 112.0), Vector2(90.0, 38.0)),
			24,
			color
		)


func _draw_button(rect: Rect2, label: String, selected: bool) -> void:
	var fill := ACTIVE_COLOR if selected else Color("244c60")
	var text_color := BACKGROUND_COLOR if selected else TEXT_COLOR
	draw_rect(rect, fill, true)
	draw_rect(rect, Color(fill, 0.95), false, 3.0)
	_draw_text_centered(label, rect, 21, text_color)


func _draw_text(
	text: String,
	position: Vector2,
	font_size: int,
	color: Color = TEXT_COLOR
) -> void:
	draw_string(
		ThemeDB.fallback_font,
		position,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		color
	)


func _draw_text_centered(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var text_size := ThemeDB.fallback_font.get_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	)
	var baseline := rect.position + Vector2(
		(rect.size.x - text_size.x) * 0.5,
		(rect.size.y + text_size.y) * 0.5 - 3.0
	)
	_draw_text(text, baseline, font_size, color)


func _panel_style(color: Color = PANEL_COLOR) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = PANEL_BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	return style


func _refresh_layout_rects() -> void:
	var margin := _margin()
	var button_width := clampf(size.x * 0.085, 126.0, 176.0)
	var button_height := clampf(size.y * 0.055, 54.0, 68.0)
	var gap := 16.0
	var right := size.x - margin - 24.0
	var top := margin + 26.0

	clear_rect = Rect2(right - button_width, top, button_width, button_height)
	fps_30_rect = Rect2(clear_rect.position.x - gap - button_width, top, button_width, button_height)
	fps_60_rect = Rect2(fps_30_rect.position.x - gap - button_width, top, button_width, button_height)

	var zone_margin := margin + 18.0
	var zone_gap := 24.0
	var zone_height := clampf(size.y * 0.18, 150.0, 210.0)
	var zone_width := (size.x - zone_margin * 2.0 - zone_gap * 2.0) / 3.0
	var zone_y := size.y - margin - zone_height
	test_zones = []
	for index in 3:
		test_zones.append(Rect2(
			zone_margin + (zone_width + zone_gap) * index,
			zone_y,
			zone_width,
			zone_height
		))


func _handle_diagnostic_action(position: Vector2) -> void:
	if fps_60_rect.has_point(position):
		Engine.max_fps = 60
		_append_log("프레임 제한을 60 FPS로 변경")
	elif fps_30_rect.has_point(position):
		Engine.max_fps = 30
		_append_log("프레임 제한을 30 FPS로 변경")
	elif clear_rect.has_point(position):
		peak_touch_count = active_touches.size()
		total_touch_down_count = 0
		event_log.clear()
		_append_log("입력 기록 초기화")


func _is_zone_pressed(zone: Rect2) -> bool:
	for position in active_touches.values():
		if zone.has_point(position):
			return true
	return false


func _append_log(message: String) -> void:
	var timestamp := Time.get_time_string_from_system()
	event_log.push_front("%s  %s" % [timestamp, message])
	if event_log.size() > 8:
		event_log.resize(8)


func _safe_area_in_viewport() -> Rect2:
	var fallback_margin := _margin()
	var fallback := Rect2(
		Vector2(fallback_margin, fallback_margin),
		size - Vector2(fallback_margin, fallback_margin) * 2.0
	)
	if not OS.has_feature("mobile"):
		return fallback

	var safe_pixels := DisplayServer.get_display_safe_area()
	var window_pixels := DisplayServer.window_get_size()
	if safe_pixels.size.x <= 0 or safe_pixels.size.y <= 0:
		return fallback
	if window_pixels.x <= 0 or window_pixels.y <= 0:
		return fallback

	var scale := Vector2(
		size.x / float(window_pixels.x),
		size.y / float(window_pixels.y)
	)
	var safe_position := Vector2(safe_pixels.position) * scale
	var safe_size := Vector2(safe_pixels.size) * scale
	return Rect2(safe_position, safe_size)


func _margin() -> float:
	return maxf(24.0, minf(size.x, size.y) * 0.02)
