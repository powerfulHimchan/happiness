extends "res://tests/gp137_runtime_test.gd"

const EXPECTED := {
	"duelist_sword": ["sword", "basic", 5, 20, 10, 35],
	"hunter_bow": ["bow", "basic", 5, 20, 10, 35],
	"runic_sword": ["sword", "skill", 5, 20, 10, 35],
	"spell_bow": ["bow", "skill", 5, 20, 10, 35],
	"fencer_sword": ["sword", "basic", 10, 15, 20, 25],
	"precision_bow": ["bow", "skill", 10, 15, 20, 25],
	"forged_sword": ["sword", "skill", 20, 5, 40, 10],
	"sturdy_bow": ["bow", "basic", 20, 5, 40, 10],
	"balanced_sword": ["sword", "basic", 25, 0, 45, 5],
	"balanced_bow": ["bow", "skill", 25, 0, 45, 5],
}

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var id := args[1] if args.size() > 1 else "duelist_sword"
	var expected: Array = EXPECTED[id]
	var weapon: String = expected[0]
	var prefix := "user://gp226_%s" % id
	store.save_path = prefix + "_checkpoint.json"
	legacy.save_path = prefix + "_meta.jsonl"
	if phase in ["seed", "catalog"]:
		store.clear_checkpoint()
		for suffix in ["_meta.jsonl", "_records.jsonl", "_abilities.jsonl"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
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
	recorder = sandbox.get_node("LocalTestRecorder")
	ultimate = sandbox.get_node("Player/UltimateController")
	for actor in [player, weapons, weapons.sword_combat, weapons.bow_combat, ultimate, runner]:
		actor.set_process(false)
		actor.set_physics_process(false)
	growth.jobs_enabled = false
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	match phase:
		"seed":
			controls.begin_retry("bow" if weapon == "sword" else "sword", 5)
			if not _finish_stage(): return
			weapons.sword_combat._skill_1_cooldown_s = 3.25
			weapons.bow_combat._skill_2_cooldown_s = 4.5
			if not await _test_reward_pages(id): return
			var saved := store.load_checkpoint()
			for bad in ["unknown_design", "clockwork_bow" if weapon == "sword" else "clockwork_sword"]:
				var corrupt := saved.duplicate(true)
				corrupt.weapons.blueprints[weapon] = bad
				if not _check(store.save_checkpoint(corrupt) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "미지/다른 무기 설계 저장 거부·기존 정상 파일 보호"): return
			var before := weapons.checkpoint_snapshot()
			store.save_path = "user://gp226_missing/checkpoint.json"
			_tap(controls.weapon_reward_confirm_rect.get_center())
			store.save_path = prefix + "_checkpoint.json"
			if not _check(weapons.checkpoint_snapshot() == before and store.load_checkpoint() == saved and not runner.reward_claimed and controls.weapon_reward_cards[controls.selected_weapon_reward].id == id, "장비 기록 실패 롤백·선택/대기/정상 저장 유지"): return
			_tap(controls.weapon_reward_confirm_rect.get_center())
			if not _check(weapons.blueprints[weapon] == id and weapons.equipment[weapon] == 1 and runner.reward_claimed and not sandbox._claim_weapon_reward(id), "실제 희귀 장착·중복 확정 거부"): return
			if not _test_design_damage(id, 1): return
		"resume":
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and runner.stage_number == 1 and runner.stage_limit == 5 and weapons.blueprints[weapon] == id and weapons.equipment[weapon] == 1 and weapons.sword_combat._skill_1_cooldown_s == 3.25 and weapons.bow_combat._skill_2_cooldown_s == 4.5, "별도 프로세스 반복 복원·희귀 장비/양쪽 대기 유지"): return
			if not _test_design_damage(id, 1): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _finish_stage() or not await _test_reward_pages(id): return
			_tap(controls.weapon_reward_confirm_rect.get_center())
			if not _check(weapons.blueprints[weapon] == id and weapons.equipment[weapon] == 2 and not weapons.equip_reward(id, 1), "둘째 정예 영웅 승급·하향 장착 거부"): return
			if not _test_design_damage(id, 2): return
			if not await _test_weapon_codex(true): return
		"finish":
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and weapons.blueprints[weapon] == id and weapons.equipment[weapon] == 2, "영웅 별도 반복 복원·효과 중첩 없음"): return
			if not _test_design_damage(id, 2): return
			for stage in [3, 4, 5]:
				_tap(controls.stage_route_rects[0].get_center())
				if not _finish_stage(): return
				if stage < 5 and not _check(sandbox._claim_weapon_reward(""), "다음 정예 장비 유지"): return
			if not _check(sandbox._resolve_boss_choice("rescue"), "실제 보스 선택·5단계 완주"): return
			if not _check(store.load_checkpoint().is_empty() and runner.stage_history.size() == 5, "5단계 완주·저장 정리"): return
			controls.begin_retry()
			if not _check(weapons.blueprints == {"sword": "", "bow": ""} and weapons.equipment == {"sword": 0, "bow": 0}, "새 도전 기본 장비 초기화"): return
		"catalog":
			if not _test_catalog(): return
			if not await _test_weapon_codex(false): return
		_:
			_check(false, "잘못된 실행 단계")
			return
	paused = false
	sandbox.free()
	print("GP-217–226 runtime test: OK (%s %s)" % [phase, id])
	quit(0)

func _test_reward_pages(id: String) -> bool:
	var state := weapons.checkpoint_snapshot()
	var saved := store.load_checkpoint()
	var health := player.damage_receiver.health
	var gauge := ultimate.gauge
	var found: Array[String] = []
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_layout()
		while controls.weapon_reward_page > 0: _tap(controls.weapon_reward_previous_rect.get_center())
		found.clear()
		for page in 4:
			controls._refresh_weapon_reward_layout()
			if not _check(controls.weapon_reward_page == page and controls.weapon_reward_pages() == 4 and controls.selected_weapon_reward == -1, "보상 네 페이지·이동 후 선택 해제"): return false
			var rects: Array = controls.weapon_reward_rects.duplicate()
			rects.append_array([controls.weapon_reward_confirm_rect, controls.weapon_reward_skip_rect, controls.weapon_reward_previous_rect, controls.weapon_reward_next_rect])
			var safe: Rect2 = controls.layout_snapshot().safe
			for i in rects.size():
				if not _check(safe.encloses(rects[i]), "16:9/20:9 보상 전체 입력 안전 영역"): return false
				for j in range(i + 1, rects.size()):
					if not _check(not rects[i].intersects(rects[j]), "페이지/확정/유지/카드 비중첩"): return false
			for card in controls.weapon_reward_cards:
				found.append(String(card.id))
			await process_frame
			_tap(controls.weapon_reward_next_rect.get_center())
		if not _check(found.size() == 12 and found.all(func(key: String) -> bool: return found.count(key) == 1) and EXPECTED.keys().all(func(key: String) -> bool: return found.has(key)), "잠긴 태엽 제외 기존2+신규10 모든 후보 한 번씩"): return false
		if not _check(controls.weapon_reward_page == 3, "마지막 페이지 경계 보존"): return false
	# 실제 UI 입력으로 원하는 장비를 선택한다.
	while controls.weapon_reward_page > 0: _tap(controls.weapon_reward_previous_rect.get_center())
	for page in 4:
		for index in controls.weapon_reward_cards.size():
			if controls.weapon_reward_cards[index].id == id:
				_tap(controls.weapon_reward_rects[index].get_center())
				return _check(state == weapons.checkpoint_snapshot() and saved == store.load_checkpoint() and health == player.damage_receiver.health and gauge == ultimate.gauge, "비교/페이지/선택만으로 저장·장비·체력·게이지 무변경")
		_tap(controls.weapon_reward_next_rect.get_center())
	return _check(false, "장비 후보 누락")

func _test_design_damage(id: String, grade: int) -> bool:
	var expectation: Array = EXPECTED[id]
	var weapon: String = expectation[0]
	var own_percent: int = expectation[2 if grade == 1 else 4]
	var unique_percent: int = expectation[3 if grade == 1 else 5]
	var bonuses := [player.growth_common_bonus, player.growth_sword_bonus, player.growth_bow_bonus]
	player.growth_common_bonus = 0
	player.growth_sword_bonus = 0
	player.growth_bow_bonus = 0
	var target := sandbox.get_node("Targets/CrossingTargetA") as PrototypeTarget
	target.set_process(false)
	target.visible = true
	target.damage_receiver.max_health = 5000
	for kind in ["basic", "skill"]:
		var expected_damage := 100 + own_percent + (unique_percent if kind == expectation[1] else 0)
		target.reset_target()
		if weapon == "sword":
			weapons.sword_combat._action_sequence += 1
			weapons.sword_combat._damage_target(target, &"sword_basic" if kind == "basic" else &"sword_spin", 100, 0, PackedStringArray(["test"]), 0)
		else:
			target.global_position = player.global_position + Vector2(250, 0)
			weapons.bow_combat._spawn_projectile("gp226:%s:%s" % [id, kind], &"bow_test", 100, 1, Vector2.RIGHT, PackedStringArray(["bow", kind]))
			var arrow := get_nodes_in_group("bow_projectile")[-1] as BowProjectile
			arrow._physics_process(0.2)
			arrow.free()
		if not _check(target.damage_receiver.health == 5000 - expected_damage, "실제 %s %s 정수 피해 %d" % [id, kind, expected_damage]): return false
		var other := "bow" if weapon == "sword" else "sword"
		var backup_damage := roundi(100.0 + (unique_percent * 0.5 if kind == expectation[1] else 0.0))
		if not _check(player.growth_damage(100, other, kind) == backup_damage, "반대 무기에도 해당 기본/스킬 보조 효과50%·최종 반올림"): return false
	if not _check(player.growth_damage(100, weapon, "ultimate") == 100, "장비 필살기 피해 제외"): return false
	weapons.force_emit_metrics()
	var other := "bow" if weapon == "sword" else "sword"
	if weapons.active_weapon_id != other: weapons._perform_switch("장비 보조 검사")
	if not _check(controls.movement_metrics.weapon_backup_effect.contains("스킬" if expectation[1] == "skill" else "기본"), "HUD 보조 고유 효과 종류 일치"): return false
	target.visible = false
	player.growth_common_bonus = bonuses[0]
	player.growth_sword_bonus = bonuses[1]
	player.growth_bow_bonus = bonuses[2]
	return true

func _test_catalog() -> bool:
	var cards := PrototypeWeaponRewards.codex_cards({})
	var original := ["sword_0", "sword_1", "sword_2", "clockwork_sword_1", "clockwork_sword_2", "bow_0", "bow_1", "bow_2", "clockwork_bow_1", "clockwork_bow_2"]
	if not _check(cards.size() == 41 and cards.slice(0, 10).map(func(card: Dictionary) -> String: return card.id) == original, "기존10 순서/ID 유지·기존 장비 순서 유지·수호·세라8종 포함 총38"): return false
	for id in EXPECTED:
		var values: Array = EXPECTED[id]
		if not _check(PrototypeWeaponRewards.profile(values[0], 0, id).is_empty() and PrototypeWeaponRewards.profile("bow" if values[0] == "sword" else "sword", 1, id).is_empty(), "일반 등급·잘못된 무기 설계 거부"): return false
		for grade in [1, 2]:
			var item := PrototypeWeaponRewards.profile(values[0], grade, id)
			if not _check(item.kind == values[1] and is_equal_approx(float(item.damage) * 100, values[2 if grade == 1 else 4]) and is_equal_approx(float(item.unique) * 100, values[3 if grade == 1 else 5]), "10설계 두 등급 정확한 성능"): return false
		if not _check(cards.filter(func(card: Dictionary) -> bool: return card.blueprint == id and card.open).size() == 2, "신규 장비 해금 없이 도감 조회"): return false
	controls.show_weapon_rewards(1, PrototypeWeaponRewards.offers(1, {"sword": 0, "bow": 0}).slice(0, 2))
	if not _check(controls.weapon_reward_pages() == 1 and controls.weapon_reward_cards.size() == 2, "이전2후보 API는 빈 추가 페이지 없음"): return false
	controls.show_main_screen()
	return true
