extends "res://tests/gp110_runtime_test.gd"

const GP112_SAVE := "user://gp112_checkpoint.json"
const GP112_LEGACY := "user://gp112_legacy.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if not args.is_empty() else "seed"
	store.save_path = GP112_SAVE
	legacy.save_path = GP112_LEGACY
	if mode == "seed":
		store.clear_checkpoint()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GP112_LEGACY))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = "user://gp112_records.jsonl"
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	recorder = sandbox.get_node("LocalTestRecorder")
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	weapons.sword_combat.set_process(false)
	weapons.bow_combat.set_process(false)
	runner.set_process(false)
	var terrain: PrototypeRouteTerrain = sandbox.get_node("RouteTerrain")
	var ultimate: UltimateController = sandbox.get_node("Player/UltimateController")
	match mode:
		"seed":
			controls.begin_retry()
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "기본 도전 보상 유지"): return
			var start := player.global_position
			sandbox._continue_stage("clockwork")
			if not _check(controls.stage_route_rects.size() == 2 and runner.stage_number == 1 and player.global_position == start and not runner.next_stage("clockwork"), "파괴 보상 없는 위험 길 UI·실행 차단"): return
			if not _check(legacy.grant("gp112-skipped", "destroy") == OK, "파괴 보상 준비"): return
			sandbox._update_boss_legacy_status()
			controls.show_main_screen()
			controls.show_start_weapon_selection()
			controls.use_boss_legacy = false
			_tap(controls.memory_card_rects[2].get_center())
			_tap(controls.start_weapon_confirm_rect.get_center())
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "영구 기억 도전 보상 유지"): return
			if not _check(player.memory_id == "core_echo" and player.boss_legacy.is_empty() and controls.stage_route_options.size() == 2 and not runner.can_select_route("clockwork"), "영구 기억만 장착·일회 보상 건너뛰기는 위험 길 개방 없음"): return
			if not _check(legacy.grant("gp112-active", "destroy") == OK, "새 파괴 보상 준비"): return
			sandbox._update_boss_legacy_status()
			controls.show_main_screen()
			controls.show_start_weapon_selection()
			_tap(controls.start_weapon_confirm_rect.get_center())
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward("sword"), "위험 길 준비 무기 보상"): return
			if not _check(player.boss_legacy.choice == "destroy" and legacy.pending_reward().is_empty() and controls.stage_route_options.size() == 3 and controls.stage_route_options[2].id == "clockwork", "적용한 일회 핵 도전만 세 번째 위험 카드"): return
			for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
				controls.size = dimensions
				controls._refresh_stage_routes()
				var safe: Rect2 = controls.layout_snapshot().safe
				for i in controls.stage_route_rects.size():
					if not _check(safe.encloses(controls.stage_route_rects[i]), "두 화면 비율 위험 카드 안전 영역"): return
					for j in range(i + 1, controls.stage_route_rects.size()):
						if not _check(not controls.stage_route_rects[i].intersects(controls.stage_route_rects[j]), "세 경로 터치 영역 겹침 없음"): return
			if not _check(store.load_checkpoint().stage.number == 1 and store.load_checkpoint().stage.reward_claimed, "위험 선택 전 저장"): return
		"resume":
			if not _check(sandbox.continue_saved_run() and controls.stage_route_options.size() == 3, "별도 프로세스 이어하기 위험 길 선택 복원"): return
			_tap(controls.stage_route_rects[2].get_center())
			if not _check(not paused and runner.stage_number == 2 and runner.route_id == "clockwork" and terrain.platforms == PrototypeRouteTerrain.CLOCKWORK_STEPS and terrain.get_child_count() == 3 and "위험" in controls.movement_metrics.run_route_name, "위험 카드 실제 터치 지형·HUD·입력 복귀"): return
			player.global_position.x = 1240
			runner._process(0.1)
			if not _check(runner._active_enemies.size() == 3 and runner.wind_spirit.position == Vector2(1750, 540), "첫 웨이브 세 종류 실제 배치"): return
			for enemy in runner._active_enemies.duplicate():
				var expected := roundi(float(runner._initial_health[enemy.get_path()]) * 1.50)
				if not _check(enemy.damage_receiver.health == expected and enemy.damage_receiver.max_health == expected, "2스테이지 기본 체력에 위험 +20% 곱 적용"): return
				_defeat(enemy)
			if not _resolve_growth(): return
			runner._process(0.1)
			if not await _cross_risk_terrain(): return
			runner._process(0.1)
			while runner.current_section < PrototypeStageRunner.Section.ELITE:
				if not _step_section(): return
			if not _check(runner.armored_boar.damage_receiver.max_health == roundi(float(runner._initial_health[runner.armored_boar.get_path()]) * 1.50), "정예도 위험 체력 적용"): return
			_defeat(runner.final_enemy())
			if not _resolve_growth(): return
			player.damage_receiver.health = 10
			ultimate.gauge = 0
			runner._process(0.1)
			var expected_health := mini(player.damage_receiver.max_health, 10 + ceili(player.damage_receiver.max_health * 0.20) + 20)
			if not _check(controls.current_screen_mode() == 11 and player.damage_receiver.health == expected_health and ultimate.gauge == 50, "통과 시 기본 회복 +20·필살기 +50 실제 지급"): return
			for ignored in 5: runner.force_emit_metrics()
			if not _check(player.damage_receiver.health == expected_health and ultimate.gauge == 50, "반복 완료 통지로 추가 보상 중복 없음"): return
			var saved := store.load_checkpoint()
			if not _check(not saved.is_empty() and saved.stage.route == "clockwork" and saved.ultimate.gauge == 50, "위험 경로·지급 보상 함께 저장"): return
			for invalid_legacy in [{}, {"choice": "rescue", "source_run": "gp112-active", "run_id": saved.recorder.id, "rescue_used": false, "assisted_stages": []}]:
				var invalid := saved.duplicate(true)
				invalid.boss_legacy = invalid_legacy
				if not _check(not RunCheckpointStore.valid_state(invalid), "핵 없는 위험 경로 저장 거부"): return
			var invalid_stage := saved.duplicate(true)
			invalid_stage.stage.history[0].route = "clockwork"
			if not _check(not RunCheckpointStore.valid_state(invalid_stage), "1스테이지 위험 기록 거부"): return
			var unknown := saved.duplicate(true)
			unknown.stage.route = "unknown"
			unknown.stage.history[-1].route = "unknown"
			if not _check(not RunCheckpointStore.valid_state(unknown), "미등록 경로 거부"): return
		"finish":
			var saved := store.load_checkpoint()
			if not _check(sandbox.continue_saved_run() and runner.route_id == "clockwork" and terrain.get_child_count() == 3 and player.damage_receiver.health == saved.player.health and ultimate.gauge == 50, "별도 프로세스 위험 지형·회복·게이지 복원 중복 없음"): return
			if not _check(sandbox._claim_weapon_reward("bow") and controls.stage_route_options.size() == 2 and not runner.next_stage("clockwork"), "통과 후 영웅 무기·보스 경로는 기존 두 종류"): return
			sandbox._continue_stage("wind")
			if not _check(runner.stage_number == 3 and terrain.platforms == PrototypeRouteTerrain.WIND_STEPS and runner.leaf_slime.damage_receiver.max_health == roundi(float(runner._initial_health[runner.leaf_slime.get_path()]) * 1.50) and runner.boss.damage_receiver.max_health == 480, "다음 스테이지 위험 배율 제거·보스 기존 체력"): return
			if not _finish_stage(): return
			if not _check(sandbox._resolve_boss_choice("rescue") and runner.stage_history[1].route == "clockwork" and store.load_checkpoint().is_empty(), "위험 이력 보존·보스 완주·체크포인트 삭제"): return
			controls.begin_retry()
			if not _check(terrain.platforms.is_empty() and player.boss_legacy.is_empty() and not runner.can_select_route("clockwork"), "새 도전에서 이전 위험 권한·지형 초기화"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-112 runtime test: OK (%s)" % mode)
	quit(0)

func _cross_risk_terrain() -> bool:
	await physics_frame
	await physics_frame
	player.prepare_next_stage(Vector2(3000, 780))
	for ignored in 4: await physics_frame
	var falls := player.fall_count
	var dashes := player.air_dash_count
	for destination in [Vector2(3180, 660), Vector2(3500, 540), Vector2(3830, 660)]:
		if not await _jump_to(destination): return false
	if not _check(player.fall_count == falls and player.air_dash_count == dashes, "좁은 발판 세 개 기본 점프로 횡단"): return false
	var safe := player.last_safe_position
	var health := player.damage_receiver.health
	var damage := ceili(player.damage_receiver.max_health * player.FALL_DAMAGE_RATIO)
	player.global_position = Vector2(3380, 1120)
	player.velocity = Vector2.ZERO
	for ignored in 90:
		await physics_frame
		if player.fall_count > falls and not player._fall_recovery_active: break
	return _check(player.fall_count == falls + 1 and player.global_position.distance_to(safe) < 4 and player.damage_receiver.health == maxi(1, health - damage), "위험 낙하 마지막 발판 복귀·기존 피해 공식")

func _check(condition: bool, label: String) -> bool:
	if condition: return true
	push_error("GP-112 실패: %s" % label)
	paused = false
	quit(1)
	return false

func _jump_to(destination: Vector2) -> bool:
	player.set_move_vector(Vector2.RIGHT)
	player.request_jump()
	var left_floor := false
	for ignored in 150:
		await physics_frame
		if not player.is_on_floor():
			left_floor = true
		# 공중에서 일찍 멈춰 착지점에 감속한다.
		if player.global_position.x >= destination.x - 34:
			player.set_move_vector(Vector2.ZERO)
		if left_floor and player.is_on_floor():
			break
	player.release_jump()
	player.set_move_vector(Vector2.ZERO)
	for ignored in 8:
		await physics_frame
	return _check(left_floor and player.is_on_floor() and absf(player.global_position.y - destination.y) < 4 and absf(player.global_position.x - destination.x) < 65 and player.last_safe_position == destination, "기본 점프 착지·새 발판 안전 복귀점: 위치 %s / 목적지 %s / 복귀 %s" % [player.global_position, destination, player.last_safe_position])
