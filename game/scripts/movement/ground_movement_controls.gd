extends Control

## CP-304용 모바일 전투 HUD와 결과 화면.
## 안전 영역 안에 체력, 시간, 무기, 스킬, 필살기를 배치하고 완료 통계를 표시한다.

signal move_vector_changed(input_vector: Vector2)
signal jump_pressed
signal jump_released
signal evade_pressed
signal reset_requested
signal skill_1_pressed
signal skill_2_pressed
signal ultimate_pressed
signal weapon_swap_pressed
signal retry_requested

enum ScreenMode {
	COMBAT,
	RESULT,
	MAIN,
}

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
	&"ultimate": "새벽 0%",
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
var hud_rect := Rect2()
var result_panel_rect := Rect2()
var result_retry_rect := Rect2()
var result_main_rect := Rect2()
var main_start_rect := Rect2()
var action_log: Array[String] = []
var movement_metrics: Dictionary = {}
var result_snapshot: Dictionary = {}
var screen_mode: int = ScreenMode.COMBAT
var last_latency_msec: int = 0
var peak_simultaneous_controls: int = 0
var redraw_accumulator: float = 0.0
var last_invincibility_log_seen: String = ""
var last_fall_log_seen: String = ""
var last_target_key_seen: String = "없음"
var last_damage_log_seen: String = ""
var last_combat_log_seen: String = ""
var last_weapon_switch_log_seen: String = ""
var last_ultimate_log_seen: String = ""
var last_enemy_log_seen: String = ""
var last_stage_log_seen: String = ""


func _ready() -> void:
	Engine.max_fps = 60
	_refresh_layout()
	_append_action_log("CP-304 전투 HUD 시작")
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
		if screen_mode != ScreenMode.COMBAT:
			if touch.pressed:
				_handle_screen_touch(touch.position)
			queue_redraw()
			return
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
	if screen_mode == ScreenMode.RESULT:
		_draw_result_screen()
		return
	if screen_mode == ScreenMode.MAIN:
		_draw_main_screen()
		return
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


func update_ultimate_metrics(metrics: Dictionary) -> void:
	for key in metrics:
		movement_metrics[key] = metrics[key]
	var ultimate_log: String = String(metrics.get("ultimate_last_log", ""))
	if not ultimate_log.is_empty() \
	and ultimate_log != "게이지 충전 대기" \
	and ultimate_log != last_ultimate_log_seen:
		last_ultimate_log_seen = ultimate_log
		_append_action_log(ultimate_log)
	queue_redraw()


func update_enemy_metrics(metrics: Dictionary) -> void:
	for key in metrics:
		movement_metrics[key] = metrics[key]
	var enemy_log: String = String(metrics.get("enemy_last_log", ""))
	if not enemy_log.is_empty() \
	and enemy_log != "행동 대기" \
	and enemy_log != last_enemy_log_seen:
		last_enemy_log_seen = enemy_log
		_append_action_log(enemy_log)
	queue_redraw()


func update_stage_metrics(metrics: Dictionary) -> void:
	for key in metrics:
		movement_metrics[key] = metrics[key]
	var stage_log: String = String(metrics.get("stage_last_log", ""))
	if not stage_log.is_empty() and stage_log != last_stage_log_seen:
		last_stage_log_seen = stage_log
		_append_action_log(stage_log)
	if bool(metrics.get("stage_complete", false)) and screen_mode == ScreenMode.COMBAT:
		_show_result_screen()
	queue_redraw()


func begin_retry() -> void:
	release_all_inputs()
	result_snapshot.clear()
	screen_mode = ScreenMode.COMBAT
	retry_requested.emit()
	queue_redraw()


func show_main_screen() -> void:
	release_all_inputs()
	screen_mode = ScreenMode.MAIN
	queue_redraw()


func begin_stage_from_main() -> void:
	begin_retry()


func current_screen_mode() -> int:
	return screen_mode


func current_result_snapshot() -> Dictionary:
	return result_snapshot.duplicate(true)


func layout_snapshot() -> Dictionary:
	return {
		"safe": _safe_area_in_viewport(),
		"hud": hud_rect,
		"move": move_zone,
		"actions": action_rects.duplicate(),
		"result_panel": result_panel_rect,
	}


func _show_result_screen() -> void:
	release_all_inputs()
	var sword_hits := int(movement_metrics.get("sword_total_hits", 0))
	var bow_hits := int(movement_metrics.get("bow_total_hits", 0))
	var total_hits := sword_hits + bow_hits
	result_snapshot = {
		"completion_s": float(movement_metrics.get("stage_elapsed_s", 0.0)),
		"target_s": float(movement_metrics.get("stage_target_s", 180.0)),
		"actual_times": movement_metrics.get("stage_actual_times", []).duplicate(),
		"damage_causes": String(movement_metrics.get("damage_cause_summary", "피격 없음")),
		"sword_hits": sword_hits,
		"bow_hits": bow_hits,
		"sword_damage": int(movement_metrics.get("sword_total_damage", 0)),
		"bow_damage": int(movement_metrics.get("bow_total_damage", 0)),
		"sword_ratio": float(sword_hits) / float(total_hits) if total_hits > 0 else 0.0,
		"bow_ratio": float(bow_hits) / float(total_hits) if total_hits > 0 else 0.0,
	}
	screen_mode = ScreenMode.RESULT
	_refresh_layout()
	queue_redraw()


func _handle_screen_touch(position: Vector2) -> void:
	if screen_mode == ScreenMode.RESULT:
		if result_retry_rect.has_point(position):
			begin_retry()
		elif result_main_rect.has_point(position):
			show_main_screen()
	elif screen_mode == ScreenMode.MAIN and main_start_rect.has_point(position):
		begin_stage_from_main()


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
				ultimate_pressed.emit()
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
	var button_width := clampf(safe.size.x * 0.06, 72.0, 106.0)
	var button_height := clampf(safe.size.y * 0.045, 34.0, 42.0)
	var gap := 8.0
	var right := safe.end.x - 18.0
	var top := safe.position.y + 112.0
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

	hud_rect = Rect2(
		safe.position + Vector2(10.0, 10.0),
		Vector2(safe.size.x - 20.0, clampf(safe.size.y * 0.20, 132.0, 158.0))
	)
	var panel_size := Vector2(
		clampf(safe.size.x * 0.72, 760.0, 1060.0),
		clampf(safe.size.y * 0.68, 470.0, 650.0)
	)
	panel_size.x = minf(panel_size.x, safe.size.x - 32.0)
	panel_size.y = minf(panel_size.y, safe.size.y - 32.0)
	result_panel_rect = Rect2(safe.get_center() - panel_size * 0.5, panel_size)
	var result_button_size := Vector2(clampf(panel_size.x * 0.30, 190.0, 280.0), 62.0)
	var result_gap := 24.0
	var buttons_width := result_button_size.x * 2.0 + result_gap
	var buttons_x := result_panel_rect.get_center().x - buttons_width * 0.5
	var buttons_y := result_panel_rect.end.y - 86.0
	result_retry_rect = Rect2(Vector2(buttons_x, buttons_y), result_button_size)
	result_main_rect = Rect2(
		Vector2(buttons_x + result_button_size.x + result_gap, buttons_y),
		result_button_size
	)
	main_start_rect = Rect2(
		Vector2(result_panel_rect.get_center().x - 150.0, result_panel_rect.end.y - 106.0),
		Vector2(300.0, 68.0)
	)


func _draw_header() -> void:
	draw_style_box(_panel_style(Color(PANEL_COLOR, 0.91)), hud_rect)
	var section_index: int = int(movement_metrics.get("stage_section_index", 1))
	var section_count: int = int(movement_metrics.get("stage_section_count", 5))
	var section_name: String = String(movement_metrics.get("stage_section_name", "전진 1"))
	var stage_elapsed: float = float(movement_metrics.get("stage_elapsed_s", 0.0))
	var stage_target: float = float(movement_metrics.get("stage_target_s", 180.0))
	var left_x := hud_rect.position.x + 20.0
	var center_x := hud_rect.position.x + hud_rect.size.x * 0.34
	var right_x := hud_rect.position.x + hud_rect.size.x * 0.62
	var top_y := hud_rect.position.y + 34.0

	var health: int = int(movement_metrics.get("health", 100))
	var max_health: int = maxi(1, int(movement_metrics.get("max_health", 100)))
	_draw_text("체력  %d / %d" % [health, max_health], Vector2(left_x, top_y), 23, TEXT_COLOR)
	var health_bar := Rect2(Vector2(left_x, top_y + 14.0), Vector2(hud_rect.size.x * 0.27, 18.0))
	draw_rect(health_bar, Color("0d202b"), true)
	draw_rect(
		Rect2(health_bar.position, Vector2(health_bar.size.x * clampf(float(health) / float(max_health), 0.0, 1.0), health_bar.size.y)),
		Color("69d06f") if health > max_health * 0.3 else Color("ef6f6c"),
		true
	)
	var target_health := String(movement_metrics.get("combat_target_health", "대상 없음"))
	_draw_text(target_health, Vector2(left_x, top_y + 62.0), 17, MUTED_TEXT_COLOR)

	_draw_text(
		"%s  %d/%d" % [
			section_name,
			section_index,
			section_count,
		],
		Vector2(center_x, top_y),
		22,
		TEXT_COLOR
	)
	var stage_objective: String = String(movement_metrics.get("stage_objective", "첫 관문까지 전진"))
	_draw_text("%s / %s" % [_format_clock(stage_elapsed), _format_clock(stage_target)], Vector2(center_x, top_y + 31.0), 25, ACTIVE_COLOR)
	_draw_text(stage_objective, Vector2(center_x, top_y + 62.0), 16, MUTED_TEXT_COLOR)

	var weapon_name: String = String(movement_metrics.get("weapon_name", "연습용 검"))
	var skill_1_name: String = String(movement_metrics.get("skill_1_name", "스킬 1"))
	var skill_2_name: String = String(movement_metrics.get("skill_2_name", "스킬 2"))
	var skill_1_cd: float = float(movement_metrics.get("skill_1_cooldown_s", 0.0))
	var skill_2_cd: float = float(movement_metrics.get("skill_2_cooldown_s", 0.0))
	_draw_text("무기  %s" % weapon_name, Vector2(right_x, top_y), 21, TEXT_COLOR)
	_draw_text("%s %.1fs  ·  %s %.1fs" % [skill_1_name, skill_1_cd, skill_2_name, skill_2_cd], Vector2(right_x, top_y + 30.0), 16, MUTED_TEXT_COLOR)
	var ultimate_gauge: int = int(movement_metrics.get("ultimate_gauge", 0))
	var ultimate_active: bool = bool(movement_metrics.get("ultimate_active", false))
	_draw_text(
		"필살기  %s" % ("발동 중" if ultimate_active else "%d%%" % ultimate_gauge),
		Vector2(right_x, top_y + 60.0),
		17,
		ACTIVE_COLOR if ultimate_active or ultimate_gauge >= 100 else TEXT_COLOR
	)

	_draw_button(fps_60_rect, "60", Engine.max_fps == 60)
	_draw_button(fps_30_rect, "30", Engine.max_fps == 30)
	_draw_button(reset_rect, "재설정", false)


func _draw_action_log(panel_rect: Rect2) -> void:
	var x := panel_rect.position.x + panel_rect.size.x * 0.62
	var y := panel_rect.position.y + 92.0
	for line in action_log:
		_draw_text(line, Vector2(x, y), 16, MUTED_TEXT_COLOR)
		y += 24.0
		if y > panel_rect.end.y - 14.0:
			break


func _draw_result_screen() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(BACKGROUND_COLOR, 0.88), true)
	draw_style_box(_panel_style(Color(PANEL_COLOR, 0.98)), result_panel_rect)
	_draw_text_centered(
		"스테이지 완료",
		Rect2(Vector2(result_panel_rect.position.x, result_panel_rect.position.y + 24.0), Vector2(result_panel_rect.size.x, 58.0)),
		36,
		PASS_COLOR
	)
	var completion_s := float(result_snapshot.get("completion_s", 0.0))
	var target_s := float(result_snapshot.get("target_s", 180.0))
	_draw_text_centered(
		"완료 %s  ·  목표 %s  ·  %s" % [
			_format_clock(completion_s),
			_format_clock(target_s),
			"목표 이내" if completion_s <= target_s else "+%s" % _format_clock(completion_s - target_s),
		],
		Rect2(Vector2(result_panel_rect.position.x, result_panel_rect.position.y + 84.0), Vector2(result_panel_rect.size.x, 42.0)),
		24,
		TEXT_COLOR
	)
	var content_x := result_panel_rect.position.x + 54.0
	var content_width := result_panel_rect.size.x - 108.0
	var y := result_panel_rect.position.y + 158.0
	_draw_result_row("구간 기록", _section_time_summary(), content_x, content_width, y)
	y += 66.0
	_draw_result_row("피격 원인", String(result_snapshot.get("damage_causes", "피격 없음")), content_x, content_width, y)
	y += 66.0
	var sword_ratio := float(result_snapshot.get("sword_ratio", 0.0)) * 100.0
	var bow_ratio := float(result_snapshot.get("bow_ratio", 0.0)) * 100.0
	var total_hits := int(result_snapshot.get("sword_hits", 0)) + int(result_snapshot.get("bow_hits", 0))
	var usage := "기록 없음" if total_hits == 0 else "검 %.0f%% · 활 %.0f%%" % [sword_ratio, bow_ratio]
	_draw_result_row("무기 사용 비율", usage, content_x, content_width, y)
	y += 66.0
	_draw_result_row(
		"전투 기록",
		"검 %d회 / 피해 %d  ·  활 %d회 / 피해 %d" % [
			int(result_snapshot.get("sword_hits", 0)),
			int(result_snapshot.get("sword_damage", 0)),
			int(result_snapshot.get("bow_hits", 0)),
			int(result_snapshot.get("bow_damage", 0)),
		],
		content_x,
		content_width,
		y
	)
	_draw_button(result_retry_rect, "다시 도전", true)
	_draw_button(result_main_rect, "메인 화면", false)


func _draw_main_screen() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(BACKGROUND_COLOR, 0.92), true)
	draw_style_box(_panel_style(Color(PANEL_COLOR, 0.98)), result_panel_rect)
	_draw_text_centered(
		"행복 이야기",
		Rect2(Vector2(result_panel_rect.position.x, result_panel_rect.position.y + 96.0), Vector2(result_panel_rect.size.x, 80.0)),
		44,
		ACTIVE_COLOR
	)
	_draw_text_centered(
		"3분 전투 스테이지",
		Rect2(Vector2(result_panel_rect.position.x, result_panel_rect.position.y + 188.0), Vector2(result_panel_rect.size.x, 46.0)),
		25,
		TEXT_COLOR
	)
	_draw_text_centered(
		"검과 활을 전환하며 다섯 구간을 돌파하세요.",
		Rect2(Vector2(result_panel_rect.position.x, result_panel_rect.position.y + 244.0), Vector2(result_panel_rect.size.x, 40.0)),
		19,
		MUTED_TEXT_COLOR
	)
	_draw_button(main_start_rect, "스테이지 시작", true)


func _draw_result_row(label: String, value: String, x: float, width: float, y: float) -> void:
	draw_rect(Rect2(Vector2(x, y - 26.0), Vector2(width, 52.0)), Color("102b3a"), true)
	_draw_text(label, Vector2(x + 18.0, y + 7.0), 18, MUTED_TEXT_COLOR)
	_draw_text(value, Vector2(x + width * 0.27, y + 7.0), 19, TEXT_COLOR)


func _section_time_summary() -> String:
	var actual_times: Array = result_snapshot.get("actual_times", [])
	if actual_times.is_empty():
		return "기록 없음"
	var parts: Array[String] = []
	for index in actual_times.size():
		parts.append("%d구간 %.1fs" % [index + 1, float(actual_times[index])])
	return " · ".join(parts)


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
		var ultimate_ready := action_id == &"ultimate" \
			and bool(movement_metrics.get("ultimate_ready", false))
		var ultimate_active := action_id == &"ultimate" \
			and bool(movement_metrics.get("ultimate_active", false))
		var color := ACTIVE_COLOR if pressed or ultimate_ready or ultimate_active else ACTION_COLOR
		draw_circle(rect.get_center(), rect.size.x * 0.5, Color(color, 0.30 if pressed else 0.20))
		draw_arc(rect.get_center(), rect.size.x * 0.5, 0.0, TAU, 44, color, 5.0, true)
		if action_id == &"ultimate":
			var ratio: float = float(movement_metrics.get("ultimate_gauge_ratio", 0.0))
			if ultimate_active:
				var duration: float = float(movement_metrics.get("ultimate_duration_s", 3.0))
				var remaining: float = float(movement_metrics.get("ultimate_remaining_s", 0.0))
				ratio = remaining / maxf(duration, 0.001)
			draw_arc(
				rect.get_center(), rect.size.x * 0.5 - 10.0,
				-PI * 0.5, -PI * 0.5 + TAU * clampf(ratio, 0.0, 1.0),
				48, ACTIVE_COLOR, 9.0, true
			)
		_draw_text_centered(_action_label(action_id), rect, 18, TEXT_COLOR)


func _action_label(action_id: StringName) -> String:
	if action_id == &"skill_1":
		return String(movement_metrics.get("skill_1_button_label", ACTION_LABELS[action_id]))
	if action_id == &"skill_2":
		return String(movement_metrics.get("skill_2_button_label", ACTION_LABELS[action_id]))
	if action_id == &"weapon_swap":
		return String(movement_metrics.get("weapon_switch_label", ACTION_LABELS[action_id]))
	if action_id == &"ultimate":
		if bool(movement_metrics.get("ultimate_active", false)):
			return "새벽 %.1f" % float(movement_metrics.get("ultimate_remaining_s", 0.0))
		if bool(movement_metrics.get("ultimate_ready", false)):
			return "새벽 준비"
		return "새벽 %d%%" % int(movement_metrics.get("ultimate_gauge", 0))
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


func _format_clock(value: float) -> String:
	var total_seconds := maxi(0, int(floor(value)))
	return "%d:%02d" % [int(total_seconds / 60), total_seconds % 60]
