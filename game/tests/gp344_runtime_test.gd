extends "res://tests/gp327_runtime_test.gd"

var fist: FistCombatController
var martial_job: String
var backup_family: String
var character: String

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	character = args[1]
	martial_job = args[2]
	backup_family = args[3]
	automatic_growth_card_id = "fist_power"
	var prefix := "user://gp344_%s_%s_%s_%s" % [character, martial_job, backup_family, "flow" if phase in ["seed", "resume"] else phase]
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
	fist = weapons.fist_combat
	recorder = sandbox.get_node("LocalTestRecorder")
	festival_ultimate = sandbox.get_node("Player/UltimateController")
	festival_terrain = sandbox.get_node("RouteTerrain")
	for actor in [player, weapons, weapons.sword_combat, weapons.bow_combat, fist, festival_ultimate, runner, sandbox.get_node("ClockTrapController"), festival_terrain]:
		actor.set_process(false)
		actor.set_physics_process(false)
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	match phase:
		"combat":
			if not await _test_start_selection(): return
			if not _start_martial(3, "standard") or not _combat(): return
		"legacy":
			automatic_growth_card_id = "sword_power"
			if not _check(controls.begin_retry("sword", 3), "이전 검·활 도전 시작"): return
			for ignored in 3:
				if not _earn_card("sword_power"): return
			if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			var saved := store.load_checkpoint()
			controls.show_main_screen()
			if not _check(not saved.is_empty() and not saved.player.has("fist") and sandbox.continue_saved_run() and weapons.equipment == {"sword": 0, "bow": 0} and player.growth_fist_bonus == 0.0 and growth.jobs.job_id == "vanguard" and not growth._card_available(PrototypeAbilityCodex.profile("fist_power")), "추가 필드 없는 기존 저장·기본 두 무기·성장 호환"): return
		"seed", "late":
			if not _start_martial(10, "journey"): return
			for ignored in 5:
				if not _earn_card("fist_power"): return
			for id in ["monk_strike", "monk_breath"]:
				if not _earn_card(id): return
			if martial_job == "phantom_dancer" and not _earn_card("monk_chain"): return
			if not _check(growth.jobs.job_id == "martial_artist" and player.job_emblem_id == "martial_artist" and festival_ultimate.selected_profile.job == "martial_artist", "실제 카드 선택으로 무도가 발현·기본 필살기"): return
			if phase == "seed" and not _real_fist_hits(): return
			if not _check(not growth.try_evolve_job(), "7단계 이전 진화 차단"): return
			for number in range(1, 7):
				if not _finish_stage() or not sandbox._claim_weapon_reward("fist" if number <= 2 else ""): return
				if number < 6 and not _next_without_layout(): return
			var before_max := player.damage_receiver.max_health
			var before_bonus := player.growth_fist_bonus
			var profile := PrototypeJobProgress.profile(martial_job)
			festival_ultimate.gauge = 76
			legacy.fail_writes = true
			_tap(controls.stage_route_rects[-1].get_center())
			var active: Dictionary = {}
			var remaining := 0.0
			if phase == "late":
				if not _check(growth.jobs.job_id == "martial_artist" and not growth.try_evolve_job(), "후반 성향 부족 진화 차단"): return
				festival_ultimate.gauge = 100
				festival_ultimate.request_ultimate()
				active = festival_ultimate._active_profile.duplicate(true)
				remaining = festival_ultimate._remaining_s
				if not _real_fist_hits(): return
			if not _check(paused and growth.awaiting_job_confirmation and growth.jobs.job_id == martial_job and player.job_emblem_id == martial_job and player.damage_receiver.max_health == before_max + int(profile.health_bonus) and is_equal_approx(player.growth_fist_bonus, before_bonus + float(profile.damage_bonus)), "실제 적중·7단계 진화·패시브·표식"): return
			if not await _layout_check(): return
			var gauge := festival_ultimate.gauge
			var choice := 0 if character == "roan" else 1
			_tap(controls.job_ultimate_rects[choice].get_center())
			_tap(controls.job_confirm_rect.get_center())
			if not _check(paused and growth.awaiting_job_confirmation and not growth.acknowledge_job(), "발견 기록 실패는 진화 확정 보류"): return
			legacy.fail_writes = false
			_tap(controls.job_confirm_rect.get_center())
			if not _check(not paused and festival_ultimate.gauge == gauge and festival_ultimate.selected_profile.job == martial_job and not growth.choose_job_ultimate(2) and not growth.try_evolve_job(), "진화 재시도·게이지 유지·중복 교체 차단"): return
			if phase == "late":
				if not _check(festival_ultimate._active_profile == active and festival_ultimate._remaining_s == remaining, "기존 사용 중 필살기 보존"): return
				festival_ultimate._physics_process(remaining + 0.1)
			else:
				var prefix_id := "thunder" if martial_job == "thunder_fist" else "phantom"
				for id in [prefix_id + "_strike", prefix_id + "_heart", prefix_id + ("_mastery" if character == "roan" else "_guard")]:
					if not _earn_card(id): return
				if not _check(not growth._card_available(PrototypeAbilityCodex.profile(prefix_id + ("_guard" if character == "roan" else "_mastery"))), "상위 특화 상호 배제"): return
				if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
				var previous := weapons.checkpoint_snapshot()
				_tap(controls.skill_reward_open_rect.get_center())
				var path := store.save_path
				store.save_path = "user://gp344_missing/checkpoint.json"
				var rejected: bool = not sandbox._claim_skill_reward("fist_wave", 0)
				store.save_path = path
				if not _check(rejected and weapons.skills == previous.skills and fist._skill_1_cooldown_s == float(previous.fist._skill_1_cooldown_s) and not runner.skills_claimed, "주먹 스킬 교체 저장 실패 되돌림"): return
				if not _check(sandbox._claim_skill_reward("fist_wave", 0), "실제 정예 보상에서 파동권 교체"): return
				var saved := store.load_checkpoint()
				if not _check(not saved.is_empty() and saved.stage.number == 7 and saved.growth.job == martial_job and saved.weapons.skills.fist[0] == "fist_wave" and saved.player.fist > 0 and RunCheckpointStore.valid_state(saved), "두 무기·성장·진화·스킬·대기시간 저장"): return
				for mutation in ["third", "active", "skills", "bonus", "score", "ultimate"]:
					var bad := saved.duplicate(true)
					match mutation:
						"third": bad.weapons.equipment["sword" if backup_family == "bow" else "bow"] = 0
						"active": bad.weapons.active = "unknown"
						"skills": bad.weapons.skills.fist[0] = "bow_volley"
						"bonus": bad.player.fist += 0.10
						"score": bad.growth.contributions.weapon.clear()
						"ultimate": bad.ultimate.profile = "dragon_burst"
					if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "변조 저장 거부·정상 파일 유지: " + mutation): return
		"resume":
			var saved := store.load_checkpoint()
			if not _restore_journey(7): return
			for field in PrototypeWeaponController.CHECKPOINT_FIELDS:
				if not _check(is_equal_approx(float(fist.get(field)), float(saved.weapons.fist[field])), "주먹 재사용 대기·전투 집계 복원: " + field): return
			if not _check(weapons.equipment.has("fist") and weapons.equipment.has(backup_family) and weapons.equipment.size() == 2 and weapons.skills.fist[0] == "fist_wave" and is_equal_approx(player.growth_fist_bonus, float(saved.player.fist)) and player.damage_receiver.max_health == int(saved.player.max_health) and growth.jobs.job_id == martial_job and player.job_emblem_id == martial_job and festival_ultimate.selected_profile.id == saved.ultimate.profile, "별도 프로세스 반복 복원·주먹 스킬·진화 보너스 중복 없음"): return
			controls.show_main_screen()
			controls.show_village()
			controls.village_page = "advanced_jobs"
			for ignored in 2: _tap(controls.village_snapshot().pager.next.get_center())
			var view: Dictionary = controls.village_snapshot()
			var own: Array = view.cards.filter(func(card: Dictionary) -> bool: return card.id == martial_job)
			if not _check(view.advanced_pages == ceili(float(PrototypeJobProgress.ADVANCED_JOBS.size()) / PrototypeVillageView.ADVANCED_PAGE_SIZE) and own.size() == 1 and own[0].open and own[0].progress.hint == "이번 도전에서 진화 완료", "무도가 두 진화의 영구 발견·현재 도감"): return
			if not await _layout_check(): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			if not _next_without_layout() or not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			if not _check(store.load_checkpoint().growth.job == martial_job and runner.stage_number == 8, "주먹 빌드 다음 스테이지 유지"): return
			recorder.clear_records()
			controls.show_main_screen()
			controls.begin_retry("sword", 3)
			if not _check(not weapons.equipment.has("fist") and growth.jobs.job_id.is_empty() and player.growth_fist_bonus == 0.0 and player.job_emblem_id.is_empty() and legacy.progress_snapshot().jobs.has(martial_job), "새 도전 초기화·발견 유지"): return
	paused = false
	sandbox.free()
	print("GP-335~344 runtime test: OK (%s %s %s %s)" % [phase, character, martial_job, backup_family])
	quit(0)

func _start_martial(count: int, mode: String) -> bool:
	return _check(controls.begin_retry("fist", count, mode, character, false, 0, backup_family) and weapons.active_weapon_id == "fist" and weapons.equipment.size() == 2 and weapons.equipment.has(backup_family) and fist.active and not weapons.combat_for(backup_family).active, "선택한 두 무기로 주먹 도전 시작")

func _real_fist_hits() -> bool:
	var target := sandbox.get_node("Targets/LeafSlime") as PrototypeTarget
	target.visible = true
	target.set_process(false)
	target.set_physics_process(false)
	var maximum := target.damage_receiver.max_health
	target.damage_receiver.max_health = 10000
	target.damage_receiver.reset()
	for hit in 80:
		fist._action_sequence += 1
		if not _check(fist._damage_target(target, &"fist_basic", 1, 0.0, PackedStringArray(["fist", "basic"]), hit) == DamageReceiver.Result.APPLIED, "실제 주먹 적중 성향 누적"): return false
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
	return _check(not controls.begin_retry("fist", 3, "standard", character, false, 0, "fist") and not controls.begin_retry("unknown", 3), "중복·알 수 없는 두 무기 시작 차단")

func _combat() -> bool:
	var target := sandbox.get_node("Targets/LeafSlime") as PrototypeTarget
	for enemy in get_nodes_in_group("targetable"): enemy.visible = false
	target.visible = true
	target.set_process(false)
	target.set_physics_process(false)
	var original := target.damage_receiver.max_health
	target.damage_receiver.max_health = 10000
	target.damage_receiver.reset()
	target.global_position = player.global_position + Vector2(100,0)
	player.facing_direction = 1
	weapons.target_selector.current_target = target
	festival_ultimate.gauge = 0
	for ignored in 4:
		fist._basic_remaining_s = 0
		fist._update_basic_attack(0.01)
	if not _check(fist.basic_attack_count == 4 and target.damage_receiver.health == 9962 and fist.combo_index == 0 and festival_ultimate.gauge == 16, "자동4연타 실제7/8/9/14 피해·기본 게이지4"): return false
	var health := target.damage_receiver.health
	for offset in [Vector2(110.1,0), Vector2(-100,0)]:
		target.global_position = player.global_position + offset
		fist._basic_remaining_s = 0
		fist._update_basic_attack(0.01)
	if not _check(target.damage_receiver.health == health, "주먹 사거리 밖·후방 자동 공격 차단"): return false
	target.global_position = player.global_position + Vector2(100,0)
	fist._basic_remaining_s = 0
	weapons.request_skill_1()
	if not _check(player._combat_action_active and is_equal_approx(player._combat_horizontal_velocity_px, 200.0 / 0.30), "쇄도권 실제 전진 동작"): return false
	fist._update_skill_action(0.31)
	if not _check(target.damage_receiver.health == health - 30 and fist.skill_hit_count == 1, "쇄도권 실제 피해30·1회 적중"): return false
	health = target.damage_receiver.health
	weapons.request_skill_2()
	fist._update_skill_action(0.66)
	if not _check(target.damage_receiver.health == health - 50 and fist.skill_hit_count == 6, "큰 프레임에도 연환권5타·총50 피해"): return false
	fist._skill_2_cooldown_s = 0
	weapons.request_skill_2()
	fist._update_skill_action(0.21)
	player.request_evade()
	health = target.damage_receiver.health
	fist._update_skill_action(1.0)
	if not _check(fist._action == SwordCombatController.Action.NONE and target.damage_receiver.health == health, "회피 취소 뒤 남은 연환권 타격 없음"): return false
	player.reset_movement_test(sandbox.TRACK_START)
	weapons.target_selector.current_target = target
	var loadout := weapons.skills.duplicate(true)
	loadout.fist[0] = "fist_wave"
	weapons.set_skill_loadout(loadout)
	fist._skill_1_cooldown_s = 0
	weapons.request_skill_1()
	fist._update_skill_action(0.19)
	var wave := get_nodes_in_group("sword_wave")[-1] as SwordWave
	target.global_position = wave.origin + Vector2(200,38)
	health = target.damage_receiver.health
	wave._physics_process(0.5)
	if not _check(target.damage_receiver.health == health - 42 and wave.weapon_family == "fist" and wave.max_hits == 2, "파동권 실제 투사체·피해42·주먹 태그"): return false
	wave.free()
	fist._finish_action("")
	player.set_lifesteal_unlocked(true)
	player.damage_receiver.health = 50
	fist._action_sequence += 1
	fist._damage_target(target,&"fist_basic",100,0,PackedStringArray(["fist","basic"]),0)
	if not _check(player.damage_receiver.health == 55, "주먹 실제 피해의 생명 흡수5%"): return false
	player.set_lifesteal_unlocked(false)
	fist._skill_1_cooldown_s = 4
	fist._skill_2_cooldown_s = 6
	weapons.request_weapon_switch()
	weapons.request_weapon_switch()
	if not _check(weapons.active_weapon_id == backup_family and not fist.active and weapons.blocked_switch_count == 1 and fist._skill_1_cooldown_s == 4 and fist._skill_2_cooldown_s == 6, "보조 전환·연속 차단·주먹 대기시간 보존"): return false
	weapons._physics_process(0.51)
	weapons.request_weapon_switch()
	if not _check(weapons.equip_reward("fist",1) and player.growth_damage(100,"fist","basic") == 125 and player.growth_damage(100,"fist","skill") == 115, "주먹 희귀 등급 실제 기본/스킬 피해"): return false
	var equipment := weapons.equipment.duplicate()
	for id in equipment: equipment[id] = 2
	if not _check(weapons.set_equipment(equipment) and player.growth_damage(100,"fist","basic") == (160 if backup_family == "bow" else 150) and player.growth_damage(100,"fist","skill") == (130 if backup_family == "bow" else 140) and player.growth_damage(100,"fist","ultimate") == 100, "주먹 영웅 등급·보조 고유 절반·필살기 장비 제외"): return false
	if not _test_all_martial_ultimates(target) or not _test_fist_enemy_rules(): return false
	weapons._emit_active_metrics()
	controls._show_result_screen()
	if not _check(controls.result_snapshot.fist_hits > 0 and controls.result_snapshot.fist_damage > 0 and is_equal_approx(float(controls.result_snapshot.fist_ratio), 1.0), "결과 화면 주먹 적중·피해·사용 비율 포함"): return false
	target.damage_receiver.max_health = original
	target.reset_target()
	return true

func _test_all_martial_ultimates(target: PrototypeTarget) -> bool:
	var expected := [[60,0],[0,40],[75,0],[25,25],[130,0],[40,45],[150,0],[0,65],[100,0],[30,60],[130,0],[0,80]]
	var index := 0
	for id in ["martial_artist", "thunder_fist", "phantom_dancer"]:
		for profile in PrototypeJobRewards.ultimates_for(id):
			festival_ultimate.reset_ultimate()
			target.damage_receiver.reset()
			target.global_position = player.global_position + Vector2(100,0)
			player.damage_receiver.health = 10
			festival_ultimate.select_job_ultimate(id,profile.id)
			festival_ultimate.gauge = 100
			festival_ultimate.request_ultimate()
			if not _check(target.damage_receiver.health == 10000 - int(expected[index][0]) and player.damage_receiver.health == 10 + int(expected[index][1]) and festival_ultimate._active and is_equal_approx(target.enemy_time_scale(),float(profile.slow)), "무도가·두 상위 직업12개 필살기 실제 피해·회복·감속"): return false
			festival_ultimate.finish_stage_effect()
			index += 1
	return true

func _test_fist_enemy_rules() -> bool:
	var event := DamageEvent.new()
	event.damage = 100
	event.tags = PackedStringArray(["fist", "basic"])
	event.source_position = Vector2(100, 0)
	var enemies := [EliteArmoredBoar.new(), BossHappinessGuardian.new(), BossHappinessHeart.new(), BossSera.new()]
	var recovery_damage := [60, 125, 150, 125]
	for index in enemies.size():
		var enemy: EliteArmoredBoar = enemies[index]
		enemy.state = EliteArmoredBoar.State.RECOVERY
		var adjusted := enemy._adjust_damage_event(event)
		if not _check(adjusted.damage == recovery_damage[index], "주먹 근접 공격도 갑옷·세 보스 빈틈 적용"): return false
		if index < 2:
			enemy.state = EliteArmoredBoar.State.STUNNED
			if not _check(enemy._adjust_damage_event(event).damage == (175 if index == 0 else 150), "주먹 기절 약점 배율"): return false
		if index == 1:
			enemy.state = EliteArmoredBoar.State.WARNING
			enemy._charge_direction = 1
			if not _check(enemy._adjust_damage_event(event).damage == 65, "수호 방패 정면 주먹 피해 감소"): return false
		enemy.free()
	return true
