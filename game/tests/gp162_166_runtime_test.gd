extends "res://tests/gp155_runtime_test.gd"

var BATCH_SAVE: String
var BATCH_META: String
var BATCH_RECORD: String
var BATCH_BOOK: String
const NEW_IDS := [PrototypeRelic.SEAL_ID, PrototypeRelic.WIND_ID, PrototypeRelic.SEED_ID, PrototypeRelic.DUEL_ID]

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var key := args[0] if not args.is_empty() else "seal"
	var phase := args[1] if args.size() > 1 else "seed"
	var id: String = {"seal": PrototypeRelic.SEAL_ID, "wind": PrototypeRelic.WIND_ID, "seed": PrototypeRelic.SEED_ID, "duel": PrototypeRelic.DUEL_ID}.get(key, "")
	if not _check(not id.is_empty(), "유효한 검사 유물"): return
	BATCH_SAVE = "user://gp162_166_" + key + "_checkpoint.json"
	BATCH_META = "user://gp162_166_" + key + "_meta.jsonl"
	BATCH_RECORD = "user://gp162_166_" + key + "_record.jsonl"
	BATCH_BOOK = "user://gp162_166_" + key + "_book.jsonl"
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
			store.save_path = "user://gp162_166_missing/checkpoint.json"
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
				PrototypeRelic.SEAL_ID:
					if not _test_seal_hits(): return
				PrototypeRelic.WIND_ID:
					if not await _test_wind_evade(): return
				PrototypeRelic.SEED_ID:
					if not _test_seed_orbs(): return
				PrototypeRelic.DUEL_ID:
					if not _test_duel_attacks(): return
		_:
			_check(false, "알 수 없는 단계")
			return
	paused = false
	sandbox.free()
	print("GP-162–166 runtime test: OK · " + key + " · " + phase)
	quit(0)

func _files() -> Dictionary:
	var result := {}
	for path in [BATCH_SAVE, BATCH_SAVE + ".bak", BATCH_META, BATCH_RECORD, BATCH_BOOK]:
		result[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return result

func _effect_snapshot() -> Dictionary:
	return {"relic": player.relic_state.duplicate(), "health": player.damage_receiver.health, "potions": player.potions_remaining, "gauge": ultimate.gauge, "growth": growth.checkpoint_snapshot(), "timers": weapons.checkpoint_snapshot(), "evade_remaining": player._evade_cooldown_remaining_s}

func _open_new_relic(id: String) -> bool:
	_tap(controls.relic_reward_open_rect.get_center())
	if not _check(controls.relic_reward_page == 0 and controls.selected_relic_offer == 0, "진입은 첫 페이지·첫 카드"): return false
	_tap(controls.relic_reward_previous_rect.get_center())
	if not _check(controls.relic_reward_page == 0, "이전 첫 페이지 경계"): return false
	_tap(controls.relic_reward_next_rect.get_center())
	controls._refresh_relic_reward_layout()
	var index := NEW_IDS.find(id)
	_tap(controls.relic_reward_card_rects[index].get_center())
	if not _check(controls.relic_reward_page == 1 and controls.selected_relic_offer == 5 + index, "둘째 페이지 실제 터치·전체 인덱스 선택"): return false
	return _check(controls.relic_reward_page == 1 and controls.selected_relic_offer == 5 + index, "기존 둘째 페이지 선택 유지")

func _test_new_save(id: String) -> bool:
	var saved := store.load_checkpoint()
	if not _check(saved.relic == {"id": id, "used": false} and saved.ultimate.gauge == 37, "새 유물 ID·게이지 저장"): return false
	for value in [{"id": id, "used": true}, {"id": id, "used": 0}, {"id": id}, {"id": id, "used": false, "multiplier": 9}, {"id": "unknown", "used": false}]:
		var bad := saved.duplicate(true)
		bad.relic = value
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "변조 유물 거부·정상 파일 보호"): return false
	return _check(controls.movement_metrics.relic_hud == PrototypeRelic.hud(player.relic_state), "원본 유물 HUD 즉시 표시")

func _test_derived_effect(id: String) -> bool:
	return _check(is_equal_approx(player.incoming_damage_multiplier(), 0.9 if id == PrototypeRelic.SEAL_ID else 1.0) and is_equal_approx(player.ground_evade_cooldown_s(), 0.36 if id == PrototypeRelic.WIND_ID else 0.45) and player.recovery_orb_heal_percent() == (15 if id == PrototypeRelic.SEED_ID else 10) and player.growth_damage(100, "sword") == (120 if id == PrototypeRelic.DUEL_ID else 100) and player.growth_damage(100, "bow", "skill") == 100 and player.skill_recharge_multiplier() == 1.0 and player.combat_gauge_multiplier() == 1.0, "ID에서 효과 한 번 복원·다른 시스템 독립")

func _test_new_view(id: String) -> bool:
	var files := _files()
	var before := _effect_snapshot()
	if not _check(controls.open_run_build() and paused, "현재 도전 조회 정지"): return false
	var cards := PrototypeRunBuildView.cards(2, controls.run_build_state)
	if not _check(cards[3].lines[0] == PrototypeRelic.hud({"id": id, "used": false}) and cards[1].lines.has("회복 구슬 · 체력 %d%% (+%d)" % [player.recovery_orb_heal_percent(), player.recovery_orb_heal_amount()]), "도전 상태 실제 유물·구슬 회복량"): return false
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		for page in 2:
			controls.run_build_tab = 2
			controls.run_build_page = page
			var view: Dictionary = controls.run_build_snapshot()
			for rect in view.layout.cards:
				if not _check(controls.layout_snapshot().safe.encloses(rect), "두 화면비 현재 상태 안전 영역"): return false
			controls.queue_redraw()
			await process_frame
	if not _check(_effect_snapshot() == before and _files() == files, "정지 조회는 런 상태·파일 불변"): return false
	controls.close_run_build()
	controls._process(3.1)
	return _check(not paused, "카운트다운 뒤 재개")

func _test_seal_hits() -> bool:
	var receiver := player.damage_receiver
	player.set_barrier_unlocked(true)
	receiver.barrier_health = 7
	receiver.health = 100
	var event := DamageEvent.new()
	event.event_id = &"gp163:barrier"
	event.damage = 10
	event.stagger_s = 0.25
	event.tags = PackedStringArray(["enemy", "melee"])
	if not _check(player.receive_damage(event) == DamageReceiver.Result.APPLIED and event.damage == 10 and event.stagger_s == 0.25 and event.tags == PackedStringArray(["enemy", "melee"]) and receiver.last_absorbed_damage == 7 and receiver.last_health_damage == 2 and receiver.health == 98, "실제 피해10→9·방벽7 후체력2·공유 이벤트 보존"): return false
	if not _check(player.receive_damage(event) == DamageReceiver.Result.DUPLICATE_BLOCKED and receiver.health == 98 and receiver.barrier_health == 0, "동일 타격 중복은 방벽·체력 무변경"): return false
	event.event_id = &"gp163:invuln"
	if not _check(player.receive_damage(event) == DamageReceiver.Result.INVULNERABLE_BLOCKED and receiver.health == 98, "원래 피격 무적 유지"): return false
	receiver.tick(2)
	event.event_id = &"gp163:minimum"
	event.damage = 1
	if not _check(player.receive_damage(event) == DamageReceiver.Result.APPLIED and receiver.last_health_damage == 1, "최소 양수 피해1 유지"): return false
	player.boss_legacy = {"choice": "destroy"}
	for damage in [5, 10, 17, 55]:
		receiver.tick(2)
		receiver.health = 100
		event.event_id = StringName("gp163:destroy:" + str(damage))
		event.damage = damage
		if not _check(player.receive_damage(event) == DamageReceiver.Result.APPLIED and receiver.last_health_damage == roundi(damage * 1.1 * 0.9) and event.damage == damage, "파괴 핵·인장 곱한 뒤 한 번 반올림·원본 유지"): return false
	player.boss_legacy = {}
	receiver.tick(2)
	event.event_id = &"gp163:invalid"
	event.damage = 0
	if not _check(player.receive_damage(event) == DamageReceiver.Result.INVALID_EVENT and event.damage == 0, "잘못된 피해가 최소1로 바뀌지 않음"): return false
	receiver.health = 100
	if not _check(receiver.apply_environmental_damage(10) == 10 and receiver.health == 90, "환경 피해는 원래10"): return false
	event.event_id = &"gp163:death"
	event.damage = 9999
	return _check(player.receive_damage(event) == DamageReceiver.Result.APPLIED and receiver.dead and store.load_checkpoint().is_empty() and not legacy.phoenix_used(player.relic_run_id), "치명타 정상 사망·유물 부활 없음·저장 정리")

func _test_wind_evade() -> bool:
	player.global_position = Vector2(600, 800)
	player.velocity = Vector2.ZERO
	for ignored in 8:
		player._physics_process(1.0 / 60.0)
		await physics_frame
	if not _check(player.is_on_floor(), "실제 지상 회피 준비"): return false
	player._evade_cooldown_remaining_s = 0
	player._input_lock_remaining_s = 0
	controls._refresh_layout()
	_tap(controls.action_rects[&"evade"].get_center())
	controls._physics_process(0.001)
	controls._handle_touch_released(4)
	if not _check(player.is_ground_evading() and is_equal_approx(player._evade_cooldown_remaining_s, 0.36) and is_equal_approx(player._invincible_remaining_s, 0.18) and is_equal_approx(player._mobility_remaining_s, 0.24), "실제 모바일 회피 대기0.36·무적0.18·동작0.24"): return false
	var remaining := player._evade_cooldown_remaining_s
	player.set_nimble_evade_unlocked(true)
	if not _check(is_equal_approx(player.ground_evade_cooldown_s(), 0.288) and player._evade_cooldown_remaining_s == remaining, "민첩한 회피와0.8곱연산·이미 시작한 대기 보존"): return false
	player.prepare_next_stage(Vector2(600, 800))
	player._start_ground_evade()
	if not _check(is_equal_approx(player._evade_cooldown_remaining_s, 0.288), "다음 실제 회피에 새 대기 적용"): return false
	player.prepare_next_stage(Vector2(600, 800))
	player._start_air_dash()
	return _check(is_equal_approx(player._mobility_remaining_s, PrototypePlayer.AIR_DASH_DURATION_S) and player.skill_recharge_multiplier() == 1.0 and player.potion_heal_ratio() == 0.25, "공중 대시·스킬·회복약 독립")

func _test_seed_orbs() -> bool:
	var orbs: RecoveryOrbController = sandbox.get_node("RecoveryOrbController")
	orbs.set_physics_process(false)
	orbs.drop_chance = 1.0
	player.damage_receiver.max_health = 101
	player.damage_receiver.health = 1
	var potions := player.potions_remaining
	var gauge := ultimate.gauge
	if not _step_section(): return false
	var enemy: PrototypeTarget = runner._active_enemies[0]
	_defeat(enemy)
	_resolve_growth()
	if not _check(orbs.drops == 1 and orbs.orbs.size() == 1, " 실제 일반 적 처치·씨앗 구슬 생성"): return false
	player.global_position = orbs.orbs[0]
	player.damage_receiver.max_health = 101
	player.damage_receiver.health = 1
	orbs._physics_process(0.02)
	if not _check(player.damage_receiver.health == 17 and orbs.healed == 16 and orbs.collected == 1 and orbs.orbs.is_empty(), "현재 최대101·15%올림16 실제 획득·집계"): return false
	player.set_orb_magnet_unlocked(true)
	player.set_orb_vitality_unlocked(true)
	orbs.orbs.append(player.global_position + Vector2(150, 0))
	orbs._physics_process(0.02)
	if not _check(player.recovery_orb_heal_percent() == 25 and player.damage_receiver.health == 43 and orbs.healed == 42 and player.recovery_orb_pickup_radius() == 152, "구슬 강화20+5%p·자석152·25%올림26·실제집계"): return false
	orbs.orbs.append(player.global_position)
	var count := orbs.collected
	player.damage_receiver.health = 101
	orbs._physics_process(0.02)
	if not _check(orbs.collected == count and orbs.orbs.size() == 1, "만피 구슬 유지"): return false
	player.damage_receiver.health = 100
	if not _check(controls.open_run_build(), "실제 조회 잠금 준비"): return false
	orbs._physics_process(0.02)
	if not _check(player.damage_receiver.health == 100 and orbs.orbs.size() == 1, "조회 중 자동 획득 차단"): return false
	controls.close_run_build()
	controls._process(3.1)
	orbs._physics_process(0.02)
	return _check(player.damage_receiver.health == 101 and orbs.healed == 43 and player.potions_remaining == potions and ultimate.gauge == gauge and player.potion_heal_ratio() == 0.25, "재개 실제 체력 상한·실회복1·회복약/게이지 독립")

func _test_duel_attacks() -> bool:
	for target in get_nodes_in_group("targetable"): target.visible = false
	player.global_position = Vector2(1000, 780)
	player.facing_direction = 1
	player.growth_common_bonus = 0.10
	player.growth_sword_bonus = 0.20
	player.growth_bow_bonus = 0.30
	player.damage_receiver.health = 1
	player.set_lifesteal_unlocked(true)
	ultimate.gauge = 0
	var timers := _timers()
	for weapon in ["sword", "bow"]:
		for kind in ["basic", "skill"]:
			var target := _combat_target("gp166:" + weapon + kind, player.global_position + Vector2(160, 0))
			target.add_to_group("combat_enemy")
			var expected := (156 if weapon == "sword" else 168) if kind == "basic" else (130 if weapon == "sword" else 140)
			if weapon == "sword":
				weapons.sword_combat._action_sequence += 1
				weapons.sword_combat._damage_target(target, &"sword_basic" if kind == "basic" else &"sword_spin", 100, 0, PackedStringArray(["sword", kind]), 0)
			else:
				weapons.bow_combat._spawn_projectile("gp166:" + kind, &"bow_basic" if kind == "basic" else &"bow_burst", 100, 1, Vector2.RIGHT, PackedStringArray(["bow", kind]))
				var shot: BowProjectile = get_nodes_in_group("bow_projectile").back()
				shot.set_physics_process(false)
				shot._check_hits(shot.global_position, target.global_position + Vector2(0, -38))
				shot.free()
			if not _check(target.damage_receiver.health == 1000 - expected, "검·활 실제 기본만1.2배·성장뒤 적용·스킬 원래값"): return false
			target.free()
	if not _check(player.damage_receiver.health == 30 and player.lifesteal_progress == 14 and ultimate.gauge == 24 and _timers() == timers, "실제594피해·흡수29/소수14·게이지24·원본 대기 유지"): return false
	weapons.set_equipment({"sword": 1, "bow": 0})
	if not _check(player.growth_damage(100, "sword") == 179 and player.growth_damage(100, "sword", "skill") == 163, "희귀 장비 곱한 후 최종 반올림·기본/스킬 구분"): return false
	player.memory_id = "core_echo"
	player.boss_legacy = {"choice": "destroy"}
	if not _check(player.growth_damage(100, "sword", "skill") == 197 and player.growth_damage(100, "sword") == 197, "기억 스킬만·파괴 핵·기본 문장 각각 한 번"): return false
	player.memory_id = ""
	player.boss_legacy = {}
	weapons.set_equipment({"sword": 0, "bow": 0})
	for job in ["vanguard", "tracker"]:
		var target := _combat_target("gp166:ultimate:" + job, player.global_position + Vector2(150, 0))
		target.add_to_group("combat_enemy")
		ultimate.reset_ultimate()
		var profile: Dictionary = PrototypeJobRewards.ultimates_for(job)[0]
		if not _check(ultimate.select_job_ultimate(job, profile.id), "공격 필살기 선택"): return false
		ultimate.gauge = 100
		ultimate.request_ultimate()
		if not _check(target.damage_receiver.health == 1000 - (78 if job == "vanguard" else 63), "실제 검·활 공격 필살기는 문장 강화 제외"): return false
		ultimate.finish_stage_effect()
		target.free()
	return true
