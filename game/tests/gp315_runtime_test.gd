extends "res://tests/gp314_runtime_test.gd"

func _run() -> void:
	auto_guardian_choice = false
	legacy_final_boss_for_tests = false
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var character := args[1]
	var weapon := args[2]
	var choice := "rescue" if character == "roan" else "destroy"
	var continuing := phase in ["resume", "defeated", "finish"]
	var prefix := "user://gp315_%s_%s_%s" % ["flow" if phase == "seed" or continuing else phase, character, weapon]
	store.save_path = prefix + "_checkpoint.json"
	legacy.save_path = prefix + "_meta.jsonl"
	journal.save_path = prefix + "_story.jsonl"
	if not continuing:
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
			if not _prepare_sera(character, weapon, choice): return
			player.damage_receiver.health = 83
			festival_ultimate.gauge = 37
			weapons.sword_combat._skill_1_cooldown_s = 3.25
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK and store.load_checkpoint().stage.final_boss == SeraEncounter.ID and store.load_checkpoint().stage.number == 9 and controls.stage_route_options[0].lines[1].contains("세라"), "새 전체 여정은 세라·성문 완료 저장·다음 경로 안내"): return
		"resume":
			if not _restore_journey(9) or not _check(player.damage_receiver.health == 83 and festival_ultimate.gauge == 37 and weapons.sword_combat._skill_1_cooldown_s == 3.25 and runner.final_boss_id == SeraEncounter.ID, "별도 프로세스에서 새 보스 종류·잔량 복원"): return
			if not _enter_sera() or not _intro_input(weapon == "bow"): return
			if not await _sera_basic_clear(weapon): return
			if not _check(controls.current_screen_mode() == 18 and controls.story_scene.name == "돌아온 친구의 이름" and store.load_checkpoint().stage.history[-1].final_boss == SeraEncounter.ID and store.load_checkpoint().story.pending == "stage:10", "실제 세라 격파→기억 회복 이야기·버전1 선택 대기 저장"): return
		"defeated":
			if not _restore_journey(10) or not _check(controls.story_scene.name == "돌아온 친구의 이름" and controls.story_scene.lines[1].contains(PrototypeCharacters.display_name(character)) and not runner.sera.is_targetable() and not sandbox._resolve_boss_choice(choice), "처치 재실행은 재전투 없이 실제 주인공 기억 회복·선택 우회 차단"): return
			if not _ack_scene(weapon == "bow") or not _check(controls.current_screen_mode() == 12 and controls.boss_choice_profile == SeraEncounter.PROFILE and journal.snapshot().fragments.size() == 9, "장면 확인·건너뛰기 뒤 세라 전용 선택·기억9종"): return
		"finish":
			if not _restore_journey(10) or not _check(controls.current_screen_mode() == 12 and controls.boss_choice_profile == SeraEncounter.PROFILE, "확인 뒤 반복 복원은 세라 전용 선택"): return
			var old_progress := legacy.progress_snapshot()
			if not _choose_sera(choice): return
			var result: Dictionary = controls.current_result_snapshot()
			var recent: Dictionary = recorder.summary_snapshot().recent_runs[0]
			if not _check(result.boss_name == BossSera.BOSS_NAME and result.final_boss == SeraEncounter.ID and result.boss_choice == choice and recent.final_boss == SeraEncounter.ID and recent.boss_choice == choice and journal.snapshot().chronicles.has("sera_" + choice) and legacy.progress_snapshot().guardian_companion == old_progress.guardian_companion and legacy.progress_snapshot().unlocked == old_progress.unlocked and legacy.progress_snapshot().sera_choices.get(choice, false) and legacy.pending_reward().is_empty() and store.load_checkpoint().is_empty() and recorder.summary_snapshot().completed_run_count == 1, "결과·광장 이력·세라 여행 기록·단일 완주·태엽 기사 보상 독립"): return
			controls.show_main_screen()
			controls.show_village()
			controls.village_page = "history"
			if not _check(controls.village_snapshot().cards[0].lines[2].contains("세라 " + GuardianDecision.label(choice)), "실제 광장 최근 이력에 세라 선택"): return
		"patterns-dash", "patterns-wave", "patterns-ring":
			if not _prepare_sera(character, weapon, choice) or not _enter_sera() or not _intro_input(true): return
			if not await _sera_patterns(phase, weapon): return
		"fault-choice", "fault-story", "fault-record":
			if not _prepare_sera(character, weapon, choice) or not _enter_sera() or not _intro_input(true) or not _finish_stage(): return
			var saved := store.load_checkpoint()
			var checkpoint_path := store.save_path
			var story_path := journal.save_path
			if phase == "fault-story":
				journal.save_path = "user://gp315_missing/story.jsonl"
				if not _check(not sandbox._acknowledge_story("stage:10") and sandbox.story_run.pending == "stage:10" and paused, "세라 기억 쓰기 실패는 장면 유지"): return
				journal.save_path = story_path
				if not _check(store.load_checkpoint() == saved and _ack_scene(true), "정상 체크포인트 보존·기억 재시도"): return
			elif not _ack_scene(true): return
			if phase == "fault-choice":
				saved = store.load_checkpoint()
				store.save_path = "user://gp315_missing/checkpoint.json"
				if not _check(not sandbox._resolve_boss_choice(choice) and runner.boss_choice.is_empty() and controls.current_screen_mode() == 12, "선택 저장 실패 시 세라 선택 되돌림"): return
				store.save_path = checkpoint_path
				if not _check(store.load_checkpoint() == saved, "실패 전 정상 선택 대기 저장 보존"): return
			if phase == "fault-record": journal.save_path = "user://gp315_missing/story.jsonl"
			if not _choose_sera(choice): return
			if phase == "fault-record":
				if not _check(not store.load_checkpoint().is_empty() and store.load_checkpoint().stage.boss_choice == choice, "여행 기록 실패는 확정 선택 저장 유지"): return
				journal.save_path = story_path
				sandbox._refresh_checkpoint()
			if not _check(store.load_checkpoint().is_empty() and recorder.summary_snapshot().completed_run_count == 1 and journal.snapshot().chronicles.has("sera_" + choice) and legacy.pending_reward().is_empty(), "실패 재시도는 세라 기록 한 번·기존 기사 보상 미지급"): return
		"legacy-gate", "legacy-final", "legacy-standard":
			legacy_final_boss_for_tests = true
			if phase == "legacy-standard":
				controls.begin_retry(weapon, 3)
				while runner.stage_number < 3:
					if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
					_tap(controls.stage_route_rects[0].get_center())
				if not _reach_journey_elite() or not _check(not runner.uses_sera() and runner.final_enemy() == runner.boss and not runner.sera.visible, "일반3단계는 기존 태엽 기사·세라 숨김"): return
			else:
				if not _prepare_sera(character, weapon, choice): return
				if phase == "legacy-final" and (not _next_without_layout() or not _finish_stage()): return
				var old := store.load_checkpoint()
				old.stage.erase("final_boss")
				for entry in old.stage.history: entry.erase("final_boss")
				if not _check(store.save_checkpoint(old) == OK and RunCheckpointStore.valid_state(old), "이전 필드 없는 버전1 저장 허용"): return
				if not _restore_journey(10 if phase == "legacy-final" else 9) or not _check(runner.final_boss_id == SeraEncounter.LEGACY and not runner.sera.visible, "이전 저장의 최종 보스 정체 유지"): return
				if phase == "legacy-gate":
					if not _next_without_layout() or not _finish_stage(): return
				if not _ack_scene(true) or not _check(controls.boss_choice_profile.is_empty(), "이전 완료 저장은 기존 재회·기사 선택"): return
				if not sandbox._resolve_boss_choice("rescue") or not _check(legacy.pending_reward().choice == "rescue", "이전 태엽 기사 보상 정상 지급"): return
		"flows", "story-off":
			if not _prepare_sera(character, weapon, choice): return
			if phase == "story-off":
				sandbox.story_run.restore({})
				if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "이야기 꺼짐 완료 저장"): return
			if not _enter_sera(phase != "story-off"): return
			if phase == "story-off":
				if not _check(not paused and controls.current_screen_mode() == 0 and runner.uses_sera(), "이야기 꺼짐도 세라 실제 전투·재회 생략"): return
				if not _finish_stage() or not _check(controls.current_screen_mode() == 12 and controls.boss_choice_profile == SeraEncounter.PROFILE, "이야기 꺼짐도 세라 선택"): return
			else:
				var elapsed := runner.stage_elapsed_s
				runner.sera.set_process(true)
				for ignored in 4: await physics_frame
				runner.sera.set_process(false)
				if not _check(paused and runner.sera.attack_count == 0 and runner.stage_elapsed_s == elapsed, "재회 중 전투·시간 정지"): return
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and runner.stage_number == 9 and not runner.sera.visible, "전투 전 종료는 마지막 성문 완료 저장"): return
				if not _enter_sera() or not _intro_input(false): return
				controls.open_run_build()
				if not _check(paused and not sandbox._sera_intro_active, "전투 조회는 별도 정지·재회 재진입 없음"): return
				controls.close_run_build()
				controls.advance_mode_timer_for_test(3.1)
				if not _check(not paused and controls.current_screen_mode() == 0 and runner.sera.damage_receiver.health == 960, "조회 복귀 후 세라 전투 유지"): return
		"validation":
			if not _prepare_sera(character, weapon, choice) or not _validate_identity(): return
		"layout":
			if not _prepare_sera(character, weapon, choice) or not _enter_sera(): return
			if not await _sera_layout(args): return
		_:
			_check(false, "알 수 없는 세라 검사")
			return
	paused = false
	sandbox.free()
	print("GP-315 runtime test: OK (%s %s %s)" % [phase, character, weapon])
	quit(0)

func _prepare_sera(character: String, weapon: String, choice: String) -> bool:
	if not _prepare_guardian_choice(character, weapon) or not _ack_scene(true) or not _select_choice(choice) or not sandbox._claim_weapon_reward(""): return false
	return _check(runner.stage_number == 9 and runner.final_boss_id == (SeraEncounter.LEGACY if legacy_final_boss_for_tests else SeraEncounter.ID), "전체 여정 준비·명시적 이전/새 보스 구분")

func _enter_sera(expect_intro: bool = true) -> bool:
	if not _next_without_layout() or not _reach_journey_elite(): return false
	return _check(runner.final_enemy() == runner.sera and runner.sera.visible and runner.sera.damage_receiver.max_health == 960 and not runner.boss.visible and not runner.guardian.visible and sandbox._sera_intro_active == expect_intro and controls.current_screen_mode() == (18 if expect_intro else 0) and runner.current_metrics().boss_name == BossSera.BOSS_NAME, "실제 세라 교체·체력·다른 보스 숨김·재회 진입·HUD 이름")

func _intro_input(skip: bool) -> bool:
	if not _check(controls.current_screen_mode() == 18 and controls.story_scene.id == "sera_intro" and sandbox._sera_intro_active, "실제 재회 화면"): return false
	var saved := store.load_checkpoint()
	var layout := PrototypeStoryView.scene_layout(controls._safe_area_in_viewport())
	for ignored in 4:
		if controls.current_screen_mode() != 18: break
		_tap((layout.skip if skip else layout.next).get_center())
	return _check(not paused and controls.current_screen_mode() == 0 and not sandbox._sera_intro_active and store.load_checkpoint() == saved and not journal.snapshot().fragments.has("queen_pendant"), "실제 읽기/건너뛰기 뒤 전투·완료 전 기억 미지급·저장 불변")

func _choose_sera(choice: String) -> bool:
	var saved := store.load_checkpoint()
	_tap(controls.boss_choice_rects[0 if choice == "rescue" else 1].get_center())
	if not _check(store.load_checkpoint() == saved, "세라 선택 비교는 저장 불변"): return false
	_tap(controls.boss_choice_confirm_rect.get_center())
	return _check(runner.boss_choice == choice and controls.current_screen_mode() == 1, "실제 세라 확정 입력·도전 결과")

func _sera_basic_clear(weapon: String) -> bool:
	var queen := runner.sera
	queen.set_process(false)
	player.prepare_next_stage(Vector2(queen.position.x - 100, 780))
	var camera := player.get_node("Camera2D") as Camera2D
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	for ignored in 2: await process_frame
	var selector := player.get_node("AutoTargetSelector") as AutoTargetSelector
	selector.force_scan()
	for attack in 110:
		if not queen.is_targetable(): break
		if weapon == "sword":
			weapons.sword_combat._basic_remaining_s = 0
			weapons.sword_combat._update_basic_attack(0.1)
		else:
			var before := queen.damage_receiver.health
			weapons.bow_combat._basic_remaining_s = 0
			weapons.bow_combat._update_basic_attack()
			for ignored in 30:
				await physics_frame
				if queen.damage_receiver.health < before: break
		if not _resolve_growth(): return false
	if not _check(queen.damage_receiver.dead and queen.last_defeat_in_combat and queen.state == EliteArmoredBoar.State.DEAD and queen.phase == 2, "실제 검/활 기본 공격·2페이즈 경유 세라 격파"): return false
	runner._process(0.1)
	return _check(runner.stage_complete, "세라 실제 처치 뒤 중심부 완료")

func _sera_patterns(phase: String, weapon: String) -> bool:
	var queen := runner.sera
	queen.set_process(false)
	player.apply_growth_health(700, 700)
	player.prepare_next_stage(Vector2(4100, 780))
	player.damage_receiver.barrier_health = 0
	player.guardian_choice = ""
	if phase == "patterns-dash":
		queen._begin_next_pattern()
		var direction := queen._charge_direction
		player.position.x = 4800
		queen._process(0.86)
		var start := queen.position.x
		queen._process(0.10)
		if not _check(queen.position.x < start and direction == -1 and queen.state == EliteArmoredBoar.State.CHARGING, "돌진 경고 방향 고정·플레이어 방향 변경 무관"): return false
		queen.position.x = BossSera.ARENA_LEFT_X + 1
		queen._process(0.1)
		if not _check(queen.position.x == BossSera.ARENA_LEFT_X and queen.state == EliteArmoredBoar.State.RECOVERY, "평지 경계에서 멈추고 왕관 빈틈·낙하 진입 없음"): return false
		if not _sera_hit(40, weapon, 50): return false
		queen._set_state(EliteArmoredBoar.State.IDLE, "검사")
		if not _sera_hit(40, weapon, 40): return false
		queen.reset_target()
		queen.position = Vector2(4700, 780)
		player.position = Vector2(4870, 780)
		queen._begin_next_pattern()
		queen._process(0.86)
		queen._process(0.1)
		if not _check(queen._charge_direction == 1 and queen.position.x > 4700 and queen.position.x <= BossSera.ARENA_RIGHT_X, "오른쪽 돌진도 경고 방향·평지 범위 보존"): return false
		queen.reset_target()
		queen.position = Vector2(4400, 780)
		player.prepare_next_stage(Vector2(4400, 780))
		player.invincible = true
		festival_ultimate.gauge = 0
		queen._begin_next_pattern()
		queen._process(0.86)
		var health := player.damage_receiver.health
		queen._process(0.001)
		var gauge := festival_ultimate.gauge
		queen._process(0.001)
		if not _check(gauge > 0 and festival_ultimate.gauge == gauge and player.damage_receiver.health == health, "돌진 정확 회피·게이지 한 번·피해 없음"): return false
	elif phase == "patterns-wave":
		queen.last_pattern = EliteArmoredBoar.Pattern.CHARGE
		queen._begin_next_pattern()
		queen._process(1.01)
		var waves := get_nodes_in_group("enemy_projectile")
		if not _check(waves.size() == 2 and waves[0].attacker_id == &"sera" and waves[0].attack_id == &"sera_smile_wave", "1페이즈 양방향 파문·세라 공격 식별"): return false
		for wave in waves: wave.set_physics_process(false)
		var point := player.position + Vector2(0, -20)
		var health := player.damage_receiver.health
		waves[0]._try_hit_player(point - Vector2(20, 0), point + Vector2(20, 0))
		if not _check(player.damage_receiver.health == health - 12, "실제 지면 파문 충돌 피해"): return false
		for wave in waves: wave.free()
		queen.damage_receiver.health = 501
		if not _sera_hit(25, "sword", 25): return false
		if not _check(queen.phase == 2 and queen.body_sprite.texture == BossSera.AWAKENED_TEXTURE and queen.state == EliteArmoredBoar.State.PHASE_TRANSITION, "체력50% 전환·고정 미소 사라짐"): return false
		queen._process(0.76)
		queen.last_pattern = EliteArmoredBoar.Pattern.CHARGE
		queen._begin_next_pattern()
		queen._process(0.71)
		queen._process(0.23)
		if not _check(get_nodes_in_group("enemy_projectile").size() == 4, "2페이즈 양방향 추가 파문"): return false
	else:
		queen.last_pattern = EliteArmoredBoar.Pattern.SHOCKWAVE
		queen._begin_next_pattern()
		queen.set_enemy_time_scale(0)
		queen._process(2.0)
		if not _check(queen._state_elapsed_s == 0 and queen.ring_count == 0, "정지 중 빛살 경고·발사 정지"): return false
		queen.set_enemy_time_scale(0.5)
		queen._process(2.0)
		if not _check(queen.state == EliteArmoredBoar.State.WARNING and queen._state_elapsed_s == 1, "감속0.5배 빛살 예고"): return false
		queen.set_enemy_time_scale(1)
		queen._process(0.11)
		var shots := get_nodes_in_group("enemy_projectile")
		if not _check(shots.size() == 8 and shots[0].attacker_id == &"sera" and shots[0].projectile_sprite.texture == BossSera.SPARK_TEXTURE and queen.state == EliteArmoredBoar.State.RECOVERY, "실제8방향 빛살·전용 외형·공격 후 빈틈"): return false
		for shot in shots: shot.set_physics_process(false)
		var point := player.position + Vector2(0, -42)
		var health := player.damage_receiver.health
		shots[0]._try_hit_player(point - Vector2(20, 0), point + Vector2(20, 0))
		if not _check(player.damage_receiver.health == health - 8, "빛살 실제 선분 충돌 피해"): return false
		for shot in shots: shot.free()
		queen.phase = 2
		queen.last_pattern = EliteArmoredBoar.Pattern.SHOCKWAVE
		queen._begin_next_pattern()
		queen._process(0.81)
		if not _check(queen.ring_count == 2 and queen._ring_second_pending, "2페이즈 첫 빛살과 지연 예고"): return false
		queen.set_enemy_time_scale(0)
		queen._process(2)
		if not _check(queen.ring_count == 2, "정지는 지연 빛살도 보존"): return false
		queen.set_enemy_time_scale(1)
		queen._process(0.29)
		shots = get_nodes_in_group("enemy_projectile")
		if not _check(queen.ring_count == 3 and shots.size() == 16 and not shots[0].direction.is_equal_approx(shots[8].direction), "2페이즈 엇갈린 두 번째8방향 빛살"): return false
		queen._ring_second_pending = true
		queen._ring_follow_up_s = 0.28
		var event := DamageEvent.new()
		event.event_id = &"sera:finish:ring"
		event.damage = 9999
		queen.receive_damage(event)
		var count := queen.ring_count
		queen._process(1)
		if not _check(not queen._ring_second_pending and queen.ring_count == count, "세라 사망은 지연 공격 취소"): return false
	return true

func _sera_hit(amount: int, tag: String, expected: int) -> bool:
	var event := DamageEvent.new()
	event.event_id = StringName("sera:test:%d" % Time.get_ticks_usec())
	event.damage = amount
	event.tags = PackedStringArray([tag])
	var health := runner.sera.damage_receiver.health
	return _check(runner.sera.receive_damage(event) == DamageReceiver.Result.APPLIED and runner.sera.damage_receiver.health == health - expected and event.damage == amount, "검/활 왕관 빈틈 배율·원본 피해 보존")

func _validate_identity() -> bool:
	var saved := store.load_checkpoint()
	var raw := FileAccess.get_file_as_string(store.save_path)
	for value in [null, true, 10, "unknown", ""]:
		var bad := saved.duplicate(true)
		bad.stage.final_boss = value
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and FileAccess.get_file_as_string(store.save_path) == raw, "잘못된 최종 보스 타입/ID 거부·정상 파일 보존"): return false
	var bad := saved.duplicate(true)
	bad.stage.history[0].final_boss = SeraEncounter.ID
	if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA, "이전 스테이지 이력의 최종 보스 변조 거부"): return false
	if not _enter_sera() or not _intro_input(true) or not _finish_stage(): return false
	saved = store.load_checkpoint()
	bad = saved.duplicate(true)
	bad.stage.history[-1].final_boss = SeraEncounter.LEGACY
	return _check(not RunCheckpointStore.valid_state(bad) and RunCheckpointStore.valid_state(saved), "세라 완료 이력/보스 불일치 거부")

func _sera_layout(args: PackedStringArray) -> bool:
	for dimensions in [Vector2(1280, 720), Vector2(1600, 720)]:
		root.content_scale_size = Vector2i(dimensions)
		root.size = Vector2i(dimensions)
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(Vector2i(dimensions))
		controls.size = dimensions
		controls.show_story(SeraEncounter.intro(player.character_id, runner.guardian_choice, []))
		for page in 3:
			controls.story_page = page
			controls.queue_redraw()
			await process_frame
			var layout := PrototypeStoryView.scene_layout(controls._safe_area_in_viewport())
			for i in 2:
				if not _check(PrototypeStoryView.wrap(controls.story_scene.lines[page * 2 + i], ThemeDB.fallback_font, 22, layout.paragraphs[i].size.x).size() * 28 <= layout.paragraphs[i].size.y, "두 화면비 재회 한글 본문 높이"): return false
			if args.size() > 3 and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(args[3] + "/gp315-%d-intro%d.png" % [int(dimensions.x), page])
		controls.show_boss_choice(SeraEncounter.PROFILE)
		var safe: Rect2 = controls._safe_area_in_viewport()
		if not _check(controls.boss_choice_rects.all(func(rect: Rect2) -> bool: return safe.encloses(rect)) and safe.encloses(controls.boss_choice_confirm_rect), "두 화면비 세라 선택 안전 영역"): return false
		controls.queue_redraw()
		await process_frame
		if args.size() > 3 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(args[3] + "/gp315-%d-choice.png" % int(dimensions.x))
	return true

func _check(condition: bool, label: String) -> bool:
	if condition: return true
	push_error("GP-315 실패: " + label)
	paused = false
	quit(1)
	return false
