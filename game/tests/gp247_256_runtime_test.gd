extends "res://tests/gp122_runtime_test.gd"

var festival_terrain: PrototypeRouteTerrain
var festival_ultimate: UltimateController
var traps: ClockTrapController

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var weapon := args[1] if args.size() > 1 else "sword"
	var prefix := "user://gp256_%s_%s" % ["fault" if phase.begins_with("fault") else "paging" if phase == "paging" else "flow", weapon]
	store.save_path = prefix + "_checkpoint.json"
	legacy.save_path = prefix + "_meta.jsonl"
	if phase in ["seed", "legacy-seed", "fault-seed", "paging"]:
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
	traps.set_process(false)
	for actor in [player, weapons, weapons.sword_combat, weapons.bow_combat, festival_ultimate, runner]:
		actor.set_process(false)
		actor.set_physics_process(false)
	growth.jobs_enabled = false
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	match phase:
		"paging":
			if not _check(legacy.grant("gp256-paging", "destroy") == OK, "실제 파괴 핵 보상 준비"): return
			sandbox._update_boss_legacy_status()
			controls.show_main_screen()
			controls.show_start_weapon_selection()
			controls.selected_starting_weapon = weapon
			controls.selected_stage_limit = 5
			_tap(controls.start_weapon_confirm_rect.get_center())
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "실제 여섯 후보 도전 준비"): return
			if not _check(player.boss_legacy.choice == "destroy" and controls.all_stage_route_options.size() == 6, "위험 권한 실제 여섯 경로"): return
			var before := store.load_checkpoint()
			_tap(controls.stage_route_next_rect.get_center())
			if not _check(controls.stage_route_page == 1 and controls.stage_route_options.size() == 2 and controls.stage_route_options[1].id == "festival", "실제 페이지 터치·유적·축제 두 카드"): return
			_tap(controls.skill_reward_open_rect.get_center())
			_tap(controls.skill_reward_cancel_rect.get_center())
			if not _check(controls.all_stage_route_options.size() == 6 and store.load_checkpoint() == before, "스킬 보상 취소는 숨은 경로·저장 유지"): return
			if controls.relic_offer_available:
				_tap(controls.relic_reward_open_rect.get_center())
				_tap(controls.relic_reward_cancel_rect.get_center())
				if not _check(controls.all_stage_route_options.size() == 6 and store.load_checkpoint() == before, "유물 보상 취소도 전체 경로 유지"): return
			if not await _select_festival() or not _finish_stage(): return
			if not _check(runner.route_id == "festival" and controls.surveyed_routes.has("festival"), "여섯 후보 둘째 페이지 선택·실제 축제 통과"): return
		"seed", "fault-seed":
			if not await _test_festival_atlas(false): return
			controls.begin_retry(weapon, 5)
			if not _earn_barrier(): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "첫 정예 기존 보상 유지"): return
			if not await _select_festival(): return
			if not _test_festival_waves(): return
			if phase == "fault-seed": legacy.fail_writes = true
			if not _complete_festival_elite(): return
			var saved := store.load_checkpoint()
			var corrupt := saved.duplicate(true)
			corrupt.stage.history[0].route = "festival"
			if not _check(store.save_checkpoint(corrupt) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "첫 스테이지 축제 변조는 원자적 거부"): return
			if not _check(sandbox._claim_weapon_reward(""), "축제 실제 보상 확정·저장"): return
			if phase == "fault-seed":
				if not _check(not controls.surveyed_routes.has("festival") and not controls.route_atlas_message.is_empty(), "답사 쓰기 실패·체크포인트 독립 유지"): return
				legacy.fail_writes = false
				controls.show_main_screen()
				controls.show_village()
				controls.village_page = "atlas"
				_tap(controls.village_snapshot().pager.next.get_center())
				_tap(controls.village_snapshot().layout.cards[2].get_center())
				if not _check(controls.surveyed_routes.has("festival") and controls.route_atlas_message.is_empty(), "둘째 페이지 축제 카드 터치로 답사 재저장"): return
			if not await _test_festival_atlas(true): return
		"resume", "fault-resume":
			for ignored in 2:
				controls.show_main_screen()
				var before := store.load_checkpoint()
				if not _check(sandbox.continue_saved_run() and runner.route_id == "festival" and runner.stage_number == 2 and festival_terrain.get_child_count() == 4 and festival_terrain.motion_elapsed_s == 0.0 and traps.state == ClockTrapController.State.OFF and player.damage_receiver.health == before.player.health and festival_ultimate.gauge == before.ultimate.gauge and controls.surveyed_routes.has("festival"), "축제 별도 반복 복원·보너스 중복 없음·발판4개 재생성"): return
			if phase == "resume":
				if not await _select_festival() or not _test_festival_waves() or not _complete_festival_elite(): return
				if not _check(sandbox._claim_weapon_reward(""), "셋째 축제 보상 저장"): return
			else:
				var journal := FileAccess.get_file_as_string(legacy.save_path)
				if not await _test_festival_atlas(true): return
				if not _check(journal == FileAccess.get_file_as_string(legacy.save_path), "복원·도감은 답사 중복 기록 없음"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and runner.stage_number == 3 and runner.route_id == "festival", "셋째 축제 체크포인트 재시작"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _check(runner.route_id == "wind" and festival_terrain.platforms == PrototypeRouteTerrain.WIND_STEPS and not runner.leaf_slime.festival_variant and not runner.seed_sack.festival_variant and not runner.wind_spirit.festival_variant, "기존 경로는 기본 지형·적 패턴으로 복귀"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "넷째 기존 경로 보상"): return
			if not await _select_festival() or not _reach_elite(): return
			_defeat(runner.final_enemy())
			if not _resolve_growth(): return
			player.damage_receiver.health = 35
			festival_ultimate.gauge = 10
			runner._process(0.1)
			if not _check(runner.awaiting_boss_choice() and player.damage_receiver.health == 35 and festival_ultimate.gauge == 10, "최종 보스는 정예 통과 보너스 제외·선택 대기 저장"): return
			if not _check(sandbox._resolve_boss_choice("rescue") and store.load_checkpoint().is_empty() and runner.stage_history.size() == 5 and recorder.summary_snapshot().completed_run_count == 1, "축제/기존 혼합5단계 보스 선택·완주·저장 정리"): return
			controls.begin_retry()
			if not _check(festival_terrain.platforms.is_empty() and not runner.seed_sack.festival_variant and festival_terrain.motion_elapsed_s == 0.0 and controls.surveyed_routes.has("festival"), "새 도전 지형/패턴 초기화·영구 답사 유지"): return
		"legacy-seed":
			controls.begin_retry(weapon, 3)
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 저장 첫 단계"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 바람 저장 유지"): return
			if not _check(RunCheckpointStore.VERSION == 1 and not store.load_checkpoint().has("festival"), "기존 저장 버전/필드 유지"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and runner.route_id == "wind" and runner.stage_limit == 3 and festival_terrain.get_child_count() == 3 and not runner.seed_sack.festival_variant, "이전 바람 저장 복원·적/지형 기본 유지"): return
			if not await _select_festival() or not _finish_stage(): return
			if not _check(sandbox._resolve_boss_choice("destroy") and store.load_checkpoint().is_empty() and controls.surveyed_routes.has("festival"), "이전 저장에서 새 축제 진입·3단계 완주"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-247–256 runtime test: OK (%s %s)" % [phase, weapon])
	quit(0)

func _select_festival() -> bool:
	var before := store.load_checkpoint()
	var metadata := legacy.progress_snapshot()
	var gauge := festival_ultimate.gauge
	var actual: Array[Dictionary] = runner.available_routes()
	var six: Array[Dictionary] = PrototypeStageRunner.ROUTES.duplicate(true)
	six.append(PrototypeStageRunner.RISK_ROUTE)
	six.append(PrototypeStageRunner.FOREST_ROUTE)
	six.append(PrototypeStageRunner.RUINS_ROUTE)
	six.append(PrototypeStageRunner.FESTIVAL_ROUTE)
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_layout()
		for offers in [actual, six]:
			var typed: Array[Dictionary] = offers
			controls.show_stage_routes(runner.stage_number, runner.stage_limit, 0, typed)
			if not _check(controls.stage_route_options.size() == 4 and controls.stage_route_pages() == (2 if typed.size() > 4 else 1), "네 카드 상한·기존 경로 순서·위험 권한 여섯 후보 페이지"): return false
			for page in controls.stage_route_pages():
				controls._change_stage_route_page(page)
				var safe: Rect2 = controls.layout_snapshot().safe
				var rects: Array = controls.stage_route_rects.duplicate()
				rects.append(controls.skill_reward_open_rect)
				if controls.relic_offer_available: rects.append(controls.relic_reward_open_rect)
				if controls.stage_route_pages() > 1: rects.append_array([controls.stage_route_previous_rect, controls.stage_route_next_rect])
				for i in rects.size():
					if not _check(safe.encloses(rects[i]), "경로·페이지·보상 입력 안전 영역"): return false
					for j in range(i + 1, rects.size()):
						if not _check(not rects[i].intersects(rects[j]), "경로·페이지·보상 비중첩"): return false
				for i in controls.stage_route_options.size():
					var texts: Array = [controls.stage_route_options[i].name]
					texts.append_array(controls.stage_route_options[i].lines)
					for j in texts.size():
						var width: float = controls.stage_route_rects[i].size.x - 24.0
						var font := 28 if j == 0 else 18
						while font > 10 and ThemeDB.fallback_font.get_string_size(texts[j], HORIZONTAL_ALIGNMENT_LEFT, -1, font).x > width: font -= 1
						if not _check(ThemeDB.fallback_font.get_string_size(texts[j], HORIZONTAL_ALIGNMENT_LEFT, -1, font).x <= width, "경로 설명 실제 축소 글꼴 너비"): return false
				controls.queue_redraw()
				await process_frame
			controls._change_stage_route_page(99)
			if not _check(controls.stage_route_page == controls.stage_route_pages() - 1, "마지막 경로 경계"): return false
			controls._change_stage_route_page(-99)
			if not _check(controls.stage_route_page == 0, "첫 경로 경계"): return false
	controls.show_stage_routes(runner.stage_number, runner.stage_limit, 0, actual)
	if not _check(before == store.load_checkpoint() and metadata == legacy.progress_snapshot() and festival_ultimate.gauge == gauge, "후보·페이지 조회는 저장/보너스 무변경"): return false
	for page in controls.stage_route_pages():
		controls._change_stage_route_page(page)
		for index in controls.stage_route_options.size():
			if controls.stage_route_options[index].id == "festival":
				_tap(controls.stage_route_rects[index].get_center())
				return _check(runner.route_id == "festival" and festival_terrain.get_child_count() == 4 and controls.movement_metrics.run_route_name == "태엽 축제장" and festival_ultimate.gauge == gauge and runner.seed_sack.festival_variant and traps.state == ClockTrapController.State.OFF, "실제 축제 카드·HUD·지형·병정/포탑 연결·입장 보너스 없음")
	return _check(false, "축제 경로 후보 누락")

func _test_festival_waves() -> bool:
	player.global_position.x = 1240
	runner._process(0.1)
	if not _check(runner._active_enemies == [runner.leaf_slime, runner.seed_sack] and runner.seed_sack.position == Vector2(2050, 780) and runner.leaf_slime.festival_variant and runner.seed_sack.festival_variant and traps.state == ClockTrapController.State.OFF, "축제 첫 웨이브 병정·고정 포탑·함정 없음"): return false
	for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
	if not _resolve_growth(): return false
	runner._process(0.1)
	if not _check(traps.state == ClockTrapController.State.OFF and runner.current_metrics().stage_objective.contains("기계 승강대"), "수직 전진 목표 안내"): return false
	player.global_position.x = 3840
	runner._process(0.1)
	return _check(runner._active_enemies.size() == 3 and runner.seed_sack.position == Vector2(4570, 780) and runner.wind_spirit.position == Vector2(4280, 560) and runner.seed_sack.festival_variant and traps.state == ClockTrapController.State.OFF, "후반 병정/포탑/공중 정령 웨이브")

func _complete_festival_elite() -> bool:
	if not _reach_elite(): return false
	_defeat(runner.final_enemy())
	if not _resolve_growth(): return false
	player.damage_receiver.health = maxi(1, player.damage_receiver.max_health - 40)
	var health := player.damage_receiver.health
	festival_ultimate.gauge = 10
	player.damage_receiver.barrier_health = 3 if player.barrier_unlocked else 0
	runner._process(0.1)
	var expected := mini(player.damage_receiver.max_health, health + ceili(player.damage_receiver.max_health * 0.20) + 15)
	if not _check(player.damage_receiver.health == expected and festival_ultimate.gauge == 20 and store.load_checkpoint().ultimate.gauge == 20 and store.load_checkpoint().stage.route == "festival" and player.damage_receiver.barrier_health == (3 if player.barrier_unlocked else 0) and store.load_checkpoint().player.barrier_health == player.damage_receiver.barrier_health, "정예 통과20%+15 회복·게이지+10·함께 저장"): return false
	for ignored in 3: sandbox._on_growth_stage_metrics(runner.current_metrics())
	return _check(player.damage_receiver.health == expected and festival_ultimate.gauge == 20 and player.damage_receiver.barrier_health == (3 if player.barrier_unlocked else 0), "중복 완료 신호는 축제 보너스 한 번만")

func _test_festival_atlas(surveyed: bool) -> bool:
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
		if not _check(second.cards.size() == 3 and second.cards[2].id == "festival" and second.cards[2].status.contains("완료") == surveyed and second.cards[2].lines[2].contains("10"), "둘째 페이지 축제 효과·실제 통과 답사 상태"): return false
		var rects: Array = second.layout.cards.duplicate()
		rects.append_array(second.pager.values())
		rects.append_array([second.layout.back, second.layout.start])
		if controls.checkpoint_available: rects.append(second.layout["continue"])
		var safe: Rect2 = controls.layout_snapshot().safe
		for i in rects.size():
			if not _check(safe.encloses(rects[i]), "축제 도감 모든 입력 안전 영역"): return false
			for j in range(i + 1, rects.size()):
				if not _check(not rects[i].intersects(rects[j]), "축제 도감 카드/페이지/하단 입력 비중첩"): return false
		_tap(second.pager.next.get_center())
		if not _check(controls.route_atlas_page == 1, "도감 마지막 경계"): return false
		controls.queue_redraw()
		await process_frame
	return _check(before == store.load_checkpoint() and journal == legacy.progress_snapshot(), "도감 조회/페이지는 저장·보너스·답사 무변경")

func _earn_barrier() -> bool:
	var chosen_seed := -1
	for candidate in 128:
		growth.rng.seed = candidate
		if growth._draw_cards().any(func(card: Dictionary) -> bool: return card.id == "magic_barrier"):
			chosen_seed = candidate
			break
	if not _check(chosen_seed >= 0, "방벽 자연 후보 RNG 재현"): return false
	growth.rng.seed = chosen_seed
	player.position.x = 1240
	runner._process(0.1)
	for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
	for index in growth.offered_cards.size():
		if growth.offered_cards[index].id == "magic_barrier":
			_tap(controls.growth_card_rects[index].get_center())
			return _check(player.barrier_unlocked and growth.ranks.magic_barrier == 1, "실제 처치·성장 선택으로 방벽 해금")
	return _check(false, "방벽 성장 후보 누락")
