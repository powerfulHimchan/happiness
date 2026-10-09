extends "res://tests/gp145_runtime_test.gd"

const GP147_SAVE := "user://gp147_checkpoint.json"
const GP147_META := "user://gp147_meta.jsonl"
const GP147_RECORD := "user://gp147_records.jsonl"
const GP147_BOOK := "user://gp147_abilities.jsonl"

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	store.save_path = GP147_SAVE
	legacy.save_path = GP147_META
	if phase == "seed" or phase.begins_with("combat") or phase == "flows":
		store.clear_checkpoint()
		for path in [GP147_META, GP147_RECORD, GP147_BOOK]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	var discoveries := AbilityDiscoveryStore.new()
	discoveries.save_path = GP147_BOOK
	sandbox.ability_discovery_store = discoveries
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP147_RECORD
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
	for actor in [player, weapons.sword_combat, weapons.bow_combat, ultimate]:
		actor.set_process(false)
		actor.set_physics_process(false)
	runner.set_process(false)
	weapons.set_physics_process(false)
	match phase:
		"seed":
			if not await _test_skill_codex(false, 1.0): return
			if not _check(PrototypeSkillRewards.SKILLS.size() == PrototypeSkillRewards.POOLS.sword.size() + PrototypeSkillRewards.POOLS.bow.size() and PrototypeSkillRewards.POOLS.sword.has("sword_wave") and PrototypeSkillRewards.POOLS.bow.has("bow_homing"), "전체 스킬·검 검기/활 후퇴 원본 보존"): return
			if not _check(PrototypeSkillRewards.CODEX_ORDER.size() == 16 and PrototypeSkillRewards.CODEX_ORDER.slice(14) == ["bow_homing", "sword_wave"] and PrototypeSkillRewards.POOLS.sword.size() == 8 and PrototypeSkillRewards.POOLS.bow.size() == 8, "양 무기8종·이전15종 도감 순서 보존"): return
			controls.begin_retry("sword", 5)
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "첫 정예 무기 유지"): return
			if not await _replace_mobility("sword_wave", 1, true): return
			if not _check(weapons.skills.sword[1] == "sword_wave" and weapons.sword_combat._skill_2_cooldown_s == 10, "실제 검기 슬롯2·원본10초 대기"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "둘째 정예 무기 유지"): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[1].get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(player.relic_state.get("id", "") == PrototypeRelic.CLOCK_ID, "실제 시계추 선택"): return
			if not await _replace_mobility("bow_homing", 0, true): return
			if not _check(weapons.skills.bow[0] == "bow_homing" and weapons.bow_combat._skill_1_cooldown_s == 9, "실제 추적 슬롯1·원본9초 대기"): return
			if not _test_mobility_save(): return
			if not await _test_skill_codex(true, 1.25): return
		"resume":
			if not _check(weapons.skills == PrototypeSkillRewards.defaults(), "복원 전 기본 스킬"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and runner.stage_number == 2 and runner.stage_limit == 5 and weapons.skills.sword[1] == "sword_wave" and weapons.skills.bow[0] == "bow_homing" and weapons.sword_combat._skill_2_cooldown_s == 10 and weapons.bow_combat._skill_1_cooldown_s == 9 and player.skill_recharge_multiplier() == 1.25, "별도 프로세스 반복 복원·양 슬롯/원본 대기/시계추/도전 길이 보존"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _test_cast_freeze("sword"): return
			if not await _test_cast_freeze("bow"): return
			while not runner.awaiting_boss_choice():
				if not _finish_stage(): return
				if runner.awaiting_boss_choice(): break
				if not _check(sandbox._claim_weapon_reward(""), "다음 정예 유지"): return
				_tap(controls.stage_route_rects[0].get_center())
			if not _check(store.load_checkpoint().weapons.skills.sword[1] == "sword_wave" and store.load_checkpoint().weapons.skills.bow[0] == "bow_homing", "5스테이지 보스 선택 대기에도 새 구성 저장"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and sandbox._resolve_boss_choice("rescue"), "별도 보스 선택 복원·완주"): return
			controls.begin_retry("bow", 3)
			if not _check(weapons.skills == PrototypeSkillRewards.defaults() and not player._combat_action_active and player._combat_horizontal_velocity_px == 0, "새 도전 기본 스킬·강제 이동 초기화"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 저장 준비"): return
			var old := store.load_checkpoint()
			old.weapons.erase("skills")
			old.stage.erase("skills_claimed")
			old.erase("relic")
			if not _check(store.save_checkpoint(old) == OK, "추가 필드 없는 이전 저장 생성"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and weapons.skills == PrototypeSkillRewards.defaults() and runner.skills_claimed, "이전 저장 기본 구성·새 기술 소급 지급 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 저장 둘째 정예"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("destroy"), "이전3단계 저장 완주"): return
		"combat-right", "combat-left":
			controls.begin_retry("sword")
			_configure_combat()
			if not _test_wave_hits(1 if phase.ends_with("right") else -1): return
			if not _test_wave_boundaries(1 if phase.ends_with("right") else -1): return
		"flows":
			controls.begin_retry("sword")
			_configure_combat()
			if not _test_wave_cancel_and_switch(): return
			if not _test_wave_damage_pipeline(): return
			if not await _test_cast_freeze("sword"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-147 runtime test: OK (" + phase + ")")
	quit(0)

func _files() -> Dictionary:
	var result := {}
	for path in [GP147_SAVE, GP147_SAVE + ".bak", GP147_META, GP147_RECORD, GP147_BOOK]:
		result[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return result

func _replace_mobility(id: String, slot: int, failure: bool) -> bool:
	_tap(controls.skill_reward_open_rect.get_center())
	var files := _files()
	if not await _test_candidates(): return false
	if not _check(_files() == files and PrototypeSkillRewards.offer_page_count(weapons.skills) == maxi(PrototypeSkillRewards.POOLS.sword.size(), PrototypeSkillRewards.POOLS.bow.size()) - 2, "순환 조회는 저장 무변경·미보유 전체 후보 비교"): return false
	for ignored in PrototypeSkillRewards.offer_page_count(weapons.skills):
		if id in _offer_ids(): break
		_tap(controls.skill_reward_cycle_rect.get_center())
	if not _check(id in _offer_ids(), "새 스킬 실제 후보 등장"): return false
	_select_offer(id, slot)
	var saved := store.load_checkpoint()
	var before := weapons.checkpoint_snapshot()
	if failure:
		store.save_path = "user://gp147_missing/checkpoint.json"
		_tap(controls.skill_reward_confirm_rect.get_center())
		store.save_path = GP147_SAVE
		if not _check(weapons.checkpoint_snapshot() == before and store.load_checkpoint() == saved and not runner.skills_claimed, "이동 스킬 교체 실패·슬롯/대기/정상 저장 롤백"): return false
	_tap(controls.skill_reward_confirm_rect.get_center())
	return _check(weapons.skills[PrototypeSkillRewards.weapon_for(id)][slot] == id and runner.skills_claimed, "실제 슬롯 비교·교체 확정")

func _test_mobility_save() -> bool:
	var saved := store.load_checkpoint()
	for weapon in ["sword", "bow"]:
		var bad := saved.duplicate(true)
		bad.weapons.skills[weapon][0] = "bow_homing" if weapon == "sword" else "sword_wave"
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "다른 무기 기술 저장 거부·정상 저장 보호"): return false
		bad = saved.duplicate(true)
		bad.weapons.skills[weapon] = ["sword_wave", "sword_wave"] if weapon == "sword" else ["bow_homing", "bow_homing"]
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "동일 기술 두 슬롯 저장 거부"): return false
	return true

func _configure_combat() -> void:
	for target in get_nodes_in_group("targetable"): target.visible = false
	player.growth_common_bonus = 0
	player.growth_sword_bonus = 0
	player.growth_bow_bonus = 0
	player.boss_legacy = {}
	player.memory_id = ""
	player.relic_state = {}
	weapons.set_equipment({"sword": 0, "bow": 0})
	weapons.set_skill_loadout({"sword": ["sword_wave", "sword_spin"], "bow": ["bow_homing", "bow_arrow_rain"]})
	weapons.bow_combat.target_selector.set_physics_process(false)

func _wave() -> SwordWave:
	var wave: SwordWave = get_nodes_in_group("sword_wave").back()
	wave.set_physics_process(false)
	return wave

func _test_wave_hits(direction: int) -> bool:
	var targets: Array[PrototypeTarget] = []
	# 트리 등록 순서는 먼 적부터다. 관통은 실제 경로의 가까운 적부터다.
	for distance in [540, 480, 320, 150]:
		targets.append(_combat_target("wave-%d" % distance, Vector2(1000 + direction * (58 + distance), 780)))
	var actor := weapons.sword_combat
	var before: int = actor.total_damage
	_begin_cast("sword", direction)
	if not _check(actor._skill_1_cooldown_s == 10 and not player._combat_move_allowed and not player._combat_turn_allowed and not player.invincible, "실제 검기 터치·10초 대기·이동/전환 잠금·무적 없음"): return false
	actor._update_skill_action(0.19)
	if not _check(get_nodes_in_group("sword_wave").is_empty(), "0.20초 전 검기 없음"): return false
	player.facing_direction = -direction
	actor._update_skill_action(0.02)
	var wave := _wave()
	if not _check(wave.direction == direction and wave.damage == 36 and wave.max_hits == 3 and wave.hit_radius_px == 60 and wave.max_distance_px == 600 and wave.origin == Vector2(1000 + direction * 58, 742), "원본 방향 고정·피해36·최대3·반경0.6m·경로6m"): return false
	wave._physics_process(1.0)
	if not _check(targets[0].damage_receiver.health == 1000 and targets.slice(1).all(func(t: PrototypeTarget) -> bool: return t.damage_receiver.health == 964) and wave._hit_count == 3 and actor.total_damage == before + 108 and wave._travelled_px == 600 and wave.is_queued_for_deletion(), "큰 프레임 실제 가까운3개체·합계108·6m 만료"): return false
	wave._check_hits()
	if not _check(actor.total_damage == before + 108 and targets[0].damage_receiver.health == 1000 and actor.current_metrics().projectile_fired_count == 1, "반복 판정 중복 피해/4개체 관통 없음·검 발사 지표"): return false
	wave.free()
	actor._update_skill_action(1.0)
	for target in targets: target.free()
	return _check(not player._combat_action_active and actor.projectile_fired_count == 1, "동작0.5초 종료·한 번 발사")

func _test_wave_boundaries(direction: int) -> bool:
	var actor := weapons.sword_combat
	var boundary := _combat_target("boundary", Vector2(1000 + direction * 88, 840))
	var high := _combat_target("high", Vector2(1000 + direction * 88, 840.01))
	var rear := _combat_target("rear", Vector2(1000 + direction * 57, 780))
	var far := _combat_target("far", Vector2(1000 + direction * 659, 780))
	var hidden := _combat_target("hidden", Vector2(1000 + direction * 100, 780))
	var dead := _combat_target("dead", Vector2(1000 + direction * 120, 780))
	hidden.visible = false
	dead.damage_receiver.dead = true
	_begin_cast("sword", direction)
	actor._update_skill_action(0.21)
	var wave := _wave()
	wave._physics_process(0.05)
	if not _check(boundary.damage_receiver.health == 964 and [high, rear, far, hidden, dead].all(func(t: PrototypeTarget) -> bool: return t.damage_receiver.health == 1000), "양방향 정확0.6m 경계 포함·높이/뒤/6m 밖/숨김/사망 제외"): return false
	wave._physics_process(0.20)
	high.global_position = Vector2(1000 + direction * 88, 780)
	wave._physics_process(0.05)
	if not _check(high.damage_receiver.health == 1000 and boundary.damage_receiver.health == 964, "지나간 경로로 들어온 적·동일 적 중복 피해 없음"): return false
	wave._physics_process(10.0)
	if not _check(wave._travelled_px == 600 and wave.is_queued_for_deletion() and far.damage_receiver.health == 1000, "무표적 큰 프레임6m 상한·범위 밖 피해 없음"): return false
	wave.free()
	actor._update_skill_action(1.0)
	for target in [boundary, high, rear, far, hidden, dead]: target.free()
	return true

func _test_wave_cancel_and_switch() -> bool:
	var actor := weapons.sword_combat
	for reason in ["evade", "hit", "switch"]:
		_begin_cast("sword")
		player.request_evade()
		if not _check(player._combat_action_active and not player.invincible, "0.12초 전 회피 취소 차단"): return false
		actor._update_skill_action(0.13)
		match reason:
			"evade": player.request_evade()
			"hit": _interrupt_cast("gp147")
			"switch":
				weapons.active_weapon_id = "bow"
				weapons._apply_active_weapon()
		actor._update_skill_action(1.0)
		if not _check(get_nodes_in_group("sword_wave").is_empty() and not player._combat_action_active and actor._skill_1_cooldown_s == 10, "발사 전 " + reason + " 취소·10초 대기 유지"): return false
	_begin_cast("sword")
	actor._update_skill_action(0.21)
	var wave := _wave()
	weapons.active_weapon_id = "bow"
	weapons._apply_active_weapon()
	ultimate._apply_enemy_time_scale(0.1)
	wave._physics_process(0.1)
	if not _check(wave._travelled_px == 120 and not wave.is_queued_for_deletion(), "발사 후 무기 전환 유지·적 감속에도 검기 속도12m/s"): return false
	ultimate._apply_enemy_time_scale(1.0)
	actor.prepare_next_stage()
	if not _check(wave.is_queued_for_deletion(), "단계 이동은 남은 검기 정리"): return false
	wave.free()
	for reason in ["사망", "낙하", "부활", "새 도전"]:
		_begin_cast("sword")
		actor._update_skill_action(0.21)
		wave = _wave()
		if reason == "새 도전": actor.reset_combat()
		else: actor._on_player_interrupted(reason)
		wave._physics_process(0.1)
		if not _check(wave.is_queued_for_deletion() and wave._travelled_px == 0, reason + " 이후 검기 정리·추가 피해 차단"): return false
		wave.free()
	player.relic_state = {"id": PrototypeRelic.CLOCK_ID, "used": false}
	actor.set_active(false)
	actor._skill_1_cooldown_s = 10
	actor._physics_process(8.0)
	return _check(is_zero_approx(actor._skill_1_cooldown_s) and PrototypeSkillRewards.lines("sword_wave", 1.25)[0].begins_with("재사용 8.0초"), "시계추 실제10→8초·조회 일치")

func _test_cast_freeze(weapon: String) -> bool:
	if weapon == "bow": return await super._test_cast_freeze(weapon)
	weapons.active_weapon_id = "sword"
	weapons._apply_active_weapon()
	player.prepare_next_stage(Vector2(1000, 780))
	player.damage_receiver.tick(1.0)
	var actor := weapons.sword_combat
	var slot: int = weapons.skills.sword.find("sword_wave")
	if not _check(slot >= 0, "실제 장착 슬롯의 검기 정지 검사"): return false
	if slot == 0: actor._skill_1_cooldown_s = 0
	else: actor._skill_2_cooldown_s = 0
	_press_skill(slot)
	actor._update_skill_action(0.21)
	var wave := _wave()
	wave.set_physics_process(true)
	actor.set_physics_process(true)
	var position := wave.global_position
	var elapsed: float = actor._action_elapsed_s
	var before := weapons.checkpoint_snapshot()
	var files := _files()
	if not _check(controls.open_run_build() and paused, "비행 중 실제 도전 상태 조회 정지"): return false
	await create_timer(0.12, true).timeout
	if not _check(wave.global_position == position and wave._travelled_px == 0 and actor._action_elapsed_s == elapsed and weapons.checkpoint_snapshot() == before, "실제 프레임 검기/동작/대기 정지"): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(2.9)
	if not _check(paused and wave.global_position == position, "복귀 카운트다운에도 검기 정지"): return false
	controls.advance_mode_timer_for_test(0.2)
	wave.set_physics_process(false)
	actor.set_physics_process(false)
	if not _check(not paused and _files() == files and weapons.checkpoint_snapshot() == before, "조회·복귀 저장 및 대기 무변경"): return false
	actor._update_skill_action(1.0)
	wave.free()
	return true

func _test_wave_damage_pipeline() -> bool:
	var actor := weapons.sword_combat
	var targets: Array[PrototypeTarget] = []
	for index in 4:
		var target := _combat_target("pipeline-%d" % index, Vector2(1150 + index * 120, 780))
		target.add_to_group("combat_enemy")
		targets.append(target)
	targets[0].damage_receiver._post_hit_remaining_s = 1.0
	player.growth_common_bonus = 0.10
	player.growth_sword_bonus = 0.20
	player.relic_state = {}
	player.set_lifesteal_unlocked(true)
	_begin_cast("sword")
	player.damage_receiver.health = player.damage_receiver.max_health - 20
	var health := player.damage_receiver.health
	ultimate.gauge = 0
	var before: int = actor.total_damage
	var count: int = actor.skill_hit_count
	actor._update_skill_action(0.21)
	var wave := _wave()
	if not _check(wave.damage == 47, "실제 공용10%·검20% 성장 피해47"): return false
	wave._physics_process(1.0)
	if not _check(targets[0].damage_receiver.health == 1000 and targets[0].damage_receiver.invulnerable_blocked_count == 1 and targets.slice(1).all(func(t: PrototypeTarget) -> bool: return t.damage_receiver.health == 953), "무적 차단은 관통 개체수 제외·뒤의3개체 실제47"): return false
	if not _check(actor.total_damage == before + 141 and actor.skill_hit_count == count + 3 and ultimate.gauge == 24 and player.damage_receiver.health == health + 7 and player.lifesteal_progress == 1, "검 스킬 집계·3회 게이지24·실제141피해 흡수7/잔량1"): return false
	var id := wave.projectile_id
	wave.free()
	actor._update_skill_action(1.0)
	for target in targets:
		target.damage_receiver.tick(1.0)
	_begin_cast("sword")
	actor._update_skill_action(0.21)
	wave = _wave()
	if not _check(wave.projectile_id != id, "다음 검기는 독립 공격ID"): return false
	wave._physics_process(0.1)
	if not _check(targets[0].damage_receiver.health == 953, "다음 검기에서 이전 무적 표적 다시 유효 명중"): return false
	wave.free()
	actor._update_skill_action(1.0)
	for target in targets: target.free()
	player.growth_common_bonus = 0
	player.growth_sword_bonus = 0
	player.set_lifesteal_unlocked(false)
	return true

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-147 failed: " + message)
		paused = false
		quit(1)
	return condition
