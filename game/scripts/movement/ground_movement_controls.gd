extends Control

## GP-103 직업 필살기·성장 선택, 모바일 전투 HUD와 Android 검증 표시.

signal move_vector_changed(input_vector: Vector2)
signal jump_pressed
signal jump_released
signal evade_pressed
signal reset_requested
signal skill_1_pressed
signal skill_2_pressed
signal ultimate_pressed
signal recovery_potion_pressed
signal weapon_swap_pressed
signal retry_requested
signal layout_test_started
signal layout_test_finished
signal combat_configuration_started
signal combat_configuration_finished
signal feedback_settings_changed(
	sound_volume: float,
	vibration_enabled: bool,
	screen_shake_enabled: bool
)
signal test_records_clear_requested
signal growth_card_selected(index: int)
signal growth_reroll_requested
signal job_confirmed(ultimate_index: int)
signal stage_route_selected(route: String)
signal continue_requested
signal skill_reward_selected(id: String, slot: int)
signal weapon_reward_selected(weapon_id: String)
signal boss_choice_confirmed(choice: String)
signal relic_reward_selected
signal potion_recipe_selected(id: String)

enum ScreenMode {
	COMBAT,
	RESULT,
	MAIN,
	LAYOUT_EDITOR,
	LAYOUT_TEST,
	COMBAT_RESUME_COUNTDOWN,
	FEEDBACK_SETTINGS,
	GROWTH_SELECTION,
	JOB_MANIFESTATION,
	STAGE_ROUTE,
	START_WEAPON,
	WEAPON_REWARD,
	BOSS_CHOICE,
	VILLAGE,
	SKILL_REWARD,
	RELIC_REWARD,
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
const ANDROID_VALIDATION_TARGET_RUNS := 10
const ANDROID_VALIDATION_TARGET_SESSION_S := 20.0 * 60.0

const MOVE_CONTROL: StringName = &"move"
const PRESET_DEFAULT := "default"
const PRESET_LEFT := "left"
const PRESET_CUSTOM := "custom"
const DEFAULT_CONTROL_CENTERS := {
	&"move": Vector2(0.15, 0.80),
	&"jump": Vector2(0.925, 0.815),
	&"evade": Vector2(0.825, 0.830),
	&"skill_1": Vector2(0.795, 0.650),
	&"skill_2": Vector2(0.905, 0.600),
	&"ultimate": Vector2(0.680, 0.665),
	&"weapon_swap": Vector2(0.690, 0.845),
	&"recovery_potion": Vector2(0.400, 0.850),
}
const LEFT_CONTROL_CENTERS := {
	&"move": Vector2(0.85, 0.80),
	&"jump": Vector2(0.075, 0.815),
	&"evade": Vector2(0.175, 0.830),
	&"skill_1": Vector2(0.205, 0.650),
	&"skill_2": Vector2(0.095, 0.600),
	&"ultimate": Vector2(0.320, 0.665),
	&"weapon_swap": Vector2(0.310, 0.845),
	&"recovery_potion": Vector2(0.600, 0.850),
}
const ACTION_ORDER: Array[StringName] = [
	&"jump",
	&"evade",
	&"skill_2",
	&"skill_1",
	&"ultimate",
	&"weapon_swap",
	&"recovery_potion",
]
const ACTION_LABELS := {
	&"jump": "점프",
	&"evade": "회피",
	&"skill_1": "돌진",
	&"skill_2": "회전",
	&"ultimate": "새벽 0%",
	&"weapon_swap": "전환",
	&"recovery_potion": "회복약",
}
const ACTION_TYPES := {
	&"jump": PlayerCommand.Type.JUMP,
	&"evade": PlayerCommand.Type.EVADE,
	&"skill_1": PlayerCommand.Type.SKILL_1,
	&"skill_2": PlayerCommand.Type.SKILL_2,
	&"ultimate": PlayerCommand.Type.ULTIMATE,
	&"weapon_swap": PlayerCommand.Type.WEAPON_SWAP,
	&"recovery_potion": PlayerCommand.Type.RECOVERY_POTION,
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
var combat_layout_rect := Rect2()
var hud_rect := Rect2()
var result_panel_rect := Rect2()
var result_retry_rect := Rect2()
var result_main_rect := Rect2()
var main_start_rect := Rect2()
var main_continue_rect := Rect2()
var checkpoint_available: bool = false
var checkpoint_message: String = ""
var main_village_rect: Rect2
var village_page: String = "village"
var village_environment_owned: bool = false
var preferred_potion_recipe: String = PrototypePotionRecipes.BASIC
var potion_recipe_message: String = ""
var main_layout_rect := Rect2()
var main_feedback_rect := Rect2()
var feedback_panel_rect := Rect2()
var feedback_sound_down_rect := Rect2()
var feedback_sound_up_rect := Rect2()
var feedback_vibration_rect := Rect2()
var feedback_shake_rect := Rect2()
var feedback_back_rect := Rect2()
var feedback_records_clear_rect := Rect2()
var editor_toolbar_rect := Rect2()
var editor_preset_default_rect := Rect2()
var editor_preset_left_rect := Rect2()
var editor_preset_custom_rect := Rect2()
var editor_size_down_rect := Rect2()
var editor_size_up_rect := Rect2()
var editor_opacity_down_rect := Rect2()
var editor_opacity_up_rect := Rect2()
var editor_test_rect := Rect2()
var editor_reset_rect := Rect2()
var editor_cancel_rect := Rect2()
var editor_apply_rect := Rect2()
var layout_test_exit_rect := Rect2()
var action_log: Array[String] = []
var movement_metrics: Dictionary = {}
var result_snapshot: Dictionary = {}
var screen_mode: int = ScreenMode.MAIN
var control_centers: Dictionary = DEFAULT_CONTROL_CENTERS.duplicate()
var control_scales: Dictionary = {}
var control_opacity: float = 0.82
var selected_layout_control: StringName = MOVE_CONTROL
var invalid_layout_controls: Array[StringName] = []
var editor_drag_pointer_id: int = -1
var editor_original_layout: Dictionary = {}
var editor_return_mode: int = ScreenMode.MAIN
var active_preset_id: String = PRESET_DEFAULT
var saved_custom_layout: Dictionary = {}
var layout_store := ControlLayoutStore.new()
var layout_store_message: String = ""
var layout_test_remaining_s: float = 0.0
var layout_test_input_counts: Dictionary = {}
var layout_test_peak_controls: int = 0
var combat_resume_remaining_s: float = 0.0
var feedback_sound_volume: float = 0.80
var feedback_vibration_enabled: bool = true
var feedback_screen_shake_enabled: bool = true
var test_record_summary: Dictionary = {}
var android_validation_session_s: float = 0.0
var android_validation_resume_count: int = 0
var android_validation_pause_count: int = 0
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
var growth_cards: Array[Dictionary] = []
var growth_card_rects: Array[Rect2] = []
var growth_reroll_rect := Rect2()
var growth_choice_level: int = 1
var growth_choice_rerolls: int = 1
var manifested_job: Dictionary = {}
var job_panel_rect := Rect2()
var job_confirm_rect := Rect2()
var job_ultimate_rects: Array[Rect2] = []
var job_ultimates: Array[Dictionary] = []
var selected_job_ultimate: int = -1
var skill_reward_open_rect: Rect2
var skill_reward_loadout: Dictionary = PrototypeSkillRewards.defaults()
var skill_reward_claimed: bool = true
var relic_offer_available: bool = false
var relic_reward_open_rect: Rect2
var relic_reward_card_rect: Rect2
var relic_reward_confirm_rect: Rect2
var relic_reward_cancel_rect: Rect2
var skill_reward_offers: Array[Dictionary] = []
var skill_reward_offer_rects: Array[Rect2] = []
var skill_reward_slot_rects: Array[Rect2] = []
var skill_reward_confirm_rect: Rect2
var skill_reward_cancel_rect: Rect2
var selected_skill_offer: int = -1
var selected_skill_slot: int = -1
var stage_route_rects: Array[Rect2] = []
var stage_route_options: Array[Dictionary] = PrototypeStageRunner.ROUTES.duplicate(true)
var cleared_stage: int = 1
var run_stage_count: int = 3
var stage_recovered_health: int = 0
var discovered_jobs: Dictionary = {}
var job_codex_message: String = ""
var unlocked_memories: Dictionary = {}
var unlocked_weapon_blueprints: Dictionary = {}
var preferred_memory_id: String = ""
var selected_memory_id: String = ""
var active_memory_id: String = ""
var start_memory_previous_selection: String = ""
var memory_card_rects: Array[Rect2] = []
var pending_boss_legacy: Dictionary = {}
var active_boss_legacy: Dictionary = {}
var use_boss_legacy: bool = false
var boss_legacy_toggle_rect := Rect2()
var selected_starting_weapon: String = "sword"
var start_weapon_previous_selection: String = "sword"
var start_weapon_return_mode: int = ScreenMode.MAIN
var start_weapon_card_rects: Array[Rect2] = []
var start_weapon_confirm_rect := Rect2()
var start_weapon_cancel_rect := Rect2()
var weapon_reward_cards: Array[Dictionary] = []
var weapon_reward_rects: Array[Rect2] = []
var weapon_reward_confirm_rect := Rect2()
var weapon_reward_skip_rect := Rect2()
var selected_weapon_reward: int = -1
var weapon_reward_stage: int = 1
var boss_choice_rects: Array[Rect2] = []
var boss_choice_confirm_rect := Rect2()
var selected_boss_choice: int = -1


func _ready() -> void:
	Engine.max_fps = 60
	for control_id in _layout_control_order():
		control_scales[control_id] = 1.0
	_load_saved_control_layout()
	_refresh_layout()
	_append_action_log("GP-104 연속 스테이지 시제품 준비")
	queue_redraw()


func _process(delta: float) -> void:
	_update_mode_timer(delta)
	android_validation_session_s += delta
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
		_validate_control_layout()
		queue_redraw()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		android_validation_pause_count += 1
		release_all_inputs()
		_append_action_log("앱 비활성화 · 입력 초기화")
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		android_validation_resume_count += 1
		_append_action_log("앱 복귀 · 입력 상태 정상")


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if screen_mode == ScreenMode.LAYOUT_EDITOR:
			_handle_editor_touch(touch)
			queue_redraw()
			return
		if screen_mode == ScreenMode.LAYOUT_TEST:
			_handle_layout_test_touch(touch)
			queue_redraw()
			return
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
		if screen_mode == ScreenMode.LAYOUT_EDITOR:
			_handle_editor_drag(drag.index, drag.position)
		elif screen_mode == ScreenMode.LAYOUT_TEST:
			_handle_touch_dragged(drag.index, drag.position)
		elif screen_mode == ScreenMode.COMBAT:
			_handle_touch_dragged(drag.index, drag.position)
		queue_redraw()


func _draw() -> void:
	if screen_mode == ScreenMode.RELIC_REWARD:
		_draw_relic_rewards()
		return
	if screen_mode == ScreenMode.SKILL_REWARD:
		_draw_skill_rewards()
		return
	if screen_mode == ScreenMode.VILLAGE:
		_draw_village()
		return
	if screen_mode == ScreenMode.BOSS_CHOICE:
		_draw_boss_choice()
		return
	if screen_mode == ScreenMode.WEAPON_REWARD:
		_draw_weapon_rewards()
		return
	if screen_mode == ScreenMode.START_WEAPON:
		_draw_start_weapon_selection()
		return
	if screen_mode == ScreenMode.STAGE_ROUTE:
		_draw_stage_routes()
		return
	if screen_mode == ScreenMode.JOB_MANIFESTATION:
		_draw_job_manifestation()
		return
	if screen_mode == ScreenMode.GROWTH_SELECTION:
		_draw_growth_choices()
		return
	if screen_mode == ScreenMode.RESULT:
		_draw_result_screen()
		return
	if screen_mode == ScreenMode.MAIN:
		_draw_main_screen()
		return
	if screen_mode == ScreenMode.LAYOUT_EDITOR:
		_draw_layout_editor()
		return
	if screen_mode == ScreenMode.LAYOUT_TEST:
		_draw_layout_test()
		return
	if screen_mode == ScreenMode.COMBAT_RESUME_COUNTDOWN:
		_draw_combat_resume_countdown()
		return
	if screen_mode == ScreenMode.FEEDBACK_SETTINGS:
		_draw_feedback_settings()
		return
	_draw_header()
	_draw_move_control()
	_draw_action_controls()
	_draw_pointer_markers()


func update_growth_metrics(metrics: Dictionary) -> void:
	for key in metrics:
		movement_metrics[key] = metrics[key]
	queue_redraw()


func show_growth_choices(cards: Array[Dictionary], level: int, rerolls: int) -> void:
	release_all_inputs()
	growth_cards = cards.duplicate(true)
	growth_choice_level = level
	growth_choice_rerolls = rerolls
	screen_mode = ScreenMode.GROWTH_SELECTION
	_refresh_growth_layout()
	queue_redraw()


func show_job_manifestation(job: Dictionary) -> void:
	release_all_inputs()
	manifested_job = job.duplicate()
	job_ultimates = PrototypeJobRewards.ultimates_for(String(job["id"]))
	selected_job_ultimate = -1
	screen_mode = ScreenMode.JOB_MANIFESTATION
	_refresh_job_layout()
	queue_redraw()


func _refresh_job_layout() -> void:
	var safe := _safe_area_in_viewport()
	var panel_size := Vector2(minf(1080.0, safe.size.x * 0.94), safe.size.y * 0.90)
	job_panel_rect = Rect2(safe.get_center() - panel_size * 0.5, panel_size)
	var button_size := Vector2(minf(320.0, panel_size.x * 0.60), minf(68.0, panel_size.y * 0.14))
	job_confirm_rect = Rect2(job_panel_rect.position + Vector2((panel_size.x - button_size.x) * 0.5, panel_size.y * 0.84), button_size)
	job_ultimate_rects.clear()
	var card_width := (panel_size.x - 72.0) * 0.5
	for index in 2:
		job_ultimate_rects.append(Rect2(job_panel_rect.position + Vector2(24.0 + index * (card_width + 24.0), panel_size.y * 0.43), Vector2(card_width, panel_size.y * 0.34)))


func _draw_job_manifestation() -> void:
	_refresh_job_layout()
	draw_rect(Rect2(Vector2.ZERO, size), Color(BACKGROUND_COLOR, 0.96), true)
	draw_style_box(_panel_style(PANEL_COLOR), job_panel_rect)
	var color: Color = manifested_job.get("color", ACTIVE_COLOR)
	var headings := ["직업이 발현되었습니다", String(manifested_job.get("name", "")), String(manifested_job.get("passive", "")), job_codex_message if not job_codex_message.is_empty() else "이번 도전의 필살기를 하나 선택하세요"]
	var sizes := [20, 34, 19, 18]
	var offsets := [0.02, 0.12, 0.23, 0.32]
	for index in headings.size():
		_draw_text_centered(headings[index], Rect2(job_panel_rect.position + Vector2(0.0, job_panel_rect.size.y * offsets[index]), Vector2(job_panel_rect.size.x, 50.0)), sizes[index], color if index == 1 else TEXT_COLOR)
	for index in job_ultimates.size():
		var rect := job_ultimate_rects[index]
		var candidate := job_ultimates[index]
		draw_style_box(_panel_style(Color("254f51") if selected_job_ultimate == index else PANEL_COLOR), rect)
		_draw_text_centered(("✓ " if selected_job_ultimate == index else "") + String(candidate["name"]), Rect2(rect.position + Vector2(0.0, rect.size.y * 0.10), Vector2(rect.size.x, 34.0)), 22, color)
		for line_index in candidate["lines"].size():
			_draw_text_centered(String(candidate["lines"][line_index]), Rect2(rect.position + Vector2(0.0, rect.size.y * 0.40 + line_index * 32.0), Vector2(rect.size.x, 30.0)), 17, TEXT_COLOR)
	_draw_button(job_confirm_rect, "확인 · 계속하기" if selected_job_ultimate >= 0 else "필살기를 선택하세요", selected_job_ultimate >= 0)


func finish_growth_selection() -> void:
	release_all_inputs()
	growth_cards.clear()
	if screen_mode in [ScreenMode.GROWTH_SELECTION, ScreenMode.JOB_MANIFESTATION, ScreenMode.STAGE_ROUTE, ScreenMode.WEAPON_REWARD, ScreenMode.BOSS_CHOICE]:
		screen_mode = ScreenMode.COMBAT
	manifested_job.clear()
	job_ultimates.clear()
	selected_job_ultimate = -1
	queue_redraw()


func show_boss_choice() -> void:
	release_all_inputs()
	selected_boss_choice = -1
	screen_mode = ScreenMode.BOSS_CHOICE
	_refresh_boss_choice_layout()
	queue_redraw()


func _refresh_boss_choice_layout() -> void:
	var safe := _safe_area_in_viewport()
	var gap := minf(32.0, safe.size.x * 0.03)
	var width := (safe.size.x * 0.90 - gap) * 0.5
	boss_choice_rects.clear()
	for index in 2:
		boss_choice_rects.append(Rect2(safe.position + Vector2(safe.size.x * 0.05 + index * (width + gap), safe.size.y * 0.31), Vector2(width, safe.size.y * 0.39)))
	var button_width := minf(360.0, safe.size.x * 0.55)
	boss_choice_confirm_rect = Rect2(safe.position + Vector2((safe.size.x - button_width) * 0.5, safe.size.y * 0.84), Vector2(button_width, safe.size.y * 0.09))


func _draw_boss_choice() -> void:
	_refresh_boss_choice_layout()
	var safe := _safe_area_in_viewport()
	draw_rect(Rect2(Vector2.ZERO, size), Color(BACKGROUND_COLOR, 0.96), true)
	_draw_text_centered("보스 승리 · 웃는 태엽 기사", Rect2(safe.position + Vector2(0, safe.size.y * 0.06), Vector2(safe.size.x, 48)), 30, PASS_COLOR)
	_draw_text_centered("기사는 사람들을 돌려보내라는 태엽 명령에 묶여 있었습니다.", Rect2(safe.position + Vector2(0, safe.size.y * 0.18), Vector2(safe.size.x, 32)), 20, TEXT_COLOR)
	_draw_text_centered("이제 기사의 운명을 선택하세요.", Rect2(safe.position + Vector2(0, safe.size.y * 0.24), Vector2(safe.size.x, 30)), 19, MUTED_TEXT_COLOR)
	var cards := [{"title": "구출", "lines": ["기사를 자유롭게 합니다.", "태엽 수호 영구 해금 · 체력 +5", "다음 도전 1회 · 체력 +10", "정예 지원 · 위기 회복 1회"]}, {"title": "파괴", "lines": ["태엽 검·활 설계도 영구 해금", "핵의 잔향 영구 해금 · 스킬 +10%", "다음 도전 1회 · 피해 +10%", "피격 +10% · 다음 도전 위험 길"]}]
	for index in cards.size():
		var card: Dictionary = cards[index]
		var rect := boss_choice_rects[index]
		draw_style_box(_panel_style(PANEL_COLOR), rect)
		if selected_boss_choice == index:
			draw_rect(rect.grow(-3), ACTIVE_COLOR, false, 4)
		_draw_text_centered(String(card.title), Rect2(rect.position + Vector2(0, rect.size.y * 0.10), Vector2(rect.size.x, 42)), 28, ACTIVE_COLOR)
		for line in card.lines.size():
			_draw_text_centered(String(card.lines[line]), Rect2(rect.position + Vector2(0, rect.size.y * (0.30 + line * 0.16)), Vector2(rect.size.x, 30)), 19, TEXT_COLOR)
	var note := checkpoint_message if checkpoint_message.begins_with("중간 저장 실패") else "선택 후 확정하세요 · 다른 도전에서는 다시 선택할 수 있습니다."
	_draw_text_centered(note, Rect2(safe.position + Vector2(0, safe.size.y * 0.75), Vector2(safe.size.x, 32)), 18, MUTED_TEXT_COLOR)
	_draw_button(boss_choice_confirm_rect, "선택 확정 · 도전 완료" if selected_boss_choice >= 0 else "구출 또는 파괴를 선택하세요", selected_boss_choice >= 0)


func show_weapon_rewards(stage: int, cards: Array[Dictionary]) -> void:
	release_all_inputs()
	weapon_reward_stage = stage
	weapon_reward_cards = cards.duplicate(true)
	selected_weapon_reward = -1
	screen_mode = ScreenMode.WEAPON_REWARD
	_refresh_weapon_reward_layout()
	queue_redraw()


func _refresh_weapon_reward_layout() -> void:
	var safe := _safe_area_in_viewport()
	var gap := minf(32.0, safe.size.x * 0.03)
	var count := maxi(2, weapon_reward_cards.size())
	var width := (safe.size.x * 0.90 - gap * (count - 1)) / count
	weapon_reward_rects.clear()
	for index in count:
		weapon_reward_rects.append(Rect2(safe.position + Vector2(safe.size.x * 0.05 + index * (width + gap), safe.size.y * 0.27), Vector2(width, safe.size.y * 0.42)))
	var button_width := minf(360.0, safe.size.x * 0.55)
	weapon_reward_confirm_rect = Rect2(safe.position + Vector2((safe.size.x - button_width) * 0.5, safe.size.y * 0.80), Vector2(button_width, safe.size.y * 0.08))
	weapon_reward_skip_rect = Rect2(safe.position + Vector2((safe.size.x - button_width) * 0.5, safe.size.y * 0.91), Vector2(button_width, safe.size.y * 0.06))


func _draw_weapon_rewards() -> void:
	_refresh_weapon_reward_layout()
	var safe := _safe_area_in_viewport()
	draw_rect(Rect2(Vector2.ZERO, size), Color(BACKGROUND_COLOR, 0.96), true)
	_draw_text_centered("정예 처치 · 무기 보상", Rect2(safe.position + Vector2(0, safe.size.y * 0.06), Vector2(safe.size.x, 50)), 32, PASS_COLOR)
	_draw_text_centered("설계도 무기: 일반 피해 감소 · 고유 효과 강화" if weapon_reward_cards.size() > 2 else "검·활 중 하나 교체 · 무기와 스킬 대기시간 유지", Rect2(safe.position + Vector2(0, safe.size.y * 0.17), Vector2(safe.size.x, 36)), 20, MUTED_TEXT_COLOR)
	for index in weapon_reward_cards.size():
		var item := weapon_reward_cards[index]
		var rect := weapon_reward_rects[index]
		draw_style_box(_panel_style(PANEL_COLOR), rect)
		if selected_weapon_reward == index:
			draw_rect(rect.grow(-3), ACTIVE_COLOR, false, 4)
		_draw_text_centered(String(item.name), Rect2(rect.position + Vector2(0, rect.size.y * 0.10), Vector2(rect.size.x, 40)), 22 if weapon_reward_cards.size() > 2 else 27, ACTIVE_COLOR)
		_draw_text_centered("현재: %s" % String(item.previous_name), Rect2(rect.position + Vector2(0, rect.size.y * 0.27), Vector2(rect.size.x, 30)), 15 if weapon_reward_cards.size() > 2 else 17, MUTED_TEXT_COLOR)
		for line in item.lines.size():
			_draw_text_centered(String(item.lines[line]), Rect2(rect.position + Vector2(0, rect.size.y * (0.44 + line * 0.16)), Vector2(rect.size.x, 30)), 18, TEXT_COLOR)
	var reward_note := checkpoint_message if checkpoint_message.begins_with("중간 저장 실패") else "보조 무기의 고유 효과는 50% 적용 · 등급 피해는 주 무기만"
	if movement_metrics.get("run_route_id", "") == "clockwork" and not checkpoint_message.begins_with("중간 저장 실패"):
		reward_note = "태엽 폐허 통과 · 체력 +20 / 필살기 +50 추가 지급 (상한 적용)"
	_draw_text_centered(reward_note, Rect2(safe.position + Vector2(0, safe.size.y * 0.72), Vector2(safe.size.x, 30)), 18, MUTED_TEXT_COLOR)
	_draw_button(weapon_reward_confirm_rect, "선택한 무기로 교체" if selected_weapon_reward >= 0 else "무기를 선택하세요", selected_weapon_reward >= 0)
	_draw_button(weapon_reward_skip_rect, "현재 무기 유지", false)


func show_stage_routes(stage: int, stage_count: int, recovered_health: int, routes: Array[Dictionary] = PrototypeStageRunner.ROUTES) -> void:
	release_all_inputs()
	stage_route_options = routes.duplicate(true)
	cleared_stage = stage
	run_stage_count = stage_count
	stage_recovered_health = recovered_health
	screen_mode = ScreenMode.STAGE_ROUTE
	_refresh_stage_routes()
	queue_redraw()


func _refresh_stage_routes() -> void:
	var safe := _safe_area_in_viewport()
	var gap := minf(32.0, safe.size.x * 0.03)
	var count := stage_route_options.size()
	var card_width := (safe.size.x * 0.90 - gap * (count - 1)) / count
	skill_reward_open_rect = Rect2(safe.position + Vector2(safe.size.x * 0.5 - 140.0, safe.size.y * 0.81), Vector2(280.0, safe.size.y * 0.08))
	relic_reward_open_rect = Rect2()
	if relic_offer_available:
		skill_reward_open_rect = Rect2(safe.position + Vector2(safe.size.x * 0.05, safe.size.y * 0.81), Vector2(safe.size.x * 0.43, safe.size.y * 0.08))
		relic_reward_open_rect = Rect2(safe.position + Vector2(safe.size.x * 0.52, safe.size.y * 0.81), skill_reward_open_rect.size)
	stage_route_rects.clear()
	for index in count:
		stage_route_rects.append(Rect2(safe.position + Vector2(safe.size.x * 0.05 + index * (card_width + gap), safe.size.y * 0.43), Vector2(card_width, safe.size.y * 0.35)))


func _draw_stage_routes() -> void:
	_refresh_stage_routes()
	var safe := _safe_area_in_viewport()
	draw_rect(Rect2(Vector2.ZERO, size), Color(BACKGROUND_COLOR, 0.96), true)
	_draw_text_centered("스테이지 %d/%d 완료" % [cleared_stage, run_stage_count], Rect2(safe.position + Vector2(0, safe.size.y * 0.08), Vector2(safe.size.x, 50)), 32, PASS_COLOR)
	_draw_text_centered("체력 +%d 회복 · 현재 %d/%d" % [stage_recovered_health, int(movement_metrics.get("health", 0)), int(movement_metrics.get("max_health", 100))], Rect2(safe.position + Vector2(0, safe.size.y * 0.20), Vector2(safe.size.x, 40)), 22, TEXT_COLOR)
	_draw_text_centered("성장을 유지하고 다음 경로를 선택하세요", Rect2(safe.position + Vector2(0, safe.size.y * 0.30), Vector2(safe.size.x, 40)), 20, MUTED_TEXT_COLOR)
	for index in stage_route_options.size():
		var rect := stage_route_rects[index]
		var route := stage_route_options[index]
		draw_style_box(_panel_style(PANEL_COLOR), rect)
		_draw_text_centered(String(route["name"]), Rect2(rect.position + Vector2(0, rect.size.y * 0.12), Vector2(rect.size.x, 40)), 28, ACTIVE_COLOR)
		for line_index in route["lines"].size():
			_draw_text_centered(String(route["lines"][line_index]), Rect2(rect.position + Vector2(0, rect.size.y * (0.40 + 0.18 * line_index)), Vector2(rect.size.x, 32)), 18, TEXT_COLOR)
	if not skill_reward_claimed:
		_draw_button(skill_reward_open_rect, "스킬 교체 살펴보기", true)
	else:
		_draw_text_centered("스킬 교체 완료", skill_reward_open_rect, 18, MUTED_TEXT_COLOR)
	if relic_offer_available:
		_draw_button(relic_reward_open_rect, "유물 · 불사조 깃털", true)
	if not checkpoint_message.is_empty():
		_draw_text_centered(checkpoint_message, Rect2(safe.position + Vector2(0, safe.size.y * 0.91), Vector2(safe.size.x, 28)), 16, PASS_COLOR if checkpoint_available else WAIT_COLOR)


func _refresh_growth_layout() -> void:
	var safe := _safe_area_in_viewport()
	var margin := minf(40.0, safe.size.x * 0.04)
	var gap := minf(24.0, safe.size.x * 0.025)
	var card_width := (safe.size.x - margin * 2.0 - gap * 2.0) / 3.0
	var card_height := safe.size.y * 0.40
	growth_card_rects.clear()
	for index in 3:
		growth_card_rects.append(Rect2(safe.position + Vector2(margin + index * (card_width + gap), safe.size.y * 0.30), Vector2(card_width, card_height)))
	var button_size := Vector2(minf(340.0, safe.size.x * 0.5), minf(68.0, safe.size.y * 0.12))
	growth_reroll_rect = Rect2(safe.position + Vector2((safe.size.x - button_size.x) * 0.5, safe.size.y * 0.78), button_size)


func _draw_growth_choices() -> void:
	_refresh_growth_layout()
	var safe := _safe_area_in_viewport()
	draw_rect(Rect2(Vector2.ZERO, size), Color(BACKGROUND_COLOR, 0.96), true)
	_draw_text_centered("레벨 %d · 능력 하나를 선택하세요" % growth_choice_level, Rect2(safe.position + Vector2(0.0, safe.size.y * 0.08), Vector2(safe.size.x, 60.0)), 30, ACTIVE_COLOR)
	_draw_text_centered("전투는 잠시 멈춥니다 · 선택하면 바로 재개", Rect2(safe.position + Vector2(0.0, safe.size.y * 0.18), Vector2(safe.size.x, 40.0)), 20, MUTED_TEXT_COLOR)
	var slot_labels := ["직업 전용" if not growth_cards.is_empty() and growth_cards[0].get("category", "") == "job" else "현재 무기", "공용", "무작위"]
	for index in growth_cards.size():
		var rect := growth_card_rects[index]
		var card := growth_cards[index]
		draw_style_box(_panel_style(PANEL_COLOR), rect)
		var font_size := mini(26, int(rect.size.x / 12.0))
		_draw_text_centered(slot_labels[index], Rect2(rect.position + Vector2(0.0, rect.size.y * 0.12), Vector2(rect.size.x, 32.0)), font_size - 4, MUTED_TEXT_COLOR)
		_draw_text_centered(String(card["title"]), Rect2(rect.position + Vector2(0.0, rect.size.y * 0.32), Vector2(rect.size.x, 44.0)), font_size, TEXT_COLOR)
		var line_index := 0
		for line in card["lines"]:
			_draw_text_centered(String(line), Rect2(rect.position + Vector2(0.0, rect.size.y * 0.56 + line_index * 38.0), Vector2(rect.size.x, 32.0)), font_size - 3, PASS_COLOR)
			line_index += 1
		var tag_labels: Array[String] = []
		var tags: Dictionary = card.get("tags", {})
		for tag in tags:
			tag_labels.append("%s +%.2f" % [PrototypeJobProgress.TAG_NAMES[tag], float(tags[tag]) * 0.70])
		_draw_text_centered(" · ".join(tag_labels), Rect2(rect.position + Vector2(0.0, rect.size.y * 0.85), Vector2(rect.size.x, 26.0)), font_size - 7, MUTED_TEXT_COLOR)
	_draw_button(growth_reroll_rect, "재추첨 %d회 남음" % growth_choice_rerolls, growth_choice_rerolls > 0)


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
	if bool(metrics.get("run_complete", metrics.get("stage_complete", false))) and screen_mode == ScreenMode.COMBAT:
		_show_result_screen()
	queue_redraw()


func update_test_record_summary(summary: Dictionary) -> void:
	test_record_summary = summary.duplicate(true)
	queue_redraw()


func begin_retry(starting_weapon: String = "sword") -> bool:
	if starting_weapon not in ["sword", "bow"]:
		return false
	_leave_village_environment()
	selected_starting_weapon = starting_weapon
	release_all_inputs()
	result_snapshot.clear()
	screen_mode = ScreenMode.COMBAT
	retry_requested.emit()
	queue_redraw()
	return true


func show_main_screen() -> void:
	_leave_village_environment()
	release_all_inputs()
	screen_mode = ScreenMode.MAIN
	queue_redraw()


func show_feedback_settings() -> void:
	release_all_inputs()
	screen_mode = ScreenMode.FEEDBACK_SETTINGS
	queue_redraw()


func set_feedback_sound_volume(value: float) -> void:
	feedback_sound_volume = clampf(value, 0.0, 1.0)
	_emit_feedback_settings()
	queue_redraw()


func set_feedback_vibration_enabled(enabled: bool) -> void:
	feedback_vibration_enabled = enabled
	_emit_feedback_settings()
	queue_redraw()


func set_feedback_screen_shake_enabled(enabled: bool) -> void:
	feedback_screen_shake_enabled = enabled
	_emit_feedback_settings()
	queue_redraw()


func feedback_settings_snapshot() -> Dictionary:
	return {
		"sound_volume": feedback_sound_volume,
		"vibration_enabled": feedback_vibration_enabled,
		"screen_shake_enabled": feedback_screen_shake_enabled,
	}


func test_record_summary_snapshot() -> Dictionary:
	return test_record_summary.duplicate(true)


func android_validation_snapshot() -> Dictionary:
	var safe := _safe_area_in_viewport()
	var touch_rects := _control_touch_rects()
	var safe_area_pass := safe.encloses(hud_rect) and safe.encloses(result_panel_rect)
	for rect in touch_rects.values():
		if not safe.encloses(rect):
			safe_area_pass = false
			break
	var completed_runs := int(test_record_summary.get("completed_run_count", 0))
	return {
		"viewport_size": size,
		"aspect_ratio": size.x / maxf(size.y, 1.0),
		"safe_area": safe,
		"safe_area_pass": safe_area_pass,
		"session_elapsed_s": android_validation_session_s,
		"continuous_20m_reached": android_validation_session_s >= ANDROID_VALIDATION_TARGET_SESSION_S,
		"pause_count": android_validation_pause_count,
		"resume_count": android_validation_resume_count,
		"background_resume_pass": android_validation_resume_count > 0,
		"completed_runs": completed_runs,
		"ten_runs_reached": completed_runs >= ANDROID_VALIDATION_TARGET_RUNS,
		"best_completion_s": float(test_record_summary.get("best_completion_s", 0.0)),
	}


func advance_android_validation_time_for_test(delta: float) -> void:
	android_validation_session_s += maxf(0.0, delta)


func _emit_feedback_settings() -> void:
	feedback_settings_changed.emit(
		feedback_sound_volume,
		feedback_vibration_enabled,
		feedback_screen_shake_enabled
	)


func begin_stage_from_main(starting_weapon: String = "sword") -> bool:
	return begin_retry(starting_weapon)


func show_start_weapon_selection() -> void:
	if screen_mode not in [ScreenMode.MAIN, ScreenMode.RESULT, ScreenMode.VILLAGE]:
		return
	start_weapon_return_mode = screen_mode
	start_weapon_previous_selection = selected_starting_weapon
	start_memory_previous_selection = selected_memory_id
	selected_memory_id = preferred_memory_id
	use_boss_legacy = not pending_boss_legacy.is_empty()
	release_all_inputs()
	screen_mode = ScreenMode.START_WEAPON
	_refresh_start_weapon_layout()
	queue_redraw()


func _refresh_start_weapon_layout() -> void:
	var safe := _safe_area_in_viewport()
	var gap := minf(32.0, safe.size.x * 0.03)
	var card_width := (safe.size.x * 0.90 - gap) * 0.5
	start_weapon_card_rects.clear()
	for index in 2:
		start_weapon_card_rects.append(Rect2(safe.position + Vector2(safe.size.x * 0.05 + index * (card_width + gap), safe.size.y * 0.24), Vector2(card_width, safe.size.y * 0.31)))
	memory_card_rects.clear()
	var memory_gap := minf(18.0, safe.size.x * 0.02)
	var memory_width := (safe.size.x * 0.90 - memory_gap * 2) / 3.0
	for index in 3:
		memory_card_rects.append(Rect2(safe.position + Vector2(safe.size.x * 0.05 + index * (memory_width + memory_gap), safe.size.y * 0.58), Vector2(memory_width, safe.size.y * 0.14)))
	var button_width := minf(280.0, safe.size.x * 0.27)
	boss_legacy_toggle_rect = Rect2(safe.position + Vector2(safe.size.x * 0.05, safe.size.y * 0.75), Vector2(safe.size.x * 0.90, safe.size.y * 0.06))
	start_weapon_cancel_rect = Rect2(safe.position + Vector2(safe.size.x * 0.5 - gap * 0.5 - button_width, safe.size.y * 0.86), Vector2(button_width, minf(64.0, safe.size.y * 0.09)))
	start_weapon_confirm_rect = Rect2(safe.position + Vector2(safe.size.x * 0.5 + gap * 0.5, safe.size.y * 0.86), start_weapon_cancel_rect.size)


func _draw_start_weapon_selection() -> void:
	_refresh_start_weapon_layout()
	var safe := _safe_area_in_viewport()
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR, true)
	_draw_text_centered("시작 무기를 선택하세요", Rect2(safe.position + Vector2(0, safe.size.y * 0.06), Vector2(safe.size.x, 54)), 32, ACTIVE_COLOR)
	_draw_text_centered(BossLegacyStore.description(String(pending_boss_legacy.get("choice", ""))) if not pending_boss_legacy.is_empty() else "선택한 무기를 주 무기로 장착하고 새 도전을 시작합니다", Rect2(safe.position + Vector2(0, safe.size.y * 0.15), Vector2(safe.size.x, 34)), 19, TEXT_COLOR)
	_draw_village_text("조제 · " + PrototypePotionRecipes.summary(preferred_potion_recipe), Rect2(safe.position + Vector2(0, safe.size.y * 0.21), Vector2(safe.size.x, safe.size.y * 0.025)), 17, PASS_COLOR)
	var ids := ["sword", "bow"]
	var names := ["검", "활"]
	var descriptions := ["자동 3연격 · 사거리 1.6m", "자동 사격 · 사거리 8m"]
	var skills := ["돌진 베기 · 회전 베기", "관통 화살 · 화살비"]
	for index in 2:
		var rect := start_weapon_card_rects[index]
		var selected: bool = selected_starting_weapon == ids[index]
		draw_style_box(_panel_style(Color("254f51") if selected else PANEL_COLOR), rect)
		if selected:
			draw_rect(rect.grow(-3.0), ACTIVE_COLOR, false, 3.0)
		var labels := [names[index] + (" · 선택됨" if selected else ""), descriptions[index], skills[index], "보조 무기 · " + names[1 - index]]
		var offsets := [0.07, 0.32, 0.52, 0.73]
		for line_index in labels.size():
			_draw_text_centered(labels[line_index], Rect2(rect.position + Vector2(0, rect.size.y * offsets[line_index]), Vector2(rect.size.x, 38)), 28 if line_index == 0 else 18, ACTIVE_COLOR if line_index == 0 else TEXT_COLOR)
	_draw_memory_cards()
	if not pending_boss_legacy.is_empty():
		_draw_button(boss_legacy_toggle_rect, "다음 도전 1회 · 보상 적용 " + ("켜짐" if use_boss_legacy else "꺼짐 · 이번 기회 건너뛰기"), use_boss_legacy)
	else:
		_draw_text_centered("영구 기억은 도전마다 하나만 장착합니다", boss_legacy_toggle_rect, 18, MUTED_TEXT_COLOR)
	_draw_button(start_weapon_cancel_rect, "돌아가기", false)
	_draw_button(start_weapon_confirm_rect, "이 무기로 시작", true)


func update_checkpoint_status(available: bool, message: String) -> void:
	checkpoint_available = available
	checkpoint_message = message
	queue_redraw()


func open_layout_editor() -> void:
	editor_return_mode = screen_mode if screen_mode == ScreenMode.COMBAT else ScreenMode.MAIN
	release_all_inputs()
	editor_original_layout = {
		"layout": _capture_control_layout(),
		"active_preset": active_preset_id,
		"custom_layout": saved_custom_layout.duplicate(true),
	}
	layout_store_message = ""
	selected_layout_control = MOVE_CONTROL
	editor_drag_pointer_id = -1
	screen_mode = ScreenMode.LAYOUT_EDITOR
	if editor_return_mode == ScreenMode.COMBAT:
		combat_configuration_started.emit()
	_validate_control_layout()
	queue_redraw()


func apply_layout_editor() -> bool:
	_validate_control_layout()
	if not invalid_layout_controls.is_empty():
		layout_store_message = "겹친 터치 영역을 먼저 정리하세요"
		queue_redraw()
		return false
	var current_layout := _capture_control_layout()
	if active_preset_id == PRESET_CUSTOM:
		saved_custom_layout = current_layout.duplicate(true)
	var save_error := layout_store.save_layout(
		active_preset_id,
		current_layout,
		saved_custom_layout,
		_layout_control_order()
	)
	if save_error != OK:
		layout_store_message = "저장 실패 · 오류 %d" % save_error
		queue_redraw()
		return false
	editor_original_layout.clear()
	editor_drag_pointer_id = -1
	layout_store_message = "저장 완료"
	if editor_return_mode == ScreenMode.COMBAT:
		_start_combat_resume_countdown()
	else:
		screen_mode = ScreenMode.MAIN
	queue_redraw()
	return true


func cancel_layout_editor() -> void:
	if not editor_original_layout.is_empty():
		_restore_control_layout(editor_original_layout.get("layout", {}))
		active_preset_id = String(editor_original_layout.get("active_preset", PRESET_DEFAULT))
		saved_custom_layout = (editor_original_layout.get("custom_layout", {}) as Dictionary).duplicate(true)
	editor_original_layout.clear()
	editor_drag_pointer_id = -1
	if editor_return_mode == ScreenMode.COMBAT:
		_start_combat_resume_countdown()
	else:
		screen_mode = ScreenMode.MAIN
	queue_redraw()


func start_layout_test() -> bool:
	if screen_mode != ScreenMode.LAYOUT_EDITOR:
		return false
	release_all_inputs()
	layout_test_remaining_s = 10.0
	layout_test_input_counts.clear()
	layout_test_peak_controls = 0
	screen_mode = ScreenMode.LAYOUT_TEST
	layout_test_started.emit()
	queue_redraw()
	return true


func finish_layout_test() -> void:
	if screen_mode != ScreenMode.LAYOUT_TEST:
		return
	release_all_inputs()
	layout_test_remaining_s = 0.0
	screen_mode = ScreenMode.LAYOUT_EDITOR
	layout_test_finished.emit()
	_validate_control_layout()
	queue_redraw()


func _start_combat_resume_countdown() -> void:
	release_all_inputs()
	combat_resume_remaining_s = 3.0
	screen_mode = ScreenMode.COMBAT_RESUME_COUNTDOWN
	queue_redraw()


func _update_mode_timer(delta: float) -> void:
	if screen_mode == ScreenMode.LAYOUT_TEST:
		layout_test_remaining_s = maxf(0.0, layout_test_remaining_s - delta)
		if is_zero_approx(layout_test_remaining_s):
			finish_layout_test()
	elif screen_mode == ScreenMode.COMBAT_RESUME_COUNTDOWN:
		combat_resume_remaining_s = maxf(0.0, combat_resume_remaining_s - delta)
		if is_zero_approx(combat_resume_remaining_s):
			screen_mode = ScreenMode.COMBAT
			editor_return_mode = ScreenMode.MAIN
			combat_configuration_finished.emit()
			queue_redraw()


func reset_layout_editor() -> void:
	var preset_to_restore := active_preset_id
	if preset_to_restore == PRESET_CUSTOM:
		_restore_control_layout(_default_layout_snapshot(DEFAULT_CONTROL_CENTERS))
	else:
		_restore_control_layout(_preset_layout(preset_to_restore))
	selected_layout_control = MOVE_CONTROL
	layout_store_message = "현재 프리셋 초기화"
	_validate_control_layout()
	queue_redraw()


func select_control_preset(preset_id: String) -> void:
	if preset_id not in [PRESET_DEFAULT, PRESET_LEFT, PRESET_CUSTOM]:
		return
	if active_preset_id == PRESET_CUSTOM:
		saved_custom_layout = _capture_control_layout()
	active_preset_id = preset_id
	if preset_id == PRESET_CUSTOM:
		_restore_control_layout(
			saved_custom_layout
			if not saved_custom_layout.is_empty()
			else _default_layout_snapshot(DEFAULT_CONTROL_CENTERS)
		)
	else:
		_restore_control_layout(_preset_layout(preset_id))
	selected_layout_control = MOVE_CONTROL
	layout_store_message = "%s 프리셋 미리보기" % _preset_label(preset_id)
	queue_redraw()


func select_layout_control(control_id: StringName) -> void:
	if control_id in _layout_control_order():
		selected_layout_control = control_id
		queue_redraw()


func adjust_selected_control_size(delta: float) -> void:
	if selected_layout_control == &"":
		return
	var current_scale := float(control_scales.get(selected_layout_control, 1.0))
	control_scales[selected_layout_control] = clampf(current_scale + delta, 0.70, 1.40)
	_mark_layout_custom()
	_refresh_layout()
	_validate_control_layout()
	queue_redraw()


func set_control_opacity(value: float) -> void:
	control_opacity = clampf(value, 0.30, 1.00)
	_mark_layout_custom()
	queue_redraw()


func set_control_center_normalized(control_id: StringName, normalized_center: Vector2) -> void:
	if control_id not in _layout_control_order():
		return
	control_centers[control_id] = normalized_center
	_mark_layout_custom()
	_refresh_layout()
	_validate_control_layout()
	queue_redraw()


func current_screen_mode() -> int:
	return screen_mode


func layout_editor_returns_to_combat() -> bool:
	return editor_return_mode == ScreenMode.COMBAT


func current_result_snapshot() -> Dictionary:
	return result_snapshot.duplicate(true)


func layout_test_snapshot() -> Dictionary:
	return {
		"remaining_s": layout_test_remaining_s,
		"input_counts": layout_test_input_counts.duplicate(true),
		"active_controls": control_pointers.keys(),
		"peak_controls": layout_test_peak_controls,
		"invalid_controls": invalid_layout_controls.duplicate(),
		"resume_remaining_s": combat_resume_remaining_s,
	}


func advance_mode_timer_for_test(delta: float) -> void:
	_update_mode_timer(delta)


func layout_snapshot() -> Dictionary:
	return {
		"safe": _safe_area_in_viewport(),
		"hud": hud_rect,
		"move": move_zone,
		"actions": action_rects.duplicate(),
		"result_panel": result_panel_rect,
		"main_village": main_village_rect,
		"growth_cards": growth_card_rects.duplicate(),
		"growth_reroll": growth_reroll_rect,
		"job_panel": job_panel_rect,
		"job_confirm": job_confirm_rect,
		"job_ultimates": job_ultimate_rects.duplicate(),
		"stage_routes": stage_route_rects.duplicate(),
		"start_weapon_cards": start_weapon_card_rects.duplicate(),
		"start_weapon_confirm": start_weapon_confirm_rect,
		"start_weapon_cancel": start_weapon_cancel_rect,
		"memory_cards": memory_card_rects.duplicate(),
		"boss_legacy_toggle": boss_legacy_toggle_rect,
		"boss_choice_cards": boss_choice_rects.duplicate(),
		"boss_choice_confirm": boss_choice_confirm_rect,
		"weapon_reward_cards": weapon_reward_rects.duplicate(),
		"weapon_reward_confirm": weapon_reward_confirm_rect,
		"weapon_reward_skip": weapon_reward_skip_rect,
	}


func control_layout_snapshot() -> Dictionary:
	return {
		"centers": control_centers.duplicate(true),
		"scales": control_scales.duplicate(true),
		"opacity": control_opacity,
		"selected": selected_layout_control,
		"invalid_controls": invalid_layout_controls.duplicate(),
		"valid": invalid_layout_controls.is_empty(),
		"touch_rects": _control_touch_rects(),
		"active_preset": active_preset_id,
		"has_custom_layout": not saved_custom_layout.is_empty(),
		"store_message": layout_store_message,
	}


func _show_result_screen() -> void:
	release_all_inputs()
	var sword_hits := int(movement_metrics.get("sword_total_hits", 0))
	var bow_hits := int(movement_metrics.get("bow_total_hits", 0))
	var total_hits := sword_hits + bow_hits
	result_snapshot = {
		"completion_s": float(movement_metrics.get("run_elapsed_s", movement_metrics.get("stage_elapsed_s", 0.0))),
		"target_s": float(movement_metrics.get("stage_target_s", 180.0)) * int(movement_metrics.get("run_stage_count", 1)),
		"stage_count": int(movement_metrics.get("run_stage_count", 1)),
		"stage_history": movement_metrics.get("run_stage_history", []).duplicate(true),
		"boss_choice": String(movement_metrics.get("boss_choice", "")),
		"boss_name": String(movement_metrics.get("boss_name", "")),
		"memory_id": active_memory_id,
		"weapon_blueprints": movement_metrics.get("weapon_blueprints", {"sword": "", "bow": ""}).duplicate(),
		"actual_times": movement_metrics.get("stage_actual_times", []).duplicate(),
		"damage_causes": String(movement_metrics.get("damage_cause_summary", "피격 없음")),
		"sword_hits": sword_hits,
		"bow_hits": bow_hits,
		"sword_damage": int(movement_metrics.get("sword_total_damage", 0)),
		"bow_damage": int(movement_metrics.get("bow_total_damage", 0)),
		"sword_ratio": float(sword_hits) / float(total_hits) if total_hits > 0 else 0.0,
		"bow_ratio": float(bow_hits) / float(total_hits) if total_hits > 0 else 0.0,
		"record_summary": _current_record_summary(),
	}
	screen_mode = ScreenMode.RESULT
	_refresh_layout()
	queue_redraw()


func _handle_screen_touch(position: Vector2) -> void:
	if screen_mode == ScreenMode.RELIC_REWARD:
		_refresh_relic_reward_layout()
		if relic_reward_cancel_rect.has_point(position):
			show_stage_routes(cleared_stage, run_stage_count, stage_recovered_health, stage_route_options)
		elif relic_reward_confirm_rect.has_point(position):
			relic_reward_selected.emit()
		return
	if screen_mode == ScreenMode.SKILL_REWARD:
		_handle_skill_reward_touch(position)
		return
	if screen_mode == ScreenMode.VILLAGE:
		_handle_village_touch(position)
		return
	if screen_mode == ScreenMode.BOSS_CHOICE:
		_refresh_boss_choice_layout()
		for index in boss_choice_rects.size():
			if boss_choice_rects[index].has_point(position):
				selected_boss_choice = index
				return
		if boss_choice_confirm_rect.has_point(position) and selected_boss_choice >= 0:
			boss_choice_confirmed.emit("rescue" if selected_boss_choice == 0 else "destroy")
		return
	if screen_mode == ScreenMode.WEAPON_REWARD:
		_refresh_weapon_reward_layout()
		for index in weapon_reward_rects.size():
			if weapon_reward_rects[index].has_point(position):
				selected_weapon_reward = index
				return
		if weapon_reward_skip_rect.has_point(position):
			weapon_reward_selected.emit("")
		elif weapon_reward_confirm_rect.has_point(position) and selected_weapon_reward >= 0:
			weapon_reward_selected.emit(String(weapon_reward_cards[selected_weapon_reward].id))
		return
	if screen_mode == ScreenMode.START_WEAPON:
		_refresh_start_weapon_layout()
		for index in start_weapon_card_rects.size():
			if start_weapon_card_rects[index].has_point(position):
				selected_starting_weapon = "sword" if index == 0 else "bow"
				return
		for index in memory_card_rects.size():
			if memory_card_rects[index].has_point(position):
				var id: String = PrototypeMemoryAbilities.IDS[index]
				if PrototypeMemoryAbilities.available(id, unlocked_memories):
					selected_memory_id = id
				return
		if not pending_boss_legacy.is_empty() and boss_legacy_toggle_rect.has_point(position):
			use_boss_legacy = not use_boss_legacy
			return
		if start_weapon_cancel_rect.has_point(position):
			selected_starting_weapon = start_weapon_previous_selection
			selected_memory_id = start_memory_previous_selection
			screen_mode = start_weapon_return_mode
		elif start_weapon_confirm_rect.has_point(position):
			begin_retry(selected_starting_weapon)
		return
	if screen_mode == ScreenMode.STAGE_ROUTE:
		if relic_offer_available and relic_reward_open_rect.has_point(position):
			release_all_inputs()
			screen_mode = ScreenMode.RELIC_REWARD
			_refresh_relic_reward_layout()
			queue_redraw()
			return
		if not skill_reward_claimed and skill_reward_open_rect.has_point(position):
			show_skill_rewards()
			return
		for index in stage_route_rects.size():
			if stage_route_rects[index].has_point(position):
				stage_route_selected.emit(String(stage_route_options[index]["id"]))
				return
		return
	if screen_mode == ScreenMode.JOB_MANIFESTATION:
		for index in job_ultimate_rects.size():
			if job_ultimate_rects[index].has_point(position) and index < job_ultimates.size():
				selected_job_ultimate = index
				queue_redraw()
				return
		if job_confirm_rect.has_point(position) and selected_job_ultimate >= 0:
			job_confirmed.emit(selected_job_ultimate)
		return
	if screen_mode == ScreenMode.GROWTH_SELECTION:
		if growth_reroll_rect.has_point(position):
			if growth_choice_rerolls > 0:
				growth_reroll_requested.emit()
			return
		for index in growth_card_rects.size():
			if growth_card_rects[index].has_point(position):
				growth_card_selected.emit(index)
				return
		return
	if screen_mode == ScreenMode.RESULT:
		if result_retry_rect.has_point(position):
			show_start_weapon_selection()
		elif result_main_rect.has_point(position):
			show_main_screen()
	elif screen_mode == ScreenMode.MAIN and main_village_rect.has_point(position):
		show_village()
	elif screen_mode == ScreenMode.MAIN and main_start_rect.has_point(position):
		show_start_weapon_selection()
	elif screen_mode == ScreenMode.MAIN and checkpoint_available and main_continue_rect.has_point(position):
		continue_requested.emit()
	elif screen_mode == ScreenMode.MAIN and main_layout_rect.has_point(position):
		open_layout_editor()
	elif screen_mode == ScreenMode.MAIN and main_feedback_rect.has_point(position):
		show_feedback_settings()
	elif screen_mode == ScreenMode.FEEDBACK_SETTINGS:
		if feedback_sound_down_rect.has_point(position):
			set_feedback_sound_volume(feedback_sound_volume - 0.10)
		elif feedback_sound_up_rect.has_point(position):
			set_feedback_sound_volume(feedback_sound_volume + 0.10)
		elif feedback_vibration_rect.has_point(position):
			set_feedback_vibration_enabled(not feedback_vibration_enabled)
		elif feedback_shake_rect.has_point(position):
			set_feedback_screen_shake_enabled(not feedback_screen_shake_enabled)
		elif feedback_records_clear_rect.has_point(position):
			test_records_clear_requested.emit()
		elif feedback_back_rect.has_point(position):
			show_main_screen()


func _handle_editor_touch(touch: InputEventScreenTouch) -> void:
	if not touch.pressed:
		if touch.index == editor_drag_pointer_id:
			editor_drag_pointer_id = -1
		return
	if editor_preset_default_rect.has_point(touch.position):
		select_control_preset(PRESET_DEFAULT)
		return
	if editor_preset_left_rect.has_point(touch.position):
		select_control_preset(PRESET_LEFT)
		return
	if editor_preset_custom_rect.has_point(touch.position):
		select_control_preset(PRESET_CUSTOM)
		return
	if editor_size_down_rect.has_point(touch.position):
		adjust_selected_control_size(-0.10)
		return
	if editor_size_up_rect.has_point(touch.position):
		adjust_selected_control_size(0.10)
		return
	if editor_opacity_down_rect.has_point(touch.position):
		set_control_opacity(control_opacity - 0.10)
		return
	if editor_opacity_up_rect.has_point(touch.position):
		set_control_opacity(control_opacity + 0.10)
		return
	if editor_test_rect.has_point(touch.position):
		start_layout_test()
		return
	if editor_reset_rect.has_point(touch.position):
		reset_layout_editor()
		return
	if editor_cancel_rect.has_point(touch.position):
		cancel_layout_editor()
		return
	if editor_apply_rect.has_point(touch.position):
		apply_layout_editor()
		return
	var hit_control := _layout_control_at(touch.position)
	if hit_control != &"":
		selected_layout_control = hit_control
		editor_drag_pointer_id = touch.index
		_move_layout_control(hit_control, touch.position)


func _handle_layout_test_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed and layout_test_exit_rect.has_point(touch.position):
		finish_layout_test()
		return
	if touch.pressed:
		_handle_touch_pressed(touch.index, touch.position)
	else:
		_handle_touch_released(touch.index)


func _handle_editor_drag(pointer_id: int, position: Vector2) -> void:
	if pointer_id == editor_drag_pointer_id and selected_layout_control != &"":
		_move_layout_control(selected_layout_control, position)


func _move_layout_control(control_id: StringName, position: Vector2) -> void:
	var safe := _safe_area_in_viewport()
	var half_size := _control_touch_rect(control_id).size * 0.5
	var clamped := Vector2(
		clampf(position.x, safe.position.x + half_size.x, safe.end.x - half_size.x),
		clampf(position.y, safe.position.y + half_size.y, safe.end.y - half_size.y)
	)
	control_centers[control_id] = Vector2(
		(clamped.x - safe.position.x) / maxf(safe.size.x, 1.0),
		(clamped.y - safe.position.y) / maxf(safe.size.y, 1.0)
	)
	_mark_layout_custom()
	_refresh_layout()
	_validate_control_layout()


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
	if screen_mode == ScreenMode.COMBAT and _handle_header_action(position):
		if screen_mode == ScreenMode.COMBAT:
			pointer_controls[pointer_id] = &"header"
		return

	if move_zone.has_point(position) and move_pointer_id < 0:
		move_pointer_id = pointer_id
		move_origin = _clamp_move_origin(position)
		move_vector = Vector2.ZERO
		pointer_controls[pointer_id] = MOVE_CONTROL
		control_pointers[MOVE_CONTROL] = pointer_id
		_record_layout_test_input(MOVE_CONTROL)
		_update_peak_controls()
		move_vector_changed.emit(move_vector)
		return

	var action_id := _action_at(position)
	if action_id != &"" and not control_pointers.has(action_id):
		pointer_controls[pointer_id] = action_id
		control_pointers[action_id] = pointer_id
		_record_layout_test_input(action_id)
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
		PlayerCommand.Type.RECOVERY_POTION:
			if command.phase == PlayerCommand.Phase.PRESSED and screen_mode == ScreenMode.COMBAT:
				recovery_potion_pressed.emit()


func _handle_header_action(position: Vector2) -> bool:
	if combat_layout_rect.has_point(position):
		open_layout_editor()
		return true
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
	if screen_mode == ScreenMode.LAYOUT_TEST:
		layout_test_peak_controls = maxi(layout_test_peak_controls, control_pointers.size())


func _record_layout_test_input(control_id: StringName) -> void:
	if screen_mode != ScreenMode.LAYOUT_TEST:
		return
	layout_test_input_counts[control_id] = int(layout_test_input_counts.get(control_id, 0)) + 1


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
	combat_layout_rect = Rect2(fps_60_rect.position.x - gap - button_width, top, button_width, button_height)

	var move_scale := float(control_scales.get(MOVE_CONTROL, 1.0))
	var move_size := Vector2(
		clampf(safe.size.x * 0.30, 420.0, 570.0),
		clampf(safe.size.y * 0.34, 260.0, 340.0)
	) * move_scale
	var move_center := safe.position + Vector2(control_centers.get(MOVE_CONTROL, DEFAULT_CONTROL_CENTERS[MOVE_CONTROL])) * safe.size
	move_center = _clamp_control_center(move_center, move_size * 0.5, safe)
	control_centers[MOVE_CONTROL] = (move_center - safe.position) / safe.size
	move_zone = Rect2(move_center - move_size * 0.5, move_size)
	move_radius = clampf(minf(move_zone.size.x, move_zone.size.y) * 0.31, 82.0, 110.0)
	if move_pointer_id < 0:
		move_origin = move_zone.get_center()

	var radii := {
		&"jump": 84.0,
		&"evade": 72.0,
		&"skill_1": 72.0,
		&"skill_2": 72.0,
		&"ultimate": 72.0,
		&"weapon_swap": 64.0,
		&"recovery_potion": 56.0,
	}
	action_rects.clear()
	for action_id in ACTION_ORDER:
		var normalized: Vector2 = control_centers.get(action_id, DEFAULT_CONTROL_CENTERS[action_id])
		var center := safe.position + normalized * safe.size
		var radius: float = float(radii[action_id]) * float(control_scales.get(action_id, 1.0))
		center = _clamp_control_center(center, Vector2.ONE * radius, safe)
		control_centers[action_id] = (center - safe.position) / safe.size
		action_rects[action_id] = Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)

	hud_rect = Rect2(
		safe.position + Vector2(10.0, 10.0),
		Vector2(safe.size.x - 20.0, clampf(safe.size.y * 0.20, 132.0, 158.0))
	)
	var panel_size := Vector2(
		clampf(safe.size.x * 0.72, 760.0, 1060.0),
		clampf(safe.size.y * 0.82, 580.0, 650.0)
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
		Vector2(result_panel_rect.get_center().x - 310.0, result_panel_rect.end.y - 106.0),
		Vector2(280.0, 68.0)
	)
	main_layout_rect = Rect2(
		Vector2(result_panel_rect.get_center().x + 30.0, result_panel_rect.end.y - 106.0),
		Vector2(280.0, 68.0)
	)
	main_feedback_rect = Rect2(
		Vector2(result_panel_rect.get_center().x - 310.0, result_panel_rect.end.y - 190.0),
		Vector2(280.0, 56.0)
	)
	main_village_rect = Rect2(Vector2(result_panel_rect.get_center().x + 30.0, result_panel_rect.end.y - 190.0), Vector2(280.0, 56.0))
	main_continue_rect = Rect2(
		Vector2(result_panel_rect.get_center().x - 140.0, result_panel_rect.end.y - 274.0),
		Vector2(280.0, 56.0)
	)
	feedback_panel_rect = result_panel_rect
	var feedback_row_x := feedback_panel_rect.position.x + 310.0
	var feedback_row_width := feedback_panel_rect.size.x - 380.0
	var feedback_button_width := 150.0
	feedback_sound_down_rect = Rect2(
		Vector2(feedback_row_x, feedback_panel_rect.position.y + 174.0),
		Vector2(feedback_button_width, 54.0)
	)
	feedback_sound_up_rect = Rect2(
		Vector2(feedback_sound_down_rect.end.x + 18.0, feedback_sound_down_rect.position.y),
		Vector2(feedback_button_width, 54.0)
	)
	feedback_vibration_rect = Rect2(
		Vector2(feedback_row_x, feedback_panel_rect.position.y + 254.0),
		Vector2(feedback_row_width, 56.0)
	)
	feedback_shake_rect = Rect2(
		Vector2(feedback_row_x, feedback_panel_rect.position.y + 334.0),
		Vector2(feedback_row_width, 56.0)
	)
	feedback_records_clear_rect = Rect2(
		Vector2(feedback_row_x, feedback_panel_rect.position.y + 400.0),
		Vector2(feedback_row_width, 54.0)
	)
	feedback_back_rect = Rect2(
		Vector2(feedback_panel_rect.get_center().x - 120.0, feedback_panel_rect.end.y - 82.0),
		Vector2(240.0, 54.0)
	)

	editor_toolbar_rect = Rect2(
		safe.position + Vector2(10.0, 10.0),
		Vector2(safe.size.x - 20.0, clampf(safe.size.y * 0.24, 166.0, 190.0))
	)
	var tool_height := 50.0
	var tool_y := editor_toolbar_rect.position.y + editor_toolbar_rect.size.y - tool_height - 14.0
	var tool_gap := 10.0
	var small_width := clampf(safe.size.x * 0.055, 68.0, 92.0)
	var action_width := clampf(safe.size.x * 0.09, 118.0, 160.0)
	var preset_width := clampf(safe.size.x * 0.085, 104.0, 148.0)
	var preset_y := editor_toolbar_rect.position.y + 44.0
	editor_preset_default_rect = Rect2(Vector2(editor_toolbar_rect.position.x + 20.0, preset_y), Vector2(preset_width, 44.0))
	editor_preset_left_rect = Rect2(Vector2(editor_preset_default_rect.end.x + tool_gap, preset_y), Vector2(preset_width, 44.0))
	editor_preset_custom_rect = Rect2(Vector2(editor_preset_left_rect.end.x + tool_gap, preset_y), Vector2(preset_width, 44.0))
	editor_size_down_rect = Rect2(Vector2(editor_toolbar_rect.position.x + 20.0, tool_y), Vector2(small_width, tool_height))
	editor_size_up_rect = Rect2(Vector2(editor_size_down_rect.end.x + tool_gap, tool_y), Vector2(small_width, tool_height))
	editor_opacity_down_rect = Rect2(Vector2(editor_size_up_rect.end.x + 42.0, tool_y), Vector2(small_width, tool_height))
	editor_opacity_up_rect = Rect2(Vector2(editor_opacity_down_rect.end.x + tool_gap, tool_y), Vector2(small_width, tool_height))
	editor_apply_rect = Rect2(Vector2(editor_toolbar_rect.end.x - action_width - 20.0, tool_y), Vector2(action_width, tool_height))
	editor_cancel_rect = Rect2(Vector2(editor_apply_rect.position.x - action_width - tool_gap, tool_y), Vector2(action_width, tool_height))
	editor_reset_rect = Rect2(Vector2(editor_cancel_rect.position.x - action_width - tool_gap, tool_y), Vector2(action_width, tool_height))
	editor_test_rect = Rect2(Vector2(editor_reset_rect.position.x - action_width - tool_gap, tool_y), Vector2(action_width, tool_height))
	layout_test_exit_rect = Rect2(
		Vector2(safe.end.x - action_width - 20.0, safe.position.y + 20.0),
		Vector2(action_width, 54.0)
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
	var top_y := hud_rect.position.y + 28.0

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
	_draw_text("Lv.%d · 경험치 %d/%d" % [int(movement_metrics.get("growth_level", 1)), int(movement_metrics.get("growth_xp", 0)), int(movement_metrics.get("growth_next_xp", 20))], Vector2(left_x, top_y + 56.0), 17, ACTIVE_COLOR)
	_draw_text(String(movement_metrics.get("growth_job_hud", "직업 미발현")), Vector2(left_x, top_y + 76.0), 15, MUTED_TEXT_COLOR)
	_draw_text(PrototypeMemoryAbilities.profile(active_memory_id).name + _legacy_hud_label(), Vector2(left_x, top_y + 96.0), 13, ACTIVE_COLOR)
	_draw_text(String(movement_metrics.get("potion_log", "회복약 · 최대 체력 25% 회복")), Vector2(left_x, top_y + 116.0), 12, MUTED_TEXT_COLOR)
	_draw_text(String(movement_metrics.get("relic_hud", "유물 없음")), Vector2(left_x, top_y + 134.0), 12, ACTIVE_COLOR)

	_draw_text(
		"%d/%d · %s  %d/%d" % [
			int(movement_metrics.get("run_stage_number", 1)),
			int(movement_metrics.get("run_stage_count", 1)),
			section_name.split(" · ")[0],
			section_index,
			section_count,
		],
		Vector2(center_x, top_y),
		18,
		TEXT_COLOR
	)
	var stage_objective: String = String(movement_metrics.get("stage_objective", "첫 관문까지 전진"))
	_draw_text("%s / %s" % [_format_clock(stage_elapsed), _format_clock(stage_target)], Vector2(center_x, top_y + 31.0), 25, ACTIVE_COLOR)
	_draw_text(stage_objective, Vector2(center_x, top_y + 62.0), 16, MUTED_TEXT_COLOR)
	_draw_text("%s · %s" % [String(movement_metrics.get("run_route_name", "풀숲 길")), String(movement_metrics.get("run_route_terrain", "연습 지형"))], Vector2(center_x, top_y + 86.0), 15, ACTIVE_COLOR)

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
		"%s  %s" % [String(movement_metrics.get("ultimate_name", "새벽의 틈")), "발동 중" if ultimate_active else "%d%%" % ultimate_gauge],
		Vector2(right_x, top_y + 60.0),
		17,
		ACTIVE_COLOR if ultimate_active or ultimate_gauge >= 100 else TEXT_COLOR
	)
	_draw_text(String(movement_metrics.get("weapon_backup_effect", "")), Vector2(right_x, top_y + 86.0), 15, MUTED_TEXT_COLOR)

	_draw_button(fps_60_rect, "60", Engine.max_fps == 60)
	_draw_button(fps_30_rect, "30", Engine.max_fps == 30)
	_draw_button(reset_rect, "재설정", false)
	_draw_button(combat_layout_rect, "배치", false)


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
		"도전 완료 · %d개 스테이지" % int(result_snapshot.get("stage_count", 1)),
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
	var choice := String(result_snapshot.get("boss_choice", ""))
	if choice in ["rescue", "destroy"]:
		_draw_text_centered("태엽 기사 %s · %s 영구 해금" % [("구출" if choice == "rescue" else "파괴"), PrototypeMemoryAbilities.profile(PrototypeMemoryAbilities.CHOICE_IDS[choice]).name + (" / 태엽 검·활 설계도" if choice == "destroy" else "")], Rect2(result_panel_rect.position + Vector2(0, 128), Vector2(result_panel_rect.size.x, 26)), 18, ACTIVE_COLOR)
	var content_x := result_panel_rect.position.x + 54.0
	var content_width := result_panel_rect.size.x - 108.0
	var y := result_panel_rect.position.y + 158.0
	_draw_result_row("스테이지 기록" if int(result_snapshot.get("stage_count", 1)) > 1 else "구간 기록", _section_time_summary(), content_x, content_width, y)
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
	y += 58.0
	var record_summary: Dictionary = result_snapshot.get("record_summary", {})
	var completed_runs := int(record_summary.get("completed_run_count", 0))
	var incomplete_runs := int(record_summary.get("incomplete_run_count", 0))
	var best_s := float(record_summary.get("best_completion_s", 0.0))
	var average_s := float(record_summary.get("average_completion_s", 0.0))
	var record_text := "완주 %d · 중단 %d · 최고 %s · 평균 %s" % [
		completed_runs,
		incomplete_runs,
		_format_clock(best_s) if best_s > 0.0 else "--:--",
		_format_clock(average_s) if average_s > 0.0 else "--:--",
	]
	_draw_result_row("로컬 테스트", record_text, content_x, content_width, y)
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
		"GP-117 · 전투 회복약",
		Rect2(Vector2(result_panel_rect.position.x, result_panel_rect.position.y + 188.0), Vector2(result_panel_rect.size.x, 46.0)),
		25,
		TEXT_COLOR
	)
	_draw_text_centered(
		BossLegacyStore.description(String(pending_boss_legacy.get("choice", ""))) if not pending_boss_legacy.is_empty() else "완료 지점 저장 · 앱을 종료해도 이어하기",
		Rect2(Vector2(result_panel_rect.position.x, result_panel_rect.position.y + 244.0), Vector2(result_panel_rect.size.x, 40.0)),
		19,
		MUTED_TEXT_COLOR
	)
	if not checkpoint_available:
		_draw_text_centered("영구 기억 %d/2 · 무기 설계도 %d/2 해금" % [unlocked_memories.size(), unlocked_weapon_blueprints.size()], Rect2(result_panel_rect.position + Vector2(0, 300), Vector2(result_panel_rect.size.x, 30)), 18, MUTED_TEXT_COLOR)
	_draw_button(main_feedback_rect, "설정", false)
	_draw_button(main_village_rect, "시간의 닻 마을", true)
	if checkpoint_available:
		_draw_button(main_continue_rect, "이어하기", true)
	if not checkpoint_message.is_empty():
		_draw_text_centered(checkpoint_message, Rect2(Vector2(result_panel_rect.position.x, main_continue_rect.position.y - 30.0), Vector2(result_panel_rect.size.x, 26.0)), 15, MUTED_TEXT_COLOR)
	_draw_button(main_start_rect, "새 도전" if checkpoint_available else "스테이지 시작", not checkpoint_available)
	_draw_button(main_layout_rect, "조작 배치", false)


func _draw_feedback_settings() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(BACKGROUND_COLOR, 0.92), true)
	draw_style_box(_panel_style(Color(PANEL_COLOR, 0.98)), feedback_panel_rect)
	_draw_text_centered(
		"설정",
		Rect2(
			Vector2(feedback_panel_rect.position.x, feedback_panel_rect.position.y + 42.0),
			Vector2(feedback_panel_rect.size.x, 58.0)
		),
		34,
		ACTIVE_COLOR
	)
	var label_x := feedback_panel_rect.position.x + 70.0
	_draw_text(
		"효과음  %d%%" % int(round(feedback_sound_volume * 100.0)),
		Vector2(label_x, feedback_sound_down_rect.position.y + 35.0),
		22,
		TEXT_COLOR
	)
	_draw_button(feedback_sound_down_rect, "소리 -", false)
	_draw_button(feedback_sound_up_rect, "소리 +", false)
	_draw_text(
		"진동",
		Vector2(label_x, feedback_vibration_rect.position.y + 36.0),
		22,
		TEXT_COLOR
	)
	_draw_button(
		feedback_vibration_rect,
		"켜짐" if feedback_vibration_enabled else "꺼짐",
		feedback_vibration_enabled
	)
	_draw_text(
		"화면 흔들기",
		Vector2(label_x, feedback_shake_rect.position.y + 36.0),
		22,
		TEXT_COLOR
	)
	_draw_button(
		feedback_shake_rect,
		"켜짐" if feedback_screen_shake_enabled else "꺼짐",
		feedback_screen_shake_enabled
	)
	var validation := android_validation_snapshot()
	_draw_text(
		"Android 검증 %d/10 · 연속 %s · 복귀 %d" % [
			int(validation["completed_runs"]),
			_format_clock(float(validation["session_elapsed_s"])),
			int(validation["resume_count"]),
		],
		Vector2(label_x, feedback_records_clear_rect.position.y + 35.0),
		18,
		TEXT_COLOR
	)
	_draw_button(feedback_records_clear_rect, "기록 초기화", false)
	_draw_text_centered(
		"기록은 기기에만 저장되며 네트워크로 전송되지 않습니다.",
		Rect2(
			Vector2(feedback_panel_rect.position.x, feedback_panel_rect.end.y - 130.0),
			Vector2(feedback_panel_rect.size.x, 36.0)
		),
		17,
		MUTED_TEXT_COLOR
	)
	_draw_button(feedback_back_rect, "메인으로", false)


func _draw_layout_editor() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(BACKGROUND_COLOR, 0.78), true)
	var safe := _safe_area_in_viewport()
	draw_rect(safe, Color("4bd49b", 0.05), true)
	draw_rect(safe, Color("65e6ae"), false, 4.0)
	_draw_text("SAFE AREA", safe.position + Vector2(16.0, safe.size.y - 18.0), 16, Color("65e6ae"))

	_draw_move_control()
	_draw_action_controls()
	var touch_rects := _control_touch_rects()
	for control_id in _layout_control_order():
		var rect: Rect2 = touch_rects[control_id]
		var invalid := control_id in invalid_layout_controls
		var selected := control_id == selected_layout_control
		var outline := Color("f05d5e") if invalid else (ACTIVE_COLOR if selected else Color(TEXT_COLOR, 0.72))
		draw_rect(rect, Color(outline, 0.10 if invalid else 0.035), true)
		draw_rect(rect, outline, false, 6.0 if selected else 3.0)
		if invalid:
			draw_line(rect.position, rect.end, outline, 4.0)
			draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), outline, 4.0)

	draw_style_box(_panel_style(Color(PANEL_COLOR, 0.98)), editor_toolbar_rect)
	var selected_label := _layout_control_label(selected_layout_control)
	var selected_scale := int(round(float(control_scales.get(selected_layout_control, 1.0)) * 100.0))
	_draw_text("프리셋", editor_toolbar_rect.position + Vector2(20.0, 32.0), 20, MUTED_TEXT_COLOR)
	_draw_button(editor_preset_default_rect, "기본", active_preset_id == PRESET_DEFAULT)
	_draw_button(editor_preset_left_rect, "왼손잡이", active_preset_id == PRESET_LEFT)
	_draw_button(editor_preset_custom_rect, "사용자", active_preset_id == PRESET_CUSTOM)
	var info_x := editor_preset_custom_rect.end.x + 30.0
	_draw_text("선택: %s  ·  크기 %d%%  ·  전체 불투명도 %d%%" % [
		selected_label,
		selected_scale,
		int(round(control_opacity * 100.0)),
	], Vector2(info_x, editor_toolbar_rect.position.y + 38.0), 21, TEXT_COLOR)
	var status := "적용 가능 · 조작 요소를 드래그하세요"
	var status_color := PASS_COLOR
	if not invalid_layout_controls.is_empty():
		status = "적용 불가 · 터치 영역이 30% 이상 겹칩니다"
		status_color = Color("ff8b85")
	elif not layout_store_message.is_empty():
		status = layout_store_message
	_draw_text(status, Vector2(info_x, editor_toolbar_rect.position.y + 78.0), 17, status_color)
	_draw_button(editor_size_down_rect, "크기 -", false)
	_draw_button(editor_size_up_rect, "크기 +", false)
	_draw_button(editor_opacity_down_rect, "투명 -", false)
	_draw_button(editor_opacity_up_rect, "투명 +", false)
	_draw_button(editor_test_rect, "10초 테스트", true)
	_draw_button(editor_reset_rect, "초기화", false)
	_draw_button(editor_cancel_rect, "취소", false)
	_draw_button(editor_apply_rect, "적용", invalid_layout_controls.is_empty())


func _draw_layout_test() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(BACKGROUND_COLOR, 0.24), true)
	_draw_move_control()
	_draw_action_controls()
	var touch_rects := _control_touch_rects()
	for control_id in _layout_control_order():
		var rect: Rect2 = touch_rects[control_id]
		var active := control_pointers.has(control_id)
		var invalid := control_id in invalid_layout_controls
		var outline := Color("f05d5e") if invalid else (ACTIVE_COLOR if active else Color(TEXT_COLOR, 0.68))
		draw_rect(rect, Color(outline, 0.16 if active else 0.04), true)
		draw_rect(rect, outline, false, 7.0 if active else 3.0)
	var safe := _safe_area_in_viewport()
	var countdown_rect := Rect2(
		Vector2(safe.get_center().x - 210.0, safe.position.y + 18.0),
		Vector2(420.0, 60.0)
	)
	draw_style_box(_panel_style(Color(PANEL_COLOR, 0.97)), countdown_rect)
	_draw_text_centered(
		"배치 테스트  %.1f초" % maxf(layout_test_remaining_s, 0.0),
		countdown_rect,
		25,
		ACTIVE_COLOR
	)
	_draw_button(layout_test_exit_rect, "테스트 종료", false)
	var status := "동시 입력 최고 %d개" % layout_test_peak_controls
	if not invalid_layout_controls.is_empty():
		status += " · 겹침 %d개" % invalid_layout_controls.size()
	_draw_text(
		status,
		Vector2(countdown_rect.position.x, countdown_rect.end.y + 26.0),
		17,
		Color("ff8b85") if not invalid_layout_controls.is_empty() else TEXT_COLOR
	)
	_draw_pointer_markers()


func _draw_combat_resume_countdown() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(BACKGROUND_COLOR, 0.72), true)
	var safe := _safe_area_in_viewport()
	var count := maxi(1, int(ceil(combat_resume_remaining_s)))
	_draw_text_centered(
		"전투 복귀",
		Rect2(Vector2(safe.position.x, safe.get_center().y - 110.0), Vector2(safe.size.x, 52.0)),
		28,
		TEXT_COLOR
	)
	_draw_text_centered(
		str(count),
		Rect2(Vector2(safe.position.x, safe.get_center().y - 48.0), Vector2(safe.size.x, 110.0)),
		72,
		ACTIVE_COLOR
	)
	_draw_text_centered(
		"새 배치로 곧 시작합니다",
		Rect2(Vector2(safe.position.x, safe.get_center().y + 72.0), Vector2(safe.size.x, 42.0)),
		19,
		MUTED_TEXT_COLOR
	)


func _draw_result_row(label: String, value: String, x: float, width: float, y: float) -> void:
	draw_rect(Rect2(Vector2(x, y - 26.0), Vector2(width, 52.0)), Color("102b3a"), true)
	_draw_text(label, Vector2(x + 18.0, y + 7.0), 18, MUTED_TEXT_COLOR)
	_draw_text(value, Vector2(x + width * 0.27, y + 7.0), 19, TEXT_COLOR)


func _current_record_summary() -> Dictionary:
	var summary := test_record_summary.duplicate(true)
	var stage_count := int(movement_metrics.get("run_stage_count", 1))
	if stage_count > 1:
		var stats: Dictionary = summary.get("completion_by_stage_count", {}).get(str(stage_count), {})
		for key in ["completed_run_count", "best_completion_s", "average_completion_s"]:
			summary[key] = stats.get(key, 0)
	return summary


func _section_time_summary() -> String:
	if int(result_snapshot.get("stage_count", 1)) > 1:
		var stage_parts: Array[String] = []
		for entry in result_snapshot.get("stage_history", []):
			stage_parts.append("%d %.1fs" % [int(entry["stage"]), float(entry["elapsed_s"])])
		return " · ".join(stage_parts)
	var actual_times: Array = result_snapshot.get("actual_times", [])
	if actual_times.is_empty():
		return "기록 없음"
	var parts: Array[String] = []
	for index in actual_times.size():
		parts.append("%d구간 %.1fs" % [index + 1, float(actual_times[index])])
	return " · ".join(parts)


func _draw_move_control() -> void:
	var active := move_pointer_id >= 0
	var outline := ACTIVE_COLOR if active else MOVE_COLOR
	draw_rect(move_zone, Color(MOVE_COLOR, (0.14 if active else 0.08) * control_opacity), true)
	draw_rect(move_zone, Color(outline, control_opacity), false, 4.0)
	_draw_text("이동", move_zone.position + Vector2(18.0, 30.0), 20, Color(MUTED_TEXT_COLOR, control_opacity))
	var knob := move_origin + move_vector * move_radius
	draw_circle(move_origin, move_radius, Color(MOVE_COLOR, 0.11 * control_opacity))
	draw_arc(move_origin, move_radius, 0.0, TAU, 48, Color(MOVE_COLOR, control_opacity), 4.0, true)
	draw_line(move_origin, knob, Color(outline, control_opacity), 7.0)
	var knob_radius := 45.0 * float(control_scales.get(MOVE_CONTROL, 1.0))
	draw_circle(knob, knob_radius, Color(outline, 0.31 * control_opacity))
	draw_arc(knob, knob_radius, 0.0, TAU, 40, Color(outline, control_opacity), 5.0, true)


func _draw_action_controls() -> void:
	for action_id in ACTION_ORDER:
		var rect: Rect2 = action_rects[action_id]
		var pressed := control_pointers.has(action_id)
		var ultimate_ready := action_id == &"ultimate" \
			and bool(movement_metrics.get("ultimate_ready", false))
		var ultimate_active := action_id == &"ultimate" \
			and bool(movement_metrics.get("ultimate_active", false))
		var color := ACTIVE_COLOR if pressed or ultimate_ready or ultimate_active else ACTION_COLOR
		if action_id == &"recovery_potion":
			color = PASS_COLOR if int(movement_metrics.get("potions_remaining", 2)) > 0 and int(movement_metrics.get("health", 100)) < int(movement_metrics.get("max_health", 100)) else MUTED_TEXT_COLOR
		draw_circle(rect.get_center(), rect.size.x * 0.5, Color(color, (0.30 if pressed else 0.20) * control_opacity))
		draw_arc(rect.get_center(), rect.size.x * 0.5, 0.0, TAU, 44, Color(color, control_opacity), 5.0, true)
		if action_id == &"ultimate":
			var ratio: float = float(movement_metrics.get("ultimate_gauge_ratio", 0.0))
			if ultimate_active:
				var duration: float = float(movement_metrics.get("ultimate_duration_s", 3.0))
				var remaining: float = float(movement_metrics.get("ultimate_remaining_s", 0.0))
				ratio = remaining / maxf(duration, 0.001)
			draw_arc(
				rect.get_center(), rect.size.x * 0.5 - 10.0,
				-PI * 0.5, -PI * 0.5 + TAU * clampf(ratio, 0.0, 1.0),
				48, Color(ACTIVE_COLOR, control_opacity), 9.0, true
			)
		_draw_text_centered(_action_label(action_id), rect, 18, Color(TEXT_COLOR, control_opacity))
		if action_id == &"recovery_potion":
			_draw_text_centered("체력 +%d%%" % int(movement_metrics.get("potion_heal_percent", 25)), Rect2(rect.position + Vector2(0, rect.size.y * 0.65), Vector2(rect.size.x, 24)), 13, Color(color, control_opacity))


func _action_label(action_id: StringName) -> String:
	if action_id == &"recovery_potion":
		return "회복 %d/%d" % [int(movement_metrics.get("potions_remaining", 2)), int(movement_metrics.get("potions_capacity", 2))]
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


func _layout_control_order() -> Array[StringName]:
	var order: Array[StringName] = [MOVE_CONTROL]
	order.append_array(ACTION_ORDER)
	return order


func _layout_control_label(control_id: StringName) -> String:
	if control_id == MOVE_CONTROL:
		return "이동 패드"
	return String(ACTION_LABELS.get(control_id, control_id))


func _control_touch_rect(control_id: StringName) -> Rect2:
	if control_id == MOVE_CONTROL:
		return move_zone
	return action_rects.get(control_id, Rect2())


func _control_touch_rects() -> Dictionary:
	var rects := {}
	for control_id in _layout_control_order():
		rects[control_id] = _control_touch_rect(control_id)
	return rects


func _layout_control_at(position: Vector2) -> StringName:
	var order := _layout_control_order()
	order.reverse()
	for control_id in order:
		if _control_touch_rect(control_id).has_point(position):
			return control_id
	return &""


func _validate_control_layout() -> void:
	invalid_layout_controls.clear()
	var order := _layout_control_order()
	for first_index in order.size():
		var first_id := order[first_index]
		var first_rect := _control_touch_rect(first_id)
		for second_index in range(first_index + 1, order.size()):
			var second_id := order[second_index]
			var second_rect := _control_touch_rect(second_id)
			if _touch_overlap_ratio(first_rect, second_rect) >= 0.30:
				if first_id not in invalid_layout_controls:
					invalid_layout_controls.append(first_id)
				if second_id not in invalid_layout_controls:
					invalid_layout_controls.append(second_id)


func _touch_overlap_ratio(first: Rect2, second: Rect2) -> float:
	var intersection := first.intersection(second)
	if intersection.size.x <= 0.0 or intersection.size.y <= 0.0:
		return 0.0
	var overlap_area := intersection.size.x * intersection.size.y
	var smaller_area := minf(first.size.x * first.size.y, second.size.x * second.size.y)
	return overlap_area / maxf(smaller_area, 1.0)


func _capture_control_layout() -> Dictionary:
	return {
		"centers": control_centers.duplicate(true),
		"scales": control_scales.duplicate(true),
		"opacity": control_opacity,
	}


func _default_layout_snapshot(centers: Dictionary) -> Dictionary:
	var scales := {}
	for control_id in _layout_control_order():
		scales[control_id] = 1.0
	return {
		"centers": centers.duplicate(true),
		"scales": scales,
		"opacity": 0.82,
	}


func _preset_layout(preset_id: String) -> Dictionary:
	if preset_id == PRESET_LEFT:
		return _default_layout_snapshot(LEFT_CONTROL_CENTERS)
	return _default_layout_snapshot(DEFAULT_CONTROL_CENTERS)


func _preset_layouts() -> Dictionary:
	return {
		PRESET_DEFAULT: _preset_layout(PRESET_DEFAULT),
		PRESET_LEFT: _preset_layout(PRESET_LEFT),
	}


func _preset_label(preset_id: String) -> String:
	match preset_id:
		PRESET_LEFT:
			return "왼손잡이"
		PRESET_CUSTOM:
			return "사용자 설정"
		_:
			return "기본"


func _mark_layout_custom() -> void:
	active_preset_id = PRESET_CUSTOM
	saved_custom_layout = _capture_control_layout()
	layout_store_message = "사용자 설정 · 적용 전"


func _load_saved_control_layout() -> void:
	var loaded := layout_store.load_layout(_preset_layouts(), _layout_control_order())
	active_preset_id = String(loaded.get("active_preset", PRESET_DEFAULT))
	saved_custom_layout = (loaded.get("custom_layout", {}) as Dictionary).duplicate(true)
	_restore_control_layout(loaded.get("active_layout", _preset_layout(PRESET_DEFAULT)))
	var recovered_controls: Array = loaded.get("recovered_controls", [])
	var recovered_fields: Array = loaded.get("recovered_fields", [])
	if active_preset_id == PRESET_CUSTOM and not recovered_controls.is_empty():
		saved_custom_layout = (loaded.get("active_layout", {}) as Dictionary).duplicate(true)
	if not recovered_controls.is_empty() or not recovered_fields.is_empty():
		layout_store_message = "손상 설정 일부를 기본값으로 복구했습니다"
	else:
		layout_store_message = "저장된 %s 프리셋" % _preset_label(active_preset_id)


func configure_layout_store_path_for_test(path: String) -> void:
	layout_store = ControlLayoutStore.new(path)


func reload_control_layout_from_store() -> void:
	_load_saved_control_layout()
	_refresh_layout()
	_validate_control_layout()
	queue_redraw()


func _restore_control_layout(snapshot: Dictionary) -> void:
	control_centers = (snapshot.get("centers", DEFAULT_CONTROL_CENTERS) as Dictionary).duplicate(true)
	control_scales = (snapshot.get("scales", {}) as Dictionary).duplicate(true)
	control_opacity = clampf(float(snapshot.get("opacity", 0.82)), 0.30, 1.00)
	_refresh_layout()
	_validate_control_layout()


func _clamp_control_center(center: Vector2, half_size: Vector2, safe: Rect2) -> Vector2:
	return Vector2(
		clampf(center.x, safe.position.x + half_size.x, safe.end.x - half_size.x),
		clampf(center.y, safe.position.y + half_size.y, safe.end.y - half_size.y)
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


func update_boss_legacy_status(pending: Dictionary, active: Dictionary) -> void:
	pending_boss_legacy = pending.duplicate(true)
	active_boss_legacy = active.duplicate(true)
	queue_redraw()


func _legacy_hud_label() -> String:
	match active_boss_legacy.get("choice"):
		"rescue": return " · 기사 회복 " + ("사용됨" if active_boss_legacy.rescue_used else "대기")
		"destroy": return " · 핵 +10% / 위험 +10%"
	return ""


func update_memory_status(unlocked: Dictionary, preferred: String, active: String) -> void:
	unlocked_memories = unlocked.duplicate()
	preferred_memory_id = preferred
	active_memory_id = active
	queue_redraw()


func update_weapon_blueprints(unlocked: Dictionary) -> void:
	unlocked_weapon_blueprints = unlocked.duplicate()
	queue_redraw()


func _draw_memory_cards() -> void:
	var safe := _safe_area_in_viewport()
	_draw_text_centered("영구 기억 · 하나만 장착", Rect2(safe.position + Vector2(0, safe.size.y * 0.55), Vector2(safe.size.x, safe.size.y * 0.03)), 14, MUTED_TEXT_COLOR)
	for index in memory_card_rects.size():
		var id: String = PrototypeMemoryAbilities.IDS[index]
		var card := PrototypeMemoryAbilities.profile(id)
		var available := PrototypeMemoryAbilities.available(id, unlocked_memories)
		var rect := memory_card_rects[index]
		draw_style_box(_panel_style(PANEL_COLOR), rect)
		if selected_memory_id == id and available:
			draw_rect(rect.grow(-3), ACTIVE_COLOR, false, 3)
		_draw_text_centered(String(card.name) + (" · 잠김" if not available else ""), Rect2(rect.position + Vector2(0, rect.size.y * 0.10), Vector2(rect.size.x, 28)), 19, ACTIVE_COLOR if available else MUTED_TEXT_COLOR)
		_draw_text_centered(String(card.effect if available else card.condition), Rect2(rect.position + Vector2(0, rect.size.y * 0.58), Vector2(rect.size.x, 24)), 16, TEXT_COLOR if available else MUTED_TEXT_COLOR)


func show_village() -> void:
	if screen_mode not in [ScreenMode.MAIN, ScreenMode.RESULT, ScreenMode.VILLAGE]:
		return
	release_all_inputs()
	village_page = "village"
	screen_mode = ScreenMode.VILLAGE
	if not village_environment_owned:
		village_environment_owned = true
		combat_configuration_started.emit()
	queue_redraw()


func _leave_village_environment() -> void:
	if village_environment_owned:
		village_environment_owned = false
		combat_configuration_finished.emit()


func village_snapshot() -> Dictionary:
	var cards := PrototypeVillageView.cards(village_page, unlocked_memories, unlocked_weapon_blueprints, test_record_summary, discovered_jobs, String(movement_metrics.get("growth_job_id", "")) if bool(movement_metrics.get("growth_run_active", false)) else "", preferred_potion_recipe)
	return {"page": village_page, "resident": bool(unlocked_memories.get("clockwork_guard", false)), "cards": cards, "layout": PrototypeVillageView.layout(_safe_area_in_viewport(), cards.size(), checkpoint_available)}


func _handle_village_touch(position: Vector2) -> void:
	var snapshot := village_snapshot()
	var layout: Dictionary = snapshot.layout
	if layout.back.has_point(position):
		if village_page == "village":
			show_main_screen()
		else:
			village_page = "village"
	elif layout.start.has_point(position):
		show_start_weapon_selection()
	elif checkpoint_available and layout["continue"].has_point(position):
		show_main_screen()
		continue_requested.emit()
	elif village_page == "village":
		for i in layout.cards.size():
			if layout.cards[i].has_point(position):
				village_page = PrototypeVillageView.FACILITIES[i]
				potion_recipe_message = ""
				break
	elif village_page == "apothecary":
		for i in layout.cards.size():
			if layout.cards[i].has_point(position) and snapshot.cards[i].open:
				potion_recipe_selected.emit(String(snapshot.cards[i].id))
				break
	queue_redraw()


func _draw_village() -> void:
	var safe := _safe_area_in_viewport()
	var snapshot := village_snapshot()
	var layout: Dictionary = snapshot.layout
	draw_rect(Rect2(Vector2.ZERO, size), Color("182d36"))
	draw_rect(Rect2(safe.position + Vector2(0, safe.size.y * 0.25), Vector2(safe.size.x, safe.size.y * 0.75)), Color("2b4b43"))
	draw_circle(safe.position + Vector2(safe.size.x * 0.90, safe.size.y * 0.11), safe.size.y * 0.06, Color("eacb88"))
	_draw_text_centered(PrototypeVillageView.TITLES[village_page], Rect2(safe.position + Vector2(0, safe.size.y * 0.04), Vector2(safe.size.x, safe.size.y * 0.09)), 34, ACTIVE_COLOR)
	var subtitle := "도전 사이에 머무는 작은 안식처" if village_page == "village" else "설계도는 정예 보상에서 획득" if village_page == "forge" else "기억 장착은 새 도전 준비에서 선택" if village_page == "memories" else "발현 조건을 채워 도전마다 직업을 발견하세요" if village_page == "jobs" else "다음 새 도전의 회복약을 선택하세요" if village_page == "apothecary" else "이 기기의 로컬 도전 기록"
	_draw_text_centered(subtitle, Rect2(safe.position + Vector2(0, safe.size.y * 0.15), Vector2(safe.size.x, safe.size.y * 0.06)), 20, TEXT_COLOR)
	var resident := potion_recipe_message if village_page == "apothecary" and not potion_recipe_message.is_empty() else "약초사 · 이어하기의 회복약은 바꾸지 않아요." if village_page == "apothecary" and snapshot.resident else "약초사 · 보스 구출 후 농축 조제를 열어 드려요." if village_page == "apothecary" else "정착한 태엽 기사 · 다음 여행도 무사히 돌아오세요." if snapshot.resident else "태엽 기사 · 보스 구출 후 마을에 정착합니다."
	_draw_text_centered(resident, Rect2(safe.position + Vector2(0, safe.size.y * 0.25), Vector2(safe.size.x, safe.size.y * 0.06)), 19, ACTIVE_COLOR if snapshot.resident else MUTED_TEXT_COLOR)
	for i in snapshot.cards.size():
		var card: Dictionary = snapshot.cards[i]
		var rect: Rect2 = layout.cards[i]
		var color := Color("3f675b") if card.open else Color("354752")
		draw_style_box(_panel_style(color), rect)
		if village_page == "apothecary" and card.id == preferred_potion_recipe:
			draw_rect(rect.grow(-3), ACTIVE_COLOR, false, 3)
		# 마을 건물의 지붕을 코드로 그린다.
		if village_page == "village":
			var roof_y := rect.position.y + rect.size.y * 0.13
			draw_colored_polygon(PackedVector2Array([Vector2(rect.position.x + 20, roof_y), Vector2(rect.get_center().x, rect.position.y - 10), Vector2(rect.end.x - 20, roof_y)]), Color("ab765b") if card.open else Color("607078"))
		var title_rect := Rect2(rect.position + Vector2(12, rect.size.y * 0.16), Vector2(rect.size.x - 24, rect.size.y * 0.13))
		_draw_village_text(card.name, title_rect, 26, TEXT_COLOR)
		_draw_village_text(String(card.get("status", "열림" if card.open else "잠김 · 조건을 확인하세요")), Rect2(rect.position + Vector2(12, rect.size.y * 0.31), Vector2(rect.size.x - 24, rect.size.y * 0.08)), 17, ACTIVE_COLOR if card.open else MUTED_TEXT_COLOR)
		for j in card.lines.size():
			_draw_village_text(String(card.lines[j]), Rect2(rect.position + Vector2(12, rect.size.y * (0.44 + j * 0.08)), Vector2(rect.size.x - 24, rect.size.y * 0.08)), 18, TEXT_COLOR)
		if village_page == "apothecary":
			var bottle := rect.position + Vector2(rect.size.x * 0.86, rect.size.y * 0.20)
			draw_rect(Rect2(bottle - Vector2(8, 24), Vector2(16, 9)), Color("ba9768"))
			draw_style_box(_panel_style(Color("d47961") if card.id == PrototypePotionRecipes.BASIC else Color("cda54b")), Rect2(bottle - Vector2(16, 13), Vector2(32, 33)))
	_draw_button(layout.back, "메인 화면" if village_page == "village" else "마을로", false)
	_draw_button(layout.start, "새 도전 준비", true)
	if checkpoint_available:
		_draw_button(layout["continue"], "이어하기", true)


func _draw_village_text(value: String, rect: Rect2, requested_size: int, color: Color) -> void:
	var font_size := mini(requested_size, maxi(12, int(rect.size.y * 0.8)))
	while font_size > 10 and ThemeDB.fallback_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x:
		font_size -= 1
	_draw_text_centered(value, rect, font_size, color)


func update_potion_recipe_status(id: String, message: String = "") -> void:
	preferred_potion_recipe = id
	potion_recipe_message = message
	queue_redraw()


func _refresh_relic_reward_layout() -> void:
	var safe := _safe_area_in_viewport()
	relic_reward_card_rect = Rect2(safe.position + Vector2(safe.size.x * 0.18, safe.size.y * 0.21), Vector2(safe.size.x * 0.64, safe.size.y * 0.47))
	var width := safe.size.x * 0.40
	relic_reward_cancel_rect = Rect2(safe.position + Vector2(safe.size.x * 0.07, safe.size.y * 0.80), Vector2(width, safe.size.y * 0.09))
	relic_reward_confirm_rect = Rect2(safe.position + Vector2(safe.size.x * 0.53, safe.size.y * 0.80), relic_reward_cancel_rect.size)


func _draw_relic_rewards() -> void:
	_refresh_relic_reward_layout()
	var safe := _safe_area_in_viewport()
	draw_rect(Rect2(Vector2.ZERO, size), Color(BACKGROUND_COLOR, 0.97), true)
	_draw_text_centered("첫 유물 · 마지막 관문을 위한 준비", Rect2(safe.position + Vector2(0, safe.size.y * 0.06), Vector2(safe.size.x, 50)), 30, ACTIVE_COLOR)
	draw_style_box(_panel_style(PANEL_COLOR), relic_reward_card_rect)
	var rect := relic_reward_card_rect
	_draw_text_centered("희귀 · 불사조 깃털", Rect2(rect.position + Vector2(0, rect.size.y * 0.07), Vector2(rect.size.x, 42)), 28, Color("ffca78"))
	var center := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.37)
	var feather := PackedVector2Array([center + Vector2(0, -28), center + Vector2(18, -8), center + Vector2(14, 14), center + Vector2(0, 30), center + Vector2(-14, 14), center + Vector2(-18, -8)])
	draw_colored_polygon(feather, Color("ffa86a"))
	draw_line(center + Vector2(0, -16), center + Vector2(0, 33), Color("fff1cf"), 3.0)
	for offset in [-8.0, 3.0, 14.0]:
		draw_line(center + Vector2(-12, offset - 8), center + Vector2(0, offset), Color("fff1cf"), 2.0)
		draw_line(center + Vector2(12, offset - 8), center + Vector2(0, offset), Color("fff1cf"), 2.0)
	var lines := ["치명적인 피해를 받으면 체력 50%로 부활", "이 도전에서 한 번 · 부활 후 1초 보호", "새 도전에는 가져갈 수 없습니다"]
	for i in lines.size():
		_draw_text_centered(lines[i], Rect2(rect.position + Vector2(0, rect.size.y * (0.57 + i * 0.12)), Vector2(rect.size.x, 30)), 19, TEXT_COLOR)
	_draw_button(relic_reward_cancel_rect, "나중에 선택", false)
	_draw_button(relic_reward_confirm_rect, "유물 획득", true)
	if not checkpoint_message.is_empty():
		_draw_text_centered(checkpoint_message, Rect2(safe.position + Vector2(0, safe.size.y * 0.92), Vector2(safe.size.x, 28)), 16, WAIT_COLOR)


func update_skill_reward_status(loadout: Dictionary, claimed: bool) -> void:
	skill_reward_loadout = loadout.duplicate(true)
	skill_reward_claimed = claimed
	skill_reward_offers = PrototypeSkillRewards.offers(loadout)
	queue_redraw()


func show_skill_rewards() -> void:
	if screen_mode != ScreenMode.STAGE_ROUTE or skill_reward_claimed:
		return
	release_all_inputs()
	selected_skill_offer = -1
	selected_skill_slot = -1
	screen_mode = ScreenMode.SKILL_REWARD
	_refresh_skill_reward_layout()
	queue_redraw()


func _refresh_skill_reward_layout() -> void:
	var safe := _safe_area_in_viewport()
	var gap := safe.size.x * 0.02
	var width := (safe.size.x * 0.90 - gap) * 0.5
	skill_reward_offer_rects.clear()
	skill_reward_slot_rects.clear()
	for i in 2:
		skill_reward_offer_rects.append(Rect2(safe.position + Vector2(safe.size.x * 0.05 + i * (width + gap), safe.size.y * 0.17), Vector2(width, safe.size.y * 0.28)))
		skill_reward_slot_rects.append(Rect2(safe.position + Vector2(safe.size.x * 0.05 + i * (width + gap), safe.size.y * 0.53), Vector2(width, safe.size.y * 0.22)))
	skill_reward_cancel_rect = Rect2(safe.position + Vector2(safe.size.x * 0.05, safe.size.y * 0.84), Vector2(width, safe.size.y * 0.09))
	skill_reward_confirm_rect = Rect2(safe.position + Vector2(safe.size.x * 0.05 + width + gap, safe.size.y * 0.84), skill_reward_cancel_rect.size)


func _handle_skill_reward_touch(position: Vector2) -> void:
	_refresh_skill_reward_layout()
	for i in skill_reward_offers.size():
		if skill_reward_offer_rects[i].has_point(position):
			selected_skill_offer = i
			selected_skill_slot = -1
			return
	if selected_skill_offer >= 0:
		for i in 2:
			if skill_reward_slot_rects[i].has_point(position):
				selected_skill_slot = i
				return
	if skill_reward_cancel_rect.has_point(position):
		show_stage_routes(cleared_stage, run_stage_count, stage_recovered_health, stage_route_options)
	elif skill_reward_confirm_rect.has_point(position) and selected_skill_offer >= 0 and selected_skill_slot >= 0:
		skill_reward_selected.emit(String(skill_reward_offers[selected_skill_offer].id), selected_skill_slot)


func _draw_skill_rewards() -> void:
	_refresh_skill_reward_layout()
	var safe := _safe_area_in_viewport()
	draw_rect(Rect2(Vector2.ZERO, size), Color(BACKGROUND_COLOR, 0.98))
	_draw_text_centered("스킬 보상 · 기존 기술과 비교", Rect2(safe.position + Vector2(0, safe.size.y * 0.05), Vector2(safe.size.x, safe.size.y * 0.07)), 30, ACTIVE_COLOR)
	for i in skill_reward_offers.size():
		var offer: Dictionary = skill_reward_offers[i]
		var rect: Rect2 = skill_reward_offer_rects[i]
		draw_style_box(_panel_style(Color("365d68") if i == selected_skill_offer else PANEL_COLOR), rect)
		_draw_village_text(("검 · " if offer.weapon == "sword" else "활 · ") + String(offer.name), Rect2(rect.position + Vector2(12, 12), Vector2(rect.size.x - 24, rect.size.y * 0.20)), 25, TEXT_COLOR)
		for j in offer.lines.size():
			_draw_village_text(String(offer.lines[j]), Rect2(rect.position + Vector2(12, rect.size.y * (0.33 + j * 0.18)), Vector2(rect.size.x - 24, rect.size.y * 0.14)), 19, MUTED_TEXT_COLOR)
	_draw_text_centered("기술을 고른 뒤 교체할 슬롯을 선택하세요", Rect2(safe.position + Vector2(0, safe.size.y * 0.46), Vector2(safe.size.x, safe.size.y * 0.06)), 19, TEXT_COLOR)
	for i in 2:
		var rect: Rect2 = skill_reward_slot_rects[i]
		draw_style_box(_panel_style(Color("365d68") if i == selected_skill_slot else PANEL_COLOR), rect)
		var id := ""
		if selected_skill_offer >= 0:
			id = String(skill_reward_loadout[skill_reward_offers[selected_skill_offer].weapon][i])
		var label := "슬롯 %d · %s" % [i + 1, PrototypeSkillRewards.SKILLS[id].display_name if not id.is_empty() else "기술을 먼저 선택"]
		_draw_village_text(label, Rect2(rect.position + Vector2(12, 10), Vector2(rect.size.x - 24, rect.size.y * 0.25)), 22, TEXT_COLOR)
		if not id.is_empty():
			var lines := PrototypeSkillRewards.lines(id)
			for j in lines.size():
				_draw_village_text(lines[j], Rect2(rect.position + Vector2(12, rect.size.y * (0.35 + j * 0.19)), Vector2(rect.size.x - 24, rect.size.y * 0.15)), 17, MUTED_TEXT_COLOR)
	_draw_text_centered(checkpoint_message if checkpoint_message.begins_with("중간 저장 실패") else "정예마다 한 번 교체 · 교체한 스킬은 대기시간부터 시작", Rect2(safe.position + Vector2(0, safe.size.y * 0.77), Vector2(safe.size.x, safe.size.y * 0.05)), 17, MUTED_TEXT_COLOR)
	_draw_button(skill_reward_cancel_rect, "현재 구성 유지", false)
	_draw_button(skill_reward_confirm_rect, "교체 확정", selected_skill_offer >= 0 and selected_skill_slot >= 0)


func update_job_codex_status(discovered: Dictionary, message: String = "") -> void:
	discovered_jobs = discovered.duplicate()
	job_codex_message = message
	queue_redraw()
