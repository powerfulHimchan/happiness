extends "res://tests/gp312_runtime_test.gd"

func _run() -> void:
	auto_guardian_choice = false
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var character := args[1]
	var weapon := args[2]
	var choice := "rescue" if character == "roan" else "destroy"
	var continuing := phase in ["pending", "acknowledged", "finish"]
	var prefix := "user://gp314_%s_%s_%s" % ["flow" if phase == "seed" or continuing else phase, character, weapon]
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
			if not _prepare_reunion(character, weapon, choice): return
			player.damage_receiver.health = 83
			festival_ultimate.gauge = 37
			weapons.sword_combat._skill_1_cooldown_s = 3.25
			if not _check(sandbox._save_checkpoint(runner.current_metrics(), false) == OK and store.load_checkpoint().story.pending == "stage:10" and not journal.snapshot().fragments.has("queen_pendant"), "재회 대기 저장·미확인 새 조각은 미발견"): return
		"pending":
			if not _restore_journey(10) or not _check_reunion(character, choice): return
			var saved := store.load_checkpoint()
			var before := [player.damage_receiver.health, festival_ultimate.gauge, weapons.sword_combat._skill_1_cooldown_s, runner.stage_elapsed_s]
			if not _check(not sandbox._resolve_boss_choice("rescue") and not sandbox._acknowledge_story("stage:9"), "재회 확인 전 선택·잘못된 장면 ID 거부"): return
			_tap(PrototypeStoryView.scene_layout(controls._safe_area_in_viewport()).next.get_center())
			runner.set_process(true)
			weapons.sword_combat.set_process(true)
			for ignored in 3: await physics_frame
			runner.set_process(false)
			weapons.sword_combat.set_process(false)
			if not _check(controls.story_page == 1 and before == [player.damage_receiver.health, festival_ultimate.gauge, weapons.sword_combat._skill_1_cooldown_s, runner.stage_elapsed_s] and store.load_checkpoint() == saved and not journal.snapshot().fragments.has("queen_pendant"), "페이지 이동·정지 중 잔량·파일 불변"): return
			if not _restore_journey(10) or not _check(controls.story_page == 0, "중간 종료·이어하기는 같은 재회 처음부터"): return
		"acknowledged":
			if not _restore_journey(10) or not _check_reunion(character, choice): return
			var health := player.damage_receiver.health
			var gauge := festival_ultimate.gauge
			if not _ack_scene(weapon == "bow"): return
			if not _check(controls.current_screen_mode() == 12 and paused and journal.snapshot().fragments.has("queen_pendant") and journal.snapshot().fragments.size() == 9 and sandbox.story_run.seen[-1] == "stage:10" and player.damage_receiver.health == health and festival_ultimate.gauge == gauge and RunCheckpointStore.valid_state(store.load_checkpoint()), "끝까지 읽기/건너뛰기에서9종 저장·기존 기사 선택 복귀"): return
		"finish":
			if not _restore_journey(10) or not _check(controls.current_screen_mode() == 12 and sandbox.story_run.pending.is_empty() and player.damage_receiver.health == 83 and festival_ultimate.gauge == 37 and weapons.sword_combat._skill_1_cooldown_s == 3.25, "확인된 장면 이어하기는 재표시 없이 잔량 복원"): return
			var raw := FileAccess.get_file_as_string(journal.save_path)
			if not _check(not sandbox._acknowledge_story("stage:10") and FileAccess.get_file_as_string(journal.save_path) == raw, "중복 확인·기억 재지급 거부"): return
			if not sandbox._resolve_boss_choice("destroy" if choice == "rescue" else "rescue"): return
			if not _check(recorder.summary_snapshot().completed_run_count == 1 and controls.current_result_snapshot().stage_count == 10 and journal.snapshot().fragments.size() == 9 and store.load_checkpoint().is_empty(), "기존 선택·결과·단일 완주·저장 정리"): return
			if not _journal_reopen(character): return
		"fragment-fault", "checkpoint-fault":
			if not _prepare_reunion(character, weapon, choice): return
			var saved := store.load_checkpoint()
			var before: Dictionary = sandbox.story_run.snapshot()
			var journal_path := journal.save_path
			var checkpoint_path := store.save_path
			if phase == "fragment-fault": journal.save_path = "user://gp314_missing/story.jsonl"
			else: store.save_path = "user://gp314_missing/checkpoint.json"
			if not _check(not sandbox._acknowledge_story("stage:10") and controls.current_screen_mode() == 18 and paused and sandbox.story_run.snapshot() == before and not controls.story_message.is_empty(), "쓰기 실패는 장면·확인 대기·정지 유지"): return
			journal.save_path = journal_path
			store.save_path = checkpoint_path
			if not _check(store.load_checkpoint() == saved and _ack_scene(true), "정상 저장 보존·실제 입력 재시도"): return
			var raw := FileAccess.get_file_as_string(journal.save_path)
			if not _restore_journey(10) or not _check(journal.snapshot().fragments.has("queen_pendant") and FileAccess.get_file_as_string(journal.save_path) == raw and controls.current_screen_mode() == 12, "부분 성공 복구에서도 기억 중복 기록 없음"): return
		"legacy-pending", "legacy-seen":
			if not _prepare_reunion(character, weapon, choice): return
			if phase == "legacy-seen":
				sandbox.story_run.acknowledge()
				if sandbox._save_checkpoint(runner.current_metrics(), false) != OK: return
			if not _check(JSON.parse_string(FileAccess.get_file_as_string(store.save_path)).version == 1 and not journal.snapshot().fragments.has("queen_pendant"), "기존8종 버전1 완료 저장 보존"): return
			if not _restore_journey(10): return
			if phase == "legacy-pending":
				if not _check_reunion(character, choice) or not _ack_scene(true): return
			else:
				if not _check(controls.current_screen_mode() == 12 and sandbox.story_run.pending.is_empty(), "이전 확인된 저장은 재회 강제 재표시 없음"): return
			if not sandbox._resolve_boss_choice("rescue"): return
			if not _check(store.load_checkpoint().is_empty() and recorder.summary_snapshot().completed_run_count == 1, "이전 저장에서도 선택·완주 정상"): return
		"rules":
			if not _prepare_reunion(character, weapon, choice) or not _content_rules(character): return
			controls.begin_retry(weapon, 10, "journey", character, false)
			while runner.stage_number < 10:
				if not _finish_stage(): return
				if runner.awaiting_guardian_choice() and not sandbox._resolve_guardian_choice("rescue"): return
				if not sandbox._claim_weapon_reward("") or not _next_without_layout(): return
			if not _finish_stage() or not _check(controls.current_screen_mode() == 12 and not sandbox.story_run.enabled and not journal.snapshot().fragments.has("queen_pendant"), "이야기 꺼짐은 재회·새 기억 없음"): return
		"layout":
			if not _prepare_reunion(character, weapon, choice): return
			if not await _reunion_layout(args): return
		_:
			_check(false, "알 수 없는 재회 검사")
			return
	paused = false
	sandbox.free()
	print("GP-314 runtime test: OK (%s %s %s)" % [phase, character, weapon])
	quit(0)

func _prepare_reunion(character: String, weapon: String, choice: String) -> bool:
	if not _prepare_guardian_choice(character, weapon) or not _ack_scene(true) or not _select_choice(choice): return false
	if not sandbox._claim_weapon_reward("") or not _next_without_layout(): return false
	var cards := PrototypeRunBuildView.cards(2, sandbox._capture_run_build())
	if not _check(cards.any(func(card: Dictionary) -> bool: return card.id == "story" and card.status == "기억 조각 7/10"), "현재 도전 정보에 새 기억 총수 반영"): return false
	if not _finish_stage(): return false
	return _check_reunion(character, choice)

func _check_reunion(character: String, choice: String) -> bool:
	var scene: Dictionary = controls.story_scene
	return _check(controls.current_screen_mode() == 18 and paused and runner.awaiting_boss_choice() and scene.id == "stage:10" and scene.name == "시계탑 아래의 재회" and scene.portrait == "sera" and scene.speaker == "미소의 여왕 세라" and scene.lines.size() == 6 and scene.lines[0].contains(PrototypeCharacters.display_name(character)) and scene.lines[-1].contains("수호기사" if choice == "rescue" else "성문을 막던 힘"), "실제 중심부 재회·주인공·성문 선택 대사·세라 외형")

func _journal_reopen(character: String) -> bool:
	controls.show_main_screen()
	controls.open_story_journal()
	var raw := FileAccess.get_file_as_string(journal.save_path)
	var layout := PrototypeStoryView.journal_layout(controls._safe_area_in_viewport(), 3)
	for ignored in 2: _tap(layout.next.get_center())
	var cards := PrototypeStory.journal_cards(0, journal.snapshot(), character)
	return _check(controls.story_journal_page == 2 and cards[8].id == "queen_pendant" and cards[8].open and cards[8].name == "여왕의 시계 장식" and FileAccess.get_file_as_string(journal.save_path) == raw, "실제 수첩3페이지·새 기억·조회 불변")

func _content_rules(character: String) -> bool:
	var history := runner.stage_history.duplicate(true)
	var first := PrototypeStory.scene("stage:10", history, character, [], 0, 10)
	var repeat := PrototypeStory.scene("stage:10", history, character, ["queen_pendant"], 0, 10)
	if not _check(first.lines[3] != repeat.lines[3] and repeat.lines[3].contains("지난 여행"), "기발견 재회는 반복 단서 대사"): return false
	if not _check(PrototypeStory.earned(history.slice(0, 9), 10).size() == 7 and not PrototypeStory.earned(history.slice(0, 9), 10).has("queen_pendant"), "성문까지 새 기억 해금 없음"): return false
	for limit in [3, 5]:
		var regular: Array[Dictionary] = [{"stage": limit, "route": "meadow"}]
		if not _check(PrototypeStory.scene("stage:%d" % limit, regular, character, [], 0, limit).name == "기사에게 남은 명령" and not PrototypeStory.earned(regular, limit).has("queen_pendant"), "일반3/5 최종 기사 이야기 유지"): return false
	var locked: Dictionary = PrototypeStory.journal_cards(0, {"fragments": {}}, character)[8]
	return _check(not locked.open and locked.lines == [PrototypeStory.FRAGMENTS.queen_pendant.hint, "아직 발견하지 않은 내용입니다"] and PrototypeStory.valid_ids(["queen_pendant"]) and not PrototypeStory.valid_ids(["queen_pendant", "queen_pendant"]), "미발견 수첩 조건·새 ID/중복 검증")

func _reunion_layout(args: PackedStringArray) -> bool:
	var saved := store.load_checkpoint()
	for dimensions in [Vector2(1280, 720), Vector2(1600, 720)]:
		root.content_scale_size = Vector2i(dimensions)
		root.size = Vector2i(dimensions)
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(Vector2i(dimensions))
		controls.size = dimensions
		var safe: Rect2 = controls._safe_area_in_viewport()
		var layout := PrototypeStoryView.scene_layout(safe)
		for rect in [layout.portrait, layout.speaker, layout.next, layout.skip] + layout.paragraphs:
			if not _check(safe.encloses(rect), "두 화면비 모든 재회 요소 안전 영역"): return false
		if not _check(not layout.portrait.intersects(layout.paragraphs[0]) and not layout.speaker.intersects(layout.paragraphs[1]) and not layout.next.intersects(layout.skip), "초상·이름·본문·버튼 비중첩"): return false
		for page in 3:
			controls.story_page = page
			for i in 2:
				var wrapped := PrototypeStoryView.wrap(controls.story_scene.lines[page * 2 + i], ThemeDB.fallback_font, 22, layout.paragraphs[i].size.x)
				if not _check(wrapped.size() * 28 <= layout.paragraphs[i].size.y, "모든 페이지 한글 줄 높이가 본문 영역 안"): return false
			controls.queue_redraw()
			await process_frame
			if args.size() > 3 and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(args[3] + "/gp314-%d-page%d.png" % [int(dimensions.x), page])
	return _check(store.load_checkpoint() == saved and not journal.snapshot().fragments.has("queen_pendant"), "화면비·페이지 조회는 저장·미발견 불변")

func _check(condition: bool, label: String) -> bool:
	if condition: return true
	push_error("GP-314 실패: " + label)
	paused = false
	quit(1)
	return false
