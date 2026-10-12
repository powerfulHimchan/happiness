extends "res://tests/gp122_runtime_test.gd"

var forest_terrain: PrototypeRouteTerrain
var forest_ultimate: UltimateController

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var weapon := args[1] if args.size() > 1 else "sword"
	var prefix := "user://gp236_%s_%s" % ["fault" if phase.begins_with("fault") else "flow", weapon]
	store.save_path = prefix + "_checkpoint.json"
	legacy.save_path = prefix + "_meta.jsonl"
	if phase in ["seed", "legacy-seed", "fault-seed"]:
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
	forest_terrain = sandbox.get_node("RouteTerrain")
	forest_ultimate = sandbox.get_node("Player/UltimateController")
	for actor in [player, weapons, weapons.sword_combat, weapons.bow_combat, forest_ultimate, runner]:
		actor.set_process(false)
		actor.set_physics_process(false)
	growth.jobs_enabled = false
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	match phase:
		"seed", "fault-seed":
			if not await _test_forest_atlas(false): return
			controls.begin_retry(weapon, 5)
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "첫 정예 기존 보상 유지"): return
			if not await _select_forest(): return
			if not _test_forest_waves(): return
			if phase == "fault-seed": legacy.fail_writes = true
			if not _complete_forest_elite(): return
			var saved := store.load_checkpoint()
			var corrupt := saved.duplicate(true)
			corrupt.stage.history[0].route = "forest"
			if not _check(store.save_checkpoint(corrupt) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "첫 스테이지 숲 변조는 원자적 거부"): return
			if not _check(sandbox._claim_weapon_reward(""), "숲 실제 보상 확정·저장"): return
			if phase == "fault-seed":
				if not _check(not controls.surveyed_routes.has("forest") and not controls.route_atlas_message.is_empty(), "답사 쓰기 실패·체크포인트 독립 유지"): return
				legacy.fail_writes = false
				controls.show_main_screen()
				controls.show_village()
				controls.village_page = "atlas"
				_tap(controls.village_snapshot().pager.next.get_center())
				_tap(controls.village_snapshot().layout.cards[0].get_center())
				if not _check(controls.surveyed_routes.has("forest") and controls.route_atlas_message.is_empty(), "둘째 페이지 숲 카드 터치로 답사 재저장"): return
			if not await _test_forest_atlas(true): return
		"resume", "fault-resume":
			for ignored in 2:
				controls.show_main_screen()
				var before := store.load_checkpoint()
				if not _check(sandbox.continue_saved_run() and runner.route_id == "forest" and runner.stage_number == 2 and forest_terrain.get_child_count() == 4 and forest_terrain.motion_elapsed_s == 0.0 and player.damage_receiver.health == before.player.health and forest_ultimate.gauge == before.ultimate.gauge and controls.surveyed_routes.has("forest"), "숲 별도 반복 복원·보너스 중복 없음·발판4개 재생성"): return
			if phase == "resume":
				if not await _select_forest() or not _test_forest_waves() or not _complete_forest_elite(): return
				if not _check(sandbox._claim_weapon_reward(""), "셋째 숲 보상 저장"): return
			else:
				var journal := FileAccess.get_file_as_string(legacy.save_path)
				if not await _test_forest_atlas(true): return
				if not _check(journal == FileAccess.get_file_as_string(legacy.save_path), "복원·도감은 답사 중복 기록 없음"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and runner.stage_number == 3 and runner.route_id == "forest", "셋째 숲 체크포인트 재시작"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _check(runner.route_id == "wind" and forest_terrain.platforms == PrototypeRouteTerrain.WIND_STEPS and not runner.leaf_slime.forest_variant and not runner.seed_sack.forest_variant and not runner.wind_spirit.forest_variant, "기존 경로는 기본 지형·적 패턴으로 복귀"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "넷째 기존 경로 보상"): return
			if not await _select_forest() or not _reach_elite(): return
			_defeat(runner.final_enemy())
			if not _resolve_growth(): return
			player.damage_receiver.health = 35
			forest_ultimate.gauge = 10
			runner._process(0.1)
			if not _check(runner.awaiting_boss_choice() and player.damage_receiver.health == 35 and forest_ultimate.gauge == 10, "최종 보스는 정예 통과 보너스 제외·선택 대기 저장"): return
			if not _check(sandbox._resolve_boss_choice("rescue") and store.load_checkpoint().is_empty() and runner.stage_history.size() == 5 and recorder.summary_snapshot().completed_run_count == 1, "숲/기존 혼합5단계 보스 선택·완주·저장 정리"): return
			controls.begin_retry()
			if not _check(forest_terrain.platforms.is_empty() and not runner.leaf_slime.forest_variant and forest_terrain.motion_elapsed_s == 0.0 and controls.surveyed_routes.has("forest"), "새 도전 지형/패턴 초기화·영구 답사 유지"): return
		"legacy-seed":
			controls.begin_retry(weapon, 3)
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 저장 첫 단계"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 바람 저장 유지"): return
			if not _check(RunCheckpointStore.VERSION == 1 and not store.load_checkpoint().has("forest"), "기존 저장 버전/필드 유지"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and runner.route_id == "wind" and runner.stage_limit == 3 and forest_terrain.get_child_count() == 3 and not runner.wind_spirit.forest_variant, "이전 바람 저장 복원·적/지형 기본 유지"): return
			if not await _select_forest() or not _finish_stage(): return
			if not _check(sandbox._resolve_boss_choice("destroy") and store.load_checkpoint().is_empty() and controls.surveyed_routes.has("forest"), "이전 저장에서 새 숲 진입·3단계 완주"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-227–236 runtime test: OK (%s %s)" % [phase, weapon])
	quit(0)

func _select_forest() -> bool:
	var before := store.load_checkpoint()
	var metadata := legacy.progress_snapshot()
	var gauge := forest_ultimate.gauge
	var actual: Array[Dictionary] = controls.stage_route_options.duplicate(true)
	var four: Array[Dictionary] = PrototypeStageRunner.ROUTES.duplicate(true)
	four.append(PrototypeStageRunner.RISK_ROUTE)
	four.append(PrototypeStageRunner.FOREST_ROUTE)
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_layout()
		for offers in [actual, four]:
			var typed: Array[Dictionary] = offers
			controls.show_stage_routes(runner.stage_number, runner.stage_limit, 0, typed)
			var safe: Rect2 = controls.layout_snapshot().safe
			var rects: Array = controls.stage_route_rects.duplicate()
			rects.append(controls.skill_reward_open_rect)
			if controls.relic_offer_available: rects.append(controls.relic_reward_open_rect)
			for i in rects.size():
				if not _check(safe.encloses(rects[i]), "3/4경로·16:9/20:9 입력 안전 영역"): return false
				for j in range(i + 1, rects.size()):
					if not _check(not rects[i].intersects(rects[j]), "경로/보상 입력 비중첩"): return false
			for i in typed.size():
				var texts: Array = [typed[i].name]
				texts.append_array(typed[i].lines)
				for j in texts.size():
					var width: float = controls.stage_route_rects[i].size.x - 24.0
					var font := 28 if j == 0 else 18
					while font > 10 and ThemeDB.fallback_font.get_string_size(texts[j], HORIZONTAL_ALIGNMENT_LEFT, -1, font).x > width: font -= 1
					if not _check(ThemeDB.fallback_font.get_string_size(texts[j], HORIZONTAL_ALIGNMENT_LEFT, -1, font).x <= width, "실제 제목/효과 축소 글꼴 너비"): return false
			controls.queue_redraw()
			await process_frame
	controls.show_stage_routes(runner.stage_number, runner.stage_limit, 0, actual)
	if not _check(before == store.load_checkpoint() and metadata == legacy.progress_snapshot() and forest_ultimate.gauge == gauge, "후보 표시·그리기는 조회 전용"): return false
	for index in controls.stage_route_options.size():
		if controls.stage_route_options[index].id == "forest":
			_tap(controls.stage_route_rects[index].get_center())
			return _check(runner.route_id == "forest" and forest_terrain.get_child_count() == 4 and controls.movement_metrics.run_route_name == "거꾸로 자란 숲" and forest_ultimate.gauge == gauge and runner.leaf_slime.forest_variant, "실제 숲 카드·HUD·지형·패턴 연결·입장 보너스 없음")
	return _check(false, "숲 경로 후보 누락")

func _test_forest_waves() -> bool:
	player.global_position.x = 1240
	runner._process(0.1)
	if not _check(runner._active_enemies == [runner.leaf_slime, runner.seed_sack] and runner.seed_sack.position == Vector2(1980, 650) and runner.leaf_slime.forest_variant and runner.seed_sack.forest_variant, "숲 첫 웨이브 높은 식물·지상 연속 도약"): return false
	for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
	if not _resolve_growth(): return false
	runner._process(0.1)
	if not _check(runner.current_metrics().stage_objective.contains("고정 쉼터"), "수직 전진 목표 안내"): return false
	player.global_position.x = 3840
	runner._process(0.1)
	return _check(runner._active_enemies.size() == 3 and runner.seed_sack.position == Vector2(4470, 650) and runner.wind_spirit.position == Vector2(4250, 480) and runner.wind_spirit.forest_variant, "후반 공중/식물/지상 세 높이 웨이브")

func _complete_forest_elite() -> bool:
	if not _reach_elite(): return false
	_defeat(runner.final_enemy())
	if not _resolve_growth(): return false
	player.damage_receiver.health = maxi(1, player.damage_receiver.max_health - 40)
	var health := player.damage_receiver.health
	forest_ultimate.gauge = 10
	runner._process(0.1)
	var expected := mini(player.damage_receiver.max_health, health + ceili(player.damage_receiver.max_health * 0.20) + 10)
	if not _check(player.damage_receiver.health == expected and forest_ultimate.gauge == 25 and store.load_checkpoint().ultimate.gauge == 25 and store.load_checkpoint().stage.route == "forest", "정예 통과20%+10 회복·게이지+15·함께 저장"): return false
	for ignored in 3: sandbox._on_growth_stage_metrics(runner.current_metrics())
	return _check(player.damage_receiver.health == expected and forest_ultimate.gauge == 25, "중복 완료 신호는 숲 보너스 한 번만")

func _test_forest_atlas(surveyed: bool) -> bool:
	var before := store.load_checkpoint()
	var journal := legacy.progress_snapshot()
	controls.show_main_screen()
	controls.show_village()
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls.village_page = "atlas"
		controls.route_atlas_page = 0
		var first: Dictionary = controls.village_snapshot()
		if not _check(first.cards.size() == 3 and first.cards[2].id == "clockwork" and first.route_pages == 2, "기존 세 경로 첫 페이지 유지"): return false
		_tap(first.pager.next.get_center())
		var second: Dictionary = controls.village_snapshot()
		if not _check(second.cards.size() == 1 and second.cards[0].id == "forest" and second.cards[0].status.contains("완료") == surveyed and second.cards[0].lines[2].contains("15"), "둘째 페이지 숲 효과·실제 통과 답사 상태"): return false
		var rects: Array = second.layout.cards.duplicate()
		rects.append_array(second.pager.values())
		rects.append_array([second.layout.back, second.layout.start])
		if controls.checkpoint_available: rects.append(second.layout["continue"])
		var safe: Rect2 = controls.layout_snapshot().safe
		for i in rects.size():
			if not _check(safe.encloses(rects[i]), "숲 도감 모든 입력 안전 영역"): return false
			for j in range(i + 1, rects.size()):
				if not _check(not rects[i].intersects(rects[j]), "숲 도감 카드/페이지/하단 입력 비중첩"): return false
		_tap(second.pager.next.get_center())
		if not _check(controls.route_atlas_page == 1, "도감 마지막 경계"): return false
		controls.queue_redraw()
		await process_frame
	return _check(before == store.load_checkpoint() and journal == legacy.progress_snapshot(), "도감 조회/페이지는 저장·보너스·답사 무변경")
