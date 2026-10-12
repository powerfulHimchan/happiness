extends "res://tests/gp171_174_runtime_test.gd"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var key := args[0] if not args.is_empty() else "charm"
	var phase := args[1] if args.size() > 1 else "seed"
	var id: String = {"charm": PrototypeRelic.CHARM_ID, "feather": PrototypeRelic.FEATHER_ID, "necklace": PrototypeRelic.NECKLACE_ID, "whistle": PrototypeRelic.WHISTLE_ID}.get(key, "")
	if not _check(not id.is_empty(), "유효한 검사 유물"): return
	BATCH_SAVE = "user://gp181_184_" + key + "_checkpoint.json"
	BATCH_META = "user://gp181_184_" + key + "_meta.jsonl"
	BATCH_RECORD = "user://gp181_184_" + key + "_record.jsonl"
	BATCH_BOOK = "user://gp181_184_" + key + "_book.jsonl"
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
			store.save_path = "user://gp181_184_missing/checkpoint.json"
			_tap(controls.relic_reward_confirm_rect.get_center())
			store.save_path = BATCH_SAVE
			if not _check(controls.current_screen_mode() == 15 and PrototypeRelic.OFFERS[controls.selected_relic_offer].id == id and _effect_snapshot() == before and store.load_checkpoint() == saved, "새 유물 실제 저장 실패·선택 보존·모든 효과/파일 롤백"): return
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(player.relic_state == {"id": id, "used": false} and controls.current_screen_mode() == 9 and not sandbox._claim_relic_reward(id), "둘째 페이지 실제 유물 확정·한 도전 하나"): return
			var after := _effect_snapshot()
			after.erase("relic")
			before.erase("relic")
			if not _check(after == before, "획득 즉시 체력·게이지·약·성장·원본 대기 불변"): return
			if id == PrototypeRelic.NECKLACE_ID:
				_tap(controls.stage_route_rects[0].get_center())
				player.damage_receiver.health = 1
				var target := _combat_target("necklace-save", player.global_position + Vector2(180, 0))
				target.add_to_group("combat_enemy")
				weapons.sword_combat._action_sequence += 1
				weapons.sword_combat._damage_target(target, &"sword_basic", 7, 0, PackedStringArray(["sword", "basic"]), 0)
				target.free()
				if not _check(player.lifesteal_progress == 7 and not growth.ranks.has("lifesteal"), "유물 단독 실제 타격·소수7 획득"): return
				if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "목걸이 소수 실제 다음 정예 저장"): return
				_set_timers()
				ultimate.gauge = 37
				if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK and store.load_checkpoint().player.lifesteal_progress == 7, "기본 흡수 능력 없이도 소수7 저장 허용"): return
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
			match id:
				PrototypeRelic.CHARM_ID:
					if not _charm_hits(): return
				PrototypeRelic.FEATHER_ID:
					if not _feather_hits(): return
				PrototypeRelic.NECKLACE_ID:
					if not _necklace_hits(): return
				PrototypeRelic.WHISTLE_ID:
					if not await _whistle_evade(): return
		_:
			_check(false, "알 수 없는 단계")
			return
	paused = false
	sandbox.free()
	print("GP-181–184 runtime test: OK · " + key + " · " + phase)
	quit(0)



func _test_derived_effect(id: String) -> bool:
	var low := player.is_crisis_health()
	var high := player.is_calm_health()
	return _check(is_equal_approx(player.incoming_damage_multiplier(), 0.8 if id == PrototypeRelic.CHARM_ID and low else 1.0) and player.basic_relic_multiplier("basic") == (1.25 if id == PrototypeRelic.FEATHER_ID and high else 1.0) and player.lifesteal_rate_percent() == (5 if id == PrototypeRelic.NECKLACE_ID else 0) and ultimate.precise_evade_gauge_amount() == (15 if id == PrototypeRelic.WHISTLE_ID else 12), "조건부 유물 현재 체력/흡수/회피 효과 독립 복원")

func _charm_hits() -> bool:
	player.damage_receiver.max_health = 100
	for health in [30, 31]:
		player.damage_receiver.health = health
		player.damage_receiver.barrier_health = 0
		player.damage_receiver.tick(2)
		var event := DamageEvent.new()
		event.event_id = StringName("charm:" + str(health))
		event.damage = 10
		if not _check(player.receive_damage(event) == DamageReceiver.Result.APPLIED and player.damage_receiver.health == health - (8 if health == 30 else 10) and event.damage == 10, "부적 실제30% 경계·공유 피해 불변"): return false
	player.survival_instinct_unlocked = true
	player.damage_receiver.health = 30
	player.damage_receiver.tick(2)
	var hit := DamageEvent.new()
	hit.event_id = &"charm:combined"
	hit.damage = 10
	player.receive_damage(hit)
	if not _check(player.damage_receiver.health == 23, "생존 본능0.9×부적0.8 최종반올림7"): return false
	var before := player.damage_receiver.health
	player.damage_receiver.apply_environmental_damage(10)
	return _check(player.damage_receiver.health == before - 10, "낙하 환경 피해 감소 제외")

func _feather_hits() -> bool:
	for node in get_nodes_in_group("targetable"): node.visible = false
	player.global_position = Vector2(1000, 780)
	player.facing_direction = 1
	player.damage_receiver.max_health = 100
	for health in [80, 79]:
		for weapon in ["sword", "bow"]:
			for kind in ["basic", "skill"]:
				player.damage_receiver.health = health
				var target := _combat_target("feather:%d:%s:%s" % [health, weapon, kind], player.global_position + Vector2(180, 0))
				if weapon == "sword":
					weapons.sword_combat._action_sequence += 1
					weapons.sword_combat._damage_target(target, &"sword_basic" if kind == "basic" else &"sword_revolve", 100, 0, PackedStringArray(["sword", kind]), 0)
				else:
					weapons.bow_combat._spawn_projectile("feather:%d:%s" % [health, kind], &"bow_basic", 100, 1, Vector2.RIGHT, PackedStringArray(["bow", kind]))
					var shot: BowProjectile = get_nodes_in_group("bow_projectile").back()
					shot.set_physics_process(false)
					shot._check_hits(shot.global_position, target.global_position + Vector2(0, -38))
					shot.free()
				if not _check(target.damage_receiver.health == 1000 - (125 if health == 80 and kind == "basic" else 100), "검/활 실제80% 경계 기본만1.25배"): return false
				target.free()
	return _check(player.growth_damage(100, "sword", "ultimate") == 100, "필살기 강화 제외")

func _necklace_hits() -> bool:
	player.prepare_next_stage(Vector2(1000, 780))
	player.damage_receiver.max_health = 100
	player.damage_receiver.health = 1
	var target := _combat_target("necklace-alone", player.global_position + Vector2(180, 0))
	target.add_to_group("combat_enemy")
	weapons.sword_combat._action_sequence += 1
	weapons.sword_combat._damage_target(target, &"sword_basic", 7, 0, PackedStringArray(["sword", "basic"]), 0)
	if not _check(player.lifesteal_progress == 7 and player.damage_receiver.health == 1, "목걸이 단독5% 소수 누적"): return false
	player.set_lifesteal_unlocked(true)
	player.set_lifesteal_branch("lifesteal_depth")
	player.healing_flow_unlocked = true
	weapons.sword_combat._action_sequence += 1
	weapons.sword_combat._damage_target(target, &"sword_basic", 7, 0, PackedStringArray(["sword", "basic"]), 0)
	if not _check(player.lifesteal_rate_percent() == 20 and player.damage_receiver.health == 2 and player.lifesteal_progress == 15, "흐름15%+목걸이5% · 기존7+28→회복1/소수15"): return false
	var before := player.damage_receiver.health
	weapons.sword_combat._damage_target(target, &"sword_basic", 7, 0, PackedStringArray(["sword", "basic"]), 0)
	if not _check(player.damage_receiver.health == before and player.lifesteal_progress == 15, "중복 타격 추가 흡수 차단"): return false
	paused = true
	weapons.sword_combat._action_sequence += 1
	weapons.sword_combat._damage_target(target, &"sword_basic", 7, 0, PackedStringArray(["sword", "basic"]), 0)
	paused = false
	if not _check(player.damage_receiver.health == before and player.lifesteal_progress == 15, "조회 중 추가 흡수 없음"): return false
	target.damage_receiver.health = 3
	weapons.sword_combat._action_sequence += 1
	weapons.sword_combat._damage_target(target, &"sword_basic", 9999, 0, PackedStringArray(["sword", "basic"]), 0)
	if not _check(player.damage_receiver.health == before + 1 and player.lifesteal_progress == 7, "과잉 피해 제외 · 실제3피해만 누적"): return false
	target.free()
	return true

func _whistle_evade() -> bool:
	player.prepare_next_stage(Vector2(960, 780))
	player.set_physics_process(true)
	for ignored in 8: await physics_frame
	player.set_physics_process(false)
	player._evade_cooldown_remaining_s = 0
	ultimate.gauge = 0
	player.set_move_vector(Vector2.RIGHT)
	var touch := InputEventScreenTouch.new()
	touch.index = 6
	touch.position = controls.action_rects[&"evade"].get_center()
	touch.pressed = true
	controls._input(touch)
	controls._physics_process(0.001)
	controls._handle_touch_released(6)
	if not _check(player.is_ground_evading() and ultimate.gauge == 0, "실제 회피 입력만으로 충전 없음"): return false
	var projectile := HOURGLASS_SEED.instantiate() as EnemySeedProjectile
	projectile.configure("whistle:precise", Vector2.LEFT, 7)
	sandbox.add_child(projectile)
	projectile.set_physics_process(false)
	var point := player.global_position + Vector2(0, -42)
	projectile._try_hit_player(point + Vector2(80, 0), point - Vector2(80, 0))
	projectile._try_hit_player(point + Vector2(80, 0), point - Vector2(80, 0))
	projectile.free()
	if not _check(ultimate.gauge == 15 and ultimate.precise_evade_count == 1 and controls.movement_metrics.ultimate_evade_gain == 15, "실제 투사체 정확회피15·중복 차단·HUD"): return false
	ultimate.grant_stage_gauge(20)
	return _check(ultimate.gauge == 35 and player.skill_recharge_multiplier() == 1.0, "경로 보상20·스킬 대기 유지")
