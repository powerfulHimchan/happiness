extends Node2D

## GP-101 성장 선택과 CP 전투·타격 피드백·로컬 기록 환경을 담당한다.

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
@onready var weapon_controller: PrototypeWeaponController = $Player/PrototypeWeaponController
@onready var ultimate_controller: UltimateController = $Player/UltimateController
@onready var feedback_controller: CombatFeedbackController = $CombatFeedbackController
@onready var test_recorder: LocalTestRecorder = $LocalTestRecorder
@onready var controls: Control = $CanvasLayer/GroundMovementControls
@onready var stage_runner: PrototypeStageRunner = $StageRunner
@onready var growth: PrototypeGrowthController = $PrototypeGrowthController

var _growth_pause_owned: bool = false
var _growth_previous_tree_pause: bool = false
var _growth_previous_controls_mode: int = Node.PROCESS_MODE_INHERIT

var _enemy_metrics_elapsed_s: float = 0.0
var _combat_environment_suspended: bool = false
var _suspended_node_states: Array[Dictionary] = []


func _ready() -> void:
	growth.metrics_changed.connect(controls.update_growth_metrics)
	growth.choices_requested.connect(_on_growth_choices_requested)
	growth.selection_finished.connect(_finish_growth_selection)
	growth.job_manifested.connect(_on_job_manifested)
	controls.job_confirmed.connect(growth.choose_job_ultimate)
	controls.growth_card_selected.connect(growth.choose_card)
	controls.growth_reroll_requested.connect(growth.reroll)
	stage_runner.stage_metrics_changed.connect(_on_growth_stage_metrics)
	controls.update_growth_metrics(growth.metrics_snapshot())
	controls.move_vector_changed.connect(player.set_move_vector)
	controls.jump_pressed.connect(player.request_jump)
	controls.jump_released.connect(player.release_jump)
	controls.evade_pressed.connect(player.request_evade)
	controls.skill_1_pressed.connect(weapon_controller.request_skill_1)
	controls.skill_2_pressed.connect(weapon_controller.request_skill_2)
	controls.ultimate_pressed.connect(ultimate_controller.request_ultimate)
	controls.weapon_swap_pressed.connect(weapon_controller.request_weapon_switch)
	controls.reset_requested.connect(_reset_test)
	controls.retry_requested.connect(_reset_test)
	controls.layout_test_started.connect(_on_layout_test_started)
	controls.layout_test_finished.connect(_on_layout_test_finished)
	controls.combat_configuration_started.connect(_suspend_combat_environment)
	controls.combat_configuration_finished.connect(_restore_combat_environment)
	controls.feedback_settings_changed.connect(feedback_controller.configure)
	controls.test_records_clear_requested.connect(test_recorder.clear_records)
	player.fall_recovery_started.connect(controls.release_all_inputs)
	player.player_died.connect(controls.release_all_inputs)
	player.movement_metrics_changed.connect(controls.update_movement_metrics)
	target_selector.target_metrics_changed.connect(controls.update_target_metrics)
	weapon_controller.combat_metrics_changed.connect(controls.update_combat_metrics)
	ultimate_controller.ultimate_metrics_changed.connect(controls.update_ultimate_metrics)
	test_recorder.summary_changed.connect(controls.update_test_record_summary)
	stage_runner.stage_metrics_changed.connect(test_recorder.record_stage_metrics)
	stage_runner.stage_metrics_changed.connect(controls.update_stage_metrics)
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
	var feedback_settings: Dictionary = controls.feedback_settings_snapshot()
	feedback_controller.configure(
		float(feedback_settings["sound_volume"]),
		bool(feedback_settings["vibration_enabled"]),
		bool(feedback_settings["screen_shake_enabled"])
	)
	controls.update_test_record_summary(test_recorder.summary_snapshot())
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
		"damage_dead": false,
		"damage_post_hit_invulnerable": false,
		"damage_post_hit_remaining_s": 0.0,
		"damage_applied_count": 0,
		"damage_duplicate_blocked_count": 0,
		"damage_invulnerable_blocked_count": 0,
		"damage_dead_blocked_count": 0,
		"damage_last_result": "대기",
		"damage_last_event_id": "없음",
		"last_damage_log": "피해 기록 대기",
		"last_damage_summary": "없음",
		"last_damage_tags": "없음",
		"last_stagger_s": 0.0,
		"damage_cause_counts": {},
		"damage_cause_summary": "피격 없음",
	})
	target_selector.force_scan()
	weapon_controller.force_emit_metrics()
	ultimate_controller.force_emit_metrics()
	stage_runner.force_emit_metrics()
	_emit_enemy_metrics()
	queue_redraw()


func _process(delta: float) -> void:
	_enemy_metrics_elapsed_s += delta
	if _enemy_metrics_elapsed_s < 0.10:
		return
	_enemy_metrics_elapsed_s = 0.0
	_emit_enemy_metrics()


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
	growth.reset_run()
	for node in get_tree().get_nodes_in_group("targetable"):
		var target := node as PrototypeTarget
		if target != null:
			target.reset_target()
	target_selector.reset_selection()
	weapon_controller.reset_combat()
	ultimate_controller.reset_ultimate()
	test_recorder.start_run()
	stage_runner.reset_stage()
	for projectile in get_tree().get_nodes_in_group("enemy_projectile"):
		projectile.queue_free()
	_enemy_metrics_elapsed_s = 0.0
	_emit_enemy_metrics()
	controls.release_all_inputs()


func _begin_growth_pause() -> void:
	if not _growth_pause_owned:
		_growth_previous_tree_pause = get_tree().paused
		_growth_previous_controls_mode = controls.process_mode
		_growth_pause_owned = true
	controls.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true


func _on_growth_choices_requested(cards: Array[Dictionary], level: int, rerolls: int) -> void:
	_begin_growth_pause()
	controls.show_growth_choices(cards, level, rerolls)


func _on_job_manifested(job: Dictionary) -> void:
	_begin_growth_pause()
	controls.show_job_manifestation(job)


func _finish_growth_selection() -> void:
	if not _growth_pause_owned:
		return
	controls.finish_growth_selection()
	controls.process_mode = _growth_previous_controls_mode
	get_tree().paused = _growth_previous_tree_pause
	_growth_pause_owned = false


func _on_growth_stage_metrics(metrics: Dictionary) -> void:
	if bool(metrics.get("stage_complete", false)):
		growth.stop_run()


func _exit_tree() -> void:
	if _growth_pause_owned:
		get_tree().paused = _growth_previous_tree_pause


func _on_layout_test_started() -> void:
	_suspend_combat_environment()


func _on_layout_test_finished() -> void:
	if not controls.layout_editor_returns_to_combat():
		_restore_combat_environment()


func _suspend_combat_environment() -> void:
	if _combat_environment_suspended:
		return
	_combat_environment_suspended = true
	_suspended_node_states.clear()
	var nodes: Array[Node] = [stage_runner, target_selector]
	for group_name in [&"combat_enemy", &"enemy_projectile", &"targetable"]:
		for candidate in get_tree().get_nodes_in_group(group_name):
			var candidate_node := candidate as Node
			if candidate_node != null and candidate_node not in nodes:
				nodes.append(candidate_node)
	for suspended_node in nodes:
		var state := {
			"node": suspended_node,
			"process_mode": suspended_node.process_mode,
			"was_targetable": suspended_node.is_in_group("targetable"),
			"visible": null,
		}
		if suspended_node is CanvasItem:
			state["visible"] = (suspended_node as CanvasItem).visible
			(suspended_node as CanvasItem).visible = false
		if bool(state["was_targetable"]):
			suspended_node.remove_from_group("targetable")
		suspended_node.process_mode = Node.PROCESS_MODE_DISABLED
		_suspended_node_states.append(state)
	target_selector.reset_selection()


func _restore_combat_environment() -> void:
	if not _combat_environment_suspended:
		return
	for state in _suspended_node_states:
		var suspended_node := state.get("node") as Node
		if not is_instance_valid(suspended_node):
			continue
		suspended_node.process_mode = int(state.get("process_mode", Node.PROCESS_MODE_INHERIT))
		if state.get("visible") != null and suspended_node is CanvasItem:
			(suspended_node as CanvasItem).visible = bool(state["visible"])
		if bool(state.get("was_targetable", false)):
			suspended_node.add_to_group("targetable")
	_suspended_node_states.clear()
	_combat_environment_suspended = false
	target_selector.force_scan()


func is_combat_environment_suspended() -> bool:
	return _combat_environment_suspended


func _emit_enemy_metrics() -> void:
	var alive_count := 0
	var warning_count := 0
	var attack_count := 0
	var hit_count := 0
	var state_labels: Array[String] = []
	var newest_log := "행동 대기"
	var newest_event_msec := -1
	var elite_metrics: Dictionary = {}
	for enemy in get_tree().get_nodes_in_group("combat_enemy"):
		if not enemy.has_method("current_metrics"):
			continue
		var metrics: Dictionary = enemy.current_metrics()
		if bool(metrics.get("enemy_alive", false)):
			alive_count += 1
		if bool(metrics.get("enemy_warning", false)):
			warning_count += 1
		attack_count += int(metrics.get("enemy_attack_count", 0))
		hit_count += int(metrics.get("enemy_hit_count", 0))
		state_labels.append("%s %s" % [
			String(metrics.get("enemy_name", "적")),
			String(metrics.get("enemy_state", "대기")),
		])
		var event_msec := int(metrics.get("enemy_event_msec", -1))
		if event_msec >= newest_event_msec:
			newest_event_msec = event_msec
			newest_log = String(metrics.get("enemy_last_log", "행동 대기"))
		if enemy.is_in_group("elite_enemy"):
			elite_metrics = metrics
	controls.update_enemy_metrics({
		"enemy_alive_count": alive_count,
		"enemy_total_count": 4,
		"enemy_warning_active_count": warning_count,
		"enemy_attack_total_count": attack_count,
		"enemy_hit_total_count": hit_count,
		"enemy_projectile_count": get_tree().get_nodes_in_group("enemy_projectile").size(),
		"enemy_state_summary": " · ".join(state_labels),
		"enemy_last_log": newest_log,
		"elite_phase": int(elite_metrics.get("elite_phase", 0)),
		"elite_state": String(elite_metrics.get("enemy_state", "미등장")),
		"elite_pattern": String(elite_metrics.get("elite_pattern", "없음")),
		"elite_weakness": String(elite_metrics.get("elite_weakness", "활 125%")),
		"elite_health": int(elite_metrics.get("elite_health", 0)),
		"elite_max_health": int(elite_metrics.get("elite_max_health", 180)),
	})


func _on_safe_zone_entered(
	body: Node2D,
	spawn_position: Vector2,
	safe_label: String
) -> void:
	if body != player:
		return
	player.set_safe_spawn(spawn_position, safe_label)
