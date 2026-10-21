extends "res://tests/gp327_runtime_test.gd"

var shield: ShieldCombatController
var family_job: String
var backup_family: String
var character: String

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	character = args[1]
	family_job = args[2]
	backup_family = args[3]
	automatic_growth_card_id = "shield_power"
	var prefix := "user://gp374_%s_%s_%s_%s" % [character, family_job, backup_family, "flow" if phase in ["seed", "resume"] else phase]
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
	shield = weapons.shield_combat
	recorder = sandbox.get_node("LocalTestRecorder")
	festival_ultimate = sandbox.get_node("Player/UltimateController")
	festival_terrain = sandbox.get_node("RouteTerrain")
	for actor in [player, weapons, weapons.sword_combat, weapons.bow_combat, weapons.fist_combat, weapons.staff_combat, weapons.polearm_combat, weapons.shield_combat, festival_ultimate, runner, sandbox.get_node("ClockTrapController"), festival_terrain]:
		actor.set_process(false)
		actor.set_physics_process(false)
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	match phase:
		"combat":
			if not await _test_start_selection(): return
			if not _start_family(3, "standard") or not _combat(): return
		"legacy":
			automatic_growth_card_id = "sword_power"
			if not _check(controls.begin_retry("sword", 3), "이전 검·활 도전 시작"): return
			for ignored in 3:
				if not _earn_card("sword_power"): return
			if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			var saved := store.load_checkpoint()
			controls.show_main_screen()
			if not _check(not saved.is_empty() and not saved.player.has("shield") and sandbox.continue_saved_run() and weapons.equipment == {"sword": 0, "bow": 0} and player.growth_shield_bonus == 0.0 and growth.jobs.job_id == "vanguard" and not growth._card_available(PrototypeAbilityCodex.profile("shield_power")), "추가 필드 없는 기존 저장·기본 두 무기·성장 호환"): return
		"seed", "late":
			if not _start_family(10, "journey"): return
			for ignored in 5:
				if not _earn_card("shield_power"): return
			for id in ["guardian_resolve", "guardian_breath"]:
				if not _earn_card(id): return
			if family_job == "rune_guardian" and not _earn_card("guardian_oath"): return
			if not _check(growth.jobs.job_id == "guardian" and player.job_emblem_id == "guardian" and festival_ultimate.selected_profile.job == "guardian", "실제 카드 선택으로 수호자 발현·기본 필살기"): return
			if phase == "seed" and not _real_shield_hits(): return
			if not _check(not growth.try_evolve_job(), "7단계 이전 진화 차단"): return
			for number in range(1, 7):
				if not _finish_stage() or not sandbox._claim_weapon_reward("shield" if number <= 2 else ""): return
				if number < 6 and not _next_without_layout(): return
			var before_max := player.damage_receiver.max_health
			var before_bonus := player.growth_shield_bonus
			var profile := PrototypeJobProgress.profile(family_job)
			festival_ultimate.gauge = 76
			legacy.fail_writes = true
			_tap(controls.stage_route_rects[-1].get_center())
			var active: Dictionary = {}
			var remaining := 0.0
			if phase == "late":
				if not _check(growth.jobs.job_id == "guardian" and not growth.try_evolve_job(), "후반 성향 부족 진화 차단"): return
				festival_ultimate.gauge = 100
				festival_ultimate.request_ultimate()
				active = festival_ultimate._active_profile.duplicate(true)
				remaining = festival_ultimate._remaining_s
				if not _real_shield_hits(): return
			if not _check(paused and growth.awaiting_job_confirmation and growth.jobs.job_id == family_job and player.job_emblem_id == family_job and player.damage_receiver.max_health == before_max + int(profile.health_bonus) and is_equal_approx(player.growth_shield_bonus, before_bonus + float(profile.damage_bonus)), "실제 적중·7단계 진화·패시브·표식"): return
			if not await _layout_check(): return
			var gauge := festival_ultimate.gauge
			var choice := 0 if character == "roan" else 1
			_tap(controls.job_ultimate_rects[choice].get_center())
			_tap(controls.job_confirm_rect.get_center())
			if not _check(paused and growth.awaiting_job_confirmation and not growth.acknowledge_job(), "발견 기록 실패는 진화 확정 보류"): return
			legacy.fail_writes = false
			_tap(controls.job_confirm_rect.get_center())
			if not _check(not paused and festival_ultimate.gauge == gauge and festival_ultimate.selected_profile.job == family_job and not growth.choose_job_ultimate(2) and not growth.try_evolve_job(), "진화 재시도·게이지 유지·중복 교체 차단"): return
			if phase == "late":
				if not _check(festival_ultimate._active_profile == active and festival_ultimate._remaining_s == remaining, "기존 사용 중 필살기 보존"): return
				festival_ultimate._physics_process(remaining + 0.1)
			else:
				var prefix_id := "fortress" if family_job == "fortress_knight" else "rune"
				for id in [prefix_id + "_strike", prefix_id + "_heart", prefix_id + ("_mastery" if character == "roan" else "_guard")]:
					if not _earn_card(id): return
				if not _check(not growth._card_available(PrototypeAbilityCodex.profile(prefix_id + ("_guard" if character == "roan" else "_mastery"))), "상위 특화 상호 배제"): return
				if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
				var previous := weapons.checkpoint_snapshot()
				_tap(controls.skill_reward_open_rect.get_center())
				var path := store.save_path
				store.save_path = "user://gp374_missing/checkpoint.json"
				var rejected: bool = not sandbox._claim_skill_reward("shield_slam", 0)
				store.save_path = path
				if not _check(rejected and weapons.skills == previous.skills and shield._skill_1_cooldown_s == float(previous.shield._skill_1_cooldown_s) and not runner.skills_claimed, "방패 스킬 교체 저장 실패 되돌림"): return
				if not _check(sandbox._claim_skill_reward("shield_slam", 0), "실제 정예 보상에서 충격 강타 교체"): return
				var saved := store.load_checkpoint()
				if not _check(not saved.is_empty() and saved.stage.number == 7 and saved.growth.job == family_job and saved.weapons.skills.shield[0] == "shield_slam" and saved.player.shield > 0 and RunCheckpointStore.valid_state(saved), "두 무기·성장·진화·스킬·대기시간 저장"): return
				for mutation in ["third", "active", "skills", "bonus", "score", "ultimate"]:
					var bad := saved.duplicate(true)
					match mutation:
						"third": bad.weapons.equipment["sword" if backup_family == "bow" else "bow"] = 0
						"active": bad.weapons.active = "unknown"
						"skills": bad.weapons.skills.shield[0] = "bow_volley"
						"bonus": bad.player.shield += 0.10
						"score": bad.growth.contributions.weapon.clear()
						"ultimate": bad.ultimate.profile = "dragon_burst"
					if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "변조 저장 거부·정상 파일 유지: " + mutation): return
		"resume":
			var saved := store.load_checkpoint()
			if not _restore_journey(7): return
			for field in PrototypeWeaponController.CHECKPOINT_FIELDS:
				if not _check(is_equal_approx(float(shield.get(field)), float(saved.weapons.shield[field])), "방패 재사용 대기·전투 집계 복원: " + field): return
			if not _check(weapons.equipment.has("shield") and weapons.equipment.has(backup_family) and weapons.equipment.size() == 2 and weapons.skills.shield[0] == "shield_slam" and is_equal_approx(player.growth_shield_bonus, float(saved.player.shield)) and player.damage_receiver.max_health == int(saved.player.max_health) and growth.jobs.job_id == family_job and player.job_emblem_id == family_job and festival_ultimate.selected_profile.id == saved.ultimate.profile, "별도 프로세스 반복 복원·방패 스킬·진화 보너스 중복 없음"): return
			controls.show_main_screen()
			controls.show_village()
			controls.village_page = "advanced_jobs"
			for ignored in 5: _tap(controls.village_snapshot().pager.next.get_center())
			var view: Dictionary = controls.village_snapshot()
			var own: Array = view.cards.filter(func(card: Dictionary) -> bool: return card.id == family_job)
			if not _check(view.advanced_pages == ceili(float(PrototypeJobProgress.ADVANCED_JOBS.size()) / PrototypeVillageView.ADVANCED_PAGE_SIZE) and own.size() == 1 and own[0].open and own[0].progress.hint == "이번 도전에서 진화 완료", "수호자 두 진화의 영구 발견·현재 도감"): return
			if not await _layout_check(): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			if not _next_without_layout() or not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			if not _check(store.load_checkpoint().growth.job == family_job and runner.stage_number == 8, "방패 빌드 다음 스테이지 유지"): return
			recorder.clear_records()
			controls.show_main_screen()
			controls.begin_retry("sword", 3)
			if not _check(not weapons.equipment.has("shield") and growth.jobs.job_id.is_empty() and player.growth_shield_bonus == 0.0 and player.job_emblem_id.is_empty() and legacy.progress_snapshot().jobs.has(family_job), "새 도전 초기화·발견 유지"): return
	paused = false
	sandbox.free()
	print("GP-365~374 runtime test: OK (%s %s %s %s)" % [phase, character, family_job, backup_family])
	quit(0)

func _start_family(count: int, mode: String) -> bool:
	return _check(controls.begin_retry("shield", count, mode, character, false, 0, backup_family) and weapons.active_weapon_id == "shield" and weapons.equipment.size() == 2 and weapons.equipment.has(backup_family) and shield.active and not weapons.combat_for(backup_family).active, "선택한 두 무기로 방패 도전 시작")

func _real_shield_hits() -> bool:
	var target := sandbox.get_node("Targets/LeafSlime") as PrototypeTarget
	target.visible = true
	target.set_process(false)
	target.set_physics_process(false)
	var maximum := target.damage_receiver.max_health
	target.damage_receiver.max_health = 10000
	target.damage_receiver.reset()
	for hit in 80:
		shield._action_sequence += 1
		if not _check(shield._damage_target(target, &"shield_basic", 1, 0.0, PackedStringArray(["shield", "basic"]), hit) == DamageReceiver.Result.APPLIED, "실제 방패 적중 성향 누적"): return false
	target.damage_receiver.max_health = maximum
	target.reset_target()
	return true

func _test_start_selection() -> bool:
	controls.show_main_screen()
	controls.show_start_weapon_selection()
	for dimensions in [Vector2(1280,720), Vector2(1600,720)]:
		controls.size = dimensions
		controls._refresh_start_weapon_layout()
		var safe: Rect2 = controls.layout_snapshot().safe
		if not _check(controls.start_weapon_card_rects.size() == PrototypeWeaponRewards.FAMILY_IDS.size() and controls.start_backup_rects.size() == PrototypeWeaponRewards.FAMILY_IDS.size(), "세 무기 선택·보조 버튼"): return false
		for index in PrototypeWeaponRewards.FAMILY_IDS.size():
			if not _check(safe.encloses(controls.start_weapon_card_rects[index]) and controls.start_weapon_card_rects[index].encloses(controls.start_backup_rects[index]), "두 화면비 주·보조 선택 안전 영역"): return false
			_tap(controls.start_weapon_card_rects[index].get_center())
			if not _check(controls.selected_starting_weapon == PrototypeWeaponRewards.FAMILY_IDS[index] and controls.selected_backup_weapon != controls.selected_starting_weapon, "주 무기 선택은 서로 다른 두 계열 유지"): return false
			for other in PrototypeWeaponRewards.FAMILY_IDS.size():
				_tap(controls.start_backup_rects[other].get_center())
				if not _check(controls.selected_backup_weapon == PrototypeWeaponRewards.FAMILY_IDS[other] and controls.selected_backup_weapon != controls.selected_starting_weapon, "보조 선택·현재 주 무기와 교환"): return false
				_tap(controls.start_weapon_card_rects[index].get_center())
		controls.queue_redraw()
		await process_frame
	_tap(controls.start_weapon_cancel_rect.get_center())
	return _check(not controls.begin_retry("shield", 3, "standard", character, false, 0, "shield") and not controls.begin_retry("unknown", 3), "중복·알 수 없는 두 무기 시작 차단")

func _test_all_family_ultimates(target: PrototypeTarget) -> bool:
	for node in get_nodes_in_group("targetable"): node.visible = node == target
	var expected := [[60,0],[0,40],[75,0],[25,25],[130,0],[40,45],[150,0],[0,65],[100,0],[30,60],[130,0],[0,80]]
	var index := 0
	for id in ["guardian", "fortress_knight", "rune_guardian"]:
		for profile in PrototypeJobRewards.ultimates_for(id):
			festival_ultimate.reset_ultimate()
			target.damage_receiver.reset()
			target.global_position = player.global_position + Vector2(100,0)
			player.damage_receiver.health = 10
			festival_ultimate.select_job_ultimate(id,profile.id)
			festival_ultimate.gauge = 100
			festival_ultimate.request_ultimate()
			if not _check(target.damage_receiver.health == 10000 - int(expected[index][0]) and player.damage_receiver.health == 10 + int(expected[index][1]) and festival_ultimate._active and is_equal_approx(target.enemy_time_scale(),float(profile.slow)), "수호자·두 상위 직업12개 필살기 실제 피해·회복·감속"): return false
			festival_ultimate.finish_stage_effect()
			index += 1
	return true

func _test_shield_enemy_rules() -> bool:
	var event := DamageEvent.new()
	event.damage = 100
	event.tags = PackedStringArray(["shield", "basic"])
	event.source_position = Vector2(100, 0)
	var enemies := [EliteArmoredBoar.new(), BossHappinessGuardian.new(), BossHappinessHeart.new(), BossSera.new()]
	var recovery_damage := [60, 125, 150, 125]
	for index in enemies.size():
		var enemy: EliteArmoredBoar = enemies[index]
		enemy.state = EliteArmoredBoar.State.RECOVERY
		var adjusted := enemy._adjust_damage_event(event)
		if not _check(adjusted.damage == recovery_damage[index], "방패 근접 공격도 갑옷·세 보스 빈틈 적용"): return false
		if index < 2:
			enemy.state = EliteArmoredBoar.State.STUNNED
			if not _check(enemy._adjust_damage_event(event).damage == (175 if index == 0 else 150), "방패 기절 약점 배율"): return false
		if index == 1:
			enemy.state = EliteArmoredBoar.State.WARNING
			enemy._charge_direction = 1
			if not _check(enemy._adjust_damage_event(event).damage == 65, "수호 방패 정면 방패 피해 감소"): return false
		enemy.free()
	return true

func _target(key: String, offset: Vector2) -> PrototypeTarget:
	var target := PrototypeTarget.new()
	target.target_key = "new-family:" + key
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
	target.add_to_group("combat_enemy")
	target.set_process(false)
	target.reset_target()
	target.global_position = player.global_position + offset
	return target

func _cast(slot: int, delta: float) -> void:
	shield.set("_skill_%d_cooldown_s" % (slot+1),0.0)
	if slot == 0: weapons.request_skill_1()
	else: weapons.request_skill_2()
	shield._update_skill_action(delta)

func _combat() -> bool:
	for enemy in get_nodes_in_group("targetable"): enemy.visible = false
	var target := _target("front",Vector2(100,0))
	player.facing_direction = 1
	weapons.target_selector.current_target = target
	if not _specific_combat(target): return false
	shield._finish_action("")
	player.set_lifesteal_unlocked(true)
	player.damage_receiver.health = 50
	shield._action_sequence += 1
	shield._damage_target(target,&"shield_basic",100,0,PackedStringArray(["shield","basic"]),0)
	if not _check(player.damage_receiver.health == 55,"실제 피해 생명 흡수5%"): return false
	player.set_lifesteal_unlocked(false)
	shield._skill_1_cooldown_s = 4
	shield._skill_2_cooldown_s = 6
	weapons.request_weapon_switch()
	weapons.request_weapon_switch()
	if not _check(weapons.active_weapon_id == backup_family and not shield.active and weapons.blocked_switch_count == 1,"다섯 보조 계열 전환·연속 차단"): return false
	shield._physics_process(1)
	if not _check(shield._skill_1_cooldown_s == 3 and shield._skill_2_cooldown_s == 5,"비활성 대기 감소"): return false
	weapons._physics_process(.51)
	weapons.request_weapon_switch()
	if not _check(weapons.equip_reward("shield",1) and player.growth_damage(100,"shield","basic") == 115 and player.growth_damage(100,"shield","skill") == 125,"희귀 장비 보정"): return false
	var equipment := weapons.equipment.duplicate()
	for id in equipment: equipment[id] = 2
	var skill_backup := backup_family in ["sword","staff","shield"]
	if not _check(weapons.set_equipment(equipment) and player.growth_damage(100,"shield","basic") == (130 if skill_backup else 140) and player.growth_damage(100,"shield","skill") == (160 if skill_backup else 150) and player.growth_damage(100,"shield","ultimate") == 100,"영웅 장비·보조50%·필살기 제외"): return false
	if not _test_all_family_ultimates(target) or not _test_shield_enemy_rules(): return false
	weapons._emit_active_metrics()
	controls._show_result_screen()
	return _check(controls.result_snapshot.shield_hits > 0 and controls.result_snapshot.shield_damage > 0 and is_equal_approx(float(controls.result_snapshot.shield_ratio),1.0),"결과 적중·피해·비율")

var _event_sequence: int = 0
func _incoming(front: bool = true, tags: PackedStringArray = PackedStringArray(["enemy"]), damage: int = 40) -> DamageEvent:
	_event_sequence += 1
	var event := DamageEvent.new()
	event.event_id = StringName("guard-test:%d" % _event_sequence)
	event.damage = damage
	event.stagger_s = .2
	event.tags = tags
	event.source_position = player.global_position+Vector2((100 if front else -100)*player.facing_direction,0)
	return event

func _reset_guard() -> void:
	player.reset_movement_test(sandbox.TRACK_START)
	player.facing_direction = 1
	player.damage_receiver.post_hit_invulnerability_s = 0
	shield.reset_combat()

func _specific_combat(target: PrototypeTarget) -> bool:
	_reset_guard()
	weapons.target_selector.current_target = target
	target.global_position = player.global_position+Vector2(150,0)
	festival_ultimate.gauge = 0
	shield._update_basic_attack(.01)
	if not _check(target.damage_receiver.health == 9982 and shield.basic_attack_count == 1 and festival_ultimate.gauge == 4 and shield._basic_remaining_s == 1.0,"방패18·1.5m 경계·1초 간격·게이지4"): return false
	for offset in [Vector2(151,0),Vector2(-100,0),Vector2(100,120)]:
		target.global_position = player.global_position+offset
		shield._basic_remaining_s = 0
		shield._update_basic_attack(.01)
	if not _check(shield.basic_attack_count == 1,"방패 후방·범위 밖 자동 공격 차단"): return false
	target.global_position = player.global_position+Vector2(100,0)
	weapons.request_skill_1()
	var event := _incoming()
	player.receive_damage(event)
	if not _check(player.damage_receiver.health == 84 and player.last_stagger_s == 0 and event.damage == 40 and event.stagger_s == .2 and shield.guard_count == 1 and not shield._counter_armed,"전방60% 감소·경직 방어·원본 보존·일반 방어는 응수 준비 없음"): return false
	player.receive_damage(event)
	if not _check(shield.guard_count == 1,"중복 피해는 방어 횟수 증가 없음"): return false
	shield._update_skill_action(1.21)
	if not _check(not shield._is_guarding() and target.damage_receiver.health == 9982,"1.2초 방어 종료·추가 공격 없음"): return false
	_reset_guard()
	_cast(1,.76)
	if not _check(target.damage_receiver.health == 9958,"미방어 응수는24"): return false
	shield._skill_2_cooldown_s = 0
	weapons.request_skill_2()
	player.receive_damage(_incoming())
	if not _check(shield._counter_armed,"응수 준비 중 실제 방어 성공"): return false
	shield._update_skill_action(.46)
	if not _check(target.damage_receiver.health == 9898 and not shield._is_guarding(),"방어 성공 응수60·타격 뒤 방어 종료"): return false
	shield._update_skill_action(.30)
	if not _check(not shield._counter_armed,"행동 종료 뒤 강화 소비"): return false
	for kind in ["invulnerable","rear","trap","invalid"]:
		_reset_guard()
		weapons.request_skill_2()
		player.invincible = kind == "invulnerable"
		player.receive_damage(_incoming(kind != "rear",PackedStringArray(["enemy","hazard","clock","ruins"]) if kind == "trap" else PackedStringArray(["enemy"]),0 if kind == "invalid" else 40))
		player.invincible = false
		if not _check(not shield._counter_armed and shield.guard_count == 0 and player.damage_receiver.health == (60 if kind in ["rear","trap"] else 100),"응수 오발동 차단: " + kind): return false
	_reset_guard()
	player.damage_receiver.barrier_health = 100
	weapons.request_skill_2()
	event = _incoming()
	player.receive_damage(event)
	if not _check(shield._counter_armed and player.damage_receiver.barrier_health == 84 and player.damage_receiver.health == 100,"방벽은 감소 후16 흡수·정상 반격"): return false
	shield._counter_armed = false
	player.receive_damage(event)
	if not _check(not shield._counter_armed,"중복 방벽 타격은 반격 준비 없음"): return false
	_reset_guard()
	player.facing_direction = -1
	weapons.request_skill_1()
	player.boss_legacy = {"choice":"destroy"}
	player.receive_damage(_incoming(true,PackedStringArray(["enemy"]),7))
	if not _check(player.damage_receiver.health == 97 and shield._line_direction == -1,"좌향·7×1.1×0.4 단일 반올림3"): return false
	player.boss_legacy = {}
	for reason in ["evade","switch","stage","fall","revive"]:
		_reset_guard()
		weapons.request_skill_2()
		player.receive_damage(_incoming())
		match reason:
			"evade":
				shield._update_skill_action(.20)
				if not _check(not player.combat_evade_allowed,"취소 창 이전 회피 차단"): return false
				shield._update_skill_action(.31)
				player.request_evade()
			"switch": shield.set_active(false)
			"stage": shield.prepare_next_stage()
			"fall": player.fall_recovery_started.emit()
			"revive": player.phoenix_revived.emit()
		if not _check(shield._action == SwordCombatController.Action.NONE and not shield._is_guarding() and not shield._counter_armed,"방어/반격 행동 수명 정리: " + reason): return false
		shield.set_active(true)
	_reset_guard()
	var loadout := weapons.skills.duplicate(true)
	loadout.shield[0] = "shield_slam"
	weapons.set_skill_loadout(loadout)
	var edge := _target("edge",Vector2(180,80))
	var rear := _target("rear",Vector2(-100,0))
	var outside := _target("outside",Vector2(181,0))
	var health := target.damage_receiver.health
	_cast(0,.61)
	if not _check(target.damage_receiver.health == health-40 and edge.damage_receiver.health == 9960 and rear.damage_receiver.health == 10000 and outside.damage_receiver.health == 10000,"강타40·전방1.8m/높이0.8m·후방/범위 밖 제외"): return false
	for victim in [edge,rear,outside]: victim.visible = false
	var enemy := get_nodes_in_group("prototype_enemy")[0] as PrototypeEnemy
	enemy.reset_target()
	enemy.visible = true
	enemy.set_process(false)
	enemy.damage_receiver.max_health = 10000
	enemy.damage_receiver.post_hit_invulnerability_s = 0
	enemy.damage_receiver.reset()
	enemy.global_position = player.global_position+Vector2(100,0)
	shield._action_sequence += 1
	shield._damage_target(enemy,&"shield_counter",24,0,PackedStringArray(["shield","skill"]),0)
	if not _check(enemy._shield_stun_remaining_s == 0,"기본 응수는 기절 없음"): return false
	shield._counter_armed = true
	shield._action_sequence += 1
	shield._damage_target(enemy,&"shield_counter",24,0,PackedStringArray(["shield","skill"]),0)
	shield._counter_armed = false
	if not _check(enemy._shield_stun_remaining_s == 1,"강화 응수 일반 적1초 기절"): return false
	shield._action_sequence += 1
	shield._damage_target(enemy,&"shield_slam",40,0,PackedStringArray(["shield","skill"]),0)
	if not _check(enemy._shield_stun_remaining_s == 1.2 and enemy.state == PrototypeEnemy.State.RECOVERY,"강타 일반 적1.2초 기절"): return false
	enemy.set_enemy_time_scale(0)
	enemy._process(1)
	if not _check(enemy._shield_stun_remaining_s == 1.2,"기절은 적 시간 정지 존중"): return false
	enemy.set_enemy_time_scale(1)
	enemy._process(.6)
	if not _check(is_equal_approx(enemy._shield_stun_remaining_s,.6) and enemy.state == PrototypeEnemy.State.RECOVERY,"기절 중 행동 정지"): return false
	enemy.reset_target()
	if not _check(enemy._shield_stun_remaining_s == 0,"새 웨이브 기절 초기화"): return false
	enemy.visible = false
	return true
