extends "res://tests/gp327_runtime_test.gd"

const NEW_SKILLS := ["fist_rising", "fist_cross", "fist_advancing", "staff_ember_volley", "staff_frost_ring", "staff_thunder_echo", "polearm_windwheel", "polearm_retreat", "shield_rush", "shield_ring"]
var combat: SwordCombatController
var skill_id: String
var character: String
var facing: int
var family: String
var test_targets: Array[PrototypeTarget] = []

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	skill_id = args[1]
	character = args[2]
	facing = int(args[3])
	family = PrototypeSkillRewards.weapon_for(skill_id)
	if not _check(skill_id in NEW_SKILLS and facing in [-1,1], "유효한 검사 인자"): return
	var prefix := "user://gp384_%s_%s_%d" % [skill_id,character,facing]
	store.save_path = prefix + "_checkpoint.json"
	legacy.save_path = prefix + "_meta.jsonl"
	journal.save_path = prefix + "_story.jsonl"
	if phase != "resume":
		store.clear_checkpoint()
		for suffix in ["_meta.jsonl", "_records.jsonl", "_abilities.jsonl", "_story.jsonl"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.story_journal_store = journal
	var book := AbilityDiscoveryStore.new()
	book.save_path = prefix + "_abilities.jsonl"
	sandbox.ability_discovery_store = book
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.get_node("LocalTestRecorder").record_path = prefix + "_records.jsonl"
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	combat = weapons.combat_for(family)
	for actor in [player, weapons, runner, sandbox.get_node("Player/UltimateController"), sandbox.get_node("ClockTrapController"), sandbox.get_node("RouteTerrain")]:
		actor.set_process(false)
		actor.set_physics_process(false)
	for id in PrototypeWeaponRewards.FAMILY_IDS:
		weapons.combat_for(id).set_process(false)
		weapons.combat_for(id).set_physics_process(false)
	sandbox.get_node("CombatFeedbackController").configure(0.0,false,false)
	if phase == "resume":
		var saved := store.load_checkpoint()
		for ignored in 2:
			controls.show_main_screen()
			var resumed: bool = sandbox.continue_saved_run()
			if not _check(resumed and weapons.skills[family][1] == skill_id and player.character_id == character and combat._skill_2_cooldown_s == saved.weapons[family]._skill_2_cooldown_s and _weapons_restored(saved.weapons), "별도 프로세스 반복 이어하기·양 슬롯·대기시간 보존"): return
	else:
		if not _check(controls.begin_retry(family,3,"standard",character,false,0,"sword"), "새 계열 도전 시작"): return
		match phase:
			"seed":
				if not await _reward_save(): return
			"combat":
				if not _combat_and_edges(): return
				if not _cancellations(): return
			"render":
				if not await _render_view(): return
			_:
				_check(false,"알 수 없는 단계")
				return
	paused = false
	sandbox.free()
	print("GP-375–384 runtime test: OK (%s %s %s %d)" % [phase,skill_id,character,facing])
	quit(0)

func _reward_save() -> bool:
	if not _finish_stage() or not sandbox._claim_weapon_reward(""): return false
	var saved := store.load_checkpoint()
	var before := weapons.checkpoint_snapshot()
	var candidates: Array[String] = []
	for page in PrototypeSkillRewards.offer_page_count(weapons.skills):
		for card in PrototypeSkillRewards.offers(weapons.skills,page):
			if card.id not in candidates: candidates.append(card.id)
	if not _check(skill_id in candidates and store.load_checkpoint() == saved and weapons.checkpoint_snapshot() == before, "모든 보상 후보에서 새 스킬 발견·조회 무변경"): return false
	_tap(controls.skill_reward_open_rect.get_center())
	for ignored in PrototypeSkillRewards.offer_page_count(weapons.skills):
		if controls.skill_reward_offers.any(func(card: Dictionary) -> bool: return card.id == skill_id): break
		_tap(controls.skill_reward_cycle_rect.get_center())
	if not _check(controls.skill_reward_offers.any(func(card: Dictionary) -> bool: return card.id == skill_id), "실제 후보 페이지에서 새 스킬 선택"): return false
	var path := store.save_path
	store.save_path = "user://gp384_missing/checkpoint.json"
	var rejected: bool = not sandbox._claim_skill_reward(skill_id,1)
	store.save_path = path
	if not _check(rejected and weapons.checkpoint_snapshot() == before and not runner.skills_claimed and store.load_checkpoint() == saved, "스킬 교체 저장 실패는 슬롯·대기시간·보상 되돌림"): return false
	if not _check(sandbox._claim_skill_reward(skill_id,1) and weapons.skills[family][1] == skill_id and combat._skill_2_cooldown_s == PrototypeSkillRewards.SKILLS[skill_id].cooldown_s, "실제 보상 교체·원본 대기시간"): return false
	saved = store.load_checkpoint()
	if not _check(RunCheckpointStore.valid_state(saved), "신규 스킬 체크포인트 검증"): return false
	var bad := saved.duplicate(true)
	bad.weapons.skills.sword[0] = skill_id
	if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "다른 무기 슬롯에 주입한 스킬 저장 거부"): return false
	var cards := PrototypeSkillRewards.codex_cards(weapons.skills,1.25)
	var own: Array = cards.filter(func(card: Dictionary) -> bool: return card.id == skill_id)
	if not _check(cards.size() == 56 and own.size() == 1 and own[0].open and own[0].status == "이번 도전 · 슬롯 2" and own[0].lines[0].contains("%.1f초" % (PrototypeSkillRewards.SKILLS[skill_id].cooldown_s/1.25)), "56종 도감·장착 슬롯·시계추 표시"): return false
	return true

func _target_at(key: String, offset: Vector2) -> PrototypeTarget:
	var target := PrototypeTarget.new()
	target.target_key = "gp384:" + key
	for label in ["BodySprite","SelectionSprite"]:
		var sprite := Sprite2D.new()
		sprite.name = label
		target.add_child(sprite)
	var health := ProgressBar.new()
	health.name = "HealthBar"
	target.add_child(health)
	var status := Label.new()
	status.name = "StatusLabel"
	target.add_child(status)
	var receiver := DamageReceiver.new()
	receiver.name = "DamageReceiver"
	receiver.max_health = 10000
	receiver.post_hit_invulnerability_s = 0
	target.add_child(receiver)
	sandbox.add_child(target)
	target.set_process(false)
	target.global_position = player.global_position + Vector2(offset.x*facing,offset.y)
	test_targets.append(target)
	return target

func _setup_cast() -> void:
	paused = false
	for target in get_nodes_in_group("targetable"):
		target.visible = false
		target.set_process(false)
		target.set_physics_process(false)
	player.reset_movement_test(sandbox.TRACK_START)
	player.facing_direction = facing
	combat.reset_combat()
	var loadout := weapons.skills.duplicate(true)
	loadout[family][0] = skill_id
	weapons.set_skill_loadout(loadout)

func _drain_bolts() -> void:
	for bolt in get_nodes_in_group("staff_magic_bolt"):
		bolt.set_physics_process(false)
		bolt._physics_process(1.2)
		bolt.free()

func _combat_and_edges() -> bool:
	_setup_cast()
	var target := _target_at("front",Vector2(100,0))
	var rear := _target_at("rear",Vector2(-100,0))
	var outside := _target_at("outside",Vector2(950,0))
	weapons.target_selector.current_target = target
	var definition: SkillDefinition = PrototypeSkillRewards.SKILLS[skill_id]
	weapons.request_skill_1()
	if not _check(combat._action != SwordCombatController.Action.NONE and combat._skill_1_cooldown_s == definition.cooldown_s and is_equal_approx(player._combat_horizontal_velocity_px, definition.movement_distance_m*100/definition.duration_s*facing), "실제 시전·대기시간·전진/후퇴 속도"): return false
	var sequence := combat._action_sequence
	weapons.request_skill_1()
	if not _check(combat._action_sequence == sequence, "사용 중 재시전 차단"): return false
	# Anchor spells must stay at cast position when the selected target moves away.
	if skill_id == "staff_thunder_echo":
		target.global_position.x += 700*facing
		rear.global_position = player.global_position + Vector2(100*facing,0)
	combat._update_skill_action(definition.duration_s + 0.01)
	_drain_bolts()
	var expected := 0
	for damage in definition.damage: expected += damage
	if not _check(target.damage_receiver.health == (10000 if skill_id == "staff_thunder_echo" else 10000-(40 if skill_id == "fist_cross" else expected)) and outside.damage_receiver.health == 10000, "큰 프레임의 모든 타격·실제 피해 합산·범위 밖 제외"): return false
	var rear_expected := expected if definition.execution_style == &"spin" or skill_id == "staff_thunder_echo" else 16 if skill_id == "fist_cross" else 0
	var front_expected := 40 if skill_id == "fist_cross" else expected
	if skill_id == "fist_cross" and not _check(target.damage_receiver.health == 10000-front_expected, "교차연권 정면 두 타격"): return false
	if not _check(rear.damage_receiver.health == 10000-rear_expected and player.facing_direction == facing, "후방/주변 판정·시전 방향 유지"): return false
	var health := target.damage_receiver.health
	combat._physics_process(0.0)
	if not _check(target.damage_receiver.health == health and combat.skill_hit_count > 0, "동일 타격 재적용 차단·실제 적중 집계"): return false
	if skill_id == "staff_ember_volley" and not _check(combat.projectile_fired_count == 3 and combat.skill_hit_count == 3, "연속 화염탄별 고유 적중 ID·세 발 모두 피해 적용"): return false
	if skill_id == "fist_rising":
		if not _uppercut_edges(): return false
	if family == "shield" and not _shield_rules(): return false
	if family == "polearm" and not _polearm_rules(): return false
	return true

func _uppercut_edges() -> bool:
	_setup_cast()
	var upper := _target_at("upper",Vector2(140,-180))
	var lower := _target_at("lower",Vector2(100,35))
	var below := _target_at("below",Vector2(100,36))
	var high := _target_at("high",Vector2(100,-181))
	weapons.request_skill_1()
	combat._update_skill_action(.56)
	return _check(upper.damage_receiver.health == 9956 and lower.damage_receiver.health == 9956 and below.damage_receiver.health == 10000 and high.damage_receiver.health == 10000, "승천권 위1.8m/아래0.35m 경계 포함·밖 제외")

func _incoming(front: bool, trap: bool = false) -> DamageEvent:
	var event := DamageEvent.new()
	event.event_id = StringName("gp384:%d" % Time.get_ticks_usec())
	event.damage = 40
	event.tags = PackedStringArray(["enemy","trap"]) if trap else PackedStringArray(["enemy"])
	event.source_position = player.global_position + Vector2((100 if front else -100)*facing,0)
	return event

func _shield_rules() -> bool:
	_setup_cast()
	player.damage_receiver.post_hit_invulnerability_s = 0
	weapons.request_skill_1()
	var shield := combat as ShieldCombatController
	if skill_id == "shield_rush":
		if not _check(shield._guard_multiplier(_incoming(true)) == 0.4 and shield._guard_multiplier(_incoming(false)) == 1.0 and shield._guard_multiplier(_incoming(true,true)) == 1.0, "방어 돌진 전방만 감소·후방/함정 제외"): return false
		player.receive_damage(_incoming(true))
		if not _check(player.damage_receiver.health == 84 and shield.guard_count == 1 and not shield._counter_armed, "돌진 중 실제 감소 피해·응수 강화 없음"): return false
		shield._update_skill_action(.33)
		if not _check(not shield._is_guarding(), "돌진 방어0.32초 종료"): return false
	else:
		var enemy := get_nodes_in_group("prototype_enemy")[0] as PrototypeEnemy
		enemy.reset_target()
		enemy.damage_receiver.max_health = 10000
		enemy.damage_receiver.post_hit_invulnerability_s = 0
		enemy.damage_receiver.reset()
		enemy.visible = true
		enemy.global_position = player.global_position + Vector2(-100*facing,0)
		shield._update_skill_action(.73)
		if not _check(is_equal_approx(enemy._shield_stun_remaining_s,.8), "원형격 막타 실제 일반 적0.8초 기절"): return false
	return true

func _polearm_rules() -> bool:
	_setup_cast()
	var enemy := get_nodes_in_group("prototype_enemy")[0] as PrototypeEnemy
	enemy.reset_target()
	enemy.damage_receiver.max_health = 10000
	enemy.damage_receiver.post_hit_invulnerability_s = 0
	enemy.damage_receiver.reset()
	enemy.visible = true
	enemy.global_position = player.global_position + Vector2(100*facing,0)
	var before := enemy.global_position.x
	weapons.request_skill_1()
	combat._update_skill_action(1.0)
	return _check(is_equal_approx(enemy.global_position.x-before, (60.0 if skill_id == "polearm_windwheel" else 80.0)*facing), "장봉 막타만 일반 적 밀침·좌우 방향")

func _cancellations() -> bool:
	for reason in ["evade","switch","stage","death","fall"]:
		_setup_cast()
		var target := _target_at("cancel_"+reason, Vector2(100,0))
		weapons.target_selector.current_target = target
		weapons.request_skill_1()
		combat._update_skill_action(0.01)
		if not _check(not player.combat_evade_allowed, "취소 창 이전 회피 차단"): return false
		match reason:
			"evade":
				combat._update_skill_action(PrototypeSkillRewards.SKILLS[skill_id].evade_cancel_start_s)
				player.request_evade()
			"switch": combat.set_active(false)
			"stage": combat.prepare_next_stage()
			"death": player.player_died.emit()
			"fall": player.fall_recovery_started.emit()
		var health := target.damage_receiver.health
		combat._update_skill_action(2.0)
		if not _check(combat._action == SwordCombatController.Action.NONE and target.damage_receiver.health == health and not player._combat_action_active and player._combat_horizontal_velocity_px == 0 and combat._slash_remaining_s == 0.0, "행동 종료·잔여 타격·강제 이동 정리: "+reason): return false
		combat.set_active(true)
		combat._clear_waves()
	return true

func _render_view() -> bool:
	_setup_cast()
	player._update_avatar_action_visual()
	var target := _target_at("render",Vector2(150,0))
	weapons.target_selector.current_target = target
	weapons.request_skill_1()
	combat._update_skill_action(float(PrototypeSkillRewards.SKILLS[skill_id].hit_times_s[0]) + .01)
	combat.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("HAPPINESS_RENDER_DIR")
	if not output.is_empty():
		var shot := root.get_texture().get_image()
		if not _check(shot.save_png(output+"/"+skill_id+"_"+character+"_"+str(facing)+".png") == OK, "실제 게임 화면 렌더링"): return false
	return true

func _weapons_restored(saved: Dictionary) -> bool:
	var actual := weapons.checkpoint_snapshot()
	if actual.active != saved.active or actual.skills != saved.skills or actual.blueprints != saved.blueprints or actual.equipment.size() != saved.equipment.size(): return false
	for id in saved.equipment:
		if not actual.equipment.has(id) or int(actual.equipment[id]) != int(saved.equipment[id]): return false
		for field in PrototypeWeaponController.CHECKPOINT_FIELDS:
			if not is_equal_approx(float(actual[id][field]),float(saved[id][field])): return false
	return true
