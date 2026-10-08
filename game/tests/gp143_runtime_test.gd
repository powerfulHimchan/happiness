extends "res://tests/gp134_runtime_test.gd"

const GP143_SAVE := "user://gp143_checkpoint.json"
const GP143_META := "user://gp143_meta.jsonl"
const GP143_RECORD := "user://gp143_records.jsonl"
const GP143_BOOK := "user://gp143_abilities.jsonl"

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	store.save_path = GP143_SAVE
	legacy.save_path = GP143_META
	if phase == "seed" or phase.begins_with("combat") or phase == "flows":
		store.clear_checkpoint()
		for path in [GP143_META, GP143_RECORD, GP143_BOOK]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	var discoveries := AbilityDiscoveryStore.new()
	discoveries.save_path = GP143_BOOK
	sandbox.ability_discovery_store = discoveries
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP143_RECORD
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
			if not _check(PrototypeSkillRewards.SKILLS.size() == 14 and PrototypeSkillRewards.POOLS.sword.size() == 7 and PrototypeSkillRewards.POOLS.bow.size() == 7, "14스킬·무기별7·도감5페이지"): return
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
			if not await _replace_mobility("bow_retreat", 0, true): return
			if not _check(weapons.skills.bow[0] == "bow_retreat" and weapons.bow_combat._skill_1_cooldown_s == 8, "실제 후퇴 슬롯1·원본8초 대기"): return
			if not _test_mobility_save(): return
			if not await _test_skill_codex(true, 1.25): return
		"resume":
			if not _check(weapons.skills == PrototypeSkillRewards.defaults(), "복원 전 기본 스킬"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and runner.stage_number == 2 and runner.stage_limit == 5 and weapons.skills.sword[1] == "sword_charge" and weapons.skills.bow[0] == "bow_retreat" and weapons.sword_combat._skill_2_cooldown_s == 9 and weapons.bow_combat._skill_1_cooldown_s == 8 and player.skill_recharge_multiplier() == 1.25, "별도 프로세스 반복 복원·양 슬롯/원본 대기/시계추/도전 길이 보존"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _test_cast_freeze("sword"): return
			if not await _test_cast_freeze("bow"): return
			while not runner.awaiting_boss_choice():
				if not _finish_stage(): return
				if runner.awaiting_boss_choice(): break
				if not _check(sandbox._claim_weapon_reward(""), "다음 정예 유지"): return
				_tap(controls.stage_route_rects[0].get_center())
			if not _check(store.load_checkpoint().weapons.skills.sword[1] == "sword_charge" and store.load_checkpoint().weapons.skills.bow[0] == "bow_retreat", "5스테이지 보스 선택 대기에도 새 구성 저장"): return
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
		"combat-sword", "combat-bow":
			controls.begin_retry("bow" if phase.ends_with("bow") else "sword")
			_configure_combat()
			var weapon := "bow" if phase.ends_with("bow") else "sword"
			if not _test_hits(weapon): return
			for direction in [1, -1]:
				if not await _test_motion(weapon, direction, false): return
				if not await _test_motion(weapon, direction, true): return
			if not _test_cancel(weapon): return
			if not await _test_cast_freeze(weapon): return
		"flows":
			controls.begin_retry()
			_configure_combat()
			if not _test_clock_and_switch(): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-143 runtime test: OK (" + phase + ")")
	quit(0)

func _files() -> Dictionary:
	var result := {}
	for path in [GP143_SAVE, GP143_SAVE + ".bak", GP143_META, GP143_RECORD, GP143_BOOK]:
		result[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return result

func _replace_mobility(id: String, slot: int, failure: bool) -> bool:
	_tap(controls.skill_reward_open_rect.get_center())
	var files := _files()
	if not await _test_candidates(): return false
	if not _check(_files() == files and PrototypeSkillRewards.offer_page_count(weapons.skills) == 5, "순환 조회는 저장 무변경·미보유5개 모두 비교"): return false
	for ignored in PrototypeSkillRewards.offer_page_count(weapons.skills):
		if id in _offer_ids(): break
		_tap(controls.skill_reward_cycle_rect.get_center())
	if not _check(id in _offer_ids(), "새 이동 스킬 실제 후보 등장"): return false
	_select_offer(id, slot)
	var saved := store.load_checkpoint()
	var before := weapons.checkpoint_snapshot()
	if failure:
		store.save_path = "user://gp143_missing/checkpoint.json"
		_tap(controls.skill_reward_confirm_rect.get_center())
		store.save_path = GP143_SAVE
		if not _check(weapons.checkpoint_snapshot() == before and store.load_checkpoint() == saved and not runner.skills_claimed, "이동 스킬 교체 실패·슬롯/대기/정상 저장 롤백"): return false
	_tap(controls.skill_reward_confirm_rect.get_center())
	return _check(weapons.skills[PrototypeSkillRewards.weapon_for(id)][slot] == id and runner.skills_claimed, "실제 슬롯 비교·교체 확정")

func _test_mobility_save() -> bool:
	var saved := store.load_checkpoint()
	for weapon in ["sword", "bow"]:
		var bad := saved.duplicate(true)
		bad.weapons.skills[weapon][0] = "bow_retreat" if weapon == "sword" else "sword_charge"
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "다른 무기 기술 저장 거부·정상 저장 보호"): return false
		bad = saved.duplicate(true)
		bad.weapons.skills[weapon] = ["sword_charge", "sword_charge"] if weapon == "sword" else ["bow_retreat", "bow_retreat"]
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
	weapons.set_skill_loadout({"sword": ["sword_charge", "sword_spin"], "bow": ["bow_retreat", "bow_arrow_rain"]})

func _actor(weapon: String) -> Node:
	return weapons.sword_combat if weapon == "sword" else weapons.bow_combat

func _begin_cast(weapon: String, direction: int = 1) -> void:
	weapons.active_weapon_id = weapon
	weapons._apply_active_weapon()
	player.prepare_next_stage(Vector2(1000, 780))
	player.damage_receiver.tick(1.0)
	player.facing_direction = direction
	player.set_move_vector(Vector2.ZERO)
	player._evade_cooldown_remaining_s = 0
	var actor := _actor(weapon)
	actor._skill_1_cooldown_s = 0
	_press_skill(0)

func _clear_shots() -> void:
	for shot in get_nodes_in_group("bow_projectile"): shot.free()

func _test_hits(weapon: String) -> bool:
	_begin_cast(weapon)
	var actor := _actor(weapon)
	if weapon == "sword":
		var front := _combat_target("charge-front", Vector2(1100, 780))
		var moving := _combat_target("charge-moved", Vector2(1350, 780))
		var behind := _combat_target("charge-behind", Vector2(920, 780))
		var high := _combat_target("charge-high", Vector2(1100, 709))
		for target in [front, moving, behind, high]: target.damage_receiver.post_hit_invulnerability_s = 0
		actor._update_skill_action(0.09)
		if not _check(front.damage_receiver.health == 1000 and not player.invincible, "돌파0.1초 전·새 무적 없음"): return false
		actor._update_skill_action(0.02)
		if not _check(front.damage_receiver.health == 982 and moving.damage_receiver.health == 1000 and behind.damage_receiver.health == 1000 and high.damage_receiver.health == 1000, "돌파 첫 실제18·거리/후방/높이 제외"): return false
		player.global_position.x += 240
		actor._update_skill_action(0.20)
		if not _check(front.damage_receiver.health == 982 and moving.damage_receiver.health == 978 and actor.skill_hit_count == 2, "둘째 실제22는 이동한 현재 위치에서 판정"): return false
		actor._update_skill_action(0.50)
		for target in [front, moving, behind, high]: target.visible = false
	else:
		var first := _combat_target("retreat-first", Vector2(1300, 780))
		var second := _combat_target("retreat-second", Vector2(1500, 780))
		for target in [first, second]: target.damage_receiver.post_hit_invulnerability_s = 0
		actor.target_selector.current_target = second
		actor._update_skill_action(0.07)
		if not _check(get_nodes_in_group("bow_projectile").is_empty(), "후퇴0.08초 전 화살 없음"): return false
		var ids: Array[String] = []
		for index in 2:
			actor._update_skill_action(0.02 if index == 0 else 0.18)
			var shots := get_nodes_in_group("bow_projectile")
			if not _check(shots.size() == 1, "0.08/0.26초 각 한 발"): return false
			var shot: BowProjectile = shots[0]
			shot.set_physics_process(false)
			ids.append(shot.projectile_id)
			if not _check(shot.damage == 24 and shot.max_hits == 1 and shot.direction == Vector2.RIGHT and shot.attack_id == &"bow_retreat", "후퇴 원본24·최대1개체·시전 방향 고정"): return false
			shot._check_hits(shot.global_position, second.global_position + Vector2(0, -38))
			shot._check_hits(shot.global_position, second.global_position + Vector2(0, -38))
			if not _check(first.damage_receiver.health == 1000 - 24 * (index + 1) and second.damage_receiver.health == 1000, "두 화살 독립 타격·반복 충돌/관통 추가 피해 없음"): return false
			shot.free()
			player.global_position.x -= 100
			player.facing_direction = -1
			actor.target_selector.current_target = null
		if not _check(ids[0] != ids[1], "독립 화살 공격ID"): return false
		actor._update_skill_action(0.50)
		if not _check(get_nodes_in_group("bow_projectile").is_empty(), "세 번째 발사 없음"): return false
		first.visible = false
		second.visible = false
	return _check(not player._combat_action_active and player._combat_horizontal_velocity_px == 0, "동작 종료는 강제 이동 해제")

func _test_motion(weapon: String, direction: int, wall: bool) -> bool:
	_begin_cast(weapon, direction)
	var actor := _actor(weapon)
	var sign := direction * (-1 if weapon == "bow" else 1)
	var obstacle: StaticBody2D
	if wall:
		obstacle = StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(20, 1200)
		shape.shape = rectangle
		obstacle.add_child(shape)
		obstacle.position = Vector2(1000 + sign * 100, 500)
		sandbox.add_child(obstacle)
	var start := player.global_position.x
	player.set_move_vector(Vector2(-direction, 0))
	if not _check(player.facing_direction == direction and not player._combat_move_allowed and not player._combat_turn_allowed and not player.invincible, "조작 반전은 스킬 이동/방향을 바꾸지 않고 무적을 주지 않음"): return false
	player.set_physics_process(true)
	var definition: SkillDefinition = actor.skill_1
	for ignored in int(round(definition.duration_s * 60)) + 1:
		await physics_frame
		actor._update_skill_action(1.0 / 60.0)
		for shot in get_nodes_in_group("bow_projectile"): shot.set_physics_process(false)
	player.set_physics_process(false)
	player.set_move_vector(Vector2.ZERO)
	var distance: float = (player.global_position.x - start) * sign
	if wall:
		if not _check(distance >= 0 and distance < 100, "양방향 실제 벽 충돌·벽 관통 없음"): return false
		obstacle.free()
	else:
		if not _check(absf(distance - absf(definition.movement_distance_m) * PrototypePlayer.PIXELS_PER_METER) < 24, "실제 물리 프레임의 전진2.4m/후퇴1.8m"): return false
	_clear_shots()
	return _check(not player._combat_action_active and player._combat_horizontal_velocity_px == 0, "이동 동작 종료·방향별 강제 이동 해제")

func _test_cancel(weapon: String) -> bool:
	_begin_cast(weapon)
	var actor := _actor(weapon)
	var cooldown: float = actor.skill_1.cooldown_s
	player.request_evade()
	if not _check(player._combat_action_active and not player.invincible, "취소 가능 시점 전 회피 차단"): return false
	_interrupt_cast("gp143:" + weapon)
	actor._update_skill_action(1.0)
	if not _check(not player._combat_action_active and player._combat_horizontal_velocity_px == 0 and actor._skill_1_cooldown_s == cooldown and get_nodes_in_group("bow_projectile").is_empty(), "피격은 이동·예정 타격 취소·대기 유지"): return false
	_begin_cast(weapon)
	actor._update_skill_action(0.16)
	for shot in get_nodes_in_group("bow_projectile"): shot.set_physics_process(false)
	var shots := get_nodes_in_group("bow_projectile").size()
	player.request_evade()
	actor._update_skill_action(1.0)
	if not _check(not player._combat_action_active and player._combat_horizontal_velocity_px == 0 and actor._skill_1_cooldown_s == cooldown and get_nodes_in_group("bow_projectile").size() == shots, "허용 시점 뒤 회피 취소·두 번째 타격/발사 없음·기존 화살 유지"): return false
	_clear_shots()
	return true

func _test_cast_freeze(weapon: String) -> bool:
	# 이어하기의 실제 교체 슬롯과 전투 시제품의 슬롯1을 모두 사용한다.
	weapons.active_weapon_id = weapon
	weapons._apply_active_weapon()
	player.prepare_next_stage(Vector2(1000, 780))
	player.damage_receiver.tick(1.0)
	var actor := _actor(weapon)
	var slot: int = weapons.skills[weapon].find("sword_charge" if weapon == "sword" else "bow_retreat")
	if not _check(slot >= 0, "조회 정지 검사 실제 새 스킬 장착"): return false
	if slot == 0: actor._skill_1_cooldown_s = 0
	else: actor._skill_2_cooldown_s = 0
	_press_skill(slot)
	actor._update_skill_action(0.04)
	actor.set_physics_process(true)
	player.set_physics_process(true)
	var position := player.global_position
	var elapsed: float = actor._action_elapsed_s
	var before := weapons.checkpoint_snapshot()
	var files := _files()
	if not _check(controls.open_run_build() and paused, "시전 중 실제 도전 상태 진입"): return false
	await create_timer(0.12, true).timeout
	if not _check(player.global_position == position and actor._action_elapsed_s == elapsed and weapons.checkpoint_snapshot() == before and get_nodes_in_group("bow_projectile").is_empty(), "실제 프레임 동안 이동/공격/발사/대기 정지"): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(2.9)
	if not _check(paused and player.global_position == position, "복귀 카운트다운 중 이동 정지"): return false
	controls.advance_mode_timer_for_test(0.2)
	actor.set_physics_process(false)
	player.set_physics_process(false)
	if not _check(not paused and _files() == files and actor._action_elapsed_s == elapsed and weapons.checkpoint_snapshot() == before, "복귀는 시전/대기/저장 변경 없음"): return false
	actor._update_skill_action(1.0)
	_clear_shots()
	return true

func _test_clock_and_switch() -> bool:
	for weapon in ["sword", "bow"]:
		_begin_cast(weapon)
		var actor := _actor(weapon)
		var original: float = actor._skill_1_cooldown_s
		weapons.active_weapon_id = "bow" if weapon == "sword" else "sword"
		weapons._apply_active_weapon()
		actor._update_skill_action(1.0)
		if not _check(not player._combat_action_active and player._combat_horizontal_velocity_px == 0 and actor._skill_1_cooldown_s == original and get_nodes_in_group("bow_projectile").is_empty(), "강제 무기 전환은 이동과 예정 타격 취소·대기 보존"): return false
	player.relic_state = {"id": PrototypeRelic.CLOCK_ID, "used": false}
	weapons.sword_combat.set_active(false)
	weapons.bow_combat.set_active(false)
	weapons.sword_combat._skill_1_cooldown_s = 9
	weapons.bow_combat._skill_1_cooldown_s = 8
	weapons.sword_combat._physics_process(7.2)
	weapons.bow_combat._physics_process(6.4)
	return _check(is_zero_approx(weapons.sword_combat._skill_1_cooldown_s) and is_zero_approx(weapons.bow_combat._skill_1_cooldown_s), "시계추 양 무기 원본9→7.2/8→6.4·보조에도 적용")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-143 failed: " + message)
		paused = false
		quit(1)
	return condition
