extends "res://tests/gp317_runtime_test.gd"

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
	var prefix := "user://gp318_%s_%s_%s_%s" % ["fault" if phase in ["fault-seed", "fault-resume"] else "flow" if phase == "seed" or continuing else phase, character, weapon, choice]
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
			if not _pending_ending(character, weapon, choice): return
		"resume", "finish":
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run(), "별도 프로세스 엔딩 복원") or not _ending_pending(character, choice): return
			if not _check(player.damage_receiver.health == 83 and festival_ultimate.gauge == 37 and weapons.sword_combat._skill_1_cooldown_s == 3.25, "체력·필살기·재사용 복원"): return
			if phase == "resume":
				var saved := store.load_checkpoint()
				var raw := FileAccess.get_file_as_string(journal.save_path)
				var before := [player.damage_receiver.health, festival_ultimate.gauge, weapons.sword_combat._skill_1_cooldown_s, runner.stage_elapsed_s]
				_tap(PrototypeStoryView.scene_layout(controls._safe_area_in_viewport()).next.get_center())
				runner.set_process(true)
				weapons.sword_combat.set_process(true)
				for ignored in 3: await physics_frame
				runner.set_process(false)
				weapons.sword_combat.set_process(false)
				if not _check(controls.story_page == 1 and saved == store.load_checkpoint() and raw == FileAccess.get_file_as_string(journal.save_path) and before == [player.damage_receiver.health, festival_ultimate.gauge, weapons.sword_combat._skill_1_cooldown_s, runner.stage_elapsed_s], "엔딩 읽기는 저장 불변·전투 시간 정지"): return
			else:
				if not _confirm_ending(weapon == "bow") or not _ending_recorded(character, choice): return
				if not _notebook(): return
				var before := journal.snapshot()
				recorder.clear_records()
				controls.show_main_screen()
				controls.begin_retry(weapon, 3, "standard", character, false)
				if not _check(journal.snapshot() == before, "도전 기록 삭제·새 도전에도 엔딩 보존"): return
		"checkpoint-fault", "journal-fault", "fault-seed":
			if not _pending_ending(character, weapon, choice): return
			var saved := store.load_checkpoint()
			var path := store.save_path
			if phase == "checkpoint-fault": store.save_path = "user://gp318_missing/checkpoint.json"
			else: journal.fail_writes = true
			if not _check(not sandbox._acknowledge_story(ArrivalEnding.SCENE_ID) and controls.current_screen_mode() == 18 and paused and growth.run_active and recorder.summary_snapshot().completed_run_count == 0 and journal.snapshot().endings.is_empty() and not controls.story_message.is_empty(), "저장 실패는 미완료·장면과 재시도 유지"): return
			store.save_path = path
			if phase == "checkpoint-fault":
				if not _check(runner.arrival_ending == ArrivalEnding.PENDING and saved == store.load_checkpoint(), "확인 저장 실패는 상태와 정상 파일 복구"): return
			else:
				if not _check(runner.arrival_ending == ArrivalEnding.SEEN and store.load_checkpoint().stage.arrival_ending == ArrivalEnding.SEEN, "기록 실패에도 확인한 체크포인트 보존"): return
			if phase != "fault-seed":
				journal.fail_writes = false
				if not sandbox._acknowledge_story(ArrivalEnding.SCENE_ID) or not _ending_recorded(character, choice): return
		"fault-resume":
			if not _check(journal.snapshot().endings.has(ArrivalEnding.ID), "시작 시 미기록 엔딩 재저장"): return
			controls.show_main_screen()
			if not sandbox.continue_saved_run() or not _ending_recorded(character, choice): return
		"validate":
			if not _pending_ending(character, weapon, choice): return
			var saved := store.load_checkpoint()
			for value in [null, true, 1, [], {}, "", "complete", ArrivalEnding.LOCKED]:
				var bad := saved.duplicate(true)
				bad.stage.arrival_ending = value
				if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "엔딩 상태 타입·전이 위변조 거부"): return
			for change in 3:
				var bad := saved.duplicate(true)
				if change == 0: bad.erase("story"); bad.stage.erase("heart_threshold")
				elif change == 1: bad.stage.heart_threshold = HeartThreshold.PENDING
				else: bad.stage.erase("heart_threshold")
				if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA, "엔딩 대기는 이야기·확인한 심장 입구 필요"): return
			if not _check(not sandbox._acknowledge_story(HeartThreshold.SCENE_ID), "이전 장면 확인 재실행 차단"): return
		"legacy":
			if not _pending_heart(character, weapon, choice): return
			var old := store.load_checkpoint()
			old.stage.erase("arrival_ending")
			if store.save_checkpoint(old) != OK: return
			controls.show_main_screen()
			if not sandbox.continue_saved_run() or not sandbox._acknowledge_story(HeartThreshold.SCENE_ID): return
			if not _check(controls.current_screen_mode() == 1 and journal.snapshot().endings.is_empty() and recorder.summary_snapshot().completed_run_count == 1, "GP317 저장은 기존 심장 장면 후 완료·엔딩 소급 없음"): return
		"story-off":
			if not _prepare_sera(character, weapon, "rescue"): return
			sandbox.story_run.restore({})
			if not _enter_sera(false) or not _finish_stage() or not _choose_sera(choice): return
			if not _ending_recorded(character, choice, false): return
		"journal":
			if not _journal_integrity(): return
		"layout":
			if not _pending_ending(character, weapon, choice): return
			for dimensions in [Vector2i(1280, 720), Vector2i(1600, 720)]:
				root.size = dimensions
				for ignored in 3: await process_frame
				var safe: Rect2 = controls._safe_area_in_viewport()
				var layout := PrototypeStoryView.scene_layout(safe)
				for key in ["portrait", "speaker", "next", "skip"]:
					if not _check(safe.encloses(layout[key]), "엔딩 화면 두 비율 안전 영역"): return
				for text in controls.story_scene.lines:
					if not _check(PrototypeStoryView.wrap(text, ThemeDB.fallback_font, 22, layout.paragraphs[0].size.x).size() * 28.0 <= layout.paragraphs[0].size.y, "엔딩 한국어 줄바꿈 높이"): return
			if not _confirm_ending(true) or not _notebook(): return
		_:
			_check(false, "알 수 없는 엔딩 검사")
			return
	paused = false
	sandbox.free()
	print("GP-318 runtime test: OK (%s %s %s %s)" % [phase, character, weapon, choice])
	quit(0)

func _pending_ending(character: String, weapon: String, choice: String) -> bool:
	if not _pending_heart(character, weapon, choice) or not sandbox._acknowledge_story(HeartThreshold.SCENE_ID): return false
	return _ending_pending(character, choice)

func _ending_pending(character: String, choice: String) -> bool:
	var saved := store.load_checkpoint()
	return _check(controls.current_screen_mode() == 18 and controls.story_scene.get("id") == ArrivalEnding.SCENE_ID and runner.arrival_ending == ArrivalEnding.PENDING and saved.stage.arrival_ending == ArrivalEnding.PENDING and paused and growth.run_active and not runner.current_metrics().run_complete and recorder.summary_snapshot().completed_run_count == 0 and journal.snapshot().endings.is_empty(), "입구 확인→도착 엔딩 대기·미완료·미해금") and _check(controls.story_scene.lines[0].contains(PrototypeCharacters.display_name(character)) and controls.story_scene.lines[2].contains("나는 기억해요" if choice == "rescue" else "사라진"), "주인공·세라 선택별 엔딩 서사")

func _confirm_ending(skip: bool) -> bool:
	var layout := PrototypeStoryView.scene_layout(controls._safe_area_in_viewport())
	for ignored in 3:
		if controls.current_screen_mode() != 18: break
		_tap((layout.skip if skip else layout.next).get_center())
	return _check(controls.current_screen_mode() == 1 and not paused and not growth.run_active, "읽기/건너뛰기로 엔딩 기록·결과 복귀")

func _ending_recorded(character: String, choice: String, story: bool = true) -> bool:
	var progress := journal.snapshot()
	return _check(progress.endings.size() == 1 and progress.ending_completions.size() == 1 and progress.endings.arrival.character == character and progress.endings.arrival.choice == choice and progress.chronicles.has("sera_" + choice) == story and controls.current_result_snapshot().arrival_ending == ArrivalEnding.SEEN and recorder.summary_snapshot().completed_run_count == 1 and store.load_checkpoint().is_empty(), "엔딩 영구 기록·선택 보존·한 번 완주·체크포인트 정리") and _check(not sandbox._acknowledge_story(ArrivalEnding.SCENE_ID), "엔딩 중복 확인 차단")

func _notebook() -> bool:
	var before := FileAccess.get_file_as_string(journal.save_path)
	controls.show_main_screen()
	controls.open_story_journal()
	for dimensions in [Vector2(1280, 720), Vector2(1600, 720)]:
		controls.size = dimensions
		var snapshot: Dictionary = controls.story_journal_snapshot()
		_tap(snapshot.layout.tabs[2].get_center())
		snapshot = controls.story_journal_snapshot()
		if not _check(controls.story_journal_tab == 2 and snapshot.cards.size() == 3 and snapshot.cards[0].open and snapshot.cards[0].name == "도착", "실제 엔딩 탭 터치·도착 기록 표시"): return false
		for rect in snapshot.layout.tabs + snapshot.layout.cards:
			if not _check(controls._safe_area_in_viewport().encloses(rect), "엔딩 탭·카드 두 비율 안전 영역"): return false
	controls.close_story_journal()
	controls.size = Vector2(1280, 720)
	return _check(before == FileAccess.get_file_as_string(journal.save_path), "엔딩 수첩 조회는 저장 불변")

func _journal_integrity() -> bool:
	if not _check(journal.record_ending("first", "arrival", "roan", "rescue") == OK, "첫 엔딩 해금"): return false
	var before := FileAccess.get_file_as_string(journal.save_path)
	if not _check(journal.record_ending("first", "arrival", "roan", "rescue") == OK and before == FileAccess.get_file_as_string(journal.save_path) and journal.record_ending("first", "arrival", "lumi", "destroy") == ERR_INVALID_DATA, "동일 도전 중복 멱등·다른 선택 덮어쓰기 차단"): return false
	if journal.record_ending("second", "arrival", "lumi", "destroy") != OK: return false
	var progress := journal.snapshot()
	if not _check(progress.endings.size() == 1 and progress.endings.arrival.character == "roan" and progress.ending_completions.size() == 2, "여러 완주 독립 기록·최초 발견 보존"): return false
	for event in [{"id": "unknown", "character": "roan", "choice": "rescue"}, {"id": "arrival", "character": null, "choice": "rescue"}, {"id": "arrival", "character": "roan", "choice": true}, {"id": "arrival", "character": "roan", "choice": "other"}]:
		event.event = "ending"
		event.run_id = "invalid"
		journal._append(event)
	var file := FileAccess.open(journal.save_path, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string("broken-tail")
	file.close()
	if not _check(journal.snapshot() == progress and journal.record_ending("third", "arrival", "lumi", "rescue") == OK and journal.snapshot().ending_completions.size() == 3, "위변조·손상 꼬리 무시·다음 정상 기록 복구"): return false
	var cards := PrototypeStory.journal_cards(2, {}, "lumi")
	return _check(cards.size() == ArrivalEnding.PROFILES.size() and not cards[0].open and cards[0].name == "엔딩 1", "미발견 엔딩 제목·본문 잠금")

func _check(condition: bool, label: String) -> bool:
	if condition: return true
	push_error("GP-318 실패: " + label)
	paused = false
	quit(1)
	return false
