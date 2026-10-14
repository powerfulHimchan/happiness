extends "res://tests/gp309_runtime_test.gd"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var character := args[1]
	var weapon := args[2]
	var prefix := "user://gp311_%s_%s_%s" % ["flow" if phase in ["seed", "resume", "finish"] else phase, character, weapon]
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
			if not _start_gate(character, weapon) or not _restore_journey(8): return
			player.damage_receiver.health = 83
			festival_ultimate.gauge = 37
			weapons.sword_combat._skill_1_cooldown_s = 3.25
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK and RunCheckpointStore.valid_state(store.load_checkpoint()), "이전 버전1·8스테이지 저장"): return
		"resume":
			if not _restore_journey(8) or not _check(player.damage_receiver.health == 83 and festival_ultimate.gauge == 37 and weapons.sword_combat._skill_1_cooldown_s == 3.25, "별도 프로세스 잔량·기술 복원"): return
			if not _next_without_layout() or not _reach_guardian() or not await _guardian_combat_clear(weapon): return
			if not _check(runner.stage_number == 9 and runner.stage_complete and not runner.awaiting_boss_choice() and not runner.reward_claimed and store.load_checkpoint().story.pending == "stage:9", "수호기사 처치→완료 이야기→기존 보상 대기 저장"): return
			player.damage_receiver.health = 83
			festival_ultimate.gauge = 37
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK and JSON.parse_string(FileAccess.get_file_as_string(store.save_path)).version == 1, "성문 완료 저장·버전 호환"): return
		"finish":
			if not _restore_journey(9) or not _check(not runner.guardian.visible and not runner.guardian.is_targetable() and player.damage_receiver.health == 83 and festival_ultimate.gauge == 37, "완료 재실행은 수호기사 재전투 없이 잔량 복원"): return
			if not _check(controls.story_scene.lines[-1].contains("수호기사") and _ack_scene(true), "수호기사 완료 이야기 확인"): return
			var before := store.load_checkpoint()
			var path := store.save_path
			store.save_path = "user://gp311_missing/checkpoint.json"
			if not _check(not sandbox._claim_weapon_reward(weapon) and not runner.reward_claimed, "보상 저장 실패 되돌림"): return
			store.save_path = path
			if not _check(store.load_checkpoint() == before and sandbox._claim_weapon_reward(weapon), "정상 저장 보존·보상 재시도"): return
			if not _restore_journey(9) or not _next_without_layout(): return
			if not _check(runner.stage_number == 10 and runner.final_enemy() == runner.boss and not runner.guardian.visible and festival_terrain.platforms == CityCoreLayout.PLATFORMS, "수호기사 재등장 없이 중심부·태엽 기사 전환"): return
			if not _finish_stage() or not _ack_scene(true) or not sandbox._resolve_boss_choice("rescue" if weapon == "sword" else "destroy"): return
			if not _check(recorder.summary_snapshot().completed_run_count == 1 and store.load_checkpoint().is_empty(), "기존 마지막 선택·10스테이지 완주·단일 기록"): return
		"combat":
			if not _start_gate(character, weapon) or not _reach_guardian() or not await _guardian_patterns(weapon): return
		"flows":
			if not _start_gate(character, weapon) or not _reach_guardian(): return
			var guard := runner.guardian
			guard.set_process(true)
			guard._begin_next_pattern()
			var before := [guard.state, guard._state_elapsed_s, guard.position, guard.damage_receiver.health]
			var saved := store.load_checkpoint()
			controls.open_run_build()
			for ignored in 5: await process_frame
			if not _check(paused and [guard.state, guard._state_elapsed_s, guard.position, guard.damage_receiver.health] == before and store.load_checkpoint() == saved, "조회 중 전투 정지·저장 불변"): return
			controls.close_run_build()
			controls.advance_mode_timer_for_test(3.1)
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and runner.stage_number == 8 and not guard.visible, "성문 전투 중 종료는 마지막 완료 지점8 복원"): return
			if not _next_without_layout() or not _reach_guardian(): return
			if not _check(guard.phase == 1 and guard.lance_count == 0 and guard.damage_receiver.health == 720, "재도전은 패턴·체력 초기화"): return
		"regress":
			if not _start_gate(character, weapon) or not _reach_guardian(): return
			for count in [3, 5]:
				controls.begin_retry(weapon, count)
				if not _check(not runner.guardian.visible and not runner.uses_guardian() and runner.final_enemy() == runner.armored_boar, "일반 도전에는 수호기사 미등장"): return
				while runner.stage_number < count:
					if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
					_tap(controls.stage_route_rects[0].get_center())
				if not _reach_journey_elite(): return
				if not _check(runner.final_enemy() == runner.boss and runner.boss.damage_receiver.max_health == (480 if count == 3 else 720), "기존3/5 최종 태엽 기사 체력·선택 유지"): return
			controls.begin_retry(weapon, 5, "regions", character)
			if not _check(not runner.guardian.visible and not runner.uses_guardian(), "지역 순회에 수호기사 미등장"): return
			runner.set_stage_enabled(false)
			if not _check(not runner.guardian.visible and not runner.boss.visible and runner.armored_boar.visible, "자유 전투는 기존 정예만 표시"): return
		_:
			_check(false, "알 수 없는 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-311 runtime test: OK (%s %s %s)" % [phase, character, weapon])
	quit(0)

func _reach_guardian() -> bool:
	if not _reach_journey_elite(): return false
	runner.guardian.set_process(false)
	if not _check(runner.uses_guardian() and not runner.uses_boss() and runner.final_enemy() == runner.guardian and runner._active_enemies == [runner.guardian] and runner.guardian.visible and not runner.armored_boar.visible and not runner.boss.visible, "성문만720체력 수호기사 등장·다른 정예 제외"): return false
	if not _check(runner.guardian.damage_receiver.health == 720 and runner.current_metrics().boss_name == BossHappinessGuardian.BOSS_NAME and runner.current_metrics().stage_section_name == "보스 · 행복의 수호기사" and runner.current_metrics().stage_objective.contains("빛의 창"), "보스 이름·경고·HUD 안내"): return false
	sandbox._emit_enemy_metrics()
	return _check(controls.movement_metrics.elite_max_health == 720 and controls.movement_metrics.elite_state == "대기", "비활성 태엽 기사가 수호기사 HUD를 덮지 않음")

func _guardian_patterns(weapon: String) -> bool:
	var guard := runner.guardian
	for direction in [-1, 1]:
		guard.reset_target()
		player.prepare_next_stage(Vector2(guard.position.x + direction * 100, 780))
		player.damage_receiver.tick(1.0)
		guard._begin_next_pattern()
		if not _check(guard._charge_direction == direction and guard.body_sprite.flip_h == (direction > 0) and guard.warning_feedback_snapshot().shape == "직선", "좌우 경고 방향과 외형 일치"): return false
		var origin := player.position
		if not _guardian_hit(40, "sword", origin, 26) or not _guardian_hit(40, "bow", origin, 32): return false
		if not _guardian_hit(40, "sword", guard.position - Vector2(direction * 100, 0), 40): return false
		guard._process(0.89)
		if not _check(guard.state == EliteArmoredBoar.State.WARNING, "돌진 예고0.9초 이전에는 공격 없음"): return false
		guard._process(0.02)
		player.position.x = guard.position.x + direction * 15
		var health := player.damage_receiver.health
		guard._process(0.01)
		guard._process(0.01)
		if not _check(player.damage_receiver.health == health - 18 and guard.hit_count == 1 and player.damage_receiver.last_event_id.begins_with("행복의 수호기사:"), "좌우 돌진 실제18피해·타격당1회·수호기사 식별"): return false
		player.position.x = 3000
		guard.position.x = BossHappinessGuardian.ARENA_LEFT_X + 1 if direction < 0 else BossHappinessGuardian.ARENA_RIGHT_X - 1
		guard._process(0.01)
		if not _check(guard.state == EliteArmoredBoar.State.STUNNED and guard.position.x == (3920 if direction < 0 else 4880), "양쪽 평지 경계 충돌·낙하 방지·빈틈"): return false
		if not _guardian_hit(40, "sword", origin, 60) or not _guardian_hit(40, "bow", origin, 60): return false
		guard._begin_recovery("검사")
		if not _guardian_hit(40, "sword", origin, 50) or not _guardian_hit(40, "bow", origin, 50): return false
	guard.reset_target()
	player.prepare_next_stage(Vector2(4350, 780))
	player.facing_direction = 1
	var camera := player.get_node("Camera2D") as Camera2D
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	for ignored in 2: await process_frame
	var selector := player.get_node("AutoTargetSelector") as AutoTargetSelector
	selector.force_scan()
	if not _check(selector.current_target == guard, "실제 자동 공격이 수호기사 표적 선택"): return false
	var previous := guard.damage_receiver.health
	if weapon == "sword":
		weapons.sword_combat._basic_remaining_s = 0
		weapons.sword_combat._update_basic_attack(0.1)
	else:
		weapons.bow_combat._basic_remaining_s = 0
		weapons.bow_combat._update_basic_attack()
		for ignored in 40:
			await physics_frame
			if guard.damage_receiver.health < previous: break
	if not _check(guard.damage_receiver.health < previous and guard.last_damage_multiplier == 1.0, "실제 검 타격/활 화살 충돌·대기 중 정상 피해"): return false
	guard.reset_target()
	player.prepare_next_stage(Vector2(4350, 780))
	guard._begin_next_pattern()
	guard._process(0.91)
	player.position.x = guard.position.x - 15
	player.invincible = true
	festival_ultimate.gauge = 0
	var health := player.damage_receiver.health
	guard._process(0.01)
	var gauge := festival_ultimate.gauge
	guard._process(0.01)
	if not _check(player.damage_receiver.health == health and gauge > 0 and festival_ultimate.gauge == gauge, "돌진 정확 회피·게이지1회·피해 없음"): return false
	player.invincible = false
	player.damage_receiver.tick(1.0)
	guard.last_pattern = EliteArmoredBoar.Pattern.CHARGE
	guard._begin_next_pattern()
	guard._process(1.01)
	var waves := get_nodes_in_group("enemy_projectile")
	if not _check(waves.size() == 2 and waves[0].attacker_id == &"happiness_guardian" and waves[0].attack_id == &"guardian_shockwave", "실제 충격파2개·공격 식별 분리"): return false
	for wave in waves: wave.set_physics_process(false)
	var point := player.position + Vector2(0, -20)
	health = player.damage_receiver.health
	waves[0]._try_hit_player(point - Vector2(20, 0), point + Vector2(20, 0))
	player.prepare_next_stage(player.position)
	player.damage_receiver.tick(1.0)
	waves[0]._try_hit_player(point - Vector2(20, 0), point + Vector2(20, 0))
	if not _check(player.damage_receiver.health == health - 12 and player.damage_receiver.last_result == DamageReceiver.Result.DUPLICATE_BLOCKED, "실제 충격파 충돌12피해·중복 차단"): return false
	for wave in waves: wave.free()
	guard._begin_recovery("검사")
	guard._begin_next_pattern()
	var aim := guard._lance_aim
	guard.set_enemy_time_scale(0)
	guard._process(2.0)
	if not _check(guard.state == EliteArmoredBoar.State.WARNING and guard._state_elapsed_s == 0 and guard.lance_count == 0, "시간 정지 중 창 경고·공격 모두 정지"): return false
	guard.set_enemy_time_scale(0.5)
	guard._process(2.0)
	if not _check(guard.state == EliteArmoredBoar.State.WARNING and guard._state_elapsed_s == 1.0, "시간 감속0.5배 예고"): return false
	guard.set_enemy_time_scale(1)
	player.position.y -= 200
	guard._process(0.11)
	var shots := _guardian_shots()
	if not _check(shots.size() == 1 and shots[0].direction.is_equal_approx(aim) and shots[0].projectile_sprite.texture == BossHappinessGuardian.LANCE_TEXTURE and guard.state == EliteArmoredBoar.State.RECOVERY, "1페이즈 실제 창1개·경고 방향 고정·전용 외형·공격 후 빈틈"): return false
	for shot in shots: shot.set_physics_process(false)
	player.damage_receiver.tick(1.0)
	player.prepare_next_stage(player.position)
	point = player.position + Vector2(0, -42)
	health = player.damage_receiver.health
	shots[0]._try_hit_player(point - Vector2(20, 0), point + Vector2(20, 0))
	if not _check(player.damage_receiver.health == health - 11, "실제 빛의 창 충돌11피해"): return false
	for shot in shots: shot.free()
	guard.reset_target()
	if not _guardian_hit(360, "test", player.position, 360) or not _check(guard.phase == 2 and guard.state == EliteArmoredBoar.State.PHASE_TRANSITION, "720체력50%에서2페이즈"): return false
	guard._process(0.75)
	guard.last_pattern = EliteArmoredBoar.Pattern.CHARGE
	guard._begin_next_pattern()
	guard._process(0.71)
	guard._process(0.23)
	waves = get_nodes_in_group("enemy_projectile")
	if not _check(waves.size() == 4 and waves[0].damage == 14, "2페이즈 실제 연속 충격파4개·14피해"): return false
	for wave in waves: wave.free()
	guard.last_pattern = EliteArmoredBoar.Pattern.SHOCKWAVE
	guard._begin_next_pattern()
	guard._process(0.79)
	if not _check(guard.warning_line.points.size() == 6 and guard.lance_count == 0, "2페이즈 창3궤적 경고·0.8초 이전 공격 없음"): return false
	guard._process(0.02)
	shots = _guardian_shots()
	if not _check(shots.size() == 3 and shots[0].damage == 14 and guard.pattern_history[-1] == BossHappinessGuardian.LANCE_PATTERN, "2페이즈 창3개·14피해·패턴 순환"): return false
	for shot in shots: shot.free()
	guard.reset_target()
	return _check(guard.phase == 1 and guard.pattern_history.is_empty() and guard.lance_count == 0 and guard.damage_receiver.health == 720, "보스 재시작은 모든 패턴 초기화")

func _guardian_combat_clear(weapon: String) -> bool:
	var guard := runner.guardian
	player.prepare_next_stage(Vector2(guard.position.x - 100, 780))
	var camera := player.get_node("Camera2D") as Camera2D
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	for ignored in 2: await process_frame
	var selector := player.get_node("AutoTargetSelector") as AutoTargetSelector
	selector.force_scan()
	for attack in 100:
		if not guard.is_targetable(): break
		if weapon == "sword":
			weapons.sword_combat._basic_remaining_s = 0
			weapons.sword_combat._update_basic_attack(0.1)
		else:
			var before := guard.damage_receiver.health
			weapons.bow_combat._basic_remaining_s = 0
			weapons.bow_combat._update_basic_attack()
			for ignored in 30:
				await physics_frame
				if guard.damage_receiver.health < before: break
		if not _resolve_growth(): return false
	if not _check(guard.damage_receiver.dead and not guard.is_targetable() and guard.last_defeat_in_combat, "실제 검/활 기본 공격으로 수호기사 처치"): return false
	runner._process(0.1)
	return _check(runner.stage_complete, "실제 처치 신호로 성문 완료")

func _guardian_shots() -> Array:
	return get_nodes_in_group("enemy_projectile").filter(func(node: Node) -> bool: return node is EnemySeedProjectile and node.attack_id == &"guardian_lance")

func _guardian_hit(amount: int, tag: String, origin: Vector2, expected: int) -> bool:
	var guard := runner.guardian
	var event := DamageEvent.new()
	event.event_id = StringName("gp311:hit:%d:%d" % [guard.spawn_generation, guard.damage_receiver.health])
	event.attacker_id = &"player"
	event.damage = amount
	event.tags = PackedStringArray([tag])
	event.source_position = origin
	var health := guard.damage_receiver.health
	if not _check(guard.receive_damage(event) == DamageReceiver.Result.APPLIED and guard.receive_damage(event) == DamageReceiver.Result.DUPLICATE_BLOCKED and guard.damage_receiver.health == health - expected, "방패 정면/뒤쪽·공격 뒤/기절 약점·중복 차단"): return false
	return _check(event.damage == amount and event.source_position == origin, "공유 원본 피해 이벤트 보존")

func _check(condition: bool, label: String) -> bool:
	if condition: return true
	push_error("GP-311 실패: " + label)
	paused = false
	quit(1)
	return false
