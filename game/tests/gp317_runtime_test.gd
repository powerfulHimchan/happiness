extends "res://tests/gp316_runtime_test.gd"

func _run() -> void:
	auto_guardian_choice = false
	legacy_final_boss_for_tests = false
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var character := args[1]
	var weapon := args[2]
	var choice := args[3]
	legacy = FaultStore.new()
	var continuing := phase in ["resume", "finish"]
	var prefix := "user://gp317_%s_%s_%s_%s" % ["flow" if phase == "seed" or continuing else phase, character, weapon, choice]
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
			if not _pending_heart(character, weapon, choice): return
			if not _check(player.damage_receiver.health == 83 and festival_ultimate.gauge == 37 and weapons.sword_combat._skill_1_cooldown_s == 3.25, "선택 뒤 잔량 유지"): return
		"resume":
			if not _restore_heart(character, choice): return
			var saved := store.load_checkpoint()
			var raw := FileAccess.get_file_as_string(legacy.save_path)
			var before := [player.damage_receiver.health, festival_ultimate.gauge, weapons.sword_combat._skill_1_cooldown_s, runner.stage_elapsed_s]
			_tap(PrototypeStoryView.scene_layout(controls._safe_area_in_viewport()).next.get_center())
			runner.set_process(true)
			weapons.sword_combat.set_process(true)
			for ignored in 3: await physics_frame
			runner.set_process(false)
			weapons.sword_combat.set_process(false)
			if not _check(controls.story_page == 1 and before == [player.damage_receiver.health, festival_ultimate.gauge, weapons.sword_combat._skill_1_cooldown_s, runner.stage_elapsed_s] and store.load_checkpoint() == saved, "페이지 이동·시간/체력/재사용 정지·파일 불변 page=%d before=%s after=%s saved=%s" % [controls.story_page, str(before), str([player.damage_receiver.health, festival_ultimate.gauge, weapons.sword_combat._skill_1_cooldown_s, runner.stage_elapsed_s]), str(store.load_checkpoint() == saved) + " before_stage=" + str(saved.stage) + " after_stage=" + str(store.load_checkpoint().get("stage", {}))]): return
			controls.show_main_screen()
			if not sandbox.continue_saved_run() or not _check(controls.story_page == 0 and raw == FileAccess.get_file_as_string(legacy.save_path), "반복 복원은 같은 장면 처음·영구 보상 중복 없음"): return
		"finish":
			if not _restore_heart(character, choice) or not _finish_heart(weapon == "bow"): return
			var result: Dictionary = controls.current_result_snapshot()
			if not _check(result.heart_threshold == HeartThreshold.SEEN and result.boss_choice == choice and journal.snapshot().chronicles.has("sera_" + choice) and recorder.summary_snapshot().completed_run_count == 1 and store.load_checkpoint().is_empty(), "장면 확인 후에만 세라 기록·한 번 완주·결과 도착 표시·저장 정리"): return
			if not _check(not sandbox._acknowledge_story(HeartThreshold.SCENE_ID), "중복 확인은 거부"): return
			controls.show_main_screen()
			if not _check(not sandbox.continue_saved_run() and recorder.summary_snapshot().completed_run_count == 1, "완료 후 재실행은 중복 완주 없음"): return
		"checkpoint-fault", "reward-fault":
			if not _pending_heart(character, weapon, choice, phase == "reward-fault"): return
			var saved := store.load_checkpoint()
			var path := store.save_path
			if phase == "checkpoint-fault": store.save_path = "user://gp317_missing/checkpoint.json"
			else: legacy.fail_sera = true
			if not _check(not sandbox._acknowledge_story(HeartThreshold.SCENE_ID) and controls.current_screen_mode() == 18 and paused and runner.heart_threshold == HeartThreshold.PENDING and recorder.summary_snapshot().completed_run_count == 0 and not controls.story_message.is_empty(), "확인 저장/영구 보상 실패는 장면 유지·미완료"): return
			store.save_path = path
			legacy.fail_sera = false
			if not _check(store.load_checkpoint() == saved, "실패 전 정상 파일 보존"): return
			controls.show_main_screen()
			if not sandbox.continue_saved_run() or not _finish_heart(true): return
		"validate":
			if not _pending_heart(character, weapon, choice): return
			var saved := store.load_checkpoint()
			for value in [null, true, 1, [], {}, "", "entered", HeartThreshold.UNREACHED]:
				var bad := saved.duplicate(true)
				bad.stage.heart_threshold = value
				if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "입구 타입·상태 위변조 거부·정상 파일 보존"): return
			for mode in 4:
				var bad := saved.duplicate(true)
				if mode == 0: bad.erase("story")
				elif mode == 1: bad.stage.boss_choice = ""; bad.stage.history[-1].boss_choice = ""
				elif mode == 2: bad.stage.final_boss = SeraEncounter.LEGACY; bad.stage.history[-1].final_boss = SeraEncounter.LEGACY
				else: bad.story.pending = "stage:10"; bad.story.seen.pop_back()
				if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA, "이야기 없음·선택 없음·이전 보스·전 장면 미확인 상태 거부"): return
			if not _check(not sandbox._acknowledge_story("stage:10") and not sandbox._resolve_boss_choice("destroy" if choice == "rescue" else "rescue"), "잘못된 장면·확정 선택 재변경 차단"): return
		"legacy":
			if not _pending_heart(character, weapon, choice): return
			var old := store.load_checkpoint()
			old.stage.erase("heart_threshold")
			old.stage.erase("arrival_ending")
			if not _check(store.save_checkpoint(old) == OK, "GP316 이전 확정 선택 저장 구성"): return
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and controls.current_screen_mode() == 1 and store.load_checkpoint().is_empty() and recorder.summary_snapshot().completed_run_count == 1, "이전 저장에는 심장 장면 소급 없음·기존 완료 보존"): return
		"story-off":
			if not _prepare_sera(character, weapon, "rescue"): return
			sandbox.story_run.restore({})
			if not _enter_sera(false) or not _finish_stage() or not _choose_sera(choice): return
			if not _check(controls.current_screen_mode() == 1 and recorder.summary_snapshot().completed_run_count == 1 and not journal.snapshot().chronicles.has("sera_" + choice), "이야기 꺼짐은 후속 장면 없이 완료·선택 보상 유지"): return
		"layout":
			if not _pending_heart(character, weapon, choice): return
			for resolution in [Vector2i(1280, 720), Vector2i(1600, 720)]:
				root.size = resolution
				for ignored in 3: await process_frame
				var safe: Rect2 = controls._safe_area_in_viewport()
				var layout := PrototypeStoryView.scene_layout(safe)
				for key in ["portrait", "speaker", "next", "skip"]:
					if not _check(safe.encloses(layout[key]), "두 화면비 실제 입구 요소 안전영역"): return
				for text in controls.story_scene.lines:
					var lines := PrototypeStoryView.wrap(text, ThemeDB.fallback_font, 22, layout.paragraphs[0].size.x)
					if not _check(lines.size() * 28.0 <= layout.paragraphs[0].size.y, "긴 한국어 문장 줄바꿈 높이"): return
		_:
			_check(false, "알 수 없는 심장 입구 검사")
			return
	paused = false
	sandbox.free()
	print("GP-317 runtime test: OK (%s %s %s %s)" % [phase, character, weapon, choice])
	quit(0)

func _pending_heart(character: String, weapon: String, choice: String, reward_fail: bool = false) -> bool:
	if not _prepare_sera(character, weapon, "rescue") or not _enter_sera() or not _intro_input(true) or not _finish_stage() or not _ack_scene(true): return false
	player.damage_receiver.health = 83
	festival_ultimate.gauge = 37
	weapons.sword_combat._skill_1_cooldown_s = 3.25
	legacy.fail_sera = reward_fail
	if not sandbox._resolve_boss_choice(choice): return false
	return _heart_pending(character, choice, reward_fail)

func _heart_pending(character: String, choice: String, reward_fail: bool = false) -> bool:
	var saved := store.load_checkpoint()
	if not _check(controls.current_screen_mode() == 18 and controls.story_scene.get("id") == HeartThreshold.SCENE_ID and runner.heart_threshold == HeartThreshold.PENDING and saved.stage.heart_threshold == HeartThreshold.PENDING and paused and growth.run_active and not runner.current_metrics().run_complete, "세라 확정 선택→심장 입구 장면·대기 저장·미완료"): return false
	if not _check(recorder.summary_snapshot().completed_run_count == 0 and not journal.snapshot().chronicles.has("sera_" + choice) and (legacy.progress_snapshot().sera_choices.get(choice, false) == not reward_fail), "선택 보상은 즉시 영구 해금·완주와 여행 기록은 확인 후"): return false
	return _check(controls.story_scene.lines[0].contains(PrototypeCharacters.display_name(character)) and controls.story_scene.lines[1].contains("세라:" if choice == "rescue" else "홀로"), "실제 주인공·구출 동행/파괴 홀로 분기")

func _restore_heart(character: String, choice: String) -> bool:
	controls.show_main_screen()
	return _check(sandbox.continue_saved_run(), "별도 프로세스 미확인 입구 복원") and _heart_pending(character, choice) and _check(player.damage_receiver.health == 83 and festival_ultimate.gauge == 37 and weapons.sword_combat._skill_1_cooldown_s == 3.25 and not runner.sera.is_targetable(), "이전 잔량·재사용·보스 처치 상태 복원")

func _finish_heart(skip: bool) -> bool:
	var layout := PrototypeStoryView.scene_layout(controls._safe_area_in_viewport())
	for ignored in 6:
		if controls.current_screen_mode() != 18: break
		_tap((layout.skip if skip else layout.next).get_center())
	return _check(controls.current_screen_mode() == 1 and not paused and not growth.run_active, "실제 읽기/건너뛰기 입력으로 결과 복귀·정지 해제")
