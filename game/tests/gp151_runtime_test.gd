extends "res://tests/gp114_runtime_test.gd"

const SAVE := "user://gp151_checkpoint.json"
const META := "user://gp151_meta.jsonl"
const RECORD := "user://gp151_records.jsonl"
const FIXTURE := "user://gp151_fixture.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = SAVE
	legacy.save_path = META
	if phase == "seed":
		store.clear_checkpoint()
		for path in [META, RECORD, FIXTURE]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = RECORD
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	recorder = sandbox.get_node("LocalTestRecorder")
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	weapons.sword_combat.set_process(false)
	weapons.bow_combat.set_process(false)
	runner.set_process(false)
	match phase:
		"seed":
			if not _fixture_test(): return
			controls.show_village()
			if not await _history_ui(true): return
			controls.show_main_screen()
			if not _reach_boss() or not _finish_stage(): return
			if not _check(sandbox._resolve_boss_choice("rescue"), "실제 구출 완주"): return
			controls.show_start_weapon_selection()
			_tap(controls.start_weapon_confirm_rect.get_center())
			if not _finish_stage(): return
			var recent: Array = recorder.summary_snapshot().recent_runs
			if not _check(recent.size() == 2 and not recent[0].completed and recent[0].completed_stages == 1 and recent[1].completed and recent[1].stage_number == 3 and recent[1].boss_choice == "rescue", "실제 완주·미완료를 최신 시작 순으로 표시"): return
			controls.show_main_screen()
			controls.show_village()
			if not await _history_ui(false): return
		"resume":
			controls.show_village()
			if not await _history_ui(false): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			if not _check(controls.current_screen_mode() == 11 and recorder.summary_snapshot().recent_runs.size() == 2, "별도 프로세스 이어하기는 항목을 늘리지 않음"): return
			for ignored in 2:
				_tap(controls.weapon_reward_skip_rect.get_center())
				_tap(controls.stage_route_rects[0].get_center())
				if not _finish_stage(): return
			if not _check(sandbox._resolve_boss_choice("destroy"), "이어하기 실제 파괴 완주"): return
			var recent: Array = recorder.summary_snapshot().recent_runs
			if not _check(recent.size() == 2 and recent[0].completed and recent[0].boss_choice == "destroy" and recent[0].completion_s > 0 and recent[1].boss_choice == "rescue", "도전 항목을 완주·시간·선택으로 갱신"): return
			controls.show_village()
			if not await _history_ui(false): return
		"finish":
			if not _check(recorder.summary_snapshot().recent_runs.size() == 2 and recorder.summary_snapshot().completed_run_count == 2, "다시 시작해도 이력·집계 보존"): return
			controls.show_village()
			if not await _history_ui(false): return
			var meta := legacy.progress_snapshot()
			var checkpoint := store.load_checkpoint()
			controls.record_history_page = 3
			recorder.clear_records()
			controls.village_page = "history"
			var view: Dictionary = controls.village_snapshot()
			if not _check(view.cards.size() == 1 and view.history_page == 0 and view.history_pages == 1 and recorder.summary_snapshot().recent_runs.is_empty() and legacy.progress_snapshot() == meta and store.load_checkpoint() == checkpoint, "기록 삭제는 빈 목록·페이지 보정, 영구 해금·저장 보존"): return
			if not await _history_ui(true): return
		_:
			_check(false, "알 수 없는 단계")
			return
	print("GP-151 runtime test: OK · " + phase)
	quit(0)

func _history_ui(empty: bool) -> bool:
	var files := _saved_bytes()
	var meta := legacy.progress_snapshot()
	var elapsed := runner.stage_elapsed_s
	var health := player.damage_receiver.health
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_layout()
		controls.village_page = "village"
		_tap(controls.village_snapshot().layout.cards[2].get_center())
		if not _check(controls.village_page == "records", "실제 광장 터치"): return false
		_tap(controls.village_snapshot().tabs.history.get_center())
		var view: Dictionary = controls.village_snapshot()
		if not _check(view.page == "history" and view.history_page == 0 and view.cards.size() == (1 if empty else 2), "탭 터치·빈 상태·실제 도전 카드"): return false
		if not empty:
			var recent: Array = recorder.summary_snapshot().recent_runs
			for i in recent.size():
				if not _check(view.cards[i].id == recent[i].id and view.cards[i].status == ("완주" if recent[i].completed else "미완료"), "실제 도전 ID·완주 상태 일치"): return false
				if recent[i].completed and not _check(view.cards[i].lines[1] == "완주 시간 %.1f초" % float(recent[i].completion_s) and view.cards[i].lines[2] == ("보스 구출" if recent[i].boss_choice == "rescue" else "보스 파괴"), "실제 완주 시간·보스 선택 표시"): return false
		var rects: Array = view.layout.cards.duplicate()
		rects.append_array(view.tabs.values())
		rects.append_array(view.pager.values())
		rects.append_array([view.layout.back, view.layout.start])
		if controls.checkpoint_available: rects.append(view.layout["continue"])
		var safe: Rect2 = controls.layout_snapshot().safe
		for i in rects.size():
			if not _check(safe.encloses(rects[i]), "두 화면비 안전 영역"): return false
			for j in range(i + 1, rects.size()):
				if not _check(not rects[i].intersects(rects[j]), "입력 영역 비중첩"): return false
		_tap(view.pager.next.get_center())
		_tap(view.pager.previous.get_center())
		controls.queue_redraw()
		for ignored in 3: await physics_frame
		if not _check(sandbox.is_combat_environment_suspended() and runner.stage_elapsed_s == elapsed and player.damage_receiver.health == health, "조회 중 실제 물리·타이머 동결"): return false
		_tap(controls.village_snapshot().tabs.records.get_center())
		if not _check(controls.village_page == "records", "통계 탭 복귀"): return false
		_tap(controls.village_snapshot().layout.back.get_center())
	if not _check(_saved_bytes() == files and legacy.progress_snapshot() == meta, "조회·복귀는 파일·체크포인트·영구 해금 미변경"): return false
	return true

func _saved_bytes() -> Array:
	var bytes: Array = []
	for path in [SAVE, SAVE + ".bak", META, RECORD]:
		bytes.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
	return bytes

func _fixture_test() -> bool:
	var fixture := LocalTestRecorder.new()
	fixture.configure_record_path_for_test(FIXTURE)
	fixture.start_run("old")
	fixture.record_stage_metrics({"stage_complete": true, "run_complete": true, "run_stage_count": 3, "run_elapsed_s": 123.4, "boss_choice": "rescue"})
	fixture._append_event("run_completed", {"run_id": "old", "stage_count": 5, "completion_s": 999, "boss_choice": "destroy"})
	fixture.restore_checkpoint({"id": "orphan"}, 2)
	fixture._append_event("run_started", {"run_id": "old"})
	var first: Array = fixture.summary_snapshot().recent_runs
	if not _check(first.size() == 2 and first[0].id == "orphan" and first[0].completed_stages == 2 and first[1].stage_number == 3 and first[1].completion_s == 123.4 and first[1].boss_choice == "rescue", "시작 기록 없는 이어하기·중복 완주/시작은 기존 항목 유지"): return false
	first[0].id = "mutated"
	if not _check(fixture.summary_snapshot().recent_runs[0].id == "orphan", "스냅샷 깊은 복사"): return false
	for i in 16: fixture.start_run("run-%d" % i)
	var file := FileAccess.open(FIXTURE, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string('{"schema_version":1,"event":"run_completed"')
	file.close()
	fixture.reload_records_for_test()
	var summary := fixture.summary_snapshot()
	if not _check(summary.recent_runs.size() == 12 and summary.recent_runs[0].id == "run-15" and summary.recent_runs[11].id == "run-4" and summary.run_count == 17 and summary.completed_run_count == 1, "최근 12개 제한·손상 꼬리 무시·전체 집계 유지"): return false
	controls.show_village()
	var original: Dictionary = controls.test_record_summary.duplicate(true)
	controls.test_record_summary = summary
	controls.village_page = "history"
	for i in 4:
		var view: Dictionary = controls.village_snapshot()
		if not _check(view.history_page == i and view.history_pages == 4 and view.cards.size() == 3 and view.cards[0].id == "run-%d" % (15 - i * 3), "실제 다음 터치 네 페이지·순서"): return false
		for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
			controls.size = dimensions
			controls._refresh_layout()
			view = controls.village_snapshot()
			for card_index in view.cards.size():
				var rect: Rect2 = view.layout.cards[card_index]
				if not _check(controls.layout_snapshot().safe.encloses(rect), "세 카드 두 화면비 안전 영역"): return false
				for line in view.cards[card_index].lines:
					if not _check(ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= rect.size.x - 24, "세 카드 설명 최소 글자 크기에서 수용"): return false
			controls.queue_redraw()
		_tap(view.pager.next.get_center())
	if not _check(controls.village_snapshot().history_page == 3, "마지막 페이지 경계"): return false
	for i in 4: _tap(controls.village_snapshot().pager.previous.get_center())
	if not _check(controls.village_snapshot().history_page == 0, "처음 페이지 경계"): return false
	controls.test_record_summary = original
	controls.show_main_screen()
	fixture.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
	return true
