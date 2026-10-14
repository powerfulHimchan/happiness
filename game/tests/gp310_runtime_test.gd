extends "res://tests/gp309_runtime_test.gd"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var character := args[1]
	var weapon := args[2]
	var prefix := "user://gp310_%s_%s_%s" % ["flow" if phase in ["seed", "resume", "finish"] else phase, character, weapon]
	store.save_path = prefix + "_checkpoint.json"
	legacy.save_path = prefix + "_meta.jsonl"
	journal.save_path = prefix + "_story.jsonl"
	if phase not in ["resume", "finish"]:
		store.clear_checkpoint()
		for suffix in ["_meta.jsonl", "_records.jsonl", "_abilities.jsonl", "_story.jsonl"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.story_journal_store = journal
	var book := AbilityDiscoveryStore.new()
	book.save_path = prefix + "_abilities.jsonl"
	sandbox.ability_discovery_store = book
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.get_node("LocalTestRecorder").record_path = prefix + "_records.jsonl"
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	recorder = sandbox.get_node("LocalTestRecorder")
	festival_ultimate = sandbox.get_node("Player/UltimateController")
	festival_terrain = sandbox.get_node("RouteTerrain")
	for actor in [player, weapons, weapons.sword_combat, weapons.bow_combat, festival_ultimate, runner, sandbox.get_node("ClockTrapController"), festival_terrain]:
		actor.set_process(false)
		actor.set_physics_process(false)
	growth.jobs_enabled = false
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	match phase:
		"seed":
			if not _prepare_core(character, weapon, false): return
			player.damage_receiver.health = 83
			festival_ultimate.gauge = 37
			weapons.sword_combat._skill_1_cooldown_s = 3.25
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK and RunCheckpointStore.valid_state(store.load_checkpoint()) and store.load_checkpoint().stage.number == 9, "성문 완료 저장·기존 버전1·중심부 준비"): return
		"resume":
			if not _restore_journey(9): return
			if not _check(player.damage_receiver.health == 83 and festival_ultimate.gauge == 37 and weapons.sword_combat._skill_1_cooldown_s == 3.25, "별도 프로세스에서 성문 잔량·기술 복원"): return
			if not _next_without_layout() or not _check_core_layout(): return
			if not _core_waves() or not _finish_stage(): return
			if not _check(runner.awaiting_boss_choice() and store.load_checkpoint().story.pending == "stage:10" and store.load_checkpoint().stage.route == "city_core", "중심부 완료·이야기/최종 선택 대기 저장"): return
		"finish":
			if not _restore_journey(10) or not _check_core_layout() or not _ack_scene(false): return
			var before := store.load_checkpoint()
			var path := store.save_path
			store.save_path = "user://gp310_missing/choice.json"
			if not _check(not sandbox._resolve_boss_choice("rescue") and runner.boss_choice.is_empty(), "중심부 최종 선택 쓰기 실패 되돌림"): return
			store.save_path = path
			if not _check(store.load_checkpoint() == before and sandbox._resolve_boss_choice("rescue" if weapon == "sword" else "destroy"), "정상 저장 보존·구출/파괴 재시도"): return
			if not _check(recorder.summary_snapshot().completed_run_count == 1 and controls.current_result_snapshot().stage_count == 10 and store.load_checkpoint().is_empty(), "10스테이지 완주 기록·완료 저장 정리"): return
		"cross":
			if not _prepare_core(character, weapon, true) or not await _core_cross(): return
		"combat":
			if not _prepare_core(character, weapon, true) or not _reach_journey_elite(): return
			if not await _core_boss_patterns(): return
		"flows":
			if not _prepare_core(character, weapon, true): return
			var before := festival_terrain.layout_snapshot()
			var saved := store.load_checkpoint()
			controls.open_run_build()
			for ignored in 5: await physics_frame
			if not _check(paused and festival_terrain.layout_snapshot() == before and store.load_checkpoint() == saved, "중심부 조회·지형/저장 불변"): return
			controls.close_run_build()
			controls.advance_mode_timer_for_test(3.1)
			controls.show_main_screen()
			controls.show_village()
			if not _check(festival_terrain.layout_snapshot() == before, "마을에서 중심부 배치 보존"): return
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and runner.stage_number == 9 and festival_terrain.platforms == CityGateLayout.PLATFORMS and festival_terrain.get_child_count() == 6, "전투 중 종료는 마지막 성문 완료 지점·중심부 몸체 제거"): return
			if not _next_without_layout() or not _check_core_layout(): return
			controls.begin_retry(weapon, 3)
			if not _check(runner.run_mode == "standard" and festival_terrain.platforms.is_empty(), "새 일반 도전에서 중심부 제거"): return
			festival_terrain.configure(2, "meadow")
			if not _check(festival_terrain.platforms == [PrototypeRouteTerrain.MEADOW_BRIDGE], "기존 풀숲 다리 회귀"): return
		_:
			_check(false, "알 수 없는 중심부 검사")
			return
	paused = false
	sandbox.free()
	print("GP-310 runtime test: OK (%s %s %s)" % [phase, character, weapon])
	quit(0)

func _prepare_core(character: String, weapon: String, enter: bool) -> bool:
	if not _start_gate(character, weapon) or not _finish_stage() or not _ack_scene(true) or not sandbox._claim_weapon_reward(""): return false
	if not _check(controls.stage_route_options.size() == 1 and controls.stage_route_options[0].id == "city_core" and controls.stage_route_options[0].lines[0].contains("시계탑 회랑"), "성문 다음 후보·전용 중심부 안내 카드"): return false
	if not enter: return true
	return _next_without_layout() and _check_core_layout()

func _check_core_layout() -> bool:
	if not _check(runner.stage_number == 10 and runner.route_id == "city_core" and festival_terrain.platforms == CityCoreLayout.PLATFORMS and festival_terrain.get_child_count() == 5, "실제 10스테이지 전용 회랑·발판5개"): return false
	for i in festival_terrain.platforms.size():
		var body := festival_terrain.get_child(i) as StaticBody2D
		var collision := body.get_child(0) as CollisionShape2D
		var rect: Rect2 = festival_terrain.platforms[i]
		if not _check(body.position == rect.get_center() and collision.shape.size == rect.size, "중심부 발판 표시/충돌 좌표·크기 일치"): return false
		if rect.position.y < 840 and not _check(rect.end.x <= BossClockworkKnight.ARENA_LEFT_X, "보스 평지에는 높은 발판 침범 없음"): return false
	return _check(runner.current_metrics().run_route_terrain == CityCoreLayout.TERRAIN_NAME, "HUD/현재 도전의 전용 중심부 지형 이름")

func _core_waves() -> bool:
	player.global_position.x = 1240
	runner._process(0.1)
	if not _check(runner._active_enemies.size() == 3 and runner.seed_sack.position == CityCoreLayout.WAVE_ONE.seed and runner.seed_sack.position.y + 60 == 660 and runner.wind_spirit.position == CityCoreLayout.WAVE_ONE.wind and runner.current_metrics().stage_objective.contains("높은 회랑"), "첫 혼합 웨이브·기존 높은 발판 위 적·전용 목표"): return false
	for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
	if not _resolve_growth(): return false
	runner._process(0.1)
	player.global_position.x = 3840
	runner._process(0.1)
	return _check(runner._active_enemies.size() == 3 and runner.seed_sack.position == CityCoreLayout.WAVE_TWO.seed and runner.leaf_slime.position == CityCoreLayout.WAVE_TWO.slime and runner.current_metrics().stage_objective.contains("궁전 앞"), "둘째 혼합 웨이브·궁전 앞 양쪽 적·전용 목표")

func _core_cross() -> bool:
	if not _advance_to_cross(): return false
	player.double_jump_unlocked = false
	var entry: Rect2 = festival_terrain.platforms[0]
	player.prepare_next_stage(Vector2(entry.get_center().x, entry.position.y - 60))
	player.set_physics_process(true)
	festival_terrain.set_physics_process(true)
	for ignored in 8: await physics_frame
	if not _check(player.is_on_floor(), "중심부 입구 실제 착지"): return false
	var falls := player.fall_count
	var dashes := player.air_dash_count
	for index in range(1, 5):
		if not await _jump_second_platform(index): return false
	if not _check(player.fall_count == falls and player.air_dash_count == dashes and player.double_jump_count == 0 and player.last_safe_label.begins_with("궁전 앞 쉼터"), "기본 점프만으로 회랑 횡단·궁전 쉼터 갱신"): return false
	var safe := player.last_safe_position
	player.global_position = Vector2(3360, 1120)
	player.velocity = Vector2.ZERO
	for ignored in 90:
		await physics_frame
		if player.fall_count > falls and not player._fall_recovery_active: break
	return _check(player.fall_count == falls + 1 and player.position.distance_to(safe) < 4, "궁전 앞 쉼터로 실제 낙하 복귀")

func _core_boss_patterns() -> bool:
	var boss := runner.boss
	boss.set_process(false)
	if not _check(boss.damage_receiver.max_health == 960 and runner.current_metrics().stage_section_name == "보스 · 웃는 태엽 기사" and runner.current_metrics().stage_objective.contains("돌진"), "960체력 보스·전용 지형에서도 패턴 안내 유지"): return false
	player.prepare_next_stage(Vector2(4000, 780))
	player.set_physics_process(true)
	player.set_move_vector(Vector2.RIGHT)
	var falls := player.fall_count
	for ignored in 150:
		await physics_frame
		if player.position.x >= 4700: break
	player.set_move_vector(Vector2.ZERO)
	if not _check(player.position.x >= 4700 and player.fall_count == falls and player.is_on_floor(), "궁전 보스 평지는 기본 이동만으로 실제 횡단"): return false
	player.set_physics_process(false)
	boss._begin_next_pattern()
	boss._process(0.64)
	if not _check(boss.state == EliteArmoredBoar.State.WARNING, "중심부에서도 돌진 예고 유지"): return false
	boss._process(0.02)
	boss.position.x = BossClockworkKnight.ARENA_LEFT_X + 10
	boss._charge_direction = -1
	player.global_position.x = BossClockworkKnight.ARENA_LEFT_X - 600
	boss._process(0.1)
	if not _check(boss.state == EliteArmoredBoar.State.STUNNED and boss.position.x == BossClockworkKnight.ARENA_LEFT_X, "새 회랑 이후에도 평지 경계에서 기절·낙하 진입 없음"): return false
	if not _hit_boss(40, "sword", 70): return false
	boss._set_state(EliteArmoredBoar.State.IDLE, "검사")
	if not _hit_boss(40, "bow", 50) or not _hit_boss(50, "sword", 30): return false
	boss._begin_next_pattern()
	boss._process(0.86)
	if not _check(get_nodes_in_group("enemy_projectile").size() == 2, "중심부 실제 충격파2개"): return false
	boss._process(0.35)
	boss._process(0.76)
	boss._begin_next_pattern()
	boss._process(1.01)
	if not _check(_boss_shots().size() == 3, "중심부 1페이즈 실제 탄막3개"): return false
	for projectile in get_nodes_in_group("enemy_projectile"): projectile.free()
	if not _hit_boss(340, "test", 340): return false
	if not _check(boss.phase == 2 and boss.damage_receiver.health == 470, "960체력 절반 경계 실제2페이즈 진입"): return false
	boss._process(0.75)
	boss.last_pattern = EliteArmoredBoar.Pattern.SHOCKWAVE
	boss._begin_next_pattern()
	boss._process(0.76)
	return _check(_boss_shots().size() == 5, "중심부 2페이즈 실제 탄막5개")

func _check(condition: bool, label: String) -> bool:
	if condition: return true
	push_error("GP-310 실패: " + label)
	paused = false
	quit(1)
	return false
