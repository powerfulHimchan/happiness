extends "res://tests/cp301_runtime_test.gd"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var facing := float(args[1]) if args.size() > 1 else 1.0
	var sandbox := SANDBOX_SCENE.instantiate()
	var meta := BossLegacyStore.new()
	meta.save_path = "user://gp252_meta.jsonl"
	sandbox.boss_legacy_store = meta
	var checkpoint := RunCheckpointStore.new()
	checkpoint.save_path = "user://gp252_checkpoint.json"
	sandbox.checkpoint_store = checkpoint
	sandbox.get_node("LocalTestRecorder").record_path = "user://gp252_records.jsonl"
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
	var actor := runner.leaf_slime if phase == "soldier" else runner.seed_sack
	actor.configure_route("festival")
	actor.set_stage_spawn(player.position + Vector2(facing * (160 if phase == "soldier" else 500), 0))
	actor.reset_target()
	match phase:
		"soldier":
			actor._process(0.001)
			var direction := actor._attack_direction
			if not _assert_true(actor.enemy_name() == "장난감 병정" and actor.body_sprite.texture == PrototypeEnemy.FESTIVAL_SOLDIER_TEXTURE and actor.warning_count == 1 and actor.warning_feedback_snapshot().shape == "직선", "병정 시각·방향 고정 직선 경고"): return
			actor._process(0.64)
			if not _assert_equal(actor.attack_count, 0, "0.65초 경고 전 공격 없음"): return
			actor._process(0.02)
			if not _assert_equal(actor.attack_count, 1, "병정 돌진 시작"): return
			var health := player.damage_receiver.health
			for ignored in 60: actor._process(0.01)
			if not _assert_true(actor.position.y == 780 and actor._attack_direction == direction and actor.hit_count == 1 and player.damage_receiver.health == health - 9 and actor.state == PrototypeEnemy.State.RECOVERY, "양 방향 지상240px 돌진·9피해 한 번·빈틈"): return
			actor._process(0.8)
			if not _assert_equal(actor.attack_count, 1, "1.1초 재감기 중 재공격 없음"): return
			actor.reset_target()
			actor._process(0.001)
			actor.receive_damage(_damage_event(&"gp252:interrupt", 1, player.position, ["sword"]))
			if not _assert_true(actor.state == PrototypeEnemy.State.RECOVERY and actor.attack_count == 0, "검 타격은 병정 돌진 준비 중단"): return
			actor.reset_target()
			actor._process(0.001)
			player.damage_receiver.tick(1)
			player._input_lock_remaining_s = 0
			player.invincible = true
			ultimate.gauge = 0
			actor._process(0.66)
			for ignored in 60: actor._process(0.01)
			if not _assert_true(player.damage_receiver.health == health - 9 and ultimate.precise_evade_count == 1, "정확한 회피는 돌진당 한 번"): return
			player.invincible = false
			actor.reset_target()
			player.damage_receiver.tick(1)
			player._input_lock_remaining_s = 0
			player.set_barrier_unlocked(true)
			actor._process(0.001)
			actor._process(0.66)
			for ignored in 60: actor._process(0.01)
			if not _assert_true(player.damage_receiver.barrier_health == 11 and player.damage_receiver.health == health - 9, "병정 공격은 방벽 선흡수"): return
		"turret":
			actor._process(0.001)
			var origin := actor.position
			var aim := actor._clock_aim
			if not _assert_true(actor.enemy_name() == "축제 포탑" and actor.body_sprite.texture == PrototypeEnemy.FESTIVAL_TURRET_TEXTURE and actor.warning_count == 1 and actor.warning_feedback_snapshot().shape == "부채", "포탑 시각·부채 경고"): return
			actor._process(1.09)
			if not _assert_equal(actor.attack_count, 0, "1.1초 경고 전 사격 없음"): return
			player.position.y -= 100
			actor._process(0.02)
			var shots := get_nodes_in_group("enemy_projectile")
			if not _assert_true(shots.size() == 5 and actor.position == origin and shots[2].direction.is_equal_approx(aim), "고정 포탑·기억한 방향·다섯 발"): return
			var ids: Array[String] = []
			for i in shots.size():
				var shot := shots[i] as EnemySeedProjectile
				shot.set_physics_process(false)
				ids.append(shot.projectile_id)
				if not _assert_true(shot.direction.is_equal_approx(aim.rotated(deg_to_rad(PrototypeEnemy.TURRET_ANGLES[i]))) and shot.attack_id == &"turret_fan" and shot.attacker_id == &"festival_turret" and shot.damage == 7 and shot.damage_tags.has("festival"), "각도·7피해·포탑 이벤트 태그"): return
			player.position.y += 100
			var health := player.damage_receiver.health
			shots[2]._physics_process(1.0)
			if not _assert_equal(player.damage_receiver.health, health - 7, "실제 중심탄 이동·피해"): return
			for shot in shots: shot.free()
			actor._process(1.0)
			if not _assert_equal(actor.attack_count, 1, "재장전1.4초 사격 없음"): return
			actor._process(0.41)
			actor._process(0.61)
			actor._process(1.11)
			shots = get_nodes_in_group("enemy_projectile")
			for shot in shots:
				shot.set_physics_process(false)
				ids.append(shot.projectile_id)
			if not _assert_true(shots.size() == 5 and ids.all(func(id: String) -> bool: return ids.count(id) == 1), "재조준 후 사격·두 주기10개 고유 ID"): return
			for shot in shots: shot.free()
			actor.reset_target()
			actor._process(0.001)
			actor.receive_damage(_damage_event(&"gp252:turret_interrupt", 1, player.position, ["sword"]))
			actor._process(1.11)
			if not _assert_equal(actor.attack_count, 0, "검 피격은 포탑 준비 사격 중단"): return
		"flows":
			actor._process(0.001)
			ultimate._apply_enemy_time_scale(0.25)
			actor._process(2)
			if not _assert_true(actor.state == PrototypeEnemy.State.WARNING and actor._state_elapsed_s == 0.5, "필살기 실제 그룹 감속·경고 연장"): return
			actor.set_process(true)
			paused = true
			var elapsed := actor._state_elapsed_s
			for ignored in 4: await process_frame
			if not _assert_equal(actor._state_elapsed_s, elapsed, "조회 일시정지 경고 동결"): return
			paused = false
			actor.set_process(false)
			ultimate.finish_stage_effect()
			if not _assert_equal(actor.enemy_time_scale(), 1.0, "감속 종료는 원래 시간 복원"): return
			sandbox._suspend_combat_environment()
			for ignored in 4: await process_frame
			if not _assert_true(not actor.visible and actor._state_elapsed_s == elapsed, "마을 환경은 병정/포탑 숨김·동결"): return
			sandbox._restore_combat_environment()
			actor.receive_damage(_damage_event(&"gp252:dead", 999, player.position, ["test"]))
			actor._process(2)
			if not _assert_true(actor.state == PrototypeEnemy.State.DEAD and actor.attack_count == 0 and not actor.warning_line.visible and get_nodes_in_group("enemy_projectile").is_empty(), "사망 후 준비 공격 취소"): return
		_:
			_assert_true(false, "잘못된 검사 단계")
			return
	actor.configure_route("meadow")
	actor.reset_target()
	if not _assert_true(not actor.festival_variant and actor.body_sprite.texture == actor._original_body_texture, "기존 경로 패턴·원래 시각 복귀"): return
	paused = false
	sandbox.free()
	print("GP-250–252 runtime test: OK (%s %.0f)" % [phase, facing])
	quit(0)
