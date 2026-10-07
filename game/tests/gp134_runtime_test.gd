extends "res://tests/gp132_runtime_test.gd"

const GP134_SAVE := "user://gp134_checkpoint.json"
const GP134_META := "user://gp134_meta.jsonl"
const GP134_RECORD := "user://gp134_records.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP134_SAVE
	legacy.save_path = GP134_META
	if phase == "seed":
		store.clear_checkpoint()
		for path in [GP134_META, GP134_RECORD]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	var discoveries := AbilityDiscoveryStore.new()
	discoveries.save_path = "user://gp134_abilities.jsonl"
	if phase == "seed": DirAccess.remove_absolute(ProjectSettings.globalize_path(discoveries.save_path))
	sandbox.ability_discovery_store = discoveries
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP134_RECORD
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
	match phase:
		"seed":
			if not await _test_skill_codex(false, 1.0): return
			if not _check(not FileAccess.file_exists(GP134_SAVE) and not FileAccess.file_exists(GP134_META), "첫 도감 방문은 저장 생성 없음"): return
			controls.begin_retry()
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			_tap(controls.skill_reward_open_rect.get_center())
			for ignored in 2: _tap(controls.skill_reward_cycle_rect.get_center())
			_select_offer("sword_thrust", 1)
			_tap(controls.skill_reward_confirm_rect.get_center())
			if not _check(weapons.skills.sword[1] == "sword_thrust" and weapons.sword_combat._skill_2_cooldown_s == 7 and runner.skills_claimed and controls.movement_metrics.skill_2_button_label == "찌르기", "실제 첫 정예 보상 찌르기 슬롯2 교체"): return
			var bad := store.load_checkpoint()
			bad.weapons.skills.bow[0] = "sword_thrust"
			if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA, "새 기술 다른 무기 저장 거부"): return
			bad = store.load_checkpoint()
			bad.weapons.skills.sword[0] = "sword_thrust"
			if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA, "동일 기술 두 슬롯 저장 거부"): return
			if not await _test_skill_codex(true, 1.0): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			_tap(controls.stage_route_rects[1].get_center())
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[1].get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(player.relic_state.id == PrototypeRelic.CLOCK_ID, "실제 시계추 보상 선택"): return
			_tap(controls.skill_reward_open_rect.get_center())
			for ignored in 2: _tap(controls.skill_reward_cycle_rect.get_center())
			_select_offer("bow_double_piercing", 0)
			var saved := store.load_checkpoint()
			var before := weapons.checkpoint_snapshot()
			store.save_path = "user://gp134_missing/checkpoint.json"
			_tap(controls.skill_reward_confirm_rect.get_center())
			store.save_path = GP134_SAVE
			if not _check(weapons.checkpoint_snapshot() == before and store.load_checkpoint() == saved and not runner.skills_claimed, "도감 추가 후 스킬 교체 실패 롤백 유지"): return
			if not _check(controls.movement_metrics.weapon_skills == before.skills, "실패 후 도감용 장착 상태도 이전 구성"): return
			_tap(controls.skill_reward_confirm_rect.get_center())
			if not _check(weapons.skills.bow[0] == "bow_double_piercing" and weapons.bow_combat._skill_1_cooldown_s == 8 and controls.movement_metrics.weapon_skills == weapons.skills, "교체 성공 후 양 무기 장착 정보 즉시 갱신"): return
			if not await _test_skill_codex(true, 1.25): return
		"resume":
			if not _check(weapons.skills == PrototypeSkillRewards.defaults() and player.relic_state.is_empty(), "이어하기 전 저장 스킬·유물 자동 적용 없음"): return
			if not await _test_skill_codex(false, 1.0): return
			for ignored in 2:
				_tap(controls.village_snapshot().layout["continue"].get_center())
				if not _check(controls.current_screen_mode() == 9 and weapons.skills.sword[1] == "sword_thrust" and weapons.skills.bow[0] == "bow_double_piercing" and player.skill_recharge_multiplier() == 1.25 and weapons.sword_combat._skill_2_cooldown_s == 7 and weapons.bow_combat._skill_1_cooldown_s == 8, "도감 이어하기 버튼으로 실제 두 슬롯·시계추 복원"): return
				if not await _test_skill_codex(true, 1.25): return
		"finish":
			if not _check(sandbox.continue_saved_run(), "스킬 도감 보스 도전 복원"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("rescue"), "교체·유물 적용 구성 실제 완주"): return
			if not await _test_skill_codex(false, 1.0): return
			controls.begin_retry()
			if not _check(weapons.skills == PrototypeSkillRewards.defaults() and player.relic_state.is_empty(), "새 도전 기본 슬롯·유물 초기화"): return
			if not await _test_skill_codex(true, 1.0): return
			controls.begin_retry()
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			var old := store.load_checkpoint()
			old.weapons.erase("skills")
			old.stage.erase("skills_claimed")
			old.erase("relic")
			if not _check(store.save_checkpoint(old) == OK, "스킬·유물 필드 없는 이전 저장 준비"): return
		"legacy":
			if not await _test_skill_codex(false, 1.0): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			if not _check(weapons.skills == PrototypeSkillRewards.defaults() and runner.skills_claimed and player.relic_state.is_empty(), "이전 저장 기본 구성·보상 소급 지급 없음"): return
			if not await _test_skill_codex(true, 1.0): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("destroy"), "이전 저장 실제 보스 완주"): return
		"combat":
			controls.begin_retry()
			if not await _test_precision_combat(): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-134 runtime test: OK (" + phase + ")")
	quit(0)

func _test_precision_combat() -> bool:
	for target in get_nodes_in_group("targetable"): target.visible = false
	player.growth_common_bonus = 0
	player.growth_sword_bonus = 0
	player.growth_bow_bonus = 0
	player.boss_legacy = {}
	player.memory_id = ""
	player.relic_state = {}
	weapons.set_equipment({"sword": 0, "bow": 0})
	weapons.set_skill_loadout({"sword": ["sword_thrust", "sword_spin"], "bow": ["bow_double_piercing", "bow_arrow_rain"]})
	player.global_position = Vector2(1000, 780)
	player.facing_direction = 1
	var front := _combat_target("thrust-front", Vector2(1200, 780))
	var boundary := _combat_target("thrust-boundary", Vector2(1300, 735))
	var behind := _combat_target("thrust-behind", Vector2(920, 780))
	var far := _combat_target("thrust-far", Vector2(1301, 780))
	var high := _combat_target("thrust-high", Vector2(1200, 734))
	for target in [front, boundary, behind, far, high]: target.damage_receiver.post_hit_invulnerability_s = 0
	var sword := weapons.sword_combat
	var bow := weapons.bow_combat
	sword._skill_1_cooldown_s = 0
	_press_skill(0)
	sword._update_skill_action(0.17)
	if not _check(front.damage_receiver.health == 1000 and sword._skill_1_cooldown_s == 7 and not player.combat_evade_allowed and not player._combat_move_allowed and not player._combat_turn_allowed, "찌르기 모바일 시전·0.18초 전·7초·이동/회피/방향 잠금"): return false
	sword._update_skill_action(0.02)
	if not _check(front.damage_receiver.health == 945 and boundary.damage_receiver.health == 945 and behind.damage_receiver.health == 1000 and far.damage_receiver.health == 1000 and high.damage_receiver.health == 1000 and sword.skill_hit_count == 2 and is_equal_approx(sword._line_half_height_m, 0.45), "찌르기 실제55·3m/0.45m 경계·후방/거리/높이 제외·표시 범위 일치"): return false
	sword.queue_redraw()
	await process_frame
	sword._update_skill_action(0.04)
	if not _check(player.combat_evade_allowed, "찌르기0.22초 이후 회피 허용"): return false
	sword._update_skill_action(0.40)
	_press_skill(0)
	if not _check(front.damage_receiver.health == 945 and sword._action == SwordCombatController.Action.NONE, "찌르기 단일 타격·재사용 중 재시전 차단"): return false
	sword._skill_1_cooldown_s = 0
	_press_skill(0)
	_interrupt_cast("thrust-before-hit")
	sword._update_skill_action(1.0)
	if not _check(front.damage_receiver.health == 945 and sword._skill_1_cooldown_s == 7 and not player._combat_action_active, "피격은 찌르기 타격 취소·대기시간 유지·이동 해제"): return false
	player._input_lock_remaining_s = 0
	player.damage_receiver.tick(1.0)
	for target in [front, boundary, behind, far, high]: target.visible = false
	player.facing_direction = -1
	var left := _combat_target("thrust-left", Vector2(700, 825))
	left.damage_receiver.post_hit_invulnerability_s = 0
	sword._skill_1_cooldown_s = 0
	_press_skill(0)
	sword._update_skill_action(0.19)
	if not _check(left.damage_receiver.health == 945 and sword._line_direction == -1, "찌르기 좌측3m/아래0.45m 경계·방향 반전"): return false
	sword._update_skill_action(0.4)
	left.visible = false
	weapons.active_weapon_id = "bow"
	weapons._apply_active_weapon()
	player.facing_direction = 1
	bow.target_selector.current_target = null
	var first := _combat_target("double-first", Vector2(1300, 780))
	var second := _combat_target("double-second", Vector2(1600, 780))
	var third := _combat_target("double-third", Vector2(1900, 780))
	for target in [first, second, third]: target.damage_receiver.post_hit_invulnerability_s = 0
	bow._skill_1_cooldown_s = 0
	_press_skill(0)
	bow._update_skill_action(0.15)
	if not _check(get_nodes_in_group("bow_projectile").is_empty() and player._combat_move_allowed and not player._combat_turn_allowed and bow._skill_1_cooldown_s == 8, "이중 관통0.16초 전·이동 허용·방향 고정·8초"): return false
	var ids: Array[String] = []
	for index in 2:
		bow._update_skill_action(0.02 if index == 0 else 0.20)
		var shots := get_nodes_in_group("bow_projectile")
		if not _check(shots.size() == 1, "0.16/0.36초 실제 화살 한 발씩"): return false
		var shot: BowProjectile = shots[0]
		shot.set_physics_process(false)
		ids.append(shot.projectile_id)
		if not _check(shot.damage == 26 and shot.max_hits == 2 and shot.attack_id == &"bow_double_piercing" and shot.direction == Vector2.RIGHT, "이중 관통 원본26·화살별2개체·정면 실제 투사체"): return false
		shot._check_hits(shot.global_position, third.global_position + Vector2(0, -38))
		shot._check_hits(shot.global_position, third.global_position + Vector2(0, -38))
		if not _check(first.damage_receiver.health == 1000 - 26 * (index + 1) and second.damage_receiver.health == first.damage_receiver.health and third.damage_receiver.health == 1000 and shot._hit_count == 2, "각 화살 두 개체 관통·동일 화살 중복 없음·세 번째 제외"): return false
		shot.free()
	if not _check(ids[0] != ids[1] and bow.skill_hit_count == 4 and bow.total_damage == 104 and player.combat_evade_allowed, "두 화살 독립 공격ID·4적중/104피해·회피 허용"): return false
	bow._update_skill_action(0.3)
	if not _check(get_nodes_in_group("bow_projectile").is_empty(), "세 번째 발사 없음"): return false
	bow._skill_1_cooldown_s = 0
	_press_skill(0)
	bow._update_skill_action(0.17)
	var flying: BowProjectile = get_nodes_in_group("bow_projectile")[0]
	flying.set_physics_process(false)
	_interrupt_cast("double-after-first")
	bow._update_skill_action(1.0)
	if not _check(get_nodes_in_group("bow_projectile").size() == 1 and bow._skill_1_cooldown_s == 8 and not player._combat_action_active, "피격은 둘째 발사 취소·기존 화살 유지·8초 보존"): return false
	flying.free()
	player._input_lock_remaining_s = 0
	player.damage_receiver.tick(1.0)
	bow._skill_1_cooldown_s = 0
	_press_skill(0)
	weapons.active_weapon_id = "sword"
	weapons._apply_active_weapon()
	bow._update_skill_action(1.0)
	if not _check(get_nodes_in_group("bow_projectile").is_empty() and bow._action == BowCombatController.Action.NONE, "무기 전환은 발사 준비 취소"): return false
	player.relic_state = {"id": PrototypeRelic.CLOCK_ID, "used": false}
	weapons.sword_combat.set_active(false)
	sword._skill_1_cooldown_s = 7
	bow._skill_1_cooldown_s = 8
	sword._physics_process(5.6)
	bow._physics_process(6.4)
	return _check(is_zero_approx(sword._skill_1_cooldown_s) and is_zero_approx(bow._skill_1_cooldown_s), "시계추 두 새 기술 실제7→5.6초/8→6.4초 보조 무기 재사용")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-134 failed: " + message)
		paused = false
		quit(1)
	return condition
