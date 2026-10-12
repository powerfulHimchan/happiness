extends "res://tests/gp227_236_runtime_test.gd"

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	store.save_path = "user://gp229_%s_checkpoint.json" % phase
	legacy.save_path = "user://gp229_%s_meta.jsonl" % phase
	store.clear_checkpoint()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy.save_path))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = "user://gp229_%s_records.jsonl" % phase
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	var book := AbilityDiscoveryStore.new()
	book.save_path = "user://gp229_%s_abilities.jsonl" % phase
	sandbox.ability_discovery_store = book
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	recorder = sandbox.get_node("LocalTestRecorder")
	forest_terrain = sandbox.get_node("RouteTerrain")
	forest_ultimate = sandbox.get_node("Player/UltimateController")
	for actor in [player, weapons, weapons.sword_combat, weapons.bow_combat, runner]:
		actor.set_process(false)
		actor.set_physics_process(false)
	growth.jobs_enabled = false
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	controls.begin_retry("sword", 5)
	if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "발판 검사 첫 정예"): return
	if not await _select_forest(): return
	player.global_position.x = 1240
	runner._process(0.1)
	for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
	if not _resolve_growth(): return
	runner._process(0.1)
	match phase:
		"motion":
			forest_terrain.set_physics_process(false)
			forest_terrain.configure(2, "forest")
			if not _check(forest_terrain.get_child(1) is AnimatableBody2D and forest_terrain.get_child(3) is AnimatableBody2D and forest_terrain.get_child(0) is StaticBody2D and forest_terrain.get_child(2) is StaticBody2D, "두 움직이는 충돌 발판·입구/중앙 고정 지지대"): return
			forest_terrain._physics_process(1.0)
			for ignored in 2: await physics_frame
			if not _check(forest_terrain.platforms[1].position == Vector2(3120, 700) and forest_terrain.platforms[3].position == Vector2(3680, 740) and forest_terrain.platforms[2] == PrototypeRouteTerrain.FOREST_STEPS[2], "반대 위상·수평40/수직20·중앙 고정"): return
			for index in 4:
				if not _check(forest_terrain.get_child(index).position.is_equal_approx(forest_terrain.platforms[index].get_center()), "실제 충돌 몸체와 표시 좌표 일치"): return
			forest_terrain._physics_process(3.0)
			for ignored in 2: await physics_frame
			if not _check(forest_terrain.platforms == PrototypeRouteTerrain.FOREST_STEPS and forest_terrain.motion_elapsed_s == 0, "큰 프레임·4초 주기 복귀"): return
			forest_terrain.configure(2, "forest")
			if not _check(forest_terrain.get_child_count() == 4 and forest_terrain.platforms == PrototypeRouteTerrain.FOREST_STEPS, "재구성은 몸체 중복 없음"): return
			forest_terrain.configure(2, "wind")
			if not _check(forest_terrain.get_child_count() == 3 and forest_terrain.get_children().all(func(body: Node) -> bool: return body is StaticBody2D), "기존 바람 고정 충돌로 복원"): return
		"cross", "pause":
			player.double_jump_unlocked = false
			player.prepare_next_stage(Vector2(3060, 780))
			player.set_physics_process(true)
			for ignored in 8: await physics_frame
			if not _check(player.is_on_floor() and player.last_safe_position == Vector2(3070, 780), "숲 입구 실제 착지·고정 안전 복귀점"): return
			if phase == "pause":
				var before := forest_terrain.layout_snapshot()
				var position := player.position
				controls.open_run_build()
				for ignored in 5: await physics_frame
				if not _check(paused and forest_terrain.layout_snapshot() == before and player.position == position, "도전 상태 조회는 발판 위상·탑승자 정지"): return
				controls.close_run_build()
				controls.advance_mode_timer_for_test(3.1)
				for ignored in 5: await physics_frame
				if not _check(not paused and forest_terrain.motion_elapsed_s > float(before.motion_elapsed), "3초 복귀 후 같은 움직임 재개"): return
				controls.show_main_screen()
				controls.show_village()
				before = forest_terrain.layout_snapshot()
				for ignored in 5: await physics_frame
				if not _check(sandbox.is_combat_environment_suspended() and forest_terrain.layout_snapshot() == before, "마을/도감 환경에서도 발판 물리 동결"): return
			else:
				var falls := player.fall_count
				var dashes := player.air_dash_count
				if not await _jump_to_forest_platform(1): return
				if not _check(player.last_safe_position == Vector2(3070, 780), "움직이는 발판은 안전 복귀점 덮어쓰기 없음"): return
				var relative_x := player.position.x - forest_terrain.platforms[1].get_center().x
				var start := forest_terrain.platforms[1].get_center()
				for ignored in 30: await physics_frame
				if not _check(player.is_on_floor() and absf(player.position.x - forest_terrain.platforms[1].get_center().x - relative_x) < 5.0 and start.distance_to(forest_terrain.platforms[1].get_center()) > 1.0, "Animatable 충돌은 실제 탑승자를 운반"): return
				if not await _jump_to_forest_platform(2): return
				var safe := Vector2(3530, 540)
				if not _check(player.last_safe_position == safe, "중앙 고정 쉼터 실제 착지·안전 갱신"): return
				if not await _jump_to_forest_platform(3): return
				if not _check(player.last_safe_position == safe and player.fall_count == falls and player.air_dash_count == dashes, "기본 점프만으로 이동 발판 횡단·공중 대시 불필요"): return
				var health := player.damage_receiver.health
				var expected_damage := ceili(player.damage_receiver.max_health * player.FALL_DAMAGE_RATIO)
				player.global_position = Vector2(3360, 1120)
				player.velocity = Vector2.ZERO
				for ignored in 90:
					await physics_frame
					if player.fall_count > falls and not player._fall_recovery_active: break
				if not _check(player.fall_count == falls + 1 and player.global_position.distance_to(safe) < 4 and player.damage_receiver.health == health - expected_damage and player.last_safe_label.contains("고정 쉼터"), "실제 낙하는 움직임과 독립인 고정 쉼터로 복귀·10% 피해"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-228–229 runtime test: OK (%s)" % phase)
	quit(0)

func _jump_to_forest_platform(index: int) -> bool:
	player.set_move_vector(Vector2.RIGHT)
	player.request_jump()
	var left_floor := false
	for ignored in 150:
		await physics_frame
		if not player.is_on_floor(): left_floor = true
		if player.global_position.x >= forest_terrain.platforms[index].get_center().x - 34:
			player.set_move_vector(Vector2.ZERO)
		if left_floor and player.is_on_floor(): break
	player.release_jump()
	player.set_move_vector(Vector2.ZERO)
	for ignored in 8: await physics_frame
	var rect := forest_terrain.platforms[index]
	return _check(left_floor and player.is_on_floor() and absf(player.position.y + 60.0 - rect.position.y) < 4.0 and player.position.x > rect.position.x + 40.0 and player.position.x < rect.end.x - 40.0, "숲 발판%d 기본 점프 실제 착지: %s / %s" % [index, player.position, rect])
