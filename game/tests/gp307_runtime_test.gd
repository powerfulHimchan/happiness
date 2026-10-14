extends "res://tests/gp277_306_runtime_test.gd"

var auto_guardian_choice := true

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var character := args[1] if args.size() > 1 else "lumi"
	var weapon := args[2] if args.size() > 2 else "sword"
	var isolated := phase in ["preview", "orders", "validate", "fault", "legacy", "flows"]
	var prefix := "user://gp307_%s_%s_%s" % [phase if isolated else "flow", character, weapon]
	store.save_path = prefix + "_checkpoint.json"
	legacy.save_path = prefix + "_meta.jsonl"
	journal.save_path = prefix + "_story.jsonl"
	if isolated or phase == "seed":
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
			if not await _journey_preview(): return
		"seed":
			if not _start_journey(character, weapon) or not _finish_stage(): return
			if not _check(store.load_checkpoint().story.pending == "stage:1" and runner.visited_regions().is_empty() and PrototypeStory.earned(runner.stage_history, 10) == ["dawn_watch"], "첫 구간은 장면 대기 저장·지역은 두 구간 뒤 완료"): return
		"resume":
			var number := int(args[3])
			if not _restore_journey(number) or not _ack_scene(number % 2 == 0) or not sandbox._claim_weapon_reward(weapon): return
			if number == 2:
				_tap(controls.relic_reward_open_rect.get_center())
				if not _check(sandbox._claim_relic_reward(PrototypeRelic.CLOCK_ID), "2구간 완료 유물·기존 획득 시점 유지"): return
			if not await _next_journey(number) or not _finish_stage(): return
			if not _check(runner.stage_number == number + 1 and store.load_checkpoint().story.pending == "stage:%d" % (number + 1) and RunCheckpointStore.valid_state(store.load_checkpoint()), "각 구간 실제 완료·저장·다음 장면"): return
			if number == 9 and not _check(runner.awaiting_boss_choice() and runner.boss.damage_receiver.max_health == 960 and runner.visited_regions().size() == 4, "10구간 태엽 기사·네 지역 완료·구출/파괴 대기"): return
		"finish":
			if not _restore_journey(10) or not _ack_scene(false): return
			var choice_save := store.load_checkpoint()
			var choice_path := store.save_path
			store.save_path = "user://gp307_missing/choice.json"
			if not _check(not sandbox._resolve_boss_choice("rescue") and runner.boss_choice.is_empty(), "최종 선택 저장 실패는 선택을 되돌림"): return
			store.save_path = choice_path
			if not _check(store.load_checkpoint() == choice_save, "최종 선택 실패는 정상 저장 보존"): return
			if not _check(sandbox._resolve_boss_choice("rescue" if weapon == "sword" else "destroy"), "완주 선택 확정"): return
			var result: Dictionary = controls.current_result_snapshot()
			var summary := recorder.summary_snapshot()
			if not _check(result.run_mode == "journey" and result.stage_count == 10 and result.visited_regions.size() == 4 and summary.completed_run_count == 1 and summary.completion_by_stage_count["10"].completed_run_count == 1 and store.load_checkpoint().is_empty(), "10구간 결과·길이 통계·체크포인트 정리"): return
			if not _check(journal.snapshot().fragments.size() == 8 and journal.snapshot().chronicles.has("regions_rescue" if weapon == "sword" else "regions_destroy"), "각 두 구간에서도 중복 조각 없이8종·기존 여행 기록"): return
		"records":
			controls.show_main_screen()
			controls.show_village()
			controls.village_page = "history"
			var cards: Array = controls.village_snapshot().cards
			if not _check(cards[0].name.begins_with("전체 여정") and cards[0].lines.has("전체 여정 · 10스테이지") and recorder.summary_snapshot().completed_run_count == 1, "재실행 후 전체 여정 이력·완주 중복 없음"): return
			controls.village_page = "record_lengths"
			if not _check(controls.village_snapshot().cards[2].id == "10" and controls.village_snapshot().cards[2].status == "완주 1회", "광장3/5/10 길이별 집계"): return
			controls.begin_retry()
			if not _check(runner.run_mode == "standard" and runner.region_order.is_empty() and runner.stage_limit == 3, "새 일반 도전은10구간 모드/순서 초기화"): return
		"orders":
			if not _journey_orders(): return
		"validate":
			if not _start_journey(character, weapon) or not _finish_stage() or not _ack_scene(true) or not sandbox._claim_weapon_reward(""): return
			if not _next_without_layout() or not _finish_stage() or not _ack_scene(true) or not sandbox._claim_weapon_reward(""): return
			if not _next_without_layout() or not _finish_stage(): return
			if not _journey_invalid(): return
		"fault":
			if not _start_journey(character, weapon) or not _finish_stage() or not _ack_scene(true): return
			var saved := store.load_checkpoint()
			var path := store.save_path
			store.save_path = "user://gp307_missing/checkpoint.json"
			if not _check(not sandbox._claim_weapon_reward(weapon) and not runner.reward_claimed and controls.current_screen_mode() == 11, "10구간 보상 저장 실패는 선택 되돌림"): return
			store.save_path = path
			if not _check(store.load_checkpoint() == saved and sandbox._claim_weapon_reward(weapon), "원래 체크포인트 보존·보상 재시도"): return
			if not _next_without_layout() or not _finish_stage(): return
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and runner.stage_number == 2 and runner.region_order == saved.stage.region_order, "재시도 후 다음 구간 저장·지역 순서 유지"): return
		"legacy":
			controls.begin_retry(weapon, 3)
			if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			var saved := store.load_checkpoint()
			controls.selected_stage_limit = 10
			controls.selected_run_mode = "journey"
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and runner.stage_limit == 3 and runner.run_mode == "standard" and store.load_checkpoint() == saved, "10구간 준비 선택과 기존3구간 이어하기 독립"): return
		"flows":
			if not _check(legacy.grant("gp307-helper", "rescue") == OK, "기사 동행 준비"): return
			sandbox._update_boss_legacy_status()
			controls.use_boss_legacy = true
			if not controls.begin_retry(weapon, 10, "journey", character): return
			for number in range(1, 10):
				if number == 6 and not _check(not legacy.spend_assist(player.boss_legacy, 6), "기존 기본 API는 범위 밖6 지원 차단"): return
				if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
				if not _check(RunCheckpointStore.valid_state(store.load_checkpoint()), "기사 동행은6~9구간 지원 저장 가능"): return
				if not _next_without_layout(): return
			if not _reach_journey_elite() or not _check(player.boss_legacy.assisted_stages.has(10), "10구간 실제 기사 지원 기록"): return
			var damaged := FileAccess.open(store.save_path, FileAccess.WRITE)
			damaged.store_string("broken")
			damaged.close()
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and runner.stage_number == 8 and player.boss_legacy.assisted_stages.has(10), "손상 주 파일은8구간 백업·후속 지원 소비 저널 복원"): return
			if not _next_without_layout() or not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			if not _check(store.load_checkpoint().stage.number == 9 and not store.load_checkpoint().boss_legacy.assisted_stages.has(10), "백업 뒤9구간 정상 저장·후속 소비는 독립 저널 유지"): return
			if not _next_without_layout() or not _reach_journey_elite(): return
			if not _check(runner.boss.damage_receiver.health == runner.boss.damage_receiver.max_health and player.boss_legacy.assisted_stages.has(10), "복원 후10구간 기사 지원 중복 피해 없음"): return
			var elapsed := runner.stage_elapsed_s
			var saved := store.load_checkpoint()
			controls.open_run_build()
			for ignored in 5: await process_frame
			if not _check(paused and runner.stage_elapsed_s == elapsed and store.load_checkpoint() == saved, "10구간 조회·시간/저장 보존"): return
			controls.close_run_build()
			controls.advance_mode_timer_for_test(3.1)
			if not _check(not paused and not sandbox.story_run.enabled and player.boss_legacy.assisted_stages.has(9), "이야기 꺼짐·후반 동행 지원·조회 복귀"): return
		_:
			_check(false, "알 수 없는 검사")
			return
	paused = false
	sandbox.free()
	print("GP-307 runtime test: OK (%s %s %s)" % [phase, character, weapon])
	quit(0)

func _start_journey(character: String, weapon: String) -> bool:
	controls.show_main_screen()
	controls.show_start_weapon_selection()
	controls.selected_character_id = character
	controls.selected_starting_weapon = weapon
	controls.selected_story_enabled = true
	runner.region_rng.seed = 307 if character == "roan" else 308
	_tap(controls.start_length_rects[3].get_center())
	_tap(controls.start_weapon_confirm_rect.get_center())
	if not _check(runner.run_mode == "journey" and runner.stage_limit == 10 and runner.route_id == runner.region_order[0] and player.character_id == character and festival_terrain.get_child_count() >= 3, "실제10구간 입력·무작위 첫 지역·첫 구간 실제 지형"): return false
	return _ack_scene(true)

func _restore_journey(number: int) -> bool:
	var saved := store.load_checkpoint()
	if not _check(not saved.is_empty() and int(saved.stage.number) == number, "별도 프로세스 복원용 체크포인트"): return false
	for ignored in 2:
		controls.show_main_screen()
		controls.selected_stage_limit = 3
		controls.selected_run_mode = "standard"
		if not _check(sandbox.continue_saved_run() and runner.stage_number == number and runner.stage_limit == 10 and runner.run_mode == "journey" and runner.region_order == saved.stage.region_order and player.damage_receiver.health == saved.player.health and weapons.skills == saved.weapons.skills and player.character_id == saved.player.character_id and store.load_checkpoint() == saved, "별도 프로세스 반복 이어하기·순서/주인공/성장/잔량 유지"): return false
	return true

func _next_without_layout() -> bool:
	var offers := runner.available_routes()
	if not _check(not offers.is_empty(), "다음 구간 존재"): return false
	_tap(controls.stage_route_rects[-1].get_center())
	return _check(not paused and runner.route_id == offers[-1].id, "실제 다음 구간 입력")

func _next_journey(number: int) -> bool:
	var offers := runner.available_routes()
	var saved := store.load_checkpoint()
	var order := runner.region_order.duplicate()
	if number < 8 and number % 2 == 1:
		if not _check(offers.size() == 1 and offers[0].id == runner.route_id, "홀수 완료는같은 지역 두번째 구간만 허용"): return false
	elif number < 8:
		if not _check(offers.size() == mini(2, 4 - number / 2) and offers.all(func(route: Dictionary) -> bool: return route.id not in runner.visited_regions()), "짝수 완료는미방문 두 지역 후보"): return false
	else:
		if not _check(offers.size() == 1 and offers[0].id == ("city_gate" if number == 8 else "city_core"), "네 지역 이후성문→중심부 고정"): return false
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls.show_stage_routes(number, 10, 0, offers)
		controls.queue_redraw()
		await process_frame
		var safe: Rect2 = controls.layout_snapshot().safe
		for rect in controls.stage_route_rects:
			if not _check(safe.encloses(rect), "10구간 후보 입력 두 화면비 안전영역"): return false
		_tap(controls.skill_reward_open_rect.get_center())
		_tap(controls.skill_reward_cancel_rect.get_center())
		if not _check(runner.available_routes() == offers and runner.region_order == order and store.load_checkpoint() == saved, "스킬 비교취소는 순서/후보/저장 무변경"): return false
	return _next_without_layout()

func _journey_preview() -> bool:
	controls.show_main_screen()
	var before := runner.checkpoint_snapshot()
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls.show_start_weapon_selection()
		var safe: Rect2 = controls.layout_snapshot().safe
		var rects: Array = controls.start_length_rects.duplicate()
		rects.append_array(controls.start_weapon_card_rects)
		rects.append_array(controls.memory_card_rects)
		rects.append_array([controls.character_open_rect, controls.boss_legacy_toggle_rect, controls.start_weapon_confirm_rect, controls.start_weapon_cancel_rect])
		for i in rects.size():
			if not _check(safe.encloses(rects[i]), "전체 여정 준비버튼 안전영역"): return false
			for j in range(i + 1, rects.size()):
				if not _check(not rects[i].intersects(rects[j]), "준비 선택버튼 비중첩"): return false
		_tap(controls.start_length_rects[3].get_center())
		controls.queue_redraw()
		await process_frame
		if not _check(controls.selected_run_mode == "journey" and runner.checkpoint_snapshot() == before, "전체 여정 미리 선택은실제 도전 무변경"): return false
		_tap(controls.start_weapon_cancel_rect.get_center())
		if not _check(controls.selected_stage_limit == 3 and controls.selected_run_mode == "standard", "준비 취소는직전 모드 복원"): return false
	for args in [["sword", 10, "standard"], ["bow", 5, "journey"], ["sword", 10, "regions"], ["sword", 1, "standard"]]:
		if not _check(not controls.begin_retry(args[0], args[1], args[2]) and runner.checkpoint_snapshot() == before, "모드/길이 불일치로저장 삭제 차단"): return false
	return true

func _journey_orders() -> bool:
	var found: Dictionary = {}
	runner.stage_limit = 10
	runner.set_run_mode("journey")
	for seed in 96:
		runner.region_rng.seed = seed
		runner.reset_run()
		var order := runner.region_order.duplicate()
		found[str(order)] = true
		var history: Array = []
		var route: String = order[0]
		for number in range(1, 11):
			history.append({"stage": number, "route": route})
			if not _check(JourneyRoutePlan.valid_history(history, order), "96시드의두구간·중복없는 네지역·최종구간 이력"): return false
			var candidates := JourneyRoutePlan.candidates(number, route, history, order)
			if number < 10: route = candidates[-1]
		if not _check(JourneyRoutePlan.completed_regions(history).size() == 4 and JourneyRoutePlan.candidates(10, route, history, order).is_empty(), "열번째구간 이후후보 없음·4지역 완료"): return false
	return _check(found.size() >= 20, "첫지역과전체순서 무작위 다양성")

func _journey_invalid() -> bool:
	var saved := store.load_checkpoint()
	var raw := FileAccess.get_file_as_string(store.save_path)
	var invalid: Array[Dictionary] = []
	for mode in [null, true, "standard", "regions", "invalid"]:
		var bad := saved.duplicate(true)
		bad.stage.run_mode = mode
		invalid.append(bad)
	for key in ["run_mode", "region_order"]:
		var bad := saved.duplicate(true)
		bad.stage.erase(key)
		invalid.append(bad)
	for order in [null, [], ["wind", "wind", "ruins", "festival"]]:
		var bad := saved.duplicate(true)
		bad.stage.region_order = order
		invalid.append(bad)
	for index in 3:
		var bad := saved.duplicate(true)
		bad.stage.history[index].route = "city_gate" if index == 0 else "meadow" if index == 1 else bad.stage.history[0].route
		if index == 2: bad.stage.route = bad.stage.history[2].route
		invalid.append(bad)
	for value in [3, 5, 9, 11, 10.5, true]:
		var bad := saved.duplicate(true)
		bad.stage.limit = value
		invalid.append(bad)
	for bad in invalid:
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and FileAccess.get_file_as_string(store.save_path) == raw, "이력/모드/순열/길이변조 원자적 거부"): return false
	return true

func _reach_journey_elite() -> bool:
	for ignored in 10:
		if runner.current_section == PrototypeStageRunner.Section.ELITE: return true
		if not _step_section(): return false
	return _check(false, "실제 마지막 적 구간 도달")

# 기존 여정 회귀는 성문 선택을 실제 입력으로 확정하고 기존 보상 흐름을 계속 검사한다.
func _ack_scene(skip: bool) -> bool:
	if not super._ack_scene(skip): return false
	return _choose_guardian_for_regression()

func _finish_stage() -> bool:
	if not super._finish_stage(): return false
	return _choose_guardian_for_regression() if not sandbox.story_run.enabled else true

func _choose_guardian_for_regression() -> bool:
	if auto_guardian_choice and runner.awaiting_guardian_choice():
		if not _check(controls.current_screen_mode() == 12, "성문 수호기사 실제 선택 화면"): return false
		_tap(controls.boss_choice_rects[0].get_center())
		_tap(controls.boss_choice_confirm_rect.get_center())
		return _check(runner.guardian_choice == "rescue" and controls.current_screen_mode() == 11, "성문 선택 후 기존 보상 흐름 회귀")
	return true
