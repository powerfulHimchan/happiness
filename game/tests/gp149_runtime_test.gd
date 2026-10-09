extends "res://tests/gp148_runtime_test.gd"

const GP149_SAVE := "user://gp149_checkpoint.json"
const GP149_META := "user://gp149_meta.jsonl"
const GP149_RECORD := "user://gp149_records.jsonl"
const GP149_BOOK := "user://gp149_abilities.jsonl"
const PORTIONED_ID := PrototypePotionRecipes.PORTIONED

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	store.save_path = GP149_SAVE
	legacy.save_path = GP149_META
	book.save_path = GP149_BOOK
	if phase in ["seed", "legacy-seed", "combat"]:
		store.clear_checkpoint()
		for path in [GP149_META, GP149_RECORD, GP149_BOOK]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.ability_discovery_store = book
	sandbox.get_node("LocalTestRecorder").record_path = GP149_RECORD
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
	_disable_live()
	growth.jobs_enabled = false
	match phase:
		"seed":
			if not await _test_recipe_layout(false, false): return
			var journal := _files()
			_tap(controls.village_snapshot().layout.cards[2].get_center())
			if not _check(not sandbox._select_potion_recipe(PORTIONED_ID) and not sandbox._select_potion_recipe("other") and _files() == journal and controls.preferred_potion_recipe == "basic", "잠긴/알 수 없는 조제 차단·방문은 저장 미변경"): return
			controls.begin_retry("sword", 3)
			if not _finish_to_boss() or not _check(sandbox._resolve_boss_choice("destroy"), "실제 3스테이지 보스 파괴 완주"): return
			if not _check(legacy.progress_snapshot().unlocked.has("core_echo") and not legacy.progress_snapshot().unlocked.has("clockwork_guard"), "파괴 기억만 영구 해금"): return
			if not await _test_recipe_layout(false, true): return
			journal = _files()
			legacy.fail_writes = true
			_tap(controls.village_snapshot().layout.cards[2].get_center())
			if not _check(controls.preferred_potion_recipe == "basic" and _files() == journal and controls.potion_recipe_message.contains("실패"), "소분 선택 저장 실패·기존 선택/저널 보존·재시도 안내"): return
			legacy.fail_writes = false
			_tap(controls.village_snapshot().layout.cards[2].get_center())
			if not _check(controls.preferred_potion_recipe == PORTIONED_ID and legacy.progress_snapshot().potion_recipe == PORTIONED_ID, "실제 세 번째 카드 선택·영구 조제 저장"): return
			journal = _files()
			_tap(controls.village_snapshot().layout.cards[2].get_center())
			if not _check(_files() == journal, "동일 조제 재선택은 중복 저널 없음"): return
			_tap(controls.village_snapshot().layout.start.get_center())
			_tap(controls.start_weapon_cancel_rect.get_center())
			if not _check(_files() == journal and controls.current_screen_mode() == 13, "준비 취소는 도전/조제 보존"): return
			_tap(controls.village_snapshot().layout.start.get_center())
			_tap(controls.start_length_rects[1].get_center())
			_tap(controls.start_weapon_card_rects[1].get_center())
			if controls.use_boss_legacy: _tap(controls.boss_legacy_toggle_rect.get_center())
			_tap(controls.start_weapon_confirm_rect.get_center())
			if not _check(player.potion_recipe == PORTIONED_ID and player.potions_remaining == 3 and player.potions_capacity() == 3 and runner.stage_limit == 5 and controls.movement_metrics.potion_heal_percent == 20 and controls._action_label(&"recovery_potion") == "회복 3/3", "실제 준비 확인·활/5단계·소분20%3개·HUD"): return
			if not await _choose_earned("magic_barrier") or not await _choose_earned(RESTORATIVE_ID) or not await _choose_earned("potion_pouch"): return
			if not _check(player.potions_remaining == 4 and player.potions_capacity() == 4, "실제 주머니 선택·소분3개에1개만 보충·최대4"): return
			player.damage_receiver.health = 1
			player.damage_receiver.barrier_health = 0
			_press_potion()
			if not _check(player.potions_remaining == 3 and player.damage_receiver.health == 1 + ceili(player.damage_receiver.max_health * 0.20) and player.damage_receiver.barrier_health == 10, "실제20%올림·1개소비·회복방벽10"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "실제 첫 정예 소분 저장"): return
			if not _test_portioned_save(): return
			var saved := store.load_checkpoint()
			if not await _test_recipe_layout(false, true): return
			_tap(controls.village_snapshot().layout.cards[0].get_center())
			if not _check(player.potion_recipe == PORTIONED_ID and player.potions_remaining == 3 and store.load_checkpoint() == saved and controls.preferred_potion_recipe == "basic", "다음 조제를 기본으로 바꿔도 진행 중 소분/잔량/저장 보존"): return
		"resume":
			if not _check(controls.preferred_potion_recipe == "basic" and player.potion_recipe == "basic", "재시작·다음 도전 기본 선택 복원"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and player.potion_recipe == PORTIONED_ID and player.potions_remaining == 3 and player.potions_capacity() == 4 and player.potion_barrier_recovery() == 10, "별도 프로세스 반복 이어하기·소분3/4·보충 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _check(player.potions_remaining == 3, "단계 이동은 소분 무료 보충 없음"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "두 번째 정예"): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[2].get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(player.relic_state.id == PrototypeRelic.DEW_ID and controls.movement_metrics.potion_heal_percent == 30 and player.potions_remaining == 3, "실제 샘의 이슬 선택·소분20→30%·개수 유지"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _test_portioned_view(): return
			var timers := weapons.checkpoint_snapshot()
			var gauge := ultimate.gauge
			for remaining in [2, 1, 0]:
				player.damage_receiver.health = 1
				player.damage_receiver.barrier_health = 0
				_press_potion(true)
				for ignored in 20: controls._physics_process(0.01)
				controls._handle_touch_released(7)
				if not _check(player.potions_remaining == remaining and player.damage_receiver.health == 1 + ceili(float(player.damage_receiver.max_health * 3) / 10.0) and player.damage_receiver.barrier_health == 10, "별도 터치당 소분30%1개·누르고 있어도 중복 소비 없음"): return
			if not _check(weapons.checkpoint_snapshot() == timers and ultimate.gauge == gauge, "소분은 스킬 대기/필살기 독립"): return
			if not _finish_to_boss() or not _check(store.load_checkpoint().player.potions_remaining == 0 and runner.stage_number == 5, "5단계 완주 대기·소진0개 저장"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and player.potion_recipe == PORTIONED_ID and player.potions_remaining == 0 and sandbox._resolve_boss_choice("rescue"), "소분0개·이슬·보스 선택 복원과 실제 구출 완주"): return
			if not await _test_recipe_layout(true, true): return
			_tap(controls.village_snapshot().layout.cards[2].get_center())
			recorder.clear_records()
			controls.begin_retry("sword", 3)
			if not _check(player.potion_recipe == PORTIONED_ID and player.potions_remaining == 3 and player.potions_capacity() == 3 and is_equal_approx(player.potion_heal_ratio(), 0.20) and not player.potion_pouch_unlocked and not player.restorative_barrier_unlocked and player.relic_state.is_empty(), "기록 초기화 후 해금/선택 유지·새 도전은소분20%3개·성장/유물 초기화"): return
		"legacy-seed":
			if not _check(legacy.grant("gp149-old-rescue", "rescue") == OK and legacy.select_potion_recipe("concentrated") == OK and not PrototypePotionRecipes.available(PORTIONED_ID, legacy.progress_snapshot().unlocked), "기존 구출 저장은 농축 해금·소분 자동 해금 없음"): return
			sandbox._update_boss_legacy_status()
			controls.begin_retry("sword", 3)
			player.damage_receiver.health = 1
			_press_potion()
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 농축 소진 저장"): return
			var saved := store.load_checkpoint()
			var bad := saved.duplicate(true)
			bad.player.potion_recipe = PORTIONED_ID
			bad.player.potions_remaining = 4
			if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "주머니 없는 소분4개 거부·이전 정상 저장 보호"): return
			if not _check(legacy.grant("gp149-old-destroy", "destroy") == OK and legacy.select_potion_recipe(PORTIONED_ID) == OK, "이전 파괴 영구 기억으로 추가 진행 없이 소분 선택"): return
		"legacy":
			if not _check(controls.preferred_potion_recipe == PORTIONED_ID and sandbox.continue_saved_run() and player.potion_recipe == "concentrated" and player.potions_remaining == 0 and player.potions_capacity() == 1, "이전 농축 저장은 다음 소분 선택과 독립·1개 최대/소진0개 호환"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_to_boss() or not _check(sandbox._resolve_boss_choice("destroy"), "이전3단계 농축 도전 완주"): return
			controls.begin_retry()
			if not _check(player.potion_recipe == PORTIONED_ID and player.potions_remaining == 3, "다음 새 도전에만 소분3개 적용"): return
		"combat":
			if not _check(legacy.grant("gp149-combat", "destroy") == OK and legacy.select_potion_recipe(PORTIONED_ID) == OK, "소분 전투 조제 준비"): return
			sandbox._update_boss_legacy_status()
			controls.begin_retry()
			if not await _choose_earned("magic_barrier") or not await _choose_earned(RESTORATIVE_ID): return
			if not _test_portioned_rounding(): return
			if not await _test_restorative_combat(): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-149 runtime test: OK (" + phase + ")")
	quit(0)

func _files() -> Dictionary:
	var result := {}
	for path in [GP149_SAVE, GP149_SAVE + ".bak", GP149_META, GP149_RECORD, GP149_BOOK]:
		result[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return result

func _test_portioned_rounding() -> bool:
	player.relic_state = {"id": PrototypeRelic.DEW_ID, "used": false}
	for sample in [{"maximum": 100, "heal": 30}, {"maximum": 120, "heal": 36}, {"maximum": 101, "heal": 31}, {"maximum": 105, "heal": 32}]:
		player.damage_receiver.max_health = sample.maximum
		player.damage_receiver.health = 1
		player.prepare_potions(PORTIONED_ID)
		_press_potion()
		if not _check(player.damage_receiver.health == 1 + sample.heal and player.potions_remaining == 2 and controls.movement_metrics.potion_heal_percent == 30, "소분20%+이슬10%는 정확한30%·정수 올림 경계·한 체력 과회복 없음"): return false
	return true

func _finish_to_boss() -> bool:
	while not runner.awaiting_boss_choice():
		if not _finish_stage(): return false
		if runner.awaiting_boss_choice(): break
		if not _check(sandbox._claim_weapon_reward(""), "실제 정예 보상"): return false
		_tap(controls.stage_route_rects[0].get_center())
	return true

func _test_portioned_save() -> bool:
	var saved := store.load_checkpoint()
	if not _check(saved.player.potion_recipe == PORTIONED_ID and saved.player.potions_remaining == 3 and saved.growth.ranks.potion_pouch == 1, "소분 원본 ID/주머니/남은3개 저장"): return false
	for invalid in [null, true, "3", -1, 5, 0.5]:
		var bad := saved.duplicate(true)
		bad.player.potions_remaining = invalid
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "소분 잔량 타입/음수/소수/상한 변조 거부·정상 저장 보호"): return false
	var bad := saved.duplicate(true)
	bad.player.erase("potions_remaining")
	return _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "명시 조제에 개수 누락 거부")

func _test_recipe_layout(rescued: bool, destroyed: bool) -> bool:
	controls.show_main_screen()
	controls.show_village()
	var files := _files()
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls.village_page = "village"
		if not _check(controls.village_snapshot().cards[4].open == (rescued or destroyed), "구출/파괴 해금 약방 시설 표시"): return false
		_tap(controls.village_snapshot().layout.cards[4].get_center())
		var snapshot: Dictionary = controls.village_snapshot()
		if not _check(snapshot.cards.size() == 3 and snapshot.cards[0].open and snapshot.cards[1].open == rescued and snapshot.cards[2].open == destroyed and snapshot.cards[2].id == PORTIONED_ID, "실제 약방 진입·기존순서/세조제·구출/파괴 독립 조건"): return false
		if not _check(snapshot.cards[2].lines[0] == "최대 체력 20% 회복 · 정수 올림" and snapshot.cards[2].lines[1] == "도전당 3개 · 스테이지 간 보존" and snapshot.cards[2].lines[2] == ("세 번 나누어 회복" if destroyed else "태엽 기사 파괴로 소분 조제 해금"), "소분 원본 성능/해금 설명"): return false
		var safe: Rect2 = controls.layout_snapshot().safe
		var rects: Array = snapshot.layout.cards.duplicate()
		rects.append_array([snapshot.layout.back, snapshot.layout.start])
		if controls.checkpoint_available: rects.append(snapshot.layout["continue"])
		for i in rects.size():
			if not _check(safe.encloses(rects[i]), "두 화면비 안전 영역"): return false
			for j in range(i + 1, rects.size()):
				if not _check(not rects[i].intersects(rects[j]), "세조제/복귀/준비/이어하기 비중첩"): return false
		for i in snapshot.cards.size():
			var rect: Rect2 = snapshot.layout.cards[i]
			for j in snapshot.cards[i].lines.size():
				var line: String = snapshot.cards[i].lines[j]
				var line_rect := Rect2(rect.position + Vector2(12, rect.size.y * (0.44 + j * 0.08)), Vector2(rect.size.x - 24, rect.size.y * 0.08))
				var font_size := mini(18, maxi(12, int(line_rect.size.y * 0.8)))
				while font_size > 10 and ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > line_rect.size.x: font_size -= 1
				if not _check(rect.encloses(line_rect) and ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= line_rect.size.x, "세 카드 설명 줄 높이/글자 폭"): return false
		controls.queue_redraw()
		await process_frame
	return _check(_files() == files and not sandbox._use_recovery_potion(), "약방 조회·프레임·잠금 회복약은 저장/잔량 무변경")

func _test_portioned_view() -> bool:
	var files := _files()
	if not _check(controls.open_run_build() and paused, "실제 현재 도전 상태 조회"): return false
	var survival := PrototypeRunBuildView.cards(2, controls.run_build_state)[1]
	if not _check(survival.lines[1] == "소분 회복약 3 / 4개" and survival.lines[2] == "회복약 · 최대 체력 30% 회복 · 방벽 +10", "소분 이름/주머니잔량/이슬30%/방벽10 조회"): return false
	_press_potion()
	if not await _test_layout(): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(3.1)
	return _check(not paused and _files() == files and player.potions_remaining == 3, "조회/복귀는 소분 미소비·저장 무변경")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-149 failed: " + message)
		paused = false
		quit(1)
	return condition
