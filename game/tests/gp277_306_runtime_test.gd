extends "res://tests/gp267_276_runtime_test.gd"

var journal := FailingStoryJournal.new()

class FailingStoryJournal extends StoryJournalStore:
	var fail_writes: bool = false
	func _append(event: Dictionary) -> Error:
		return ERR_CANT_CREATE if fail_writes else super._append(event)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var character := args[1] if args.size() > 1 else "lumi"
	var weapon := args[2] if args.size() > 2 else "sword"
	var isolated := phase in ["preview", "fragment-fault", "checkpoint-fault", "rewind-fault", "validate", "corruption", "death", "reader", "orders", "jobs"]
	var prefix := "user://gp306_%s_%s_%s" % [phase if isolated else "legacy" if phase.begins_with("legacy") else "chronicle" if phase.begins_with("chronicle") else "flow", character, weapon]
	store.save_path = prefix + "_checkpoint.json"
	legacy.save_path = prefix + "_meta.jsonl"
	if isolated or phase in ["seed", "legacy-seed", "chronicle-seed"]:
		store.clear_checkpoint()
		for suffix in ["_meta.jsonl", "_records.jsonl", "_abilities.jsonl", "_story.jsonl"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	journal.save_path = prefix + "_story.jsonl"
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
	for actor in [player, weapons, weapons.sword_combat, weapons.bow_combat, festival_ultimate, runner, sandbox.get_node("ClockTrapController"), sandbox.get_node("RouteTerrain")]:
		actor.set_process(false)
		actor.set_physics_process(false)
	growth.jobs_enabled = false
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	match phase:
		"seed":
			if not _start_story(character, weapon): return
			if not _check(paused and sandbox.story_run.pending == "prologue" and player.character_id == character and sandbox.story_run.known.is_empty(), "프롤로그에서 실제 전투 정지"): return
			if not await _check_scene_layout(): return
			if not _ack_scene(false) or not _finish_stage(): return
			var saved := store.load_checkpoint()
			if not _check(saved.story.pending == "stage:1" and saved.story.seen == ["prologue"] and controls.current_screen_mode() == 18 and journal.snapshot().fragments.is_empty(), "첫 완료 장면 대기·체크포인트·조각 확인 전 상태"): return
		"resume1", "resume2", "finish":
			var saved := store.load_checkpoint()
			for ignored in 2:
				controls.show_main_screen()
				controls.selected_story_enabled = false
				var restored: bool = sandbox.continue_saved_run()
				if not _check(restored and _same_story(saved.story) and controls.current_screen_mode() == 18 and paused and player.character_id == character and player.damage_receiver.health == saved.player.health and festival_ultimate.gauge == saved.ultimate.gauge, "별도 프로세스 반복 복원·같은 장면/주인공·잔량 유지"): return
			if phase == "finish":
				if not _ack_scene(true): return
				if not _check(controls.current_screen_mode() == 12 and sandbox._resolve_boss_choice("rescue" if weapon == "sword" else "destroy"), "보스 장면 후 실제 구출/파괴"): return
				if not _check_story_result(character, weapon): return
			else:
				if not _ack_scene(phase == "resume1") or not sandbox._claim_weapon_reward(""): return
				_tap(controls.stage_route_rects[0 if runner.run_mode == "regions" else 1 if phase == "resume1" else 2].get_center())
				if not _check(not paused and runner.stage_number == (2 if phase == "resume1" else 3) and sandbox.story_run.pending.is_empty(), "장면→무기 보상→경로 선택·전투 복귀"): return
				if not _test_story_info(): return
				if not _finish_stage(): return
				if phase == "resume2":
					while runner.stage_number < runner.stage_limit:
						if not _ack_scene(true) or not sandbox._claim_weapon_reward(""): return
						_tap(controls.stage_route_rects[0].get_center())
						if not _finish_stage(): return
					if not _check(runner.awaiting_boss_choice() and store.load_checkpoint().story.pending == "stage:%d" % runner.stage_limit, "마지막 보스 장면 대기까지 저장"): return
		"records":
			var progress := journal.snapshot()
			var id := "regions_" if character == "lumi" else ""
			id += "rescue" if weapon == "sword" else "destroy"
			if not _check(progress.chronicles.has(id) and progress.chronicles[id].character == character and progress.fragments.size() == (8 if character == "lumi" else 4), "영구 조각8/4·여행 기록·실제 주인공 재실행 복원"): return
			if not await _test_journal(): return
			recorder.clear_records()
			controls.begin_retry()
			if not _check(not sandbox.story_run.enabled and journal.snapshot() == progress and recorder.summary_snapshot().run_count == 1, "테스트 이력 삭제·새 일반 도전은 기억 수첩 보존"): return
		"preview":
			if not await _test_story_preview(character): return
		"fragment-fault", "checkpoint-fault":
			if not _start_story(character, weapon) or not _ack_scene(true) or not _finish_stage(): return
			var saved := store.load_checkpoint()
			var path := store.save_path
			if phase == "fragment-fault": journal.fail_writes = true
			else: store.save_path = "user://gp306_missing/checkpoint.json"
			_tap(PrototypeStoryView.scene_layout(controls.layout_snapshot().safe).skip.get_center())
			if not _check(controls.current_screen_mode() == 18 and paused and _same_story(saved.story) and not controls.story_message.is_empty() and not sandbox._claim_weapon_reward(""), "조각/확인 저장 실패는 같은 장면·보상 차단·되돌림"): return
			journal.fail_writes = false
			store.save_path = path
			if not _check(store.load_checkpoint() == saved and _ack_scene(true) and sandbox._claim_weapon_reward("") and journal.snapshot().fragments.size() == 1, "원본 저장 보존·확인 재시도·조각 중복 없음"): return
		"chronicle-seed":
			if not _start_story(character, weapon) or not _ack_scene(true): return
			while true:
				if not _finish_stage() or not _ack_scene(true): return
				if runner.awaiting_boss_choice(): break
				if not sandbox._claim_weapon_reward(""): return
				_tap(controls.stage_route_rects[0].get_center())
			journal.fail_writes = true
			if not _check(sandbox._resolve_boss_choice("rescue") and controls.current_screen_mode() == 1 and not store.load_checkpoint().is_empty() and store.load_checkpoint().stage.boss_choice == "rescue" and journal.snapshot().chronicles.is_empty(), "기록 쓰기 실패에도 보스 선택/완주 먼저 보존·체크포인트 유지"): return
			var before := store.load_checkpoint()
			controls.begin_retry()
			if not _check(controls.current_screen_mode() == 2 and store.load_checkpoint() == before and recorder.summary_snapshot().run_count == 1, "실패한 기록을 지우는 새 도전 차단"): return
		"chronicle-resume":
			if not _check(store.load_checkpoint().is_empty() and journal.snapshot().chronicles.has("rescue") and journal.snapshot().completions.size() == 1 and recorder.summary_snapshot().completed_run_count == 1, "선택 확정 뒤 재실행은 여행 기록 회수·단일 완료·중간 저장 정리"): return
			var progress := journal.snapshot()
			sandbox._refresh_checkpoint()
			if not _check(journal.snapshot() == progress, "동일 확인은 여행 기록 중복 없음"): return
		"rewind-fault":
			controls.begin_retry()
			journal.fail_writes = true
			_hit_player(9999, "failed-rewind")
			if not _check(player.damage_receiver.dead and journal.snapshot().rewind_count == 0 and not sandbox._pending_rewind_ids.is_empty(), "사망 쓰기 실패는 소비되지 않은 기록으로 대기"): return
			controls.show_main_screen()
			controls.open_story_journal()
			journal.fail_writes = false
			_tap(controls.story_journal_snapshot().layout.retry.get_center())
			if not _check(journal.snapshot().rewind_count == 1 and sandbox._pending_rewind_ids.is_empty() and controls.story_journal_snapshot().error.is_empty(), "수첩 재시도로 실제 사망1회 복구"): return
		"death":
			for index in 3:
				controls.begin_retry(weapon, 3, "standard", character, index % 2 == 0)
				if sandbox.story_run.enabled and not _ack_scene(true): return
				var id := String(recorder.checkpoint_snapshot().id)
				_hit_player(9999, "rewind-%d" % index)
				var raw := FileAccess.get_file_as_string(journal.save_path)
				sandbox._on_story_death()
				if not _check(player.damage_receiver.dead and journal.snapshot().rewind_count == index + 1 and FileAccess.get_file_as_string(journal.save_path) == raw and journal.snapshot().rewinds.has(id), "실제 사망과 동일 생명 중복 호출은 되감기1회만"): return
			if not _start_story(character, weapon): return
			if not _check(sandbox.story_run.rewinds == 3 and controls.story_scene.lines.size() == 5 and _ack_scene(true) and player.damage_receiver.max_health == 100 and player.growth_damage(100, weapon) == 100, "세 되감기 후 단서 문장·전투/체력 벌점 없음"): return
			journal.record_rewind("later")
			if not _finish_stage(): return
			if not _check(store.load_checkpoint().story.rewinds == 3, "현재 여행은 시작 때 되감기 수 고정"): return
		"validate":
			if not _start_story(character, weapon) or not _ack_scene(true) or not _finish_stage(): return
			var saved := store.load_checkpoint()
			var raw := FileAccess.get_file_as_string(store.save_path)
			for value in [null, [], true, {"enabled": "true"}, {"enabled": false}, {"enabled": true, "known": [], "rewinds": false, "seen": ["prologue"], "pending": "stage:1"}]:
				var bad := saved.duplicate(true)
				bad.story = value
				if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and FileAccess.get_file_as_string(store.save_path) == raw, "손상된 이야기 상태 원자적 거부"): return
			for key in ["known", "rewinds", "seen", "pending"]:
				for value in [null, true, -1, "invalid", ["sera"], ["prologue", "prologue"]]:
					var bad := saved.duplicate(true)
					bad.story[key] = value
					if not _check(not RunCheckpointStore.valid_state(bad), "이야기 필드 형식/중복/순서 거부"): return
			var old := saved.duplicate(true)
			old.erase("story")
			if not _check(RunCheckpointStore.valid_state(old), "이야기 필드 없는 이전 체크포인트 호환"): return
		"corruption":
			if not _check(journal.record_fragments(["dawn_watch"]) == OK and journal.record_rewind("one") == OK, "정상 저널 줄 준비"): return
			var raw := FileAccess.get_file_as_string(journal.save_path)
			var file := FileAccess.open(journal.save_path, FileAccess.READ_WRITE)
			file.seek_end()
			file.store_string('{"version":1,"payload":"broken"}\n')
			file.close()
			journal._append({"event": "fragments", "ids": ["unknown"]})
			journal._append({"event": "chronicle", "id": true, "character": false, "ids": [], "run_id": "bad"})
			if not _check(journal.record_rewind("two") == OK and journal.snapshot().rewind_count == 2 and journal.snapshot().fragments.keys() == ["dawn_watch"] and journal.snapshot().chronicles.is_empty(), "손상/체크섬/잘못된 ID 줄을 건너뛰고 뒤 정상 기록 복구"): return
			if not _check(journal.record_fragments(["dawn_watch", "dawn_watch"]) == ERR_INVALID_DATA and journal.record_chronicle("x", "invalid", "roan", []) == ERR_INVALID_DATA and not raw.is_empty(), "중복·알 수 없는 영구 콘텐츠 거부"): return
		"legacy-seed":
			controls.begin_retry(weapon, 3, "standard", character)
			if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			if not _check(not store.load_checkpoint().has("story"), "기존 일반 저장은 이야기 필드 없음"): return
		"legacy":
			controls.selected_story_enabled = true
			if not _check(sandbox.continue_saved_run() and not sandbox.story_run.enabled and controls.current_screen_mode() == 9 and not controls.selected_story_enabled, "준비의 이야기 선택과 이전 전투 저장 복원 독립"): return
		"reader":
			if not _start_story(character, weapon) or not _ack_scene(true) or not _finish_stage() or not _ack_scene(true) or not sandbox._claim_weapon_reward(""): return
			controls.show_main_screen()
			controls.show_village()
			if not await _test_journal(): return
			if not _check(controls.current_screen_mode() == 13 and sandbox.is_combat_environment_suspended(), "수첩 닫으면 마을 환경 동결 소유권 유지"): return
		"orders":
			if not _test_story_orders(): return
		"jobs":
			growth.jobs_enabled = true
			if not _start_story(character, weapon) or not _ack_scene(true): return
			for stage in 3:
				if not _finish_stage() or not _ack_scene(true): return
				if stage < 2:
					if not sandbox._claim_weapon_reward(""): return
					_tap(controls.stage_route_rects[0].get_center())
			if not _check(growth.jobs.job_id in ["vanguard", "tracker"] and controls.current_screen_mode() == 12 and sandbox._resolve_boss_choice("rescue"), "이야기 중 실제 성장 카드·직업 발현·필살기 확인·보스 확정"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-277–306 runtime test: OK (%s %s %s)" % [phase, character, weapon])
	quit(0)

func _start_story(character: String, weapon: String) -> bool:
	controls.show_main_screen()
	controls.show_start_weapon_selection()
	_tap(controls.character_open_rect.get_center())
	_tap(controls.character_card_rects[0 if character == "roan" else 1].get_center())
	if not _check(controls.selected_story_enabled and not controls.story_toggle_rect.has_area(), "새 도전 이야기 항상 켜짐·토글 없음"): return false
	if not controls.character_detail_open: _tap(controls.character_card_rects[PrototypeCharacters.IDS.find(controls.selected_character_id)].get_center())
	_tap(controls.character_confirm_rect.get_center())
	_tap(controls.start_weapon_card_rects[0 if weapon == "sword" else 1].get_center())
	controls.open_preparation_options()
	_tap(controls.start_length_rects[2 if character == "lumi" else 0].get_center())
	controls.close_preparation_options()
	_tap(controls.start_weapon_confirm_rect.get_center())
	return _check(controls.current_screen_mode() == 18 and sandbox.story_run.enabled and player.character_id == character and weapons.active_weapon_id == weapon, "실제 설정→이야기 켜짐→검/활·로안/루미 시작")

func _ack_scene(skip: bool) -> bool:
	if not _check(controls.current_screen_mode() == 18, "확인할 실제 장면"): return false
	var id := String(controls.story_scene.id)
	var layout := PrototypeStoryView.scene_layout(controls.layout_snapshot().safe)
	for ignored in 4:
		if controls.current_screen_mode() != 18: break
		_tap((layout.skip if skip else layout.next).get_center())
	return _check(controls.current_screen_mode() != 18 and id in sandbox.story_run.seen and sandbox.story_run.pending.is_empty(), "다음/확인·건너뛰기 모두 같은 장면 완료")

func _check_story_result(character: String, weapon: String) -> bool:
	var result: Dictionary = controls.current_result_snapshot()
	var progress := journal.snapshot()
	var id := ("regions_" if character == "lumi" else "") + ("rescue" if weapon == "sword" else "destroy")
	var recent: Dictionary = recorder.summary_snapshot().recent_runs[0]
	if not _check(result.story.chronicle == id and recent.chronicle == id and recent.story_enabled and result.character_id == character and progress.chronicles.has(id) and store.load_checkpoint().is_empty() and recorder.summary_snapshot().completed_run_count == 1, "결과·영구 여행 기록·광장 이력·단일 완주·저장 정리"): return false
	controls._refresh_story_entry_layout()
	var safe: Rect2 = controls.layout_snapshot().safe
	if not _check(safe.encloses(controls.story_journal_open_rect) and not controls.story_journal_open_rect.intersects(controls.result_retry_rect) and not controls.story_journal_open_rect.intersects(controls.result_main_rect), "결과 수첩 버튼 안전 영역·비중첩"): return false
	_tap(controls.story_journal_open_rect.get_center())
	if not _check(controls.current_screen_mode() == 19 and paused, "결과의 실제 수첩 입력"): return false
	_tap(controls.story_journal_snapshot().layout.back.get_center())
	if not _check(controls.current_screen_mode() == 1 and controls.current_result_snapshot() == result, "수첩에서 같은 결과로 복귀"): return false
	controls.show_main_screen()
	controls.show_village()
	controls.village_page = "history"
	return _check(controls.village_snapshot().cards[0].lines.any(func(line: String) -> bool: return line.begins_with("이야기 여행")), "광장에 이야기 여행 종류·기록 이름 표시")

func _test_story_info() -> bool:
	controls.open_run_build()
	var cards := PrototypeRunBuildView.cards(2, controls.run_build_state)
	if not _check(cards.any(func(card: Dictionary) -> bool: return card.id == "story"), "현재 도전 정보에 이야기/조각 카드"): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(3.1)
	return _check(not paused and sandbox.story_run.enabled, "정보 조회 복귀는 이야기 도전 유지")

func _check_scene_layout() -> bool:
	var snapshot: Dictionary = controls.story_scene.duplicate(true)
	var elapsed := runner.stage_elapsed_s
	runner.set_process(true)
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		var safe: Rect2 = controls.layout_snapshot().safe
		var layout := PrototypeStoryView.scene_layout(safe)
		if not _check(safe.encloses(layout.next) and safe.encloses(layout.skip) and not layout.next.intersects(layout.skip), "두 화면비 장면 버튼 안전 영역·비중첩"): return false
		for line in snapshot.lines:
			var wrapped := PrototypeStoryView.wrap(String(line), ThemeDB.fallback_font, 22, layout.paragraphs[0].size.x)
			if not _check(wrapped.size() * 28 <= layout.paragraphs[0].size.y, "22px 이야기 문장 줄바꿈 높이"): return false
		controls.queue_redraw()
		await process_frame
		controls.notification(Control.NOTIFICATION_APPLICATION_PAUSED)
		controls.notification(Control.NOTIFICATION_APPLICATION_RESUMED)
		if not _check(paused and runner.stage_elapsed_s == elapsed and controls.story_scene == snapshot and controls.command_buffer.pending_count() == 0, "장면 중 앱 복귀는 장면/정지 유지·입력 해제"): return false
	runner.set_process(false)
	return true

func _test_journal() -> bool:
	var before := journal.snapshot()
	var file := FileAccess.get_file_as_string(journal.save_path)
	var save := store.load_checkpoint()
	var original: int = controls.current_screen_mode()
	controls._refresh_story_entry_layout()
	_tap(controls.story_journal_open_rect.get_center())
	if not _check(controls.current_screen_mode() == 19 and paused, "실제 수첩 버튼·전투 동결"): return false
	var elapsed := runner.stage_elapsed_s
	runner.set_process(true)
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		for tab in 2:
			_tap(controls.story_journal_snapshot().layout.tabs[tab].get_center())
			var pages: int = controls.story_journal_snapshot().pages
			for page in pages:
				var snapshot: Dictionary = controls.story_journal_snapshot()
				var safe: Rect2 = controls.layout_snapshot().safe
				var rects: Array = snapshot.layout.cards.duplicate()
				rects.append_array(snapshot.layout.tabs)
				rects.append_array([snapshot.layout.previous, snapshot.layout.next, snapshot.layout.back, snapshot.layout.retry])
				for i in rects.size():
					if not _check(safe.encloses(rects[i]), "수첩 두 화면비 안전 영역"): return false
					for j in range(i + 1, rects.size()):
						if not _check(not rects[i].intersects(rects[j]), "수첩 입력 비중첩"): return false
				for i in snapshot.cards.size():
					for line in snapshot.cards[i].lines:
						var rect: Rect2 = snapshot.layout.cards[i]
						var wrapped := PrototypeStoryView.wrap(String(line), ThemeDB.fallback_font, 14, rect.size.x * 0.90)
						if not _check(wrapped.size() * 16 <= rect.size.y * 0.17, "수첩14px 문장 높이·스포일러 미발견 상태"): return false
				controls.queue_redraw()
				await process_frame
				_tap(snapshot.layout.next.get_center())
	if not _check(runner.stage_elapsed_s == elapsed, "수첩을 보는 동안 실제 실행 가능한 스테이지 시계 정지"): return false
	runner.set_process(false)
	_tap(controls.story_journal_snapshot().layout.back.get_center())
	return _check(controls.current_screen_mode() == original and journal.snapshot() == before and FileAccess.get_file_as_string(journal.save_path) == file and store.load_checkpoint() == save, "수첩 페이지/탭/조회는 모든 기록 무변경·원래 화면 복귀")

func _test_story_preview(character: String) -> bool:
	controls.show_main_screen()
	controls.show_start_weapon_selection()
	var selected: bool = controls.selected_story_enabled
	_tap(controls.character_open_rect.get_center())
	if not _check(not controls.story_toggle_rect.has_area() and controls.selected_story_enabled, "이야기 토글 제거·항상 켜짐"): return false
	if not await _test_journal(): return false
	if controls.character_detail_open: _tap(controls.character_cancel_rect.get_center())
	_tap(controls.character_cancel_rect.get_center())
	if not _check(controls.selected_story_enabled == selected, "설정 취소는 이야기 선택 복구"): return false
	_tap(controls.character_open_rect.get_center())
	if not _check(not controls.story_toggle_rect.has_area() and controls.selected_story_enabled, "이야기 토글 제거·항상 켜짐"): return false
	if not controls.character_detail_open: _tap(controls.character_card_rects[PrototypeCharacters.IDS.find(controls.selected_character_id)].get_center())
	_tap(controls.character_confirm_rect.get_center())
	_tap(controls.start_weapon_cancel_rect.get_center())
	return _check(controls.selected_story_enabled == selected and not growth.run_active and recorder.summary_snapshot().run_count == 0 and not sandbox.story_run.enabled and not character.is_empty(), "전체 준비 취소는 도전/스토리/보상 시작 없음")

func _test_story_orders() -> bool:
	var a: Array[Dictionary] = [{"stage": 1, "route": "meadow"}, {"stage": 2, "route": "wind"}, {"stage": 3, "route": "forest"}, {"stage": 4, "route": "ruins"}, {"stage": 5, "route": "festival"}]
	var b: Array[Dictionary] = [{"stage": 1, "route": "meadow"}, {"stage": 2, "route": "ruins"}, {"stage": 3, "route": "forest"}, {"stage": 4, "route": "wind"}, {"stage": 5, "route": "festival"}]
	if not _check(PrototypeStory.earned(a, 5).size() == 8 and PrototypeStory.earned(b, 5).size() == 8 and PrototypeStory.chronicle_id(a, "rescue") == PrototypeStory.chronicle_id(b, "rescue"), "지역 순서와 독립적으로 네 지역 단서/여행 기록8개"): return false
	var scene := PrototypeStory.scene("stage:5", a, "lumi", [], 0, 5)
	var seen := PrototypeStory.scene("stage:5", b, "roan", ["knight_order"], 0, 5)
	if not _check(scene.name == "기사에게 남은 명령" and scene.lines != seen.lines and seen.lines[-1].contains("지난 여행"), "보스 구간·시작 때 기발견 단서에 따른 짧은 대사"): return false
	var repeat: Array[Dictionary] = [{"stage": 1, "route": "meadow"}, {"stage": 2, "route": "wind"}, {"stage": 3, "route": "wind"}]
	var repeated := PrototypeStory.scene("stage:3", repeat, "roan", [], 0, 5)
	if not _check(repeated.lines[0].contains("같은 길") and PrototypeStory.earned(repeat, 5).size() == 2 and PrototypeStory.chronicle_id(repeat, "rescue") == "rescue", "반복 경로는 다른 문장·조각 중복/세 지역 조건 우회 없음"): return false
	for id in PrototypeStory.FRAGMENTS:
		var cards := PrototypeStory.journal_cards(0, {"fragments": {}}, "roan")
		for card in cards:
			if not _check(not card.open and card.lines.size() == 2 and not card.lines.has(PrototypeStory.FRAGMENTS[card.id].lines[0]), "미발견 내용은 조건만 표시"): return false
	return true

func _same_story(expected: Dictionary) -> bool:
	return sandbox.story_run.enabled == expected.enabled and sandbox.story_run.known == expected.known and sandbox.story_run.rewinds == int(expected.rewinds) and sandbox.story_run.seen == expected.seen and sandbox.story_run.pending == expected.pending
