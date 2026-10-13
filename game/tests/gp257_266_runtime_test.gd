extends "res://tests/gp247_256_runtime_test.gd"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var weapon := args[1] if args.size() > 1 else "sword"
	var isolated := phase in ["preview", "orders", "validate", "fault", "flows"]
	var prefix := "user://gp266_%s_%s" % [phase if isolated else "legacy" if phase.begins_with("legacy") else "flow", weapon]
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
	festival_terrain = sandbox.get_node("RouteTerrain")
	festival_ultimate = sandbox.get_node("Player/UltimateController")
	traps = sandbox.get_node("ClockTrapController")
	for actor in [player, weapons, weapons.sword_combat, weapons.bow_combat, festival_ultimate, runner, traps, festival_terrain]:
		actor.set_process(false)
		actor.set_physics_process(false)
	growth.jobs_enabled = false
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	match phase:
		"preview":
			if not _test_preview(weapon): return
			if not _check(legacy.grant("gp266-preview", "destroy") == OK, "실제 파괴 일회 보상 준비"): return
			sandbox._update_boss_legacy_status()
			if not _start_regions(weapon) or not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			if not _check(player.boss_legacy.choice == "destroy" and legacy.pending_reward().is_empty(), "순회에서도 핵 효과 적용·일회 소비"): return
			if not await _test_candidates(): return
		"seed":
			if not _start_regions(weapon): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "연습 정예 저장·무기 보상"): return
			if not await _test_candidates(): return
			if not _check(store.load_checkpoint().stage.region_order == runner.region_order and runner.visited_regions().is_empty() and RunCheckpointStore.VERSION == 1, "우선순위 저장·연습은 지역 통과 제외·버전1"): return
		"resume2", "resume3", "resume4", "boss":
			var stage: int = {"resume2": 2, "resume3": 3, "resume4": 4, "boss": 5}[phase]
			if not _restore_regions(stage - 1): return
			if not await _test_candidates(): return
			if not _pick_region((stage + (1 if weapon == "bow" else 0)) % 2): return
			if not _check(runner.stage_number == stage and runner.current_metrics().run_route_name == ("바람꽃 평원" if runner.route_id == "wind" else PrototypeStageRunner.route_profile(runner.route_id).name), "지역 이름·실제 스테이지 배정"): return
			if not _check(festival_terrain.get_child_count() == (3 if runner.route_id == "wind" else 4) and runner.seed_sack.forest_variant == (runner.route_id == "forest") and runner.seed_sack.ruins_variant == (runner.route_id == "ruins") and runner.seed_sack.festival_variant == (runner.route_id == "festival"), "각 지역 실제 지형·적 패턴 연결"): return
			if not _finish_stage(): return
			if stage == 5:
				if not _check(runner.awaiting_boss_choice() and runner.boss.damage_receiver.max_health == 720 and runner.visited_regions().size() == 4 and store.load_checkpoint().stage.history.size() == 5, "네 지역 통과·720 보스 선택 대기 저장"): return
			else:
				if not _check(sandbox._claim_weapon_reward(""), "지역 정예 보상 저장"): return
				if stage == 2:
					_tap(controls.relic_reward_open_rect.get_center())
					if not _check(sandbox._claim_relic_reward(PrototypeRelic.CLOCK_ID), "순회에서도 실제 유물 획득·저장"): return
				if not _check(runner.visited_regions().size() == stage - 1 and controls.surveyed_routes.has(runner.route_id), "중복 없는 지역 통과·영구 답사"): return
		"finish":
			if not _restore_regions(5): return
			if not _check(sandbox._resolve_boss_choice("rescue" if weapon == "sword" else "destroy"), "순회 최종 구출/파괴 확정"): return
			var result: Dictionary = controls.current_result_snapshot()
			var summary := recorder.summary_snapshot()
			if not _check(result.run_mode == "regions" and result.visited_regions.size() == 4 and result.stage_count == 5 and summary.completed_run_count == 1 and summary.completion_by_stage_count["5"].completed_run_count == 1 and summary.recent_runs[0].run_mode == "regions" and store.load_checkpoint().is_empty(), "순회 결과·5단계 통계·이력·저장 정리"): return
			recorder.reload_records_for_test()
			controls.show_main_screen()
			controls.show_village()
			controls.village_page = "history"
			if not _check(controls.village_snapshot().cards[0].name.begins_with("지역 순회") and controls.village_snapshot().cards[0].lines.has("네 지역 순회 · 5스테이지"), "광장 이력에서 순회 구분·재시작 기록 유지"): return
			controls.begin_retry(weapon, 3)
			if not _check(runner.run_mode == "standard" and runner.region_order.is_empty() and not runner.checkpoint_snapshot().has("run_mode") and runner.stage_number == 1 and controls.surveyed_routes.size() == 5, "일반 새 도전 초기화·네 지역/연습 답사 유지"): return
		"legacy-seed":
			controls.begin_retry(weapon, 5)
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "기존5단계 저장 준비"): return
			if not _check(not store.load_checkpoint().stage.has("run_mode") and not store.load_checkpoint().stage.has("region_order"), "일반 저장은 추가 필드 없이 기존 형식 유지"): return
		"legacy":
			controls.selected_run_mode = "regions"
			controls.selected_stage_limit = 5
			if not _check(sandbox.continue_saved_run() and runner.run_mode == "standard" and runner.region_order.is_empty() and controls.all_stage_route_options.size() == 5, "준비 순회 선택과 이전 일반 저장 복원 독립"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "기존 반복 풀숲 경로 계속 진행"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _check(runner.route_id == "meadow" and runner.stage_number == 3, "일반 도전 반복 경로 유지"): return
		"orders":
			if not _test_orders(): return
		"validate":
			if not _start_regions(weapon) or not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			for ignored in 2:
				if not _pick_region(0) or not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			if not _test_invalid_states(): return
		"fault":
			if not _start_regions(weapon) or not _finish_stage() or not sandbox._claim_weapon_reward("") or not _pick_region(0) or not _finish_stage(): return
			var saved := store.load_checkpoint()
			var before := weapons.checkpoint_snapshot()
			var path := store.save_path
			store.save_path = "user://gp266_missing/checkpoint.json"
			if not _check(not sandbox._claim_weapon_reward("bow") and weapons.checkpoint_snapshot() == before and runner.region_order == saved.stage.region_order and runner.visited_regions().size() == 1, "무기 보상 저장 실패·장비 롤백·지역 순서 보존"): return
			store.save_path = path
			if not _check(store.load_checkpoint() == saved and sandbox._claim_weapon_reward("bow"), "기존 저장 원자적 유지·다시 확정"): return
			if not _restore_regions(2) or not await _test_candidates(): return
		"flows":
			if not _start_regions(weapon) or not _finish_stage() or not sandbox._claim_weapon_reward("") or not _pick_region(0): return
			var before := store.load_checkpoint()
			var elapsed := runner.stage_elapsed_s
			var order := runner.region_order.duplicate()
			controls.open_run_build()
			controls.run_build_tab = 2
			controls.run_build_page = 0
			var cards := PrototypeRunBuildView.cards(2, sandbox._capture_run_build())
			if not _check(cards.any(func(card: Dictionary) -> bool: return card.id == "regions" and card.status == "통과 0/4 · 남은 4곳"), "현재 도전 정보에 순회 진행 카드"): return
			for ignored in 5: await process_frame
			if not _check(paused and runner.stage_elapsed_s == elapsed and runner.region_order == order and store.load_checkpoint() == before, "도전 정보 조회는 전투·우선순위·저장 동결"): return
			controls.close_run_build()
			controls.advance_mode_timer_for_test(3.1)
			if not _check(not paused and runner.region_order == order, "복귀 카운트다운 후 같은 지역 순서"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-257–266 runtime test: OK (%s %s)" % [phase, weapon])
	quit(0)

func _start_regions(weapon: String) -> bool:
	controls.show_main_screen()
	controls.show_start_weapon_selection()
	controls.selected_starting_weapon = weapon
	runner.region_rng.seed = 42 if weapon == "sword" else 43
	_tap(controls.start_length_rects[2].get_center())
	if controls.pending_boss_legacy.get("choice", "") == "destroy":
		if not _check(controls.start_legacy_description().contains("일반 도전"), "순회 준비는 위험 길 제외를 정확히 안내"): return false
	_tap(controls.start_weapon_confirm_rect.get_center())
	return _check(runner.run_mode == "regions" and runner.stage_limit == 5 and runner.stage_number == 1 and runner.region_order.size() == 4 and runner.current_metrics().run_route_name == "연습 구간", "실제 순회 버튼·검/활 시작·연습 후 네 지역")

func _restore_regions(stage: int) -> bool:
	var before := store.load_checkpoint()
	for ignored in 2:
		controls.show_main_screen()
		controls.selected_run_mode = "standard"
		controls.selected_stage_limit = 3
		if not _check(sandbox.continue_saved_run() and runner.run_mode == "regions" and runner.stage_limit == 5 and runner.stage_number == stage and runner.region_order == before.stage.region_order and player.damage_receiver.health == before.player.health and festival_ultimate.gauge == before.ultimate.gauge and weapons.skills == before.weapons.skills and store.load_checkpoint() == before, "별도 프로세스 반복 복원·모드/순서/성장/잔량 보존·추가 보상 없음"): return false
	return true

func _pick_region(preferred: int) -> bool:
	var options := runner.available_routes()
	var index := preferred % options.size()
	var id: String = options[index].id
	var visited := runner.visited_regions()
	var order := runner.region_order.duplicate()
	_tap(controls.stage_route_rects[index].get_center())
	return _check(runner.route_id == id and id not in visited and runner.region_order == order and not paused, "실제 미방문 카드 선택·기존 성장 유지")

func _test_candidates() -> bool:
	var before := store.load_checkpoint()
	var visited := runner.visited_regions()
	var order := runner.region_order.duplicate()
	var offers := runner.available_routes()
	if not _check(offers.size() == mini(2, 4 - visited.size()) and offers.all(func(route: Dictionary) -> bool: return route.id not in visited and route.id in runner.REGION_IDS) and not runner.can_select_route("meadow") and not runner.can_select_route("clockwork"), "미방문 최대 두 후보·연습/위험 경로 제외"): return false
	for id in visited:
		if not _check(not runner.can_select_route(id) and not runner.next_stage(id), "이미 통과한 지역 재선택 거부"): return false
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls.show_stage_routes(runner.stage_number, 5, 0, offers)
		var safe: Rect2 = controls.layout_snapshot().safe
		var rects: Array = controls.stage_route_rects.duplicate()
		rects.append(controls.skill_reward_open_rect)
		if controls.relic_offer_available: rects.append(controls.relic_reward_open_rect)
		for i in rects.size():
			if not _check(safe.encloses(rects[i]), "두 화면비 순회 카드/보상 입력 안전 영역"): return false
			for j in range(i + 1, rects.size()):
				if not _check(not rects[i].intersects(rects[j]), "후보 한/두 개·보상 입력 비중첩"): return false
		controls.queue_redraw()
		await process_frame
		_tap(controls.skill_reward_open_rect.get_center())
		_tap(controls.skill_reward_cancel_rect.get_center())
		if not _check(controls.all_stage_route_options == offers and runner.available_routes() == offers and runner.region_order == order and store.load_checkpoint() == before, "스킬 보상 열기/취소는 후보 재추첨·저장 없음"): return false
		if controls.relic_offer_available:
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_cancel_rect.get_center())
			if not _check(controls.all_stage_route_options == offers and store.load_checkpoint() == before, "유물 보상 취소도 같은 두 후보"): return false
	return true

func _test_preview(weapon: String) -> bool:
	controls.begin_retry(weapon, 3)
	var before := runner.checkpoint_snapshot()
	var journal := FileAccess.get_file_as_string(legacy.save_path)
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls.show_main_screen()
		controls.show_start_weapon_selection()
		var safe: Rect2 = controls.layout_snapshot().safe
		var rects: Array = controls.start_length_rects.duplicate()
		rects.append_array(controls.start_weapon_card_rects)
		rects.append_array(controls.memory_card_rects)
		rects.append_array([controls.boss_legacy_toggle_rect, controls.start_weapon_confirm_rect, controls.start_weapon_cancel_rect])
		if not _check(controls.start_length_rects.size() == 3, "기존3/5·새 순회 세 선택지"): return false
		for index in 3:
			var label: String = ["3스테이지 · 약 9분", "5스테이지 · 약 15분", "지역 순회 · 5단계"][index]
			if not _check(ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x <= controls.start_length_rects[index].size.x - 16, "실제18px 글꼴 길이 버튼 너비"): return false
		for i in rects.size():
			if not _check(safe.encloses(rects[i]), "순회 준비 입력 안전 영역"): return false
			for j in range(i + 1, rects.size()):
				if not _check(not rects[i].intersects(rects[j]), "준비 길이·무기·기억·하단 버튼 비중첩"): return false
		_tap(controls.start_length_rects[2].get_center())
		if not _check(controls.selected_run_mode == "regions" and runner.checkpoint_snapshot() == before and FileAccess.get_file_as_string(legacy.save_path) == journal, "순회 미리 선택은 실제 런/일회 보상 무변경"): return false
		controls.notification(Control.NOTIFICATION_APPLICATION_PAUSED)
		controls.notification(Control.NOTIFICATION_APPLICATION_RESUMED)
		_tap(controls.start_weapon_cancel_rect.get_center())
		if not _check(controls.selected_run_mode == "standard" and controls.selected_stage_limit == 3 and runner.checkpoint_snapshot() == before, "앱 복귀·취소는 이전 길이/모드 복원"): return false
	for args in [["sword", 3, "regions"], ["bow", 0, "regions"], ["sword", 5, "invalid"]]:
		if not _check(not controls.begin_retry(args[0], args[1], args[2]) and runner.checkpoint_snapshot() == before, "지원하지 않는 모드/길이 원자적 거부"): return false
	return true

func _test_orders() -> bool:
	var found: Dictionary = {}
	runner.stage_limit = 5
	if not _check(runner.set_run_mode("regions"), "순회 모드 설정"): return false
	for seed in 96:
		runner.region_rng.seed = seed
		runner.reset_run()
		var order := runner.region_order.duplicate()
		found[str(order)] = true
		if not _check(order.size() == 4 and order.all(func(id: String) -> bool: return id in runner.REGION_IDS and order.count(id) == 1), "셔플은 네 지역 중복/누락 없음"): return false
		for ignored in 4: runner.available_routes()
		if not _check(runner.region_order == order, "후보 조회는 RNG/순서 무변경"): return false
	if not _check(found.size() >= 20, "96개 시드의 다양한 지역 우선순위"): return false
	runner.stage_limit = 3
	return _check(not runner.set_run_mode("regions") and not runner.set_run_mode("invalid"), "순회는5단계만 지원")

func _test_invalid_states() -> bool:
	var saved := store.load_checkpoint()
	var invalid: Array[Dictionary] = []
	for order in [null, "wind", ["wind"], ["wind", "wind", "ruins", "festival"], ["wind", "forest", "ruins", "unknown"]]:
		var bad := saved.duplicate(true)
		bad.stage.region_order = order
		invalid.append(bad)
	for mode in [null, "standard", "invalid", true]:
		var bad := saved.duplicate(true)
		bad.stage.run_mode = mode
		invalid.append(bad)
	var bad := saved.duplicate(true)
	bad.stage.erase("run_mode")
	invalid.append(bad)
	bad = saved.duplicate(true)
	bad.stage.erase("region_order")
	invalid.append(bad)
	bad = saved.duplicate(true)
	bad.stage.history[0].route = "wind"
	invalid.append(bad)
	bad = saved.duplicate(true)
	bad.stage.history[2].route = bad.stage.history[1].route
	bad.stage.route = bad.stage.history[2].route
	invalid.append(bad)
	bad = saved.duplicate(true)
	bad.stage.history[1].route = bad.stage.region_order[3]
	invalid.append(bad)
	for state in invalid:
		if not _check(store.save_checkpoint(state) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "모드/순열/이력/미제시 후보 변조 원자적 거부"): return false
	return true
