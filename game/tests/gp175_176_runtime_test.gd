extends "res://tests/gp158_runtime_test.gd"

const GP175_176_SAVE := "user://gp175_176_checkpoint.json"
const GP175_176_META := "user://gp175_176_meta.jsonl"
const GP175_176_RECORD := "user://gp175_176_records.jsonl"
const GP175_176_BOOK := "user://gp175_176_abilities.jsonl"

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	store.save_path = GP175_176_SAVE
	legacy.save_path = GP175_176_META
	if phase == "seed" or phase.begins_with("combat") or phase == "flows":
		store.clear_checkpoint()
		for path in [GP175_176_META, GP175_176_RECORD, GP175_176_BOOK]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	var discoveries := AbilityDiscoveryStore.new()
	discoveries.save_path = GP175_176_BOOK
	sandbox.ability_discovery_store = discoveries
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP175_176_RECORD
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
			if not _check(PrototypeSkillRewards.CODEX_ORDER.size() == 20 and PrototypeSkillRewards.CODEX_ORDER.slice(18, 20) == ["sword_rising", "bow_chain"] and PrototypeSkillRewards.POOLS.sword.size() >= 9 and PrototypeSkillRewards.POOLS.bow.size() >= 9, "20종 도감·기존18종 순서 보존·검/활 각10종"): return
			if not _check(PrototypeSkillRewards.SKILLS.size() == PrototypeSkillRewards.POOLS.sword.size() + PrototypeSkillRewards.POOLS.bow.size() and PrototypeSkillRewards.POOLS.sword.has("sword_rising") and PrototypeSkillRewards.POOLS.bow.has("bow_chain"), "전체 스킬·올려 베기/연쇄 관통 원본 등록"): return
			controls.begin_retry("sword", 5)
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "첫 정예 무기 유지"): return
			if not await _replace_mobility("sword_rising", 1, true): return
			if not _check(weapons.skills.sword[1] == "sword_rising" and weapons.sword_combat._skill_2_cooldown_s == 8, "올려 베기 슬롯2·원본8초 대기"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "둘째 정예 무기 유지"): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[1].get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(player.relic_state.get("id", "") == PrototypeRelic.CLOCK_ID, "실제 시계추 선택"): return
			if not await _replace_mobility("bow_chain", 0, true): return
			if not _check(weapons.skills.bow[0] == "bow_chain" and weapons.bow_combat._skill_1_cooldown_s == 9, "연쇄 관통 슬롯1·원본9초 대기"): return
			if not _test_mobility_save(): return
			if not await _test_skill_codex(true, 1.25): return
		"resume":
			if not _check(weapons.skills == PrototypeSkillRewards.defaults(), "복원 전 기본 스킬"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and runner.stage_number == 2 and runner.stage_limit == 5 and weapons.skills.sword[1] == "sword_rising" and weapons.skills.bow[0] == "bow_chain" and weapons.sword_combat._skill_2_cooldown_s == 8 and weapons.bow_combat._skill_1_cooldown_s == 9 and player.skill_recharge_multiplier() == 1.25, "별도 프로세스 반복 복원·양 슬롯/원본 대기/시계추/도전 길이 보존"): return
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
			if not _check(store.load_checkpoint().weapons.skills.sword[1] == "sword_rising" and store.load_checkpoint().weapons.skills.bow[0] == "bow_chain", "5스테이지 보스 선택 대기에도 새 구성 저장"): return
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
			if not _test_rising_hits(1 if phase.ends_with("right") else -1): return
			if not _test_chain_hits(1 if phase.ends_with("right") else -1): return
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
	print("GP-175/176 runtime test: OK (" + phase + ")")
	quit(0)

func _files() -> Dictionary:
	var result := {}
	for path in [GP175_176_SAVE, GP175_176_SAVE + ".bak", GP175_176_META, GP175_176_RECORD, GP175_176_BOOK]:
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
		store.save_path = "user://gp175_176_missing/checkpoint.json"
		_tap(controls.skill_reward_confirm_rect.get_center())
		store.save_path = GP175_176_SAVE
		if not _check(weapons.checkpoint_snapshot() == before and store.load_checkpoint() == saved and not runner.skills_claimed, "이동 스킬 교체 실패·슬롯/대기/정상 저장 롤백"): return false
	_tap(controls.skill_reward_confirm_rect.get_center())
	return _check(weapons.skills[PrototypeSkillRewards.weapon_for(id)][slot] == id and runner.skills_claimed, "실제 슬롯 비교·교체 확정")

func _test_mobility_save() -> bool:
	var saved := store.load_checkpoint()
	for weapon in ["sword", "bow"]:
		var bad := saved.duplicate(true)
		bad.weapons.skills[weapon][0] = "bow_chain" if weapon == "sword" else "sword_rising"
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "다른 무기 기술 저장 거부·정상 저장 보호"): return false
		bad = saved.duplicate(true)
		bad.weapons.skills[weapon] = ["sword_rising", "sword_rising"] if weapon == "sword" else ["bow_chain", "bow_chain"]
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
	weapons.set_skill_loadout({"sword": ["sword_rising", "sword_spin"], "bow": ["bow_chain", "bow_arrow_rain"]})
	weapons.bow_combat.target_selector.set_physics_process(false)

func _new_target(key: String, offset: Vector2) -> PrototypeTarget:
	var target := _combat_target(key, player.global_position + offset)
	target.add_to_group("combat_enemy")
	return target

func _test_rising_hits(direction: int) -> bool:
	player.prepare_next_stage(Vector2(1000, 780))
	player.facing_direction = direction
	var actor := weapons.sword_combat
	actor.reset_combat()
	var high := _new_target("rising-high", Vector2(160 * direction, -170))
	var edge := _new_target("rising-edge", Vector2(180 * direction, -180))
	var low := _new_target("rising-low", Vector2(150 * direction, 41))
	var rear := _new_target("rising-rear", Vector2(-120 * direction, -100))
	var outside := _new_target("rising-outside", Vector2(181 * direction, -100))
	ultimate.gauge = 0
	_press_skill(0)
	actor._update_skill_action(0.21)
	if not _check(high.damage_receiver.health == 1000 and actor._skill_1_cooldown_s == 8 and not player.invincible, "올려 베기 준비0.22초·8초 대기·추가 무적 없음"): return false
	player.facing_direction = -direction
	actor._update_skill_action(0.02)
	if not _check(high.damage_receiver.health == 958 and edge.damage_receiver.health == 958 and low.damage_receiver.health == 1000 and rear.damage_receiver.health == 1000 and outside.damage_receiver.health == 1000 and ultimate.gauge == 16, "상승 영역/경계/시전 방향 고정·실제42피해/적중 게이지"): return false
	actor._update_skill_action(10)
	if not _check(high.damage_receiver.health == 958 and not player._combat_action_active, "큰 프레임에서 타격 중복 없음·행동 해제"): return false
	for t in [high, edge, low, rear, outside]: t.free()
	return true

func _chain_shot() -> BowProjectile:
	weapons.bow_combat._spawn_projectile("chain:stale", &"bow_chain", 18, 2, Vector2.RIGHT, PackedStringArray(["bow", "skill"]))
	var shot: BowProjectile = get_nodes_in_group("bow_projectile").back()
	shot.set_physics_process(false)
	return shot

func _test_chain_hits(direction: int) -> bool:
	player.prepare_next_stage(Vector2(1000, 780))
	player.facing_direction = direction
	weapons.active_weapon_id = "bow"
	weapons._apply_active_weapon()
	var actor := weapons.bow_combat
	actor.reset_combat()
	actor.target_selector.current_target = null
	var a := _new_target("chain-a", Vector2(200 * direction, 0))
	var b := _new_target("chain-b", Vector2(300 * direction, 0))
	var c := _new_target("chain-c", Vector2(400 * direction, 0))
	ultimate.gauge = 0
	_press_skill(0)
	actor._update_skill_action(0.15)
	if not _check(actor.projectile_fired_count == 0 and actor._skill_1_cooldown_s == 9, "연쇄 준비/9초 원본 대기"): return false
	for step in [0.02, 0.22, 0.22]:
		actor._update_skill_action(step)
		var shots := get_nodes_in_group("bow_projectile")
		if not _check(shots.size() == 1, "각 시점 실제 화살 한발 생성"): return false
		var shot: BowProjectile = shots[0]
		shot.set_physics_process(false)
		shot._check_hits(shot.global_position, c.global_position + Vector2(0, -38))
		shot._check_hits(shot.global_position, c.global_position + Vector2(0, -38))
		if not _check(shot._hit_count == 2 and shot.max_hits == 2, "화살마다 가까운 두개체만·중복 충돌 없음"): return false
		shot.free()
	if not _check(a.damage_receiver.health == 946 and b.damage_receiver.health == 946 and c.damage_receiver.health == 1000 and ultimate.gauge == 48 and actor.projectile_fired_count == 3, "실제3발×18·각2관통·적중48게이지"): return false
	actor._update_skill_action(10)
	if not _check(actor.projectile_fired_count == 3 and not player._combat_action_active, "큰 프레임 발사 중복 없음·행동 해제"): return false
	for t in [a, b, c]: t.free()
	return true

func _test_cancellation() -> bool:
	for weapon in ["sword", "bow"]:
		player.prepare_next_stage(Vector2(1000, 780))
		weapons.active_weapon_id = weapon
		weapons._apply_active_weapon()
		var actor = weapons.sword_combat if weapon == "sword" else weapons.bow_combat
		actor.reset_combat()
		_press_skill(0)
		actor.set_active(false)
		actor._update_skill_action(1.0)
		if not _check(actor._action == 0 and get_nodes_in_group("bow_projectile").is_empty(), "발사 전 전환 취소·원본 대기 유지"): return false
		actor.set_active(true)
		var remaining: float = actor._skill_1_cooldown_s
		_press_skill(0)
		if not _check(actor._action == 0 and actor._skill_1_cooldown_s == remaining, "반복 전환 재시전 대기 우회 없음"): return false
	return true

func _test_cast_freeze(weapon: String) -> bool:
	player.prepare_next_stage(Vector2(1000, 780))
	weapons.active_weapon_id = weapon
	weapons._apply_active_weapon()
	var id := "sword_rising" if weapon == "sword" else "bow_chain"
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
