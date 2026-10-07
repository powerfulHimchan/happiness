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
var _intermission_stage: int = 0
var _stage_recovered_health: int = 0
var checkpoint_store := RunCheckpointStore.new()
var boss_legacy_store := BossLegacyStore.new()
var ability_discovery_store := AbilityDiscoveryStore.new()
var _ability_codex_message: String = ""
var _job_codex_message: String = ""
var _pending_route_records: Array = []
var _route_atlas_message: String = ""
var _last_legacy_grant_source: String = ""
var _last_legacy_grant_path: String = ""
var _restoring_checkpoint: bool = false
var _available_checkpoint: Dictionary = {}

var _enemy_metrics_elapsed_s: float = 0.0
var _combat_environment_suspended: bool = false
var _suspended_node_states: Array[Dictionary] = []


func _ready() -> void:
	player.boss_legacy_store = boss_legacy_store
	player.phoenix_allowed = _can_collect_recovery_orb
	player.lifesteal_allowed = _can_collect_recovery_orb
	growth.record_ability = _record_abilities
	_record_abilities([])
	_update_boss_legacy_status()
	growth.metrics_changed.connect(controls.update_growth_metrics)
	growth.choices_requested.connect(_on_growth_choices_requested)
	growth.selection_finished.connect(_finish_growth_selection)
	growth.job_manifested.connect(_on_job_manifested)
	controls.job_confirmed.connect(_confirm_job)
	controls.stage_route_selected.connect(_continue_stage)
	controls.weapon_reward_selected.connect(_claim_weapon_reward)
	controls.skill_reward_selected.connect(_claim_skill_reward)
	controls.relic_reward_selected.connect(_claim_relic_reward)
	controls.potion_recipe_selected.connect(_select_potion_recipe)
	controls.route_records_retry_requested.connect(_retry_route_records)
	controls.boss_choice_confirmed.connect(_resolve_boss_choice)
	controls.continue_requested.connect(continue_saved_run)
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
	controls.recovery_potion_pressed.connect(_use_recovery_potion)
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
	player.damage_received.connect(_on_boss_legacy_damage)
	player.player_died.connect(controls.release_all_inputs)
	player.phoenix_revived.connect(controls.release_all_inputs)
	player.player_died.connect(_finish_growth_selection)
	player.player_died.connect(_discard_checkpoint)
	player.movement_metrics_changed.connect(controls.update_movement_metrics)
	target_selector.target_metrics_changed.connect(controls.update_target_metrics)
	weapon_controller.combat_metrics_changed.connect(controls.update_combat_metrics)
	ultimate_controller.ultimate_metrics_changed.connect(controls.update_ultimate_metrics)
	test_recorder.summary_changed.connect(controls.update_test_record_summary)
	stage_runner.stage_metrics_changed.connect(_record_stage_metrics)
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
	_refresh_checkpoint()
	if not _available_checkpoint.is_empty():
		controls.show_main_screen()


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
	# 확정 저장을 먼저 회수하고 보상 소비 저장 실패 시 새 도전을 시작하지 않는다.
	_refresh_checkpoint()
	if not _available_checkpoint.is_empty() and (not _job_codex_message.is_empty() or not _ability_codex_message.is_empty()):
		controls.show_main_screen()
		return
	if not _available_checkpoint.is_empty() and not String(_available_checkpoint.stage.get("boss_choice", "")).is_empty() and not _grant_boss_legacy(String(_available_checkpoint.recorder.id), String(_available_checkpoint.stage.boss_choice)):
		controls.show_main_screen()
		return
	var run_id := "%d-%d-%d" % [int(Time.get_unix_time_from_system() * 1000), Time.get_ticks_usec(), randi()]
	var claimed := boss_legacy_store.claim(run_id, controls.use_boss_legacy, controls.selected_memory_id)
	if claimed.error != OK:
		controls.show_main_screen()
		controls.update_checkpoint_status(not _available_checkpoint.is_empty(), "보상·기억 저장 실패 · 다시 시작하세요")
		return
	_discard_checkpoint()
	_finish_growth_selection()
	_intermission_stage = 0
	player.reset_movement_test(TRACK_START)
	player.prepare_potions(String(boss_legacy_store.progress_snapshot().potion_recipe))
	weapon_controller.reset_combat(controls.selected_starting_weapon)
	growth.reset_run(weapon_controller.active_weapon_id)
	player.boss_legacy = claimed.state
	player.memory_id = claimed.memory_id
	var memory_health := PrototypeMemoryAbilities.health_bonus(player.memory_id)
	player.apply_growth_health(memory_health, memory_health)
	if player.boss_legacy.get("choice") == "rescue":
		player.apply_growth_health(10, 10)
	_update_boss_legacy_status()
	for node in get_tree().get_nodes_in_group("targetable"):
		var target := node as PrototypeTarget
		if target != null:
			target.reset_target()
	target_selector.reset_selection()
	ultimate_controller.reset_ultimate()
	test_recorder.start_run(run_id)
	player.relic_run_id = run_id
	if controls.requested_stage_limit > 0:
		stage_runner.stage_limit = controls.requested_stage_limit
	stage_runner.reset_run()
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
	_discover_job(String(job.id))


func _finish_growth_selection() -> void:
	if not _growth_pause_owned:
		return
	controls.finish_growth_selection()
	controls.process_mode = _growth_previous_controls_mode
	get_tree().paused = _growth_previous_tree_pause
	_growth_pause_owned = false


func _on_growth_stage_metrics(metrics: Dictionary) -> void:
	if _restoring_checkpoint:
		return
	if not bool(metrics.get("stage_complete", false)):
		if growth.run_active and int(metrics.get("stage_section_index", 0)) == 5 and boss_legacy_store.spend_assist(player.boss_legacy, stage_runner.stage_number):
			var event := DamageEvent.new()
			event.event_id = StringName("helper:%s:%d" % [player.boss_legacy.run_id, stage_runner.stage_number])
			event.attacker_id = &"clockwork_helper"
			event.attack_id = &"clockwork_support"
			event.damage = 20
			event.tags = PackedStringArray(["helper"])
			stage_runner.final_enemy().receive_damage(event)
			_update_boss_legacy_status()
		return
	if growth.run_active and not player.damage_receiver.dead:
		_record_route_history(stage_runner.stage_history)
	if bool(metrics.get("run_complete", true)):
		_finish_growth_selection()
		growth.stop_run()
		var reward_saved := _grant_boss_legacy(String(test_recorder.checkpoint_snapshot().id), String(metrics.get("boss_choice", "")))
		test_recorder.record_stage_metrics(metrics)
		if reward_saved and test_recorder.has_completed_run(String(test_recorder.checkpoint_snapshot().id)):
			_discard_checkpoint()
	elif stage_runner.awaiting_boss_choice() and growth.run_active and not player.damage_receiver.dead:
		if controls.current_screen_mode() != 12:
			controls.release_all_inputs()
			_begin_growth_pause()
			controls.show_boss_choice()
			_save_checkpoint(metrics)
	elif growth.run_active and not player.damage_receiver.dead and _intermission_stage != stage_runner.stage_number:
		_intermission_stage = stage_runner.stage_number
		controls.release_all_inputs()
		var healing := ceili(player.damage_receiver.max_health * 0.20)
		if stage_runner.route_id == "clockwork":
			healing += 20
			ultimate_controller.grant_stage_gauge(50)
		var before := player.damage_receiver.health
		player.apply_growth_health(0, healing)
		_stage_recovered_health = player.damage_receiver.health - before
		_begin_growth_pause()
		controls.show_weapon_rewards(stage_runner.stage_number, PrototypeWeaponRewards.offers(stage_runner.stage_number, weapon_controller.equipment, weapon_controller.unlocked_blueprints, weapon_controller.blueprints))
		_save_checkpoint(metrics)


func _use_recovery_potion() -> bool:
	if controls.current_screen_mode() != 0 or not growth.run_active or get_tree().paused or stage_runner.stage_complete:
		return false
	return player.use_recovery_potion()


func _can_collect_recovery_orb() -> bool:
	return controls.current_screen_mode() == 0 and growth.run_active \
		and not get_tree().paused and not _combat_environment_suspended \
		and stage_runner.stage_enabled and not stage_runner.stage_complete


func _save_checkpoint(metrics: Dictionary, record_metrics: bool = true) -> Error:
	if growth.choosing or growth.awaiting_job_confirmation:
		return ERR_BUSY
	var ability_error := _record_abilities(growth.ranks.keys())
	if ability_error != OK:
		controls.update_checkpoint_status(not _available_checkpoint.is_empty(), _ability_codex_message)
		return ability_error
	var job_error := _discover_job(growth.jobs.job_id)
	if job_error != OK:
		controls.update_checkpoint_status(not _available_checkpoint.is_empty(), "중간 저장 실패 · 직업 기록을 다시 저장해야 합니다")
		return job_error
	if record_metrics:
		test_recorder.record_stage_metrics(metrics)
	var state := {
		"stage": stage_runner.checkpoint_snapshot(),
		"growth": growth.checkpoint_snapshot(),
		"player": {"health": player.damage_receiver.health, "max_health": player.damage_receiver.max_health, "common": player.growth_common_bonus, "sword": player.growth_sword_bonus, "bow": player.growth_bow_bonus, "potions_remaining": player.potions_remaining, "potion_recipe": player.potion_recipe, "lifesteal_progress": player.lifesteal_progress, "barrier_health": player.damage_receiver.barrier_health},
		"weapons": weapon_controller.checkpoint_snapshot(),
		"ultimate": {"gauge": ultimate_controller.gauge, "profile": String(ultimate_controller.selected_profile.get("id", ""))},
		"recorder": test_recorder.checkpoint_snapshot(),
		"boss_legacy": player.boss_legacy.duplicate(true),
		"memory_id": player.memory_id,
		"relic": player.relic_state.duplicate(),
	}
	var error := checkpoint_store.save_checkpoint(state)
	if error == OK:
		_available_checkpoint = state.duplicate(true)
	controls.update_checkpoint_status(not _available_checkpoint.is_empty(), checkpoint_store.message if error == OK else "중간 저장 실패 · 오류 %d" % error)
	return error


func _claim_weapon_reward(id: String) -> bool:
	if controls.current_screen_mode() != 11 or not stage_runner.has_next_stage() or stage_runner.reward_claimed or not growth.run_active or player.damage_receiver.dead:
		return false
	var previous := weapon_controller.equipment.duplicate()
	var previous_blueprints := weapon_controller.blueprints.duplicate()
	if not id.is_empty():
		var offer: Dictionary = {}
		for candidate in PrototypeWeaponRewards.offers(stage_runner.stage_number, weapon_controller.equipment, weapon_controller.unlocked_blueprints, weapon_controller.blueprints):
			if candidate.id == id:
				offer = candidate
		if offer.is_empty():
			return false
		if offer.name != offer.previous_name and not weapon_controller.equip_reward(id, mini(stage_runner.stage_number, 2)):
			return false
	stage_runner.reward_claimed = true
	if _save_checkpoint(stage_runner.current_metrics()) != OK:
		stage_runner.reward_claimed = false
		weapon_controller.set_loadout(previous, previous_blueprints)
		return false
	_show_intermission_routes()
	return true


func _resolve_boss_choice(choice: String) -> bool:
	if controls.current_screen_mode() != 12 or not stage_runner.awaiting_boss_choice() or not growth.run_active or player.damage_receiver.dead or choice not in ["rescue", "destroy"]:
		return false
	stage_runner.boss_choice = choice
	stage_runner.stage_history[-1]["boss_choice"] = choice
	# 완료 기록보다 선택을 먼저 저장하여 실패 시 다시 선택할 수 있다.
	if _save_checkpoint(stage_runner.current_metrics(), false) != OK:
		stage_runner.boss_choice = ""
		stage_runner.stage_history[-1]["boss_choice"] = ""
		return false
	_finish_growth_selection()
	stage_runner.force_emit_metrics()
	return true


func _record_stage_metrics(metrics: Dictionary) -> void:
	if not _restoring_checkpoint:
		test_recorder.record_stage_metrics(metrics)


func _refresh_checkpoint() -> void:
	_available_checkpoint = checkpoint_store.load_checkpoint()
	var job_error: Error = OK
	var ability_error: Error = _record_abilities(_available_checkpoint.growth.ranks.keys() if not _available_checkpoint.is_empty() else [])
	if not _available_checkpoint.is_empty():
		_record_route_history(_available_checkpoint.stage.history)
		job_error = _discover_job(String(_available_checkpoint.growth.job))
	if job_error == OK and ability_error == OK:
		if not _available_checkpoint.is_empty() and not String(_available_checkpoint.stage.get("boss_choice", "")).is_empty():
			if _grant_boss_legacy(String(_available_checkpoint.recorder.id), String(_available_checkpoint.stage.boss_choice)) and test_recorder.has_completed_run(String(_available_checkpoint.recorder.id)):
				_discard_checkpoint()
		elif not _available_checkpoint.is_empty() and test_recorder.has_completed_run(String(_available_checkpoint.recorder.id)):
			_discard_checkpoint()
	_update_boss_legacy_status()
	controls.update_checkpoint_status(not _available_checkpoint.is_empty(), _ability_codex_message if ability_error != OK else checkpoint_store.message if job_error == OK else "직업 기록 저장 실패 · 이어하기로 다시 시도하세요")


func _discard_checkpoint() -> void:
	checkpoint_store.clear_checkpoint()
	_available_checkpoint.clear()
	controls.update_checkpoint_status(false, checkpoint_store.message)


func continue_saved_run() -> bool:
	_refresh_checkpoint()
	if _available_checkpoint.is_empty() or controls.current_screen_mode() != 2:
		return false
	var state := _available_checkpoint.duplicate(true)
	if _record_abilities(state.growth.ranks.keys()) != OK:
		return false
	if _discover_job(String(state.growth.job)) != OK:
		return false
	_restoring_checkpoint = true
	_finish_growth_selection()
	controls.release_all_inputs()
	player.reset_movement_test(TRACK_START)
	player.damage_receiver.max_health = int(state.player.max_health)
	player.damage_receiver.health = int(state.player.health)
	player.growth_common_bonus = float(state.player.common)
	player.growth_sword_bonus = float(state.player.sword)
	player.growth_bow_bonus = float(state.player.bow)
	player.boss_legacy = boss_legacy_store.restore_active(state.get("boss_legacy", {}))
	player.memory_id = String(state.get("memory_id", ""))
	player.relic_state = state.get("relic", {}).duplicate()
	player.relic_run_id = String(state.recorder.id)
	if player.relic_state.get("id", "") == PrototypeRelic.PHOENIX_ID:
		player.relic_state.used = player.relic_state.used or boss_legacy_store.phoenix_used(player.relic_run_id)
	controls.selected_memory_id = player.memory_id
	_update_boss_legacy_status()
	growth.restore_checkpoint(state.growth)
	player.prepare_potions(String(state.player.get("potion_recipe", PrototypePotionRecipes.BASIC)), int(state.player.get("potions_remaining", PrototypePlayer.POTIONS_PER_RUN)))
	player.lifesteal_progress = int(state.player.get("lifesteal_progress", 0))
	player.damage_receiver.barrier_health = int(state.player.get("barrier_health", 0))
	player.queue_redraw()
	weapon_controller.restore_checkpoint(state.weapons)
	ultimate_controller.reset_ultimate()
	ultimate_controller.gauge = int(state.ultimate.gauge)
	if not String(state.ultimate.profile).is_empty():
		ultimate_controller.select_job_ultimate(String(state.growth.job), String(state.ultimate.profile))
	_intermission_stage = int(state.stage.number)
	stage_runner.restore_checkpoint(state.stage)
	test_recorder.restore_checkpoint(state.recorder, stage_runner.stage_number)
	_restoring_checkpoint = false
	player.apply_growth_health(0, 0)
	ultimate_controller.force_emit_metrics()
	_begin_growth_pause()
	_stage_recovered_health = 0
	if stage_runner.uses_boss():
		controls.show_boss_choice()
		if not stage_runner.boss_choice.is_empty():
			_finish_growth_selection()
			stage_runner.force_emit_metrics()
	elif stage_runner.reward_claimed:
		_show_intermission_routes()
	else:
		controls.show_weapon_rewards(stage_runner.stage_number, PrototypeWeaponRewards.offers(stage_runner.stage_number, weapon_controller.equipment, weapon_controller.unlocked_blueprints, weapon_controller.blueprints))
	return true


func _continue_stage(route: String) -> void:
	if not stage_runner.has_next_stage() or not stage_runner.reward_claimed or not growth.run_active or player.damage_receiver.dead or not stage_runner.can_select_route(route) or controls.current_screen_mode() != 9:
		return
	controls.release_all_inputs()
	weapon_controller.prepare_next_stage()
	feedback_controller.prepare_next_stage()
	player.prepare_next_stage(TRACK_START)
	ultimate_controller.finish_stage_effect()
	for group in ["enemy_projectile", "bow_projectile"]:
		for projectile in get_tree().get_nodes_in_group(group):
			projectile.free()
	if route == "meadow":
		player.apply_growth_health(0, 20)
	elif route == "wind":
		ultimate_controller.grant_stage_gauge(25)
	target_selector.reset_selection()
	growth.begin_next_stage()
	stage_runner.next_stage(route)
	_finish_growth_selection()
	_emit_enemy_metrics()


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
	var nodes: Array[Node] = [stage_runner, target_selector, $RecoveryOrbController]
	if controls.village_environment_owned:
		nodes.append_array([player, weapon_controller])
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
		if enemy == stage_runner.boss and not stage_runner.uses_boss():
			continue
		if enemy == stage_runner.armored_boar and stage_runner.uses_boss():
			continue
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


func _grant_boss_legacy(source: String, choice: String) -> bool:
	if choice.is_empty():
		return true
	if source == _last_legacy_grant_source and boss_legacy_store.save_path == _last_legacy_grant_path:
		return true
	var error := boss_legacy_store.grant(source, choice)
	if error == OK:
		_last_legacy_grant_source = source
		_last_legacy_grant_path = boss_legacy_store.save_path
	_update_boss_legacy_status()
	if error != OK:
		controls.update_checkpoint_status(true, "보상 저장 실패 · 이어하기로 다시 저장하세요")
	return error == OK


func _update_boss_legacy_status() -> void:
	var progress := boss_legacy_store.progress_snapshot()
	controls.update_boss_legacy_status(progress.pending, player.boss_legacy)
	controls.update_memory_status(progress.unlocked, progress.selected_memory, player.memory_id)
	weapon_controller.unlocked_blueprints = progress.blueprints.duplicate()
	controls.update_weapon_blueprints(progress.blueprints)
	controls.update_job_codex_status(progress.jobs, _job_codex_message)
	controls.update_potion_recipe_status(String(progress.potion_recipe))
	controls.update_route_atlas_status(progress.routes, _route_atlas_message)


func _select_potion_recipe(id: String) -> bool:
	if controls.current_screen_mode() != 13 or controls.village_page != "apothecary":
		return false
	var error := boss_legacy_store.select_potion_recipe(id)
	controls.update_potion_recipe_status(String(boss_legacy_store.progress_snapshot().potion_recipe), "조제 저장 실패 · 다시 선택하세요" if error != OK else "다음 새 도전에 적용됩니다")
	return error == OK


func _on_boss_legacy_damage(_event: DamageEvent) -> void:
	_update_boss_legacy_status()


func _show_intermission_routes() -> void:
	controls.update_skill_reward_status(weapon_controller.skills, stage_runner.skills_claimed)
	controls.relic_offer_available = stage_runner.stage_number == 2 and player.relic_state.is_empty()
	controls.show_stage_routes(stage_runner.stage_number, stage_runner.stage_limit, _stage_recovered_health, stage_runner.available_routes())


func _claim_skill_reward(id: String, slot: int) -> bool:
	if controls.current_screen_mode() != 14 or not stage_runner.has_next_stage() or not stage_runner.reward_claimed or stage_runner.skills_claimed or not growth.run_active or player.damage_receiver.dead:
		return false
	var offered := false
	for card in controls.skill_reward_offers:
		if String(card.id) == id: offered = true
	if not offered: return false
	var previous := weapon_controller.checkpoint_snapshot()
	if not weapon_controller.replace_skill(id, slot):
		return false
	stage_runner.skills_claimed = true
	if _save_checkpoint(stage_runner.current_metrics()) != OK:
		stage_runner.skills_claimed = false
		weapon_controller.set_skill_loadout(previous.skills)
		for weapon in ["sword", "bow"]:
			var combat: Node = weapon_controller.sword_combat if weapon == "sword" else weapon_controller.bow_combat
			for field in ["_skill_1_cooldown_s", "_skill_2_cooldown_s"]:
				combat.set(field, previous[weapon][field])
		weapon_controller.force_emit_metrics()
		return false
	weapon_controller.prepare_next_stage()
	_show_intermission_routes()
	return true


func _claim_relic_reward(id: String = PrototypeRelic.PHOENIX_ID) -> bool:
	if controls.current_screen_mode() != 15 or stage_runner.stage_number != 2 \
	or not stage_runner.has_next_stage() or not stage_runner.reward_claimed \
	or not growth.run_active or player.damage_receiver.dead or not player.relic_state.is_empty() or not PrototypeRelic.valid_id(id):
		return false
	player.relic_state = {"id": id, "used": false}
	player.relic_run_id = String(test_recorder.checkpoint_snapshot().id)
	if _save_checkpoint(stage_runner.current_metrics()) != OK:
		player.relic_state = {}
		weapon_controller.force_emit_metrics()
		player.apply_growth_health(0, 0)
		return false
	player.apply_growth_health(0, 0)
	weapon_controller.force_emit_metrics()
	_show_intermission_routes()
	return true


func _record_abilities(ids: Array) -> Error:
	var error := ability_discovery_store.discover(ids)
	_ability_codex_message = "능력 기록 저장 실패 · 다시 선택하거나 이어하기로 재시도하세요" if error != OK else ""
	controls.update_ability_codex_status(ability_discovery_store.snapshot(), _ability_codex_message)
	return error


func _discover_job(id: String) -> Error:
	var error: Error = OK if id.is_empty() else boss_legacy_store.discover_job(id)
	_job_codex_message = "직업 기록 저장 실패 · 확인을 눌러 다시 시도하세요" if error != OK else ""
	controls.update_job_codex_status(boss_legacy_store.progress_snapshot().jobs, _job_codex_message)
	return error


func _confirm_job(index: int) -> bool:
	if not growth.awaiting_job_confirmation or not growth.run_active or index < 0 or index >= PrototypeJobRewards.ultimates_for(growth.jobs.job_id).size():
		return false
	if _discover_job(growth.jobs.job_id) != OK:
		return false
	return growth.choose_job_ultimate(index)


func _record_route_history(history: Array) -> void:
	for entry in history:
		var id := String(entry.route)
		if id in PrototypeRouteAtlas.IDS and id not in _pending_route_records:
			_pending_route_records.append(id)
	_flush_route_records()


func _flush_route_records() -> void:
	var error := boss_legacy_store.discover_routes(_pending_route_records)
	if error == OK:
		_pending_route_records.clear()
	_route_atlas_message = "지도 기록 저장 실패 · 경로 카드를 눌러 재시도" if error != OK else ""
	controls.update_route_atlas_status(boss_legacy_store.progress_snapshot().routes, _route_atlas_message)


func _retry_route_records() -> void:
	if controls.current_screen_mode() == 13 and controls.village_page == "atlas":
		_flush_route_records()
