extends "res://tests/gp308_runtime_test.gd"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var character := args[1]
	var weapon := args[2]
	var prefix := "user://gp309_%s_%s_%s" % ["flow" if phase in ["seed", "resume"] else phase, character, weapon]
	store.save_path = prefix + "_checkpoint.json"
	legacy.save_path = prefix + "_meta.jsonl"
	journal.save_path = prefix + "_story.jsonl"
	if phase != "resume":
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
	if phase == "resume":
		if not _restore_journey(9) or not _check_gate_layout(): return
		if not _ack_scene(false) or not sandbox._claim_weapon_reward(weapon): return
		if not _next_without_layout(): return
		if not _check(runner.route_id == "city_core" and festival_terrain.platforms == CityCoreLayout.PLATFORMS and festival_terrain.get_child_count() == 5, "중심부 진입은 전용 회랑·성문 몸체 제거"): return
		if not _finish_stage() or not _ack_scene(true) or not sandbox._resolve_boss_choice("rescue" if weapon == "sword" else "destroy"): return
		if not _check(recorder.summary_snapshot().completed_run_count == 1 and store.load_checkpoint().is_empty(), "성문 이후 중심부·최종 선택·10구간 완주 저장"): return
	else:
		if not _start_gate(character, weapon): return
		match phase:
			"seed":
				if not _gate_waves() or not _finish_stage(): return
				player.damage_receiver.health = 83
				festival_ultimate.gauge = 37
				weapons.sword_combat._skill_1_cooldown_s = 3.25
				if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK and store.load_checkpoint().story.pending == "stage:9", "성문 완료 이야기 대기·체력/게이지/기술 저장"): return
				var scene := PrototypeStory.scene("stage:9", runner.stage_history, player.character_id, sandbox.story_run.known, sandbox.story_run.rewinds, 10)
				if not _check(scene.name == "성벽 위의 같은 미소" and scene.lines[0].contains(PrototypeCharacters.display_name(character)), "선택한 주인공·성문 주민 이야기"): return
			"cross":
				if not await _gate_cross(): return
			"fault":
				if not _finish_stage() or not _ack_scene(true): return
				var before := store.load_checkpoint()
				var original := store.save_path
				store.save_path = "user://gp309_missing/checkpoint.json"
				if not _check(not sandbox._claim_weapon_reward(weapon) and not runner.reward_claimed, "성문 보상 쓰기 실패 되돌림"): return
				store.save_path = original
				if not _check(store.load_checkpoint() == before and sandbox._claim_weapon_reward(weapon), "성문 저장 보존·보상 재시도"): return
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and runner.reward_claimed and runner.route_id == "city_gate", "재시도한 성문 완료 상태 반복 복원"): return
				if not _next_without_layout(): return
			"flows":
				var before := festival_terrain.layout_snapshot()
				var saved := store.load_checkpoint()
				controls.open_run_build()
				for ignored in 5: await physics_frame
				if not _check(paused and festival_terrain.layout_snapshot() == before and store.load_checkpoint() == saved, "성문 조회 정지·저장 불변"): return
				controls.close_run_build()
				controls.advance_mode_timer_for_test(3.1)
				controls.show_main_screen()
				controls.show_village()
				if not _check(festival_terrain.layout_snapshot() == before, "마을에서도 성문 지형 무변경"): return
				controls.begin_retry(weapon, 3)
				if not _check(runner.run_mode == "standard" and festival_terrain.platforms.is_empty(), "새 일반 도전에는 성문 지형·장식 제거"): return
				festival_terrain.configure(2, "meadow")
				if not _check(festival_terrain.platforms == [PrototypeRouteTerrain.MEADOW_BRIDGE], "기존 풀숲 다리 호환"): return
			_:
				_check(false, "알 수 없는 성문 검사")
				return
	paused = false
	sandbox.free()
	print("GP-309 runtime test: OK (%s %s %s)" % [phase, character, weapon])
	quit(0)

func _start_gate(character: String, weapon: String) -> bool:
	if not _start_journey(character, weapon): return false
	for number in range(1, 9):
		if not _finish_stage() or not _ack_scene(true) or not sandbox._claim_weapon_reward(""): return false
		if number == 8 and not _check(controls.stage_route_options[0].lines[1].contains("성문 계단"), "실제 성문 이동 카드 안내"): return false
		if not _next_without_layout(): return false
	return _check_gate_layout()

func _check_gate_layout() -> bool:
	if not _check(runner.stage_number == 9 and runner.route_id == "city_gate" and festival_terrain.platforms == CityGateLayout.PLATFORMS and festival_terrain.get_child_count() == 6, "9스테이지 실제 전용 계단·성벽 발판6개"): return false
	for i in festival_terrain.platforms.size():
		var body := festival_terrain.get_child(i) as StaticBody2D
		var collision := body.get_child(0) as CollisionShape2D
		if not _check(body.position == festival_terrain.platforms[i].get_center() and collision.shape.size == festival_terrain.platforms[i].size, "성문 발판 표시·충돌 좌표/크기 일치"): return false
	return _check(runner.current_metrics().run_route_terrain == CityGateLayout.TERRAIN_NAME, "HUD/현재 도전의 성문 전용 지형 이름")

func _gate_waves() -> bool:
	player.global_position.x = 1240
	runner._process(0.1)
	if not _check(runner._active_enemies.size() == 3 and runner.seed_sack.position == CityGateLayout.WAVE_ONE.seed and runner.wind_spirit.position == CityGateLayout.WAVE_ONE.wind and runner.current_metrics().stage_objective.contains("성문 앞"), "첫 성문 웨이브·세 적 전용 배치·목표"): return false
	for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
	if not _resolve_growth(): return false
	runner._process(0.1)
	player.global_position.x = 3840
	runner._process(0.1)
	return _check(runner.seed_sack.position == CityGateLayout.WAVE_TWO.seed and runner.seed_sack.position.y + 60 == festival_terrain.platforms[5].position.y and runner.current_metrics().stage_objective.contains("성벽 위"), "둘째 성문 웨이브·실제 성벽 위 원거리 적·목표")

func _gate_cross() -> bool:
	if not _advance_to_cross(): return false
	player.double_jump_unlocked = false
	var entry: Rect2 = festival_terrain.platforms[0]
	player.prepare_next_stage(Vector2(entry.get_center().x, entry.position.y - 60))
	player.set_physics_process(true)
	festival_terrain.set_physics_process(true)
	for ignored in 8: await physics_frame
	if not _check(player.is_on_floor(), "성문 입구 실제 착지"): return false
	var falls := player.fall_count
	var dashes := player.air_dash_count
	for index in range(1, 6):
		if not await _jump_second_platform(index): return false
	if not _check(player.fall_count == falls and player.air_dash_count == dashes and player.double_jump_count == 0, "성문 계단·전투 발판은 기본 점프만으로 횡단"): return false
	var safe := player.last_safe_position
	if not _check(player.last_safe_label.begins_with("성벽 쉼터"), "성문 낙하 복귀점 이름"): return false
	player.global_position = Vector2(3360, 1120)
	player.velocity = Vector2.ZERO
	for ignored in 90:
		await physics_frame
		if player.fall_count > falls and not player._fall_recovery_active: break
	return _check(player.fall_count == falls + 1 and player.position.distance_to(safe) < 4, "성벽 쉼터로 실제 낙하 복귀")
