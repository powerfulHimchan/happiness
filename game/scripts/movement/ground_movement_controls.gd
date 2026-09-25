extends Control

## CP-205용 모바일 조작 HUD.
## 전환 제한, 예약 입력과 두 무기의 독립 대기시간을 표시한다.

signal move_vector_changed(input_vector: Vector2)
signal jump_pressed
signal jump_released
signal evade_pressed
signal reset_requested
signal damage_test_pressed
signal skill_1_pressed
signal skill_2_pressed
signal weapon_swap_pressed

const PANEL_COLOR := Color("18394b")
const PANEL_BORDER_COLOR := Color("4f7180")
const TEXT_COLOR := Color("eef8fa")
const MUTED_TEXT_COLOR := Color("a9c4cd")
const MOVE_COLOR := Color("3cae9b")
const ACTION_COLOR := Color("397eb8")
const ACTIVE_COLOR := Color("ffd166")
const PASS_COLOR := Color("9be564")
const WAIT_COLOR := Color("f7b267")
const BACKGROUND_COLOR := Color("102636")

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
	&"skill_1": "돌진",
	&"skill_2": "회전",
	&"ultimate": "피격 12",
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
var move_radius: float = 106.0
var fps_60_rect := Rect2()
var fps_30_rect := Rect2()
var reset_rect := Rect2()
var action_log: Array[String] = []
var movement_metrics: Dictionary = {}
var last_latency_msec: int = 0
var peak_simultaneous_controls: int = 0
var redraw_accumulator: float = 0.0
var last_invincibility_log_seen: String = ""
var last_fall_log_seen: String = ""
var last_target_key_seen: String = "없음"
var last_damage_log_seen: String = ""
var last_combat_log_seen: String = ""
var last_weapon_switch_log_seen: String = ""


func _ready() -> void:
	Engine.max_fps = 60
	_refresh_layout()
	_append_action_log("CP-205 두 무기 전환 테스트 시작")
	queue_redraw()


func _process(delta: float) -> void:
	redraw_accumulator += delta
	if redraw_accumulator >= 0.05:
		redraw_accumulator = 0.0
		queue_redraw()


func _physics_process(_delta: float) -> void:
	var now_msec := Time.get_ticks_msec()
	command_buffer.purge_expired(now_msec)
	var processed := 0
	while processed < 8:
		var command := command_buffer.pop_next(now_msec)
		if command == null:
			break
		last_latency_msec = maxi(0, now_msec - command.created_at_msec)
		_append_action_log("%s %s · %d ms" % [
			command.display_name(),
			command.phase_name(),
			last_latency_msec,
		])
		_dispatch_action_command(command)
		processed += 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh_layout()
		queue_redraw()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		release_all_inputs()
		_append_action_log("앱 비활성화 · 입력 초기화")


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
	_draw_header()
	_draw_move_control()
	_draw_action_controls()
	_draw_pointer_markers()


func update_movement_metrics(metrics: Dictionary) -> void:
	for key in metrics:
		movement_metrics[key] = metrics[key]
	var invincibility_log: String = String(metrics.get("last_invincibility_log", ""))
	if not invincibility_log.is_empty() \
		and invincibility_log != "무적 로그 대기" \
		and invincibility_log != last_invincibility_log_seen:
		last_invincibility_log_seen = invincibility_log
		_append_action_log(invincibility_log)
	var fall_log: String = String(metrics.get("last_fall_log", ""))
	if not fall_log.is_empty() \
		and fall_log != "낙하 기록 대기" \
		and fall_log != last_fall_log_seen:
		last_fall_log_seen = fall_log
		_append_action_log(fall_log)
	var damage_log: String = String(metrics.get("last_damage_log", ""))
	if not damage_log.is_empty() \
		and damage_log != "피해 기록 대기" \
		and damage_log != last_damage_log_seen:
		last_damage_log_seen = damage_log
		_append_action_log(damage_log)
	queue_redraw()


func update_target_metrics(metrics: Dictionary) -> void:
	for key in metrics:
		movement_metrics[key] = metrics[key]
	var target_key: String = String(metrics.get("target_key", "없음"))
	if target_key != last_target_key_seen:
		last_target_key_seen = target_key
		_append_action_log("대상 → %s" % target_key)
	queue_redraw()


func update_combat_metrics(metrics: Dictionary) -> void:
	for key in metrics:
		movement_metrics[key] = metrics[key]
	var combat_log: String = String(metrics.get("combat_last_log", ""))
	if not combat_log.is_empty() \
	and combat_log != "공격 대기" \
	and combat_log != last_combat_log_seen:
		last_combat_log_seen = combat_log
		_append_action_log(combat_log)
	var switch_log: String = String(metrics.get("weapon_switch_last_log", ""))
	if not switch_log.is_empty() \
	and switch_log != "전환 대기" \
	and switch_log != last_weapon_switch_log_seen:
		last_weapon_switch_log_seen = switch_log
		_append_action_log(switch_log)
	queue_redraw()


func report_damage_test(message: String) -> void:
	_append_action_log(message)
	queue_redraw()


func release_all_inputs() -> void:
	pointer_controls.clear()
	pointer_positions.clear()
	control_pointers.clear()
	command_buffer.clear()
	move_pointer_id = -1
	move_vector = Vector2.ZERO
	move_origin = move_zone.get_center()
	move_vector_changed.emit(Vector2.ZERO)
	jump_released.emit()
	queue_redraw()


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
		_update_peak_controls()
		move_vector_changed.emit(move_vector)
		return

	var action_id := _action_at(position)
	if action_id != &"" and not control_pointers.has(action_id):
		pointer_controls[pointer_id] = action_id
		control_pointers[action_id] = pointer_id
		_submit_action(action_id, PlayerCommand.Phase.PRESSED, pointer_id)
		_update_peak_controls()
		return

	pointer_controls[pointer_id] = &"unassigned"


func _handle_touch_dragged(pointer_id: int, position: Vector2) -> void:
	pointer_positions[pointer_id] = position
	if pointer_id == move_pointer_id:
		var displacement := position - move_origin
		move_vector = displacement.limit_length(move_radius) / move_radius
		move_vector_changed.emit(move_vector)


func _handle_touch_released(pointer_id: int) -> void:
	var control_id: StringName = pointer_controls.get(pointer_id, &"")
	if control_id == MOVE_CONTROL:
		move_pointer_id = -1
		move_vector = Vector2.ZERO
		control_pointers.erase(MOVE_CONTROL)
		move_vector_changed.emit(Vector2.ZERO)
	elif control_id in ACTION_ORDER:
		if control_id == &"jump":
			_submit_action(control_id, PlayerCommand.Phase.RELEASED, pointer_id)
		control_pointers.erase(control_id)

	pointer_controls.erase(pointer_id)
	pointer_positions.erase(pointer_id)


func _submit_action(action_id: StringName, phase: int, pointer_id: int) -> void:
	command_buffer.submit(
		int(ACTION_TYPES[action_id]),
		phase,
		pointer_id,
		Time.get_ticks_msec()
	)


func _dispatch_action_command(command: PlayerCommand) -> void:
	match command.command_type:
		PlayerCommand.Type.JUMP:
			if command.phase == PlayerCommand.Phase.PRESSED:
				jump_pressed.emit()
			elif command.phase == PlayerCommand.Phase.RELEASED:
				jump_released.emit()
		PlayerCommand.Type.EVADE:
			if command.phase == PlayerCommand.Phase.PRESSED:
				evade_pressed.emit()
		PlayerCommand.Type.SKILL_1:
			if command.phase == PlayerCommand.Phase.PRESSED:
				skill_1_pressed.emit()
		PlayerCommand.Type.SKILL_2:
			if command.phase == PlayerCommand.Phase.PRESSED:
				skill_2_pressed.emit()
		PlayerCommand.Type.ULTIMATE:
			if command.phase == PlayerCommand.Phase.PRESSED:
				damage_test_pressed.emit()
		PlayerCommand.Type.WEAPON_SWAP:
			if command.phase == PlayerCommand.Phase.PRESSED:
				weapon_swap_pressed.emit()


func _handle_header_action(position: Vector2) -> bool:
	if fps_60_rect.has_point(position):
		Engine.max_fps = 60
		_append_action_log("60 FPS로 변경")
		return true
	if fps_30_rect.has_point(position):
		Engine.max_fps = 30
		_append_action_log("30 FPS로 변경")
		return true
	if reset_rect.has_point(position):
		reset_requested.emit()
		action_log.clear()
		_append_action_log("위치와 테스트 결과 초기화")
		return true
	return false


func _action_at(position: Vector2) -> StringName:
	for action_id in ACTION_ORDER:
		var rect: Rect2 = action_rects[action_id]
		if rect.has_point(position):
			return action_id
	return &""


func _update_peak_controls() -> void:
	peak_simultaneous_controls = maxi(peak_simultaneous_controls, control_pointers.size())


func _refresh_layout() -> void:
	var safe := _safe_area_in_viewport()
	var button_width := clampf(safe.size.x * 0.075, 118.0, 160.0)
	var button_height := clampf(safe.size.y * 0.052, 50.0, 62.0)
	var gap := 14.0
	var right := safe.end.x - 20.0
	var top := safe.position.y + 20.0
	reset_rect = Rect2(right - button_width, top, button_width, button_height)
	fps_30_rect = Rect2(reset_rect.position.x - gap - button_width, top, button_width, button_height)
	fps_60_rect = Rect2(fps_30_rect.position.x - gap - button_width, top, button_width, button_height)

	move_zone = Rect2(
		safe.position.x + 20.0,
		safe.end.y - clampf(safe.size.y * 0.38, 285.0, 370.0),
		clampf(safe.size.x * 0.30, 420.0, 570.0),
		clampf(safe.size.y * 0.34, 260.0, 340.0)
	)
	move_radius = clampf(minf(move_zone.size.x, move_zone.size.y) * 0.31, 82.0, 110.0)
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


func _draw_header() -> void:
	var safe := _safe_area_in_viewport()
	var panel_rect := Rect2(
		safe.position + Vector2(14.0, 14.0),
		Vector2(safe.size.x - 28.0, clampf(safe.size.y * 0.235, 205.0, 245.0))
	)
	draw_style_box(_panel_style(Color(PANEL_COLOR, 0.91)), panel_rect)
	_draw_text("CP-205 · 검·활 두 무기 전환", panel_rect.position + Vector2(22.0, 40.0), 29)
	_draw_text(
		"전환 제한 0.50초 · 공격 대기시간 유지 · 무기별 스킬 쿨다운 유지",
		panel_rect.position + Vector2(22.0, 72.0),
		18,
		MUTED_TEXT_COLOR
	)

	var health: int = int(movement_metrics.get("health", 100))
	var max_health: int = int(movement_metrics.get("max_health", 100))
	var dead: bool = bool(movement_metrics.get("damage_dead", false))
	var hit_invulnerable: bool = bool(movement_metrics.get("damage_post_hit_invulnerable", false))
	var hit_invulnerable_s: float = float(movement_metrics.get("damage_post_hit_remaining_s", 0.0))
	var state_text := "사망" if dead else ("피격 무적" if hit_invulnerable else "전투 가능")
	_draw_text(
		"HP %d/%d  |  상태 %s  |  무적 남음 %.2fs" % [
			health, max_health, state_text, hit_invulnerable_s,
		],
		panel_rect.position + Vector2(22.0, 106.0),
		20,
		WAIT_COLOR if dead else (ACTIVE_COLOR if hit_invulnerable else PASS_COLOR)
	)

	var combat_action: String = String(movement_metrics.get("combat_action", "자동 공격"))
	var weapon_name: String = String(movement_metrics.get("weapon_name", "연습용 검"))
	var target_health: String = String(movement_metrics.get("combat_target_health", "대상 없음"))
	var active_weapon_id: String = String(movement_metrics.get("active_weapon_id", "sword"))
	_draw_text(
		"주 무기 %s(%s)  |  행동 %s  |  %s" % [
			weapon_name, active_weapon_id, combat_action, target_health,
		],
		panel_rect.position + Vector2(22.0, 139.0),
		18,
		MUTED_TEXT_COLOR
	)

	var switch_remaining: float = float(movement_metrics.get("weapon_switch_remaining_s", 0.0))
	var switch_buffered: bool = bool(movement_metrics.get("weapon_switch_buffered", false))
	var switch_buffer_remaining: float = float(movement_metrics.get("weapon_switch_buffer_remaining_s", 0.0))
	var switch_count: int = int(movement_metrics.get("weapon_switch_count", 0))
	var blocked_count: int = int(movement_metrics.get("weapon_switch_blocked_count", 0))
	var sword_basic: float = float(movement_metrics.get("sword_basic_remaining_s", 0.0))
	var bow_basic: float = float(movement_metrics.get("bow_basic_remaining_s", 0.0))
	_draw_text(
		"전환 %.2fs  |  예약 %s %.2fs  |  성공 %d / 차단 %d  |  기본 검 %.2f · 활 %.2f" % [
			switch_remaining, "ON" if switch_buffered else "OFF", switch_buffer_remaining,
			switch_count, blocked_count, sword_basic, bow_basic,
		],
		panel_rect.position + Vector2(22.0, 172.0),
		18,
		TEXT_COLOR
	)

	var sword_skill_1: float = float(movement_metrics.get("sword_skill_1_cooldown_s", 0.0))
	var sword_skill_2: float = float(movement_metrics.get("sword_skill_2_cooldown_s", 0.0))
	var bow_skill_1: float = float(movement_metrics.get("bow_skill_1_cooldown_s", 0.0))
	var bow_skill_2: float = float(movement_metrics.get("bow_skill_2_cooldown_s", 0.0))
	var switch_log: String = String(movement_metrics.get("weapon_switch_last_log", "전환 대기"))
	_draw_text(
		"검 스킬 %.1f / %.1f  |  활 스킬 %.1f / %.1f  |  %s" % [
			sword_skill_1, sword_skill_2, bow_skill_1, bow_skill_2, switch_log,
		],
		panel_rect.position + Vector2(22.0, 205.0),
		17,
		PASS_COLOR
	)

	_draw_button(fps_60_rect, "60 FPS", Engine.max_fps == 60)
	_draw_button(fps_30_rect, "30 FPS", Engine.max_fps == 30)
	_draw_button(reset_rect, "초기화", false)
	_draw_action_log(panel_rect)


func _draw_action_log(panel_rect: Rect2) -> void:
	var x := panel_rect.position.x + panel_rect.size.x * 0.62
	var y := panel_rect.position.y + 92.0
	for line in action_log:
		_draw_text(line, Vector2(x, y), 16, MUTED_TEXT_COLOR)
		y += 24.0
		if y > panel_rect.end.y - 14.0:
			break


func _draw_move_control() -> void:
	var active := move_pointer_id >= 0
	draw_rect(move_zone, Color(MOVE_COLOR, 0.14 if active else 0.08), true)
	draw_rect(move_zone, ACTIVE_COLOR if active else MOVE_COLOR, false, 4.0)
	_draw_text("이동", move_zone.position + Vector2(18.0, 30.0), 20, MUTED_TEXT_COLOR)
	var knob := move_origin + move_vector * move_radius
	draw_circle(move_origin, move_radius, Color(MOVE_COLOR, 0.11))
	draw_arc(move_origin, move_radius, 0.0, TAU, 48, MOVE_COLOR, 4.0, true)
	draw_line(move_origin, knob, ACTIVE_COLOR if active else MOVE_COLOR, 7.0)
	draw_circle(knob, 45.0, Color(ACTIVE_COLOR if active else MOVE_COLOR, 0.31))
	draw_arc(knob, 45.0, 0.0, TAU, 40, ACTIVE_COLOR if active else MOVE_COLOR, 5.0, true)


func _draw_action_controls() -> void:
	for action_id in ACTION_ORDER:
		var rect: Rect2 = action_rects[action_id]
		var pressed := control_pointers.has(action_id)
		var color := ACTIVE_COLOR if pressed else ACTION_COLOR
		draw_circle(rect.get_center(), rect.size.x * 0.5, Color(color, 0.30 if pressed else 0.20))
		draw_arc(rect.get_center(), rect.size.x * 0.5, 0.0, TAU, 44, color, 5.0, true)
		_draw_text_centered(_action_label(action_id), rect, 18, TEXT_COLOR)


func _action_label(action_id: StringName) -> String:
	if action_id == &"skill_1":
		return String(movement_metrics.get("skill_1_button_label", ACTION_LABELS[action_id]))
	if action_id == &"skill_2":
		return String(movement_metrics.get("skill_2_button_label", ACTION_LABELS[action_id]))
	if action_id == &"weapon_swap":
		return String(movement_metrics.get("weapon_switch_label", ACTION_LABELS[action_id]))
	return String(ACTION_LABELS[action_id])


func _draw_pointer_markers() -> void:
	for pointer_id in pointer_positions:
		var position: Vector2 = pointer_positions[pointer_id]
		draw_circle(position, 22.0, Color(TEXT_COLOR, 0.18))
		draw_arc(position, 22.0, 0.0, TAU, 28, TEXT_COLOR, 3.0, true)
		_draw_text("#%d" % int(pointer_id), position + Vector2(25.0, -16.0), 16)


func _draw_button(rect: Rect2, label: String, selected: bool) -> void:
	var fill := ACTIVE_COLOR if selected else Color("244c60")
	var text_color := BACKGROUND_COLOR if selected else TEXT_COLOR
	draw_rect(rect, fill, true)
	draw_rect(rect, Color(fill, 0.95), false, 3.0)
	_draw_text_centered(label, rect, 18, text_color)


func _draw_text(text: String, position: Vector2, font_size: int, color: Color = TEXT_COLOR) -> void:
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


func _append_action_log(message: String) -> void:
	action_log.push_front(message)
	if action_log.size() > 4:
		action_log.resize(4)


func _clamp_move_origin(position: Vector2) -> Vector2:
	return Vector2(
		clampf(position.x, move_zone.position.x + move_radius, move_zone.end.x - move_radius),
		clampf(position.y, move_zone.position.y + move_radius, move_zone.end.y - move_radius)
	)


func _safe_area_in_viewport() -> Rect2:
	var fallback_margin := maxf(24.0, minf(size.x, size.y) * 0.02)
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
