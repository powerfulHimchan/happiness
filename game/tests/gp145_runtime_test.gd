extends "res://tests/gp143_runtime_test.gd"

const GP145_SAVE := "user://gp145_checkpoint.json"
const GP145_META := "user://gp145_meta.jsonl"
const GP145_RECORD := "user://gp145_records.jsonl"
const GP145_BOOK := "user://gp145_abilities.jsonl"

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	store.save_path = GP145_SAVE
	legacy.save_path = GP145_META
	if phase == "seed" or phase.begins_with("combat") or phase == "flows":
		store.clear_checkpoint()
		for path in [GP145_META, GP145_RECORD, GP145_BOOK]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	var discoveries := AbilityDiscoveryStore.new()
	discoveries.save_path = GP145_BOOK
	sandbox.ability_discovery_store = discoveries
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP145_RECORD
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
			if not _check(PrototypeSkillRewards.SKILLS.size() == PrototypeSkillRewards.POOLS.sword.size() + PrototypeSkillRewards.POOLS.bow.size() and PrototypeSkillRewards.POOLS.sword.has("sword_charge") and PrototypeSkillRewards.POOLS.bow.has("bow_homing"), "전체 스킬·검 돌파/활 후퇴 원본 보존"): return
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
			if not await _replace_mobility("bow_homing", 0, true): return
			if not _check(weapons.skills.bow[0] == "bow_homing" and weapons.bow_combat._skill_1_cooldown_s == 9, "실제 추적 슬롯1·원본9초 대기"): return
			if not _test_mobility_save(): return
			if not await _test_skill_codex(true, 1.25): return
		"resume":
			if not _check(weapons.skills == PrototypeSkillRewards.defaults(), "복원 전 기본 스킬"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and runner.stage_number == 2 and runner.stage_limit == 5 and weapons.skills.sword[1] == "sword_charge" and weapons.skills.bow[0] == "bow_homing" and weapons.sword_combat._skill_2_cooldown_s == 9 and weapons.bow_combat._skill_1_cooldown_s == 9 and player.skill_recharge_multiplier() == 1.25, "별도 프로세스 반복 복원·양 슬롯/원본 대기/시계추/도전 길이 보존"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _test_cast_freeze("sword"): return
			if not await _test_cast_freeze("bow"): return
			while not runner.awaiting_boss_choice():
				if not _finish_stage(): return
				if runner.awaiting_boss_choice(): break
				if not _check(sandbox._claim_weapon_reward(""), "다음 정예 유지"): return
				_tap(controls.stage_route_rects[0].get_center())
			if not _check(store.load_checkpoint().weapons.skills.sword[1] == "sword_charge" and store.load_checkpoint().weapons.skills.bow[0] == "bow_homing", "5스테이지 보스 선택 대기에도 새 구성 저장"): return
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
			if not _test_tracking(1 if phase.ends_with("right") else -1): return
			if not _test_target_loss(): return
		"flows":
			controls.begin_retry("bow")
			_configure_combat()
			if not _test_cancel_and_switch(): return
			if not await _test_cast_freeze("bow"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-145 runtime test: OK (" + phase + ")")
	quit(0)

func _files() -> Dictionary:
	var result := {}
	for path in [GP145_SAVE, GP145_SAVE + ".bak", GP145_META, GP145_RECORD, GP145_BOOK]:
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
		store.save_path = "user://gp145_missing/checkpoint.json"
		_tap(controls.skill_reward_confirm_rect.get_center())
		store.save_path = GP145_SAVE
		if not _check(weapons.checkpoint_snapshot() == before and store.load_checkpoint() == saved and not runner.skills_claimed, "이동 스킬 교체 실패·슬롯/대기/정상 저장 롤백"): return false
	_tap(controls.skill_reward_confirm_rect.get_center())
	return _check(weapons.skills[PrototypeSkillRewards.weapon_for(id)][slot] == id and runner.skills_claimed, "실제 슬롯 비교·교체 확정")

func _test_mobility_save() -> bool:
	var saved := store.load_checkpoint()
	for weapon in ["sword", "bow"]:
		var bad := saved.duplicate(true)
		bad.weapons.skills[weapon][0] = "bow_homing" if weapon == "sword" else "sword_charge"
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "다른 무기 기술 저장 거부·정상 저장 보호"): return false
		bad = saved.duplicate(true)
		bad.weapons.skills[weapon] = ["sword_charge", "sword_charge"] if weapon == "sword" else ["bow_homing", "bow_homing"]
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
	weapons.set_skill_loadout({"sword": ["sword_charge", "sword_spin"], "bow": ["bow_homing", "bow_arrow_rain"]})
	weapons.bow_combat.target_selector.set_physics_process(false)

func _shot() -> BowProjectile:
	var shot: BowProjectile = get_nodes_in_group("bow_projectile").back()
	shot.set_physics_process(false)
	return shot

func _test_tracking(direction: int) -> bool:
	var target := _combat_target("moving", Vector2(1000 + direction * 420, 780))
	var rear := _combat_target("rear", Vector2(1000 - direction * 100, 780))
	var far := _combat_target("far", Vector2(1000 + direction * 950, 780))
	var offscreen := _combat_target("offscreen", Vector2(1000 + direction * 100, -2000))
	var actor := weapons.bow_combat
	_begin_cast("bow", direction)
	if not _check(actor._homing_target != null and actor._homing_target.get_ref() == target and actor._skill_1_cooldown_s == 9 and player._combat_move_allowed and not player._combat_turn_allowed, "실제 터치·정면 표적 고정·후방/범위/화면 제외·9초 대기"): return false
	actor._update_skill_action(0.13)
	if not _check(get_nodes_in_group("bow_projectile").is_empty(), "0.14초 전 발사 없음"): return false
	player.facing_direction = -direction
	actor._update_skill_action(0.02)
	var shot := _shot()
	if not _check(get_nodes_in_group("bow_projectile").size() == 1 and shot.damage == 44 and shot.max_hits == 1 and shot.global_position.x == 1000 + direction * 58 and shot.arrow_sprite.modulate == Color("65e6ae"), "단발44·원래 방향 발사 위치·초록 화살"): return false
	target.global_position.y -= 120
	var heading := shot.direction.angle()
	shot._physics_process(0.05)
	var turn := absf(wrapf(shot.direction.angle() - heading, -PI, PI))
	if not _check(turn > 0 and turn <= PI * 0.05 + 0.001 and shot.direction.y < 0, "이동 표적을 향해 초당180도 이하 회전"): return false
	for ignored in 100:
		if shot.is_queued_for_deletion(): break
		shot._physics_process(0.01)
	if not _check(target.damage_receiver.health == 956 and shot._hit_count == 1 and shot._travelled_px <= 800 and rear.damage_receiver.health == 1000 and far.damage_receiver.health == 1000, "곡선 비행 실제44 한 번 명중·최대 경로8m"): return false
	shot._check_hits(shot.global_position, target.global_position)
	if not _check(target.damage_receiver.health == 956, "중복 충돌 추가 피해 없음"): return false
	shot.free()
	actor._update_skill_action(1.0)
	for node in [target, rear, far, offscreen]: node.free()
	_begin_cast("bow", direction)
	actor._update_skill_action(0.5)
	shot = _shot()
	if not _check(shot._tracking_target == null and shot.direction == Vector2(direction, 0) and not player._combat_action_active, "무표적 직진·0.35초 동작 종료"): return false
	var start := shot.global_position
	shot._physics_process(10.0)
	if not _check(is_equal_approx(shot._travelled_px, 800) and is_equal_approx(shot.global_position.distance_to(start), 800) and shot.is_queued_for_deletion(), "큰 프레임도8m 경로에서 만료"): return false
	shot.free()
	return true

func _test_target_loss() -> bool:
	var actor := weapons.bow_combat
	for before_fire in [true, false]:
		for reason in ["hidden", "dead", "freed", "offscreen", "respawn"]:
			var target := _combat_target(reason, Vector2(1420, 780))
			_begin_cast("bow")
			var shot: BowProjectile
			if not before_fire:
				actor._update_skill_action(0.15)
				shot = _shot()
			match reason:
				"hidden": target.visible = false
				"dead": target.damage_receiver.dead = true
				"freed": target.free()
				"offscreen": target.global_position.y = -2000
				"respawn": target.reset_target()
			var replacement := _combat_target("replacement", Vector2(1320, 900))
			actor.target_selector.force_scan()
			if before_fire:
				actor._update_skill_action(0.15)
				shot = _shot()
			var heading := shot.direction
			shot._physics_process(0.01)
			if not _check(shot._tracking_target == null and shot.direction == heading and (not before_fire or heading == Vector2.RIGHT), "발사 전/후 " + reason + " 표적 상실·재지정 없이 직진"): return false
			if is_instance_valid(target):
				target.visible = true
				target.global_position.y = 900
			shot._steer(0.1)
			if not _check(shot.direction == heading, "표적 복귀에도 재추적 없음"): return false
			shot.free()
			actor._update_skill_action(1.0)
			if is_instance_valid(target): target.free()
			replacement.free()
	var target := _combat_target("timeout", Vector2(1700, 1000))
	_begin_cast("bow")
	actor._update_skill_action(0.15)
	var shot := _shot()
	shot._steer(0.6)
	shot._steer(0.4)
	var heading := shot.direction
	target.global_position.y -= 300
	shot._steer(1.0)
	if not _check(shot._tracking_target == null and shot.direction == heading, "추적1초 상한·이후 현재 방향 유지"): return false
	shot.free()
	target.free()
	actor._update_skill_action(1.0)
	return true

func _test_cancel_and_switch() -> bool:
	var actor := weapons.bow_combat
	for reason in ["evade", "hit", "switch"]:
		_begin_cast("bow")
		actor._update_skill_action(0.09)
		match reason:
			"evade": player.request_evade()
			"hit": _interrupt_cast("homing")
			"switch":
				weapons.active_weapon_id = "sword"
				weapons._apply_active_weapon()
		actor._update_skill_action(1.0)
		if not _check(get_nodes_in_group("bow_projectile").is_empty() and not player._combat_action_active and actor._skill_1_cooldown_s == 9, "발사 전 " + reason + " 취소·9초 대기 유지"): return false
	_begin_cast("bow")
	actor._update_skill_action(0.15)
	var shot := _shot()
	weapons.active_weapon_id = "sword"
	weapons._apply_active_weapon()
	ultimate._apply_enemy_time_scale(0.1)
	var start := shot.global_position
	shot._physics_process(0.1)
	if not _check(is_equal_approx(shot.global_position.distance_to(start), shot.speed_px_s * 0.1) and get_nodes_in_group("bow_projectile").size() == 1, "발사 후 무기 전환 화살 유지·적 감속은 화살 속도 유지"): return false
	ultimate._apply_enemy_time_scale(1.0)
	shot.free()
	player.relic_state = {"id": PrototypeRelic.CLOCK_ID, "used": false}
	actor.set_active(false)
	actor._skill_1_cooldown_s = 9
	actor._physics_process(7.2)
	return _check(is_zero_approx(actor._skill_1_cooldown_s) and PrototypeSkillRewards.lines("bow_homing", 1.25)[0].begins_with("재사용 7.2초"), "시계추 실제9→7.2초·조회 일치")

func _test_cast_freeze(weapon: String) -> bool:
	if weapon == "sword": return await super._test_cast_freeze(weapon)
	weapons.active_weapon_id = "bow"
	weapons._apply_active_weapon()
	player.prepare_next_stage(Vector2(1000, 780))
	var actor := weapons.bow_combat
	var target := _combat_target("freeze", Vector2(1420, 780))
	actor._skill_1_cooldown_s = 0
	_press_skill(0)
	actor._update_skill_action(0.15)
	var shot := _shot()
	shot.set_physics_process(true)
	actor.set_physics_process(true)
	var position := shot.global_position
	var tracking := shot._tracking_remaining_s
	if not _check(tracking > 0, "추적 잔량이 있는 실제 화살 정지 검사"): return false
	var elapsed := actor._action_elapsed_s
	var before := weapons.checkpoint_snapshot()
	var files := _files()
	if not _check(controls.open_run_build() and paused, "비행 중 도전 상태 조회 정지"): return false
	await create_timer(0.12, true).timeout
	if not _check(shot.global_position == position and shot._tracking_remaining_s == tracking and actor._action_elapsed_s == elapsed and weapons.checkpoint_snapshot() == before, "실제 프레임 화살/추적/동작/대기 정지"): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(2.9)
	if not _check(paused and shot.global_position == position, "복귀 카운트다운에도 화살 정지"): return false
	controls.advance_mode_timer_for_test(0.2)
	shot.set_physics_process(false)
	actor.set_physics_process(false)
	if not _check(not paused and _files() == files and weapons.checkpoint_snapshot() == before, "조회·복귀 저장 및 대기 무변경"): return false
	actor._update_skill_action(1.0)
	shot.free()
	target.free()
	return true

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-145 failed: " + message)
		paused = false
		quit(1)
	return condition
