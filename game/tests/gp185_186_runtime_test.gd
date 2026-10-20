extends "res://tests/gp175_176_runtime_test.gd"

const GP185_186_SAVE := "user://gp185_186_checkpoint.json"
const GP185_186_META := "user://gp185_186_meta.jsonl"
const GP185_186_RECORD := "user://gp185_186_records.jsonl"
const GP185_186_BOOK := "user://gp185_186_abilities.jsonl"

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	store.save_path = GP185_186_SAVE
	legacy.save_path = GP185_186_META
	if phase == "seed" or phase.begins_with("combat") or phase == "flows":
		store.clear_checkpoint()
		for path in [GP185_186_META, GP185_186_RECORD, GP185_186_BOOK]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	var discoveries := AbilityDiscoveryStore.new()
	discoveries.save_path = GP185_186_BOOK
	sandbox.ability_discovery_store = discoveries
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP185_186_RECORD
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
			if not _check(PrototypeSkillRewards.CODEX_ORDER.size() >= 22 and PrototypeSkillRewards.CODEX_ORDER.slice(20, 22) == ["sword_revolve", "bow_fan_piercing"] and PrototypeSkillRewards.POOLS.sword.size() >= 9 and PrototypeSkillRewards.POOLS.bow.size() >= 9, "22종 도감·기존20종 순서 보존·검/활 각11종"): return
			if not _check(PrototypeSkillRewards.SKILLS.size() == PrototypeSkillRewards.POOLS.sword.size() + PrototypeSkillRewards.POOLS.bow.size() + PrototypeSkillRewards.FIST_POOL.size() and PrototypeSkillRewards.POOLS.sword.has("sword_revolve") and PrototypeSkillRewards.POOLS.bow.has("bow_fan_piercing"), "전체 스킬·올려 베기/연쇄 관통 원본 등록"): return
			controls.begin_retry("sword", 5)
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "첫 정예 무기 유지"): return
			if not await _replace_mobility("sword_revolve", 1, true): return
			if not _check(weapons.skills.sword[1] == "sword_revolve" and weapons.sword_combat._skill_2_cooldown_s == 10, "선회 베기 슬롯2·원본10초 대기"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "둘째 정예 무기 유지"): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[1].get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(player.relic_state.get("id", "") == PrototypeRelic.CLOCK_ID, "실제 시계추 선택"): return
			if not await _replace_mobility("bow_fan_piercing", 0, true): return
			if not _check(weapons.skills.bow[0] == "bow_fan_piercing" and weapons.bow_combat._skill_1_cooldown_s == 9, "확산 관통 슬롯1·원본9초 대기"): return
			if not _test_mobility_save(): return
			if not await _test_skill_codex(true, 1.25): return
		"resume":
			if not _check(weapons.skills == PrototypeSkillRewards.defaults(), "복원 전 기본 스킬"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and runner.stage_number == 2 and runner.stage_limit == 5 and weapons.skills.sword[1] == "sword_revolve" and weapons.skills.bow[0] == "bow_fan_piercing" and weapons.sword_combat._skill_2_cooldown_s == 10 and weapons.bow_combat._skill_1_cooldown_s == 9 and player.skill_recharge_multiplier() == 1.25, "별도 프로세스 반복 복원·양 슬롯/원본 대기/시계추/도전 길이 보존"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _test_cast_freeze("sword"): return
			if not await _test_cast_freeze("bow"): return
			var stale := _chain_shot()
			while not runner.awaiting_boss_choice():
				if not _finish_stage(): return
				if runner.awaiting_boss_choice(): break
				if not _check(sandbox._claim_weapon_reward(""), "다음 정예 유지"): return
				_tap(controls.stage_route_rects[0].get_center())
				if not _check(not is_instance_valid(stale) and get_nodes_in_group("bow_projectile").is_empty(), "실제 다음 스테이지 전환은 남은 도탄 화살 정리"): return
			if not _check(store.load_checkpoint().weapons.skills.sword[1] == "sword_revolve" and store.load_checkpoint().weapons.skills.bow[0] == "bow_fan_piercing", "5스테이지 보스 선택 대기에도 새 구성 저장"): return
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
			if not _test_revolve_hits(1 if phase.ends_with("right") else -1): return
			if not _test_fan_hits(1 if phase.ends_with("right") else -1): return
		"flows":
			controls.begin_retry("sword")
			_configure_combat()
			if not _test_cancellation(): return
			if not await _test_cast_freeze("sword"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-185/186 runtime test: OK (" + phase + ")")
	quit(0)

func _files() -> Dictionary:
	var result := {}
	for path in [GP185_186_SAVE, GP185_186_SAVE + ".bak", GP185_186_META, GP185_186_RECORD, GP185_186_BOOK]:
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
		store.save_path = "user://gp185_186_missing/checkpoint.json"
		_tap(controls.skill_reward_confirm_rect.get_center())
		store.save_path = GP185_186_SAVE
		if not _check(weapons.checkpoint_snapshot() == before and store.load_checkpoint() == saved and not runner.skills_claimed, "이동 스킬 교체 실패·슬롯/대기/정상 저장 롤백"): return false
	_tap(controls.skill_reward_confirm_rect.get_center())
	return _check(weapons.skills[PrototypeSkillRewards.weapon_for(id)][slot] == id and runner.skills_claimed, "실제 슬롯 비교·교체 확정")

func _test_mobility_save() -> bool:
	var saved := store.load_checkpoint()
	for weapon in ["sword", "bow"]:
		var bad := saved.duplicate(true)
		bad.weapons.skills[weapon][0] = "bow_fan_piercing" if weapon == "sword" else "sword_revolve"
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "다른 무기 기술 저장 거부·정상 저장 보호"): return false
		bad = saved.duplicate(true)
		bad.weapons.skills[weapon] = ["sword_revolve", "sword_revolve"] if weapon == "sword" else ["bow_fan_piercing", "bow_fan_piercing"]
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
	weapons.set_skill_loadout({"sword": ["sword_revolve", "sword_spin"], "bow": ["bow_fan_piercing", "bow_arrow_rain"]})
	weapons.bow_combat.target_selector.set_physics_process(false)

func _new_target(key: String, offset: Vector2) -> PrototypeTarget:
	var target := _combat_target(key, player.global_position + offset)
	target.add_to_group("combat_enemy")
	return target

func _test_revolve_hits(direction: int) -> bool:
	player.prepare_next_stage(Vector2(1000, 780))
	player.facing_direction = direction
	var actor := weapons.sword_combat
	actor.reset_combat()
	var front := _new_target("revolve-front", Vector2(200 * direction, 0))
	var rear := _new_target("revolve-rear", Vector2(-200 * direction, 0))
	var edge := _new_target("revolve-edge", Vector2(220 * direction, 90))
	var outside := _new_target("revolve-outside", Vector2(221 * direction, 0))
	ultimate.gauge = 0
	_press_skill(0)
	actor._update_skill_action(0.15)
	if not _check(front.damage_receiver.health == 1000 and actor._skill_1_cooldown_s == 10 and not player.invincible, "선회 준비/10초 대기/추가 무적 없음"): return false
	actor._update_skill_action(0.02)
	if not _check(front.damage_receiver.health == 978 and rear.damage_receiver.health == 1000 and edge.damage_receiver.health == 978 and outside.damage_receiver.health == 1000, "정면22·2.2m/높이 경계"): return false
	player.facing_direction = -direction
	actor._update_skill_action(0.2)
	if not _check(front.damage_receiver.health == 978 and rear.damage_receiver.health == 974 and actor._line_visual_direction == -direction, "시전 방향 고정·후방26만"): return false
	actor._update_skill_action(0.2)
	if not _check(front.damage_receiver.health == 956 and rear.damage_receiver.health == 974 and edge.damage_receiver.health == 956 and ultimate.gauge == 40, "정면 마지막22·타격5회 게이지40"): return false
	actor._update_skill_action(10)
	if not _check(front.damage_receiver.health == 956 and not player._combat_action_active, "큰 프레임 중복 없음·정상 행동 종료"): return false
	for t in [front, rear, edge, outside]: t.free()
	return true

func _test_fan_hits(direction: int) -> bool:
	player.prepare_next_stage(Vector2(1000, 780))
	player.facing_direction = direction
	weapons.active_weapon_id = "bow"
	weapons._apply_active_weapon()
	var actor := weapons.bow_combat
	actor.reset_combat()
	actor.target_selector.current_target = null
	_press_skill(0)
	actor._update_skill_action(0.19)
	if not _check(actor.projectile_fired_count == 0 and actor._skill_1_cooldown_s == 9, "확산 준비0.2초·9초 대기"): return false
	actor._update_skill_action(0.02)
	var shots := get_nodes_in_group("bow_projectile")
	if not _check(shots.size() == 3 and actor.last_combat_log.contains("확산 관통") and actor.last_combat_log.contains("각 최대2개체 관통"), "실제 세 방향 화살/원본 이름/관통 로그"): return false
	ultimate.gauge = 0
	for i in shots.size():
		var shot: BowProjectile = shots[i]
		shot.set_physics_process(false)
		var expected := Vector2(direction, 0).rotated(deg_to_rad(BowCombatController.SPREAD_ANGLES_DEG[i]))
		if not _check(shot.direction.is_equal_approx(expected) and shot.max_hits == 2 and shot.damage == 20, "시전 방향 기준±15도·각2관통/20피해"): return false
		var targets: Array[PrototypeTarget] = []
		for distance in [200, 320, 440]:
			var t := _combat_target("fan:%d:%d" % [i, distance], shot.global_position + expected * distance - Vector2(0, -38))
			t.add_to_group("combat_enemy")
			targets.append(t)
		shot._check_hits(shot.global_position, shot.global_position + expected * 500)
		shot._check_hits(shot.global_position, shot.global_position + expected * 500)
		if not _check(targets[0].damage_receiver.health == 980 and targets[1].damage_receiver.health == 980 and targets[2].damage_receiver.health == 1000 and shot._hit_count == 2, "각 경로 실제 가까운2개체·중복 차단"): return false
		for t in targets: t.free()
		shot.free()
	if not _check(ultimate.gauge == 48 and actor.projectile_fired_count == 3, "6적중 기존 게이지48·3발 발사"): return false
	actor._update_skill_action(10)
	return _check(actor.projectile_fired_count == 3 and not player._combat_action_active, "큰 프레임 추가 발사 없음")
func _test_cast_freeze(weapon: String) -> bool:
	player.prepare_next_stage(Vector2(1000, 780))
	weapons.active_weapon_id = weapon
	weapons._apply_active_weapon()
	var id := "sword_revolve" if weapon == "sword" else "bow_fan_piercing"
	var slot: int = weapons.skills[weapon].find(id)
	var actor = weapons.sword_combat if weapon == "sword" else weapons.bow_combat
	actor.reset_combat()
	_press_skill(slot)
	actor._update_skill_action(0.1)
	actor.set_physics_process(true)
	var elapsed: float = actor._action_elapsed_s
	var files := _files()
	var timers := weapons.checkpoint_snapshot()
	if not _check(controls.open_run_build() and paused, "시전 중 실제 도전 상태 조회"): return false
	var cards := PrototypeRunBuildView.cards(1, controls.run_build_state)
	if not _check(cards.any(func(card: Dictionary) -> bool: return card.id == id), "새 장착 스킬 조회"): return false
	await create_timer(0.12, true).timeout
	if not _check(actor._action_elapsed_s == elapsed and weapons.checkpoint_snapshot() == timers, "실제 프레임 시전/대기 정지"): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(3.1)
	actor.set_physics_process(false)
	if not _check(not paused and _files() == files and weapons.checkpoint_snapshot() == timers, "조회 후 원본 시전/대기/파일 보존"): return false
	actor._update_skill_action(1.0)
	for shot in get_nodes_in_group("bow_projectile"): shot.free()
	return _check(not player._combat_action_active, "복귀 후 정상 시전 완료")
