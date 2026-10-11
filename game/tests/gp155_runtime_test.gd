extends "res://tests/gp150_runtime_test.gd"

const GP155_SAVE := "user://gp155_checkpoint.json"
const GP155_META := "user://gp155_meta.jsonl"
const GP155_RECORD := "user://gp155_records.jsonl"
const GP155_BOOK := "user://gp155_abilities.jsonl"
const HOURGLASS_SEED := preload("res://scenes/combat/enemy_seed_projectile.tscn")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP155_SAVE
	legacy.save_path = GP155_META
	if phase in ["seed", "legacy-seed", "combat"]:
		store.clear_checkpoint()
		for path in [GP155_META, GP155_RECORD]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	var discoveries := AbilityDiscoveryStore.new()
	discoveries.save_path = GP155_BOOK
	if phase in ["seed", "legacy-seed", "combat"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(discoveries.save_path))
	sandbox.ability_discovery_store = discoveries
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP155_RECORD
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
			if not _check(not sandbox._claim_relic_reward(PrototypeRelic.HOURGLASS_ID) and ultimate.combat_gauge_amount(4) == 4, "보상 전 지급 차단·기존 기본4"): return
			if not _reach_relic_reward(): return
			var saved := store.load_checkpoint()
			if not await _test_relic_layout(): return
			if not _check(store.load_checkpoint() == saved and player.relic_state.is_empty(), "다섯 후보 비교·취소는 저장/유물 불변"): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[4].get_center())
			_set_timers()
			ultimate.gauge = 37
			var timers := weapons.checkpoint_snapshot()
			var health := player.damage_receiver.health
			var potions := player.potions_remaining
			var growth_state := growth.checkpoint_snapshot()
			store.save_path = "user://gp155_missing/checkpoint.json"
			_tap(controls.relic_reward_confirm_rect.get_center())
			store.save_path = GP155_SAVE
			if not _check(controls.current_screen_mode() == 15 and controls.selected_relic_offer == 4 and player.relic_state.is_empty() and ultimate.combat_gauge_amount(4) == 4 and ultimate.gauge == 37 and weapons.checkpoint_snapshot() == timers and store.load_checkpoint() == saved, "저장 실패·유물/획득 배율/게이지/대기/정상 파일 롤백"): return
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(player.relic_state == {"id": PrototypeRelic.HOURGLASS_ID, "used": false} and player.combat_gauge_multiplier() == 1.25 and controls.movement_metrics.relic_hud.contains("모래시계") and controls.movement_metrics.combat_gauge_multiplier == 1.25 and controls.movement_metrics.ultimate_basic_gain == 5, "실제 다섯째 카드·배율/HUD·보상 소비"): return
			if not _check(ultimate.gauge == 37 and player.damage_receiver.health == health and player.potions_remaining == potions and weapons.checkpoint_snapshot() == timers and growth.checkpoint_snapshot() == growth_state and not sandbox._claim_relic_reward(PrototypeRelic.CLOCK_ID), "획득은 기존 게이지/체력/약/성장/대기 보존·둘째 유물 거부"): return
			if not _test_hourglass_save() or not await _test_dew_text() or not await _test_village_codex(PrototypeRelic.HOURGLASS_ID, false): return
		"resume":
			if not _check(player.relic_state.is_empty() and ultimate.combat_gauge_amount(4) == 4, "재시작 첫 화면 자동 지급 없음"): return
			var saved := store.load_checkpoint()
			if not _check(legacy.spend_phoenix(String(saved.recorder.id)) == OK, "깃털 소비 저널 독립 준비"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and player.relic_state == saved.relic and player.combat_gauge_multiplier() == 1.25 and ultimate.gauge == 37 and player.damage_receiver.health == saved.player.health and player.potions_remaining == saved.player.potions_remaining and _weapon_matches(saved.weapons), "별도 프로세스 반복 복원·배율1회·게이지/체력/약/대기 유지"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _test_hourglass_view(): return
			if not _finish_to_boss() or not _check(runner.stage_number == 5 and store.load_checkpoint().relic.id == PrototypeRelic.HOURGLASS_ID, "5단계 최종 보스 저장도 유물 보존"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and player.combat_gauge_multiplier() == 1.25 and sandbox._resolve_boss_choice("rescue"), "최종 보스 선택 복원·완주"): return
			controls.use_boss_legacy = false
			controls.begin_retry("bow", 3)
			if not _check(player.relic_state.is_empty() and player.combat_gauge_multiplier() == 1.0 and ultimate.combat_gauge_amount(4) == 4 and ultimate.gauge == 0, "새 도전 배율/게이지 초기화"): return
		"legacy-seed":
			controls.begin_retry("bow", 3)
			if not _reach_relic_reward(): return
			var saved := store.load_checkpoint()
			saved.erase("relic")
			if not _check(store.save_checkpoint(saved) == OK, "유물 필드 없는 기존 저장 준비"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and player.relic_state.is_empty() and ultimate.combat_gauge_amount(4) == 4, "이전 저장은 기존 게이지·새 유물 자동 지급 없음"): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[1].get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(player.skill_recharge_multiplier() == 1.25 and player.combat_gauge_multiplier() == 1.0, "기존 시계추 대기 효과·게이지 배율 독립"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_to_boss() or not _check(sandbox._resolve_boss_choice("destroy"), "기존3단계 실제 완주"): return
		"combat":
			controls.begin_retry("sword", 3)
			if not _reach_relic_reward(): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[4].get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			_tap(controls.stage_route_rects[0].get_center())
			if not await _test_hourglass_combat(): return
		_:
			_check(false, "알 수 없는 단계")
			return
	paused = false
	sandbox.free()
	print("GP-155 runtime test: OK · " + phase)
	quit(0)

func _files() -> Dictionary:
	var result := {}
	for path in [GP155_SAVE, GP155_SAVE + ".bak", GP155_META, GP155_RECORD, GP155_BOOK]:
		result[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return result

func _test_hourglass_save() -> bool:
	var saved := store.load_checkpoint()
	if not _check(saved.relic == {"id": PrototypeRelic.HOURGLASS_ID, "used": false} and saved.ultimate.gauge == 37 and not saved.ultimate.has("gain_multiplier"), "유물 ID만 저장·게이지 유지·중복 배율 필드 없음"): return false
	for relic in [{"id": PrototypeRelic.HOURGLASS_ID, "used": true}, {"id": PrototypeRelic.HOURGLASS_ID, "used": 0}, {"id": PrototypeRelic.HOURGLASS_ID}, {"id": PrototypeRelic.HOURGLASS_ID, "used": false, "extra": 1}, {"id": "unknown", "used": false}]:
		var bad := saved.duplicate(true)
		bad.relic = relic
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "사용/타입/누락/추가/ID 변조 거부·정상 저장 보호"): return false
	return _check(PrototypeRelic.OFFERS.slice(0, 4).map(func(item: Dictionary) -> String: return item.id) == [PrototypeRelic.PHOENIX_ID, PrototypeRelic.CLOCK_ID, PrototypeRelic.DEW_ID, PrototypeRelic.EMBER_ID] and PrototypeRelic.OFFERS[4].id == PrototypeRelic.HOURGLASS_ID, "기존 네 유물 순서·다섯째 모래시계")

func _test_hourglass_view() -> bool:
	var files := _files()
	var before: Dictionary = sandbox._capture_run_build()
	if not _check(controls.open_run_build() and paused, "현재 도전 조회 실제 정지"): return false
	var cards := PrototypeRunBuildView.cards(2, controls.run_build_state)
	if not _check(cards[2].lines.has("게이지 기본5 · 스킬10 · 회피15") and cards[3].lines[0].contains("모래시계"), "현재 도전 실제 게이지 획득/유물 표시"): return false
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls.run_build_tab = 2
		controls.run_build_page = 0
		var view: Dictionary = controls.run_build_snapshot()
		for rect in view.layout.cards:
			if not _check(controls.layout_snapshot().safe.encloses(rect), "두 화면비 현재 도전 안전 영역"): return false
		controls.queue_redraw()
		await process_frame
	if not _check(sandbox._capture_run_build() == before and _files() == files, "조회는 효과/게이지/체력/대기/파일 무변경"): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(3.1)
	return _check(not paused and _files() == files, "3초 복귀·파일 보존")

func _test_hourglass_combat() -> bool:
	for target in get_nodes_in_group("targetable"): target.visible = false
	player.global_position = Vector2(1000, 780)
	player.facing_direction = 1
	player.growth_common_bonus = 0
	player.growth_sword_bonus = 0
	player.growth_bow_bonus = 0
	player.memory_id = ""
	player.boss_legacy = {}
	weapons.set_equipment({"sword": 0, "bow": 0})
	player.damage_receiver.max_health = 100
	player.damage_receiver.health = 1
	player.set_lifesteal_unlocked(true)
	ultimate.gauge = 0
	var timers := _timers()
	for weapon in ["sword", "bow"]:
		for kind in ["basic", "skill"]:
			var target := _combat_target("gp155:" + weapon + kind, player.global_position + Vector2(200, 0))
			target.add_to_group("combat_enemy")
			var before := ultimate.gauge
			if weapon == "sword":
				weapons.sword_combat._action_sequence += 1
				var attack: StringName = &"sword_basic" if kind == "basic" else &"sword_spin"
				var tags := PackedStringArray(["sword", kind])
				weapons.sword_combat._damage_target(target, attack, 100, 0, tags, 0)
				if not _check(weapons.sword_combat._damage_target(target, attack, 100, 0, tags, 0) == DamageReceiver.Result.DUPLICATE_BLOCKED, "실제 검 중복 타격 차단"): return false
			else:
				weapons.bow_combat._spawn_projectile("gp155:" + kind, &"bow_basic" if kind == "basic" else &"bow_piercing", 100, 1, Vector2.RIGHT, PackedStringArray(["bow", kind]))
				var shot: BowProjectile = get_nodes_in_group("bow_projectile").back()
				shot.set_physics_process(false)
				shot._check_hits(shot.global_position, target.global_position + Vector2(0, -38))
				shot._check_hits(shot.global_position, target.global_position + Vector2(0, -38))
				shot.free()
			if not _check(target.damage_receiver.health == 900 and ultimate.gauge == before + (10 if kind == "skill" else 5), "양 무기 실제 기본5/스킬10·중복 충전 없음·피해100 유지"): return false
			target.free()
	if not _check(ultimate.gauge == 30 and player.damage_receiver.health == 21 and _timers() == timers, "네 타격30·흡수20·양 대기 독립"): return false
	# 실제 지상 회피 입력과 적 투사체 충돌로 정확 회피를 판정한다.
	player.prepare_next_stage(Vector2(960, 780))
	player.set_physics_process(true)
	for ignored in 8: await physics_frame
	player.set_physics_process(false)
	player._evade_cooldown_remaining_s = 0
	player.set_move_vector(Vector2.RIGHT)
	var touch := InputEventScreenTouch.new()
	touch.index = 6
	touch.position = controls.action_rects[&"evade"].get_center()
	touch.pressed = true
	controls._input(touch)
	controls._physics_process(0.001)
	controls._handle_touch_released(6)
	if not _check(player.is_ground_evading() and ultimate.gauge == 30, "실제 회피 입력만으로 충전 없음"): return false
	var projectile := HOURGLASS_SEED.instantiate() as EnemySeedProjectile
	projectile.configure("gp155:precise", Vector2.LEFT, 7)
	sandbox.add_child(projectile)
	projectile.set_physics_process(false)
	var point := player.global_position + Vector2(0, -42)
	projectile._try_hit_player(point + Vector2(80, 0), point - Vector2(80, 0))
	projectile._try_hit_player(point + Vector2(80, 0), point - Vector2(80, 0))
	projectile.free()
	if not _check(ultimate.gauge == 45 and player.damage_receiver.health == 21 and ultimate.precise_evade_count == 1, "실제 정확 회피15·동일 투사체 중복 차단·체력 유지"): return false
	player._update_mobility_timers(1)
	var target := _combat_target("gp155:collector", player.global_position + Vector2(200, 0))
	target.add_to_group("combat_enemy")
	target.defeated.connect(growth._on_enemy_defeated)
	_defeat(target)
	if not _check(ultimate.gauge == 45, "시간 수집 미획득 처치는 추가 충전 없음"): return false
	if not _resolve_growth(): return false
	growth.ranks.time_collector = 1
	target.reset_target()
	_defeat(target)
	target.defeated.emit(target)
	if not _check(ultimate.gauge == 51, "실제 시간 수집 처치5×1.25 최종 반올림6·중복 없음"): return false
	if not _resolve_growth(): return false
	target.visible = false
	ultimate.grant_stage_gauge(20)
	if not _check(ultimate.gauge == 71, "경로 보상은20 그대로"): return false
	ultimate.gauge = 99
	ultimate.grant_defeat_gauge()
	if not _check(ultimate.gauge == 100, "획득 최대100 상한"): return false
	ultimate.request_ultimate()
	if not _check(ultimate._active and ultimate.gauge == 0 and ultimate._remaining_s == 3 and ultimate._active_profile.get("slow", 0.15) == 0.15, "공용 발동100 소비·3초/15%감속 유지"): return false
	var duration := ultimate._remaining_s
	target.reset_target()
	target.visible = true
	_defeat(target)
	if not _check(ultimate.gauge == 6 and ultimate._remaining_s == duration, "발동 중 처치6·지속시간 연장 없음"): return false
	if not _resolve_growth(): return false
	target.free()
	ultimate.gauge = 100
	ultimate.request_ultimate()
	if not _check(ultimate.activation_count == 1 and ultimate.gauge == 100, "발동 중 재사용·재소비 차단"): return false
	ultimate.finish_stage_effect()
	ultimate.force_emit_metrics()
	growth._emit_metrics()
	if not _check(controls._ultimate_hud_label().contains("처치 +6"), "시간 수집 HUD는 실제6 표시"): return false
	if not await _test_hourglass_view(): return false
	for profile in PrototypeJobRewards.ULTIMATES:
		ultimate.reset_ultimate()
		if not _check(ultimate.select_job_ultimate(profile.job, profile.id), "네 직업 필살기 원본 선택"): return false
		var burst: PrototypeTarget
		var burst_gain := 6 if int(profile.get("damage", 0)) > 0 else 0
		if burst_gain > 0:
			burst = _combat_target("gp155:burst:" + String(profile.id), player.global_position + Vector2(150, 0))
			burst.add_to_group("combat_enemy")
			burst.defeated.connect(growth._on_enemy_defeated)
			burst.damage_receiver.health = 1
		ultimate.gauge = 100
		player.damage_receiver.health = 1
		ultimate.request_ultimate()
		if not _check(ultimate.gauge == burst_gain and ultimate._remaining_s == float(profile.duration) and ultimate._active_profile.slow == profile.slow and player.damage_receiver.health == 1 + int(profile.get("heal", 0)), "직업 발동 소비/지속/감속/회복 원본·공격 필살기 실제 처치6"): return false
		if burst != null:
			if not _check(burst.damage_receiver.dead, "공격 필살기 실제 치명타"): return false
			burst.free()
		if not _resolve_growth(): return false
		ultimate.finish_stage_effect()
	ultimate.reset_ultimate()
	ultimate.time_echo_unlocked = true
	ultimate.gauge = 100
	ultimate.request_ultimate()
	if not _check(ultimate.gauge == 0 and ultimate._remaining_s == 4 and player.combat_gauge_multiplier() == 1.25, "시간의 여운4초와 모래시계 배율 독립"): return false
	ultimate.finish_stage_effect()
	player.damage_receiver.tick(2)
	_hit_player(9999, "hourglass-not-phoenix")
	return _check(player.damage_receiver.dead and not player.relic_state.used and not legacy.phoenix_used(player.relic_run_id) and store.load_checkpoint().is_empty(), "모래시계는 부활/소비 없음·정상 사망·저장 정리")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-155 failed: " + message)
		paused = false
		quit(1)
	return condition
