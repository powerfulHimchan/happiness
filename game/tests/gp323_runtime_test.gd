extends "res://tests/gp322_runtime_test.gd"

var expected_level := 2
var expedition_journal := ExpeditionJournal.new()

class ExpeditionJournal extends FailingStoryJournal:
	var fail_clear := false
	func _append(event: Dictionary) -> Error:
		return ERR_CANT_CREATE if fail_clear and event.get("event") == "expedition_clear" else super._append(event)

func _run() -> void:
	heart_battle_for_tests = true
	final_ritual_for_tests = true
	auto_guardian_choice = false
	legacy_final_boss_for_tests = false
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var character := args[1]
	var weapon := args[2]
	expedition_story = phase not in ["healing", "story-off"]
	expected_level = 1 if phase in ["clear-fault", "clear-seed", "clear-resume"] else 2
	legacy = FaultStore.new()
	journal = expedition_journal
	var continuing := phase in ["resume", "clear-resume"]
	var prefix := "user://gp323_%s_%s_%s" % ["clearflow" if phase in ["clear-seed", "clear-resume"] else "flow" if phase in ["seed", "resume"] else phase, character, weapon]
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
		"preview", "migration":
			if journal.record_ending("prior-arrival", ArrivalEnding.ID, character, "rescue") != OK: return
			controls.show_main_screen()
			controls.show_start_weapon_selection()
			_tap(controls.start_length_rects[3].get_center())
			if not _check(controls.expedition_unlocked() and controls.expedition_cap == 1 and not controls.begin_retry(weapon, 10, "journey", character, false, 2), "원정 1 미완주 시 원정 2 시작 차단"): return
			if phase == "preview":
				if journal.record_expedition_clear("prior-arrival", 1) != OK: return
				controls.expedition_unlocked()
				for expected in [1, 2, 0]:
					_tap(controls.expedition_rect.get_center())
					if not _check(controls.selected_expedition == expected, "기본·원정1·원정2 실제 순환 입력"): return
				_tap(controls.expedition_rect.get_center())
				_tap(controls.expedition_rect.get_center())
				_tap(controls.start_weapon_cancel_rect.get_center())
				if not _check(controls.selected_expedition == 0 and not controls.begin_retry(weapon, 5, "regions", character, false, 2), "준비 취소·다른 모드 원정2 차단"): return
			else:
				# Existing GP-322 completion is older than the latest 12 runs; matching ending is required.
				recorder._append_event("run_completed", {"run_id": "prior-arrival", "run_mode": "journey", "stage_count": 10, "expedition": 1, "character_id": character, "boss_choice": "rescue", "completion_s": 100.0})
				recorder._append_event("run_completed", {"run_id": "unmatched", "run_mode": "journey", "stage_count": 10, "expedition": 2, "character_id": character, "boss_choice": "rescue", "completion_s": 100.0})
				for index in 15: recorder._append_event("run_started", {"run_id": "later-%d" % index})
				expedition_journal.fail_clear = true
				sandbox._refresh_checkpoint()
				controls.expedition_unlocked()
				if not _check(controls.expedition_cap == 1, "기존 기록 이관 실패는 미해금 유지"): return
				expedition_journal.fail_clear = false
				sandbox._refresh_checkpoint()
				controls.expedition_unlocked()
				if not _check(controls.expedition_cap == 2 and journal.snapshot().expedition_clears.size() == 1 and not journal.snapshot().expedition_clears.has("unmatched"), "이전 원정1 완주+엔딩 일치만 영구 해금·최근 12개와 독립"): return
				recorder.clear_records()
				if not _check(controls.expedition_unlocked() and controls.expedition_cap == 2, "도전 기록 삭제 후 해금 영구 보존"): return
		"seed", "validate", "legacy", "healing", "layout", "story-off":
			if not _unlock_two(character) or not _start_journey(character, weapon): return
			if phase == "layout":
				controls.show_main_screen()
				controls.show_start_weapon_selection()
				for width in [1280, 1600]:
					root.size = Vector2i(width, 720)
					await process_frame
					controls._refresh_start_weapon_layout()
					if not _check(controls._safe_area_in_viewport().encloses(controls.expedition_rect) and not controls.expedition_rect.intersects(controls.character_open_rect) and controls.expedition_label().contains("75%"), "원정2 안내·두 화면비 배치"): return
			elif phase == "healing":
				if not _healing_rules(weapon): return
			else:
				if not _finish_stage(): return
				var saved := store.load_checkpoint()
				if not _check(saved.stage.expedition == 2 and player.expedition == 2 and RunCheckpointStore.valid_state(saved), "원정2 완료 저장·회복 효율 유지"): return
				if phase == "validate":
					for value in [true, null, -1, 6, 2.5, "2", [], {}]:
						var bad := saved.duplicate(true)
						bad.stage.expedition = value
						if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and saved == store.load_checkpoint(), "잘못된 난이도 거부·정상 저장 보존"): return
					var path := store.save_path
					store.save_path = "user://gp323_missing/checkpoint.json"
					if not _check(sandbox._save_checkpoint(runner.current_metrics()) != OK and player.expedition == 2, "쓰기 실패 시 난이도·회복 유지"): return
					store.save_path = path
				elif phase == "legacy":
					for level in [0, 1]:
						if level == 0: saved.stage.erase("expedition")
						else: saved.stage.expedition = 1
						if store.save_checkpoint(saved) != OK: return
						controls.show_main_screen()
						if not sandbox.continue_saved_run() or not _check(runner.expedition == level and player.expedition == level and player.scaled_health_recovery(40) == 40, "기존 기본·원정1 저장은 회복 감소 비소급"): return
				elif phase == "story-off":
					controls.show_main_screen()
					if not sandbox.continue_saved_run() or not _check(not sandbox.story_run.enabled and player.expedition == 2, "이야기 꺼짐 원정2 재실행 복원"): return
		"resume":
			if not _restore_journey(1) or not _check(runner.expedition == 2 and player.expedition == 2 and recorder.summary_snapshot().recent_runs[0].expedition == 2, "별도 프로세스 난이도·회복·이력 복원"): return
			if not _ack_scene(true) or not sandbox._claim_weapon_reward("") or not _next_without_layout() or not _finish_stage(): return
			if not _check(extra_encounters == 1 and store.load_checkpoint().stage.expedition == 2, "다음 지역 추가 정예·난이도 유지"): return
		"clear-resume":
			controls.show_main_screen()
			if not sandbox.continue_saved_run() or not _check(recorder.summary_snapshot().completed_run_count == 1 and controls.current_result_snapshot().expedition == 1 and controls.expedition_unlocked() and controls.expedition_cap == 2 and store.load_checkpoint().is_empty(), "별도 프로세스 원정 기록 부분 성공 복구·한 번 완주·영구 해금"): return
		"finish", "clear-fault", "clear-seed":
			if phase == "finish" and not _unlock_two(character): return
			if not await _gp321_enter_choices(character, weapon, "rescue") or not _gp321_select_final("liberation"): return
			if phase in ["clear-fault", "clear-seed"]:
				expedition_journal.fail_clear = true
				if not _check(not sandbox._acknowledge_story(FinalRitual.ENDING_SCENE) and recorder.summary_snapshot().completed_run_count == 0 and journal.snapshot().endings.has("liberation") and journal.snapshot().expedition_clears.is_empty() and not runner.current_metrics().run_complete, "엔딩 성공·원정 기록 실패는 완주/상위 해금 차단"): return
				controls.show_main_screen()
				if not _check(not sandbox.continue_saved_run(), "지속된 원정 기록 실패는 이어하기도 보류"): return
				if phase == "clear-seed":
					paused = false
					sandbox.free()
					print("GP-323 runtime test: OK (%s %s %s)" % [phase, character, weapon])
					quit(0)
					return
				expedition_journal.fail_clear = false
				if not sandbox.continue_saved_run(): return
			else:
				if not _gp323_confirm_final(): return
			var run_id: String = recorder.checkpoint_snapshot().id
			if not _check(journal.snapshot().expedition_clears[run_id] == expected_level and recorder.summary_snapshot().completed_run_count == 1 and controls.current_result_snapshot().expedition == expected_level and recorder.summary_snapshot().recent_runs[0].expedition == expected_level, "실제 심장 처치·엔딩·원정 영구 기록·결과·한 번 완주"): return
			if not _check(extra_encounters == 10 and controls.expedition_unlocked() and controls.expedition_cap == mini(3, expected_level + 1), "추가 정예10개·최종 해금"): return
			recorder.clear_records()
			if not _check(controls.expedition_unlocked() and controls.expedition_cap == mini(3, expected_level + 1) and journal.record_expedition_clear(run_id, expected_level) == OK and journal.record_expedition_clear(run_id, 5) == ERR_INVALID_DATA, "기록 삭제·중복 확인·잘못된 원정 거부"): return
		_:
			_check(false, "알 수 없는 원정2 검사")
			return
	paused = false
	sandbox.free()
	print("GP-323 runtime test: OK (%s %s %s)" % [phase, character, weapon])
	quit(0)

func _unlock_two(character: String) -> bool:
	return journal.record_ending("prior-arrival", ArrivalEnding.ID, character, "rescue") == OK and journal.record_expedition_clear("prior-arrival", 1) == OK

func _start_journey(character: String, weapon: String) -> bool:
	controls.show_main_screen()
	controls.show_start_weapon_selection()
	controls.selected_character_id = character
	controls.selected_starting_weapon = weapon
	controls.selected_backup_weapon = "sword" if weapon == "bow" else "bow"
	controls.selected_story_enabled = expedition_story
	controls.selected_expedition = 0
	_tap(controls.start_length_rects[3].get_center())
	for index in expected_level: _tap(controls.expedition_rect.get_center())
	_tap(controls.start_weapon_confirm_rect.get_center())
	if not _check(runner.expedition == expected_level and player.expedition == expected_level and runner.run_mode == "journey", " 실제 준비 입력으로 난이도 시작"): return false
	return _ack_scene(true) if expedition_story else true

func _active_heart() -> bool:
	runner.heart.set_process(false)
	return _check(runner.expedition == expected_level and runner.heart_battle == HeartEncounter.ACTIVE and runner.heart.is_targetable() and store.load_checkpoint().stage.expedition == expected_level and player.expedition == expected_level, "선택 난이도로 실제 심장 전투·저장·회복 유지")

func _step_section() -> bool:
	if runner.current_section == PrototypeStageRunner.Section.WAVE_TWO and runner.expedition == 2:
		if not _check(runner._active_enemies.size() == 4 and runner.armored_boar in runner._active_enemies, "원정2에도 추가 정예 유지"): return false
		extra_encounters += 1
	return super._step_section()

func _gp323_confirm_final() -> bool:
	return _gp321_confirm_final()

func _healing_rules(weapon: String) -> bool:
	player.damage_receiver.max_health = 100
	player.damage_receiver.health = 20
	player.prepare_potions(PrototypePotionRecipes.BASIC)
	player.relic_state = {}
	if not _check(player.use_recovery_potion() and player.damage_receiver.health == 39 and player.potions_remaining == 1, "기본25 회복약은19 회복·1회 소비"): return false
	player.damage_receiver.health = 20
	if not _check(player.collect_recovery_orb() and player.damage_receiver.health == 28, "회복구슬10은8 회복·중복 보정 없음"): return false
	player.apply_growth_health(20, 20)
	if not _check(player.damage_receiver.max_health == 120 and player.damage_receiver.health == 43, "최대 체력 증가는 원래20·회복만15"): return false
	player.damage_receiver.max_health = 100
	player.damage_receiver.health = 20
	festival_ultimate._active_profile = {"heal": 40}
	festival_ultimate._apply_job_effect()
	if not _check(player.damage_receiver.health == 50, "회복형 필살기40은30 회복"): return false
	player.set_barrier_unlocked(true)
	player.damage_receiver.barrier_health = 0
	player.recover_barrier(10)
	if not _check(player.damage_receiver.barrier_health == 10 and player.scaled_health_recovery(1) == 1 and player.scaled_health_recovery(4) == 3, "방벽 제외·체력 정수 올림 경계"): return false
	player.set_barrier_unlocked(false)
	if not _step_section(): return false
	var target := runner.leaf_slime
	target.damage_receiver.max_health = 1000
	target.damage_receiver.health = 1000
	player.set_lifesteal_unlocked(true)
	player.damage_receiver.health = 20
	var event := DamageEvent.new()
	event.event_id = &"gp323:lifesteal"
	event.attacker_id = &"player"
	event.damage = 80
	event.tags = PackedStringArray([weapon, "basic"])
	if not _check(player.deal_weapon_damage(target, event) == DamageReceiver.Result.APPLIED and player.damage_receiver.health == 23, "실제 검/활 피해80의 흡수4는3 회복"): return false
	player.lifesteal_unlocked = false
	for id in ["victory_recovery", "victory_recovery_boost", "victory_resilience"]: growth.ranks[id] = 1
	player.damage_receiver.health = 20
	event.event_id = &"gp323:victory"
	event.damage = 9999
	player.deal_weapon_damage(target, event)
	if not _check(player.damage_receiver.health == 23, "실제 처치 회복4는3 회복"): return false
	for id in ["victory_recovery", "victory_recovery_boost", "victory_resilience"]: growth.ranks.erase(id)
	player.relic_state = {"id": PrototypeRelic.PHOENIX_ID, "used": false}
	player.damage_receiver.health = 1
	var fatal := DamageEvent.new()
	fatal.event_id = &"gp323:phoenix"
	fatal.damage = 9999
	fatal.tags = PackedStringArray(["enemy"])
	player.receive_damage(fatal)
	if not _check(not player.damage_receiver.dead and player.damage_receiver.health == 50 and player.relic_state.used, "불사조 부활 체력50%는 원래 효과 유지"): return false
	player.relic_state = {}
	# Remove XP side effects only for measuring stage recovery; real stage gates still run.
	for enemy in runner._all_combat_enemies():
		if enemy.defeated.is_connected(growth._on_enemy_defeated): enemy.defeated.disconnect(growth._on_enemy_defeated)
	player.damage_receiver.health = 1
	var route := runner.route_id
	if not _finish_stage(): return false
	var raw := 20 + (10 if route == "forest" else 15 if route == "festival" else 0)
	if not _check(player.damage_receiver.health == 1 + ceili(raw * 0.75), "실제 스테이지 완료 회복과 지역 보너스에 한 번만75% 적용"): return false
	var saved := store.load_checkpoint()
	if not _check(not saved.is_empty(), "회복 검증 후 실제 유효 저장"): return false
	controls.show_main_screen()
	if not sandbox.continue_saved_run() or not _check(player.damage_receiver.health == saved.player.health and player.expedition == expected_level, "체력 복원은 다시 감소하지 않음"): return false
	return true
