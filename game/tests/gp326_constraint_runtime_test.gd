extends "res://tests/gp326_runtime_test.gd"

# Exercise the real controllers and touch signals, independently of resource availability.
func _run() -> void:
	var journal_store := StoryJournalStore.new()
	journal_store.save_path = "user://gp326_rules_story.jsonl"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(journal_store.save_path))
	journal_store.record_ending("rules-four", ArrivalEnding.ID, "roan", "rescue")
	journal_store.record_expedition_clear("rules-four", 4)
	sandbox = SANDBOX.instantiate()
	sandbox.story_journal_store = journal_store
	sandbox.checkpoint_store.save_path = "user://gp326_rules_checkpoint.json"
	sandbox.get_node("LocalTestRecorder").record_path = "user://gp326_rules_records.jsonl"
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	runner = sandbox.get_node("StageRunner")
	growth = sandbox.get_node("PrototypeGrowthController")
	festival_ultimate = sandbox.get_node("Player/UltimateController")
	if not controls.begin_retry("sword", 10, "journey", "roan", false, 5): return
	growth.jobs_enabled = false
	for node in [player, runner, festival_ultimate, sandbox.get_node("ClockTrapController")]:
		node.set_process(false)
		node.set_physics_process(false)
	for stage in range(1, 11):
		runner.stage_number = stage
		runner.route_id = "wind" if stage <= 8 else JourneyRoutePlan.GATE if stage == 9 else JourneyRoutePlan.CORE
		runner.reset_stage()
		var expected := "recovery_potion" if stage in [2, 6] else "ultimate" if stage in [4, 8] else ""
		if not _check(runner.stage_constraint() == expected and runner.active_constraint().is_empty(), "일정·사전 예고"): return
		if not expected.is_empty() and not _check(runner.current_metrics().stage_constraint_hint.contains("예고"), "시작 전 예고"): return
		# An ultimate activated before the wave is allowed to finish normally.
		festival_ultimate.reset_ultimate()
		festival_ultimate.gauge = 100
		festival_ultimate.request_ultimate()
		if not _check(festival_ultimate._active, "봉인 전 필살기 발동"): return
		runner.current_section = PrototypeStageRunner.Section.WAVE_TWO
		runner._emit_metrics()
		if not _check(runner.active_constraint() == expected and festival_ultimate._active, "웨이브 진입은 사용 중 필살기 유지"): return
		festival_ultimate._physics_process(10.0)
		if not _check(not festival_ultimate._active, "기존 필살기 자연 종료"): return
		festival_ultimate._add_gauge(100, "constraint probe")
		player.damage_receiver.health = 10
		player.prepare_potions(PrototypePotionRecipes.BASIC)
		var stock: int = player.potions_remaining
		var barrier: int = player.damage_receiver.barrier_health
		var activations: int = festival_ultimate.activation_count
		if expected == "recovery_potion":
			if not _check(not player.use_recovery_potion() and not sandbox._use_recovery_potion(), "직접·모바일 경로 회복약 봉인"): return
			_tap(controls.action_rects[&"recovery_potion"].get_center())
			if not _check(player.potions_remaining == stock and player.damage_receiver.health == 10 and player.damage_receiver.barrier_health == barrier and controls._action_label(&"recovery_potion") == "회복 봉인", "잔량·체력·방벽 불변 및 버튼 안내"): return
			player.apply_growth_health(0, 40)
			if not _check(player.damage_receiver.health == 40, "다른 체력 회복은 75% 유지"): return
		elif expected == "ultimate":
			festival_ultimate.request_ultimate()
			_tap(controls.action_rects[&"ultimate"].get_center())
			if not _check(not festival_ultimate._active and festival_ultimate.gauge == 100 and festival_ultimate.activation_count == activations and controls._action_label(&"ultimate") == "새벽 봉인", "직접·터치 필살기 차단 및 게이지 보존"): return
			festival_ultimate.gauge = 0
			festival_ultimate._add_gauge(12, "constraint probe")
			if not _check(festival_ultimate.gauge == 12, "봉인 중 게이지 획득 유지"): return
			festival_ultimate.gauge = 100
		if not expected.is_empty():
			if not _check(controls.open_run_build() and paused and runner.active_constraint() == expected, "상세 조회 일시정지는 봉인 해제하지 않음"): return
			var cards := PrototypeRunBuildView.cards(2, controls.run_build_state)
			if not _check(cards.any(func(card): return card.id == "stage_constraints"), "별도 제약 설명 카드"): return
			controls.close_run_build()
			controls.advance_mode_timer_for_test(3.1)
			runner._finish_current_section()
			if not _check(runner.active_constraint().is_empty() and not controls._action_stage_blocked(StringName(expected)) and runner.current_metrics().stage_constraint_hint.contains("해제"), "웨이브 종료 즉시 상태·HUD 해제"): return
			if expected == "recovery_potion":
				if not _check(sandbox._use_recovery_potion() and player.potions_remaining == stock - 1, "해제 후 보존 회복약 사용"): return
			else:
				festival_ultimate.request_ultimate()
				if not _check(festival_ultimate._active and festival_ultimate.gauge == 0, "해제 후 보존 게이지 사용"): return
		# Reset/failure/mode transitions never retain a stored lock.
		festival_ultimate.reset_ultimate()
		runner.current_section = PrototypeStageRunner.Section.WAVE_TWO
		runner.failed = true
		if not _check(runner.active_constraint().is_empty(), "사망 후 봉인 없음"): return
		runner.failed = false
		runner.reset_stage()
		if not _check(runner.active_constraint().is_empty(), "재시작은 예고 상태"): return
	for level in range(5):
		runner.expedition = level
		runner.stage_number = 2
		runner.current_section = PrototypeStageRunner.Section.WAVE_TWO
		if not _check(runner.stage_constraint().is_empty(), "이전 원정에 비소급"): return
	runner.expedition = 5
	for mode in ["standard", "regions"]:
		runner.run_mode = mode
		if not _check(runner.active_constraint().is_empty(), "다른 모드 제약 없음"): return
	paused = false
	sandbox.free()
	print("GP-326 constraint runtime test: OK (10 stages, touch/direct gates, resources, release/reset)")
	quit(0)
