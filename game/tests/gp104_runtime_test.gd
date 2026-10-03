extends SceneTree

const SANDBOX := preload("res://scenes/movement/ground_movement_sandbox.tscn")
const RECORD_PATH := "user://gp104_runtime_records.jsonl"
var sandbox: Node
var controls: Control
var player: PrototypePlayer
var growth: PrototypeGrowthController
var runner: PrototypeStageRunner
var weapons: PrototypeWeaponController
var ultimate: UltimateController
var recorder: LocalTestRecorder
var saw_job_card: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	ultimate = sandbox.get_node("Player/UltimateController")
	recorder = sandbox.get_node("LocalTestRecorder")
	(sandbox.get_node("CombatFeedbackController") as CombatFeedbackController).configure(0.0, false, false)
	weapons.sword_combat.set_process(false)
	weapons.bow_combat.set_process(false)
	recorder.configure_record_path_for_test(RECORD_PATH)
	recorder.clear_records()
	# 기존 1스테이지 기록은 유지하되 3스테이지 최고 시간과 비교하지 않는다.
	recorder.start_run()
	recorder.record_stage_metrics({"stage_complete": true, "stage_actual_times": [], "stage_elapsed_s": 0.1})
	for job_index in 2:
		controls.begin_stage_from_main()
		if job_index == 1:
			weapons.request_weapon_switch()
		var job := "vanguard" if job_index == 0 else "tracker"
		for stage in range(1, 4):
			if not _check(runner.stage_number == stage and runner.stage_limit == 3 and not paused and growth.run_active, "사용자 경로의 3스테이지 시작"):
				return
			if stage > 1:
				var before := growth.metrics_snapshot()
				var initial_health: int = runner._initial_health[runner.leaf_slime.get_path()]
				player.global_position.x = 1240
				runner._process(0.1)
				for enemy in runner._active_enemies:
					enemy.set_process(false)
				if not _check(runner.leaf_slime.damage_receiver.max_health == roundi(initial_health * (1.0 + 0.25 * (stage - 1))), "후속 스테이지 체력 증가"):
					return
				if not _check((runner.wind_spirit in runner._active_enemies) == (runner.route_id == "wind"), "두 경로의 실제 첫 웨이브 구성"):
					return
				player.global_position = Vector2(1420, 780)
				player.facing_direction = 1
				var camera := player.get_node("Camera2D") as Camera2D
				camera.reset_smoothing()
				camera.force_update_scroll()
				var target_health := runner.leaf_slime.damage_receiver.health
				ultimate.gauge = 100
				ultimate.request_ultimate()
				if not _check(ultimate.activation_count > 0 and ultimate.last_burst_hits > 0 and runner.leaf_slime.damage_receiver.health < target_health and ultimate.selected_profile.get("job", "") == job, "이어진 실제 적에게 직업 필살기 적용"):
					return
				if not _check(growth.jobs.job_id == job and growth.level >= int(before["growth_level"]), "후속 전투에도 직업·성장 유지"):
					return
			elif not _check(growth.jobs.job_id.is_empty(), "새 도전 시작 직업 초기화"):
				return
			if not _finish_stage():
				return
			if stage == 3:
				if not _check(not paused and runner.stage_complete and bool(runner.current_metrics()["run_complete"]) and controls.current_screen_mode() == 1 and not growth.run_active and growth.total_experience == 240 and saw_job_card, "3개 완주 후 단일 결과·총 경험치·직업 카드 활용"):
					return
				var result: Dictionary = controls.current_result_snapshot()
				if not _check(result["stage_count"] == 3 and result["stage_history"].size() == 3 and is_equal_approx(float(result["completion_s"]), float(runner.current_metrics()["run_elapsed_s"])) and is_equal_approx(float(result["target_s"]), 540.0), "전체 완료 시간·3개 스테이지 기록"):
					return
				continue
			if not _check(paused and controls.current_screen_mode() == 9 and growth.run_active and growth.jobs.job_id == job, "중간 완료는 경로 선택·발현 보상 보존"):
				return
			var expected_health := mini(player.damage_receiver.max_health, _before_clear_health + ceili(player.damage_receiver.max_health * 0.20))
			if not _check(player.damage_receiver.health == expected_health, "최대 체력 기준 20% 회복"):
				return
			var clock := runner.stage_elapsed_s
			var unchanged_health := player.damage_receiver.health
			runner.force_emit_metrics()
			runner.force_emit_metrics()
			await create_timer(0.10, true).timeout
			if not _check(paused and is_equal_approx(clock, runner.stage_elapsed_s) and player.damage_receiver.health == unchanged_health and controls.command_buffer.pending_count() == 0, "선택 중 전투 정지·중복 회복 방지"):
				return
			for viewport_size in [Vector2(1280, 720), Vector2(2400, 1080)]:
				controls.size = viewport_size
				controls._refresh_stage_routes()
				var layout: Dictionary = controls.layout_snapshot()
				var safe: Rect2 = layout["safe"]
				if not _check(safe.encloses(controls.stage_route_rects[0]) and safe.encloses(controls.stage_route_rects[1]) and not controls.stage_route_rects[0].intersects(controls.stage_route_rects[1]), "경로 두 비율 안전 영역·비중첩"):
					return
			controls.notification(Control.NOTIFICATION_APPLICATION_PAUSED)
			controls.notification(Control.NOTIFICATION_APPLICATION_RESUMED)
			sandbox._continue_stage("invalid")
			if not _check(paused and runner.stage_number == stage and controls.current_screen_mode() == 9, "앱 복귀·잘못된 경로 선택 차단"):
				return
			var before_growth := growth.metrics_snapshot()
			var before_ultimate := ultimate.selected_profile.duplicate(true)
			var before_weapon := weapons.active_weapon_id
			weapons.sword_combat._skill_1_cooldown_s = 3.5
			weapons.bow_combat._skill_2_cooldown_s = 4.75
			ultimate.gauge = 90
			ultimate._active = true
			ultimate._active_profile = ultimate.selected_profile.duplicate(true)
			ultimate._remaining_s = 2.0
			var route_index := (job_index + stage - 1) % 2
			var route := String(PrototypeStageRunner.ROUTES[route_index]["id"])
			var arrow := preload("res://scenes/combat/bow_projectile.tscn").instantiate() as BowProjectile
			arrow.configure("gp104:old_arrow", &"bow_basic", 14, 14, 8, 1, Vector2.RIGHT, PackedStringArray(["bow"]))
			sandbox.add_child(arrow)
			var seed := preload("res://scenes/combat/enemy_seed_projectile.tscn").instantiate() as EnemySeedProjectile
			seed.configure("gp104:old_seed", Vector2.LEFT)
			sandbox.add_child(seed)
			if not _check(not get_nodes_in_group("bow_projectile").is_empty() and not get_nodes_in_group("enemy_projectile").is_empty(), "정리 대상의 실제 투사체 생성"):
				return
			_tap(controls.stage_route_rects[route_index].get_center())
			if not _check(not paused and controls.current_screen_mode() == 0 and runner.stage_number == stage + 1 and runner.route_id == route and player.global_position == sandbox.TRACK_START and player.last_safe_position == sandbox.TRACK_START, "화면 터치로 다음 스테이지·시작점·낙하 복귀점 이동"):
				return
			if not _check(growth.level == before_growth["growth_level"] and growth.experience == before_growth["growth_xp"] and growth.ranks == before_growth["growth_ranks"] and growth.jobs.contributions == before_growth["growth_job_contributions"] and growth.rerolls_remaining == 1 and ultimate.selected_profile == before_ultimate and weapons.active_weapon_id == before_weapon and is_equal_approx(weapons.sword_combat._skill_1_cooldown_s, 3.5) and is_equal_approx(weapons.bow_combat._skill_2_cooldown_s, 4.75), "성향·카드·무기·필살기·쿨다운 보존·재추첨 보충"):
				return
			if not _check(not ultimate._active and ultimate.gauge == (100 if route_index == 1 else 90) and player.damage_receiver.health == (mini(player.damage_receiver.max_health, unchanged_health + 20) if route_index == 0 else unchanged_health), "지속 효과 종료·경로 보상·게이지 상한"):
				return
			sandbox._continue_stage(route)
			if not _check(runner.stage_number == stage + 1 and get_nodes_in_group("bow_projectile").is_empty() and get_nodes_in_group("enemy_projectile").is_empty(), "중복 전환 차단·투사체 정리"):
				return
	var summary := recorder.summary_snapshot()
	if not _check(summary["completed_run_count"] == 3 and summary["completion_by_stage_count"]["3"]["completed_run_count"] == 2 and is_equal_approx(float(summary["completion_by_stage_count"]["1"]["best_completion_s"]), 0.1) and float(summary["completion_by_stage_count"]["3"]["best_completion_s"]) > 0.1, "단일/연속 완료 기록 분리·중간 완료 미집계"):
		return
	var result_summary: Dictionary = controls.current_result_snapshot()["record_summary"]
	if not _check(result_summary["completed_run_count"] == 2 and result_summary["best_completion_s"] == summary["completion_by_stage_count"]["3"]["best_completion_s"], "결과 화면에서 3스테이지끼리 최고 시간 비교"):
		return
	recorder.reload_records_for_test()
	if not _check(recorder.summary_snapshot() == summary, "JSON Lines 재실행 집계 유지"):
		return
	controls.begin_retry()
	# 같은 적의 1번 공격도 재등장한 생명에서는 새로운 피해로 받아야 한다.
	player.damage_receiver.health = 100
	for life in 2:
		var slime := runner.leaf_slime
		slime.reset_target()
		slime.visible = true
		slime.set_process(false)
		slime.global_position = player.global_position + Vector2(0, -38)
		slime.attack_count = 1
		slime._attack_hit_consumed = false
		player.damage_receiver.tick(1.0)
		player._input_lock_remaining_s = 0.0
		var health_before := player.damage_receiver.health
		slime._try_contact_damage(8, &"slime_contact")
		if not _check(player.damage_receiver.health == health_before - 8, "적 재등장 후 같은 공격 번호의 피해 적용"):
			return
		player.damage_receiver.tick(1.0)
		player._input_lock_remaining_s = 0.0
		slime._attack_hit_consumed = false
		slime._try_contact_damage(8, &"slime_contact")
		if not _check(player.damage_receiver.health == health_before - 8, "같은 생명·같은 타격의 중복 차단 유지"):
			return
	# 중간 화면에서 재도전·사망·씬 종료해도 트리가 정지된 채 남지 않는다.
	for exit_case in 3:
		controls.begin_retry()
		if not _check(runner.stage_number == 1 and runner.stage_history.is_empty() and growth.level == 1 and growth.jobs.job_id.is_empty() and ultimate.selected_profile.is_empty() and player.damage_receiver.max_health == 100, "새 도전 전체 초기화"):
			return
		if not _finish_stage():
			return
		if exit_case == 0:
			controls.begin_retry()
			if not _check(not paused and runner.stage_number == 1 and controls.current_screen_mode() == 0, "경로 화면에서 재도전 정지 해제"):
				return
		elif exit_case == 1:
			player.player_died.emit()
			if not _check(not paused and not growth.run_active, "경로 화면 사망 정지 해제"):
				return
		else:
			sandbox.free()
			await process_frame
			if not _check(not paused, "경로 화면 씬 종료 정지 복구"):
				return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORD_PATH))
	print("GP-104 runtime test: OK")
	quit(0)


var _before_clear_health: int = 0


func _finish_stage() -> bool:
	if runner.current_section == PrototypeStageRunner.Section.ADVANCE_ONE:
		player.global_position.x = 1240
		runner._process(0.1)
	for enemy in runner._active_enemies.duplicate():
		_defeat(enemy)
	if not _resolve_growth():
		return false
	runner._process(0.1)
	player.global_position.x = 3840
	runner._process(0.1)
	for enemy in runner._active_enemies.duplicate():
		_defeat(enemy)
	if not _resolve_growth():
		return false
	runner._process(0.1)
	player.damage_receiver.health = 35
	_defeat(runner.final_enemy())
	if not _resolve_growth():
		return false
	_before_clear_health = player.damage_receiver.health
	runner._process(0.1)
	# 기존 회귀 검사는 현재 무기 유지 후 경로 선택을 이어간다.
	if controls.current_screen_mode() == 11:
		_tap(controls.weapon_reward_skip_rect.get_center())
	if controls.current_screen_mode() == 12:
		_tap(controls.boss_choice_rects[0].get_center())
		_tap(controls.boss_choice_confirm_rect.get_center())
	return true


func _resolve_growth() -> bool:
	for ignored in 12:
		if growth.awaiting_job_confirmation:
			_tap(controls.job_ultimate_rects[0].get_center())
			_tap(controls.job_confirm_rect.get_center())
		elif growth.choosing:
			if growth.offered_cards[0].get("category", "") == "job":
				saw_job_card = true
			if growth.rerolls_remaining == 1:
				growth.reroll()
			_tap(controls.growth_card_rects[0].get_center())
		else:
			return true
	return _check(false, "성장 선택 대기 해소")


func _defeat(target: PrototypeTarget) -> void:
	if target.damage_receiver.dead:
		return
	target.set_process(false)
	target.damage_receiver.tick(1.0)
	var event := DamageEvent.new()
	event.event_id = StringName("gp104:%s:%d" % [target.get_instance_id(), target.spawn_generation])
	event.attacker_id = &"player"
	event.damage = 9999
	event.tags = PackedStringArray(["test"])
	target.receive_damage(event)


func _tap(position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 4
	event.pressed = true
	event.position = position
	controls._input(event)


func _check(condition: bool, label: String) -> bool:
	if condition:
		return true
	push_error("GP-104 실패: %s" % label)
	paused = false
	quit(1)
	return false
