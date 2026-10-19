extends "res://tests/gp324_runtime_test.gd"

func _run() -> void:
	heart_battle_for_tests = true
	final_ritual_for_tests = true
	auto_guardian_choice = false
	legacy_final_boss_for_tests = false
	expected_level = 4
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var character := args[1]
	var weapon := args[2]
	expedition_story = phase not in ["healing", "story-off"]
	legacy = FaultStore.new()
	journal = expedition_journal
	var continuing := phase in ["resume", "clear-resume"]
	var prefix := "user://gp325_%s_%s_%s" % ["flow" if phase in ["seed", "resume"] else "clear" if phase in ["clear-seed", "clear-resume"] else phase, character, weapon]
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
			if not _unlock_three(character): return
			controls.show_main_screen()
			controls.show_start_weapon_selection()
			_tap(controls.start_length_rects[3].get_center())
			if not _check(controls.expedition_unlocked() and controls.expedition_cap == 3 and not controls.begin_retry(weapon, 10, "journey", character, false, 4), "원정3 미완주는 원정4 차단"): return
			if journal.record_ending("prior-three", ArrivalEnding.ID, character, "rescue") != OK: return
			expedition_journal.fail_clear = true
			if not _check(journal.record_expedition_clear("prior-three", 3) != OK and controls.expedition_unlocked() and controls.expedition_cap == 3, "원정3 완주 기록 실패는 상위 해금 보류"): return
			expedition_journal.fail_clear = false
			if journal.record_expedition_clear("prior-three", 3) != OK: return
			controls.expedition_unlocked()
			for level in [1, 2, 3, 4, 0]:
				_tap(controls.expedition_rect.get_center())
				if not _check(controls.selected_expedition == level, "기본·원정1·2·3·4 순환"): return
			for ignored in 4: _tap(controls.expedition_rect.get_center())
			if not _check(controls.expedition_label().contains("보스 재공격"), "원정4 패턴 설명"): return
			_tap(controls.start_weapon_cancel_rect.get_center())
			if not _check(controls.selected_expedition == 0 and not controls.begin_retry(weapon, 5, "regions", character, false, 4) and not controls.begin_retry(weapon, 10, "journey", character, false, 5), "취소·다른 모드·미구현 원정 차단"): return
			recorder.clear_records()
			if not _check(controls.expedition_unlocked() and controls.expedition_cap == 4, "도전 기록 삭제와 독립 해금"): return
		"resume":
			if not _restore_journey(1) or not _patterns_enabled(true): return
			if not _check(player.expedition == 4 and recorder.summary_snapshot().recent_runs[0].expedition == 4 and player.scaled_health_recovery(40) == 30, "별도 프로세스 원정4 이력/회복 복원"): return
			if not _ack_scene(true) or not sandbox._claim_weapon_reward("") or not _next_without_layout() or not _finish_stage() or not _patterns_enabled(true): return
		"clear-resume":
			controls.show_main_screen()
			if not sandbox.continue_saved_run(): return
			if not _check(recorder.summary_snapshot().completed_run_count == 1 and controls.current_result_snapshot().expedition == 4 and controls.expedition_unlocked() and controls.expedition_cap == 4 and store.load_checkpoint().is_empty(), "원정4 부분 기록 실패·별도 프로세스 복구·원정5 미해금"): return
		"finish", "clear-seed":
			if not _unlock_four(character) or not await _gp321_enter_choices(character, weapon, "rescue") or not _gp321_select_final("liberation"): return
			if phase == "clear-seed":
				expedition_journal.fail_clear = true
				if not _check(not sandbox._acknowledge_story(FinalRitual.ENDING_SCENE) and recorder.summary_snapshot().completed_run_count == 0 and not journal.snapshot().expedition_clears.has(recorder.checkpoint_snapshot().id), "엔딩 성공·원정4 기록 실패는 완주 보류"): return
			else:
				if not _gp323_confirm_final(): return
				var run_id: String = recorder.checkpoint_snapshot().id
				if not _check(extra_encounters == 10 and journal.snapshot().expedition_clears[run_id] == 4 and controls.current_result_snapshot().expedition == 4 and recorder.summary_snapshot().recent_runs[0].expedition == 4, "10개 추가 정예·실제 심장 처치·엔딩·원정4 영구 완주·결과"): return
		"seed", "legacy", "validate", "healing", "story-off", "layout":
			if not _unlock_four(character) or not _start_journey(character, weapon) or not _patterns_enabled(true): return
			if phase == "healing":
				if not _healing_rules(weapon): return
			elif phase == "layout":
				controls.show_main_screen()
				controls.show_start_weapon_selection()
				for width in [1280, 1600]:
					root.size = Vector2i(width, 720)
					await process_frame
					controls._refresh_start_weapon_layout()
					if not _check(controls._safe_area_in_viewport().encloses(controls.expedition_rect) and not controls.expedition_rect.intersects(controls.character_open_rect) and controls.expedition_label().contains("원정 4"), "원정4 안내 두 화면비 배치"): return
			else:
				if not _finish_stage(): return
				var saved := store.load_checkpoint()
				if not _check(saved.stage.expedition == 4 and RunCheckpointStore.valid_state(saved), "유효 원정4 저장"): return
				if phase == "validate":
					for value in [true, null, -1, 5, 3.5, "3", [], {}]:
						var bad := saved.duplicate(true)
						bad.stage.expedition = value
						if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "변조 저장 차단·정상 원정4 보존"): return
					var path := store.save_path
					store.save_path = "user://gp325_missing/checkpoint.json"
					if not _check(sandbox._save_checkpoint(runner.current_metrics()) != OK and runner.expedition == 4, "쓰기 실패로 난이도 변경 없음"): return
					store.save_path = path
				elif phase == "legacy":
					for level in [0, 1, 2, 3]:
						saved.stage.expedition = level
						if level == 0: saved.stage.erase("expedition")
						if store.save_checkpoint(saved) != OK: return
						controls.show_main_screen()
						if not sandbox.continue_saved_run() or not _patterns_enabled(false) or not _check(player.expedition == level and player.scaled_health_recovery(40) == (30 if level >= 2 else 40), "이전 저장 회복·패턴 비소급"): return
				elif phase == "story-off":
					controls.show_main_screen()
					if not sandbox.continue_saved_run() or not _patterns_enabled(true) or not _check(not sandbox.story_run.enabled and player.expedition == 4, "이야기 꺼짐 이어하기"): return
		_:
			_check(false, "알 수 없는 원정4 검사")
			return
	paused = false
	sandbox.free()
	print("GP-325 runtime test: OK (%s %s %s)" % [phase, character, weapon])
	quit(0)

func _unlock_four(character: String) -> bool:
	return _unlock_three(character) and journal.record_ending("prior-three", ArrivalEnding.ID, character, "rescue") == OK and journal.record_expedition_clear("prior-three", 3) == OK

func _patterns_enabled(enabled: bool) -> bool:
	if not super._patterns_enabled(runner.expedition >= 3): return false
	for boss in [runner.boss, runner.guardian, runner.sera, runner.heart]:
		if not _check(boss.expedition_patterns == enabled, "재사용 보스의 난이도 복원·비소급"): return false
	return true

func _step_section() -> bool:
	if not _patterns_enabled(true): return false
	if runner.expedition == 4 and runner.current_section == PrototypeStageRunner.Section.WAVE_TWO:
		if not _check(runner._active_enemies.size() == 4 and runner.armored_boar in runner._active_enemies, "원정4 추가 정예 유지"): return false
		extra_encounters += 1
	if runner.current_section == PrototypeStageRunner.Section.ELITE and runner.final_enemy() is ExpeditionBoss:
		if not _check(runner.current_metrics().stage_objective.contains("재공격"), "실제 보스 구간 HUD 재공격 안내"): return false
	return super._step_section()

func _active_heart() -> bool:
	return super._active_heart() and _patterns_enabled(true) and _check(runner.current_metrics().stage_objective.contains("재공격"), "실제 심장 전투의 원정4 안내")
