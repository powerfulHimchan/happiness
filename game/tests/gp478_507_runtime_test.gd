extends "res://tests/gp327_runtime_test.gd"

const NEW_SKILLS := PrototypeSkillRewards.DAWN_SKILLS

const EXPECTED := {
	"sword_dawn_chain": {"front":58,"rear":0,"projectiles":0},
	"sword_retreat_wave": {"front":42,"rear":0,"projectiles":1},
	"sword_orbit": {"front":60,"rear":60,"projectiles":0},
	"sword_high_arc": {"front":48,"rear":0,"projectiles":0},
	"sword_returning_edge": {"front":32,"rear":32,"projectiles":0},
	"bow_prism_fan": {"front":19,"rear":0,"projectiles":5},
	"bow_starlit_rain": {"front":58,"rear":0,"projectiles":0},
	"bow_swallow_trio": {"front":64,"rear":0,"projectiles":3},
	"bow_drill": {"front":56,"rear":0,"projectiles":2},
	"bow_retreat_fan": {"front":24,"rear":0,"projectiles":6},
	"fist_dawn_barrage": {"front":60,"rear":0,"projectiles":0},
	"fist_retreat_palm": {"front":42,"rear":0,"projectiles":0},
	"fist_spiral": {"front":52,"rear":52,"projectiles":0},
	"fist_sky_chain": {"front":50,"rear":0,"projectiles":0},
	"fist_twin_pulse": {"front":58,"rear":0,"projectiles":2},
	"staff_crystal_fan": {"front":20,"rear":0,"projectiles":3},
	"staff_meteor_pair": {"front":60,"rear":0,"projectiles":2},
	"staff_dawn_pulse": {"front":54,"rear":54,"projectiles":0},
	"staff_storm_seal": {"front":66,"rear":0,"projectiles":0},
	"staff_retreat_lance": {"front":52,"rear":0,"projectiles":2},
	"polearm_horizon": {"front":60,"rear":0,"projectiles":0},
	"polearm_dawn_orbit": {"front":62,"rear":62,"projectiles":0},
	"polearm_skyward": {"front":50,"rear":0,"projectiles":0},
	"polearm_back_cross": {"front":26,"rear":30,"projectiles":0},
	"polearm_comet": {"front":62,"rear":0,"projectiles":0},
	"shield_dawn_chain": {"front":62,"rear":0,"projectiles":0},
	"shield_retreat_bash": {"front":46,"rear":0,"projectiles":0},
	"shield_orbit": {"front":56,"rear":56,"projectiles":0},
	"shield_twin_wave": {"front":56,"rear":0,"projectiles":2},
	"shield_cross_march": {"front":46,"rear":20,"projectiles":0},
}

var combat: Node
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
	var prefix := "user://gp507_%s_%s_%d" % [skill_id,character,facing]
	store.save_path = prefix + "_checkpoint.json"
	legacy.save_path = prefix + "_meta.jsonl"
	journal.save_path = prefix + "_story.jsonl"
	if phase not in ["resume", "next"]:
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
	if phase in ["resume", "next"]:
		var saved := store.load_checkpoint()
		for ignored in 2:
			controls.show_main_screen()
			var resumed: bool = sandbox.continue_saved_run()
			if not _check(resumed and weapons.skills[family][1] == skill_id and player.character_id == character and combat._skill_2_cooldown_s == saved.weapons[family]._skill_2_cooldown_s and _weapons_restored(saved.weapons), "별도 프로세스 반복 이어하기·양 슬롯·대기시간 보존"): return
		if phase == "next":
			_tap(controls.stage_route_rects[0].get_center())
			if not _check(runner.stage_number == 2 and weapons.skills[family][1] == skill_id,"다음 스테이지에 새 스킬 유지"): return
			if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			if not _check(store.load_checkpoint().weapons.skills[family][1] == skill_id,"두 번째 완료 저장에도 스킬 유지"): return
			controls.show_main_screen()
			if not _check(controls.begin_retry(family,3,"standard",character,false,0,"bow" if family == "sword" else "sword") and skill_id not in weapons.skills[family],"새 도전은 시작 스킬로 초기화"): return

	else:
		if not _check(controls.begin_retry(family,3,"standard",character,false,0,"bow" if family == "sword" else "sword"), "새 계열 도전 시작"): return
		match phase:
			"seed":
				if not await _reward_save(): return
			"catalog":
				if not _catalog(): return
			"combat":
				if not _combat_and_edges(): return
				if not _cancellations(): return
			"render":
				if not await _render_view(): return
			"render_reward":
				if not await _render_reward(): return
			_:
				_check(false,"알 수 없는 단계")
				return
	paused = false
	sandbox.free()
	print("GP-478–507 runtime test: OK (%s %s %s %d)" % [phase,skill_id,character,facing])
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
	store.save_path = "user://gp507_missing/checkpoint.json"
	var rejected: bool = not sandbox._claim_skill_reward(skill_id,1)
	store.save_path = path
	if not _check(rejected and weapons.checkpoint_snapshot() == before and not runner.skills_claimed and store.load_checkpoint() == saved, "스킬 교체 저장 실패는 슬롯·대기시간·보상 되돌림"): return false
	if not _check(sandbox._claim_skill_reward(skill_id,1) and weapons.skills[family][1] == skill_id and combat._skill_2_cooldown_s == PrototypeSkillRewards.SKILLS[skill_id].cooldown_s, "실제 보상 교체·원본 대기시간"): return false
	saved = store.load_checkpoint()
	if not _check(RunCheckpointStore.valid_state(saved), "신규 스킬 체크포인트 검증"): return false
	var bad := saved.duplicate(true)
	var other: String = weapons.skills.keys().filter(func(id: String) -> bool: return id != family)[0]
	bad.weapons.skills[other][0] = skill_id
	if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "다른 무기 슬롯에 주입한 스킬 저장 거부"): return false
	var cards := PrototypeSkillRewards.codex_cards(weapons.skills,1.25)
	var own: Array = cards.filter(func(card: Dictionary) -> bool: return card.id == skill_id)
	if not _check(cards.size() == PrototypeSkillRewards.SKILLS.size() and own.size() == 1 and own[0].open and own[0].status == "이번 도전 · 슬롯 2" and own[0].lines[0].contains("%.1f초" % (PrototypeSkillRewards.SKILLS[skill_id].cooldown_s/1.25)), "88종 도감·장착 슬롯·시계추 표시"): return false
	return true

func _target_at(key: String, offset: Vector2) -> PrototypeTarget:
	var target := PrototypeTarget.new()
	target.target_key = "gp507:" + key
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
	var expected: Dictionary = EXPECTED[skill_id]
	var projectile_style: bool = expected.projectiles > 0 or family == "bow" or skill_id == "staff_storm_seal"
	var target := _target_at("front",Vector2(400 if projectile_style else 100,0))
	var rear := _target_at("rear",Vector2(-100,0))
	var outside := _target_at("outside",Vector2(1100,0))
	weapons.target_selector.current_target = target
	var definition: SkillDefinition = PrototypeSkillRewards.SKILLS[skill_id]
	weapons.request_skill_1()
	if not _check(combat._action != 0 and combat._skill_1_cooldown_s == definition.cooldown_s and is_equal_approx(player._combat_horizontal_velocity_px,definition.movement_distance_m*100/definition.duration_s*facing),"실제 시전·원본 대기·이동 속도"): return false
	var sequence: int = combat._action_sequence
	weapons.request_skill_1()
	if not _check(combat._action_sequence == sequence,"사용 중 재시전 거부"): return false
	combat._update_skill_action(definition.duration_s+.01)
	for group in ["sword_wave","bow_projectile","staff_magic_bolt"]:
		for projectile in get_nodes_in_group(group):
			projectile.set_physics_process(false)
			projectile._physics_process(1.2)
			projectile.free()
	if not _check(target.damage_receiver.health == 10000-int(expected.front) and rear.damage_receiver.health == 10000-int(expected.rear) and outside.damage_receiver.health == 10000,"전/후방·큰 프레임 누적 피해·범위 밖: %s/%s 기대 %s/%s" % [10000-target.damage_receiver.health,10000-rear.damage_receiver.health,expected.front,expected.rear]): return false
	if not _check(combat.projectile_fired_count == int(expected.projectiles) and combat.skill_hit_count > 0 and player.facing_direction == facing,"발사 개수·적중 집계·시전 방향 유지"): return false
	var health := target.damage_receiver.health
	combat._update_skill_action(.1)
	if not _check(target.damage_receiver.health == health,"완료 타격 중복 적용 없음"): return false
	if definition.hit_below_m >= 0:
		_setup_cast()
		var upper := _target_at("upper",Vector2(100,-definition.hit_half_height_m*100))
		var lower := _target_at("lower",Vector2(100,definition.hit_below_m*100))
		var below := _target_at("below",Vector2(100,definition.hit_below_m*100+1))
		weapons.request_skill_1()
		combat._update_skill_action(definition.duration_s+.01)
		if not _check(upper.damage_receiver.health < 10000 and lower.damage_receiver.health < 10000 and below.damage_receiver.health == 10000,"올려치기 위/아래 경계 포함·경계 밖 제외"): return false
	if skill_id in ["staff_storm_seal","bow_starlit_rain"]:
		_setup_cast()
		var moved := _target_at("moved",Vector2(350,0))
		var anchor := _target_at("anchor",Vector2(350,0))
		weapons.target_selector.current_target = moved
		weapons.request_skill_1()
		moved.global_position.x += 600*facing
		combat._update_skill_action(definition.duration_s+.01)
		if not _check(moved.damage_receiver.health == 10000 and anchor.damage_receiver.health < 10000,"시전 위치 고정 범위 마법은 이동한 표적 추적 없음"): return false
	return true

func _purge_projectiles() -> void:
	for group in ["sword_wave","bow_projectile","staff_magic_bolt"]:
		for projectile in get_nodes_in_group(group): projectile.free()

func _catalog() -> bool:
	if not _check(NEW_SKILLS.size() == 30 and PrototypeSkillRewards.SKILLS.size() == 88 and PrototypeSkillRewards.CODEX_ORDER.size() == 88 and PrototypeSkillRewards.CODEX_ORDER.slice(58) == NEW_SKILLS,"신규30·총88·이전58도감 순서 보존"): return false
	var ids: Array[String] = []
	for id in NEW_SKILLS:
		var d: SkillDefinition = PrototypeSkillRewards.SKILLS[id]
		if not _check(id not in ids and d.skill_id == id and d.hit_times_s.size() == d.damage.size() and d.cooldown_s > d.duration_s and d.hit_times_s[0] > 0 and d.hit_times_s[-1] < d.duration_s,"고유ID·실행 시간·재사용·타격 데이터"): return false
		ids.append(id)
		var prior := 0.0
		for time in d.hit_times_s:
			if not _check(time > prior,"타격 시점 순서"): return false
			prior = time
	for id in PrototypeWeaponRewards.FAMILY_IDS:
		var expected_size := 22 if id in ["sword","bow"] else 11
		if not _check(PrototypeSkillRewards.pool_for(id).size() == expected_size,"여섯 계열에 각각5스킬 추가"): return false
	return true

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
		if not _check(combat._action == SwordCombatController.Action.NONE and target.damage_receiver.health == health and not player._combat_action_active and player._combat_horizontal_velocity_px == 0, "행동 종료·잔여 타격·강제 이동 정리: "+reason): return false
		combat.set_active(true)
		_purge_projectiles()
	return true

func _render_view() -> bool:
	_setup_cast()
	player._update_avatar_action_visual()
	var target := _target_at("render",Vector2(150,0))
	weapons.target_selector.current_target = target
	weapons.request_skill_1()
	combat._update_skill_action(float(PrototypeSkillRewards.SKILLS[skill_id].hit_times_s[0]) + .01)
	combat._emit_metrics()
	combat.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("HAPPINESS_RENDER_DIR")
	if not output.is_empty():
		var shot := root.get_texture().get_image()
		if not _check(shot.save_png(output+"/"+skill_id+"_"+character+"_"+str(facing)+".png") == OK, "실제 게임 화면 렌더링"): return false
	return true

func _render_reward() -> bool:
	if not _finish_stage() or not sandbox._claim_weapon_reward(""): return false
	_tap(controls.skill_reward_open_rect.get_center())
	for ignored in PrototypeSkillRewards.offer_page_count(weapons.skills):
		if controls.skill_reward_offers.any(func(card: Dictionary) -> bool: return card.id == skill_id): break
		_tap(controls.skill_reward_cycle_rect.get_center())
	var found := false
	for index in controls.skill_reward_offers.size():
		if controls.skill_reward_offers[index].id == skill_id:
			_tap(controls.skill_reward_offer_rects[index].get_center())
			found = true
			break
	if not _check(found,"신규 스킬 보상 화면 렌더 대상"): return false
	_tap(controls.skill_reward_slot_rects[1].get_center())
	var before := store.load_checkpoint()
	controls.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if not _check(store.load_checkpoint() == before,"보상 비교 그리기는 저장 무변경"): return false
	var output := OS.get_environment("HAPPINESS_RENDER_DIR")
	if not output.is_empty():
		if not _check(root.get_texture().get_image().save_png(output+"/reward_"+skill_id+".png") == OK,"보상 설명 화면 캡처"): return false
	return true

func _weapons_restored(saved: Dictionary) -> bool:
	var actual := weapons.checkpoint_snapshot()
	if actual.active != saved.active or actual.skills != saved.skills or actual.blueprints != saved.blueprints or actual.equipment.size() != saved.equipment.size(): return false
	for id in saved.equipment:
		if not actual.equipment.has(id) or int(actual.equipment[id]) != int(saved.equipment[id]): return false
		for field in PrototypeWeaponController.CHECKPOINT_FIELDS:
			if not is_equal_approx(float(actual[id][field]),float(saved[id][field])): return false
	return true
