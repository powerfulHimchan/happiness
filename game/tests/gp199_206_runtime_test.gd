extends "res://tests/gp171_174_runtime_test.gd"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var key := args[0] if not args.is_empty() else "charm"
	var phase := args[1] if args.size() > 1 else "seed"
	var id: String = {"iron": PrototypeRelic.IRON_LEAF_ID, "spark": PrototypeRelic.LAST_SPARK_ID, "sword": PrototypeRelic.SWORD_PENDANT_ID, "bow": PrototypeRelic.BOW_PENDANT_ID, "bell": PrototypeRelic.TEMPO_BELL_ID, "prism": PrototypeRelic.SKILL_PRISM_ID, "dial": PrototypeRelic.DAWN_DIAL_ID, "lens": PrototypeRelic.BARRIER_LENS_ID}.get(key, "")
	if not _check(not id.is_empty(), "유효한 검사 유물"): return
	BATCH_SAVE = "user://gp199_206_" + key + "_checkpoint.json"
	BATCH_META = "user://gp199_206_" + key + "_meta.jsonl"
	BATCH_RECORD = "user://gp199_206_" + key + "_record.jsonl"
	BATCH_BOOK = "user://gp199_206_" + key + "_book.jsonl"
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
			store.save_path = "user://gp199_206_missing/checkpoint.json"
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
				if not _check(sandbox.continue_saved_run() and player.relic_state == saved.relic and player.damage_receiver.health == saved.player.health and player.potions_remaining == saved.player.potions_remaining and player.lifesteal_progress == int(saved.player.get("lifesteal_progress", 0)) and ultimate.gauge == 37 and _weapon_matches(saved.weapons), "별도 프로세스 반복 복원·잔량·원본 대기 보존"): return
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
			if not _expansion_combat(id): return
		_:
			_check(false, "알 수 없는 단계")
			return
	paused = false
	sandbox.free()
	print("GP-199–206 runtime test: OK · " + key + " · " + phase)
	quit(0)



func _test_derived_effect(id: String) -> bool:
	var low := player.is_crisis_health()
	var high := player.is_calm_health()
	var shield := player.damage_receiver.barrier_health > 0
	return _check(is_equal_approx(player.incoming_damage_multiplier(), 0.85 if id == PrototypeRelic.IRON_LEAF_ID and high else 1.0) and player.expansion_damage_multiplier("sword", "skill") == (1.15 if id == PrototypeRelic.SWORD_PENDANT_ID else 1.3 if id == PrototypeRelic.LAST_SPARK_ID and low else 1.25 if id == PrototypeRelic.BARRIER_LENS_ID and shield else 1.0) and ultimate.weapon_hit_gauge_amount(false) == (6 if id == PrototypeRelic.TEMPO_BELL_ID else 4) and ultimate.weapon_hit_gauge_amount(true) == (11 if id == PrototypeRelic.SKILL_PRISM_ID else 8) and ultimate.duration_for({}) == (4 if id == PrototypeRelic.DAWN_DIAL_ID else 3), "새 유물 ID만으로 파생 효과 복원")

func _expansion_combat(id: String) -> bool:
	for old in get_nodes_in_group("targetable"): old.visible = false
	player.prepare_next_stage(Vector2(1000, 780))
	player.growth_common_bonus = 0
	player.growth_sword_bonus = 0
	player.growth_bow_bonus = 0
	player.damage_receiver.max_health = 100
	for health in [30, 31, 79, 80]:
		for barrier in [0, 1]:
			player.damage_receiver.health = health
			player.damage_receiver.barrier_health = barrier
			if not _test_derived_effect(id): return false
			for weapon in ["sword", "bow"]:
				for kind in ["basic", "skill", "ultimate"]:
					var multiplier := 1.15 if id == PrototypeRelic.SWORD_PENDANT_ID and weapon == "sword" or id == PrototypeRelic.BOW_PENDANT_ID and weapon == "bow" else 1.3 if id == PrototypeRelic.LAST_SPARK_ID and health <= 30 and kind == "skill" else 1.25 if id == PrototypeRelic.BARRIER_LENS_ID and barrier > 0 and kind == "skill" else 1.0
					if not _check(player.growth_damage(100, weapon, kind) == roundi(100 * multiplier), "조건 경계·검/활·기본/스킬/필살기 구분"): return false
	player.damage_receiver.health = 80
	player.damage_receiver.barrier_health = 0
	player.damage_receiver.tick(2)
	var event := DamageEvent.new()
	event.event_id = &"expansion:incoming"
	event.damage = 20
	if not _check(player.receive_damage(event) == DamageReceiver.Result.APPLIED and player.damage_receiver.last_health_damage == (17 if id == PrototypeRelic.IRON_LEAF_ID else 20) and event.damage == 20, "실제 전투 피해·공유 이벤트 보존"): return false
	for kind in ["basic", "skill"]:
		player.damage_receiver.health = 30
		player.damage_receiver.barrier_health = 1
		var target := _combat_target("expansion:" + kind, player.global_position + Vector2(180, 0))
		ultimate.gauge = 0
		weapons.sword_combat._action_sequence += 1
		weapons.sword_combat._damage_target(target, &"sword_flurry" if kind == "skill" else &"sword_basic", 100, 0, PackedStringArray(["sword", kind]), 0)
		if not _check(target.damage_receiver.health == 1000 - player.growth_damage(100, "sword", kind) and ultimate.gauge == ultimate.weapon_hit_gauge_amount(kind == "skill"), "실제 적중 피해·종/프리즘 충전·중복 차단"): return false
		target.free()
	ultimate.gauge = 100
	ultimate.request_ultimate()
	var duration := ultimate._remaining_s
	ultimate.time_echo_unlocked = true
	ultimate.time_echo_boost_unlocked = true
	if not _check(duration == (4 if id == PrototypeRelic.DAWN_DIAL_ID else 3) and ultimate._remaining_s == duration and ultimate.duration_for({}) == duration + 2, "실제 시계판 감속·활성 시간 불변·다음 발동 여운 합산"): return false
	ultimate.finish_stage_effect()
	return true
