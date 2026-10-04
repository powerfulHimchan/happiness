extends "res://tests/gp110_runtime_test.gd"

const GP122_SAVE := "user://gp122_checkpoint.json"
const GP122_META := "user://gp122_meta.jsonl"
const GP122_RECORD := "user://gp122_records.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP122_SAVE
	legacy.save_path = GP122_META
	if phase == "seed":
		store.clear_checkpoint()
		for path in [GP122_META, GP122_RECORD]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP122_RECORD
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
	player.set_physics_process(false)
	match phase:
		"seed":
			var initial := legacy.progress_snapshot()
			controls.show_village()
			if not await _test_atlas_layout(): return
			_tap(controls.village_snapshot().layout.cards[2].get_center())
			if not _check(legacy.progress_snapshot() == initial and controls.surveyed_routes.is_empty() and store.load_checkpoint().is_empty() and not runner.can_select_route("clockwork"), "도감 방문·위험 카드 터치는 기록·보상·선택 권한 미변경"): return
			controls.begin_retry()
			if not _reach_elite(): return
			_defeat(runner.final_enemy())
			if not _resolve_growth(): return
			legacy.fail_writes = true
			runner._process(0.1)
			if not _check(runner.stage_complete and controls.current_screen_mode() == 11 and controls.surveyed_routes.is_empty() and not controls.route_atlas_message.is_empty() and not store.load_checkpoint().is_empty(), "답사 저장 실패도 스테이지 완료·무기 보상·중간 저장 가능"): return
			if not _check(sandbox._claim_weapon_reward(""), "답사 실패 중 무기 보상 유지 가능"): return
			var saved := store.load_checkpoint()
			controls.show_main_screen()
			controls.show_village()
			_tap(controls.village_snapshot().layout.cards[5].get_center())
			_tap(controls.village_snapshot().layout.cards[0].get_center())
			if not _check(controls.surveyed_routes.is_empty() and not controls.route_atlas_message.is_empty() and store.load_checkpoint() == saved, "실패한 터치 재시도는 정상 저장 보존"): return
			legacy.fail_writes = false
			_tap(controls.village_snapshot().layout.cards[0].get_center())
			if not _check(controls.surveyed_routes == {"meadow": true} and controls.route_atlas_message.is_empty() and controls.village_snapshot().cards[0].status.contains("완료") and store.load_checkpoint() == saved, "카드 실제 터치로 재저장·통과 표기·체크포인트 미변경"): return
			var journal := FileAccess.get_file_as_string(GP122_META)
			if not _check(legacy.discover_routes(["meadow"]) == OK and legacy.discover_routes(["meadow", "unknown"]) == ERR_INVALID_DATA and legacy.discover_routes(["wind", "wind"]) == ERR_INVALID_DATA and FileAccess.get_file_as_string(GP122_META) == journal, "중복은 쓰기 없음·알 수 없는 경로·중복 배열은 원자적으로 거부"): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			for ignored in 3: runner.force_emit_metrics()
			if not _check(FileAccess.get_file_as_string(GP122_META) == journal, "이어하기·반복 완료 통지는 답사 중복 없음"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _check(runner.stage_number == 2 and runner.route_id == "wind" and controls.surveyed_routes == {"meadow": true} and store.load_checkpoint() == saved, "경로 진입만으로 바람 답사 기록 없음"): return
		"resume":
			if not _check(controls.surveyed_routes == {"meadow": true} and sandbox.continue_saved_run(), "별도 프로세스 영구 답사·첫 통과 저장 복원"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _finish_stage(): return
			if not _check(controls.surveyed_routes == {"meadow": true, "wind": true}, "실제 바람 길 통과로 두 번째 답사 기록"): return
			if not _check(sandbox._claim_weapon_reward(""), "바람 무기 보상 유지"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("destroy"), "실제 보스 파괴로 다음 위험 도전 준비"): return
			controls.show_main_screen()
			controls.show_start_weapon_selection()
			_tap(controls.start_weapon_confirm_rect.get_center())
			if not _check(player.boss_legacy.choice == "destroy" and controls.surveyed_routes.size() == 2, "새 도전은 영구 답사 유지·파괴 핵 적용"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "위험 길 선택 전 중간 저장"): return
			if not _check(controls.stage_route_options.size() == 3 and not controls.surveyed_routes.has("clockwork"), "파괴 권한 개방과 위험 답사 독립"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and controls.surveyed_routes.size() == 2, "위험 선택 전 저장 재시작"): return
			_tap(controls.stage_route_rects[2].get_center())
			if not _check(runner.route_id == "clockwork" and not controls.surveyed_routes.has("clockwork"), "위험 길 입장은 답사 미완료"): return
			if not _finish_stage(): return
			if not _check(controls.surveyed_routes.size() == 3 and controls.surveyed_routes.has("clockwork"), "위험 길 실제 통과로 세 경로 영구 답사"): return
			if not _check(sandbox._claim_weapon_reward(""), "위험 무기 보상 유지"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("rescue"), "위험 도전 실제 보스 구출 완주"): return
			recorder.clear_records()
			controls.show_village()
			if not await _test_atlas_layout(): return
			if not _check(controls.surveyed_routes.size() == 3 and controls.test_record_summary.run_count == 0, "완주·도전 기록 삭제 후 영구 답사 유지"): return
			for invalid in [null, true, 7, "wind", ["unknown"], ["wind", "unknown"], ["wind", "wind"], [7]]:
				legacy._append({"event": "routes", "ids": invalid})
			var file := FileAccess.open(GP122_META, FileAccess.READ_WRITE)
			file.seek_end()
			file.store_string("{truncated")
			file.close()
			legacy._append({"event": "loadout", "run_id": "fixture", "memory_id": ""})
			sandbox._update_boss_legacy_status()
			if not _check(controls.surveyed_routes.size() == 3, "손상 끝줄·잘못된 답사 이벤트는 정상 기록 보존"): return
			controls.show_main_screen()
			controls.show_start_weapon_selection()
			controls.use_boss_legacy = false
			_tap(controls.start_weapon_confirm_rect.get_center())
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 형식 저장 첫 통과 준비"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 형식 저장 바람 통과 준비"): return
			# GP-121 중간 저장과 동일한 스키마. 답사 이벤트 없는 기존 저널을 재현한다.
			DirAccess.remove_absolute(ProjectSettings.globalize_path(GP122_META))
		"legacy":
			if not _check(controls.surveyed_routes == {"meadow": true, "wind": true} and sandbox.continue_saved_run(), "답사 이벤트 없는 이전 저장의 실제 통과 이력 복구"): return
			var saved := store.load_checkpoint()
			var journal := FileAccess.get_file_as_string(GP122_META)
			controls.show_main_screen()
			controls.show_village()
			if not await _test_atlas_layout(): return
			if not _check(FileAccess.get_file_as_string(GP122_META) == journal and store.load_checkpoint() == saved and not runner.can_select_route("clockwork"), "이전 저장 도감 재방문은 중복·체크포인트 변경·위험 권한 없음"): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("rescue"), "복구한 이전 저장으로 보스 완주"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-122 runtime test: OK (" + phase + ")")
	quit(0)

func _test_atlas_layout() -> bool:
	var before := legacy.progress_snapshot()
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls.village_page = "village"
		var village: Dictionary = controls.village_snapshot()
		if not _check(village.cards.size() == 6 and village.layout.cards[3].position.y > village.layout.cards[0].end.y and village.cards[5].open, "여섯 시설 3열·2행·지도 제작소 항상 방문 가능"): return false
		_tap(village.layout.cards[5].get_center())
		if not _check(controls.village_page == "atlas", "지도 제작소 실제 터치 진입"): return false
		for page in ["village", "atlas"]:
			controls.village_page = page
			var snapshot: Dictionary = controls.village_snapshot()
			var safe: Rect2 = controls.layout_snapshot().safe
			var rects: Array = snapshot.layout.cards.duplicate()
			rects.append_array([snapshot.layout.back, snapshot.layout.start])
			if controls.checkpoint_available: rects.append(snapshot.layout["continue"])
			for i in rects.size():
				if not _check(safe.encloses(rects[i]), "두 화면비 마을·도감 안전 영역"): return false
				for j in range(i + 1, rects.size()):
					if not _check(not rects[i].intersects(rects[j]), "시설·경로·복귀·도전 버튼 겹침 없음"): return false
			controls.queue_redraw()
			await process_frame
		var cards: Array = controls.village_snapshot().cards
		if not _check(cards.size() == 3 and cards[0].id == "meadow" and cards[1].id == "wind" and cards[2].id == "clockwork" and cards[0].lines[2].contains("20") and cards[1].lines[2].contains("25") and cards[2].lines[2].contains("50") and cards[2].lines[4].contains("2스테이지"), "실제 경로 정의의 지형·보너스·위험 조건 표시"): return false
	var elapsed := runner.stage_elapsed_s
	var position := player.position
	for ignored in 3: await physics_frame
	return _check(legacy.progress_snapshot() == before and sandbox.is_combat_environment_suspended() and player.position == position and runner.stage_elapsed_s == elapsed and not sandbox._use_recovery_potion(), "도감 방문은 저장 미변경·전투/물리 동결·회복약 차단")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-122 failed: " + message)
		paused = false
		quit(1)
	return condition
