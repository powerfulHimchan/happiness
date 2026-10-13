extends "res://tests/gp307_runtime_test.gd"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var route := args[1]
	var prefix := "user://gp308_%s_%s" % ["flow" if phase in ["seed", "resume"] else phase, route]
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
	match phase:
		"resume":
			var saved := store.load_checkpoint()
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and runner.stage_number == 2 and runner.route_id == route and runner.region_section() == 2 and player.damage_receiver.health == saved.player.health and festival_ultimate.gauge == 37 and weapons.sword_combat._skill_1_cooldown_s == 3.25 and store.load_checkpoint() == saved, "별도 프로세스 두 번째 구간 반복 복원·잔량/장비/순서 보존"): return
				if not _check(festival_terrain.base_platforms == RegionStageLayout.platforms(route) and festival_terrain.motion_elapsed_s == 0, "완료 저장의 전용 지형은 같은 배치·위상0 복원"): return
			var options := runner.available_routes()
			_tap(controls.stage_route_rects[0].get_center())
			if not _check(runner.stage_number == 3 and runner.route_id == options[0].id and runner.region_section() == 1 and festival_terrain.region_section == 1 and festival_terrain.get_child_count() == (3 if runner.route_id == "wind" else 4), "다음 지역은 원래 첫 구간·전용 몸체 잔류 없음"): return
		_:
			if not _start_second_section(route): return
			match phase:
				"seed":
					if not _check(runner.current_metrics().run_route_name.contains(RegionStageLayout.TITLES[route]) and runner.current_metrics().run_region_section == 2, "HUD 실제 두 번째 구간 이름/번호"): return
					player.global_position.x = 1240
					runner._process(0.1)
					if not _check(runner._active_enemies.size() == 3 and runner.seed_sack.position == RegionStageLayout.WAVE_ONE[route].seed and runner.wind_spirit.position == RegionStageLayout.WAVE_ONE[route].wind, "첫 웨이브 실제 세 적·전용 위치"): return
					for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
					if not _resolve_growth(): return
					runner._process(0.1)
					player.global_position.x = 3840
					runner._process(0.1)
					if not _check(runner.seed_sack.position == RegionStageLayout.WAVE_TWO[route].seed and runner.leaf_slime.position == RegionStageLayout.WAVE_TWO[route].slime, "둘째 웨이브 실제 전용 위치"): return
					if not _finish_stage() or not sandbox._claim_weapon_reward("sword"): return
					_tap(controls.relic_reward_open_rect.get_center())
					if not _check(sandbox._claim_relic_reward(PrototypeRelic.CLOCK_ID), "두 번째 구간의 실제 유물 보상"): return
					player.damage_receiver.health = 83
					festival_ultimate.gauge = 37
					weapons.sword_combat._skill_1_cooldown_s = 3.25
					if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK and RunCheckpointStore.valid_state(store.load_checkpoint()) and not store.load_checkpoint().stage.has("region_section"), "저장 버전1·구간은 기존 모드/번호에서 결정"): return
				"motion":
					if not await _second_motion(route): return
				"cross":
					if not await _second_cross(route): return
				"flows":
					if not await _second_flows(route): return
				"hazard":
					if not _second_hazard(route): return
				_:
					_check(false, "알 수 없는 검사 단계")
					return
	paused = false
	sandbox.free()
	print("GP-308 runtime test: OK (%s %s)" % [phase, route])
	quit(0)

func _start_second_section(route: String) -> bool:
	runner.stage_limit = 10
	runner.set_run_mode("journey")
	var selected_seed := -1
	for seed in 96:
		runner.region_rng.seed = seed
		runner.reset_run()
		if runner.route_id == route:
			selected_seed = seed
			break
	if not _check(selected_seed >= 0, "각 지역으로 시작하는 실제 무작위 시드"): return false
	runner.region_rng.seed = selected_seed
	controls.show_main_screen()
	controls.show_start_weapon_selection()
	_tap(controls.start_length_rects[3].get_center())
	_tap(controls.start_weapon_confirm_rect.get_center())
	if not _check(runner.route_id == route and runner.region_section() == 1 and festival_terrain.get_child_count() == (3 if route == "wind" else 4), "첫 구간은 기존 지형·실제 전체 여정 시작"): return false
	if not _finish_stage() or not sandbox._claim_weapon_reward(""): return false
	if not _check(controls.stage_route_options[0].name.contains(RegionStageLayout.TITLES[route]), "실제 다음 구간 카드의 전용 이름"): return false
	_tap(controls.stage_route_rects[0].get_center())
	return _check(runner.stage_number == 2 and runner.route_id == route and runner.region_section() == 2 and festival_terrain.base_platforms == RegionStageLayout.platforms(route) and festival_terrain.get_child_count() == (6 if route == "forest" else 5), "실제 입력으로 같은 지역 두 번째 전용 지형 구성")

func _second_motion(route: String) -> bool:
	var base := festival_terrain.base_platforms.duplicate()
	var elapsed := 2.25 if route == "ruins" else 1.0
	festival_terrain._physics_process(elapsed)
	for ignored in 2: await physics_frame
	for i in base.size():
		if not _check(festival_terrain.get_child(i).position.is_equal_approx(festival_terrain.platforms[i].get_center()), "전용 발판의 표시/충돌 좌표 일치"): return false
		if i not in [1, 3] or route == "wind":
			if not _check(festival_terrain.platforms[i] == base[i], "입구·중앙·출구·전투 고정 쉼터"): return false
		else:
			if not _check(festival_terrain.get_child(i) is AnimatableBody2D and festival_terrain.platforms[i] != base[i], "두 전용 움직이는 충돌 발판"): return false
	var period := 4.0 if route == "forest" else 6.0 if route == "ruins" else 5.0
	festival_terrain._physics_process(period - elapsed)
	if not _check(festival_terrain.platforms == base, "정확한 주기 뒤 전용 배치로 복귀"): return false
	festival_terrain.configure(2, route, true, true, 2)
	if not _check(festival_terrain.get_child_count() == base.size(), "재구성에서 몸체 중복 없음"): return false
	festival_terrain.configure(2, route)
	return _check(festival_terrain.region_section == 1 and festival_terrain.get_child_count() == (3 if route == "wind" else 4), "일반/순회2스테이지는 원래 첫 구간 지형")

func _advance_to_cross() -> bool:
	player.global_position.x = 1240
	runner._process(0.1)
	for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
	if not _resolve_growth(): return false
	runner._process(0.1)
	return _check(runner.current_section == PrototypeStageRunner.Section.ADVANCE_TWO, "실제 첫 웨이브 뒤 이동 구간")

func _second_cross(route: String) -> bool:
	if not _advance_to_cross(): return false
	var terrain := festival_terrain
	player.double_jump_unlocked = false
	var entry: Rect2 = terrain.platforms[0]
	player.prepare_next_stage(Vector2(entry.get_center().x, entry.position.y - 60))
	player.set_physics_process(true)
	terrain.set_physics_process(true)
	for ignored in 8: await physics_frame
	if not _check(player.is_on_floor(), "전용 입구 실제 착지"): return false
	var falls := player.fall_count
	var dashes := player.air_dash_count
	for index in range(1, 5):
		if not await _jump_second_platform(index): return false
		if index == 1 and route != "wind":
			var relative := player.position.x - terrain.platforms[1].get_center().x
			var before := terrain.platforms[1].get_center()
			if route == "ruins": terrain.motion_elapsed_s = 1.5
			for ignored in 30: await physics_frame
			if not _check(player.is_on_floor() and absf(player.position.x - terrain.platforms[1].get_center().x - relative) < 5 and before.distance_to(terrain.platforms[1].get_center()) > 1, "실제 탑승자를 운반하는 전용 발판"): return false
	if not _check(player.fall_count == falls and player.air_dash_count == dashes and player.double_jump_count == 0, "각 전용 구간은 기본 점프만으로 횡단·추가 해금 불필요"): return false
	var safe := player.last_safe_position
	player.global_position = Vector2(3360, 1120)
	player.velocity = Vector2.ZERO
	for ignored in 90:
		await physics_frame
		if player.fall_count > falls and not player._fall_recovery_active: break
	return _check(player.fall_count == falls + 1 and player.position.distance_to(safe) < 4, "전용 출구 고정 쉼터로 실제 낙하 복귀")

func _jump_second_platform(index: int) -> bool:
	player.set_move_vector(Vector2.RIGHT)
	player.request_jump()
	var left := false
	for ignored in 150:
		if runner.current_section == PrototypeStageRunner.Section.ADVANCE_TWO and player.position.x >= PrototypeStageRunner.ADVANCE_TWO_X:
			runner._process(0.01)
			for enemy in runner._active_enemies:
				enemy.set_process(false)
				enemy.set_physics_process(false)
		await physics_frame
		if not player.is_on_floor(): left = true
		if player.position.x >= festival_terrain.platforms[index].get_center().x - 34: player.set_move_vector(Vector2.ZERO)
		if left and player.is_on_floor(): break
	player.release_jump()
	player.set_move_vector(Vector2.ZERO)
	for ignored in 8: await physics_frame
	var rect: Rect2 = festival_terrain.platforms[index]
	return _check(left and player.is_on_floor() and absf(player.position.y + 60 - rect.position.y) < 4 and player.position.x > rect.position.x + 40 and player.position.x < rect.end.x - 40, "전용 발판%d 기본 점프 착지 %s / %s" % [index, player.position, rect])

func _second_flows(route: String) -> bool:
	var before := festival_terrain.layout_snapshot()
	var saved := store.load_checkpoint()
	festival_terrain.set_physics_process(true)
	controls.open_run_build()
	for ignored in 5: await physics_frame
	if not _check(paused and festival_terrain.layout_snapshot() == before and store.load_checkpoint() == saved, "전용 지형도 조회에서 동결·저장 무변경"): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(3.1)
	for ignored in 5: await physics_frame
	if route != "wind" and not _check(festival_terrain.motion_elapsed_s > 0, "조회 후 전용 발판 움직임 재개"): return false
	controls.show_main_screen()
	controls.show_village()
	before = festival_terrain.layout_snapshot()
	for ignored in 5: await physics_frame
	if not _check(festival_terrain.layout_snapshot() == before, "마을/도감에서 전용 지형 동결"): return false
	for number in [2, 4, 6, 8]:
		if not _check(RegionStageLayout.section("journey", number, route) == 2, "등장 순서와 무관한 지역 두 번째 구간"): return false
	for mode in ["standard", "regions"]:
		for number in range(1, 11):
			if not _check(RegionStageLayout.section(mode, number, route) == 1, "기존 모드에는 전용 두 번째 구간을 적용하지 않음"): return false
	return true

func _second_hazard(route: String) -> bool:
	var trap: ClockTrapController = sandbox.get_node("ClockTrapController")
	trap.start_wave(1)
	if route != "ruins": return _check(trap.state == ClockTrapController.State.OFF, "다른 지역에 유적 함정 없음")
	if not _check(trap.zones == RegionStageLayout.TRAP_ZONES and trap.state == ClockTrapController.State.WARNING, "시계 회랑 전용 위치·먼저 경고"): return false
	player.global_position = trap.zones[0].get_center() + Vector2(0, 38)
	player.velocity = Vector2.ZERO
	var hp := player.damage_receiver.health
	trap._process(1.01)
	trap._process(0.01)
	if not _check(player.damage_receiver.health == hp - ClockTrapController.DAMAGE and trap.hit_count == 1, "새 위치의 실제 함정 피해"): return false
	trap._process(0.01)
	if not _check(player.damage_receiver.health == hp - ClockTrapController.DAMAGE, "같은 맥동은 한 번만 피해"): return false
	trap.start_wave(2)
	if not _check(trap.zone_index == 1 and trap.zones[1] == RegionStageLayout.TRAP_ZONES[1], "다음 웨이브의 새 위치"): return false
	trap.configure(2, "ruins")
	return _check(trap.region_section == 1 and trap.zones == ClockTrapController.ZONES and trap.state == ClockTrapController.State.OFF, "기존 유적 경로의 원래 함정 배치 복원")
