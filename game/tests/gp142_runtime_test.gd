extends "res://tests/gp141_runtime_test.gd"

const GP142_SAVE := "user://gp142_checkpoint.json"
const GP142_META := "user://gp142_meta.jsonl"
const GP142_RECORD := "user://gp142_records.jsonl"
const GP142_BOOK := "user://gp142_abilities.jsonl"
const RECOVERY_ID := "victory_recovery"

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	store.save_path = GP142_SAVE
	legacy.save_path = GP142_META
	book.save_path = GP142_BOOK
	if phase in ["seed", "legacy-seed", "combat"]:
		store.clear_checkpoint()
		for path in [GP142_META, GP142_RECORD, GP142_BOOK]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.ability_discovery_store = book
	sandbox.get_node("LocalTestRecorder").record_path = GP142_RECORD
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
	_disable_live()
	match phase:
		"seed":
			controls.begin_retry("sword", 5)
			if not await _choose_recovery(true): return
			if not _test_recovery_gates(): return
			if not await _choose_earned("lifesteal") or not await _choose_earned("time_collector"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "실제 첫 정예 보상 저장"): return
			player.damage_receiver.health = 17
			player.lifesteal_progress = 7
			ultimate.gauge = 31
			weapons.sword_combat._skill_1_cooldown_s = 6.0
			weapons.bow_combat._skill_2_cooldown_s = 8.0
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "처치 회복·체력17·흡수 소수·게이지·대기 저장"): return
			if not _test_recovery_save(): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _test_recovery_view(): return
		"resume":
			if not _check(growth.ranks.is_empty() and book.snapshot().has(RECOVERY_ID) and growth.victory_recovery_amount() == 0, "영구 발견만으로 도전 회복 지급 없음"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and growth.ranks[RECOVERY_ID] == 1 and player.damage_receiver.health == 17 and player.lifesteal_progress == 7 and ultimate.gauge == 31 and weapons.sword_combat._skill_1_cooldown_s == 6.0 and weapons.bow_combat._skill_2_cooldown_s == 8.0, "별도 프로세스 반복 이어하기·무료 회복/충전 없음"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not await _test_recovery_view(): return
			for target in get_nodes_in_group("targetable"): target.visible = false
			player.global_position = Vector2(1000, 780)
			player.facing_direction = 1
			var target := _collector_target("gp142:combined")
			var before := player.damage_receiver.health
			var gauge_before := ultimate.gauge
			var expected := growth.victory_recovery_amount() + (7 + target.damage_receiver.health) / PrototypePlayer.LIFESTEAL_DAMAGE_PER_HEALTH
			_sword_hit(target, 9999)
			if not _check(player.damage_receiver.health == before + expected and player.lifesteal_progress == 7 and ultimate.gauge == mini(100, gauge_before + 9), "복원 후 실제 검 처치·흡수와 회복 합산·기존 타격4+시간수집5"): return
			if not _resolve_growth(): return
			while not runner.awaiting_boss_choice():
				if not _finish_stage(): return
				if runner.awaiting_boss_choice(): break
				if not _check(sandbox._claim_weapon_reward(""), "회복 능력 보존한 정예 보상"): return
				_tap(controls.stage_route_rects[0].get_center())
			if not _check(store.load_checkpoint().growth.ranks[RECOVERY_ID] == 1 and runner.stage_number == 5, "긴 도전 최종 보스 선택 대기 저장"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and sandbox._resolve_boss_choice("rescue") and store.load_checkpoint().is_empty(), "별도 보스 선택 복원·완주"): return
			controls.begin_retry("bow", 3)
			if not _check(not growth.ranks.has(RECOVERY_ID) and growth.victory_recovery_amount() == 0 and book.snapshot().has(RECOVERY_ID), "새 도전 능력 초기화·발견 유지"): return
			player.damage_receiver.health = 25
			var target := _collector_target("gp142:fresh")
			_defeat(target)
			if not _check(player.damage_receiver.health == 25, "새 도전 실제 처치 회복 없음"): return
		"legacy-seed":
			controls.begin_retry("bow", 3)
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 능력 구성 저장 준비"): return
			var old := store.load_checkpoint()
			if old.growth.ranks.has(RECOVERY_ID):
				old.growth.ranks.erase(RECOVERY_ID)
				old.growth.ranks.vitality = int(old.growth.ranks.get("vitality", 0)) + 1
				old.player.max_health += 20
			old.player.health = 17
			if not _check(store.save_checkpoint(old) == OK and not store.load_checkpoint().growth.ranks.has(RECOVERY_ID), "처치 회복 이전 저장·체력17"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and not growth.ranks.has(RECOVERY_ID) and player.damage_receiver.health == 17, "이전 저장 복원·새 능력 자동 지급 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			var before: int = player.damage_receiver.health
			var target := _collector_target("gp142:legacy")
			_defeat(target)
			if not _check(player.damage_receiver.health == before, "기존 능력 미선택 실제 처치 회복 없음"): return
			if not _resolve_growth() or not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 저장 두 번째 정예"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("destroy"), "이전 저장 세 단계 완주"): return
		"combat":
			controls.begin_retry()
			if not await _choose_recovery(false): return
			if not _test_recovery_gates() or not _test_recovery_combat(): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-142 runtime test: OK (" + phase + ")")
	quit(0)

func _choose_recovery(failure: bool) -> bool:
	var chosen_seed := -1
	for candidate in 512:
		growth.rng.seed = candidate
		if growth._draw_cards().any(func(card: Dictionary) -> bool: return card.id == RECOVERY_ID):
			chosen_seed = candidate
			break
	if not _check(chosen_seed >= 0, "실제 공용 후보 풀에 처치 회복"): return false
	growth.rng.seed = chosen_seed
	player.damage_receiver.health = 25
	player.global_position.x = 1240
	runner._process(0.1)
	for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
	var index := -1
	for i in growth.offered_cards.size():
		if growth.offered_cards[i].id == RECOVERY_ID: index = i
	if not _check(index >= 0 and paused and player.damage_receiver.health == 25, "실제 처치 레벨업·선택 전 회복 없음"): return false
	var before := growth.checkpoint_snapshot()
	if failure:
		for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
			controls.size = dimensions
			controls._refresh_growth_layout()
			var rect: Rect2 = controls.growth_card_rects[index]
			if not _check(controls.layout_snapshot().safe.encloses(rect), "처치 회복 카드 두 화면비 안전 영역"): return false
			for line in growth.offered_cards[index].lines:
				if not _check(ThemeDB.fallback_font.get_string_size(String(line), HORIZONTAL_ALIGNMENT_LEFT, -1, mini(26, int(rect.size.x / 12.0)) - 3).x <= rect.size.x - 24, "처치 회복 설명 두 화면비 글자 너비"): return false
			controls.queue_redraw()
			await process_frame
		book.save_path = "user://gp142_missing/abilities.jsonl"
		_tap(controls.growth_card_rects[index].get_center())
		if not _check(paused and growth.choosing and growth.checkpoint_snapshot() == before and player.damage_receiver.health == 25, "발견 기록 실패·효과/성향/등급/즉시 회복 없음"): return false
		book.save_path = GP142_BOOK
	_tap(controls.growth_card_rects[index].get_center())
	return _check(not paused and growth.ranks[RECOVERY_ID] == 1 and book.snapshot().has(RECOVERY_ID) and player.damage_receiver.health == 25, "실제 카드 터치·기록 재시도·선택 계기 처치의 소급 회복 없음")

func _test_recovery_gates() -> bool:
	for ignored in 128:
		if not _check(not growth._draw_cards().any(func(card: Dictionary) -> bool: return card.id == RECOVERY_ID), "최대1등급 이후 후보 제외"): return false
	var before := growth.checkpoint_snapshot()
	var health := player.damage_receiver.health
	growth.choosing = true
	growth.offered_cards = [PrototypeAbilityCodex.profile(RECOVERY_ID)]
	var rejected := not growth.choose_card(0)
	growth.choosing = false
	growth.offered_cards.clear()
	return _check(rejected and growth.checkpoint_snapshot() == before and player.damage_receiver.health == health, "오래된 중복 카드 확정 거부·무변경")

func _test_recovery_save() -> bool:
	var saved := store.load_checkpoint()
	for invalid in [null, true, "1", 0, 2, 0.5]:
		var bad := saved.duplicate(true)
		bad.growth.ranks[RECOVERY_ID] = invalid
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "변조 등급 타입/0/2/소수 거부·정상 저장 보호"): return false
	return true

func _files() -> Dictionary:
	var result := {}
	for path in [GP142_SAVE, GP142_SAVE + ".bak", GP142_META, GP142_RECORD, GP142_BOOK]:
		result[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return result

func _test_recovery_view() -> bool:
	var files := _files()
	var health := player.damage_receiver.health
	if not _check(controls.open_run_build(), "현재 도전 상태에서 조회"): return false
	var source := PrototypeAbilityCodex.profile(RECOVERY_ID)
	var cards := PrototypeRunBuildView.cards(0, controls.run_build_state)
	var card: Dictionary = cards.filter(func(item: Dictionary) -> bool: return item.id == RECOVERY_ID)[0]
	if not _check(card.status == "이번 도전 1등급" and card.lines[0] == source.lines[0] and PrototypeAbilityCodex.definitions().size() == PrototypeGrowthController.CARDS.size() + PrototypeJobRewards.CARDS.size(), "원본 전체 능력 도감·현재 보유 등급"): return false
	cards = PrototypeRunBuildView.cards(2, controls.run_build_state)
	if not _check(cards[1].lines.has("처치 회복 · 적마다 체력 +%d" % growth.victory_recovery_amount()), "최대 체력 변화가 반영된 실제 회복량 표시"): return false
	if not await _test_layout(): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(3.1)
	return _check(not paused and _files() == files and player.damage_receiver.health == health, "두 화면비 조회·복귀로 저장/회복 변경 없음")

func _test_recovery_combat() -> bool:
	for target in get_nodes_in_group("targetable"): target.visible = false
	player.global_position = Vector2(1000, 780)
	player.facing_direction = 1
	var target := _collector_target("gp142:sword")
	_sword_hit(target, 10)
	if not _check(player.damage_receiver.health == 25, "비치명 실제 검 타격 회복 없음"): return false
	var amount := growth.victory_recovery_amount()
	_sword_hit(target, 9999)
	if not _check(player.damage_receiver.health == 25 + amount, "실제 검 처치로 2% 회복"): return false
	target.defeated.emit(target)
	if not _check(player.damage_receiver.health == 25 + amount, "중복 처치 신호 추가 회복 없음"): return false
	if not _resolve_growth(): return false
	target.reset_target()
	var before := player.damage_receiver.health
	target.defeated.emit(target)
	if not _check(player.damage_receiver.health == before, "살아 있는 적 위조 처치 거부"): return false
	_defeat(target)
	if not _check(player.damage_receiver.health == before + growth.victory_recovery_amount(), "같은 적 새 생명 실제 처치는 한 번 회복"): return false
	if not _resolve_growth(): return false
	target.visible = false
	target = _collector_target("gp142:bow")
	before = player.damage_receiver.health
	_arrow_hit(target, 9999, "gp142:bow")
	if not _check(player.damage_receiver.health == before + growth.victory_recovery_amount(), "실제 활 투사체 처치 회복"): return false
	if not _resolve_growth(): return false
	target.visible = false
	for kind in ["ordinary", "elite", "boss"]:
		target = _collector_target("gp142:" + kind)
		if kind != "ordinary": target.add_to_group("elite_enemy")
		if kind == "boss": target.add_to_group("boss_enemy")
		player.damage_receiver.health = 25
		amount = growth.victory_recovery_amount()
		_defeat(target)
		if not _check(player.damage_receiver.health == 25 + amount, "일반/정예/보스 동일 비율 회복"): return false
		if not _resolve_growth(): return false
		target.visible = false
	var selected_profile: Dictionary = ultimate.selected_profile.duplicate(true)
	ultimate.selected_profile = PrototypeJobRewards.ultimates_for("vanguard")[0].duplicate(true)
	target = _collector_target("gp142:ultimate")
	target.damage_receiver.health = 1
	player.damage_receiver.health = 25
	amount = growth.victory_recovery_amount()
	ultimate.gauge = 100
	ultimate.request_ultimate()
	if not _check(target.damage_receiver.dead and player.damage_receiver.health == 25 + amount and ultimate._active, "실제 공격형 필살기 처치도 한 번 회복"): return false
	ultimate.finish_stage_effect()
	ultimate.selected_profile = selected_profile
	if not _resolve_growth(): return false
	target.visible = false
	var maximum := player.damage_receiver.max_health
	player.damage_receiver.max_health = 105
	player.damage_receiver.health = 104
	target = _collector_target("gp142:cap")
	if not _check(growth.victory_recovery_amount() == 3, "현재 최대105의2%는3으로 올림"): return false
	_defeat(target)
	if not _check(player.damage_receiver.health == 105, "최대 체력 상한·초과 회복 없음"): return false
	player.damage_receiver.max_health = maximum
	if not _resolve_growth(): return false
	target.visible = false
	for mode in ["training", "hidden", "dead", "paused", "build", "editor", "intermission", "inactive"]:
		growth.experience = 0
		target = _collector_target("gp142:guard:" + mode)
		player.damage_receiver.health = 25
		match mode:
			"training": target.remove_from_group("combat_enemy")
			"hidden": target.visible = false
			"dead": player.damage_receiver.dead = true; player.damage_receiver.health = 0
			"paused": paused = true
			"build": controls.open_run_build()
			"editor": controls.open_layout_editor()
			"intermission": runner.stage_complete = true
			"inactive": growth.stop_run()
		before = player.damage_receiver.health
		_defeat(target)
		if not _check(player.damage_receiver.health == before, "회복 자격 차단: " + mode): return false
		match mode:
			"dead": player.damage_receiver.dead = false
			"paused": paused = false
			"build": controls.close_run_build(); controls.advance_mode_timer_for_test(3.1)
			"editor": controls.cancel_layout_editor(); controls.advance_mode_timer_for_test(3.1)
			"intermission": runner.stage_complete = false
		if mode in ["paused", "build", "editor", "intermission"]:
			var resumed_health := player.damage_receiver.health
			target.defeated.emit(target)
			if not _check(player.damage_receiver.health == resumed_health, "잠금 해제 후 신호 재전송·미지급 회복 누적 없음: " + mode): return false
		target.visible = false
	return true

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-142 failed: " + message)
		paused = false
		quit(1)
	return condition
