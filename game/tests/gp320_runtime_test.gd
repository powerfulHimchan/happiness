extends "res://tests/gp319_runtime_test.gd"

func _run() -> void:
	heart_battle_for_tests = true
	auto_guardian_choice = false
	legacy_final_boss_for_tests = false
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var character := args[1]
	var weapon := args[2]
	var choice := args[3]
	legacy = FaultStore.new()
	var continuing := phase in ["resume", "defeated", "finish", "fault-resume"]
	var prefix := "user://gp320_%s_%s_%s_%s" % ["fault" if phase in ["fault-seed", "fault-resume"] else "flow" if phase == "seed" or continuing else phase, character, weapon, choice]
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
			if not _enter_heart(character, weapon, choice): return
		"resume", "defeated":
			if not _restore_battle() or not _active_heart(): return
			if phase == "resume":
				var saved := store.load_checkpoint()
				runner.heart.damage_receiver.health = 47
				controls.show_main_screen()
				if not sandbox.continue_saved_run() or not _check(runner.heart.damage_receiver.health == 1200 and saved == store.load_checkpoint(), "중간 종료는 전투 직전 저장으로 재도전·반쪽 보스 저장 없음"): return
			else:
				if not await _basic_clear(weapon) or not _victory_pending(): return
		"finish":
			controls.show_main_screen()
			if not sandbox.continue_saved_run() or not _victory_pending() or not _confirm_victory(weapon == "bow") or not _heart_recorded(choice): return
		"entry-fault", "truth-fault", "victory-fault", "journal-fault", "fault-seed":
			if not _prepare_battle(character, weapon, choice): return
			var saved := store.load_checkpoint()
			var path := store.save_path
			if phase == "truth-fault":
				journal.fail_writes = true
				if not _check(not sandbox._acknowledge_story(HeartThreshold.SCENE_ID) and runner.heart_battle == HeartEncounter.PENDING and not runner.heart.visible and store.load_checkpoint().stage.arrival_ending == ArrivalEnding.LOCKED, "진실 저널 실패는 전투 직전 확인 저장 보존·진입 보류"): return
				journal.fail_writes = false
				if not sandbox._acknowledge_story(HeartThreshold.SCENE_ID) or not _active_heart(): return
			elif phase == "entry-fault":
				store.save_path = "user://gp320_missing/entry.json"
				if not _check(not sandbox._acknowledge_story(HeartThreshold.SCENE_ID) and runner.heart_battle == HeartEncounter.AVAILABLE and not runner.heart.visible, "입구 저장 실패는 전투/상태 전이 차단"): return
				store.save_path = path
				if not _check(saved == store.load_checkpoint(), "입구 이전 정상 저장 보존"): return
				if not sandbox._acknowledge_story(HeartThreshold.SCENE_ID) or not _active_heart(): return
			else:
				if not sandbox._acknowledge_story(HeartThreshold.SCENE_ID): return
				if not await _basic_clear(weapon): return
				var before := store.load_checkpoint()
				if phase == "victory-fault": store.save_path = "user://gp320_missing/victory.json"
				else: journal.fail_writes = true
				if not _check(not sandbox._acknowledge_story(HeartEncounter.VICTORY_SCENE) and controls.current_screen_mode() == 18 and paused and growth.run_active and recorder.summary_snapshot().completed_run_count == 0 and not journal.snapshot().chronicles.has("heart_" + choice), "승리 확인/영구 기록 실패는 장면·미완료 유지"): return
				store.save_path = path
				if phase == "victory-fault":
					if not _check(before == store.load_checkpoint() and runner.heart_battle == HeartEncounter.DEFEATED, "확인 실패는 처치 저장과 상태 보존"): return
				else:
					if not _check(store.load_checkpoint().stage.heart_battle == HeartEncounter.SEEN, "영구 기록 실패에도 확인 저장 보존"): return
				if phase != "fault-seed":
					journal.fail_writes = false
					if not sandbox._acknowledge_story(HeartEncounter.VICTORY_SCENE) or not _heart_recorded(choice): return
		"fault-resume":
			if not _check(journal.snapshot().chronicles.has("heart_" + choice), "다음 실행에서 승리 영구 기록 복구"): return
			controls.show_main_screen()
			if not sandbox.continue_saved_run() or not _heart_recorded(choice): return
		"legacy", "first", "validate", "patterns", "layout", "death", "story-off", "reward-fault":
			if phase == "first":
				if not _pending_heart(character, weapon, choice) or not _check(runner.heart_battle == HeartEncounter.LOCKED, "첫 여정은 심장 전투 잠금"): return
				if not sandbox._acknowledge_story(HeartThreshold.SCENE_ID) or not _check(controls.story_scene.id == ArrivalEnding.SCENE_ID and not runner.heart.visible, "첫 도착 엔딩 흐름 보존"): return
			elif phase in ["story-off", "reward-fault"]:
				if journal.record_ending("prior-arrival", ArrivalEnding.ID, character, choice) != OK or not _prepare_sera(character, weapon, "rescue"): return
				sandbox.story_run.restore({})
				if not _enter_sera(false) or not _finish_stage(): return
				player.damage_receiver.health = 83
				festival_ultimate.gauge = 37
				weapons.sword_combat._skill_1_cooldown_s = 3.25
				legacy.fail_sera = phase == "reward-fault"
				if not sandbox._resolve_boss_choice(choice): return
				if phase == "reward-fault":
					if not _check(not runner.heart.visible and paused and controls.current_screen_mode() == 18 and not controls.story_message.is_empty() and store.load_checkpoint().stage.heart_battle == HeartEncounter.PENDING, "이야기 꺼짐도 세라 보상 실패 시 진입 보류·확정 선택 보존"): return
					legacy.fail_sera = false
					if not sandbox._acknowledge_story(HeartThreshold.SCENE_ID): return
				if not _active_heart(): return
				if not await _basic_clear(weapon) or not _heart_recorded(choice): return
			else:
				if not _prepare_battle(character, weapon, choice): return
				var saved := store.load_checkpoint()
				if phase == "legacy":
					saved.stage.erase("heart_battle")
					if store.save_checkpoint(saved) != OK: return
					controls.show_main_screen()
					if not sandbox.continue_saved_run() or not sandbox._acknowledge_story(HeartThreshold.SCENE_ID) or not _check(controls.story_scene.id == ArrivalEnding.SCENE_ID and not runner.heart.visible, "GP319 저장에는 새 전투 소급 없음"): return
				else:
					if not sandbox._acknowledge_story(HeartThreshold.SCENE_ID) or not _active_heart(): return
					if phase == "validate":
						var pending := store.load_checkpoint()
						for value in [null, true, 3, [], {}, "unknown", HeartEncounter.ACTIVE, HeartEncounter.SEEN]:
							var bad := pending.duplicate(true)
							bad.stage.heart_battle = value
							if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and pending == store.load_checkpoint(), "잘못된 상태/미확인 승리 거부·정상 저장 보존"): return
					elif phase == "patterns":
						if not await _patterns(): return
					elif phase == "layout":
						if not await _heart_layout(character, choice): return
					elif phase == "death":
						player.damage_receiver.barrier_health = 0
						player.relic_state = {}
						var event := DamageEvent.new()
						event.event_id = &"heart-death"
						event.damage = 9999
						event.tags = PackedStringArray(["enemy", "heart"])
						player.receive_damage(event)
						if not _check(player.damage_receiver.dead and not growth.run_active and store.load_checkpoint().is_empty() and recorder.summary_snapshot().completed_run_count == 0 and journal.snapshot().rewind_count == 1, "심장 사망은 기존 되감기·실패 정책·완주 미지급"): return
		_:
			_check(false, "알 수 없는 심장 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-320 runtime test: OK (%s %s %s %s)" % [phase, character, weapon, choice])
	quit(0)

func _prepare_battle(character: String, weapon: String, choice: String) -> bool:
	return journal.record_ending("prior-arrival", ArrivalEnding.ID, character, choice) == OK and _pending_heart(character, weapon, choice) and _check(runner.heart_battle == HeartEncounter.AVAILABLE and controls.story_scene.confirm == "심장 전투" and not runner.current_metrics().run_complete, "첫 엔딩 이후 새 여정의 입구에서만 전투 해금")

func _enter_heart(character: String, weapon: String, choice: String) -> bool:
	return _prepare_battle(character, weapon, choice) and sandbox._acknowledge_story(HeartThreshold.SCENE_ID) and _active_heart()

func _restore_battle() -> bool:
	controls.show_main_screen()
	return sandbox.continue_saved_run()

func _active_heart() -> bool:
	runner.heart.set_process(false)
	var saved := store.load_checkpoint()
	return _check(runner.heart_battle == HeartEncounter.ACTIVE and runner.final_enemy() == runner.heart and runner.heart.visible and not runner.sera.visible and not runner.boss.visible and not paused and controls.current_screen_mode() == 0 and not runner.stage_complete and not runner.current_metrics().run_complete and festival_terrain.heart_arena and runner.current_metrics().run_route_name == "행복의 심장" and runner.current_metrics().boss_name == BossHappinessHeart.BOSS_NAME and saved.stage.heart_battle == HeartEncounter.PENDING and player.damage_receiver.health == 83 and festival_ultimate.gauge == 37 and weapons.sword_combat._skill_1_cooldown_s == 3.25 and legacy.progress_snapshot().sera_choices.get(runner.boss_choice, false) and recorder.summary_snapshot().completed_run_count == 0, "실제1200심장 전투·다른 보스 숨김·잔량/재사용·전투 직전 저장·미완료")

func _basic_clear(weapon: String) -> bool:
	var heart := runner.heart
	heart.set_process(false)
	player.prepare_next_stage(Vector2(heart.position.x - 100, 780))
	var camera := player.get_node("Camera2D") as Camera2D
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	for ignored in 2: await process_frame
	var selector := player.get_node("AutoTargetSelector") as AutoTargetSelector
	for attack in 150:
		if not heart.is_targetable(): break
		selector.force_scan()
		if weapon == "sword":
			weapons.sword_combat._basic_remaining_s = 0
			weapons.sword_combat._update_basic_attack(0.1)
		else:
			weapons.bow_combat._basic_remaining_s = 0
			weapons.bow_combat._update_basic_attack()
			for shot in get_nodes_in_group("bow_projectile"):
				for ignored in 12:
					if is_instance_valid(shot) and not shot.is_queued_for_deletion(): shot._physics_process(0.025)
				if is_instance_valid(shot): shot.queue_free()
		if not _resolve_growth(): return false
		await process_frame
	if not _check(not heart.is_targetable() and heart.last_defeat_in_combat and heart.phase == 2 and heart.state == EliteArmoredBoar.State.DEAD, "실제 검 타격/활 투사체로 두 페이즈 심장 처치"): return false
	if not _resolve_growth(): return false
	sandbox.weapon_controller.force_emit_metrics()
	runner._process(0.5)
	return _check(runner.heart_battle in [HeartEncounter.DEFEATED, HeartEncounter.SEEN] and not runner.heart.visible and get_nodes_in_group("enemy_projectile").all(func(shot: Node) -> bool: return shot.is_queued_for_deletion()), "심장 처치 후 공격 정리·완료 대기")

func _victory_pending() -> bool:
	return _check(controls.current_screen_mode() == 18 and controls.story_scene.id == HeartEncounter.VICTORY_SCENE and paused and growth.run_active and runner.heart_battle == HeartEncounter.DEFEATED and store.load_checkpoint().stage.heart_battle == HeartEncounter.DEFEATED and recorder.summary_snapshot().completed_run_count == 0, "처치 저장·전용 승리 장면·확인 전 완주 차단")

func _confirm_victory(skip: bool) -> bool:
	var layout := PrototypeStoryView.scene_layout(controls._safe_area_in_viewport())
	for ignored in 2:
		if controls.current_screen_mode() != 18: break
		_tap((layout.skip if skip else layout.next).get_center())
	return controls.current_screen_mode() == 1

func _heart_recorded(choice: String) -> bool:
	var progress := journal.snapshot()
	var result: Dictionary = controls.current_result_snapshot()
	if not _check(result.heart_battle == HeartEncounter.SEEN and result.boss_name == BossHappinessHeart.BOSS_NAME and result.boss_choice == choice and progress.chronicles.has("heart_" + choice) and progress.endings.size() == 1 and recorder.summary_snapshot().completed_run_count == 1 and store.load_checkpoint().is_empty(), "심장 제압 결과·선택별 영구 기록·도착 최초 기록 보존·한 번 완주"): return false
	var cards := PrototypeVillageView.cards("history", {}, {}, recorder.summary_snapshot())
	if not _check(cards[0].status == "심장 제압", "광장 최근 도전 카드에 제압 표시"): return false
	var recent: Dictionary = recorder.summary_snapshot().recent_runs[0]
	if not _check(recent.heart_cleared and not sandbox._acknowledge_story(HeartEncounter.VICTORY_SCENE), "최근 이력에 제압 표시·중복 확인 거부"): return false
	controls.show_main_screen()
	controls.open_story_journal()
	_tap(controls.story_journal_snapshot().layout.tabs[1].get_center())
	var journal_cards := PrototypeStory.journal_cards(1, progress, player.character_id)
	return _check(journal_cards.any(func(card: Dictionary) -> bool: return card.id == "heart_" + choice and card.open), "수첩에서 승리 여행 기록 다시 읽기")

func _patterns() -> bool:
	var heart := runner.heart
	for expected in [EliteArmoredBoar.Pattern.SHOCKWAVE, BossHappinessHeart.NEEDLES, BossHappinessHeart.BEAM]:
		heart._begin_next_pattern()
		if not _check(heart.current_pattern == expected and heart.warning_line.visible and heart.warning_feedback_snapshot().uses_color_and_shape, "파문→부채→수평선의 형태/색 경고"): return false
		heart.set_enemy_time_scale(0)
		var count := heart.attack_count
		heart._process(2)
		if not _check(heart.attack_count == count, "필살기 정지 중 패턴 미진행"): return false
		heart.set_enemy_time_scale(1)
		heart._process(0.5)
		if not _check(heart.attack_count == count, "경고 이전에는 타격 없음"): return false
		heart._process(0.6)
		if not _check(heart.attack_count == count + 1, "경고 뒤 실제 공격"): return false
	for shot in get_nodes_in_group("enemy_projectile"): shot.queue_free()
	player.damage_receiver.health = 83
	player.damage_receiver.barrier_health = 0
	player.damage_receiver._post_hit_remaining_s = 0
	player.prepare_next_stage(Vector2(4100, 780))
	heart._beam_y = player.global_position.y - 42
	player.global_position.y -= 150
	var before := player.damage_receiver.health
	heart._fire_beam()
	if not _check(player.damage_receiver.health == before, "경고 뒤 높이를 바꾸면 수평 절단 회피"): return false
	player.global_position.y = 780
	player.invincible = true
	heart._fire_beam()
	player.invincible = false
	if not _check(player.damage_receiver.health == before, "절단 지상 회피 무적 판정"): return false
	player.damage_receiver._post_hit_remaining_s = 0
	heart._fire_beam()
	if not _check(player.damage_receiver.health < before, "위치 유지 시 절단 실제 타격"): return false
	var hit := DamageEvent.new()
	hit.event_id = &"heart-phase-two"
	hit.damage = 610
	hit.tags = PackedStringArray(["sword"])
	heart.receive_damage(hit)
	if not _check(heart.phase == 2 and heart.state == EliteArmoredBoar.State.PHASE_TRANSITION, "체력50% 과부하 전환"): return false
	heart._process(0.8)
	heart.last_pattern = EliteArmoredBoar.Pattern.SHOCKWAVE
	heart._begin_next_pattern()
	var shots := get_nodes_in_group("enemy_projectile").size()
	heart._process(0.73)
	if not _check(get_nodes_in_group("enemy_projectile").size() == shots + 5, "2페이즈 바늘5발 강화"): return false
	return true

func _heart_layout(character: String, choice: String) -> bool:
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 720)]:
		root.size = dimensions
		for ignored in 3: await process_frame
		var safe: Rect2 = controls._safe_area_in_viewport()
		var layout := PrototypeStoryView.scene_layout(safe)
		for line in HeartEncounter.victory(character, choice).lines:
			if not _check(PrototypeStoryView.wrap(line, ThemeDB.fallback_font, 22, layout.paragraphs[0].size.x).size() * 28 <= layout.paragraphs[0].size.y, "승리 한국어 대사 높이"): return false
	return true

func _check(condition: bool, label: String) -> bool:
	if condition: return true
	push_error("GP-320 실패: " + label)
	paused = false
	quit(1)
	return false
