extends "res://tests/gp157_runtime_test.gd"

const GP158_SAVE := "user://gp158_checkpoint.json"
const GP158_META := "user://gp158_meta.jsonl"
const GP158_RECORD := "user://gp158_records.jsonl"
const GP158_BOOK := "user://gp158_abilities.jsonl"

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	store.save_path = GP158_SAVE
	legacy.save_path = GP158_META
	if phase == "seed" or phase.begins_with("combat") or phase == "flows":
		store.clear_checkpoint()
		for path in [GP158_META, GP158_RECORD, GP158_BOOK]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	var discoveries := AbilityDiscoveryStore.new()
	discoveries.save_path = GP158_BOOK
	sandbox.ability_discovery_store = discoveries
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP158_RECORD
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
			if not _check(PrototypeSkillRewards.CODEX_ORDER.size() >= 18 and PrototypeSkillRewards.CODEX_ORDER.slice(16, 18) == ["bow_ricochet", "sword_cross"] and PrototypeSkillRewards.POOLS.sword.size() >= 9 and PrototypeSkillRewards.POOLS.bow.size() >= 9, "18종 도감·기존17종 순서 보존·검/활 각9종"): return
			if not _check(PrototypeSkillRewards.SKILLS.size() == PrototypeSkillRewards.POOLS.sword.size() + PrototypeSkillRewards.POOLS.bow.size() and PrototypeSkillRewards.POOLS.sword.has("sword_cross") and PrototypeSkillRewards.POOLS.bow.has("bow_ricochet"), "전체 스킬·검 교차/활 도탄 원본 보존"): return
			controls.begin_retry("sword", 5)
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "첫 정예 무기 유지"): return
			if not await _replace_mobility("sword_cross", 1, true): return
			if not _check(weapons.skills.sword[1] == "sword_cross" and weapons.sword_combat._skill_2_cooldown_s == 9, "실제 교차 슬롯2·원본9초 대기"): return
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
				if not _check(sandbox.continue_saved_run() and runner.stage_number == 2 and runner.stage_limit == 5 and weapons.skills.sword[1] == "sword_cross" and weapons.skills.bow[0] == "bow_ricochet" and weapons.sword_combat._skill_2_cooldown_s == 9 and weapons.bow_combat._skill_1_cooldown_s == 10 and player.skill_recharge_multiplier() == 1.25, "별도 프로세스 반복 복원·양 슬롯/원본 대기/시계추/도전 길이 보존"): return
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
			if not _check(store.load_checkpoint().weapons.skills.sword[1] == "sword_cross" and store.load_checkpoint().weapons.skills.bow[0] == "bow_ricochet", "5스테이지 보스 선택 대기에도 새 구성 저장"): return
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
			if not _test_cross_hits(1 if phase.ends_with("right") else -1): return
			if not _test_cross_boundaries(1 if phase.ends_with("right") else -1): return
		"flows":
			controls.begin_retry("sword")
			_configure_combat()
			if not _test_cross_cancel() or not _test_cross_damage(): return
			if not await _test_cast_freeze("sword"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-158 runtime test: OK (" + phase + ")")
	quit(0)

func _files() -> Dictionary:
	var result := {}
	for path in [GP158_SAVE, GP158_SAVE + ".bak", GP158_META, GP158_RECORD, GP158_BOOK]:
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
		store.save_path = "user://gp158_missing/checkpoint.json"
		_tap(controls.skill_reward_confirm_rect.get_center())
		store.save_path = GP158_SAVE
		if not _check(weapons.checkpoint_snapshot() == before and store.load_checkpoint() == saved and not runner.skills_claimed, "이동 스킬 교체 실패·슬롯/대기/정상 저장 롤백"): return false
	_tap(controls.skill_reward_confirm_rect.get_center())
	return _check(weapons.skills[PrototypeSkillRewards.weapon_for(id)][slot] == id and runner.skills_claimed, "실제 슬롯 비교·교체 확정")

func _test_mobility_save() -> bool:
	var saved := store.load_checkpoint()
	for weapon in ["sword", "bow"]:
		var bad := saved.duplicate(true)
		bad.weapons.skills[weapon][0] = "bow_ricochet" if weapon == "sword" else "sword_cross"
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "다른 무기 기술 저장 거부·정상 저장 보호"): return false
		bad = saved.duplicate(true)
		bad.weapons.skills[weapon] = ["sword_cross", "sword_cross"] if weapon == "sword" else ["bow_ricochet", "bow_ricochet"]
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
	weapons.set_skill_loadout({"sword": ["sword_cross", "sword_spin"], "bow": ["bow_ricochet", "bow_arrow_rain"]})
	weapons.bow_combat.target_selector.set_physics_process(false)

func _cross_target(key: String, offset: Vector2) -> PrototypeTarget:
	var target := _combat_target("gp158:" + key, Vector2(1000, 780) + offset)
	target.add_to_group("combat_enemy")
	target.damage_receiver.post_hit_invulnerability_s = 0
	return target

func _test_cross_hits(direction: int) -> bool:
	var actor := weapons.sword_combat
	var front := _cross_target("front", Vector2(direction * 150, 0))
	var rear := _cross_target("rear", Vector2(-direction * 150, 0))
	var crossing := _cross_target("crossing", Vector2(direction * 100, 0))
	var entrant := _cross_target("entrant", Vector2(-direction * 350, 0))
	var targets := [front, rear, crossing, entrant]
	ultimate.gauge = 0
	var before: int = actor.skill_hit_count
	_begin_cast("sword", direction)
	actor._update_skill_action(0.15)
	if not _check(targets.all(func(t: PrototypeTarget) -> bool: return t.damage_receiver.health == 1000) and actor._skill_1_cooldown_s == 9 and not player._combat_move_allowed and not player._combat_turn_allowed and not player.invincible, "실제 입력·9초 대기·0.16초 전 피해 없음·이동/방향 잠금·무적 없음"): return false
	player.set_move_vector(Vector2(-direction, 0))
	if not _check(player.facing_direction == direction and player._combat_horizontal_velocity_px == 0, "반대 이동 입력도 시선/강제 이동 불변"): return false
	player.facing_direction = -direction
	actor._update_skill_action(0.02)
	if not _check(front.damage_receiver.health == 968 and crossing.damage_receiver.health == 968 and rear.damage_receiver.health == 1000 and actor._line_direction == direction and actor._line_visual_direction == direction and ultimate.gauge == 16, "시전 방향 고정·정면만 실제32·유효2개체 충전16·정면 시각 효과"): return false
	crossing.global_position.x = 1000 - direction * 100
	entrant.global_position.x = 1000 - direction * 200
	actor._update_skill_action(0.18)
	if not _check(rear.damage_receiver.health == 1000 and entrant.damage_receiver.health == 1000, "0.36초 전 후방 피해 없음"): return false
	actor._update_skill_action(0.02)
	if not _check(front.damage_receiver.health == 968 and rear.damage_receiver.health == 956 and crossing.damage_receiver.health == 924 and entrant.damage_receiver.health == 956 and actor._line_direction == direction and actor._line_visual_direction == -direction and actor.skill_hit_count == before + 5 and ultimate.gauge == 40, "후방만44·실제 이동/새 진입 재평가·두 타격 이벤트 분리·후방 시각 효과"): return false
	var health := targets.map(func(t: PrototypeTarget) -> int: return t.damage_receiver.health)
	actor._update_skill_action(10)
	if not _check(targets.map(func(t: PrototypeTarget) -> int: return t.damage_receiver.health) == health and not player._combat_action_active and actor.skill_hit_count == before + 5, "큰 프레임 동작 종료·세 번째/중복 타격 없음"): return false
	for target in targets: target.free()
	# 한 프레임에 두 타격 시점이 지나가도 순서와 방향을 보존한다.
	front = _cross_target("large-front", Vector2(direction * 150, 0))
	rear = _cross_target("large-rear", Vector2(-direction * 150, 0))
	_begin_cast("sword", direction)
	actor._update_skill_action(1.0)
	if not _check(front.damage_receiver.health == 968 and rear.damage_receiver.health == 956 and not player._combat_action_active, "큰 프레임도32→44·각 방향 한 번"): return false
	front.free()
	rear.free()
	return true

func _test_cross_boundaries(direction: int) -> bool:
	var actor := weapons.sword_combat
	var targets: Array[PrototypeTarget] = []
	for side in [1, -1]:
		for offset in [Vector2(240, 90), Vector2(240.01, 0), Vector2(100, 90.01), Vector2(100, -90), Vector2(100, -90.01)]:
			targets.append(_cross_target("bounds", Vector2(offset.x * direction * side, offset.y)))
	var hidden := _cross_target("hidden", Vector2(direction * 120, 0))
	var dead := _cross_target("dead", Vector2(-direction * 120, 0))
	var blocked := _cross_target("blocked", Vector2(-direction * 180, 0))
	hidden.visible = false
	dead.damage_receiver.dead = true
	blocked.damage_receiver._post_hit_remaining_s = 1.0
	ultimate.gauge = 0
	_begin_cast("sword", direction)
	actor._update_skill_action(1.0)
	for i in targets.size():
		var expected := 1000 - (32 if i < 5 else 44) if i % 5 in [0, 3] else 1000
		if not _check(targets[i].damage_receiver.health == expected, "좌우2.4m/상하0.9m 경계 포함·경계 밖 제외"): return false
	if not _check([hidden, dead, blocked].all(func(t: PrototypeTarget) -> bool: return t.damage_receiver.health == 1000) and ultimate.gauge == 32, "숨김/사망/무적 피해 없음·유효4적중만 게이지32"): return false
	for target in targets + [hidden, dead, blocked]: target.free()
	# 기본 회전/정면 일섬의 범위와 기존 방향 규칙이 유지된다.
	weapons.set_skill_loadout({"sword": ["sword_line", "sword_spin"], "bow": weapons.skills.bow})
	var front := _cross_target("old-front", Vector2(direction * 150, 0))
	var rear := _cross_target("old-rear", Vector2(-direction * 150, 0))
	_begin_cast("sword", direction)
	actor._update_skill_action(1.0)
	if not _check(front.damage_receiver.health < 1000 and rear.damage_receiver.health == 1000 and actor._line_visual_direction == direction, "기존 일섬은 정면만·시각 방향 유지"): return false
	front.free()
	rear.free()
	return true

func _test_cross_cancel() -> bool:
	var actor := weapons.sword_combat
	for before_first in [true, false]:
		for reason in (["hit", "switch", "stage"] if before_first else ["evade", "hit", "switch", "stage"]):
			var front := _cross_target("cancel-front", Vector2(150, 0))
			var rear := _cross_target("cancel-rear", Vector2(-150, 0))
			_begin_cast("sword")
			player.request_evade()
			if not _check(player._combat_action_active and not player.invincible, "0.20초 전 회피 차단"): return false
			actor._update_skill_action(0.10 if before_first else 0.21)
			match reason:
				"evade": player.request_evade()
				"hit": _interrupt_cast("gp158:%s" % before_first)
				"switch":
					weapons.active_weapon_id = "bow"
					weapons._apply_active_weapon()
				"stage": actor.prepare_next_stage()
			actor._update_skill_action(1.0)
			if not _check(front.damage_receiver.health == (1000 if before_first else 968) and rear.damage_receiver.health == 1000 and not player._combat_action_active and actor._skill_1_cooldown_s == 9, "타격 전/타격 사이 %s/%s 취소·원본9초 유지 (HP%d/%d, action%d, cooldown%.2f)" % [before_first, reason, front.damage_receiver.health, rear.damage_receiver.health, actor._action, actor._skill_1_cooldown_s]): return false
			front.free()
			rear.free()
	player.relic_state = {"id": PrototypeRelic.CLOCK_ID, "used": false}
	actor.set_active(false)
	actor._skill_1_cooldown_s = 9
	actor._physics_process(7.2)
	return _check(is_zero_approx(actor._skill_1_cooldown_s) and PrototypeSkillRewards.lines("sword_cross", 1.25)[0].begins_with("재사용 7.2초"), "시계추 실제9→7.2초·도감 일치")

func _test_cross_damage() -> bool:
	player.relic_state = {"id": PrototypeRelic.EMBER_ID, "used": false}
	player.growth_common_bonus = 0.10
	player.growth_sword_bonus = 0.15
	player.set_lifesteal_unlocked(true)
	player.damage_receiver.health = 1
	player.lifesteal_progress = 0
	ultimate.gauge = 0
	var front := _cross_target("scaled-front", Vector2(150, 0))
	var rear := _cross_target("scaled-rear", Vector2(-150, 0))
	_begin_cast("sword")
	weapons.sword_combat._update_skill_action(1.0)
	if not _check(front.damage_receiver.health == 956 and rear.damage_receiver.health == 939 and ultimate.gauge == 16 and player.damage_receiver.health == 6 and player.lifesteal_progress == 5, "32/44에 성장1.25·불씨1.1 최종44/61·실제합105·흡수5/소수5·게이지16"): return false
	front.free()
	rear.free()
	player.relic_state = {"id": PrototypeRelic.HOURGLASS_ID, "used": false}
	player.growth_common_bonus = 0
	player.growth_sword_bonus = 0
	player.set_lifesteal_unlocked(false)
	growth.ranks.time_collector = 1
	growth.ranks.time_collector_boost = 1
	ultimate.set_time_collector_boost_unlocked(true)
	ultimate.gauge = 0
	front = _cross_target("kill-front", Vector2(150, 0))
	rear = _cross_target("kill-rear", Vector2(-150, 0))
	for target in [front, rear]:
		target.damage_receiver.health = 1
		target.defeated.connect(growth._on_enemy_defeated)
	_begin_cast("sword")
	weapons.sword_combat._update_skill_action(0.17)
	if not _resolve_growth(): return false
	weapons.sword_combat._update_skill_action(1.0)
	if not _check(front.damage_receiver.dead and rear.damage_receiver.dead and ultimate.gauge == 40, "실제 두 처치·모래시계 스킬10+강화 처치10 각각"): return false
	if not _resolve_growth(): return false
	front.free()
	rear.free()
	player.relic_state = {}
	return true

func _test_cast_freeze(weapon: String) -> bool:
	if weapon == "bow": return await super._test_cast_freeze(weapon)
	weapons.active_weapon_id = "sword"
	weapons._apply_active_weapon()
	player.prepare_next_stage(Vector2(1000, 780))
	player.damage_receiver.tick(1.0)
	player.facing_direction = 1
	var actor := weapons.sword_combat
	var slot: int = weapons.skills.sword.find("sword_cross")
	if not _check(slot >= 0, "실제 교체된 교차 베기 슬롯"): return false
	if slot == 0: actor._skill_1_cooldown_s = 0
	else: actor._skill_2_cooldown_s = 0
	var front := _cross_target("freeze-front", Vector2(150, 0))
	var rear := _cross_target("freeze-rear", Vector2(-150, 0))
	var expected_front := player.growth_damage(32, "sword", "skill")
	var expected_rear := player.growth_damage(44, "sword", "skill")
	_press_skill(slot)
	actor._update_skill_action(0.17)
	if not _check(front.damage_receiver.health == 1000 - expected_front and rear.damage_receiver.health == 1000, "실제 첫 타격 후 조회 준비"): return false
	actor.set_physics_process(true)
	var elapsed := actor._action_elapsed_s
	var before := weapons.checkpoint_snapshot()
	var files := _files()
	if not _check(controls.open_run_build() and paused, "두 타격 사이 실제 현재 도전 조회"): return false
	var cards := PrototypeRunBuildView.cards(1, controls.run_build_state)
	if not _check(cards.any(func(card: Dictionary) -> bool: return card.id == "sword_cross" and card.lines.has("정면 피해32 · 후방 피해44")), "현재 도전의 장착 슬롯/원본 피해 조회"): return false
	await create_timer(0.12, true).timeout
	if not _check(actor._action_elapsed_s == elapsed and actor._line_direction == 1 and actor._line_visual_direction == 1 and rear.damage_receiver.health == 1000 and weapons.checkpoint_snapshot() == before, "실제 프레임 타격/방향/대기 정지"): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(2.9)
	if not _check(paused and rear.damage_receiver.health == 1000, "3초 복귀 중 후방 피해 없음"): return false
	controls.advance_mode_timer_for_test(0.2)
	actor.set_physics_process(false)
	if not _check(not paused and _files() == files and weapons.checkpoint_snapshot() == before, "조회/복귀 저장·대기 무변경"): return false
	actor._update_skill_action(1.0)
	if not _check(front.damage_receiver.health == 1000 - expected_front and rear.damage_receiver.health == 1000 - expected_rear and actor._line_visual_direction == -1, "복귀 후 후방만 두 번째 피해·첫 타격 중복 없음"): return false
	front.free()
	rear.free()
	return true

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-158 failed: " + message)
		paused = false
		quit(1)
	return condition

