extends "res://tests/gp110_runtime_test.gd"

const GP115_SAVE := "user://gp115_checkpoint.json"
const GP115_LEGACY := "user://gp115_meta.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP115_SAVE
	legacy.save_path = GP115_LEGACY
	if phase == "seed":
		store.clear_checkpoint()
		for path in [GP115_LEGACY, "user://gp115_records.jsonl"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = "user://gp115_records.jsonl"
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	recorder = sandbox.get_node("LocalTestRecorder")
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	weapons.sword_combat.set_process(false)
	weapons.bow_combat.set_process(false)
	runner.set_process(false)
	match phase:
		"seed":
			controls.begin_retry()
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			if not _check(controls.current_screen_mode() == 9 and not runner.skills_claimed and controls.skill_reward_offers[0].id == "sword_crescent" and controls.skill_reward_offers[1].id == "bow_volley", "무기 보상 후 두 스킬 후보"): return
			var saved := store.load_checkpoint()
			var previous := weapons.checkpoint_snapshot()
			_tap(controls.skill_reward_open_rect.get_center())
			if not _check(controls.current_screen_mode() == 14 and paused, "교체 화면은 전투 정지 유지"): return
			_tap(controls.skill_reward_confirm_rect.get_center())
			if not _check(weapons.checkpoint_snapshot() == previous and not sandbox._claim_skill_reward("unknown", 0) and not sandbox._claim_skill_reward("sword_dash", 1) and not sandbox._claim_skill_reward("bow_volley", 2), "선택 없는 확정·잘못된 기술·중복 기술·슬롯 차단"): return
			_tap(controls.skill_reward_cancel_rect.get_center())
			if not _check(controls.current_screen_mode() == 9 and store.load_checkpoint() == saved and weapons.checkpoint_snapshot() == previous, "유지는 교체·소비·저장 변경 없음"): return
			_tap(controls.skill_reward_open_rect.get_center())
			if not await _test_layout(): return
			_tap(controls.skill_reward_offer_rects[0].get_center())
			_tap(controls.skill_reward_slot_rects[0].get_center())
			weapons.sword_combat._skill_1_cooldown_s = 12.5
			weapons.sword_combat._skill_2_cooldown_s = 4.5
			previous = weapons.checkpoint_snapshot()
			store.save_path = "user://gp115_missing/checkpoint.json"
			_tap(controls.skill_reward_confirm_rect.get_center())
			if not _check(controls.current_screen_mode() == 14 and not runner.skills_claimed and weapons.checkpoint_snapshot() == previous, "교체 저장 실패는 기술·모든 대기시간 롤백"): return
			store.save_path = GP115_SAVE
			if not _check(store.load_checkpoint() == saved, "실패는 정상 저장 보존"): return
			_tap(controls.skill_reward_confirm_rect.get_center())
			if not _check(controls.current_screen_mode() == 9 and runner.skills_claimed and weapons.skills.sword == ["sword_crescent", "sword_spin"] and is_equal_approx(weapons.sword_combat._skill_1_cooldown_s, 12.5) and is_equal_approx(weapons.sword_combat._skill_2_cooldown_s, 4.5) and controls.movement_metrics.skill_1_button_label == "반달", "실제 슬롯1 확정·더 긴 기존 대기시간·다른 슬롯·HUD 유지"): return
			controls.show_skill_rewards()
			if not _check(controls.current_screen_mode() == 9 and not sandbox._claim_skill_reward("bow_volley", 0), "같은 정예의 두 번째 교체 차단"): return
			saved = store.load_checkpoint()
			for bad in [null, {}, {"sword": ["sword_dash", "sword_dash"], "bow": ["bow_piercing", "bow_arrow_rain"]}, {"sword": ["sword_dash", "bow_volley"], "bow": ["bow_piercing", "bow_arrow_rain"]}, {"sword": ["sword_dash", "unknown"], "bow": ["bow_piercing", "bow_arrow_rain"]}]:
				var invalid := saved.duplicate(true)
				invalid.weapons.skills = bad
				if not _check(store.save_checkpoint(invalid) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "손상·중복·타 무기 기술 저장 거부"): return
			var invalid := saved.duplicate(true)
			invalid.stage.skills_claimed = "true"
			if not _check(not RunCheckpointStore.valid_state(invalid), "소비 상태의 잘못된 형식 거부"): return
		"resume":
			if not _check(sandbox.continue_saved_run() and controls.current_screen_mode() == 9 and runner.skills_claimed and weapons.skills.sword[0] == "sword_crescent" and is_equal_approx(weapons.sword_combat._skill_1_cooldown_s, 12.5), "별도 프로세스의 교체 구성·소비·대기시간 복원"): return
			sandbox._continue_stage("wind")
			if not _check(weapons.skills.sword[0] == "sword_crescent" and not runner.skills_claimed, "다음 구간에서 구성 유지·정예 교체 갱신"): return
			if not _finish_stage(): return
			_tap(controls.weapon_reward_rects[1].get_center())
			_tap(controls.weapon_reward_confirm_rect.get_center())
			if not _check(weapons.skills.sword[0] == "sword_crescent" and weapons.equipment.bow == 2, "무기 등급 교체는 스킬 구성 유지"): return
			_tap(controls.skill_reward_open_rect.get_center())
			if not _check(controls.skill_reward_offers[0].id == "sword_dash", "버린 기존 기술도 다음 정예에서 다시 제안"): return
			_tap(controls.skill_reward_offer_rects[1].get_center())
			_tap(controls.skill_reward_slot_rects[1].get_center())
			_tap(controls.skill_reward_confirm_rect.get_center())
			if not _check(weapons.skills == {"sword": ["sword_crescent", "sword_spin"], "bow": ["bow_piercing", "bow_volley"]} and is_equal_approx(weapons.bow_combat._skill_2_cooldown_s, 8.0) and store.load_checkpoint().weapons.skills == weapons.skills, "활 슬롯2 교체·새 기술 대기시간 시작·원자적 저장"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and weapons.skills.bow[1] == "bow_volley", "검·활 교체 동시 복원"): return
			sandbox._continue_stage("meadow")
			if not _finish_stage(): return
			if not _check(sandbox._resolve_boss_choice("rescue") and controls.current_screen_mode() == 1 and store.load_checkpoint().is_empty(), "교체한 도전의 실제 보스 완주·결과·저장 정리"): return
			controls.begin_retry("bow")
			if not _check(weapons.skills == PrototypeSkillRewards.defaults() and weapons.bow_combat.skill_2.skill_id == &"bow_arrow_rain", "새 도전은 기본 스킬로 초기화"): return
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			var saved := store.load_checkpoint()
			saved.stage.erase("skills_claimed")
			saved.weapons.erase("skills")
			if not _check(store.save_checkpoint(saved) == OK, "이전 버전 완료 저장 준비"): return
		"legacy-resume":
			if not _check(sandbox.continue_saved_run() and weapons.skills == PrototypeSkillRewards.defaults() and runner.skills_claimed and controls.skill_reward_claimed, "이전 저장은 기본 구성·기존 정예 보상 완료로 호환"): return
			controls.show_skill_rewards()
			if not _check(controls.current_screen_mode() == 9, "이전 저장에 새 보상 소급 지급 없음"): return
		"combat":
			controls.begin_retry()
			if not _test_combat(): return
		_:
			_check(false, "검사 단계 오류")
			return
	print("GP-115 runtime test: OK (" + phase + ")")
	quit(0)

func _test_layout() -> bool:
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_skill_reward_layout()
		var rectangles: Array = controls.skill_reward_offer_rects.duplicate()
		rectangles.append_array(controls.skill_reward_slot_rects)
		rectangles.append_array([controls.skill_reward_confirm_rect, controls.skill_reward_cancel_rect])
		var safe: Rect2 = controls.layout_snapshot().safe
		for i in rectangles.size():
			if not _check(safe.encloses(rectangles[i]), "교체 두 화면비 안전 영역"): return false
			for j in range(i + 1, rectangles.size()):
				if not _check(not rectangles[i].intersects(rectangles[j]), "교체 입력 겹침 없음"): return false
		for offer in [0, 1]:
			_tap(controls.skill_reward_offer_rects[offer].get_center())
			_tap(controls.skill_reward_slot_rects[1].get_center())
			controls.queue_redraw()
			await process_frame
	return true

func _test_combat() -> bool:
	var target: PrototypeTarget = sandbox.get_node("Targets/CrossingTargetA")
	for other in get_nodes_in_group("targetable"):
		if other is PrototypeTarget and other != target:
			other.visible = false
	target.damage_receiver.max_health = 1000
	target.reset_target()
	target.visible = true
	target.set_process(false)
	player.growth_common_bonus = 0.0
	player.growth_sword_bonus = 0.0
	player.growth_bow_bonus = 0.0
	player.boss_legacy = {}
	player.memory_id = ""
	weapons.set_equipment({"sword": 0, "bow": 0})
	var loadout := {"sword": ["sword_crescent", "sword_dash"], "bow": ["bow_arrow_rain", "bow_volley"]}
	if not _check(weapons.set_skill_loadout(loadout), "시험 구성 설정"): return false
	player.position = Vector2(1000, 780)
	target.position = Vector2(1180, 780)
	var sword := weapons.sword_combat
	var bow := weapons.bow_combat
	sword._skill_1_cooldown_s = 0
	sword._skill_2_cooldown_s = 0
	sword.request_skill_1()
	sword._update_skill_action(0.23)
	if not _check(target.damage_receiver.health == 948 and sword.skill_hit_count == 1 and sword._skill_1_cooldown_s == 10 and sword._skill_2_cooldown_s == 0, "슬롯1 반달 실제 범위 52 피해·해당 슬롯만 재사용"): return false
	sword._update_skill_action(0.25)
	sword.request_skill_1()
	if not _check(sword._action == SwordCombatController.Action.NONE and target.damage_receiver.health == 948, "재사용 중 중복 시전 차단"): return false
	sword._skill_1_cooldown_s = 0
	sword.request_skill_1()
	sword._on_player_interrupted("피격")
	sword._update_skill_action(0.5)
	if not _check(target.damage_receiver.health == 948, "반달 타격 전 피격 취소·지연 타격 없음"): return false
	loadout.sword = ["sword_spin", "sword_crescent"]
	weapons.set_skill_loadout(loadout)
	sword._skill_2_cooldown_s = 0
	sword.request_skill_2()
	sword._update_skill_action(0.48)
	if not _check(target.damage_receiver.health == 896 and sword._skill_2_cooldown_s == 10, "반달 슬롯2에서도 같은 공격·해당 슬롯 재사용"): return false
	weapons.active_weapon_id = "bow"
	weapons._apply_active_weapon()
	player.facing_direction = 1
	player.position = Vector2(1000, 780)
	target.position = Vector2(1400, 780)
	target.damage_receiver.health = 1000
	bow._skill_1_cooldown_s = 0
	bow._skill_2_cooldown_s = 0
	bow.request_skill_2()
	bow._update_skill_action(0.45)
	var shots := get_nodes_in_group("bow_projectile")
	if not _check(shots.size() == 3 and bow._skill_2_cooldown_s == 8 and bow._skill_1_cooldown_s == 0, "연속 사격 슬롯2 실제 세 발·슬롯별 재사용"): return false
	var ids := {}
	for shot in shots:
		ids[shot.projectile_id] = true
		shot.set_process(false)
		shot._check_hits(target.global_position + Vector2(0, -38), target.global_position + Vector2(0, -38))
		shot._check_hits(target.global_position + Vector2(0, -38), target.global_position + Vector2(0, -38))
	if not _check(ids.size() == 3 and target.damage_receiver.health == 946 and bow.skill_hit_count == 3 and bow.total_damage == 54, "세 화살 고유 ID·18씩 실제 피해·모두 스킬 집계"): return false
	for shot in shots:
		shot.free()
	bow._finish_action("검사")
	loadout.bow = ["bow_volley", "bow_piercing"]
	weapons.set_skill_loadout(loadout)
	bow._skill_1_cooldown_s = 0
	bow.request_skill_1()
	bow._update_skill_action(0.13)
	bow._on_player_evade_started()
	bow._update_skill_action(0.5)
	if not _check(get_nodes_in_group("bow_projectile").size() == 1 and bow._skill_1_cooldown_s == 8 and controls.movement_metrics.skill_1_button_label == "연사", "슬롯1 연사·회피 취소 후 남은 두 발 없음·HUD 일치"): return false
	return true

func _check(condition: bool, message: String) -> bool:
	if condition: return true
	push_error("GP-115 실패: " + message)
	paused = false
	quit(1)
	return false
