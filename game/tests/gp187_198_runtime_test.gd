extends "res://tests/gp175_176_runtime_test.gd"

const GP187_198_SAVE := "user://gp187_198_checkpoint.json"
const GP187_198_META := "user://gp187_198_meta.jsonl"
const GP187_198_RECORD := "user://gp187_198_records.jsonl"
const GP187_198_BOOK := "user://gp187_198_abilities.jsonl"

var sword_id: String
var bow_id: String
const SWORDS := ["sword_flurry", "sword_cleave", "sword_twin_wave", "sword_sweep", "sword_backstep", "sword_alternating"]
const BOWS := ["bow_needle", "bow_heavy", "bow_wide_fan", "bow_storm", "bow_echo", "bow_seeking_volley"]

func _run() -> void:
	var pair := int(OS.get_cmdline_user_args()[1])
	sword_id = SWORDS[pair]
	bow_id = BOWS[pair]
	var phase := OS.get_cmdline_user_args()[0]
	store.save_path = GP187_198_SAVE + str(SWORDS.find(sword_id))
	legacy.save_path = GP187_198_META
	if phase == "seed" or phase.begins_with("combat") or phase == "flows":
		store.clear_checkpoint()
		for path in [GP187_198_META, GP187_198_RECORD, GP187_198_BOOK]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	var discoveries := AbilityDiscoveryStore.new()
	discoveries.save_path = GP187_198_BOOK
	sandbox.ability_discovery_store = discoveries
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP187_198_RECORD
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
			if not _check(PrototypeSkillRewards.CODEX_ORDER.size() == 34 and PrototypeSkillRewards.POOLS.sword.size() == 17 and PrototypeSkillRewards.POOLS.bow.size() == 17 and PrototypeSkillRewards.SKILLS.size() == 34 and PrototypeSkillRewards.CODEX_ORDER.slice(22, 28) == SWORDS and PrototypeSkillRewards.CODEX_ORDER.slice(28) == BOWS, "전체34종·이전22종 순서 보존·검/활 각17종"): return
			controls.begin_retry("sword", 5)
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "첫 정예 무기 유지"): return
			if not await _replace_mobility(sword_id, 1, true): return
			if not _check(weapons.skills.sword[1] == sword_id and weapons.sword_combat._skill_2_cooldown_s == PrototypeSkillRewards.SKILLS[sword_id].cooldown_s, "선회 베기 슬롯2·원본10초 대기"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "둘째 정예 무기 유지"): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[1].get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(player.relic_state.get("id", "") == PrototypeRelic.CLOCK_ID, "실제 시계추 선택"): return
			if not await _replace_mobility(bow_id, 0, true): return
			if not _check(weapons.skills.bow[0] == bow_id and weapons.bow_combat._skill_1_cooldown_s == PrototypeSkillRewards.SKILLS[bow_id].cooldown_s, "확산 관통 슬롯1·원본9초 대기"): return
			if not _test_mobility_save(): return
			if not await _test_skill_codex(true, 1.25): return
		"resume":
			if not _check(weapons.skills == PrototypeSkillRewards.defaults(), "복원 전 기본 스킬"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and runner.stage_number == 2 and runner.stage_limit == 5 and weapons.skills.sword[1] == sword_id and weapons.skills.bow[0] == bow_id and weapons.sword_combat._skill_2_cooldown_s == PrototypeSkillRewards.SKILLS[sword_id].cooldown_s and weapons.bow_combat._skill_1_cooldown_s == PrototypeSkillRewards.SKILLS[bow_id].cooldown_s and player.skill_recharge_multiplier() == 1.25, "별도 프로세스 반복 복원·양 슬롯/원본 대기/시계추/도전 길이 보존"): return
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
			if not _check(store.load_checkpoint().weapons.skills.sword[1] == sword_id and store.load_checkpoint().weapons.skills.bow[0] == bow_id, "5스테이지 보스 선택 대기에도 새 구성 저장"): return
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
			if not _test_sword_hits(1 if phase.ends_with("right") else -1): return
			if not _test_bow_hits(1 if phase.ends_with("right") else -1): return
		"flows":
			controls.begin_retry("sword")
			_configure_combat()
			if not _test_cancellation(): return
			if bow_id == "bow_seeking_volley" and not _tracking_series(): return
			if not await _test_cast_freeze("sword"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-187–198 runtime test: OK (" + phase + ")")
	quit(0)

func _files() -> Dictionary:
	var result := {}
	for path in [store.save_path, store.save_path + ".bak", GP187_198_META, GP187_198_RECORD, GP187_198_BOOK]:
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
		store.save_path = "user://gp187_198_missing/checkpoint.json"
		_tap(controls.skill_reward_confirm_rect.get_center())
		store.save_path = GP187_198_SAVE + str(SWORDS.find(sword_id))
		if not _check(weapons.checkpoint_snapshot() == before and store.load_checkpoint() == saved and not runner.skills_claimed, "이동 스킬 교체 실패·슬롯/대기/정상 저장 롤백"): return false
	_tap(controls.skill_reward_confirm_rect.get_center())
	return _check(weapons.skills[PrototypeSkillRewards.weapon_for(id)][slot] == id and runner.skills_claimed, "실제 슬롯 비교·교체 확정")

func _test_mobility_save() -> bool:
	var saved := store.load_checkpoint()
	for weapon in ["sword", "bow"]:
		var bad := saved.duplicate(true)
		bad.weapons.skills[weapon][0] = bow_id if weapon == "sword" else sword_id
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "다른 무기 기술 저장 거부·정상 저장 보호"): return false
		bad = saved.duplicate(true)
		bad.weapons.skills[weapon] = [sword_id, sword_id] if weapon == "sword" else [bow_id, bow_id]
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
	weapons.set_skill_loadout({"sword": [sword_id, "sword_spin"], "bow": [bow_id, "bow_arrow_rain"]})
	weapons.bow_combat.target_selector.set_physics_process(false)

func _new_target(key: String, offset: Vector2) -> PrototypeTarget:
	var target := _combat_target(key, player.global_position + offset)
	target.add_to_group("combat_enemy")
	return target

func _test_sword_hits(direction: int) -> bool:
	player.prepare_next_stage(Vector2(1000, 780))
	player.facing_direction = direction
	var actor := weapons.sword_combat
	var def: SkillDefinition = PrototypeSkillRewards.SKILLS[sword_id]
	actor.reset_combat()
	var front := _new_target("new-front", Vector2(140 * direction, 0))
	var rear := _new_target("new-rear", Vector2(-140 * direction, 0))
	var outside := _new_target("new-outside", Vector2((def.hit_range_m * 100 + 100) * direction, 200))
	ultimate.gauge = 0
	_press_skill(0)
	actor._update_skill_action(float(def.hit_times_s[0]) - 0.01)
	if not _check(front.damage_receiver.health == 1000 and actor._skill_1_cooldown_s == def.cooldown_s and not player.invincible, "실제 준비/원본 대기/추가 무적 없음"): return false
	if def.movement_distance_m < 0 and not _check(player._combat_horizontal_velocity_px * direction < 0, "물러 베기 실제 후퇴 속도"): return false
	player.facing_direction = -direction
	actor._update_skill_action(10)
	var expected_front := 0
	var expected_rear := 0
	var hits := 0
	if def.execution_style == &"wave":
		var waves := get_nodes_in_group("sword_wave")
		if not _check(waves.size() == 2, "쌍월 실제 검기2발"): return false
		for wave: SwordWave in waves:
			wave.set_physics_process(false)
			if not _check(wave.direction == direction and wave.attack_id == StringName(sword_id) and wave.max_distance_px == 700 and wave.max_hits == 2, "시전 고정·검기 출처/7m/2관통"): return false
			wave._physics_process(0.2)
			wave._check_hits()
			expected_front += 26
			hits += 1
			wave.free()
	else:
		for index in def.damage.size():
			var reverse := index < def.hit_directions.size() and def.hit_directions[index] == -1
			if def.execution_style == &"spin" or reverse:
				expected_rear += def.damage[index]
				hits += 1
			if def.execution_style == &"spin" or not reverse:
				expected_front += def.damage[index]
				hits += 1
	if not _check(front.damage_receiver.health == 1000 - expected_front and rear.damage_receiver.health == 1000 - expected_rear and outside.damage_receiver.health == 1000 and ultimate.gauge == mini(100, hits * 8) and not player._combat_action_active, "실제 앞/뒤/범위 밖·모든 타격·큰 프레임·게이지"): return false
	actor._update_skill_action(10)
	if not _check(front.damage_receiver.health == 1000 - expected_front, "종료 후 중복 타격 없음"): return false
	for t in [front, rear, outside]: t.free()
	return true

func _test_bow_hits(direction: int) -> bool:
	player.prepare_next_stage(Vector2(1000, 780))
	player.facing_direction = direction
	weapons.active_weapon_id = "bow"
	weapons._apply_active_weapon()
	var actor := weapons.bow_combat
	var def: SkillDefinition = PrototypeSkillRewards.SKILLS[bow_id]
	actor.reset_combat()
	actor.target_selector.current_target = null
	var anchor := _new_target("rain-anchor", Vector2(250 * direction, 0)) if def.execution_style == &"rain" else null
	if anchor != null: actor.target_selector.current_target = anchor
	_press_skill(0)
	actor._update_skill_action(float(def.hit_times_s[0]) - 0.01)
	if not _check(actor.projectile_fired_count == 0 and actor._skill_1_cooldown_s == def.cooldown_s, "발사 준비·원본 대기"): return false
	ultimate.gauge = 0
	actor._update_skill_action(10)
	if anchor != null:
		if not _check(anchor.damage_receiver.health == 940 and actor.skill_hit_count == 4 and ultimate.gauge == 32 and actor.last_combat_log.contains(def.display_name), "폭풍 실제 범위4타/총60/게이지32"): return false
		anchor.free()
	else:
		var shots := get_nodes_in_group("bow_projectile")
		var expected_count := def.damage.size() * (def.spread_angles_deg.size() if def.execution_style == &"spread" else 1)
		if not _check(shots.size() == expected_count and actor.projectile_fired_count == expected_count, "모든 실제 발사 수"): return false
		for i in shots.size():
			var shot: BowProjectile = shots[i]
			shot.set_physics_process(false)
			var expected := Vector2(direction, 0).rotated(deg_to_rad(def.spread_angles_deg[i])) if def.execution_style == &"spread" else Vector2(direction, 0)
			if not _check(shot.direction.is_equal_approx(expected) and shot.max_hits == def.max_targets and shot.max_distance_px == def.hit_range_m * 100 and shot.attack_id == StringName(bow_id), "실제 화살 방향·사거리·관통·출처"): return false
			var targets: Array[PrototypeTarget] = []
			for n in def.max_targets + 1:
				targets.append(_combat_target("new-arrow:%d:%d" % [i,n], shot.global_position + expected * (200 + n * 120) - PrototypeTarget.BODY_CENTER))
			for t in targets: t.add_to_group("combat_enemy")
			shot._check_hits(shot.global_position, shot.global_position + expected * 800)
			if shot is RicochetArrow:
				if not _check(shot.ricochet_range_px == 400 and shot.ricochet_damage == 18 and targets[0].damage_receiver.health == 972, "실제 첫28·주변4m·도탄18"): return false
				shot._check_hits(shot.global_position, targets[1].global_position + PrototypeTarget.BODY_CENTER)
				if not _check(targets[1].damage_receiver.health == 982 and targets[2].damage_receiver.health == 1000, "실제 한 번 도탄·세 번째 표적 제외"): return false
			else:
				shot._check_hits(shot.global_position, shot.global_position + expected * 800)
				for n in targets.size():
					if not _check(targets[n].damage_receiver.health == 1000 - (def.damage[0] if n < def.max_targets else 0), "최대관통·가까운 순서·중복 제외"): return false
			for t in targets: t.free()
			shot.free()
	actor._update_skill_action(10)
	return _check(not player._combat_action_active, "발사 후 행동 종료")

func _test_cast_freeze(weapon: String) -> bool:
	player.prepare_next_stage(Vector2(1000, 780))
	weapons.active_weapon_id = weapon
	weapons._apply_active_weapon()
	var id := sword_id if weapon == "sword" else bow_id
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
	for shot in get_nodes_in_group("bow_projectile") + get_nodes_in_group("sword_wave"): shot.free()
	return _check(not player._combat_action_active, "복귀 후 정상 시전 완료")

func _tracking_series() -> bool:
	player.prepare_next_stage(Vector2(1000, 780))
	weapons.active_weapon_id = "bow"
	weapons._apply_active_weapon()
	var actor := weapons.bow_combat
	actor.reset_combat()
	var target := _new_target("tracking-series", Vector2(250, 0))
	actor.target_selector.current_target = target
	_press_skill(0)
	actor._update_skill_action(0.17)
	var first: BowProjectile = get_nodes_in_group("bow_projectile").back()
	first.set_physics_process(false)
	if not _check(first._tracking_target != null and first._tracking_target.get_ref() == target, "추적 연사 첫 발 실제 표적 고정"): return false
	target.global_position.y -= 100
	actor._update_skill_action(0.18)
	var second: BowProjectile = get_nodes_in_group("bow_projectile").back()
	second.set_physics_process(false)
	if not _check(second._tracking_target.get_ref() == target and second.direction.y < first.direction.y, "같은 표적 이동에 다음 발 방향 갱신"): return false
	target.reset_target()
	actor._update_skill_action(0.18)
	var third: BowProjectile = get_nodes_in_group("bow_projectile").back()
	third.set_physics_process(false)
	if not _check(third._tracking_target == null and third.direction == Vector2.RIGHT and actor.projectile_fired_count == 3, "같은 노드의 다른 생명은 추적하지 않고 직진"): return false
	for shot in get_nodes_in_group("bow_projectile"): shot.free()
	target.free()
	actor._update_skill_action(10)
	return true
