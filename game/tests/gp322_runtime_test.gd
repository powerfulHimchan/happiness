extends "res://tests/gp321_runtime_test.gd"

var extra_encounters := 0
var expedition_story := true

func _run() -> void:
	heart_battle_for_tests = true
	final_ritual_for_tests = true
	auto_guardian_choice = false
	legacy_final_boss_for_tests = false
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	expedition_story = phase != "story-off"
	var character := args[1]
	var weapon := args[2]
	legacy = FaultStore.new()
	var continuing := phase == "resume"
	var prefix := "user://gp322_%s_%s_%s" % ["flow" if phase in ["seed", "resume"] else phase, character, weapon]
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
		"preview":
			controls.show_main_screen()
			controls.show_start_weapon_selection()
			_tap(controls.start_length_rects[3].get_center())
			var before: int = recorder.summary_snapshot().run_count
			_tap(controls.expedition_rect.get_center())
			if not _check(not controls.expedition_unlocked() and controls.selected_expedition == 0 and not controls.begin_retry(weapon, 10, "journey", character, false, 1) and recorder.summary_snapshot().run_count == before, "미해금 실제 입력·시작 API 차단·기록 불변"): return
			journal.fail_writes = true
			if not _check(journal.record_ending("prior-arrival", ArrivalEnding.ID, character, "rescue") != OK and not controls.expedition_unlocked(), "영구 엔딩 저장 실패로 해금하지 않음"): return
			journal.fail_writes = false
			if journal.record_ending("prior-arrival", ArrivalEnding.ID, character, "rescue") != OK: return
			_tap(controls.expedition_rect.get_center())
			if not _check(controls.expedition_unlocked() and controls.selected_expedition == 1 and not controls.begin_retry(weapon, 3, "standard", character, false, 1), "기록 성공 후 실제 원정 선택·일반 도전 결합 거부"): return
			_tap(controls.start_weapon_cancel_rect.get_center())
			if not _check(controls.selected_expedition == 0, "준비 취소는 이전 난이도 복원"): return
			controls.show_start_weapon_selection()
			_tap(controls.expedition_rect.get_center())
			_tap(controls.start_length_rects[0].get_center())
			if not _check(controls.selected_expedition == 0 and not journal.snapshot().endings.is_empty(), "일반 도전 전환은 기본 난이도·영구 해금 보존"): return
			if not controls.begin_retry(weapon, 3, "standard", character): return
			if not _step_section() or not _step_section() or not _step_section(): return
			if not _check(runner.expedition == 0 and runner._active_enemies.size() == 3 and runner.armored_boar not in runner._active_enemies, "기본 난이도 웨이브와 원래 적 수 보존"): return
		"seed", "validate", "legacy", "layout", "story-off":
			if journal.record_ending("prior-arrival", ArrivalEnding.ID, character, "rescue") != OK or not _start_journey(character, weapon): return
			if phase == "layout":
				controls.show_main_screen()
				controls.show_start_weapon_selection()
				for width in [1280, 1600]:
					root.size = Vector2i(width, 720)
					await process_frame
					controls._refresh_start_weapon_layout()
					if not _check(controls._safe_area_in_viewport().encloses(controls.expedition_rect) and not controls.expedition_rect.intersects(controls.character_open_rect) and not controls.expedition_rect.intersects(controls.start_length_rects[0]) and not controls.boss_legacy_toggle_rect.intersects(controls.start_weapon_confirm_rect), "두 화면비 난이도·주인공·길이·시작 버튼 분리"): return
				return _done(phase, character, weapon)
			if not _finish_stage() or not _check(extra_encounters == 1, "첫 스테이지 추가 정예 실제 처치"): return
			var saved := store.load_checkpoint()
			if not _check(saved.stage.expedition == 1 and RunCheckpointStore.valid_state(saved) and recorder.summary_snapshot().recent_runs[0].expedition == 1, "완료 저장과 진행 이력의 원정 유지"): return
			if phase == "validate":
				for value in [true, null, -1, 3, 1.5, "1", [], {}]:
					var bad := saved.duplicate(true)
					bad.stage.expedition = value
					if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "잘못된 난이도 저장 거부·정상 파일 보존"): return
				var path := store.save_path
				store.save_path = "user://gp322_missing/checkpoint.json"
				if not _check(sandbox._save_checkpoint(runner.current_metrics()) != OK and runner.expedition == 1, "저장 실패 시 난이도 유지"): return
				store.save_path = path
				if not _check(store.load_checkpoint() == saved, "저장 실패 후 이전 정상 저장 보존"): return
			elif phase == "story-off":
				controls.show_main_screen()
				if not sandbox.continue_saved_run() or not _check(runner.expedition == 1 and not sandbox.story_run.enabled, "이야기 꺼짐 원정 저장·재실행 유지"): return
				if not sandbox._claim_weapon_reward("") or not _next_without_layout() or not _finish_stage(): return
			elif phase == "legacy":
				saved.stage.erase("expedition")
				if store.save_checkpoint(saved) != OK: return
				controls.show_main_screen()
				if not sandbox.continue_saved_run() or not _check(runner.expedition == 0 and recorder.summary_snapshot().recent_runs[0].expedition == 0, "필드 없는 이전 저장은 기본 난이도·이력 복원"): return
		"resume":
			if not _restore_journey(1) or not _check(runner.expedition == 1, "별도 프로세스·준비 선택과 독립 원정 복원"): return
			if not _ack_scene(true) or not sandbox._claim_weapon_reward("") or not _next_without_layout() or not _finish_stage(): return
			if not _check(runner.stage_number == 2 and extra_encounters == 1 and store.load_checkpoint().stage.expedition == 1, "복원 후 다음 지역 추가 정예와 저장 유지"): return
		"finish":
			if not await _gp321_enter_choices(character, weapon, "rescue") or not _gp321_select_final("liberation") or not _gp321_confirm_final() or not _gp321_final_recorded("liberation", character, "rescue"): return
			if not _check(extra_encounters == 10 and controls.current_result_snapshot().expedition == 1 and recorder.summary_snapshot().recent_runs[0].expedition == 1, "10개 추가 정예·실제 심장 처치·엔딩·결과·완주 이력"): return
			var cards := PrototypeVillageView.cards("history", {}, {}, recorder.summary_snapshot())
			if not _check(str(cards).contains("원정 1"), "마을 이력 원정 이름"): return
		_:
			_check(false, "알 수 없는 원정 검사")
			return
	_done(phase, character, weapon)

func _done(phase: String, character: String, weapon: String) -> void:
	paused = false
	sandbox.free()
	print("GP-322 runtime test: OK (%s %s %s)" % [phase, character, weapon])
	quit(0)

func _start_journey(character: String, weapon: String) -> bool:
	controls.show_main_screen()
	controls.show_start_weapon_selection()
	controls.selected_character_id = character
	controls.selected_starting_weapon = weapon
	controls.selected_story_enabled = expedition_story
	runner.region_rng.seed = 322 if character == "roan" else 323
	_tap(controls.start_length_rects[3].get_center())
	_tap(controls.expedition_rect.get_center())
	_tap(controls.start_weapon_confirm_rect.get_center())
	if not _check(runner.expedition == 1 and runner.run_mode == "journey" and runner.stage_limit == 10, "실제 준비 입력으로 원정 1 시작"): return false
	return _ack_scene(true) if expedition_story else true

func _step_section() -> bool:
	if runner.current_section == PrototypeStageRunner.Section.WAVE_TWO and runner.expedition == 1:
		if not _check(runner._active_enemies.size() == 4 and runner.armored_boar in runner._active_enemies and runner.armored_boar.is_targetable(), "두 번째 웨이브에 정예 1마리 추가"): return false
		for enemy in [runner.leaf_slime, runner.seed_sack, runner.wind_spirit]: _defeat(enemy)
		if not _resolve_growth(): return false
		runner._process(0.01)
		if not _check(runner.current_section == PrototypeStageRunner.Section.WAVE_TWO and not runner.stage_complete and runner.armored_boar.is_targetable(), "일반 적만 처치하면 관문·웨이브 완료 차단"): return false
		extra_encounters += 1
	return super._step_section()

func _active_heart() -> bool:
	runner.heart.set_process(false)
	return _check(runner.expedition == 1 and runner.heart_battle == HeartEncounter.ACTIVE and runner.heart.is_targetable() and store.load_checkpoint().stage.expedition == 1 and runner.current_metrics().run_route_name == "행복의 심장 · 원정 1", "원정 난이도로 실제 심장 전투·직전 저장 유지")
