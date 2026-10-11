extends "res://tests/gp153_runtime_test.gd"

const GP156_SAVE := "user://gp156_checkpoint.json"
const GP156_META := "user://gp156_meta.jsonl"
const GP156_RECORD := "user://gp156_records.jsonl"
const GP156_BOOK := "user://gp156_abilities.jsonl"
const BOOST_ID := "time_collector_boost"

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	store.save_path = GP156_SAVE
	legacy.save_path = GP156_META
	book.save_path = GP156_BOOK
	if phase in ["seed", "legacy-seed", "combat"]:
		store.clear_checkpoint()
		for path in [GP156_META, GP156_RECORD, GP156_BOOK]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.ability_discovery_store = book
	sandbox.get_node("LocalTestRecorder").record_path = GP156_RECORD
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
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
	growth.jobs_enabled = false
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	_disable_live()
	match phase:
		"seed":
			controls.begin_retry("sword", 5)
			if not _test_boost_gates(false): return
			if not await _choose_earned("time_collector"): return
			ultimate.gauge = 100
			ultimate.request_ultimate()
			ultimate._physics_process(0.5)
			if not await _choose_earned(BOOST_ID, true): return
			if not _check(ultimate._active and ultimate._remaining_s == 2.5 and ultimate._active_duration_s == 3, "발동 도중 강화는 현재 필살기의 시간/효과 유지"): return
			if not _check(ultimate.defeat_gauge_amount() == 8 and controls.movement_metrics.ultimate_defeat_gain == 8 and controls._ultimate_hud_label().contains("처치 +8"), "실제 선택·즉시 지표/HUD8"): return
			if not _test_boost_gates(true) or not await _test_boost_view(8): return
			ultimate.finish_stage_effect()
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "첫 정예 실제 저장"): return
			player.damage_receiver.health = 17
			player.potions_remaining = 1
			ultimate.gauge = 37
			weapons.sword_combat._skill_1_cooldown_s = 3.25
			weapons.bow_combat._skill_2_cooldown_s = 5.5
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "선행/강화·게이지·체력·약·양 대기 저장"): return
			if not _test_boost_save(): return
			controls.show_main_screen()
			controls.show_village()
			if not await _test_book_layout(): return
			var card: Dictionary = PrototypeAbilityCodex.cards(book.snapshot(), growth.ranks).filter(func(item: Dictionary) -> bool: return item.id == BOOST_ID)[0]
			if not _check(PrototypeAbilityCodex.definitions().size() >= 27 and card.open and card.status == "이번 도전 1등급" and card.lines[2] == "조건: 시간 수집 획득 후", "27능력 전체 도감·실제 발견·선행/등급"): return
		"resume":
			if not _check(not ultimate.time_collector_boost_unlocked and ultimate.defeat_gauge_amount() == 5 and book.snapshot().has(BOOST_ID), "영구 발견만으로 강화 지급 없음"): return
			var saved := store.load_checkpoint()
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and ultimate.time_collector_boost_unlocked and ultimate.defeat_gauge_amount() == 8 and ultimate.gauge == 37 and player.damage_receiver.health == 17 and player.potions_remaining == 1 and _weapon_matches(saved.weapons), "별도 프로세스 반복 복원·강화 비누적·잔량 보존"): return
			_tap(controls.stage_route_rects[0].get_center())
			var target := _boost_target("resume")
			_defeat(target)
			if not _check(ultimate.gauge == 45, "복원 후 실제 처치8"): return
			target.free()
			if not _resolve_growth() or not await _test_boost_view(8) or not _finish_to_boss(): return
			if not _check(runner.stage_number == 5 and store.load_checkpoint().growth.ranks[BOOST_ID] == 1, "5단계 최종 보스 저장·강화 유지"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and ultimate.defeat_gauge_amount() == 8 and sandbox._resolve_boss_choice("rescue"), "최종 보스 복원·완주"): return
			controls.use_boss_legacy = false
			controls.begin_retry("bow", 3)
			if not _check(not ultimate.time_collector_boost_unlocked and ultimate.defeat_gauge_amount() == 5 and ultimate.gauge == 0 and growth.ranks.is_empty() and book.snapshot().has(BOOST_ID), "새 도전 기본5/게이지0·발견만 보존"): return
			var target := _boost_target("new-run")
			_defeat(target)
			if not _check(ultimate.gauge == 0, "새 도전 시간 수집 미획득 처치는 추가 충전 없음"): return
			target.free()
		"legacy-seed":
			controls.begin_retry("bow", 3)
			if not await _choose_earned("time_collector"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward("") and not store.load_checkpoint().growth.ranks.has(BOOST_ID), "기존 시간 수집만 보유한 저장 준비"): return
			ultimate.gauge = 31
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "기존 저장 게이지31"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and not ultimate.time_collector_boost_unlocked and ultimate.defeat_gauge_amount() == 5 and ultimate.gauge == 31, "기존 저장 기본5·소급 강화/충전 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			var target := _boost_target("legacy")
			_defeat(target)
			if not _check(ultimate.gauge == 36, "이전 저장 실제 처치5 유지"): return
			target.free()
			if not _resolve_growth() or not _finish_to_boss() or not _check(sandbox._resolve_boss_choice("destroy"), "기존3단계 실제 완주"): return
		"combat":
			controls.begin_retry("sword", 5)
			if not await _choose_earned("time_collector") or not await _choose_earned(BOOST_ID): return
			if not _reach_relic_reward(): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[4].get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(ultimate.time_collector_boost_unlocked and controls.movement_metrics.ultimate_defeat_gain == 10, "실제 유물 선택·강화8×모래시계1.25=10"): return
			var saved := store.load_checkpoint()
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and ultimate.defeat_gauge_amount() == 10 and ultimate.gauge == saved.ultimate.gauge and player.damage_receiver.health == saved.player.health and _weapon_matches(saved.weapons), "유물/강화 함께 반복 복원·10 비누적·저장 잔량 보존"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _test_boost_combat(): return
		_:
			_check(false, "알 수 없는 단계")
			return
	paused = false
	sandbox.free()
	print("GP-156 runtime test: OK · " + phase)
	quit(0)

func _disable_live() -> void:
	for controller in [weapons, weapons.sword_combat, weapons.bow_combat, ultimate, player]:
		controller.set_process(false)
		controller.set_physics_process(false)
	runner.set_process(false)
	for enemy in runner._all_combat_enemies():
		enemy.set_process(false)
		enemy.set_physics_process(false)

func _files() -> Dictionary:
	var result := {}
	for path in [GP156_SAVE, GP156_SAVE + ".bak", GP156_META, GP156_RECORD, GP156_BOOK]:
		result[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return result

func _weapon_matches(saved: Dictionary) -> bool:
	var actual := weapons.checkpoint_snapshot()
	if actual.active != saved.active or actual.skills != saved.skills or actual.blueprints != saved.blueprints: return false
	for weapon in ["sword", "bow"]:
		if int(actual.equipment[weapon]) != int(saved.equipment[weapon]): return false
		for field in PrototypeWeaponController.CHECKPOINT_FIELDS:
			if float(actual[weapon][field]) != float(saved[weapon][field]): return false
	return true

func _finish_to_boss() -> bool:
	while not runner.awaiting_boss_choice():
		if not _finish_stage(): return false
		if runner.awaiting_boss_choice(): break
		if not _check(sandbox._claim_weapon_reward(""), "실제 다음 정예 보상"): return false
		_tap(controls.stage_route_rects[0].get_center())
	return true

func _reach_relic_reward() -> bool:
	if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "첫 정예 보상"): return false
	_tap(controls.stage_route_rects[1].get_center())
	if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "둘째 정예 보상"): return false
	return _check(runner.stage_number == 2 and controls.relic_offer_available, "실제 둘째 정예 유물 선택")

func _choose_earned(id: String, failure: bool = false) -> bool:
	var seed_value := -1
	for candidate in 512:
		growth.rng.seed = candidate
		if growth._draw_cards().any(func(card: Dictionary) -> bool: return card.id == id):
			seed_value = candidate
			break
	if not _check(seed_value >= 0, "원본 풀에서 실제 후보: " + id): return false
	growth.rng.seed = seed_value
	var initial_gauge := ultimate.gauge
	var initial_xp := growth.total_experience
	var previous_gain := ultimate.defeat_gauge_amount() if growth.ranks.has("time_collector") else 0
	for ignored in 12:
		if growth.choosing: break
		match runner.current_section:
			PrototypeStageRunner.Section.ADVANCE_ONE: player.global_position.x = 1240
			PrototypeStageRunner.Section.ADVANCE_TWO: player.global_position.x = 3840
			PrototypeStageRunner.Section.WAVE_ONE, PrototypeStageRunner.Section.WAVE_TWO:
				for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
			PrototypeStageRunner.Section.ELITE: _defeat(runner.final_enemy())
		if not growth.choosing: runner._process(0.1)
	var index := -1
	for i in growth.offered_cards.size():
		if growth.offered_cards[i].id == id: index = i
	if not _check(index >= 0 and paused, "실제 처치·레벨업·후보 카드"): return false
	# 이 두 선택은 첫 웨이브의 일반 적 경험치로 열린다. 원인 처치는 기존 획득량만 지급한다.
	if not _check(ultimate.gauge == mini(100, initial_gauge + (growth.total_experience - initial_xp) / 10 * previous_gain), "선택 원인 처치에는 선택 전 획득량만 적용"): return false
	var before := growth.checkpoint_snapshot()
	var gauge := ultimate.gauge
	var gain := ultimate.defeat_gauge_amount()
	var equipment := weapons.checkpoint_snapshot()
	var health := player.damage_receiver.health
	var potions := player.potions_remaining
	var remaining := ultimate._remaining_s
	if failure:
		for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
			controls.size = dimensions
			controls._refresh_growth_layout()
			var rect: Rect2 = controls.growth_card_rects[index]
			for line in growth.offered_cards[index].lines:
				if not _check(controls.layout_snapshot().safe.encloses(rect) and ThemeDB.fallback_font.get_string_size(String(line), HORIZONTAL_ALIGNMENT_LEFT, -1, mini(26, int(rect.size.x / 12.0)) - 3).x <= rect.size.x - 24, "두 화면비 카드·글자 너비"): return false
			await process_frame
		book.save_path = "user://gp156_missing/abilities.jsonl"
		_tap(controls.growth_card_rects[index].get_center())
		book.save_path = GP156_BOOK
		if not _check(paused and growth.choosing and growth.checkpoint_snapshot() == before and ultimate.defeat_gauge_amount() == gain and ultimate.gauge == gauge and not ultimate.time_collector_boost_unlocked and not book.snapshot().has(id), "기록 실패·등급/성향/획득량/게이지 불변"): return false
	_tap(controls.growth_card_rects[index].get_center())
	return _check(not paused and growth.ranks.has(id) and book.snapshot().has(id) and ultimate.gauge == gauge and ultimate._remaining_s == remaining and player.damage_receiver.health == health and player.potions_remaining == potions and weapons.checkpoint_snapshot() == equipment, "실제 카드 터치·재시도·즉시 충전/회복/대기 변경 없음")

func _test_boost_gates(owned: bool) -> bool:
	for ignored in 100:
		if not _check(not growth._draw_cards().any(func(card: Dictionary) -> bool: return card.id == BOOST_ID), "선행 미충족/최대1등급 후보 제외"): return false
	var before := growth.checkpoint_snapshot()
	var gauge := ultimate.gauge
	if not _reject_card(BOOST_ID): return false
	return _check(growth.checkpoint_snapshot() == before and ultimate.gauge == gauge and ultimate.time_collector_boost_unlocked == owned, "선행/중복 카드 확정 거부·효과 비누적")

func _test_boost_save() -> bool:
	var saved := store.load_checkpoint()
	for invalid in [null, true, "1", 0, 2, 0.5]:
		var bad := saved.duplicate(true)
		bad.growth.ranks[BOOST_ID] = invalid
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "등급 타입/범위 거부·정상 파일 보존"): return false
	var bad := saved.duplicate(true)
	bad.growth.ranks.erase("time_collector")
	bad.growth.ranks.vitality = int(bad.growth.ranks.get("vitality", 0)) + 1
	bad.player.max_health += 20
	if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "등급 합계/체력이 정상이어도 선행 없는 저장 거부"): return false
	store.save_path = "user://gp156_missing/checkpoint.json"
	var rejected: bool = sandbox._save_checkpoint(runner.current_metrics()) != OK
	store.save_path = GP156_SAVE
	return _check(rejected and store.load_checkpoint() == saved and sandbox._save_checkpoint(runner.current_metrics()) == OK and saved.ultimate.size() == 2, "저장 실패 재시도·기존 등급/게이지만 저장")

func _test_boost_view(gain: int) -> bool:
	var files := _files()
	var before: Dictionary = sandbox._capture_run_build()
	if not _check(controls.open_run_build() and paused, "현재 도전 조회 정지"): return false
	var abilities := PrototypeRunBuildView.cards(0, controls.run_build_state)
	var job: Dictionary = PrototypeRunBuildView.cards(2, controls.run_build_state).filter(func(card: Dictionary) -> bool: return card.id == "job")[0]
	if not _check(abilities.any(func(card: Dictionary) -> bool: return card.id == BOOST_ID) and job.lines.has("시간 수집 · 처치 게이지 +%d" % gain) and before.ultimate.defeat_gain == gain, "보유 강화·실제 처치8/10 조회"): return false
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls.run_build_tab = 2
		controls.run_build_page = 0
		var view: Dictionary = controls.run_build_snapshot()
		for rect in view.layout.cards:
			if not _check(controls.layout_snapshot().safe.encloses(rect), "두 화면비 조회 카드 안전 영역"): return false
		for line in job.lines:
			if not _check(ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= view.layout.cards[2].size.x - 24, "조회 필살기 설명 너비"): return false
		await process_frame
	if not _check(sandbox._capture_run_build() == before and _files() == files, "조회는 게이지/강화/체력/대기/파일 불변"): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(3.1)
	return _check(not paused and _files() == files, "3초 복귀·저장 보존")

func _boost_target(key: String) -> PrototypeTarget:
	var target := _absorb_target("gp156:" + key, player.global_position + Vector2(200, 0))
	target.defeated.connect(growth._on_enemy_defeated)
	return target

func _test_boost_combat() -> bool:
	for target in get_nodes_in_group("targetable"): target.visible = false
	player.global_position = Vector2(1000, 780)
	player.facing_direction = 1
	for hourglass in [false, true]:
		player.relic_state = {"id": PrototypeRelic.HOURGLASS_ID, "used": false} if hourglass else {}
		for weapon in ["sword", "bow"]:
			for skill in [false, true]:
				var target := _boost_target(weapon + str(skill) + str(hourglass))
				target.damage_receiver.health = 1
				ultimate.gauge = 0
				if weapon == "sword":
					weapons.sword_combat._action_sequence += 1
					weapons.sword_combat._damage_target(target, &"sword_spin" if skill else &"sword_basic", 10, 0, PackedStringArray(["sword", "skill" if skill else "basic"]), 0)
				else:
					weapons.bow_combat._spawn_projectile("gp156:" + target.target_key, &"bow_piercing" if skill else &"bow_basic", 10, 1, Vector2.RIGHT, PackedStringArray(["bow", "skill" if skill else "basic"]))
					var shot: BowProjectile = get_nodes_in_group("bow_projectile").back()
					shot.set_physics_process(false)
					shot._check_hits(shot.global_position, target.global_position + Vector2(0, -38))
					shot._check_hits(shot.global_position, target.global_position + Vector2(0, -38))
					shot.free()
				var expected := (10 if skill else 5) + 10 if hourglass else (8 if skill else 4) + 8
				target.defeated.emit(target)
				if not _check(target.damage_receiver.dead and ultimate.gauge == expected, "실제 검/활 기본/스킬 치명타·타격+강화 처치·중복 차단"): return false
				target.free()
				if not _resolve_growth(): return false
		ultimate.force_emit_metrics()
		if not _check(controls._ultimate_hud_label().contains("처치 +10" if hourglass else "처치 +8"), "HUD 실제8/10"): return false
		if not await _test_boost_view(10 if hourglass else 8): return false
	# 실제 모래시계 보상에 강화8을 적용한 상태에서 종류·생명·자격을 검사한다.
	for kind in ["ordinary", "elite", "boss"]:
		var target := _boost_target(kind)
		if kind != "ordinary": target.add_to_group("elite_enemy")
		if kind == "boss": target.add_to_group("boss_enemy")
		ultimate.gauge = 0
		_defeat(target)
		target.defeated.emit(target)
		if not _check(ultimate.gauge == 10, "일반/정예/보스 실제 처치10·중복 없음"): return false
		if not _resolve_growth(): return false
		target.reset_target()
		target.defeated.emit(target)
		if not _check(ultimate.gauge == 10, "살아 있는 적 위조 신호 차단"): return false
		_defeat(target)
		if not _check(ultimate.gauge == 20, "같은 개체 새 생명10"): return false
		target.free()
		if not _resolve_growth(): return false
	for lock in ["practice", "hidden", "dead", "inactive"]:
		var target := _boost_target(lock)
		if lock == "practice": target.remove_from_group("combat_enemy")
		if lock == "hidden": target.visible = false
		if lock == "dead": player.damage_receiver.dead = true
		if lock == "inactive": growth.run_active = false
		ultimate.gauge = 0
		_defeat(target)
		if not _check(ultimate.gauge == 0, "연습/숨김/사망/비활성 처치 차단"): return false
		player.damage_receiver.dead = false
		growth.run_active = true
		target.free()
	ultimate.gauge = 0
	ultimate.grant_stage_gauge(20)
	if not _check(ultimate.gauge == 20 and ultimate.combat_gauge_amount(4) == 5 and ultimate.combat_gauge_amount(8) == 10 and ultimate.combat_gauge_amount(12) == 15, "경로 보상20·기존 타격/회피 배율 독립"): return false
	ultimate.gauge = 99
	var capped := _boost_target("cap")
	_defeat(capped)
	capped.free()
	if not _check(ultimate.gauge == 100, "99+10 최대100"): return false
	if not _resolve_growth(): return false
	for profile in [{}] + PrototypeJobRewards.ULTIMATES:
		ultimate.finish_stage_effect()
		ultimate.selected_profile.clear()
		if not profile.is_empty() and not _check(ultimate.select_job_ultimate(profile.job, profile.id), "직업 필살기 원본 선택"): return false
		var target := _boost_target("ultimate")
		target.damage_receiver.health = 1
		ultimate.gauge = 100
		ultimate.request_ultimate()
		var burst_gain := 10 if int(profile.get("damage", 0)) > 0 else 0
		if not _check(ultimate._active and ultimate.gauge == burst_gain and ultimate._remaining_s == float(profile.get("duration", 3)), "공용/네 직업 실제 발동·공격형 처치10·원래 지속"): return false
		if burst_gain == 0: _defeat(target)
		if not _check(ultimate.gauge == 10 and ultimate._remaining_s == float(profile.get("duration", 3)), "발동 중 실제 처치10·지속시간 불변"): return false
		target.free()
		if not _resolve_growth(): return false
		ultimate.gauge = 100
		var count := ultimate.activation_count
		ultimate.request_ultimate()
		if not _check(ultimate.gauge == 100 and ultimate.activation_count == count, "발동 중 재입력·중복 소비 차단"): return false
	ultimate.finish_stage_effect()
	ultimate.selected_profile.clear()
	# 기존 여운과 회복 능력의 조합은 효과를 직접 준비해 처치 계산을 격리한다.
	ultimate.time_echo_unlocked = true
	ultimate.gauge = 100
	ultimate.request_ultimate()
	var target := _boost_target("echo")
	_defeat(target)
	target.free()
	if not _check(ultimate.gauge == 10 and ultimate._remaining_s == 4, "여운4초와 강화/유물 처치10 독립"): return false
	if not _resolve_growth(): return false
	ultimate.finish_stage_effect()
	player.set_lifesteal_unlocked(true)
	player.lifesteal_progress = 0
	growth.ranks.victory_recovery = 1
	player.damage_receiver.health = 1
	var healing := growth.victory_recovery_amount()
	target = _boost_target("healing")
	target.damage_receiver.health = 100
	ultimate.gauge = 0
	weapons.sword_combat._action_sequence += 1
	weapons.sword_combat._damage_target(target, &"sword_basic", 9999, 0, PackedStringArray(["sword", "basic"]), 0)
	target.free()
	return _check(ultimate.gauge == 15 and player.damage_receiver.health == 6 + healing, "강화/유물 기본5+처치10·흡수5와 원래 처치 회복 독립")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-156 failed: " + message)
		paused = false
		quit(1)
	return condition
