extends "res://tests/cp301_runtime_test.gd"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var facing := float(args[1]) if args.size() > 1 else 1.0
	var sandbox := SANDBOX_SCENE.instantiate()
	var meta := BossLegacyStore.new()
	meta.save_path = "user://gp242_meta.jsonl"
	sandbox.boss_legacy_store = meta
	var store := RunCheckpointStore.new()
	store.save_path = "user://gp242_checkpoint.json"
	sandbox.checkpoint_store = store
	sandbox.get_node("LocalTestRecorder").record_path = "user://gp242_records.jsonl"
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
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
	var ultimate := sandbox.get_node("Player/UltimateController") as UltimateController
	var weapons := sandbox.get_node("Player/PrototypeWeaponController") as PrototypeWeaponController
	for node in [weapons, weapons.sword_combat, weapons.bow_combat, ultimate]:
		node.set_process(false)
		node.set_physics_process(false)
	for enemy in runner._all_combat_enemies(): enemy.set_process(false)
	var trap := sandbox.get_node("ClockTrapController") as ClockTrapController
	trap.set_process(false)
	trap.configure(2, "ruins")
	trap.start_wave(1)
	player.global_position = ClockTrapController.ZONES[0].get_center() + Vector2(0, 38)
	match phase:
		"damage":
			var health := player.damage_receiver.health
			trap._process(0.99)
			if not _assert_true(trap.state == ClockTrapController.State.WARNING and trap.visible and player.damage_receiver.health == health, "1초 전 경고·무피해"): return
			trap._process(0.011)
			if not _assert_equal(player.damage_receiver.health, health, "발동 전이 프레임은 선제 피해 없음"): return
			trap._process(0.01)
			player.damage_receiver.tick(1)
			player._input_lock_remaining_s = 0
			trap._process(0.1)
			if not _assert_true(player.damage_receiver.health == health - 12 and trap.hit_count == 1, "한 주기 한 번·12피해·중복 차단"): return
			trap._process(0.3)
			trap._process(2.51)
			trap._process(1.01)
			trap._process(0.01)
			if not _assert_true(player.damage_receiver.health == health - 24 and trap.cycle == 2, "휴식 뒤 새 경고·새 피해 ID"): return
			player.damage_receiver.tick(1)
			player._input_lock_remaining_s = 0
			player.set_barrier_unlocked(true)
			trap.start_wave(2)
			player.position = ClockTrapController.ZONES[1].get_center() + Vector2(0, 38)
			trap._process(1.01)
			trap._process(0.01)
			if not _assert_true(player.damage_receiver.barrier_health == 8 and player.damage_receiver.health == health - 24, "시간 함정도 방벽 선흡수"): return
			player.damage_receiver.barrier_health = 3
			player.recover_barrier(10)
			if not _assert_equal(player.damage_receiver.barrier_health, 13, "유적 방벽 보너스 기존 회복 규칙"): return
			player.recover_barrier(100)
			if not _assert_equal(player.damage_receiver.barrier_health, 20, "방벽 최대치 제한"): return
			player.set_barrier_unlocked(false)
			player.recover_barrier(10)
			if not _assert_equal(player.damage_receiver.barrier_health, 0, "미해금 방벽 보너스 없음"): return
		"evade":
			var health := player.damage_receiver.health
			ultimate.gauge = 0
			player.invincible = true
			trap._process(1.01)
			trap._process(0.01)
			trap._process(0.1)
			if not _assert_true(player.damage_receiver.health == health and ultimate.precise_evade_count == 1 and ultimate.gauge == ultimate.precise_evade_gauge_amount(), "정확한 회피·주기당 게이지 한 번"): return
			player.invincible = false
			trap.start_wave(1)
			player.position.y = 640
			trap._process(1.01)
			trap._process(0.01)
			if not _assert_true(not trap._hit_consumed and player.damage_receiver.health == health, "높이 밖 점프는 회피 등록/피해 없음"): return
			player.position.y = 780
			trap._process(0.01)
			if not _assert_equal(player.damage_receiver.health, health - 12, "발동 중 재진입은 한 번 타격"): return
		"flows":
			ultimate._apply_enemy_time_scale(0.25)
			trap._process(2)
			if not _assert_true(trap.state == ClockTrapController.State.WARNING and trap.elapsed_s == 0.5, "필살기 실제 그룹 감속·경고 연장"): return
			trap.set_process(true)
			paused = true
			var before := trap.snapshot()
			for ignored in 4: await process_frame
			if not _assert_equal(trap.snapshot(), before, "트리 일시정지는 같은 함정 상태 동결"): return
			paused = false
			for ignored in 4: await process_frame
			if not _assert_true(trap.elapsed_s > float(before.elapsed), "복귀 후 같은 경고 재개"): return
			trap.set_process(false)
			ultimate.finish_stage_effect()
			if not _assert_equal(trap.enemy_time_scale, 1.0, "스테이지 필살기 종료는 함정 시간 복원"): return
			sandbox._suspend_combat_environment()
			before = trap.snapshot()
			for ignored in 4: await process_frame
			if not _assert_true(not trap.visible and trap.snapshot() == before, "마을 환경은 함정 숨김·동결"): return
			sandbox._restore_combat_environment()
			trap.stop()
			if not _assert_true(trap.state == ClockTrapController.State.OFF and not trap.visible, "웨이브 종료 함정 정리"): return
			trap.start_wave(1)
			player.receive_damage(_damage_event(&"gp242:dead", 999, Vector2.ZERO, ["test"]))
			trap._process(0.1)
			if not _assert_equal(trap.state, ClockTrapController.State.OFF, "사망 즉시 경고 정리"): return
			trap.configure(2, "wind")
			trap.start_wave(1)
			if not _assert_equal(trap.state, ClockTrapController.State.OFF, "다른 경로 함정 없음"): return
		"doll":
			trap.stop()
			player.position = Vector2(2500, 780)
			var actor := runner.seed_sack
			actor.configure_route("ruins")
			actor.set_stage_spawn(player.position + Vector2(facing * 500, 0))
			actor.reset_target()
			actor._process(0.001)
			var aim := actor._clock_aim
			if not _assert_true(actor.enemy_name() == "별시계 인형" and actor.body_sprite.texture == PrototypeEnemy.CLOCK_DOLL_TEXTURE and actor.warning_count == 1, "실제 태엽 인형 시각·첫 경고"): return
			actor._process(0.99)
			if not _assert_equal(actor.attack_count, 0, "1초 첫 경고"): return
			actor._process(0.02)
			var seeds := get_nodes_in_group("enemy_projectile")
			if not _assert_equal(seeds.size(), 3, "인형 첫 세 발 생성"): return
			var ids: Array[String] = []
			for seed in seeds:
				seed.set_physics_process(false)
				ids.append(seed.projectile_id)
				if not _assert_true(seed.attack_id == &"clock_doll_volley" and seed.damage == 7, "실제 인형 발사체 태그·기존 피해"): return
			var direction: Vector2 = seeds[1].direction
			var health := player.damage_receiver.health
			seeds[1]._physics_process(1.0)
			if not _assert_equal(player.damage_receiver.health, health - 7, "실제 중심 발사체 이동·피해"): return
			for seed in seeds: seed.free()
			player.position.x += facing * 120
			actor._process(0.351)
			if not _assert_true(actor.state == PrototypeEnemy.State.WARNING and actor.warning_count == 2 and actor._clock_aim == aim, "짧은 빈틈 뒤 두 번째 경고·기억한 방향"): return
			actor._process(0.69)
			if not _assert_equal(actor.attack_count, 1, "0.7초 재사격 경고 전 금지"): return
			actor._process(0.02)
			seeds = get_nodes_in_group("enemy_projectile")
			for seed in seeds:
				seed.set_physics_process(false)
				ids.append(seed.projectile_id)
			if not _assert_true(seeds.size() == 3 and seeds[1].direction.is_equal_approx(direction) and ids.all(func(id: String) -> bool: return ids.count(id) == 1), "같은 방향 재사격·여섯 고유 ID"): return
			for seed in seeds: seed.free()
			actor._process(0.4)
			if not _assert_true(actor.attack_count == 2 and actor.state == PrototypeEnemy.State.RECOVERY, "세 번째 자동 사격 없음"): return
			actor.reset_target()
			actor._process(0.001)
			actor.receive_damage(_damage_event(&"gp242:interrupt", 1, player.position, ["sword"]))
			if not _assert_true(actor._combo_remaining == 0 and actor.state == PrototypeEnemy.State.RECOVERY, "근접 피격은 예약 재사격 중단"): return
			actor.reset_target()
			actor._process(0.001)
			actor.receive_damage(_damage_event(&"gp242:doll_dead", 999, player.position, ["test"]))
			actor._process(2)
			if not _assert_true(actor._combo_remaining == 0 and actor.attack_count == 0 and not actor.warning_line.visible, "인형 사망 예약 정리"): return
			actor.configure_route("meadow")
			actor.reset_target()
			if not _assert_true(actor.body_sprite.texture == actor._original_body_texture and not actor.ruins_variant, "기존 씨앗 포대 시각·패턴 복원"): return
		_:
			_assert_true(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-240–242 runtime test: OK (%s %.0f)" % [phase, facing])
	quit(0)
