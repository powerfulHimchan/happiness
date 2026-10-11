extends "res://tests/gp162_166_runtime_test.gd"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var key := args[0] if not args.is_empty() else "rune"
	var phase := args[1] if args.size() > 1 else "seed"
	var id: String = {"rune": PrototypeRelic.RUNE_ID, "compass": PrototypeRelic.COMPASS_ID, "coin": PrototypeRelic.COIN_ID, "cup": PrototypeRelic.CUP_ID}.get(key, "")
	if not _check(not id.is_empty(), "유효한 검사 유물"): return
	BATCH_SAVE = "user://gp171_174_" + key + "_checkpoint.json"
	BATCH_META = "user://gp171_174_" + key + "_meta.jsonl"
	BATCH_RECORD = "user://gp171_174_" + key + "_record.jsonl"
	BATCH_BOOK = "user://gp171_174_" + key + "_book.jsonl"
	store.save_path = BATCH_SAVE
	legacy.save_path = BATCH_META
	if phase in ["seed", "combat"]:
		store.clear_checkpoint()
		for path in [BATCH_META, BATCH_RECORD]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	var discoveries := AbilityDiscoveryStore.new()
	discoveries.save_path = BATCH_BOOK
	if phase in ["seed", "combat"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(discoveries.save_path))
	sandbox.ability_discovery_store = discoveries
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = BATCH_RECORD
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
	weapons.set_physics_process(false)
	ultimate.set_process(false)
	ultimate.set_physics_process(false)
	growth.jobs_enabled = false
	for enemy in runner._all_combat_enemies():
		enemy.set_process(false)
		enemy.set_physics_process(false)
	match phase:
		"seed":
			controls.begin_retry("sword", 5)
			if not _check(not sandbox._claim_relic_reward(id), "보상 전 유물 지급 거부"): return
			if not _reach_relic_reward(): return
			var saved := store.load_checkpoint()
			if not await _test_relic_layout(): return
			if not _check(store.load_checkpoint() == saved and player.relic_state.is_empty(), "전 페이지 비교·취소는 저장·효과 유지"): return
			if not _open_new_relic(id): return
			_set_timers()
			ultimate.gauge = 37
			var before := _effect_snapshot()
			store.save_path = "user://gp171_174_missing/checkpoint.json"
			_tap(controls.relic_reward_confirm_rect.get_center())
			store.save_path = BATCH_SAVE
			if not _check(controls.current_screen_mode() == 15 and PrototypeRelic.OFFERS[controls.selected_relic_offer].id == id and _effect_snapshot() == before and store.load_checkpoint() == saved, "새 유물 실제 저장 실패·선택 보존·모든 효과/파일 롤백"): return
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(player.relic_state == {"id": id, "used": false} and controls.current_screen_mode() == 9 and not sandbox._claim_relic_reward(id), "둘째 페이지 실제 유물 확정·한 도전 하나"): return
			var after := _effect_snapshot()
			after.erase("relic")
			before.erase("relic")
			if not _check(after == before, "획득 즉시 체력·게이지·약·성장·원본 대기 불변"): return
			if not _test_new_save(id) or not await _test_village_codex(id, false) or not await _test_dew_text(): return
		"resume":
			if not _check(player.relic_state.is_empty(), "재시작 첫 화면 자동 지급 없음"): return
			var saved := store.load_checkpoint()
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and player.relic_state == saved.relic and player.damage_receiver.health == saved.player.health and player.potions_remaining == saved.player.potions_remaining and ultimate.gauge == 37 and _weapon_matches(saved.weapons), "별도 프로세스 반복 복원·잔량·원본 대기 보존"): return
			if not _test_derived_effect(id): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _test_new_view(id): return
			if not _finish_to_boss() or not _check(runner.stage_number == 5 and store.load_checkpoint().relic.id == id, "5스테이지 최종 보스 저장까지 유물 유지"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and player.relic_state.id == id and sandbox._resolve_boss_choice("rescue"), "각 새 유물 보스 선택 복원·완주"): return
			controls.use_boss_legacy = false
			controls.begin_retry("bow", 3)
			if not _check(player.relic_state.is_empty() and player.incoming_damage_multiplier() == 1.0 and player.basic_relic_multiplier("basic") == 1.0 and is_equal_approx(player.ground_evade_cooldown_s(), 0.45) and player.recovery_orb_heal_percent() == 10, "새 도전 모든 새 유물 효과 제거"): return
		"combat":
			controls.begin_retry("sword", 3)
			if not _reach_relic_reward() or not _open_new_relic(id): return
			_tap(controls.relic_reward_confirm_rect.get_center())
			_tap(controls.stage_route_rects[0].get_center())
			if not _test_derived_effect(id): return
			match id:
				PrototypeRelic.RUNE_ID:
					if not _rune_hits(): return
				PrototypeRelic.COMPASS_ID:
					if not _compass_orbs(): return
				PrototypeRelic.COIN_ID:
					if not _coin_kills(): return
				PrototypeRelic.CUP_ID:
					if not _cup_potions(): return
		_:
			_check(false, "알 수 없는 단계")
			return
	paused = false
	sandbox.free()
	print("GP-171–174 runtime test: OK · " + key + " · " + phase)
	quit(0)


func _open_new_relic(id: String) -> bool:
	_tap(controls.relic_reward_open_rect.get_center())
	var index := -1
	for i in PrototypeRelic.OFFERS.size():
		if PrototypeRelic.OFFERS[i].id == id: index = i
	var page := index / PrototypeRelic.REWARD_PAGE_SIZE
	for ignored in page: _tap(controls.relic_reward_next_rect.get_center())
	controls._refresh_relic_reward_layout()
	_tap(controls.relic_reward_card_rects[index % PrototypeRelic.REWARD_PAGE_SIZE].get_center())
	if not _check(controls.selected_relic_offer == index, "새 유물 실제 여러 페이지 터치"): return false
	if page == controls.relic_reward_pages() - 1:
		_tap(controls.relic_reward_next_rect.get_center())
		if not _check(controls.selected_relic_offer == index and controls.relic_reward_page == page, "마지막 페이지 다음은 선택 유지"): return false
	return true

func _test_derived_effect(id: String) -> bool:
	if id == PrototypeRelic.COIN_ID and not _check(controls._ultimate_hud_label().contains("처치 +3"), "수집 카드 없이 동전만 보유한 실제 HUD3"): return false
	return _check(player.skill_relic_multiplier("skill") == (1.2 if id == PrototypeRelic.RUNE_ID else 1.0) and player.recovery_orb_pickup_radius() == (114 if id == PrototypeRelic.COMPASS_ID else 76) and is_equal_approx(player.potion_heal_ratio(), 0.30 if id == PrototypeRelic.CUP_ID else 0.25) and ultimate.defeat_gauge_amount(false) == (3 if id == PrototypeRelic.COIN_ID else 0) and player.basic_relic_multiplier("basic") == 1.0, "유물 효과 독립·ID에서 한번 복원")

func _rune_hits() -> bool:
	for node in get_nodes_in_group("targetable"): node.visible = false
	player.global_position = Vector2(1000, 780)
	player.facing_direction = 1
	for weapon in ["sword", "bow"]:
		for kind in ["basic", "skill"]:
			var target := _combat_target("rune:" + weapon + kind, player.global_position + Vector2(180, 0))
			if weapon == "sword":
				weapons.sword_combat._action_sequence += 1
				weapons.sword_combat._damage_target(target, &"sword_basic" if kind == "basic" else &"sword_rising", 100, 0, PackedStringArray(["sword", kind]), 0)
			else:
				weapons.bow_combat._spawn_projectile("rune:" + kind, &"bow_basic" if kind == "basic" else &"bow_chain", 100, 1, Vector2.RIGHT, PackedStringArray(["bow", kind]))
				var shot: BowProjectile = get_nodes_in_group("bow_projectile").back()
				shot.set_physics_process(false)
				shot._check_hits(shot.global_position, target.global_position + Vector2(0, -38))
				shot.free()
			if not _check(target.damage_receiver.health == 1000 - (120 if kind == "skill" else 100), "실제 검/활 스킬만1.2배"): return false
			target.free()
	return _check(player.growth_damage(100, "sword", "ultimate") == 100 and player.growth_damage(100, "bow") == 100, "기본/필살기 강화 제외")

func _compass_orbs() -> bool:
	var orbs: RecoveryOrbController = sandbox.get_node("RecoveryOrbController")
	orbs.set_physics_process(false)
	player.damage_receiver.health = 1
	orbs.orbs = [player.global_position + Vector2(115, 0)]
	orbs._physics_process(0.01)
	if not _check(orbs.orbs.size() == 1, "나침반 바깥 경계 유지"): return false
	orbs.orbs[0] = player.global_position + Vector2(114, 0)
	orbs._physics_process(0.01)
	if not _check(orbs.orbs.is_empty() and player.damage_receiver.health == 1 + player.recovery_orb_heal_amount(), "나침반 거리 실제 획득·회복 유지"): return false
	player.set_orb_magnet_unlocked(true)
	if not _check(player.recovery_orb_pickup_radius() == 228, "기본 자석과 곱연산"): return false
	player.set_orb_magnet_boost_unlocked(true)
	return _check(player.recovery_orb_pickup_radius() == 342 and player.recovery_orb_heal_percent() == 10, "넓은 자석3.42m · 회복 독립")

func _coin_kills() -> bool:
	ultimate.gauge = 0
	var target := _coin_target("coin-alone")
	_defeat(target)
	if not _check(ultimate.gauge == 3, "시간 수집 없이 실제 처치3 충전"): return false
	target.defeated.emit(target)
	if not _check(ultimate.gauge == 3, "동일 생명 중복 처치 충전 차단"): return false
	target.reset_target()
	target.defeated.emit(target)
	if not _check(ultimate.gauge == 3, "살아있는 적 위조 신호 차단"): return false
	target.free()
	if not _resolve_growth(): return false
	paused = true
	target = _coin_target("coin-paused")
	_defeat(target)
	target.free()
	if not _check(ultimate.gauge == 3, "조회/정지 중 처치 동전 충전 없음"): return false
	paused = false
	if not _resolve_growth(): return false
	target = _coin_target("coin-hidden")
	target.visible = false
	_defeat(target)
	target.free()
	if not _check(ultimate.gauge == 3, "숨긴 적 처치 동전 충전 없음"): return false
	growth.ranks.time_collector = 1
	ultimate.set_time_collector_boost_unlocked(true)
	ultimate.gauge = 0
	target = _coin_target("coin-combined")
	_defeat(target)
	if not _check(ultimate.gauge == 11, "강화 시간 수집8+동전3 합산"): return false
	target.free()
	if not _resolve_growth(): return false
	ultimate.gauge = 99
	target = _coin_target("coin-cap")
	_defeat(target)
	target.free()
	return _check(ultimate.gauge == 100, "처치 충전100 상한")

func _cup_potions() -> bool:
	player.set_potion_pouch_unlocked(true)
	player.set_potion_mastery_unlocked(true)
	player._input_lock_remaining_s = 0
	for recipe in [PrototypePotionRecipes.BASIC, PrototypePotionRecipes.CONCENTRATED, PrototypePotionRecipes.PORTIONED]:
		player.prepare_potions(recipe)
		player.damage_receiver.max_health = 101
		player.damage_receiver.health = 1
		var expected := roundi(float(PrototypePotionRecipes.profile(recipe).ratio) * 100) + 10
		var before := player.potions_remaining
		if not _check(player.use_recovery_potion() and player.damage_receiver.health == 1 + ceili(101 * expected / 100.0) and player.potions_remaining == before - 1, "숙련+잔 세 조제 정수올림·한개 소비"): return false
	return _check(player.recovery_orb_heal_percent() == 10 and player.skill_recharge_multiplier() == 1.0, "구슬/대기 독립")

func _coin_target(key: String) -> PrototypeTarget:
	var target := _combat_target(key, player.global_position + Vector2(200, 0))
	target.add_to_group("combat_enemy")
	target.defeated.connect(growth._on_enemy_defeated)
	return target
