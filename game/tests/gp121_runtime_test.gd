extends "res://tests/gp115_runtime_test.gd"

const GP121_SAVE := "user://gp121_checkpoint.json"
const GP121_META := "user://gp121_meta.jsonl"
const GP121_RECORD := "user://gp121_records.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP121_SAVE
	legacy.save_path = GP121_META
	if phase == "seed":
		store.clear_checkpoint()
		for path in [GP121_META, GP121_RECORD]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP121_RECORD
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
			if not _check(_offer_ids() == ["sword_crescent", "bow_volley", "sword_line", "bow_spread"], "보유하지 않은 검·활 각 두 개·전체 네 후보"): return
			var saved := store.load_checkpoint()
			_tap(controls.skill_reward_open_rect.get_center())
			if not await _test_four_candidate_layout(): return
			_tap(controls.skill_reward_cancel_rect.get_center())
			if not _check(store.load_checkpoint() == saved and weapons.skills == PrototypeSkillRewards.defaults(), "네 후보 조회·선택 취소는 저장과 구성 유지"): return
			_tap(controls.skill_reward_open_rect.get_center())
			_tap(controls.skill_reward_offer_rects[2].get_center())
			_tap(controls.skill_reward_slot_rects[1].get_center())
			weapons.sword_combat._skill_1_cooldown_s = 3.5
			weapons.sword_combat._skill_2_cooldown_s = 18.0
			weapons.bow_combat._skill_1_cooldown_s = 4.0
			weapons.bow_combat._skill_2_cooldown_s = 6.0
			var before := weapons.checkpoint_snapshot()
			store.save_path = "user://gp121_missing/checkpoint.json"
			_tap(controls.skill_reward_confirm_rect.get_center())
			store.save_path = GP121_SAVE
			if not _check(controls.current_screen_mode() == 14 and not runner.skills_claimed and weapons.checkpoint_snapshot() == before and store.load_checkpoint() == saved, "일섬 교체 저장 실패는 구성·모든 대기시간·정상 파일 롤백"): return
			_tap(controls.skill_reward_confirm_rect.get_center())
			if not _check(weapons.skills.sword == ["sword_dash", "sword_line"] and weapons.sword_combat._skill_2_cooldown_s == 18 and weapons.sword_combat._skill_1_cooldown_s == 3.5 and weapons.bow_combat._skill_1_cooldown_s == 4 and runner.skills_claimed and controls.movement_metrics.skill_2_button_label == "일섬", "일섬 슬롯2 확정·더 긴 대기시간·다른 슬롯·보조 무기 유지"): return
			if not _check(not sandbox._claim_skill_reward("bow_spread", 0), "같은 정예의 두 번째 새 스킬 교체 차단"): return
			var bad := store.load_checkpoint()
			bad.weapons.skills.bow[0] = "sword_line"
			if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA, "새 기술도 다른 무기 슬롯 저장 거부"): return
		"resume":
			if not _check(sandbox.continue_saved_run() and weapons.skills.sword[1] == "sword_line" and weapons.sword_combat._skill_2_cooldown_s == 18 and runner.skills_claimed, "별도 프로세스 일섬·슬롯2 대기시간·보상 사용 복원"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			if not _check(_offer_ids().size() == 4 and "sword_line" not in _offer_ids() and "sword_spin" in _offer_ids() and not runner.skills_claimed, "다음 정예는 현재 보유 기술 제외·버린 기술 재제안"): return
			_tap(controls.skill_reward_open_rect.get_center())
			var index := _offer_ids().find("bow_spread")
			_tap(controls.skill_reward_offer_rects[index].get_center())
			_tap(controls.skill_reward_slot_rects[0].get_center())
			_tap(controls.skill_reward_confirm_rect.get_center())
			if not _check(weapons.skills.bow == ["bow_spread", "bow_arrow_rain"] and weapons.bow_combat._skill_1_cooldown_s == 7 and weapons.skills.sword[1] == "sword_line" and store.load_checkpoint().weapons.skills == weapons.skills, "산개 슬롯1 교체·7초 대기시간·일섬 동시 저장"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and weapons.skills.sword[1] == "sword_line" and weapons.skills.bow[0] == "bow_spread", "서로 다른 슬롯의 새 두 기술 재시작 복원"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage(): return
			if not _check(sandbox._resolve_boss_choice("rescue") and store.load_checkpoint().is_empty(), "새 기술 구성으로 실제 보스 완주·저장 정리"): return
			controls.begin_retry()
			if not _check(weapons.skills == PrototypeSkillRewards.defaults(), "다음 새 도전은 기본 구성 초기화"): return
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			var old := store.load_checkpoint()
			old.weapons.erase("skills")
			old.stage.erase("skills_claimed")
			if not _check(store.save_checkpoint(old) == OK, "스킬 교체 이전 버전의 저장 준비"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and weapons.skills == PrototypeSkillRewards.defaults() and runner.skills_claimed, "초기 저장은 기본 스킬·기존 정예 사용 완료 호환"): return
			controls.show_skill_rewards()
			if not _check(controls.current_screen_mode() == 9 and not sandbox._claim_skill_reward("sword_line", 0), "이전 저장에 새 기술 보상 소급 지급 없음"): return
		"combat":
			controls.begin_retry()
			if not _test_directional_combat(): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-121 runtime test: OK (" + phase + ")")
	quit(0)

func _offer_ids() -> Array[String]:
	var ids: Array[String] = []
	for offer in controls.skill_reward_offers:
		ids.append(String(offer.id))
	return ids

func _test_four_candidate_layout() -> bool:
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_skill_reward_layout()
		var rects: Array = controls.skill_reward_offer_rects.duplicate()
		if not _check(rects.size() == 4, "네 후보 카드 모두 배치"): return false
		rects.append_array(controls.skill_reward_slot_rects)
		rects.append_array([controls.skill_reward_confirm_rect, controls.skill_reward_cancel_rect])
		var safe: Rect2 = controls.layout_snapshot().safe
		for i in rects.size():
			if not _check(safe.encloses(rects[i]), "두 화면비 후보·비교·확정·취소 안전 영역"): return false
			for j in range(i + 1, rects.size()):
				if not _check(not rects[i].intersects(rects[j]), "네 카드와 두 슬롯 입력 비중첩"): return false
		for i in 4:
			_tap(controls.skill_reward_offer_rects[i].get_center())
			for slot in 2:
				_tap(controls.skill_reward_slot_rects[slot].get_center())
				if not _check(controls.selected_skill_offer == i and controls.selected_skill_slot == slot, "네 기술 각각 두 교체 슬롯 실제 터치"): return false
			controls.queue_redraw()
			await process_frame
	return true

func _combat_target(key: String, point: Vector2) -> PrototypeTarget:
	var template: PrototypeTarget = sandbox.get_node("Targets/CrossingTargetA")
	var target := template.duplicate() as PrototypeTarget
	target.target_key = "gp121:" + key
	target.position = point
	target.visible = true
	sandbox.add_child(target)
	target.damage_receiver.max_health = 1000
	target.reset_target()
	target.set_process(false)
	return target

func _test_directional_combat() -> bool:
	for target in get_nodes_in_group("targetable"):
		target.visible = false
	player.growth_common_bonus = 0
	player.growth_sword_bonus = 0
	player.growth_bow_bonus = 0
	player.boss_legacy = {}
	player.memory_id = ""
	weapons.set_equipment({"sword": 0, "bow": 0})
	var loadout := {"sword": ["sword_line", "sword_spin"], "bow": ["bow_spread", "bow_arrow_rain"]}
	if not _check(weapons.set_skill_loadout(loadout), "새 두 기술 슬롯1 설정"): return false
	player.global_position = Vector2(1000, 780)
	player.facing_direction = 1
	var front := _combat_target("front", Vector2(1360, 780))
	var boundary := _combat_target("boundary", Vector2(1400, 690))
	var behind := _combat_target("behind", Vector2(920, 780))
	var far := _combat_target("far", Vector2(1420, 780))
	var high := _combat_target("high", Vector2(1200, 680))
	var sword := weapons.sword_combat
	var bow := weapons.bow_combat
	sword._skill_1_cooldown_s = 0
	sword._skill_2_cooldown_s = 4.5
	_press_skill(0)
	sword._update_skill_action(0.44)
	if not _check(front.damage_receiver.health == 1000 and sword._skill_1_cooldown_s == 12 and not player.combat_evade_allowed, "일섬 실제 모바일 시전·0.45초 전 타격 없음·취소 잠금"): return false
	sword._update_skill_action(0.02)
	if not _check(front.damage_receiver.health == 940 and boundary.damage_receiver.health == 940 and behind.damage_receiver.health == 1000 and far.damage_receiver.health == 1000 and high.damage_receiver.health == 1000 and sword.skill_hit_count == 2 and sword.total_damage == 120 and sword._line_remaining_s > 0 and sword._line_direction == 1, "일섬 정면 4m·상하 0.9m 경계·60 피해·후방/거리/높이 제외·시각 효과"): return false
	sword._update_skill_action(0.35)
	weapons.request_skill_1()
	if not _check(front.damage_receiver.health == 940 and sword._action == SwordCombatController.Action.NONE and sword._skill_2_cooldown_s == 4.5, "일섬 타격 중복·재사용 중 재시전 없음·다른 슬롯 유지"): return false
	loadout.sword = ["sword_spin", "sword_line"]
	weapons.set_skill_loadout(loadout)
	player.facing_direction = -1
	sword._skill_2_cooldown_s = 0
	_press_skill(1)
	sword._update_skill_action(0.46)
	if not _check(behind.damage_receiver.health == 940 and front.damage_receiver.health == 940 and sword._skill_2_cooldown_s == 12 and sword._line_direction == -1 and controls.movement_metrics.skill_2_button_label == "일섬", "슬롯2 일섬은 왼쪽 정면만 타격·방향·HUD 일치"): return false
	sword._update_skill_action(0.35)
	sword._skill_2_cooldown_s = 0
	weapons.request_skill_2()
	_interrupt_cast("line-interrupt")
	sword._update_skill_action(0.80)
	if not _check(behind.damage_receiver.health == 940 and sword._action == SwordCombatController.Action.NONE and sword._skill_2_cooldown_s == 12, "실제 피격 취소는 일섬 지연 타격 없음·대기시간 환급 없음"): return false
	player._input_lock_remaining_s = 0
	player.damage_receiver.tick(1.0)
	for target in [front, boundary, behind, far, high]: target.visible = false
	weapons.active_weapon_id = "bow"
	weapons._apply_active_weapon()
	weapons.set_equipment({"sword": 0, "bow": 1})
	player.facing_direction = 1
	bow._skill_1_cooldown_s = 0
	bow._skill_2_cooldown_s = 6
	_press_skill(0)
	bow._update_skill_action(0.17)
	if not _check(get_nodes_in_group("bow_projectile").is_empty(), "산개는 0.18초 전 발사 없음"): return false
	bow._update_skill_action(0.02)
	var shots := get_nodes_in_group("bow_projectile")
	if not _check(shots.size() == 3 and bow._skill_1_cooldown_s == 7 and bow._skill_2_cooldown_s == 6 and not bow.rain_marker.visible and controls.movement_metrics.skill_1_button_label == "산개", "산개 슬롯1 세 발·7초·다른 슬롯 유지·화살비 표시 없음·HUD"): return false
	var ids := {}
	var fan_targets: Array[PrototypeTarget] = []
	for i in shots.size():
		var shot: BowProjectile = shots[i]
		ids[shot.projectile_id] = true
		shot.set_physics_process(false)
		var point := shot.global_position + shot.direction * 400 + Vector2(0, 38)
		fan_targets.append(_combat_target("fan%d" % i, point))
	if not _check(ids.size() == 3 and shots[0].direction.x > 0 and shots[0].direction.y < -0.25 and absf(shots[1].direction.y) < 0.001 and shots[2].direction.y > 0.25, "세 발 고유 ID와 -15/0/+15도 실제 발사 방향"): return false
	var extra := _combat_target("extra", Vector2(1800, 780))
	for i in shots.size():
		var shot: BowProjectile = shots[i]
		var end: Vector2 = fan_targets[i].global_position + Vector2(0, -38)
		shot._check_hits(shot.global_position, end)
		shot._check_hits(shot.global_position, end)
		shot._check_hits(extra.global_position + Vector2(0, -38), extra.global_position + Vector2(0, -38))
		if not _check(fan_targets[i].damage_receiver.health == 982 and shot._hit_count == 1, "서로 다른 적 실제 적중·희귀 활 배율·화살당 1개체·중복 차단"): return false
	if not _check(extra.damage_receiver.health == 1000 and bow.skill_hit_count == 3 and bow.total_damage == 54, "1개체 제한 후 추가 관통 없음·세 발 모두 스킬 집계"): return false
	for shot in shots: shot.free()
	bow._finish_action("검사")
	loadout.bow = ["bow_piercing", "bow_spread"]
	weapons.set_skill_loadout(loadout)
	bow._skill_2_cooldown_s = 0
	player.facing_direction = -1
	weapons.request_skill_2()
	_interrupt_cast("spread-interrupt")
	bow._update_skill_action(0.50)
	if not _check(get_nodes_in_group("bow_projectile").is_empty() and bow._skill_2_cooldown_s == 7, "슬롯2 산개 실제 피격 취소는 세 발 생성 없음·대기시간 보존"): return false
	player._input_lock_remaining_s = 0
	player.damage_receiver.tick(1.0)
	bow._skill_2_cooldown_s = 0
	weapons.request_skill_2()
	bow._update_skill_action(0.19)
	shots = get_nodes_in_group("bow_projectile")
	if not _check(shots.size() == 3 and shots[0].direction.x < 0 and shots[1].direction.x < 0 and shots[2].direction.x < 0 and controls.movement_metrics.skill_2_button_label == "산개", "슬롯2 산개도 왼쪽 부채꼴 세 발·HUD 일치"): return false
	for shot in shots: shot.free()
	bow._finish_action("검사")
	bow._skill_2_cooldown_s = 0
	weapons.request_skill_2()
	weapons.active_weapon_id = "sword"
	weapons._apply_active_weapon()
	bow._update_skill_action(0.50)
	if not _check(get_nodes_in_group("bow_projectile").is_empty() and bow._skill_2_cooldown_s == 7, "보조 무기로 바뀐 산개는 지연 발사 없음·대기시간 유지"): return false
	sword._skill_2_cooldown_s = 0
	weapons.request_skill_2()
	weapons.active_weapon_id = "bow"
	weapons._apply_active_weapon()
	sword._update_skill_action(0.80)
	if not _check(sword._action == SwordCombatController.Action.NONE and sword._line_remaining_s == 0 and sword._skill_2_cooldown_s == 12, "보조 무기로 바뀐 일섬은 지연 타격·시각 효과 없음·대기시간 유지"): return false
	return true

func _press_skill(slot: int) -> void:
	controls._handle_touch_released(4)
	_tap(controls.action_rects[&"skill_1" if slot == 0 else &"skill_2"].get_center())
	controls._physics_process(0.01)
	controls._handle_touch_released(4)

func _interrupt_cast(id: String) -> void:
	var event := DamageEvent.new()
	event.event_id = StringName("gp121:" + id)
	event.attacker_id = &"enemy"
	event.damage = 1
	event.stagger_s = 0.20
	event.tags = PackedStringArray(["enemy", "test"])
	player.receive_damage(event)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-121 failed: " + message)
		quit(1)
	return condition
