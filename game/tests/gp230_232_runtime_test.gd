extends "res://tests/cp301_runtime_test.gd"

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	var facing := float(OS.get_cmdline_user_args()[1]) if OS.get_cmdline_user_args().size() > 1 else 1.0
	var sandbox := SANDBOX_SCENE.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	var meta := BossLegacyStore.new()
	meta.save_path = "user://gp232_enemy_meta.jsonl"
	sandbox.boss_legacy_store = meta
	var store := RunCheckpointStore.new()
	store.save_path = "user://gp232_enemy_checkpoint.json"
	sandbox.checkpoint_store = store
	sandbox.get_node("LocalTestRecorder").record_path = "user://gp232_enemy_records.jsonl"
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	var runner := sandbox.get_node("StageRunner") as PrototypeStageRunner
	runner.set_stage_enabled(false)
	runner.set_process(false)
	var player := sandbox.get_node("Player") as PrototypePlayer
	player.reset_movement_test(Vector2(2500, 780))
	player.set_physics_process(false)
	var weapons := sandbox.get_node("Player/PrototypeWeaponController") as PrototypeWeaponController
	for node in [weapons, weapons.sword_combat, weapons.bow_combat, sandbox.get_node("Player/UltimateController")]:
		node.set_process(false)
		node.set_physics_process(false)
	for enemy in runner._all_combat_enemies(): enemy.set_process(false)
	var actor := runner.leaf_slime if phase == "slime" else runner.wind_spirit if phase == "wind" else runner.seed_sack
	actor.configure_route("forest")
	actor.set_stage_spawn(player.global_position + Vector2(facing * (100.0 if phase == "slime" else 400.0 if phase == "wind" else 500.0), -165.0 if phase == "wind" else 0.0))
	actor.reset_target()
	match phase:
		"slime", "wind":
			var warning := 0.35 if phase == "slime" else 0.6
			actor._process(0.001)
			if not _assert_true(actor.state == PrototypeEnemy.State.WARNING and actor.warning_count == 1 and actor._combo_remaining == 1, "숲 첫 공격 경고·연속1회 예약"): return
			actor._process(warning - 0.01)
			if not _assert_equal(actor.attack_count, 0, "첫 경고 시간 전 공격 금지"): return
			actor._process(0.011)
			if not _assert_equal(actor.attack_count, 1, "첫 공격 발동"): return
			if not _contact_once(actor, player, phase): return
			actor._process(1.0)
			if not _assert_equal(actor.state, PrototypeEnemy.State.RECOVERY, "첫 공격 후 빈틈"): return
			actor._process(0.30)
			if not _assert_true(actor.state == PrototypeEnemy.State.WARNING and actor.warning_count == 2 and actor.attack_count == 1 and actor._combo_remaining == 0, "두 번째도 별도 경고·예약 소비"): return
			var direction := actor._attack_direction
			if phase == "wind": player.global_position.x += facing * 100
			actor._process(warning - 0.01)
			if not _assert_true(actor.attack_count == 1 and (phase == "slime" or actor._attack_direction == direction), "재공격 경고 시간·돌진 방향 고정"): return
			actor._process(0.011)
			if not _assert_equal(actor.attack_count, 2, "두 번째 공격 발동"): return
			if not _contact_once(actor, player, phase): return
			actor._process(1.0)
			actor._process(0.30)
			if not _assert_true(actor.state == PrototypeEnemy.State.RECOVERY and actor.attack_count == 2 and actor.warning_count == 2, "세 번째 자동 공격 없음·기존 긴 빈틈"): return
			actor.reset_target()
			actor._combo_remaining = 1
			actor.receive_damage(_damage_event(&"gp232:dead", 999, player.global_position, ["test"]))
			actor._process(1.0)
			if not _assert_true(actor.state == PrototypeEnemy.State.DEAD and not actor.warning_line.visible and not actor.warning_ring.visible and actor.attack_count == 0, "사망 후 예약 공격 중단"): return
			actor.configure_route("meadow")
			actor.reset_target()
			actor.global_position = player.global_position + Vector2(facing * 100, 0)
			actor._process(0.001)
			actor._process(warning + 0.01)
			actor._process(1.0)
			actor._process(0.30)
			if not _assert_true(actor.attack_count == 1 and actor.warning_count == 1 and actor._combo_remaining == 0, "기존 경로 단일 공격 유지"): return
		"seed":
			actor._process(0.001)
			if not _assert_true(actor.warning_feedback_snapshot().shape == "부채" and actor.warning_line.visible and actor.warning_ring.visible, "씨앗 부채 경고·색과 형태"): return
			actor._process(0.99)
			if not _assert_equal(get_nodes_in_group("enemy_projectile").size(), 0, "1초 경고 전 씨앗 없음"): return
			actor._process(0.02)
			var seeds := get_nodes_in_group("enemy_projectile")
			if not _assert_equal(seeds.size(), 5, "숲 실제5발 생성"): return
			var ids: Array[String] = []
			for seed in seeds:
				seed.set_physics_process(false)
				ids.append(seed.projectile_id)
				if not _assert_true(seed.damage == 7 and is_equal_approx(seed.speed_px_s, 550), "기존 피해/속도 유지"): return
			if not _assert_true(ids.all(func(id: String) -> bool: return ids.count(id) == 1) and is_equal_approx(absf(rad_to_deg(seeds[0].direction.angle_to(seeds[4].direction))), 48.0), "48도 부채·각 발 고유 ID"): return
			var health := player.damage_receiver.health
			seeds[2]._physics_process(1.0)
			if not _assert_equal(player.damage_receiver.health, health - 7, "실제 중심 씨앗 이동·접촉 피해"): return
			for seed in seeds: seed.free()
			actor.configure_route("meadow")
			actor.reset_target()
			actor._process(0.001)
			actor._process(1.01)
			if not _assert_equal(get_nodes_in_group("enemy_projectile").size(), 3, "기존3발 회귀"): return
		"flows":
			for enemy in [runner.leaf_slime, runner.seed_sack, runner.wind_spirit]:
				enemy.configure_route("forest")
				enemy.reset_target()
				enemy.visible = true
				enemy.set_enemy_time_scale(0.25)
				enemy._begin_warning("감속 검사")
				var duration := 0.35 if enemy == runner.leaf_slime else 1.0 if enemy == runner.seed_sack else 0.6
				enemy._process(duration * 2.0)
				if not _assert_equal(enemy.attack_count, 0, "필살기 감속은 새 패턴 경고에도 적용"): return
				enemy._process(duration * 2.0 + 0.01)
				if not _assert_equal(enemy.attack_count, 1, "감속된 경고 종료 후 공격"): return
				enemy.reset_target()
				enemy._begin_warning("정지 검사")
				enemy.set_process(true)
				paused = true
				for ignored in 3: await process_frame
				if not _assert_equal(enemy._state_elapsed_s, 0.0, "트리 정지는 새 경고 진행 동결"): return
				paused = false
				for ignored in 3: await process_frame
				if not _assert_true(enemy._state_elapsed_s > 0.0, "복귀 후 같은 경고 재개"): return
				enemy.set_process(false)
		_:
			_assert_true(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-230–232 runtime test: OK (%s %.0f)" % [phase, facing])
	quit(0)

func _contact_once(actor: PrototypeEnemy, player: PrototypePlayer, phase: String) -> bool:
	player.damage_receiver.tick(1.0)
	player._input_lock_remaining_s = 0.0
	actor.global_position = player.global_position + Vector2(0, -38)
	var health := player.damage_receiver.health
	actor._try_contact_damage(8 if phase == "slime" else 10, &"slime_jump" if phase == "slime" else &"wind_dash")
	actor._try_contact_damage(8 if phase == "slime" else 10, &"slime_jump" if phase == "slime" else &"wind_dash")
	return _assert_equal(player.damage_receiver.health, health - (8 if phase == "slime" else 10), "연속 각 공격당 접촉 피해 한 번")
