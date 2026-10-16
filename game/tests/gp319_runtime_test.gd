extends "res://tests/gp318_runtime_test.gd"

func _run() -> void:
	auto_guardian_choice = false
	legacy_final_boss_for_tests = false
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var character := args[1]
	var weapon := args[2]
	var choice := args[3]
	legacy = FaultStore.new()
	var continuing := phase in ["resume", "finish", "fault-resume"]
	var prefix := "user://gp319_%s_%s_%s_%s" % ["fault" if phase in ["fault-seed", "fault-resume"] else "flow" if phase == "seed" or continuing else phase, character, weapon, choice]
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
		"seed", "resume", "finish":
			if phase == "seed":
				if journal.record_ending("prior-arrival", ArrivalEnding.ID, character, choice) != OK or not _pending_heart(character, weapon, choice): return
			else:
				controls.show_main_screen()
				if not sandbox.continue_saved_run(): return
			if not _truth_pending(character, choice): return
			if phase == "resume":
				var saved := store.load_checkpoint()
				var raw := FileAccess.get_file_as_string(journal.save_path)
				var before := [player.damage_receiver.health, festival_ultimate.gauge, weapons.sword_combat._skill_1_cooldown_s, runner.stage_elapsed_s]
				_tap(PrototypeStoryView.scene_layout(controls._safe_area_in_viewport()).next.get_center())
				if not _check(controls.story_page == 1 and controls.story_scene.id == HeartThreshold.SCENE_ID and store.load_checkpoint() == saved, "한 번의 다음 입력은 두 번째 페이지·저장 불변"): return
				runner.set_process(true)
				weapons.sword_combat.set_process(true)
				for ignored in 3: await physics_frame
				runner.set_process(false)
				weapons.sword_combat.set_process(false)
				if not _check(before == [player.damage_receiver.health, festival_ultimate.gauge, weapons.sword_combat._skill_1_cooldown_s, runner.stage_elapsed_s] and saved == store.load_checkpoint() and raw == FileAccess.get_file_as_string(journal.save_path), "읽기는 시간·잔량·저장 불변 before=%s after=%s saved=%s journal=%s" % [str(before), str([player.damage_receiver.health, festival_ultimate.gauge, weapons.sword_combat._skill_1_cooldown_s, runner.stage_elapsed_s]), str(saved == store.load_checkpoint()), str(raw == FileAccess.get_file_as_string(journal.save_path)) + " stage_before=" + str(saved.stage) + " stage_after=" + str(store.load_checkpoint().get("stage", {})) + " page=" + str(controls.story_page) + " id=" + str(controls.story_scene.get("id"))]): return
			if phase == "finish":
				if not _confirm_truth(weapon == "bow") or not _finish_truth(character, choice): return
		"checkpoint-fault", "journal-fault", "fault-seed":
			if journal.record_ending("prior-arrival", ArrivalEnding.ID, character, choice) != OK or not _pending_heart(character, weapon, choice): return
			var saved := store.load_checkpoint()
			var path := store.save_path
			if phase == "checkpoint-fault": store.save_path = "user://gp319_missing/checkpoint.json"
			else: journal.fail_writes = true
			if not _check(not sandbox._acknowledge_story(HeartThreshold.SCENE_ID) and paused and growth.run_active and controls.story_scene.id == HeartThreshold.SCENE_ID and not controls.story_message.is_empty() and not journal.snapshot().fragments.has("heart_machine") and recorder.summary_snapshot().completed_run_count == 0, "저장 실패는 진실 미지급·장면 유지·미완료"): return
			store.save_path = path
			if phase == "checkpoint-fault":
				if not _check(saved == store.load_checkpoint() and runner.heart_threshold == HeartThreshold.PENDING, "체크포인트 실패는 상태·정상 파일 보존"): return
			else:
				if not _check(store.load_checkpoint().stage.heart_threshold == HeartThreshold.SEEN and store.load_checkpoint().stage.arrival_ending == ArrivalEnding.PENDING, "저널 실패에도 확인한 체크포인트 보존"): return
			if phase == "journal-fault":
				controls.show_main_screen()
				if not _check(not sandbox.continue_saved_run() and store.load_checkpoint().stage.heart_threshold == HeartThreshold.SEEN, "기록 실패가 계속되면 이어하기도 차단·확인한 저장 보존"): return
				journal.fail_writes = false
				if not sandbox.continue_saved_run() or not _finish_truth(character, choice): return
			elif phase != "fault-seed":
				journal.fail_writes = false
				if not sandbox._acknowledge_story(HeartThreshold.SCENE_ID) or not _finish_truth(character, choice): return
		"fault-resume":
			if not _check(journal.snapshot().fragments.has("heart_machine"), "프로세스 시작에서 확인한 진실 영구 기록 복구"): return
			controls.show_main_screen()
			if not sandbox.continue_saved_run() or not _finish_truth(character, choice): return
		"first-run", "legacy", "validate", "layout":
			if phase != "first-run" and journal.record_ending("prior-arrival", ArrivalEnding.ID, character, choice) != OK: return
			if not _pending_heart(character, weapon, choice): return
			var saved := store.load_checkpoint()
			if phase == "first-run":
				if not _check(not sandbox.story_run.arrival_seen and controls.story_scene.name == "행복의 심장 앞에서", "첫 여정에는 심장의 정체 잠금"): return
				# 진행 중 외부에서 엔딩이 발견되어도 현재 여정 자격은 바뀌지 않는다.
				if journal.record_ending("other-arrival", ArrivalEnding.ID, character, choice) != OK: return
				controls.show_main_screen()
				if not sandbox.continue_saved_run() or not _check(not sandbox.story_run.arrival_seen, "진행 중 해금 소급 차단"): return
			elif phase == "legacy":
				saved.story.erase("arrival_seen")
				if store.save_checkpoint(saved) != OK: return
				controls.show_main_screen()
				if not sandbox.continue_saved_run() or not _check(not sandbox.story_run.arrival_seen and controls.story_scene.name == "행복의 심장 앞에서", "필드 없는 이전 저장은 소급 해금 없음"): return
			elif phase == "validate":
				for value in [null, 0, 1, "true", [], {}]:
					var bad := saved.duplicate(true)
					bad.story.arrival_seen = value
					if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "자격 타입 변조 거부·정상 저장 보존"): return
			elif phase == "layout":
				if not await _truth_layout(character, choice): return
			if phase in ["first-run", "legacy"]:
				if not sandbox._acknowledge_story(HeartThreshold.SCENE_ID) or not _confirm_ending(true): return
				if not _check(not journal.snapshot().fragments.has("heart_machine"), "첫 여정·이전 저장에서 진실 소급 수집 없음"): return
				controls.show_main_screen()
				controls.begin_retry(weapon, 10, "journey", character, true)
				if not _check(sandbox.story_run.arrival_seen and controls.story_scene.name == "도착 너머의 진실", "다음 새 이야기 전체 여정에서 후속 프롤로그 해금"): return
		"story-off", "standard":
			if journal.record_ending("prior-arrival", ArrivalEnding.ID, character, choice) != OK: return
			controls.begin_retry(weapon, 10 if phase == "story-off" else 3, "journey" if phase == "story-off" else "standard", character, phase == "standard")
			if not _check(controls.current_screen_mode() == (0 if phase == "story-off" else 18) and not journal.snapshot().fragments.has("heart_machine"), "이야기 꺼짐·일반 도전은 후속 장면과 기억 없음"): return
			if phase == "standard" and not _check(controls.story_scene.name != "도착 너머의 진실", "일반 도전은 기존 프롤로그 유지"): return
		_:
			_check(false, "알 수 없는 단계")
			return
	paused = false
	sandbox.free()
	print("GP-319 runtime test: OK (%s %s %s %s)" % [phase, character, weapon, choice])
	quit(0)

func _truth_pending(character: String, choice: String) -> bool:
	var saved := store.load_checkpoint()
	return _check(sandbox.story_run.arrival_seen and saved.story.arrival_seen and controls.story_scene.name == "행복의 심장 · 미소의 대가" and controls.story_scene.lines[0].contains(PrototypeCharacters.display_name(character)) and controls.story_scene.lines[3].contains("고대 마법 기계") and controls.story_scene.lines[4].contains("세라:" if choice == "rescue" else "부서진 왕관") and not journal.snapshot().fragments.has("heart_machine") and recorder.summary_snapshot().completed_run_count == 0, "엔딩 이후 새 여정·실제 주인공/선택별 진실·확인 전 기억 미지급")

func _confirm_truth(skip: bool) -> bool:
	var layout := PrototypeStoryView.scene_layout(controls._safe_area_in_viewport())
	for ignored in 3:
		if controls.story_scene.id != HeartThreshold.SCENE_ID: break
		_tap((layout.skip if skip else layout.next).get_center())
	return _check(controls.story_scene.id == ArrivalEnding.SCENE_ID and journal.snapshot().fragments.has("heart_machine"), "실제 확인/건너뛰기로 진실 기록 후 엔딩 이동")

func _finish_truth(character: String, choice: String) -> bool:
	if not _check(journal.snapshot().fragments.has("heart_machine") and journal.snapshot().fragments.size() == 10 and controls.story_scene.id == ArrivalEnding.SCENE_ID, "열 번째 기억 수집·엔딩 대기"): return false
	if not _confirm_ending(true): return false
	var before := FileAccess.get_file_as_string(journal.save_path)
	if not _check(recorder.summary_snapshot().completed_run_count == 1 and journal.snapshot().ending_completions.size() == 2 and journal.snapshot().ending_completions[recorder.checkpoint_snapshot().id].choice == choice and store.load_checkpoint().is_empty(), "선택 유지·한 번 완주·이전 엔딩 보존"): return false
	controls.show_main_screen()
	controls.open_story_journal()
	for ignored in 3: _tap(controls.story_journal_snapshot().layout.next.get_center())
	var book: Dictionary = controls.story_journal_snapshot()
	if not _check(book.pages == 4 and book.cards.size() == 1 and book.cards[0].id == "heart_machine" and book.cards[0].open and book.cards[0].name == "미소를 만드는 심장", "실제 수첩 4페이지·열 번째 기억 표시"): return false
	controls.close_story_journal()
	recorder.clear_records()
	return _check(before == FileAccess.get_file_as_string(journal.save_path), "수첩 조회·도전 기록 삭제에도 영구 진실 유지")

func _truth_layout(character: String, choice: String) -> bool:
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 720)]:
		root.size = dimensions
		for ignored in 3: await process_frame
		var safe: Rect2 = controls._safe_area_in_viewport()
		var layout := PrototypeStoryView.scene_layout(safe)
		for rect in layout.paragraphs + [layout.portrait, layout.speaker, layout.next, layout.skip]:
			if not _check(safe.encloses(rect), "후속 장면 안전 영역"): return false
		for scene in [HeartThreshold.scene(character, choice, "rescue", true, true), PrototypeStory.scene("prologue", [], character, [], 3, 10, true)]:
			for line in scene.lines:
				var wrapped := PrototypeStoryView.wrap(String(line), ThemeDB.fallback_font, 22, layout.paragraphs[0].size.x)
				if not _check(wrapped.size() * 28.0 <= layout.paragraphs[0].size.y, "한국어 긴 문장 높이"): return false
	return true

func _check(condition: bool, label: String) -> bool:
	if condition: return true
	push_error("GP-319 실패: " + label)
	paused = false
	quit(1)
	return false
