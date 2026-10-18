extends "res://tests/gp320_runtime_test.gd"

func _run() -> void:
	heart_battle_for_tests = true
	final_ritual_for_tests = true
	auto_guardian_choice = false
	legacy_final_boss_for_tests = false
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var character := args[1]
	var weapon := args[2]
	var choice := args[3]
	var ending := args[4]
	legacy = FaultStore.new()
	var continuing := phase in ["resume", "finish", "fault-resume"]
	var prefix := "user://gp321_%s_%s_%s_%s_%s" % ["fault" if phase in ["fault-seed", "fault-resume"] else "flow" if phase == "seed" or continuing else phase, character, weapon, choice, ending]
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
	if not continuing and ending == "return":
		for i in 3:
			if journal.record_rewind("earlier-%d" % i) != OK: return
	match phase:
		"first":
			if not _check(_pending_heart(character, weapon, choice) and runner.heart_battle == HeartEncounter.LOCKED and runner.final_ritual.phase == FinalRitual.LOCKED, "첫 여정은 기존 도착 엔딩 대상"): return
			if not sandbox._acknowledge_story(HeartThreshold.SCENE_ID) or not _confirm_ending(true): return
			if not _check(journal.snapshot().endings.size() == 1 and journal.snapshot().endings.has(ArrivalEnding.ID) and recorder.summary_snapshot().completed_run_count == 1, "새 필드가 있어도 첫 도착 엔딩 정상 완료"): return
		"seed":
			if not await _gp321_enter_choices(character, weapon, choice) or not _gp321_choices_pending(): return
		"resume":
			controls.show_main_screen()
			if not sandbox.continue_saved_run() or not _gp321_choices_pending(): return
			var before := store.load_checkpoint()
			_tap(FinalRitual.layout(controls._safe_area_in_viewport()).confirm.get_center())
			var escape := InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.pressed = true
			controls._input(escape)
			if not _check(store.load_checkpoint() == before and controls.story_scene.id == FinalRitual.CHOICE_SCENE, "미선택 확인·뒤로가기는 결말 자동 확정 금지"): return
			if ending == "dawn" and not _gp321_visit_secret(): return
			if not _gp321_select_final(ending): return
			_tap(PrototypeStoryView.scene_layout(controls._safe_area_in_viewport()).skip.get_center())
			if not _gp321_choices_pending() or not _gp321_select_final(ending): return
		"finish", "fault-resume":
			controls.show_main_screen()
			if not sandbox.continue_saved_run(): return
			if phase == "finish" and not _gp321_ending_pending(ending): return
			if phase == "finish" and not _gp321_confirm_final(): return
			if not _gp321_final_recorded(ending, character, choice): return
		"selection-fault", "ending-fault", "journal-fault", "fault-seed", "secret-fault", "validate", "layout", "legacy":
			if not await _gp321_enter_choices(character, weapon, choice): return
			if phase == "legacy":
				var old := store.load_checkpoint()
				old.stage.erase("final_ritual")
				if store.save_checkpoint(old) != OK: return
				controls.show_main_screen()
				if not sandbox.continue_saved_run() or not _check(controls.current_screen_mode() == 1 and journal.snapshot().endings.size() == 1 and not journal.snapshot().endings.has(ending), "구버전 확인 저장은 기존 완료·새 엔딩 소급 없음"): return
			elif phase == "validate":
				if not _gp321_validate_ritual(): return
			elif phase == "layout":
				if not await _gp321_ritual_layout(character, choice, args): return
			elif phase == "selection-fault":
				var before := store.load_checkpoint()
				var path := store.save_path
				store.save_path = "user://gp321_missing/selection.json"
				if not _check(not sandbox._on_final_action("liberation") and runner.final_ritual.phase == FinalRitual.CHOOSING and controls.story_scene.id == FinalRitual.CHOICE_SCENE, "선택 저장 실패는 결말 전이 차단"): return
				store.save_path = path
				if not _check(before == store.load_checkpoint(), "선택 실패는 이전 정상 파일 보존") or not _gp321_select_final("liberation") or not _gp321_confirm_final(): return
			elif phase == "secret-fault":
				if not sandbox._on_final_action("secret"): return
				journal.fail_writes = true
				if not _check(not sandbox._acknowledge_story(FinalRitual.SECRET_SCENE) and store.load_checkpoint().stage.final_ritual.secret and not journal.snapshot().secrets.has(FinalRitual.SECRET_SCENE), "비밀 저널 실패도 확인 저장 보존·미완료"): return
				journal.fail_writes = false
				if not sandbox._acknowledge_story(FinalRitual.SECRET_SCENE) or not _check(journal.snapshot().secrets.has(FinalRitual.SECRET_SCENE), "비밀 기록 재시도"): return
			else:
				if not _gp321_select_final(ending): return
				var before := store.load_checkpoint()
				var path := store.save_path
				if phase == "ending-fault": store.save_path = "user://gp321_missing/ending.json"
				else: journal.fail_writes = true
				if not _check(not sandbox._acknowledge_story(FinalRitual.ENDING_SCENE) and growth.run_active and paused and recorder.summary_snapshot().completed_run_count == 0 and not journal.snapshot().endings.has(ending), "결말 확인/영구 기록 실패는 완주·엔딩 지급 차단"): return
				runner.force_emit_metrics()
				if not _check(recorder.summary_snapshot().completed_run_count == 0 and not runner.current_metrics().run_complete and controls.story_scene.id == FinalRitual.ENDING_SCENE, "저장 실패 뒤 추가 갱신에도 미완료·엔딩 장면 유지"): return
				store.save_path = path
				if phase == "ending-fault":
					if not _check(before == store.load_checkpoint() and runner.final_ritual.phase == FinalRitual.ENDING, "확인 실패 상태·파일 복원"): return
				else:
					if not _check(store.load_checkpoint().stage.final_ritual.phase == FinalRitual.SEEN and not sandbox._on_final_action("back"), "저널 실패 뒤 확정 결말 보존·다른 선택 차단"): return
				if phase != "fault-seed":
					journal.fail_writes = false
					if not _check(sandbox._acknowledge_story(FinalRitual.ENDING_SCENE), "엔딩 재시도 · " + controls.story_message + " active=" + str(growth.run_active)) or not _gp321_final_recorded(ending, character, choice): return
		"story-off":
			if journal.record_ending("prior-arrival", ArrivalEnding.ID, character, choice) != OK or not _prepare_sera(character, weapon, "rescue"): return
			sandbox.story_run.restore({})
			if not _enter_sera(false) or not _finish_stage() or not sandbox._resolve_boss_choice(choice) or not await _basic_clear(weapon): return
			if not _gp321_choices_pending() or not _check(FinalRitual.can_choose(runner.final_ritual, "liberation"), "이야기 꺼짐도 핵심 기억·선택 가능·자동 완주 금지") or not _gp321_select_final("liberation") or not _check(controls.story_scene.lines.size() == 2, "이야기 꺼짐 간결한 결말 확인") or not _gp321_confirm_final() or not _gp321_final_recorded("liberation", character, choice): return
		_:
			_check(false, "알 수 없는 최종 엔딩 검사")
			return
	paused = false
	sandbox.free()
	print("GP-321 runtime test: OK (%s %s %s %s %s)" % [phase, character, weapon, choice, ending])
	quit(0)

func _gp321_enter_choices(character: String, weapon: String, choice: String) -> bool:
	if not _check(_enter_heart(character, weapon, choice), "최종 선택 검사 심장 진입"): return false
	if not await _basic_clear(weapon): return false
	if not _check(sandbox._acknowledge_story(HeartEncounter.VICTORY_SCENE), "최종 선택 검사 승리 확인 · " + controls.story_message): return false
	return _gp321_choices_pending()

func _gp321_choices_pending() -> bool:
	return _check(controls.current_screen_mode() == 18 and controls.story_scene.get("id") == FinalRitual.CHOICE_SCENE and runner.final_ritual.phase == FinalRitual.CHOOSING and paused and growth.run_active and not runner.current_metrics().run_complete and recorder.summary_snapshot().completed_run_count == 0 and store.load_checkpoint().stage.final_ritual.phase == FinalRitual.CHOOSING, "심장 승리 뒤 최종 선택 저장·확정 전 완주 차단")

func _gp321_visit_secret() -> bool:
	var layout := FinalRitual.layout(controls._safe_area_in_viewport())
	_tap(layout.cards[2].get_center())
	if not _check(controls.final_selected.is_empty() and not sandbox._on_final_action("dawn"), "비밀 기록 이전 새벽 잠금"): return false
	_tap(layout.secret.get_center())
	if not _check(controls.story_scene.id == FinalRitual.SECRET_SCENE, "실제 비밀 기록실 입장"): return false
	_tap(PrototypeStoryView.scene_layout(controls._safe_area_in_viewport()).skip.get_center())
	return _check(controls.story_scene.id == FinalRitual.CHOICE_SCENE and runner.final_ritual.secret and journal.snapshot().secrets.has(FinalRitual.SECRET_SCENE), "비밀 기록 영구 저장·새벽 조건 해금")

func _gp321_select_final(id: String) -> bool:
	var layout := FinalRitual.layout(controls._safe_area_in_viewport())
	_tap(layout.cards[FinalRitual.IDS.find(id)].get_center())
	if not _check(controls.final_selected == id and runner.final_ritual.choice == "", "카드 선택만으로는 확정·기록 없음"): return false
	_tap(layout.confirm.get_center())
	return _gp321_ending_pending(id)

func _gp321_ending_pending(id: String) -> bool:
	return _check(controls.story_scene.get("id") == FinalRitual.ENDING_SCENE and runner.final_ritual.phase == FinalRitual.ENDING and runner.final_ritual.choice == id and paused and growth.run_active and store.load_checkpoint().stage.final_ritual.choice == id and not journal.snapshot().endings.has(id), "선택 확인 뒤 결말 장면·체크포인트·영구 기록 대기")

func _gp321_confirm_final() -> bool:
	for i in 6:
		if controls.current_screen_mode() != 18: break
		_tap(PrototypeStoryView.scene_layout(controls._safe_area_in_viewport()).next.get_center())
	return _check(controls.current_screen_mode() == 1, "장면 마지막 확인 후 결과 화면")

func _gp321_final_recorded(id: String, character: String, choice: String) -> bool:
	var progress := journal.snapshot()
	if not _check(progress.endings.has(id) and progress.endings[id].character == character and progress.endings[id].choice == choice and progress.endings.arrival.run_id == "prior-arrival" and recorder.summary_snapshot().completed_run_count == 1 and controls.current_result_snapshot().ending_id == id and store.load_checkpoint().is_empty(), "선택 엔딩·도착 최초 기록·한 번 완주·결과·저장 정리"): return false
	var recent: Dictionary = recorder.summary_snapshot().recent_runs[0]
	if not _check(recent.ending_id == id and not sandbox._acknowledge_story(FinalRitual.ENDING_SCENE), "최근 이력 엔딩·중복 확인 차단"): return false
	var cards := PrototypeStory.journal_cards(2, progress, character)
	if not _check(cards.size() == 4 and cards.any(func(card: Dictionary) -> bool: return card.id == id and card.open), "수첩 4종 엔딩 영구 열람"): return false
	var before := FileAccess.get_file_as_string(journal.save_path)
	if not controls.open_story_journal(): return _check(false, "결과에서 수첩 열기")
	controls.story_journal_tab = 2
	controls.story_journal_page = 1 if id == "dawn" else 0
	var book: Dictionary = controls.story_journal_snapshot()
	for i in book.cards.size():
		if book.cards[i].id == id: _tap(book.layout.cards[i].get_center())
	if not _check(controls.story_scene.get("journal_replay") == true and controls.current_screen_mode() == 18 and paused, "발견한 엔딩 카드 터치로 전체 장면 다시 읽기"): return false
	var back := InputEventKey.new()
	back.keycode = KEY_ESCAPE
	back.pressed = true
	controls._input(back)
	if not _check(controls.current_screen_mode() == 19 and paused and before == FileAccess.get_file_as_string(journal.save_path) and recorder.summary_snapshot().completed_run_count == 1, "재열람 뒤 수첩 복귀·기록/완주 불변"): return false
	controls.close_story_journal()
	return _check(controls.current_screen_mode() == 1 and not paused, "수첩 닫기 뒤 결과·일시정지 복원")

func _gp321_validate_ritual() -> bool:
	var saved := store.load_checkpoint()
	for value in [null, [], true, {}, {"phase": "unknown"}]:
		var bad := saved.duplicate(true)
		bad.stage.final_ritual = value
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and saved == store.load_checkpoint(), "잘못된 최종 선택 상태·타입 거부"): return false
	for mutation in ["choice", "phase", "memories", "rewinds", "secret", "history"]:
		var bad := saved.duplicate(true)
		match mutation:
			"choice": bad.stage.final_ritual.choice = "dawn"
			"phase": bad.stage.final_ritual.phase = FinalRitual.SEEN
			"memories": bad.stage.final_ritual.memories = ["unknown"]
			"rewinds": bad.stage.final_ritual.rewinds = true
			"secret": bad.stage.final_ritual.secret = 1
			"history": bad.stage.history[-1].ending_id = "return"
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and saved == store.load_checkpoint(), "불일치 결말/기억/이력 저장 거부"): return false
	var gates := FinalRitual.initial(2)
	if not _check(not FinalRitual.can_choose(gates, "return") and not FinalRitual.can_choose(gates, "liberation") and not FinalRitual.can_choose(gates, "dawn"), "기억/되감기 미충족 차단"): return false
	gates.rewinds = 3
	if not _check(FinalRitual.can_choose(gates, "return"), "되감기 3회 경계"): return false
	gates.memories = FinalRitual.CORE_MEMORIES.duplicate()
	return _check(FinalRitual.can_choose(gates, "liberation") and not FinalRitual.can_choose(gates, "dawn"), "핵심 기억 해방·10종 전 새벽 잠금")

func _gp321_ritual_layout(character: String, choice: String, args: PackedStringArray) -> bool:
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		controls._refresh_layout()
		for i in 3: await process_frame
		var safe: Rect2 = controls._safe_area_in_viewport()
		var layout := FinalRitual.layout(safe)
		for rect in layout.cards + [layout.secret, layout.confirm]:
			if not _check(safe.encloses(rect), "선택 카드/버튼 두 화면비 안전 영역"): return false
		var paragraphs: Array = PrototypeStoryView.scene_layout(safe).paragraphs
		for id in FinalRitual.IDS:
			var state := runner.final_ritual.duplicate(true)
			state.choice = id
			state.phase = FinalRitual.ENDING
			for line in FinalRitual.ending_scene(state, character, choice, false).lines:
				if not _check(PrototypeStoryView.wrap(line, ThemeDB.fallback_font, 22, paragraphs[0].size.x).size() * 28 <= paragraphs[0].size.y, "엔딩 한국어 대사 높이"): return false
		if args.size() > 5:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(args[5] + "-" + str(dimensions.x) + ".png")
	return true
