extends "res://tests/gp135_runtime_test.gd"

const GP150_SAVE := "user://gp150_checkpoint.json"
const GP150_META := "user://gp150_meta.jsonl"
const GP150_RECORD := "user://gp150_records.jsonl"
const GP150_BOOK := "user://gp150_abilities.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP150_SAVE
	legacy.save_path = GP150_META
	if phase in ["seed", "legacy-seed", "combat"]:
		store.clear_checkpoint()
		for path in [GP150_META, GP150_RECORD]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	var discoveries := AbilityDiscoveryStore.new()
	discoveries.save_path = GP150_BOOK
	if phase in ["seed", "legacy-seed", "combat"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(discoveries.save_path))
	sandbox.ability_discovery_store = discoveries
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP150_RECORD
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
	match phase:
		"seed":
			if not await _test_village_codex("", false): return
			controls.begin_retry("sword", 5)
			if not _check(not sandbox._claim_relic_reward(PrototypeRelic.EMBER_ID) and player.relic_damage_multiplier() == 1.0, "실제 보상 전 지급 차단"): return
			if not _reach_relic_reward(): return
			var saved := store.load_checkpoint()
			if not await _test_relic_layout(): return
			if not _check(player.relic_state.is_empty() and player.relic_damage_multiplier() == 1.0 and store.load_checkpoint() == saved, "네 후보 비교·취소·피해/저장 무변경"): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[3].get_center())
			_set_timers()
			var timers := weapons.checkpoint_snapshot()
			var health := player.damage_receiver.health
			var potions := player.potions_remaining
			var gauge := ultimate.gauge
			var growth_state := growth.checkpoint_snapshot()
			store.save_path = "user://gp150_missing/checkpoint.json"
			_tap(controls.relic_reward_confirm_rect.get_center())
			store.save_path = GP150_SAVE
			if not _check(controls.current_screen_mode() == 15 and controls.selected_relic_offer == 3 and player.relic_state.is_empty() and player.growth_damage(100, "sword") == 100 and weapons.checkpoint_snapshot() == timers and store.load_checkpoint() == saved, "불씨 저장 실패·피해/유물/대기/정상파일 원자적 롤백"): return
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(player.relic_state == {"id": PrototypeRelic.EMBER_ID, "used": false} and is_equal_approx(player.relic_damage_multiplier(), 1.1) and player.growth_damage(100, "sword") == 110 and player.growth_damage(100, "bow") == 110 and controls.movement_metrics.relic_hud.contains("여명의 불씨") and controls.movement_metrics.relic_damage_multiplier == player.relic_damage_multiplier(), "실제 네 번째 카드·양 무기110·HUD·보상소비"): return
			if not _check(player.damage_receiver.health == health and player.potions_remaining == potions and ultimate.gauge == gauge and weapons.checkpoint_snapshot() == timers and growth.checkpoint_snapshot() == growth_state and not sandbox._claim_relic_reward(PrototypeRelic.CLOCK_ID), "획득은 회복/보충/충전/성장/대기 무변경·둘째 유물 거부"): return
			if not _test_ember_save(): return
			if not await _test_dew_text() or not await _test_village_codex(PrototypeRelic.EMBER_ID, false): return
		"resume":
			if not _check(player.relic_state.is_empty() and player.relic_damage_multiplier() == 1.0, "재시작 첫 화면 자동 유물 지급 없음"): return
			var saved := store.load_checkpoint()
			if not _check(legacy.spend_phoenix(String(saved.recorder.id)) == OK, "같은 도전 깃털 소비 저널로 불씨 독립 확인"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and player.relic_state == saved.relic and player.growth_damage(100, "sword") == 110 and player.growth_damage(100, "bow") == 110 and player.damage_receiver.health == saved.player.health and player.potions_remaining == saved.player.potions_remaining and _weapon_matches(saved.weapons), "별도 프로세스 반복 복원·효과1회·체력/소진/양 대기 유지·깃털 소비 독립"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _test_ember_view(): return
			if not _finish_to_boss() or not _check(store.load_checkpoint().relic.id == PrototypeRelic.EMBER_ID and runner.stage_number == 5, "5단계 최종 보스 저장도 불씨 보존"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and is_equal_approx(player.relic_damage_multiplier(), 1.1) and sandbox._resolve_boss_choice("destroy"), "보스 선택 복원·불씨 도전 실제 파괴 완주"): return
			controls.use_boss_legacy = false
			controls.begin_retry("bow", 3)
			if not _check(player.relic_state.is_empty() and player.relic_damage_multiplier() == 1.0 and player.growth_damage(100, "bow") == 100, "새 도전 불씨 제거·이전 공격 배율 소급 없음"): return
		"legacy-seed":
			controls.begin_retry("bow", 3)
			if not _reach_relic_reward(): return
			var saved := store.load_checkpoint()
			saved.erase("relic")
			if not _check(store.save_checkpoint(saved) == OK, "유물 필드 없는 기존 저장 준비"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and player.relic_state.is_empty() and player.relic_damage_multiplier() == 1.0, "기존 저장 호환·새 유물 자동 지급 없음"): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[1].get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(player.relic_state.id == PrototypeRelic.CLOCK_ID and player.skill_recharge_multiplier() == 1.25 and player.relic_damage_multiplier() == 1.0, "기존 시계추 선택·대기20% 감소·피해 배율 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_to_boss() or not _check(sandbox._resolve_boss_choice("rescue"), "기존3단계 저장 실제 완주"): return
		"combat":
			controls.begin_retry("sword", 3)
			if not _reach_relic_reward(): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[3].get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			_tap(controls.stage_route_rects[0].get_center())
			if not _test_ember_combat(): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-150 runtime test: OK (" + phase + ")")
	quit(0)

func _resolve_growth() -> bool:
	for ignored in 12:
		if growth.awaiting_job_confirmation:
			_tap(controls.job_ultimate_rects[0].get_center())
			_tap(controls.job_confirm_rect.get_center())
		elif growth.choosing:
			growth.offered_cards = [PrototypeAbilityCodex.profile("vitality")]
			sandbox._on_growth_choices_requested(growth.offered_cards, growth.level, growth.rerolls_remaining)
			_tap(controls.growth_card_rects[0].get_center())
		else: return true
	return _check(false, "성장 선택 해소")

func _finish_to_boss() -> bool:
	while not runner.awaiting_boss_choice():
		if not _finish_stage(): return false
		if runner.awaiting_boss_choice(): break
		if not _check(sandbox._claim_weapon_reward(""), "실제 다음 정예 보상"): return false
		_tap(controls.stage_route_rects[0].get_center())
	return true

func _files() -> Dictionary:
	var result := {}
	for path in [GP150_SAVE, GP150_SAVE + ".bak", GP150_META, GP150_RECORD, GP150_BOOK]:
		result[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return result

func _weapon_matches(saved: Dictionary) -> bool:
	var actual := weapons.checkpoint_snapshot()
	if actual.active != saved.active or actual.skills != saved.skills or actual.blueprints != saved.blueprints: return false
	for weapon in ["sword", "bow"]:
		if int(actual.equipment[weapon]) != int(saved.equipment[weapon]): return false
		for field in PrototypeWeaponController.CHECKPOINT_FIELDS:
			if float(actual[weapon][field]) != float(saved[weapon][field]): return false
	return true

func _test_ember_save() -> bool:
	var saved := store.load_checkpoint()
	if not _check(saved.relic == {"id": PrototypeRelic.EMBER_ID, "used": false} and saved.player.common == 0 and saved.player.sword == 0 and saved.player.bow == 0, "유물 원본만 저장·성장 보너스에 복사하지 않음"): return false
	for relic in [{"id": PrototypeRelic.EMBER_ID, "used": true}, {"id": PrototypeRelic.EMBER_ID, "used": 0}, {"id": PrototypeRelic.EMBER_ID}, {"id": PrototypeRelic.EMBER_ID, "used": false, "extra": 1}, {"id": "unknown", "used": false}]:
		var bad := saved.duplicate(true)
		bad.relic = relic
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "불씨 사용/타입/누락/추가/ID 변조 거부·정상 파일 보호"): return false
	return _check(PrototypeRelic.OFFERS.size() == 4 and PrototypeRelic.OFFERS.slice(0, 3).map(func(item: Dictionary) -> String: return item.id) == [PrototypeRelic.PHOENIX_ID, PrototypeRelic.CLOCK_ID, PrototypeRelic.DEW_ID], "기존 세 유물 순서 유지·넷째 불씨 추가")

func _test_ember_view() -> bool:
	var files := _files()
	var health := player.damage_receiver.health
	var potions := player.potions_remaining
	if not _check(controls.open_run_build() and paused, "실제 현재 도전 상태 조회"): return false
	var weapons_view := PrototypeRunBuildView.cards(1, controls.run_build_state)
	var overview := PrototypeRunBuildView.cards(2, controls.run_build_state)
	if not _check(weapons_view[0].lines[3] == "기본 피해100 기준 110" and weapons_view[1].lines[4] == "스킬 피해100 기준 110" and overview[3].lines[0].contains("여명의 불씨"), "현재 도전의 양 무기 실제 합산 피해와 불씨 보유 표시"): return false
	if not _check(not sandbox._use_recovery_potion(), "조회 중 회복약 차단"): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(3.1)
	return _check(not paused and _files() == files and player.damage_receiver.health == health and player.potions_remaining == potions and is_equal_approx(player.relic_damage_multiplier(), 1.1), "조회/복귀는 유물/잔량/저장 무변경")

func _timers() -> Array[float]:
	var values: Array[float] = []
	for actor in [weapons.sword_combat, weapons.bow_combat]:
		for field in ["_basic_remaining_s", "_skill_1_cooldown_s", "_skill_2_cooldown_s"]:
			values.append(float(actor.get(field)))
	return values

func _test_ember_combat() -> bool:
	for target in get_nodes_in_group("targetable"): target.visible = false
	player.global_position = Vector2(1000, 780)
	player.facing_direction = 1
	player.growth_common_bonus = 0.10
	player.growth_sword_bonus = 0.20
	player.growth_bow_bonus = 0.30
	player.memory_id = ""
	player.boss_legacy = {}
	weapons.set_equipment({"sword": 0, "bow": 0})
	player.damage_receiver.max_health = 100
	player.damage_receiver.health = 1
	player.set_lifesteal_unlocked(true)
	ultimate.gauge = 0
	var timers := _timers()
	var xp := growth.total_experience
	for weapon in ["sword", "bow"]:
		for kind in ["basic", "skill"]:
			var target := _combat_target("gp150:" + weapon + kind, player.global_position + Vector2(200, 0))
			target.add_to_group("combat_enemy")
			var expected := 143 if weapon == "sword" else 154
			if weapon == "sword":
				weapons.sword_combat._action_sequence += 1
				var attack: StringName = &"sword_basic" if kind == "basic" else &"sword_spin"
				var tags := PackedStringArray(["sword", kind])
				weapons.sword_combat._damage_target(target, attack, 100, 0, tags, 0)
				var gauge := ultimate.gauge
				if not _check(weapons.sword_combat._damage_target(target, attack, 100, 0, tags, 0) == DamageReceiver.Result.DUPLICATE_BLOCKED and ultimate.gauge == gauge, "중복 검 타격은 피해/게이지/흡수 중복 없음"): return false
			else:
				weapons.bow_combat._spawn_projectile("gp150:" + kind, &"bow_basic" if kind == "basic" else &"bow_piercing", 100, 1, Vector2.RIGHT, PackedStringArray(["bow", kind]))
				var shot: BowProjectile = get_nodes_in_group("bow_projectile").back()
				shot.set_physics_process(false)
				if not _check(shot.damage == expected, "발사 시 불씨·활 성장 피해 고정"): return false
				shot._check_hits(shot.global_position, target.global_position + Vector2(0, -38))
				var gauge := ultimate.gauge
				shot._check_hits(shot.global_position, target.global_position + Vector2(0, -38))
				if not _check(ultimate.gauge == gauge, "같은 투사체 중복은 추가 게이지 없음"): return false
				shot.free()
			if not _check(target.damage_receiver.health == 1000 - expected, "공용10%·검20%/활30%·불씨1.1배 실제 기본/스킬143/154"): return false
			target.free()
	if not _check(ultimate.gauge == 24 and player.damage_receiver.health == 30 and player.lifesteal_progress == 14 and growth.total_experience == xp and _timers() == timers, "실제594 피해 흡수29·소수14·기존게이지24·경험치/양 대기 독립"): return false
	weapons.set_equipment({"sword": 1, "bow": 0})
	if not _check(player.growth_damage(100, "sword") == 164 and player.growth_damage(100, "sword", "skill") == 179, "성장/장비/불씨 곱한 뒤 한 번 반올림·149.5를 먼저150으로 반올림하지 않음"): return false
	player.memory_id = "core_echo"
	player.boss_legacy = {"choice": "destroy"}
	if not _check(player.growth_damage(100, "sword", "skill") == 216, "기억10%/일회파괴10%/성장/장비/불씨 각각 한 번 적용"): return false
	player.memory_id = ""
	player.boss_legacy = {}
	weapons.set_equipment({"sword": 0, "bow": 0})
	for job in ["vanguard", "tracker"]:
		var target := _combat_target("gp150:ultimate:" + job, player.global_position + Vector2(150, 0))
		target.add_to_group("combat_enemy")
		ultimate.reset_ultimate()
		var profile: Dictionary = PrototypeJobRewards.ultimates_for(job)[0]
		if not _check(ultimate.select_job_ultimate(job, profile.id), "실제 공격형 필살기 원본 선택"): return false
		ultimate.gauge = 100
		var health := player.damage_receiver.health
		ultimate.request_ultimate()
		if not _check(target.damage_receiver.health == 1000 - (86 if job == "vanguard" else 69) and ultimate._active and ultimate.gauge == 0 and ultimate._remaining_s == 3.0 and ultimate._active_profile.slow == 0.15 and player.damage_receiver.health == health, "공격형 검86/활69 실제 피해·3초/15%감속·게이지/흡수 독립"): return false
		ultimate.finish_stage_effect()
		target.free()
	for job in ["vanguard", "tracker"]:
		ultimate.reset_ultimate()
		var profile: Dictionary = PrototypeJobRewards.ultimates_for(job)[1]
		if not _check(ultimate.select_job_ultimate(job, profile.id), "실제 회복형 필살기 원본 선택"): return false
		ultimate.gauge = 100
		player.damage_receiver.health = 1
		ultimate.request_ultimate()
		if not _check(player.damage_receiver.health == (41 if job == "vanguard" else 31) and ultimate._remaining_s == 5.0 and ultimate._active_profile.slow == (0.35 if job == "vanguard" else 0.25), "회복형40/30·5초·원래 감속 유지"): return false
		ultimate.finish_stage_effect()
	player.damage_receiver.health = 1
	_press_dew_potion()
	if not _check(player.damage_receiver.health == 26 and is_equal_approx(player.potion_heal_ratio(), 0.25) and player.skill_recharge_multiplier() == 1.0 and player.ground_evade_cooldown_s() == 0.45, "회복약25%·스킬/회피 대기 독립"): return false
	player.damage_receiver.health = 100
	player.damage_receiver.tick(2)
	_hit_player(10, "ember-incoming")
	if not _check(player.damage_receiver.health == 90, "불씨는 들어오는 피해10 유지"): return false
	player.damage_receiver.tick(2)
	_hit_player(9999, "ember-not-phoenix")
	return _check(player.damage_receiver.dead and not player.relic_state.used and not legacy.phoenix_used(player.relic_run_id) and store.load_checkpoint().is_empty(), "불씨는 부활/소비 없음·정상 사망·저장 정리")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-150 failed: " + message)
		paused = false
		quit(1)
	return condition
