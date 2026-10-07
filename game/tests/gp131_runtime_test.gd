extends "res://tests/gp128_runtime_test.gd"

const GP131_SAVE := "user://gp131_checkpoint.json"
const GP131_META := "user://gp131_meta.jsonl"
const GP131_RECORD := "user://gp131_records.jsonl"
const GP131_BOOK := "user://gp131_abilities.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP131_SAVE
	legacy.save_path = GP131_META
	book.save_path = GP131_BOOK
	if phase in ["seed", "combat"]:
		store.clear_checkpoint()
		for path in [GP131_META, GP131_RECORD, GP131_BOOK]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.ability_discovery_store = book
	sandbox.get_node("LocalTestRecorder").record_path = GP131_RECORD
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	recorder = sandbox.get_node("LocalTestRecorder")
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	for controller in [weapons.sword_combat, weapons.bow_combat]:
		controller.set_process(false)
		controller.set_physics_process(false)
	player.set_physics_process(false)
	runner.set_process(false)
	match phase:
		"seed":
			controls.begin_retry()
			player.damage_receiver.health = 45
			if not await _choose_pouch(): return
			if not _check(player.potion_pouch_unlocked and player.potions_remaining == 3 and player.potions_capacity() == 3 and player.damage_receiver.health == 45 and growth.ranks.potion_pouch == 1 and book.snapshot().has("potion_pouch") and controls._action_label(&"recovery_potion") == "회복 3/3", "실제 주머니 카드 +1개·3칸·체력 유지·1등급·발견·HUD"): return
			for ignored in 100:
				for card in growth._draw_cards():
					if not _check(card.id != "potion_pouch", "도전당 1회 후보 제외"): return
			if not _reject_card("potion_pouch") or not _check(player.potions_remaining == 3, "중복 선택 보충 없음"): return
			if not _finish_stage(): return
			var saved := store.load_checkpoint()
			store.save_path = "user://gp131_missing/checkpoint.json"
			if not _check(not sandbox._claim_weapon_reward("") and not runner.reward_claimed and player.potions_remaining == 3, "중간 저장 실패는 주머니·개수·보상 보존"): return
			store.save_path = GP131_SAVE
			if not _check(store.load_checkpoint() == saved and sandbox._claim_weapon_reward(""), "정상 파일 보호·보상 재시도"): return
			saved = store.load_checkpoint()
			if not _check(saved.player.potions_remaining == 3 and saved.growth.ranks.potion_pouch == 1, "기본 3개·능력 등급 저장"): return
			for invalid in [null, true, "3", [], {}, -1, 4, 1.5]:
				var bad := saved.duplicate(true)
				bad.player.potions_remaining = invalid
				if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "주머니 있어도 잘못된 타입·음수·초과·소수 개수 거부"): return
			controls.show_main_screen()
			controls.show_village()
			if not await _test_book_layout(): return
			controls.ability_codex_page = 3
			var cards: Array = controls.village_snapshot().cards
			if not _check(cards.filter(func(card: Dictionary) -> bool: return card.id == "potion_pouch" and card.open and card.status == "이번 도전 1등급").size() == 1 and player.potions_remaining == 3, "전체 능력 도감 실제 원본·등급·조회는 보충 없음"): return
		"resume":
			if not _check(not player.potion_pouch_unlocked and player.potions_capacity() == 2 and controls.discovered_abilities.has("potion_pouch"), "영구 발견만으로 시작 주머니 자동 지급 없음"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and player.potion_pouch_unlocked and player.potions_remaining == 3 and player.potions_capacity() == 3, "별도 프로세스·반복 이어하기 3개 복원·중복 보충 없음"): return
			_tap(controls.stage_route_rects[1].get_center())
			var ultimate: UltimateController = sandbox.get_node("Player/UltimateController")
			var gauge := ultimate.gauge
			weapons.sword_combat._skill_1_cooldown_s = 3.25
			weapons.bow_combat._skill_2_cooldown_s = 4.75
			for remaining in [2, 1, 0]:
				player.damage_receiver.health = 1
				_press_pouch_potion()
				if not _check(player.potions_remaining == remaining and player.damage_receiver.health == 1 + ceili(player.damage_receiver.max_health * 0.25) and controls._action_label(&"recovery_potion") == "회복 %d/3" % remaining, "추가 회복약 실제 모바일 소비·기본 25%·HUD 잔량"): return
			var health := player.damage_receiver.health
			_press_pouch_potion()
			if not _check(player.potions_remaining == 0 and player.damage_receiver.health == health and ultimate.gauge == gauge and weapons.sword_combat._skill_1_cooldown_s == 3.25 and weapons.bow_combat._skill_2_cooldown_s == 4.75, "소진 후 사용 차단·필살기와 양 무기 쿨다운 독립"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward("") and store.load_checkpoint().player.potions_remaining == 0, "다음 정예 휴식은 회복약 충전 없음·0개 저장"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and player.potion_pouch_unlocked and player.potions_remaining == 0 and player.potions_capacity() == 3, "소진 상태 재시작 복원·무료 보충 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _check(player.potions_remaining == 0, "보스 스테이지 이동도 소진 유지"): return
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("rescue"), "주머니 실제 보스 완주"): return
			controls.begin_retry()
			if not _check(not player.potion_pouch_unlocked and player.potions_remaining == 2 and player.potions_capacity() == 2 and book.snapshot().has("potion_pouch"), "새 도전 기본 2개 초기화·영구 발견 유지"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 저장 준비"): return
			var old := store.load_checkpoint()
			old.player.erase("potions_remaining")
			old.player.erase("potion_recipe")
			if not _check(not old.growth.ranks.has("potion_pouch") and store.save_checkpoint(old) == OK, "기존 초기 저장 형식 준비"): return
			old.player.potions_remaining = 3
			if not _check(not RunCheckpointStore.valid_state(old), "주머니 없는 기본 3개 변조 거부"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and not player.potion_pouch_unlocked and player.potions_remaining == 2 and player.potions_capacity() == 2, "기존 저장 기본 25%·2개 호환"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "기존 저장 두 번째 정예"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("destroy"), "기존 저장 실제 보스 완주"): return
		"combat":
			if not _check(legacy.grant("gp131-apothecary", "rescue") == OK and legacy.select_potion_recipe(PrototypePotionRecipes.CONCENTRATED) == OK, "실제 구출 해금·농축 조제 준비"): return
			sandbox._update_boss_legacy_status()
			controls.begin_retry()
			if not _check(player.potion_recipe == PrototypePotionRecipes.CONCENTRATED and player.potions_remaining == 1, "농축 새 도전 1개"): return
			_press_pouch_potion()
			if not _check(player.potions_remaining == 1, "만피 농축은 소비 없음"): return
			player.damage_receiver.health = 1
			_press_pouch_potion()
			if not _check(player.potions_remaining == 0 and player.damage_receiver.health == 41, "농축 실제 40% 회복"): return
			if not await _choose_pouch(): return
			if not _check(player.potions_remaining == 1 and player.potions_capacity() == 2 and player.damage_receiver.health == 41 and controls._action_label(&"recovery_potion") == "회복 1/2", "소진 후 선택은 1개만 보충·농축 최대2·즉시 치료 없음"): return
			_press_pouch_potion()
			if not _check(player.potions_remaining == 0 and player.damage_receiver.health == 81, "추가 농축도 같은 40% 회복"): return
			player.set_potion_pouch_unlocked(true, true)
			if not _check(player.potions_remaining == 0, "이미 해금된 주머니 직접 재호출 보충 없음"): return
			controls.begin_retry()
			if not await _choose_pouch(): return
			if not _check(player.potions_remaining == 2 and player.potions_capacity() == 2, "미사용 농축에 주머니 선택은 2개"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "농축 2개 저장"): return
			var saved := store.load_checkpoint()
			var bad := saved.duplicate(true)
			bad.player.potions_remaining = 3
			if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "농축 주머니도 최대 2개·정상 파일 보호"): return
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and player.potion_recipe == PrototypePotionRecipes.CONCENTRATED and player.potions_remaining == 2 and player.potions_capacity() == 2, "농축 2개 복원·기본 조제 최대1에 잘못 잘리지 않음"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "농축 주머니 두 번째 정예"): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			_tap(controls.stage_route_rects[0].get_center())
			player.damage_receiver.tick(2)
			_hit_player(9999, "pouch-phoenix")
			if not _check(not player.damage_receiver.dead and player.relic_state.used and player.potions_remaining == 2 and player.potions_capacity() == 2, "불사조 부활은 주머니·회복약 잔량 보존"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-131 runtime test: OK (" + phase + ")")
	quit(0)

func _choose_pouch() -> bool:
	var chosen_seed := -1
	for candidate in 256:
		growth.rng.seed = candidate
		for card in growth._draw_cards():
			if card.id == "potion_pouch": chosen_seed = candidate
		if chosen_seed >= 0: break
	if not _check(chosen_seed >= 0, "실제 공용 주머니 후보 등장"): return false
	growth.rng.seed = chosen_seed
	player.global_position.x = 1240
	runner._process(0.1)
	for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
	var index := -1
	for i in growth.offered_cards.size():
		if growth.offered_cards[i].id == "potion_pouch": index = i
	if not _check(index >= 0 and paused and growth.choosing, "실제 처치 레벨업·주머니 카드 UI"): return false
	var before := growth.checkpoint_snapshot()
	var potions := player.potions_remaining
	var health := player.damage_receiver.health
	book.save_path = "user://gp131_missing/abilities.jsonl"
	_tap(controls.growth_card_rects[index].get_center())
	if not _check(paused and growth.choosing and growth.checkpoint_snapshot() == before and not player.potion_pouch_unlocked and player.potions_remaining == potions and player.damage_receiver.health == health, "발견 기록 실패는 주머니·보충·체력·등급·성향 미적용"): return false
	book.save_path = GP131_BOOK
	_tap(controls.growth_card_rects[index].get_center())
	return _check(not paused and not growth.choosing and player.potion_pouch_unlocked, "같은 카드 재선택·기록·보충·전투 재개")

func _press_pouch_potion() -> void:
	var event := InputEventScreenTouch.new()
	event.index = 7
	event.position = controls.action_rects[&"recovery_potion"].get_center()
	event.pressed = true
	controls._input(event)
	controls._physics_process(0.01)
	controls._handle_touch_released(7)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-131 failed: " + message)
		paused = false
		quit(1)
	return condition
