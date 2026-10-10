extends "res://tests/gp146_runtime_test.gd"

const GP148_SAVE := "user://gp148_checkpoint.json"
const GP148_META := "user://gp148_meta.jsonl"
const GP148_RECORD := "user://gp148_records.jsonl"
const GP148_BOOK := "user://gp148_abilities.jsonl"
const RESTORATIVE_ID := "restorative_barrier"

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	store.save_path = GP148_SAVE
	legacy.save_path = GP148_META
	book.save_path = GP148_BOOK
	if phase in ["seed", "legacy-seed", "combat"]:
		store.clear_checkpoint()
		for path in [GP148_META, GP148_RECORD, GP148_BOOK]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.ability_discovery_store = book
	sandbox.get_node("LocalTestRecorder").record_path = GP148_RECORD
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
			controls.begin_retry("sword", 5)
			if not _test_restorative_gates(false): return
			if not await _choose_earned("magic_barrier"): return
			_barrier_hit("seed7", 7)
			if not await _choose_earned(RESTORATIVE_ID, true): return
			if not _check(player.damage_receiver.barrier_health == 13 and player.potion_barrier_recovery() == 10, "실제 선택은13잔량 유지·다음 회복약부터10"): return
			if not _test_restorative_gates(true): return
			player._input_lock_remaining_s = 0
			player.damage_receiver.health = 1
			_press_potion()
			if not _check(player.damage_receiver.barrier_health == 20 and player.potions_remaining == 1, "실제 회복약1개 소비·방벽20 상한"): return
			if not await _test_restorative_view(): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "실제 첫 정예 보상"): return
			player.damage_receiver.health = 17
			player.damage_receiver.barrier_health = 13
			ultimate.gauge = 31
			weapons.sword_combat._skill_1_cooldown_s = 3.25
			weapons.bow_combat._skill_2_cooldown_s = 5.5
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "회복 방벽·회복약1개·잔량·체력·게이지·양 대기 저장"): return
			if not _test_restorative_save(): return
			controls.show_main_screen()
			controls.show_village()
			if not await _test_book_layout(): return
			var cards := PrototypeAbilityCodex.cards(book.snapshot(), growth.ranks)
			var card: Dictionary = cards.filter(func(item: Dictionary) -> bool: return item.id == RESTORATIVE_ID)[0]
			if not _check(cards.size() == PrototypeAbilityCodex.definitions().size() and card.open and card.status == "이번 도전 1등급" and card.lines[2] == "조건: 마력 방벽 획득 후", "전체 능력 도감·조건/발견/현재 등급"): return
		"resume":
			if not _check(player.potion_barrier_recovery() == 0 and book.snapshot().has(RESTORATIVE_ID), "발견만으로 능력 지급 없음"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and player.potion_barrier_recovery() == 10 and player.damage_receiver.barrier_health == 13 and player.damage_receiver.health == 17 and player.potions_remaining == 1 and ultimate.gauge == 31 and weapons.sword_combat._skill_1_cooldown_s == 3.25 and weapons.bow_combat._skill_2_cooldown_s == 5.5, "별도 프로세스·반복 복원·무료 충전/회복약 보충 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			_barrier_hit("restored20", 20)
			player._input_lock_remaining_s = 0
			var health := player.damage_receiver.health
			var gauge := ultimate.gauge
			var timers := weapons.checkpoint_snapshot()
			_press_potion()
			if not _check(player.damage_receiver.barrier_health == 10 and player.potions_remaining == 0 and player.damage_receiver.health == mini(player.damage_receiver.max_health, health + ceili(player.damage_receiver.max_health * 0.25)) and ultimate.gauge == gauge and weapons.checkpoint_snapshot() == timers, "복원 후 실제 소비·방벽10·원래25%회복·게이지/양 대기 독립"): return
			if not await _test_restorative_view(): return
			while not runner.awaiting_boss_choice():
				if not _finish_stage(): return
				if runner.awaiting_boss_choice(): break
				if not _check(sandbox._claim_weapon_reward(""), "정예 보상에서 능력/소진 유지"): return
				_tap(controls.stage_route_rects[0].get_center())
			if not _check(store.load_checkpoint().growth.ranks[RESTORATIVE_ID] == 1 and store.load_checkpoint().player.potions_remaining == 0 and runner.stage_number == 5, "5스테이지 최종 저장·회복약 무료 보충 없음"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and player.potion_barrier_recovery() == 10 and player.potions_remaining == 0 and sandbox._resolve_boss_choice("rescue"), "보스 선택 복원·소진 유지·완주"): return
			controls.begin_retry("bow", 3)
			if not _check(player.potion_barrier_recovery() == 0 and not player.barrier_unlocked and growth.ranks.is_empty() and book.snapshot().has(RESTORATIVE_ID) and player.potions_remaining == 2, "새 도전 초기화·기본2개·발견 유지"): return
		"legacy-seed":
			controls.begin_retry("bow", 3)
			if not await _choose_earned("magic_barrier"): return
			_barrier_hit("legacy7", 7)
			player._input_lock_remaining_s = 0
			player.damage_receiver.health = 1
			_press_potion()
			if not _check(player.damage_receiver.barrier_health == 13 and player.potions_remaining == 1, "미획득 회복약은 방벽 충전 없음"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 기본 방벽 저장 준비"): return
			if not _check(not store.load_checkpoint().growth.ranks.has(RESTORATIVE_ID), "기존 저장에 새 능력 없음"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and player.damage_receiver.barrier_health == 13 and player.potion_barrier_recovery() == 0, "이전 저장·능력 소급 지급 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			_barrier_hit("legacy7-again", 7)
			player._input_lock_remaining_s = 0
			player.damage_receiver.health = 1
			_press_potion()
			if not _check(player.damage_receiver.barrier_health == 13 and player.potions_remaining == 0, "이전 저장 실제 회복약은 방벽 충전 없음"): return
			while not runner.awaiting_boss_choice():
				if not _finish_stage(): return
				if runner.awaiting_boss_choice(): break
				if not _check(sandbox._claim_weapon_reward(""), "이전 저장 정예"): return
				_tap(controls.stage_route_rects[0].get_center())
			if not _check(sandbox._resolve_boss_choice("destroy"), "이전3스테이지 완주"): return
		"combat":
			controls.begin_retry()
			if not await _choose_earned("magic_barrier") or not await _choose_earned(RESTORATIVE_ID): return
			if not await _test_restorative_combat(): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-148 runtime test: OK (" + phase + ")")
	quit(0)

func _choose_earned(id: String, failure: bool = false) -> bool:
	var seed_value := -1
	for candidate in 512:
		growth.rng.seed = candidate
		for card in growth._draw_cards():
			if card.id == id: seed_value = candidate
		if seed_value >= 0: break
	if not _check(seed_value >= 0, "원본 후보 풀에서 다음 능력 발견: " + id): return false
	growth.rng.seed = seed_value
	for ignored in 12:
		if growth.choosing: break
		match runner.current_section:
			PrototypeStageRunner.Section.ADVANCE_ONE: player.global_position.x = 1240
			PrototypeStageRunner.Section.ADVANCE_TWO: player.global_position.x = 3840
			PrototypeStageRunner.Section.WAVE_ONE, PrototypeStageRunner.Section.WAVE_TWO:
				for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
			PrototypeStageRunner.Section.ELITE: _defeat(runner.final_enemy())
		if not growth.choosing: runner._process(0.1)
	var index := -1
	for i in growth.offered_cards.size():
		if growth.offered_cards[i].id == id: index = i
	if not _check(index >= 0 and growth.choosing and paused, "실제 처치 레벨업·자연 후보 UI: " + id): return false
	var before := growth.checkpoint_snapshot()
	var equipment := weapons.checkpoint_snapshot()
	var health := player.damage_receiver.health
	var potions := player.potions_remaining
	var bonus := _bonus()
	var barrier := player.damage_receiver.barrier_health
	var gauge := ultimate.gauge
	if failure:
		for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
			controls.size = dimensions
			controls._refresh_growth_layout()
			var rect: Rect2 = controls.growth_card_rects[index]
			if not _check(controls.layout_snapshot().safe.encloses(rect), "직업 강화 카드 두 화면비 안전 영역"): return false
			for line in growth.offered_cards[index].lines:
				if not _check(ThemeDB.fallback_font.get_string_size(String(line), HORIZONTAL_ALIGNMENT_LEFT, -1, mini(26, int(rect.size.x / 12.0)) - 3).x <= rect.size.x - 24, "강화 설명 글자 너비"): return false
			controls.queue_redraw()
			await process_frame
		book.save_path = "user://gp148_missing/abilities.jsonl"
		_tap(controls.growth_card_rects[index].get_center())
		if not _check(paused and growth.choosing and growth.checkpoint_snapshot() == before and _bonus() == bonus and not book.snapshot().has(id), "영구 발견 저장 실패·등급/성향/효과 미적용"): return false
		book.save_path = GP148_BOOK
	_tap(controls.growth_card_rects[index].get_center())
	if failure and not _check(is_equal_approx(_bonus(), bonus) and player.damage_receiver.barrier_health == barrier and player.damage_receiver.health == health and player.potions_remaining == potions and weapons.checkpoint_snapshot() == equipment and ultimate.gauge == gauge, "같은 카드 재시도·방벽 선택 자체는 즉시 회복 없음·회복/대기/게이지 보존"): return false
	if growth.awaiting_job_confirmation:
		_tap(controls.job_ultimate_rects[0].get_center())
		_tap(controls.job_confirm_rect.get_center())
	return _check(not paused and not growth.choosing and growth.ranks.has(id) and book.snapshot().has(id), "실제 카드 터치·영구 발견·재개")

func _files() -> Dictionary:
	var result := {}
	for path in [GP148_SAVE, GP148_SAVE + ".bak", GP148_META, GP148_RECORD, GP148_BOOK]:
		result[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return result

func _test_restorative_gates(owned: bool) -> bool:
	for ignored in 100:
		if not _check(not growth._draw_cards().any(func(card: Dictionary) -> bool: return card.id == RESTORATIVE_ID), "선행 없음/최대1등급 후보 차단"): return false
	var before := growth.checkpoint_snapshot()
	var barrier := player.damage_receiver.barrier_health
	if not _reject_card(RESTORATIVE_ID): return false
	return _check(before == growth.checkpoint_snapshot() and barrier == player.damage_receiver.barrier_health and player.potion_barrier_recovery() == (10 if owned else 0), "선행/중복 확정 거부·등급/성향/잔량 무변경")

func _test_restorative_save() -> bool:
	var saved := store.load_checkpoint()
	for invalid in [null, true, "1", 0, 2, 0.5]:
		var bad := saved.duplicate(true)
		bad.growth.ranks[RESTORATIVE_ID] = invalid
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "등급 변조·정상 저장 보호"): return false
	var bad := saved.duplicate(true)
	bad.growth.ranks.erase("magic_barrier")
	bad.growth.ranks.vitality = int(bad.growth.ranks.get("vitality", 0)) + 1
	bad.player.max_health += 20
	bad.player.barrier_health = 0
	return _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "선행 없는 회복 방벽 저장 거부")

func _press_potion(held: bool = false) -> void:
	controls._handle_touch_released(7)
	var event := InputEventScreenTouch.new()
	event.index = 7
	event.position = controls.action_rects[&"recovery_potion"].get_center()
	event.pressed = true
	controls._input(event)
	controls._physics_process(0.01)
	if not held: controls._handle_touch_released(7)

func _test_restorative_combat() -> bool:
	player.damage_receiver.max_health = 101
	player.set_potion_pouch_unlocked(true)
	var timers := weapons.checkpoint_snapshot()
	var gauge := ultimate.gauge
	for recipe in PrototypePotionRecipes.IDS:
		for dew in [false, true]:
			player.relic_state = {"id": PrototypeRelic.DEW_ID, "used": false} if dew else {}
			player.prepare_potions(recipe)
			player.damage_receiver.health = 1
			player.damage_receiver.barrier_health = 0
			var before := player.potions_remaining
			var expected := 1 + ceili(101 * player.potion_heal_ratio())
			_press_potion(true)
			if not _check(player.damage_receiver.health == expected and player.damage_receiver.barrier_health == 10 and player.potions_remaining == before - 1 and controls.movement_metrics.barrier_health == 10 and controls.movement_metrics.potion_barrier_recovery == 10, "기본/농축·이슬 조합 원래 회복률·실제1개 소비·방벽10·HUD"): return false
			for ignored in 20: controls._physics_process(0.05)
			if not _check(player.damage_receiver.barrier_health == 10 and player.damage_receiver.health == expected and player.potions_remaining == before - 1, "버튼 유지·반복 프레임은 중복 소비/무료 충전 없음"): return false
			controls._handle_touch_released(7)
			player.damage_receiver.health = 100
			_press_potion()
			if not _check(player.damage_receiver.health == 101 and player.damage_receiver.barrier_health == 20 and player.potions_remaining == before - 2, "실제 체력1 회복도1개 소비·방벽10·20 상한"): return false
	player.relic_state = {}
	for fortified in [false, true]:
		player.set_fortified_barrier_unlocked(fortified)
		var cap := player.barrier_capacity()
		player.prepare_potions(PrototypePotionRecipes.BASIC)
		player.damage_receiver.health = 101
		player.damage_receiver.barrier_health = 0
		_press_potion()
		if not _check(player.potions_remaining == 3 and player.damage_receiver.barrier_health == 0, "만피·방벽 소진에도 회복약 무료 사용 없음"): return false
		player.damage_receiver.health = 1
		player.damage_receiver.barrier_health = cap - 2
		_press_potion()
		if not _check(player.damage_receiver.barrier_health == cap and player.potion_log.ends_with("방벽 +2"), "기본20/강화30 상한·실제 보충2 로그"): return false
		player.damage_receiver.health = 1
		_press_potion()
		if not _check(player.damage_receiver.barrier_health == cap and player.potion_log.ends_with("방벽 +0") and player.potions_remaining == 1, "가득 찬 방벽은 체력 회복만·원래1개 소비"): return false
		player.damage_receiver.health = 1
		player.damage_receiver.barrier_health = 0
		player.potions_remaining = 0
		_press_potion()
		if not _check(player.damage_receiver.health == 1 and player.damage_receiver.barrier_health == 0, "소진 후 회복/방벽 없음"): return false
	player.set_fortified_barrier_unlocked(false)
	player.prepare_potions(PrototypePotionRecipes.BASIC)
	player.damage_receiver.health = 1
	player.damage_receiver.barrier_health = 0
	player.apply_growth_health(0, 1)
	if not _check(player.damage_receiver.barrier_health == 0 and player.potions_remaining == 3, "다른 회복·약 준비는 방벽 미지급"): return false
	_press_potion()
	var health := player.damage_receiver.health
	_barrier_hit("potion-impact17", 17)
	if not _check(player.damage_receiver.barrier_health == 0 and player.damage_receiver.health == health - 7, "회복된 방벽10은 실제17피해 흡수·체력7 차감"): return false
	player.damage_receiver.health = 1
	player.damage_receiver.barrier_health = 0
	player.prepare_potions(PrototypePotionRecipes.BASIC)
	player.damage_receiver.tick(2.0)
	for reason in ["hit", "fall", "dead", "paused", "environment", "stage", "ended", "main"]:
		match reason:
			"hit": player._input_lock_remaining_s = 1.0
			"fall": player._fall_recovery_active = true
			"dead": player.damage_receiver.dead = true
			"paused": paused = true
			"environment": sandbox._combat_environment_suspended = true
			"stage": runner.stage_complete = true
			"ended": growth.run_active = false
			"main": controls.screen_mode = 2
		if not _check(not sandbox._use_recovery_potion() and player.potions_remaining == 3 and player.damage_receiver.health == 1 and player.damage_receiver.barrier_health == 0, reason + " 차단·회복약/체력/방벽 보존"): return false
		player._input_lock_remaining_s = 0
		player._fall_recovery_active = false
		player.damage_receiver.dead = false
		paused = false
		sandbox._combat_environment_suspended = false
		runner.stage_complete = false
		growth.run_active = true
		controls.screen_mode = 0
	if not await _test_restorative_view(): return false
	if not _check(weapons.checkpoint_snapshot() == timers and ultimate.gauge == gauge, "회복 방벽은 스킬/필살기 대기와 충전 독립"): return false
	player.set_barrier_unlocked(false)
	if not _check(player.potion_barrier_recovery() == 0 and not player.restorative_barrier_unlocked, "방벽 해제는 회복 방벽도 종료"): return false
	return true

func _test_restorative_view() -> bool:
	var files := _files()
	var barrier := player.damage_receiver.barrier_health
	var health := player.damage_receiver.health
	var potions := player.potions_remaining
	if not _check(controls.open_run_build() and paused, "실제 도전 상태 조회"): return false
	var abilities := PrototypeRunBuildView.cards(0, controls.run_build_state)
	var card: Dictionary = abilities.filter(func(item: Dictionary) -> bool: return item.id == RESTORATIVE_ID)[0]
	var survival := PrototypeRunBuildView.cards(2, controls.run_build_state)[1]
	if not _check(card.status == "이번 도전 1등급" and survival.lines[2].ends_with("방벽 +10"), "실제 보유 능력·회복약 방벽 보충량 조회"): return false
	_press_potion()
	if not _check(not sandbox._use_recovery_potion(), "조회 중 지연된 회복약 명령 차단"): return false
	if not await _test_layout(): return false
	controls.notification(Control.NOTIFICATION_APPLICATION_PAUSED)
	controls.notification(Control.NOTIFICATION_APPLICATION_RESUMED)
	player.set_physics_process(true)
	await create_timer(0.12, true).timeout
	if not _check(player.damage_receiver.barrier_health == barrier and player.damage_receiver.health == health and player.potions_remaining == potions and _files() == files, "앱 복귀·조회 실제 프레임 동결/저장 무변경"): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(2.9)
	_press_potion()
	if not _check(paused and not sandbox._use_recovery_potion() and player.damage_receiver.barrier_health == barrier and player.potions_remaining == potions, "3초 복귀 중 회복약/방벽 미지급"): return false
	controls.advance_mode_timer_for_test(0.2)
	player.set_physics_process(false)
	return _check(not paused and _files() == files and player.damage_receiver.barrier_health == barrier and player.damage_receiver.health == health and player.potions_remaining == potions, "복귀 원래 체력/방벽/소진 유지")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-148 failed: " + message)
		paused = false
		quit(1)
	return condition
