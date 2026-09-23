extends Control

## CP-101 입력 명령 계층 검증 화면.
## 포인터 소유권, 동적 이동 패드, 액션 우선순위와 입력 버퍼를 시각화한다.

const BACKGROUND_COLOR := Color("102636")
const GRID_COLOR := Color("284556")
const PANEL_COLOR := Color("18394b")
const PANEL_BORDER_COLOR := Color("4f7180")
const TEXT_COLOR := Color("eef8fa")
const MUTED_TEXT_COLOR := Color("a9c4cd")
const SAFE_COLOR := Color("76d39b")
const MOVE_COLOR := Color("62d6c8")
const ACTION_COLOR := Color("53a5db")
const ACTIVE_COLOR := Color("ffd166")
const PASS_COLOR := Color("9be564")
const DANGER_COLOR := Color("f07178")

const MOVE_CONTROL: StringName = &"move"
const ACTION_ORDER: Array[StringName] = [
	&"jump",
	&"evade",
	&"skill_2",
	&"skill_1",
	&"ultimate",
	&"weapon_swap",
]
const ACTION_LABELS := {
	&"jump": "점프",
	&"evade": "회피",
	&"skill_1": "스킬 1",
	&"skill_2": "스킬 2",
	&"ultimate": "필살기",
	&"weapon_swap": "전환",
}
const ACTION_TYPES := {
	&"jump": PlayerCommand.Type.JUMP,
	&"evade": PlayerCommand.Type.EVADE,
	&"skill_1": PlayerCommand.Type.SKILL_1,
	&"skill_2": PlayerCommand.Type.SKILL_2,
	&"ultimate": PlayerCommand.Type.ULTIMATE,
	&"weapon_swap": PlayerCommand.Type.WEAPON_SWAP,
}

var command_buffer := PlayerCommandBuffer.new()
var pointer_controls: Dictionary = {}
var pointer_positions: Dictionary = {}
var control_pointers: Dictionary = {}
var action_rects: Dictionary = {}
var move_zone := Rect2()
var move_pointer_id: int = -1
var move_origin := Vector2.ZERO
var move_vector := Vector2.ZERO
var move_radius: float = 110.0
var jump_pressed_at_msec: int = -1
var event_log: Array[String] = []
var peak_simultaneous_controls: int = 0
var simultaneous_action_passed: bool = false
var last_latency_msec: int = 0
var executed_command_count: int = 0
var action_lock_until_msec: int = 0
var fps_60_rect := Rect2()
var fps_30_rect := Rect2()
var reset_rect := Rect2()
var redraw_accumulator: float = 0.0


func _ready() -> void:
	Engine.max_fps = 60
	_refresh_layout()
	_append_log("CP-101 입력 샌드박스 준비 완료")
	_append_log("이동 패드를 유지한 채 액션 버튼을 눌러보세요")
	queue_redraw()


func _process(delta: float) -> void:
	redraw_accumulator += delta
	if redraw_accumulator >= 0.05:
		redraw_accumulator = 0.0
		queue_redraw()


func _physics_process(_delta: float) -> void:
	var now_msec := Time.get_ticks_msec()
	var removed := command_buffer.purge_expired(now_msec)
	if removed > 0:
		_append_log("만료된 입력 %d개 폐기" % removed)

	var processed := 0
	while processed < 8:
		var blocked_types: Array[int] = []
		if now_msec < action_lock_until_msec:
			blocked_types = [PlayerCommand.Type.JUMP, PlayerCommand.Type.WEAPON_SWAP]
		var command := command_buffer.pop_next(now_msec, blocked_types)
		if command == null:
			break
		_execute_command(command, now_msec)
		processed += 1

	_update_simultaneous_result()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh_layout()
		queue_redraw()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_clear_active_input()
		_append_log("앱 비활성화로 입력 상태 초기화")
		queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_handle_touch_pressed(touch.index, touch.position)
		else:
			_handle_touch_released(touch.index)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_handle_touch_dragged(drag.index, drag.position)
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	_draw_grid()
	_draw_safe_area()
	_draw_header()
	_draw_command_log()
	_draw_move_control()
	_draw_action_controls()
	_draw_pointer_markers()


func _handle_touch_pressed(pointer_id: int, position: Vector2) -> void:
	pointer_positions[pointer_id] = position
	if _handle_header_action(position):
		pointer_controls[pointer_id] = &"header"
		return

	if move_zone.has_point(position) and move_pointer_id < 0:
		move_pointer_id = pointer_id
		move_origin = _clamp_move_origin(position)
		move_vector = Vector2.ZERO
		pointer_controls[pointer_id] = MOVE_CONTROL
		control_pointers[MOVE_CONTROL] = pointer_id
		_append_log("이동 포인터 #%d 획득" % pointer_id)
		_update_simultaneous_result()
		return

	var action_id := _action_at(position)
	if action_id != &"" and not control_pointers.has(action_id):
		pointer_controls[pointer_id] = action_id
		control_pointers[action_id] = pointer_id
		_submit_action(action_id, PlayerCommand.Phase.PRESSED, pointer_id)
		_update_simultaneous_result()
		return

	pointer_controls[pointer_id] = &"unassigned"
	_append_log("포인터 #%d는 조작 영역 밖에서 시작" % pointer_id)


func _handle_touch_dragged(pointer_id: int, position: Vector2) -> void:
	pointer_positions[pointer_id] = position
	if pointer_id == move_pointer_id:
		var displacement := position - move_origin
		move_vector = displacement.limit_length(move_radius) / move_radius


func _handle_touch_released(pointer_id: int) -> void:
	var control_id: StringName = pointer_controls.get(pointer_id, &"")
	if control_id == MOVE_CONTROL:
		move_pointer_id = -1
		move_vector = Vector2.ZERO
		control_pointers.erase(MOVE_CONTROL)
		_append_log("이동 포인터 #%d 해제" % pointer_id)
	elif control_id in ACTION_ORDER:
		if control_id == &"jump":
			_submit_action(control_id, PlayerCommand.Phase.RELEASED, pointer_id)
		control_pointers.erase(control_id)

	pointer_controls.erase(pointer_id)
	pointer_positions.erase(pointer_id)
	_update_simultaneous_result()


func _submit_action(action_id: StringName, phase: int, pointer_id: int) -> void:
	var command_type: int = int(ACTION_TYPES[action_id])
	var now_msec := Time.get_ticks_msec()
	command_buffer.submit(command_type, phase, pointer_id, now_msec)
	if action_id == &"jump":
		jump_pressed_at_msec = now_msec if phase == PlayerCommand.Phase.PRESSED else -1


func _execute_command(command: PlayerCommand, now_msec: int) -> void:
	last_latency_msec = maxi(0, now_msec - command.created_at_msec)
	executed_command_count += 1
	var detail := "%s · %s · 우선순위 %d · %d ms" % [
		command.display_name(),
		command.phase_name(),
		command.priority(),
		last_latency_msec,
	]
	_append_log(detail)

	if command.command_type == PlayerCommand.Type.SKILL_1 \
		and command.phase == PlayerCommand.Phase.PRESSED:
		action_lock_until_msec = now_msec + 150
	elif command.command_type == PlayerCommand.Type.SKILL_2 \
		and command.phase == PlayerCommand.Phase.PRESSED:
		action_lock_until_msec = now_msec + 250

	if move_pointer_id >= 0 and command.phase == PlayerCommand.Phase.PRESSED:
		simultaneous_action_passed = true


func _handle_header_action(position: Vector2) -> bool:
	if fps_60_rect.has_point(position):
		Engine.max_fps = 60
		_append_log("프레임 제한을 60 FPS로 변경")
		return true
	if fps_30_rect.has_point(position):
		Engine.max_fps = 30
		_append_log("프레임 제한을 30 FPS로 변경")
		return true
	if reset_rect.has_point(position):
		_reset_test_result()
		return true
	return false


func _action_at(position: Vector2) -> StringName:
	for action_id in ACTION_ORDER:
		var rect: Rect2 = action_rects[action_id]
		if rect.has_point(position):
			return action_id
	return &""


func _update_simultaneous_result() -> void:
	var active_count := control_pointers.size()
	peak_simultaneous_controls = maxi(peak_simultaneous_controls, active_count)


func _reset_test_result() -> void:
	command_buffer.clear()
	peak_simultaneous_controls = control_pointers.size()
	simultaneous_action_passed = false
	last_latency_msec = 0
	executed_command_count = 0
	event_log.clear()
	_append_log("테스트 결과 초기화")


func _clear_active_input() -> void:
	pointer_controls.clear()
	pointer_positions.clear()
	control_pointers.clear()
	command_buffer.clear()
	move_pointer_id = -1
	move_vector = Vector2.ZERO
	jump_pressed_at_msec = -1
	action_lock_until_msec = 0


func _refresh_layout() -> void:
	var safe := _safe_area_in_viewport()
	var header_height := clampf(safe.size.y * 0.25, 190.0, 255.0)
	var header_gap := clampf(safe.size.x * 0.008, 12.0, 20.0)
	var button_width := clampf(safe.size.x * 0.078, 122.0, 168.0)
	var button_height := clampf(safe.size.y * 0.058, 52.0, 66.0)
	var header_right := safe.end.x - 22.0
	var header_top := safe.position.y + 24.0
	reset_rect = Rect2(header_right - button_width, header_top, button_width, button_height)
	fps_30_rect = Rect2(reset_rect.position.x - header_gap - button_width, header_top, button_width, button_height)
	fps_60_rect = Rect2(fps_30_rect.position.x - header_gap - button_width, header_top, button_width, button_height)

	move_zone = Rect2(
		safe.position.x + 20.0,
		safe.end.y - clampf(safe.size.y * 0.42, 310.0, 410.0),
		clampf(safe.size.x * 0.31, 430.0, 580.0),
		clampf(safe.size.y * 0.38, 280.0, 370.0)
	)
	move_radius = clampf(minf(move_zone.size.x, move_zone.size.y) * 0.30, 82.0, 118.0)
	if move_pointer_id < 0:
		move_origin = move_zone.get_center()

	var centers := {
		&"jump": Vector2(0.925, 0.815),
		&"evade": Vector2(0.825, 0.830),
		&"skill_1": Vector2(0.795, 0.650),
		&"skill_2": Vector2(0.905, 0.600),
		&"ultimate": Vector2(0.680, 0.665),
		&"weapon_swap": Vector2(0.690, 0.845),
	}
	var radii := {
		&"jump": 84.0,
		&"evade": 72.0,
		&"skill_1": 72.0,
		&"skill_2": 72.0,
		&"ultimate": 72.0,
		&"weapon_swap": 64.0,
	}
	action_rects.clear()
	for action_id in ACTION_ORDER:
		var normalized: Vector2 = centers[action_id]
		var center := safe.position + normalized * safe.size
		var radius: float = float(radii[action_id])
		action_rects[action_id] = Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)

	# header_height를 계산해 화면 높이가 작은 비율에서도 조작 영역 시작을 고정한다.
	move_zone.position.y = maxf(move_zone.position.y, safe.position.y + header_height + 18.0)


func _draw_grid() -> void:
	var spacing := maxf(64.0, size.x / 16.0)
	var x := 0.0
	while x <= size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), GRID_COLOR, 1.0)
		x += spacing
	var y := 0.0
	while y <= size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), GRID_COLOR, 1.0)
		y += spacing


func _draw_safe_area() -> void:
	var safe := _safe_area_in_viewport()
	draw_rect(safe, Color(SAFE_COLOR, 0.035), true)
	draw_rect(safe, SAFE_COLOR, false, 3.0)


func _draw_header() -> void:
	var safe := _safe_area_in_viewport()
	var panel_rect := Rect2(
		safe.position + Vector2(14.0, 14.0),
		Vector2(safe.size.x - 28.0, clampf(safe.size.y * 0.22, 178.0, 230.0))
	)
	draw_style_box(_panel_style(), panel_rect)
	_draw_text("CP-101 · 입력 명령 샌드박스", panel_rect.position + Vector2(24.0, 44.0), 31)
	_draw_text(
		"동적 이동 패드 + 포인터별 액션 소유권 + 우선순위/버퍼",
		panel_rect.position + Vector2(24.0, 78.0),
		20,
		MUTED_TEXT_COLOR
	)

	var result_text := "PASS · 이동 중 액션 명령 확인" if simultaneous_action_passed else "대기 · 이동을 유지하며 액션을 누르세요"
	var result_color := PASS_COLOR if simultaneous_action_passed else ACTIVE_COLOR
	_draw_text(result_text, panel_rect.position + Vector2(24.0, 119.0), 24, result_color)
	var metrics := "FPS %d/%d  |  활성 조작 %d  |  최대 동시 %d  |  대기 명령 %d  |  최근 지연 %d ms" % [
		Engine.get_frames_per_second(),
		Engine.max_fps,
		control_pointers.size(),
		peak_simultaneous_controls,
		command_buffer.pending_count(),
		last_latency_msec,
	]
	_draw_text(metrics, panel_rect.position + Vector2(24.0, 158.0), 21)

	_draw_button(fps_60_rect, "60 FPS", Engine.max_fps == 60)
	_draw_button(fps_30_rect, "30 FPS", Engine.max_fps == 30)
	_draw_button(reset_rect, "초기화", false)


func _draw_command_log() -> void:
	var safe := _safe_area_in_viewport()
	var panel_rect := Rect2(
		safe.position.x + safe.size.x * 0.335,
		safe.position.y + safe.size.y * 0.285,
		safe.size.x * 0.31,
		safe.size.y * 0.64
	)
	draw_style_box(_panel_style(Color(PANEL_COLOR, 0.86)), panel_rect)
	_draw_text("실행된 명령", panel_rect.position + Vector2(22.0, 36.0), 24)
	_draw_text("회피 > 필살기 > 스킬 > 점프 > 전환 > 자동 공격", panel_rect.position + Vector2(22.0, 68.0), 17, MUTED_TEXT_COLOR)
	var line_y := panel_rect.position.y + 104.0
	for line in event_log:
		if line_y > panel_rect.end.y - 18.0:
			break
		_draw_text(line, Vector2(panel_rect.position.x + 22.0, line_y), 18, MUTED_TEXT_COLOR)
		line_y += 29.0


func _draw_move_control() -> void:
	var is_active := move_pointer_id >= 0
	draw_rect(move_zone, Color(MOVE_COLOR, 0.10 if not is_active else 0.18), true)
	draw_rect(move_zone, ACTIVE_COLOR if is_active else MOVE_COLOR, false, 4.0)
	_draw_text("이동 영역 · 첫 터치가 패드 중심", move_zone.position + Vector2(18.0, 32.0), 20, MUTED_TEXT_COLOR)

	var knob_position := move_origin + move_vector * move_radius
	draw_circle(move_origin, move_radius, Color(MOVE_COLOR, 0.11))
	draw_arc(move_origin, move_radius, 0.0, TAU, 48, MOVE_COLOR, 4.0, true)
	draw_line(move_origin, knob_position, ACTIVE_COLOR if is_active else MOVE_COLOR, 7.0)
	draw_circle(knob_position, 46.0, Color(ACTIVE_COLOR if is_active else MOVE_COLOR, 0.28))
	draw_arc(knob_position, 46.0, 0.0, TAU, 40, ACTIVE_COLOR if is_active else MOVE_COLOR, 5.0, true)
	_draw_text(
		"벡터  %.2f, %.2f" % [move_vector.x, move_vector.y],
		move_zone.position + Vector2(18.0, move_zone.size.y - 20.0),
		20,
		ACTIVE_COLOR if is_active else MUTED_TEXT_COLOR
	)


func _draw_action_controls() -> void:
	for action_id in ACTION_ORDER:
		var rect: Rect2 = action_rects[action_id]
		var pressed := control_pointers.has(action_id)
		var color := ACTIVE_COLOR if pressed else ACTION_COLOR
		draw_circle(rect.get_center(), rect.size.x * 0.5, Color(color, 0.24 if pressed else 0.14))
		draw_arc(rect.get_center(), rect.size.x * 0.5, 0.0, TAU, 44, color, 5.0, true)
		_draw_text_centered(String(ACTION_LABELS[action_id]), rect, 19, color if not pressed else BACKGROUND_COLOR)

	if Time.get_ticks_msec() < action_lock_until_msec:
		_draw_text("스킬 행동 잠금 · 점프/전환 입력 버퍼 확인", Vector2(size.x * 0.66, size.y * 0.30), 19, DANGER_COLOR)


func _draw_pointer_markers() -> void:
	for pointer_id in pointer_positions:
		var position: Vector2 = pointer_positions[pointer_id]
		draw_circle(position, 24.0, Color(TEXT_COLOR, 0.22))
		draw_arc(position, 24.0, 0.0, TAU, 28, TEXT_COLOR, 3.0, true)
		_draw_text("#%d" % int(pointer_id), position + Vector2(28.0, -18.0), 17, TEXT_COLOR)


func _draw_button(rect: Rect2, label: String, selected: bool) -> void:
	var fill := ACTIVE_COLOR if selected else Color("244c60")
	var text_color := BACKGROUND_COLOR if selected else TEXT_COLOR
	draw_rect(rect, fill, true)
	draw_rect(rect, Color(fill, 0.95), false, 3.0)
	_draw_text_centered(label, rect, 19, text_color)


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


func _append_log(message: String) -> void:
	var seconds := Time.get_ticks_msec() / 1000.0
	event_log.push_front("%6.2f  %s" % [seconds, message])
	if event_log.size() > 11:
		event_log.resize(11)


func _clamp_move_origin(position: Vector2) -> Vector2:
	return Vector2(
		clampf(position.x, move_zone.position.x + move_radius, move_zone.end.x - move_radius),
		clampf(position.y, move_zone.position.y + move_radius, move_zone.end.y - move_radius)
	)


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
	return Rect2(Vector2(safe_pixels.position) * scale, Vector2(safe_pixels.size) * scale)


func _margin() -> float:
	return maxf(24.0, minf(size.x, size.y) * 0.02)
