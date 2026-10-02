extends "res://tests/gp110_runtime_test.gd"

const GP116_SAVE := "user://gp116_checkpoint.json"
const GP116_META := "user://gp116_meta.jsonl"
const GP116_RECORD := "user://gp116_records.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP116_SAVE
	legacy.save_path = GP116_META
	if phase == "seed":
		store.clear_checkpoint()
		for path in [GP116_META, GP116_RECORD]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	legacy.fail_writes = phase == "legacy-fail"
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP116_RECORD
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
			if not _check(controls.discovered_jobs.is_empty() and legacy.progress_snapshot().jobs.is_empty(), "처음에는 두 직업 모두 미발견"): return
			controls.show_village()
			if not await _test_codex_layout(): return
			var before := legacy.progress_snapshot()
			_tap(controls.village_snapshot().layout.back.get_center())
			if not _check(legacy.progress_snapshot() == before and player.growth_damage(20, "sword") == 20, "도감 방문으로 직업 발견·능력 지급 없음"): return
			controls.begin_retry("sword")
			for i in 3:
				legacy.fail_writes = i == 2
				_gain_card(0)
				if i < 2 and not _check(growth.jobs.job_id.is_empty() and controls.discovered_jobs.is_empty(), "조건 충족 전에는 미발견"): return
			if not _check(growth.jobs.job_id == "vanguard" and growth.awaiting_job_confirmation and paused and controls.discovered_jobs.is_empty() and not controls.job_codex_message.is_empty(), "실제 자동 발현·기록 저장 실패 표시"): return
			_tap(controls.job_ultimate_rects[0].get_center())
			_tap(controls.job_confirm_rect.get_center())
			if not _check(paused and growth.awaiting_job_confirmation and player.get_node("UltimateController").selected_profile.is_empty() and legacy.progress_snapshot().jobs.is_empty(), "기록 실패는 확인 보류·필살기 미선택"): return
			legacy.fail_writes = false
			_tap(controls.job_confirm_rect.get_center())
			if not _check(not paused and not growth.awaiting_job_confirmation and controls.discovered_jobs == {"vanguard": true} and controls.job_codex_message.is_empty(), "확인으로 재저장·영구 발견·정상 재개"): return
			var journal := FileAccess.get_file_as_string(GP116_META)
			if not _check(legacy.discover_job("vanguard") == OK and FileAccess.get_file_as_string(GP116_META) == journal and legacy.discover_job("unknown") == ERR_INVALID_DATA, "중복 발견·잘못된 직업은 쓰기 없음"): return
			if not _check(legacy.pending_reward().is_empty() and legacy.progress_snapshot().unlocked.is_empty() and legacy.progress_snapshot().blueprints.is_empty(), "직업 발견과 보스 보상·기억·설계도 독립"): return
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			if not _check(store.load_checkpoint().growth.job == "vanguard", "실제 중간 완료에 발현 직업 저장"): return
		"resume":
			if not _check(controls.discovered_jobs == {"vanguard": true} and sandbox.continue_saved_run() and growth.jobs.job_id == "vanguard", "별도 프로세스에서 영구 발견·현재 직업 복원"): return
			var saved := store.load_checkpoint()
			controls.show_main_screen()
			controls.show_village()
			if not await _test_codex_layout(): return
			_tap(controls.village_snapshot().layout.cards[3].get_center())
			if not _check(controls.village_snapshot().cards[0].status == "발견 · 현재 도전", "현재 도전의 발현 직업 도감 표시"): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			if not _check(controls.current_screen_mode() == 9 and store.load_checkpoint() == saved, "도감에서 이어하기·저장 미변경"): return
			controls.begin_retry("bow")
			if not _check(growth.jobs.job_id.is_empty() and player.growth_damage(20, "bow") == 20 and controls.discovered_jobs.size() == 1, "발견이 시작 직업·패시브를 지급하지 않음"): return
			for ignored in 3:
				_gain_card(1)
			if not _check(growth.jobs.job_id == "tracker" and controls.discovered_jobs.size() == 2, "두 번째 실제 자동 발현 즉시 영구 기록"): return
			_tap(controls.job_ultimate_rects[1].get_center())
			_tap(controls.job_confirm_rect.get_center())
			player.player_died.emit()
			recorder.clear_records()
			controls.show_main_screen()
			controls.show_village()
			_tap(controls.village_snapshot().layout.cards[3].get_center())
			if not _check(controls.discovered_jobs.size() == 2 and controls.test_record_summary.run_count == 0 and controls.village_snapshot().cards[1].status == "영구 발견", "사망·도전 기록 삭제 후 발견 유지·현재 표시 해제"): return
		"finish":
			if not _check(controls.discovered_jobs.size() == 2 and not controls.checkpoint_available, "재시작 뒤 두 직업 유지·사망한 도전 저장 없음"): return
			# 손상·알 수 없는 직업·잘못된 형식의 줄은 정상 발견을 지우지 않는다.
			legacy._append({"event": "job", "job_id": "unknown"})
			legacy._append({"event": "job", "job_id": 7})
			var file := FileAccess.open(GP116_META, FileAccess.READ_WRITE)
			file.seek_end()
			file.store_string("{truncated")
			file.close()
			legacy._append({"event": "loadout", "run_id": "fixture", "memory_id": ""})
			sandbox._update_boss_legacy_status()
			if not _check(controls.discovered_jobs.size() == 2, "손상 끝줄 복구·알 수 없는 직업 발견 없음"): return
			controls.begin_retry()
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			if not _check(growth.jobs.job_id == "vanguard", "이전 저장의 실제 발현 직업 준비"): return
			# GP-115 이전 보상 저널 형식만 남긴다.
			var lines: Array[String] = []
			for line in FileAccess.get_file_as_string(GP116_META).split("\n"):
				var envelope: Variant = JSON.parse_string(line)
				if not envelope is Dictionary or not envelope.get("payload") is String: continue
				var event: Variant = JSON.parse_string(envelope.payload)
				if event is Dictionary and event.get("event") != "job": lines.append(line)
			file = FileAccess.open(GP116_META, FileAccess.WRITE)
			file.store_string("\n".join(lines) + "\n")
			file.close()
		"legacy-fail":
			var saved := store.load_checkpoint()
			if not _check(controls.discovered_jobs.is_empty() and controls.checkpoint_available and not sandbox.continue_saved_run() and controls.current_screen_mode() == 2 and store.load_checkpoint() == saved, "이전 직업 기록 저장 실패는 이어하기·정상 저장 보호"): return
			controls.begin_retry()
			if not _check(controls.current_screen_mode() == 2 and store.load_checkpoint() == saved and controls.discovered_jobs.is_empty(), "기록 복구 실패 중 새 도전도 기존 저장 유지"): return
		"legacy-resume":
			if not _check(controls.discovered_jobs == {"vanguard": true} and sandbox.continue_saved_run() and controls.current_screen_mode() == 9 and growth.jobs.job_id == "vanguard", "이전 저장에서 실제 발현 직업만 기록 복구"): return
			var journal := FileAccess.get_file_as_string(GP116_META)
			sandbox._refresh_checkpoint()
			if not _check(FileAccess.get_file_as_string(GP116_META) == journal, "재조회 복구에 중복 쓰기 없음"): return
		_:
			_check(false, "검사 단계 오류")
			return
	paused = false
	sandbox.free()
	print("GP-116 runtime test: OK (" + phase + ")")
	quit(0)

func _gain_card(index: int) -> void:
	var needed := growth.next_level_experience()
	growth.experience += needed
	growth.total_experience += needed
	growth._offer_next_level()
	growth.offered_cards.assign([PrototypeGrowthController.CARDS[index]])
	sandbox._on_growth_choices_requested(growth.offered_cards, growth.level, growth.rerolls_remaining)
	_tap(controls.growth_card_rects[0].get_center())

func _test_codex_layout() -> bool:
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_layout()
		for page in ["village", "jobs"]:
			controls.village_page = page
			var snapshot: Dictionary = controls.village_snapshot()
			var safe: Rect2 = controls.layout_snapshot().safe
			var rectangles: Array = snapshot.layout.cards.duplicate()
			rectangles.append_array([snapshot.layout.back, snapshot.layout.start])
			if controls.checkpoint_available: rectangles.append(snapshot.layout["continue"])
			for i in rectangles.size():
				if not _check(safe.encloses(rectangles[i]), "네 시설·직업 도감 두 화면비 안전 영역"): return false
				for j in range(i + 1, rectangles.size()):
					if not _check(not rectangles[i].intersects(rectangles[j]), "터치 영역 겹침 없음"): return false
			if page == "jobs":
				for i in 2:
					var card: Dictionary = snapshot.cards[i]
					var job: Dictionary = PrototypeJobProgress.JOBS[i]
					if not _check(card.id == job.id and card.open == controls.discovered_jobs.get(job.id, false) and card.lines.size() == 6 and "5" in card.lines[0] and "3" in card.lines[0] and job.passive == card.lines[1], "실제 데이터에서 조건·효과·발견 표시"): return false
			controls.queue_redraw()
			await process_frame
		controls.village_page = "village"
		_tap(controls.village_snapshot().layout.cards[3].get_center())
		if not _check(controls.village_page == "jobs", "네 번째 시설 터치로 직업 도감 진입"): return false
		_tap(controls.village_snapshot().layout.back.get_center())
		if not _check(controls.village_page == "village", "직업 도감에서 마을 복귀"): return false
	return true

func _check(condition: bool, message: String) -> bool:
	if condition: return true
	push_error("GP-116 실패: " + message)
	paused = false
	quit(1)
	return false
