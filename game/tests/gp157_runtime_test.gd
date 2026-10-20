extends "res://tests/gp145_runtime_test.gd"

const GP157_SAVE := "user://gp157_checkpoint.json"
const GP157_META := "user://gp157_meta.jsonl"
const GP157_RECORD := "user://gp157_records.jsonl"
const GP157_BOOK := "user://gp157_abilities.jsonl"

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	store.save_path = GP157_SAVE
	legacy.save_path = GP157_META
	if phase == "seed" or phase.begins_with("combat") or phase == "flows":
		store.clear_checkpoint()
		for path in [GP157_META, GP157_RECORD, GP157_BOOK]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	var discoveries := AbilityDiscoveryStore.new()
	discoveries.save_path = GP157_BOOK
	sandbox.ability_discovery_store = discoveries
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP157_RECORD
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
	growth.jobs_enabled = false
	for enemy in runner._all_combat_enemies():
		enemy.set_process(false)
		enemy.set_physics_process(false)
	match phase:
		"seed":
			if not await _test_skill_codex(false, 1.0): return
			if not _check(PrototypeSkillRewards.SKILLS.size() == PrototypeSkillRewards.POOLS.sword.size() + PrototypeSkillRewards.POOLS.bow.size() + PrototypeSkillRewards.FIST_POOL.size() and PrototypeSkillRewards.POOLS.sword.has("sword_charge") and PrototypeSkillRewards.POOLS.bow.has("bow_ricochet"), "전체 스킬·검 돌파/활 후퇴 원본 보존"): return
			controls.begin_retry("sword", 5)
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "첫 정예 무기 유지"): return
			if not await _replace_mobility("sword_charge", 1, true): return
			if not _check(weapons.skills.sword[1] == "sword_charge" and weapons.sword_combat._skill_2_cooldown_s == 9, "실제 돌파 슬롯2·원본9초 대기"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "둘째 정예 무기 유지"): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[1].get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(player.relic_state.get("id", "") == PrototypeRelic.CLOCK_ID, "실제 시계추 선택"): return
			if not await _replace_mobility("bow_ricochet", 0, true): return
			if not _check(weapons.skills.bow[0] == "bow_ricochet" and weapons.bow_combat._skill_1_cooldown_s == 10, "실제 도탄 슬롯1·원본10초 대기"): return
			if not _test_mobility_save(): return
			if not await _test_skill_codex(true, 1.25): return
		"resume":
			if not _check(weapons.skills == PrototypeSkillRewards.defaults(), "복원 전 기본 스킬"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and runner.stage_number == 2 and runner.stage_limit == 5 and weapons.skills.sword[1] == "sword_charge" and weapons.skills.bow[0] == "bow_ricochet" and weapons.sword_combat._skill_2_cooldown_s == 9 and weapons.bow_combat._skill_1_cooldown_s == 10 and player.skill_recharge_multiplier() == 1.25, "별도 프로세스 반복 복원·양 슬롯/원본 대기/시계추/도전 길이 보존"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _test_cast_freeze("sword"): return
			if not await _test_cast_freeze("bow"): return
			var stale := _fire()
			while not runner.awaiting_boss_choice():
				if not _finish_stage(): return
				if runner.awaiting_boss_choice(): break
				if not _check(sandbox._claim_weapon_reward(""), "다음 정예 유지"): return
				_tap(controls.stage_route_rects[0].get_center())
				if not _check(not is_instance_valid(stale) and get_nodes_in_group("bow_projectile").is_empty(), "실제 다음 스테이지 전환은 남은 도탄 화살 정리"): return
			if not _check(store.load_checkpoint().weapons.skills.sword[1] == "sword_charge" and store.load_checkpoint().weapons.skills.bow[0] == "bow_ricochet", "5스테이지 보스 선택 대기에도 새 구성 저장"): return
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
			controls.begin_retry("bow")
			_configure_combat()
			if not _test_ricochet(1 if phase.ends_with("right") else -1): return
			if not _test_ricochet_limits(): return
		"flows":
			controls.begin_retry("bow")
			_configure_combat()
			if not _test_cancel_and_switch() or not _test_damage_pipeline(): return
			if not await _test_cast_freeze("bow"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-157 runtime test: OK (" + phase + ")")
	quit(0)

func _files() -> Dictionary:
	var result := {}
	for path in [GP157_SAVE, GP157_SAVE + ".bak", GP157_META, GP157_RECORD, GP157_BOOK]:
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
		store.save_path = "user://gp157_missing/checkpoint.json"
		_tap(controls.skill_reward_confirm_rect.get_center())
		store.save_path = GP157_SAVE
		if not _check(weapons.checkpoint_snapshot() == before and store.load_checkpoint() == saved and not runner.skills_claimed, "이동 스킬 교체 실패·슬롯/대기/정상 저장 롤백"): return false
	_tap(controls.skill_reward_confirm_rect.get_center())
	return _check(weapons.skills[PrototypeSkillRewards.weapon_for(id)][slot] == id and runner.skills_claimed, "실제 슬롯 비교·교체 확정")

func _test_mobility_save() -> bool:
	var saved := store.load_checkpoint()
	for weapon in ["sword", "bow"]:
		var bad := saved.duplicate(true)
		bad.weapons.skills[weapon][0] = "bow_ricochet" if weapon == "sword" else "sword_charge"
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "다른 무기 기술 저장 거부·정상 저장 보호"): return false
		bad = saved.duplicate(true)
		bad.weapons.skills[weapon] = ["sword_charge", "sword_charge"] if weapon == "sword" else ["bow_ricochet", "bow_ricochet"]
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
	weapons.set_skill_loadout({"sword": ["sword_charge", "sword_spin"], "bow": ["bow_ricochet", "bow_arrow_rain"]})
	weapons.bow_combat.target_selector.set_physics_process(false)

func _ricochet_target(key: String, point: Vector2) -> PrototypeTarget:
	var target := _combat_target("gp157:" + key, point)
	target.add_to_group("combat_enemy")
	target.damage_receiver.post_hit_invulnerability_s = 0
	return target

func _fire(direction: int = 1) -> RicochetArrow:
	_begin_cast("bow", direction)
	weapons.bow_combat._update_skill_action(0.17)
	return _shot() as RicochetArrow

func _test_ricochet(facing: int) -> bool:
	# 먼 적을 먼저 등록해도 첫 명중은 비행 경로의 가까운 적이다.
	var far := _ricochet_target("far", Vector2(1000 + facing * 660, 780))
	var second := _ricochet_target("second", Vector2(1000 + facing * 420, 660))
	var first := _ricochet_target("first", Vector2(1000 + facing * 320, 780))
	var behind := _ricochet_target("rear", Vector2(1000 - facing * 200, 780))
	var actor := weapons.bow_combat
	ultimate.gauge = 0
	var hits := actor.skill_hit_count
	_begin_cast("bow", facing)
	actor._update_skill_action(0.15)
	if not _check(get_nodes_in_group("bow_projectile").is_empty() and actor._skill_1_cooldown_s == 10 and player._combat_move_allowed and not player._combat_turn_allowed and not player.invincible, "실제 입력·10초 대기·0.16초 전 발사 없음·이동 허용/시선 고정"): return false
	player.facing_direction = -facing
	actor._update_skill_action(0.02)
	var shot := _shot() as RicochetArrow
	if not _check(shot != null and shot.damage == 48 and shot.ricochet_damage == 32 and shot.direction == Vector2(facing, 0) and shot.global_position.x == 1000 + facing * 58 and shot.arrow_sprite.modulate == Color("ffb347"), "시전 방향/출발 위치 고정·단발48/도탄32·금색 화살"): return false
	shot._physics_process(1.0)
	if not _check(first.damage_receiver.health == 952 and second.damage_receiver.health == 1000 and far.damage_receiver.health == 1000 and shot._hit_count == 1 and shot._locked_target() == second and shot.damage == 32 and shot.max_distance_px == 300 and shot.arrow_sprite.modulate == Color("ff7b72"), "실제 첫48·가까운 두 번째 표적 고정·첫 경로 관통 없음·도탄3m"): return false
	# 고정 이후 경로에 다른 적이 나타나도 재지정하거나 추가 관통하지 않는다.
	var collateral := _ricochet_target("collateral", shot.global_position + shot.direction * 40 - PrototypeTarget.BODY_CENTER)
	for ignored in 100:
		if shot.is_queued_for_deletion(): break
		shot._physics_process(0.01)
	shot._check_hits(first.global_position, far.global_position)
	if not _check(second.damage_receiver.health == 968 and collateral.damage_receiver.health == 1000 and behind.damage_receiver.health == 1000 and first.damage_receiver.health == 952 and shot._hit_count == 2 and shot.is_queued_for_deletion() and actor.skill_hit_count == hits + 2 and ultimate.gauge == 16, "실제 두 번째32·총2적중/게이지16·중복/세 번째/재타격 없음"): return false
	shot.free()
	actor._update_skill_action(1.0)
	for target in [first, second, far, behind, collateral]: target.free()
	return true

func _test_ricochet_limits() -> bool:
	var actor := weapons.bow_combat
	for distance in [299.9, 300.0, 300.1]:
		var first := _ricochet_target("boundary-first", Vector2(1300, 780))
		var second := _ricochet_target("boundary", Vector2(1300 + distance, 770))
		var shot := _fire()
		shot._physics_process(1.0)
		if not _check((shot._locked_target() == second) == (distance <= 300.0), "3m 도탄 경계 포함·경계 밖 제외"): return false
		shot._physics_process(1.0)
		if not _check(second.damage_receiver.health == (968 if distance <= 300.0 else 1000), "정확한 거리 경계의 실제 도탄 피해"): return false
		shot.free()
		actor._update_skill_action(1.0)
		first.free()
		second.free()
	for reason in ["hidden", "dead", "offscreen", "far", "practice"]:
		var first := _ricochet_target("first:" + reason, Vector2(1300, 780))
		var second := _ricochet_target(reason, Vector2(1500, 780))
		match reason:
			"hidden": second.visible = false
			"dead": second.damage_receiver.dead = true
			"offscreen": second.global_position.y = -2000
			"far": second.global_position.x = 1900
			"practice": second.remove_from_group("combat_enemy")
		var before := second.damage_receiver.health
		var shot := _fire()
		shot._physics_process(1.0)
		if not _check(first.damage_receiver.health == 952 and second.damage_receiver.health == before and shot._hit_count == 1 and shot.is_queued_for_deletion(), "숨김/사망/화면 밖/3m 밖/연습 표적 도탄 후보 제외"): return false
		shot.free()
		actor._update_skill_action(1.0)
		first.free()
		second.free()
	for reason in ["hidden", "dead", "offscreen", "respawn", "freed"]:
		var first := _ricochet_target("first-loss", Vector2(1300, 780))
		var second := _ricochet_target(reason, Vector2(1420, 660))
		var shot := _fire()
		shot._physics_process(1.0)
		if not _check(shot._locked_target() == second, "도탄 생명 고정 준비"): return false
		match reason:
			"hidden": second.visible = false
			"dead": second.damage_receiver.dead = true
			"offscreen": second.global_position.y = -2000
			"respawn": second.reset_target()
			"freed": second.free()
		var replacement := _ricochet_target("replacement", shot.global_position + shot.direction * 60 - PrototypeTarget.BODY_CENTER)
		first.reset_target()
		shot._physics_process(1.0)
		if not _check(shot.is_queued_for_deletion() and shot._hit_count == 1 and replacement.damage_receiver.health == 1000 and first.damage_receiver.health == 1000, "고정 표적 상실·재생성/대체/첫 적 재타격 없이 만료"): return false
		shot.free()
		actor._update_skill_action(1.0)
		first.free()
		if is_instance_valid(second): second.free()
		replacement.free()
	var first := _ricochet_target("blocked", Vector2(1300, 780))
	first.damage_receiver._post_hit_remaining_s = 1.0
	var second := _ricochet_target("blocked-next", Vector2(1420, 660))
	var shot := _fire()
	var gauge := ultimate.gauge
	shot._physics_process(1.0)
	if not _check(shot.is_queued_for_deletion() and shot._hit_count == 0 and first.damage_receiver.health == 1000 and second.damage_receiver.health == 1000 and ultimate.gauge == gauge, "실제 피해 없는 첫 충돌은 도탄/충전 없음"): return false
	shot.free()
	first.free()
	second.free()
	actor._update_skill_action(1.0)
	shot = _fire()
	var start := shot.global_position
	shot._physics_process(10.0)
	if not _check(shot.is_queued_for_deletion() and shot._hit_count == 0 and shot._travelled_px == 800 and shot.global_position.distance_to(start) == 800, "무표적 큰 프레임도 첫 비행8m 상한"): return false
	shot.free()
	actor._update_skill_action(1.0)
	first = _ricochet_target("fixed-first", Vector2(1300, 780))
	second = _ricochet_target("fixed-next", Vector2(1420, 660))
	shot = _fire()
	shot._physics_process(1.0)
	var heading := shot.direction
	second.global_position.y += 220
	shot._physics_process(10.0)
	if not _check(shot.direction == heading and shot.is_queued_for_deletion() and shot._hit_count == 1 and second.damage_receiver.health == 1000 and shot._travelled_px == 300, "도탄은 고정 방향·이동 표적 재추적 없음·3m 만료"): return false
	shot.free()
	first.free()
	second.free()
	actor._update_skill_action(1.0)
	return true

func _test_cancel_and_switch() -> bool:
	var actor := weapons.bow_combat
	for reason in ["evade", "hit", "switch"]:
		_begin_cast("bow")
		player.request_evade()
		if not _check(player._combat_action_active and not player.invincible, "0.08초 전 회피 취소 차단"): return false
		actor._update_skill_action(0.09)
		match reason:
			"evade": player.request_evade()
			"hit": _interrupt_cast("ricochet")
			"switch":
				weapons.active_weapon_id = "sword"
				weapons._apply_active_weapon()
		actor._update_skill_action(1.0)
		if not _check(get_nodes_in_group("bow_projectile").is_empty() and not player._combat_action_active and actor._skill_1_cooldown_s == 10, "발사 전 회피/피격/전환 취소·10초 보존"): return false
	var shot := _fire()
	weapons.active_weapon_id = "sword"
	weapons._apply_active_weapon()
	ultimate._apply_enemy_time_scale(0.1)
	var start := shot.global_position
	shot._physics_process(0.1)
	if not _check(is_equal_approx(shot.global_position.distance_to(start), shot.speed_px_s * 0.1), "발사 후 전환 화살 유지·적 감속은 플레이어 화살 속도 불변"): return false
	ultimate._apply_enemy_time_scale(1.0)
	shot.free()
	player.relic_state = {"id": PrototypeRelic.CLOCK_ID, "used": false}
	actor.set_active(false)
	actor._skill_1_cooldown_s = 10
	actor._physics_process(8)
	return _check(is_zero_approx(actor._skill_1_cooldown_s) and PrototypeSkillRewards.lines("bow_ricochet", 1.25)[0].begins_with("재사용 8.0초"), "시계추10→8초·원본 대기와 도감 일치")

func _test_damage_pipeline() -> bool:
	player.relic_state = {"id": PrototypeRelic.EMBER_ID, "used": false}
	player.growth_common_bonus = 0.10
	player.growth_bow_bonus = 0.15
	player.set_lifesteal_unlocked(true)
	player.damage_receiver.health = 1
	player.lifesteal_progress = 0
	ultimate.gauge = 0
	var first := _ricochet_target("scaled-first", Vector2(1300, 780))
	var second := _ricochet_target("scaled-next", Vector2(1420, 660))
	var shot := _fire()
	if not _check(shot.damage == 66 and shot.ricochet_damage == 44, "각 원본48/32에 성장1.25·불씨1.1·최종 반올림"): return false
	shot._physics_process(1.0)
	shot._physics_process(1.0)
	if not _check(first.damage_receiver.health == 934 and second.damage_receiver.health == 956 and ultimate.gauge == 16 and player.damage_receiver.health == 6 and player.lifesteal_progress == 10, "실제 합산110·스킬8씩·흡수5/소수10"): return false
	shot.free()
	weapons.bow_combat._update_skill_action(1.0)
	first.free()
	second.free()
	player.relic_state = {"id": PrototypeRelic.HOURGLASS_ID, "used": false}
	player.growth_common_bonus = 0
	player.growth_bow_bonus = 0
	player.set_lifesteal_unlocked(false)
	growth.ranks.time_collector = 1
	growth.ranks.time_collector_boost = 1
	ultimate.set_time_collector_boost_unlocked(true)
	ultimate.gauge = 0
	first = _ricochet_target("kill-first", Vector2(1300, 780))
	second = _ricochet_target("kill-next", Vector2(1420, 660))
	for target in [first, second]:
		target.damage_receiver.health = 1
		target.defeated.connect(growth._on_enemy_defeated)
	shot = _fire()
	shot._physics_process(1.0)
	if not _resolve_growth(): return false
	shot._physics_process(1.0)
	if not _check(first.damage_receiver.dead and second.damage_receiver.dead and ultimate.gauge == 40, "실제 두 처치·모래시계 스킬10+강화 처치10 각각·죽은 첫 적에서 도탄"): return false
	if not _resolve_growth(): return false
	shot.free()
	first.free()
	second.free()
	weapons.bow_combat._update_skill_action(1.0)
	player.relic_state = {}
	return true

func _test_cast_freeze(weapon: String) -> bool:
	if weapon == "sword": return await super._test_cast_freeze(weapon)
	var expected_damage := player.growth_damage(32, "bow", "skill")
	var first := _ricochet_target("freeze-first", Vector2(1300, 780))
	var second := _ricochet_target("freeze-next", Vector2(1420, 660))
	var shot := _fire()
	shot._physics_process(1.0)
	if not _check(shot._hit_count == 1 and shot._locked_target() == second, "도탄 비행 정지 준비"): return false
	var actor := weapons.bow_combat
	shot.set_physics_process(true)
	actor.set_physics_process(true)
	var position := shot.global_position
	var direction := shot.direction
	var elapsed := actor._action_elapsed_s
	var before := weapons.checkpoint_snapshot()
	var files := _files()
	if not _check(controls.open_run_build() and paused, "도탄 중 실제 현재 도전 조회"): return false
	var cards := PrototypeRunBuildView.cards(1, controls.run_build_state)
	if not _check(cards.any(func(card: Dictionary) -> bool: return card.id == "bow_ricochet" and card.lines.has("첫 피해48 · 도탄 피해32")), "보유 슬롯·원본 첫/도탄 피해 조회"): return false
	await create_timer(0.12, true).timeout
	if not _check(shot.global_position == position and shot.direction == direction and shot._hit_count == 1 and second.damage_receiver.health == 1000 and actor._action_elapsed_s == elapsed and weapons.checkpoint_snapshot() == before, "실제 프레임 도탄/표적/동작/대기 정지"): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(2.9)
	if not _check(paused and shot.global_position == position, "3초 복귀 중 도탄 정지"): return false
	controls.advance_mode_timer_for_test(0.2)
	shot.set_physics_process(false)
	actor.set_physics_process(false)
	if not _check(not paused and _files() == files and weapons.checkpoint_snapshot() == before, "조회/복귀 파일·대기 무변경"): return false
	shot._physics_process(1.0)
	if not _check(second.damage_receiver.health == 1000 - expected_damage and shot.damage == expected_damage and shot._hit_count == 2, "복귀 후 같은 고정 표적·성장 반영 도탄 피해 보존"): return false
	actor._update_skill_action(1.0)
	shot.free()
	first.free()
	second.free()
	return true

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-157 failed: " + message)
		paused = false
		quit(1)
	return condition

