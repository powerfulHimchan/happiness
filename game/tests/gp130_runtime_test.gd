extends "res://tests/gp129_runtime_test.gd"

const GP130_SAVE := "user://gp130_checkpoint.json"
const GP130_META := "user://gp130_meta.jsonl"
const GP130_RECORD := "user://gp130_records.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP130_SAVE
	legacy.save_path = GP130_META
	if phase == "seed":
		store.clear_checkpoint()
		for path in [GP130_META, GP130_RECORD]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP130_RECORD
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	recorder = sandbox.get_node("LocalTestRecorder")
	ultimate = sandbox.get_node("Player/UltimateController")
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	weapons.sword_combat.set_physics_process(false)
	weapons.bow_combat.set_physics_process(false)
	weapons.sword_combat.set_process(false)
	weapons.bow_combat.set_process(false)
	player.set_physics_process(false)
	runner.set_process(false)
	match phase:
		"seed":
			if not await _test_village_codex("", false): return
			if not _check(store.load_checkpoint().is_empty() and not FileAccess.file_exists(GP130_SAVE), "첫 도감 방문은 저장 생성 없음"): return
			controls.begin_retry()
			if not _reach_relic_reward(): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[1].get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(player.relic_state.id == PrototypeRelic.CLOCK_ID, "실제 정예 보상 시계추 선택"): return
			if not await _test_village_codex(PrototypeRelic.CLOCK_ID, false): return
		"resume":
			if not _check(player.relic_state.is_empty() and player.skill_recharge_multiplier() == 1, "재시작 첫 화면에는 저장 유물 자동 지급 없음"): return
			if not await _test_village_codex("", false): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			if not _check(controls.current_screen_mode() == 9 and player.relic_state.id == PrototypeRelic.CLOCK_ID and player.skill_recharge_multiplier() == 1.25, "도감의 실제 이어하기 버튼은 저장 유물·효과 복원"): return
			if not await _test_village_codex(PrototypeRelic.CLOCK_ID, false): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			if not _check(player.skill_recharge_multiplier() == 1.25 and not player.relic_state.used, "도감 조회·반복 이어하기는 유물 효과 중첩·소비 없음"): return
		"finish":
			if not _check(sandbox.continue_saved_run(), "시계추 보스 완주 복원"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("rescue"), "도감 추가 후 실제 보스 완주"): return
			if not await _test_village_codex("", false): return
			controls.begin_retry()
			if not _check(player.relic_state.is_empty() and player.skill_recharge_multiplier() == 1, "새 도전 유물 초기화"): return
			if not _reach_relic_reward(): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not await _test_village_codex(PrototypeRelic.PHOENIX_ID, false): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			_tap(controls.stage_route_rects[0].get_center())
			player.damage_receiver.tick(2)
			_hit_player(9999, "codex-phoenix")
			if not _check(not player.damage_receiver.dead and player.relic_state.used and legacy.phoenix_used(player.relic_run_id), "실제 치명타 부활·깃털 소비 유지"): return
			if not await _test_village_codex(PrototypeRelic.PHOENIX_ID, true): return
			controls.begin_retry()
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			var old := store.load_checkpoint()
			old.erase("relic")
			if not _check(store.save_checkpoint(old) == OK, "유물 필드 없는 이전 저장 준비"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and player.relic_state.is_empty(), "이전 저장 이어하기 호환"): return
			if not await _test_village_codex("", false): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("destroy"), "유물 없는 기존 저장 실제 완주"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-130 runtime test: OK (" + phase + ")")
	quit(0)

func _test_village_codex(expected_id: String, used: bool) -> bool:
	var saved := store.load_checkpoint()
	var weapon_state := weapons.checkpoint_snapshot()
	var growth_state := growth.checkpoint_snapshot()
	var relic := player.relic_state.duplicate()
	var metadata := legacy.progress_snapshot()
	var health := player.damage_receiver.health
	var potions := player.potions_remaining
	var gauge := ultimate.gauge
	var multiplier := player.skill_recharge_multiplier()
	controls.show_main_screen()
	controls.show_village()
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_layout()
		controls.village_page = "village"
		_tap(controls.village_snapshot().layout.cards[1].get_center())
		if not _check(controls.village_page == "memories", "기존 두 번째 시설 기억의 쉼터 진입"): return false
		_tap(controls.village_snapshot().tabs.relics.get_center())
		if not _check(controls.village_page == "relics", "실제 유물 도감 탭 터치"): return false
		var snapshot: Dictionary = controls.village_snapshot()
		if not _check(snapshot.cards.size() == 2, "불사조·시계추 두 카드 표시"): return false
		var rects: Array = snapshot.layout.cards.duplicate()
		rects.append_array(snapshot.tabs.values())
		rects.append_array([snapshot.layout.back, snapshot.layout.start])
		if controls.checkpoint_available: rects.append(snapshot.layout["continue"])
		var safe: Rect2 = controls.layout_snapshot().safe
		for i in rects.size():
			if not _check(safe.encloses(rects[i]), "두 화면비 카드·탭·이동 버튼 안전 영역"): return false
			for j in range(i + 1, rects.size()):
				if not _check(not rects[i].intersects(rects[j]), "전체 입력 영역 비중첩"): return false
		for i in snapshot.cards.size():
			var card: Dictionary = snapshot.cards[i]
			var source: Dictionary = PrototypeRelic.OFFERS[i]
			var owned: bool = String(card.id) == expected_id
			var expected_status := "이번 도전 · 사용 완료" if owned and used else "이번 도전 · 보유 중" if owned else "미보유 · 효과 미리 보기"
			if not _check(card.id == source.id and card.name == source.name and card.lines.slice(0, 3) == source.lines and card.lines.size() == 5 and card.lines[3].contains("두 번째 정예") and card.open == owned and card.status == expected_status, "실제 보상 원본 효과·조건·미보유/보유/사용 완료 표시"): return false
			_tap(snapshot.layout.cards[i].get_center())
		controls.queue_redraw()
		await process_frame
		_tap(snapshot.tabs.memories.get_center())
		if not _check(controls.village_page == "memories" and controls.village_snapshot().cards.size() == 2, "영구 기억 탭 기존 두 기억 유지"): return false
		controls.queue_redraw()
		await process_frame
		_tap(controls.village_snapshot().layout.back.get_center())
		if not _check(controls.village_page == "village", "쉼터 뒤로는 기존 마을 복귀"): return false
		_tap(controls.village_snapshot().layout.cards[1].get_center())
		_tap(controls.village_snapshot().tabs.relics.get_center())
	return _check(store.load_checkpoint() == saved and weapons.checkpoint_snapshot() == weapon_state and growth.checkpoint_snapshot() == growth_state and player.relic_state == relic and legacy.progress_snapshot() == metadata and player.damage_receiver.health == health and player.potions_remaining == potions and ultimate.gauge == gauge and player.skill_recharge_multiplier() == multiplier, "도감 방문·조회·카드 터치·탭·복귀는 저장/보상/성장/대기시간/체력/회복약/필살기/유물 변경 없음")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-130 failed: " + message)
		paused = false
		quit(1)
	return condition
