extends "res://tests/gp257_266_runtime_test.gd"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var character := args[1] if args.size() > 1 else "lumi"
	var weapon := args[2] if args.size() > 2 else "sword"
	var isolated := phase in ["preview", "balance", "fault", "validate", "records"]
	var prefix := "user://gp276_%s_%s_%s" % [phase if isolated else "legacy" if phase.begins_with("legacy") else "flow", character, weapon]
	store.save_path = prefix + "_checkpoint.json"
	legacy.save_path = prefix + "_meta.jsonl"
	if isolated or phase in ["seed", "legacy-seed"]:
		store.clear_checkpoint()
		for suffix in ["_meta.jsonl", "_records.jsonl", "_abilities.jsonl"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
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
	for actor in [player, weapons, weapons.sword_combat, weapons.bow_combat, festival_ultimate, runner, sandbox.get_node("ClockTrapController"), sandbox.get_node("RouteTerrain")]:
		actor.set_process(false)
		actor.set_physics_process(false)
	growth.jobs_enabled = false
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	match phase:
		"seed", "legacy-seed":
			if not _start_character(character, weapon): return
			if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			var saved := store.load_checkpoint()
			if not _check(saved.player.character_id == character and RunCheckpointStore.VERSION == 1 and player.avatar_sprite.texture == PrototypeCharacters.texture(character), "실제 정예 저장·선택 외형·버전1"): return
			if phase == "legacy-seed":
				saved.player.erase("character_id")
				if not _check(store.save_checkpoint(saved) == OK, "주인공 필드 없는 이전 저장 준비"): return
				var old_events: Array[String] = []
				for line in FileAccess.get_file_as_string(recorder.record_path).split("\n", false):
					var event: Dictionary = JSON.parse_string(line)
					event.erase("character_id")
					old_events.append(JSON.stringify(event))
				var file := FileAccess.open(recorder.record_path, FileAccess.WRITE)
				file.store_string("\n".join(old_events) + "\n")
				file.close()
		"resume", "finish", "legacy":
			var saved := store.load_checkpoint()
			var expected := "roan" if phase == "legacy" else character
			for ignored in 2:
				controls.show_main_screen()
				controls.selected_character_id = "lumi" if expected == "roan" else "roan"
				if not _check(sandbox.continue_saved_run() and player.character_id == expected and controls.selected_character_id == expected and player.avatar_sprite.texture == PrototypeCharacters.texture(expected) and player.damage_receiver.health == saved.player.health and weapons.active_weapon_id == saved.weapons.active and festival_ultimate.gauge == saved.ultimate.gauge, "별도 프로세스 반복 복원·준비 선택과 독립·잔량 유지"): return
			if phase == "resume":
				_tap(controls.stage_route_rects[0].get_center())
				if not await _test_character_info(expected): return
				if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
				if not _check(store.load_checkpoint().player.character_id == expected and runner.stage_number == 2, "다음 지역에도 캐릭터·저장 유지"): return
			else:
				while runner.stage_number < runner.stage_limit:
					_tap(controls.stage_route_rects[0].get_center())
					if not _finish_stage(): return
					if runner.stage_number < runner.stage_limit and not sandbox._claim_weapon_reward(""): return
				if not _check(store.load_checkpoint().player.character_id == expected and runner.awaiting_boss_choice(), "보스 선택 대기에도 주인공 저장"): return
				if not _check(sandbox._resolve_boss_choice("rescue" if weapon == "sword" else "destroy"), "구출·파괴 확정"): return
				var result: Dictionary = controls.current_result_snapshot()
				var summary := recorder.summary_snapshot()
				if not _check(result.character_id == expected and summary.recent_runs[0].character_id == expected and summary.run_count == 1 and summary.completed_run_count == 1 and store.load_checkpoint().is_empty(), "결과·동일 도전 이력·단일 완주·저장 정리"): return
				controls.show_start_weapon_selection()
				_tap(controls.character_open_rect.get_center())
				_tap(controls.character_card_rects[1 if expected == "roan" else 0].get_center())
				if not controls.character_detail_open: _tap(controls.character_card_rects[PrototypeCharacters.IDS.find(controls.selected_character_id)].get_center())
				_tap(controls.character_confirm_rect.get_center())
				_tap(controls.start_weapon_cancel_rect.get_center())
				if not _check(controls.current_screen_mode() == 1 and player.character_id == expected and controls.selected_character_id == expected, "실제 결과의 재도전 준비·주인공 변경 취소"): return
				recorder.reload_records_for_test()
				controls.show_main_screen()
				controls.show_village()
				controls.village_page = "history"
				if not _check(controls.village_snapshot().cards[0].lines.has("주인공 · " + PrototypeCharacters.display_name(expected)), "광장 다시 로드한 주인공 기록"): return
				controls.begin_retry(weapon, 3)
				if not _check(player.character_id == "roan" and player.avatar_sprite.texture == PrototypeCharacters.ROAN_TEXTURE and not runner.current_metrics().has("character_id"), "기존 API 기본 로안·새 도전 외형 초기화"): return
		"preview":
			if not await _test_character_preview(character): return
		"balance":
			if not _test_character_balance(weapon): return
		"fault":
			var original := "roan" if character == "lumi" else "lumi"
			controls.begin_retry(weapon, 3, "standard", original)
			if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			var saved := store.load_checkpoint()
			var id := String(recorder.checkpoint_snapshot().id)
			if not _check(legacy.grant("gp276-next-reward", "rescue") == OK, "실제 다음 도전 보상 준비"): return
			sandbox._update_boss_legacy_status()
			legacy.fail_writes = true
			if not _prepare_character(character, weapon, 0): return
			_tap(controls.start_weapon_confirm_rect.get_center())
			if not _check(controls.current_screen_mode() == 2 and player.character_id == original and player.avatar_sprite.texture == PrototypeCharacters.texture(original) and String(recorder.checkpoint_snapshot().id) == id and store.load_checkpoint() == saved and legacy.pending_reward().choice == "rescue", "보상 소비 저장 실패는 기존 캐릭터·도전·체크포인트 유지"): return
			legacy.fail_writes = false
			if not _start_character(character, weapon): return
			if not _check(player.boss_legacy.choice == "rescue" and legacy.pending_reward().is_empty() and recorder.summary_snapshot().run_count == 2, "다시 시작 성공 때 캐릭터 변경·보상1회 소비"): return
		"validate":
			if not _start_character(character, weapon) or not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			var saved := store.load_checkpoint()
			var raw := FileAccess.get_file_as_string(store.save_path)
			for value in [null, true, 1, 1.5, "", "sera", "Lumi", [], {}, ["lumi"]]:
				var bad := saved.duplicate(true)
				bad.player.character_id = value
				if not _check(not RunCheckpointStore.valid_state(bad) and store.save_checkpoint(bad) == ERR_INVALID_DATA and FileAccess.get_file_as_string(store.save_path) == raw, "잘못된 캐릭터 저장 원자적 거부"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			var bad := store.load_checkpoint()
			bad.player.character_id = "unknown"
			var payload := JSON.stringify(bad)
			store._write(store.save_path, JSON.stringify({"version": 1, "payload": payload, "sha256": payload.sha256_text()}))
			if not _check(store.load_checkpoint().stage.number == 1 and store.load_checkpoint().player.character_id == character, "체크섬 맞는 캐릭터 변조도 이전 정상 백업 복구"): return
		"records":
			var events: Array[Dictionary] = [
				{"event": "run_started", "run_id": "old"},
				{"event": "run_started", "run_id": "new", "character_id": "lumi", "run_mode": "regions"},
				{"event": "run_resumed", "run_id": "new", "character_id": "roan", "stage_number": 2},
				{"event": "run_completed", "run_id": "new", "character_id": "lumi", "stage_count": 5, "boss_choice": "rescue"},
				{"event": "run_resumed", "run_id": "new", "character_id": "roan", "stage_number": 1},
			]
			for malformed in [null, true, {}, "sera"]:
				events.append({"event": "run_started", "run_id": str(malformed), "character_id": malformed})
			var recent := recorder._recent_runs(events)
			for run in recent:
				if not _check(run.character_id == ("lumi" if run.id == "new" else "roan"), "이전·잘못된 이력은 로안·이어하기 충돌로 주인공 변경 없음"): return
			var run: Dictionary = recent[4]
			if not _check(run.id == "new" and run.completed and run.completed_stages == 5 and run.run_mode == "regions", "완주 이후 이어하기가 결과·지역모드 변경 없음"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-267–276 runtime test: OK (%s %s %s)" % [phase, character, weapon])
	quit(0)

func _prepare_character(character: String, weapon: String, length_index: int) -> bool:
	controls.show_main_screen()
	controls.show_start_weapon_selection()
	_tap(controls.character_open_rect.get_center())
	if not _check(controls.current_screen_mode() == 17, "실제 주인공 변경 버튼"): return false
	_tap(controls.character_card_rects[0 if character == "roan" else 1].get_center())
	if not controls.character_detail_open: _tap(controls.character_card_rects[PrototypeCharacters.IDS.find(controls.selected_character_id)].get_center())
	_tap(controls.character_confirm_rect.get_center())
	_tap(controls.start_weapon_card_rects[0 if weapon == "sword" else 1].get_center())
	controls.open_preparation_options()
	_tap(controls.start_length_rects[length_index].get_center())
	controls.close_preparation_options()
	return _check(controls.current_screen_mode() == 10 and controls.selected_character_id == character, "주인공 확정은 준비로 복귀·무기·길이 선택")

func _start_character(character: String, weapon: String) -> bool:
	if not _prepare_character(character, weapon, 2 if character == "lumi" else 0): return false
	_tap(controls.start_weapon_confirm_rect.get_center())
	return _check(player.character_id == character and controls.current_screen_mode() == 0 and player.avatar_sprite.texture == PrototypeCharacters.texture(character) and weapons.active_weapon_id == weapon and growth.run_active, "실제 로안·루미 검·활 시작")

func _test_character_preview(character: String) -> bool:
	controls.begin_retry("bow", 3, "standard", character)
	if not _finish_stage() or not sandbox._claim_weapon_reward(""): return false
	var saved := store.load_checkpoint()
	var records := recorder.checkpoint_snapshot()
	var journal := FileAccess.get_file_as_string(legacy.save_path)
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls.show_main_screen()
		if dimensions.x > 2000: controls.show_village()
		controls.show_start_weapon_selection()
		if not _check(controls.layout_snapshot().safe.encloses(controls.character_open_rect) and ThemeDB.fallback_font.get_string_size("주인공 · 루미 · 변경", HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x < controls.character_open_rect.size.x - 16, "준비 변경 버튼 안전 영역·실제 글꼴 너비"): return false
		for rect in controls.start_length_rects + controls.start_weapon_card_rects + controls.memory_card_rects + [controls.start_weapon_confirm_rect, controls.start_weapon_cancel_rect, controls.boss_legacy_toggle_rect]:
			if not _check(not controls.character_open_rect.intersects(rect), "변경 버튼과 기존 준비 입력 비중첩"): return false
		_tap(controls.character_open_rect.get_center())
		var rects: Array = controls.character_card_rects.duplicate()
		rects.append_array([controls.character_cancel_rect])
		var safe: Rect2 = controls.layout_snapshot().safe
		for i in rects.size():
			if not _check(safe.encloses(rects[i]), "두 화면비 주인공 카드·버튼 안전 영역"): return false
			for j in range(i + 1, rects.size()):
				if not _check(not rects[i].intersects(rects[j]), "주인공 입력 비중첩"): return false
		if not _check(not controls.character_confirm_rect.has_area(), "주인공 미선택 시 다음 입력 없음"): return false
		_tap(controls.character_card_rects[1 if character == "roan" else 0].get_center())
		controls.notification(Control.NOTIFICATION_APPLICATION_PAUSED)
		controls.notification(Control.NOTIFICATION_APPLICATION_RESUMED)
		controls.queue_redraw()
		await process_frame
		if not _check(controls.selected_character_id != character and player.character_id == character and controls.command_buffer.pending_count() == 0, "미리보기·앱 복귀는 현재 도전 변경·입력 누적 없음"): return false
		if controls.character_detail_open: _tap(controls.character_cancel_rect.get_center())
		if dimensions.x > 2000:
			var back := InputEventKey.new()
			back.pressed = true
			back.keycode = KEY_ESCAPE
			controls._input(back)
		else: _tap(controls.character_cancel_rect.get_center())
		if not _check(controls.selected_character_id == character and controls.current_screen_mode() == 10, "선택 취소로 원래 준비 주인공 복구"): return false
		_tap(controls.character_open_rect.get_center())
		_tap(controls.character_card_rects[1 if character == "roan" else 0].get_center())
		if not controls.character_detail_open: _tap(controls.character_card_rects[PrototypeCharacters.IDS.find(controls.selected_character_id)].get_center())
		_tap(controls.character_confirm_rect.get_center())
		_tap(controls.start_weapon_cancel_rect.get_center())
		if not _check(controls.selected_character_id == character and player.character_id == character and store.load_checkpoint() == saved and recorder.checkpoint_snapshot() == records and FileAccess.get_file_as_string(legacy.save_path) == journal, "준비 전체 취소도 기존 캐릭터·보상·저장 보존"): return false
	return true

func _test_character_balance(weapon: String) -> bool:
	var baseline: Dictionary = {}
	for character in PrototypeCharacters.IDS:
		for selection in [[3, "standard"], [5, "standard"], [5, "regions"]]:
			controls.begin_retry(weapon, selection[0], selection[1], character)
			if not _check(runner.stage_limit == selection[0] and runner.run_mode == selection[1] and player.character_id == character, "두 주인공 모든 길이·모드 조합"): return false
		controls.begin_retry(weapon, 3, "standard", character)
		player.set_move_vector(Vector2(-1, 0))
		if not _check(player.avatar_sprite.flip_h and player.avatar_sprite.texture == PrototypeCharacters.texture(character), "선택 외형 좌향 유지"): return false
		player.set_move_vector(Vector2(1, 0))
		_hit_player(17, "gp276-%s" % character)
		player.damage_receiver.tick(1.0)
		player._update_avatar_action_visual()
		if not _check(not player.avatar_sprite.flip_h and player.damage_receiver.health == 83 and player.movement_animation.state == "hit" and (player.avatar_sprite.texture as AtlasTexture).atlas == HeroMovementAnimation.SHEETS[character], "우향·실제 피해17·피격 외형 유지"): return false
		var state: Dictionary = sandbox._capture_run_build()
		state.erase("character_id")
		state.erase("hero_trait")
		if baseline.is_empty(): baseline = state
		elif not _check(state == baseline, "두 주인공 미발동 시 공통 생존·피해·성장·스킬·필살기 동일"): return false
	var id := String(recorder.checkpoint_snapshot().id)
	if not _check(not controls.begin_retry(weapon, 3, "standard", "sera") and not player.set_character("sera") and String(recorder.checkpoint_snapshot().id) == id and player.character_id == "lumi", "미지원 주인공 API 무변경 거부"): return false
	controls.show_character_selection()
	return _check(controls.current_screen_mode() == 0 and player.character_id == "lumi", "전투 중 주인공 교체 화면 차단")

func _test_character_info(character: String) -> bool:
	var saved := store.load_checkpoint()
	controls.open_run_build()
	var state: Dictionary = controls.run_build_state
	var cards := PrototypeRunBuildView.cards(2, state)
	if not _check(state.character_id == character and cards[0].lines.has("주인공 · " + PrototypeCharacters.display_name(character)) and controls.movement_metrics.character_id == character, "HUD·현재 도전 정보는 실제 주인공"): return false
	for ignored in 3: await process_frame
	if not _check(paused and store.load_checkpoint() == saved and player.character_id == character, "정보 조회 중 전투 정지·주인공·저장 보존"): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(3.1)
	return _check(not paused and player.character_id == character, "복귀 카운트다운 뒤 동일 주인공")
