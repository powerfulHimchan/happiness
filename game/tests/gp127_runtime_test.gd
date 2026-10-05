extends "res://tests/gp121_runtime_test.gd"

const GP127_SAVE := "user://gp127_checkpoint.json"
const GP127_META := "user://gp127_meta.jsonl"
const GP127_RECORD := "user://gp127_records.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP127_SAVE
	legacy.save_path = GP127_META
	if phase == "seed":
		store.clear_checkpoint()
		for path in [GP127_META, GP127_RECORD]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP127_RECORD
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
	weapons.sword_combat.set_physics_process(false)
	weapons.bow_combat.set_physics_process(false)
	weapons.sword_combat.set_process(false)
	weapons.bow_combat.set_process(false)
	player.set_physics_process(false)
	runner.set_process(false)
	match phase:
		"seed":
			controls.begin_retry()
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			var saved := store.load_checkpoint()
			_tap(controls.skill_reward_open_rect.get_center())
			if not await _test_candidates(): return
			if not _check(store.load_checkpoint() == saved and weapons.skills == PrototypeSkillRewards.defaults() and not runner.skills_claimed, "후보 조회·터치는 보상 소비·구성·저장 변경 없음"): return
			if not _check(not sandbox._claim_skill_reward("sword_triple", 1), "현재 화면에 없는 새 기술 직접 지급 차단"): return
			_tap(controls.skill_reward_cycle_rect.get_center())
			_select_offer("sword_triple", 1)
			var before := weapons.checkpoint_snapshot()
			store.save_path = "user://gp127_missing/checkpoint.json"
			_tap(controls.skill_reward_confirm_rect.get_center())
			store.save_path = GP127_SAVE
			if not _check(weapons.checkpoint_snapshot() == before and not runner.skills_claimed and store.load_checkpoint() == saved, "삼연 교체 저장 실패·정상 파일·모든 대기시간 롤백"): return
			_tap(controls.skill_reward_confirm_rect.get_center())
			if not _check(weapons.skills.sword == ["sword_dash", "sword_triple"] and weapons.sword_combat._skill_2_cooldown_s == 9 and runner.skills_claimed and controls.movement_metrics.skill_2_button_label == "삼연", "삼연 실제 확정·슬롯2·9초·HUD·보상 소비"): return
			var bad := store.load_checkpoint()
			bad.weapons.skills.bow[0] = "sword_triple"
			if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA, "새 기술 다른 무기 저장 거부"): return
		"resume":
			if not _check(sandbox.continue_saved_run() and weapons.skills.sword[1] == "sword_triple" and weapons.sword_combat._skill_2_cooldown_s == 9, "별도 프로세스 삼연 복원·대기시간 유지"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			_tap(controls.skill_reward_open_rect.get_center())
			_tap(controls.skill_reward_cycle_rect.get_center())
			if not _check("sword_triple" not in _offer_ids() and "bow_focus" in _offer_ids(), "다음 정예 보유 제외·집중 제안"): return
			_select_offer("bow_focus", 0)
			_tap(controls.skill_reward_confirm_rect.get_center())
			if not _check(weapons.skills.bow == ["bow_focus", "bow_arrow_rain"] and weapons.bow_combat._skill_1_cooldown_s == 10 and store.load_checkpoint().weapons.skills == weapons.skills, "집중 슬롯1·10초·두 새 기술 동시 저장"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and weapons.skills.sword[1] == "sword_triple" and weapons.skills.bow[0] == "bow_focus", "두 새 기술 재시작 복원"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage(): return
			if not _check(sandbox._resolve_boss_choice("rescue") and store.load_checkpoint().is_empty(), "새 구성 보스 완주·저장 정리"): return
			controls.begin_retry()
			if not _check(weapons.skills == PrototypeSkillRewards.defaults(), "새 도전 기본 스킬 초기화"): return
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			var old := store.load_checkpoint()
			old.weapons.erase("skills")
			old.stage.erase("skills_claimed")
			if not _check(store.save_checkpoint(old) == OK, "기존 저장 준비"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and weapons.skills == PrototypeSkillRewards.defaults() and runner.skills_claimed, "이전 저장 기본 스킬·보상 사용 완료 유지"): return
			controls.show_skill_rewards()
			if not _check(controls.current_screen_mode() == 9 and not sandbox._claim_skill_reward("bow_focus", 0), "이전 정예에 새 기술 소급 지급 없음"): return
		"combat":
			controls.begin_retry()
			if not await _test_tactical_combat(): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-127 runtime test: OK (" + phase + ")")
	quit(0)

func _select_offer(id: String, slot: int) -> void:
	_tap(controls.skill_reward_offer_rects[_offer_ids().find(id)].get_center())
	_tap(controls.skill_reward_slot_rects[slot].get_center())

func _test_candidates() -> bool:
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		var seen := {}
		for page in 3:
			controls._refresh_skill_reward_layout()
			var rects: Array = controls.skill_reward_offer_rects.duplicate()
			rects.append_array(controls.skill_reward_slot_rects)
			rects.append_array([controls.skill_reward_cycle_rect, controls.skill_reward_confirm_rect, controls.skill_reward_cancel_rect])
			var safe: Rect2 = controls.layout_snapshot().safe
			for i in rects.size():
				if not _check(safe.encloses(rects[i]), "후보 전환 포함 두 화면비 안전 영역"): return false
				for j in range(i + 1, rects.size()):
					if not _check(not rects[i].intersects(rects[j]), "전환·후보·슬롯 입력 비중첩"): return false
			for id in _offer_ids():
				seen[id] = true
				if not _check(id not in weapons.skills[PrototypeSkillRewards.weapon_for(id)], "보유 스킬 제외"): return false
			_select_offer(_offer_ids()[0], 0)
			controls.queue_redraw()
			await process_frame
			_tap(controls.skill_reward_cycle_rect.get_center())
			if not _check(controls.selected_skill_offer == -1 and controls.selected_skill_slot == -1, "후보 전환은 오래된 선택 초기화"): return false
		if not _check(seen.size() == 6 and seen.has("sword_triple") and seen.has("bow_focus") and controls.skill_reward_offset == 0, "여섯 미보유 기술 전체 조회·세 번 후 첫 후보"): return false
	return true

func _test_tactical_combat() -> bool:
	for target in get_nodes_in_group("targetable"): target.visible = false
	player.growth_common_bonus = 0
	player.growth_sword_bonus = 0
	player.growth_bow_bonus = 0
	player.boss_legacy = {}
	player.memory_id = ""
	weapons.set_equipment({"sword": 0, "bow": 0})
	weapons.set_skill_loadout({"sword": ["sword_triple", "sword_spin"], "bow": ["bow_focus", "bow_arrow_rain"]})
	player.global_position = Vector2(1000, 780)
	player.facing_direction = 1
	var front := _combat_target("triple-front", Vector2(1200, 780))
	var boundary := _combat_target("triple-boundary", Vector2(1240, 690))
	var behind := _combat_target("triple-behind", Vector2(920, 780))
	var far := _combat_target("triple-far", Vector2(1250, 780))
	var high := _combat_target("triple-high", Vector2(1200, 680))
	for target in [front, boundary, behind, far, high]: target.damage_receiver.post_hit_invulnerability_s = 0
	var sword := weapons.sword_combat
	var bow := weapons.bow_combat
	sword._skill_1_cooldown_s = 0
	_press_skill(0)
	sword._update_skill_action(0.13)
	if not _check(front.damage_receiver.health == 1000 and sword._skill_1_cooldown_s == 9, "삼연 모바일 시전·첫 타격 전·9초"): return false
	sword._update_skill_action(0.02)
	if not _check(front.damage_receiver.health == 976 and not player.combat_evade_allowed, "첫 타격 24·초기 회피 잠금"): return false
	sword._update_skill_action(0.20)
	if not _check(front.damage_receiver.health == 948 and player.combat_evade_allowed, "둘째 타격 28·회피 취소 허용"): return false
	sword._update_skill_action(0.20)
	if not _check(front.damage_receiver.health == 912 and boundary.damage_receiver.health == 912 and behind.damage_receiver.health == 1000 and far.damage_receiver.health == 1000 and high.damage_receiver.health == 1000 and sword.skill_hit_count == 6, "셋째36·총88·정면2.4m 경계·후방/거리/높이 제외·각 타격 고유 ID: %s" % [str([front.damage_receiver.health, boundary.damage_receiver.health, behind.damage_receiver.health, far.damage_receiver.health, high.damage_receiver.health, sword.skill_hit_count])]): return false
	sword._update_skill_action(0.30)
	sword._skill_1_cooldown_s = 0
	_press_skill(0)
	sword._update_skill_action(0.15)
	_interrupt_cast("triple-interrupt")
	sword._update_skill_action(1.0)
	if not _check(front.damage_receiver.health == 888 and sword._action == SwordCombatController.Action.NONE and sword._skill_1_cooldown_s == 9, "피격은 삼연 남은 두 타격 취소·대기시간 유지"): return false
	player._input_lock_remaining_s = 0
	player.damage_receiver.tick(1.0)
	for target in [front, boundary, behind, far, high]: target.visible = false
	weapons.active_weapon_id = "bow"
	weapons._apply_active_weapon()
	player.facing_direction = -1
	bow._skill_1_cooldown_s = 0
	_press_skill(0)
	bow._update_skill_action(0.69)
	if not _check(get_nodes_in_group("bow_projectile").is_empty() and not player._combat_move_allowed and not player._combat_turn_allowed and player.combat_evade_allowed and bow._skill_1_cooldown_s == 10, "집중0.7초 준비·이동/방향 고정·회피 취소·10초"): return false
	bow.queue_redraw()
	await process_frame
	bow._update_skill_action(0.02)
	var shots := get_nodes_in_group("bow_projectile")
	if not _check(shots.size() == 1 and shots[0].direction == Vector2.LEFT and shots[0].damage == 80 and shots[0].max_hits == 1 and shots[0].attack_id == &"bow_focus", "집중 정면 한 발·80 피해·1개체·실제 투사체"): return false
	var shot: BowProjectile = shots[0]
	shot.set_physics_process(false)
	var victim := _combat_target("focus-victim", Vector2(620, 770))
	var extra := _combat_target("focus-extra", Vector2(400, 770))
	shot._check_hits(shot.global_position, victim.global_position + Vector2(0, -38))
	shot._check_hits(extra.global_position, extra.global_position)
	if not _check(victim.damage_receiver.health == 920 and extra.damage_receiver.health == 1000 and bow.skill_hit_count == 1, "집중 실제 적중·관통/중복 없음·스킬 집계"): return false
	shot.free()
	bow._finish_action("검사")
	bow._skill_1_cooldown_s = 0
	_press_skill(0)
	_interrupt_cast("focus-interrupt")
	bow._update_skill_action(1.1)
	if not _check(get_nodes_in_group("bow_projectile").is_empty() and bow._skill_1_cooldown_s == 10 and not player._combat_action_active, "피격은 집중 발사 취소·이동 잠금 해제·대기시간 유지"): return false
	player._input_lock_remaining_s = 0
	player.damage_receiver.tick(1.0)
	bow._skill_1_cooldown_s = 0
	_press_skill(0)
	weapons.active_weapon_id = "sword"
	weapons._apply_active_weapon()
	bow._update_skill_action(1.1)
	if not _check(get_nodes_in_group("bow_projectile").is_empty() and bow._action == BowCombatController.Action.NONE, "무기 전환은 준비·발사·표시 취소"): return false
	return true

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-127 failed: " + message)
		quit(1)
	return condition
