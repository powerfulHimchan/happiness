extends "res://tests/gp148_runtime_test.gd"

const GP153_SAVE := "user://gp153_checkpoint.json"
const GP153_META := "user://gp153_meta.jsonl"
const GP153_RECORD := "user://gp153_records.jsonl"
const GP153_BOOK := "user://gp153_abilities.jsonl"
const MAGNET_ID := "orb_magnet"
var orbs: RecoveryOrbController

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP153_SAVE
	legacy.save_path = GP153_META
	book.save_path = GP153_BOOK
	if phase in ["seed", "legacy-seed", "combat"]:
		store.clear_checkpoint()
		for path in [GP153_META, GP153_RECORD, GP153_BOOK]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.ability_discovery_store = book
	sandbox.get_node("LocalTestRecorder").record_path = GP153_RECORD
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
	orbs = sandbox.get_node("RecoveryOrbController")
	orbs.set_physics_process(false)
	growth.jobs_enabled = false
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	_disable_live()
	match phase:
		"seed":
			controls.begin_retry("sword", 5)
			if not _check(player.recovery_orb_pickup_radius() == 76 and orbs.pickup_hint() == "회복 +10%", "기존 획득 거리·표기"): return
			if not await _choose_earned(MAGNET_ID, true): return
			if not _check(player.orb_magnet_unlocked and player.recovery_orb_pickup_radius() == 152 and controls.movement_metrics.recovery_orb_pickup_radius_m == 1.52, "실제 선택은 획득 거리만2배·현재 지표"): return
			if not _test_magnet_gates() or not await _test_magnet_view(): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "첫 정예 실제 보상"): return
			player.damage_receiver.health = 17
			player.potions_remaining = 1
			ultimate.gauge = 31
			weapons.sword_combat._skill_1_cooldown_s = 3.25
			weapons.bow_combat._skill_2_cooldown_s = 5.5
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "능력·체력·회복약·게이지·양 대기 저장"): return
			if not _test_magnet_save(): return
			controls.show_main_screen()
			controls.show_village()
			if not await _test_book_layout(): return
			var card: Dictionary = PrototypeAbilityCodex.cards(book.snapshot(), growth.ranks).filter(func(item: Dictionary) -> bool: return item.id == MAGNET_ID)[0]
			if not _check(PrototypeAbilityCodex.definitions().size() == 25 and card.open and card.status == "이번 도전 1등급" and card.lines[2] == "조건: 공용·무작위 후보", "25능력 도감·원본 효과/조건/현재 등급"): return
		"resume":
			if not _check(not player.orb_magnet_unlocked and player.recovery_orb_pickup_radius() == 76 and book.snapshot().has(MAGNET_ID), "영구 발견만으로 능력 지급 없음"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and player.orb_magnet_unlocked and player.recovery_orb_pickup_radius() == 152 and player.damage_receiver.health == 17 and player.potions_remaining == 1 and ultimate.gauge == 31 and weapons.sword_combat._skill_1_cooldown_s == 3.25 and weapons.bow_combat._skill_2_cooldown_s == 5.5 and orbs.orbs.is_empty(), "별도 프로세스·반복 복원·거리 배율 중복/회복/구슬 재생성 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _pickup_at(Vector2(100, 0), true): return
			if not await _test_magnet_view(): return
			while not runner.awaiting_boss_choice():
				if not _finish_stage(): return
				if runner.awaiting_boss_choice(): break
				if not _check(sandbox._claim_weapon_reward(""), "정예 보상에서 자석 유지"): return
				_tap(controls.stage_route_rects[0].get_center())
			if not _check(runner.stage_number == 5 and store.load_checkpoint().growth.ranks[MAGNET_ID] == 1, "5단계 최종 저장·한 번만 선택"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and player.recovery_orb_pickup_radius() == 152 and sandbox._resolve_boss_choice("rescue"), "최종 보스 선택 복원·완주"): return
			controls.begin_retry("bow", 3)
			if not _check(not player.orb_magnet_unlocked and player.recovery_orb_pickup_radius() == 76 and growth.ranks.is_empty() and book.snapshot().has(MAGNET_ID), "새 도전 기본 거리·영구 발견 보존"): return
			if not _pickup_at(Vector2(100, 0), false) or not _pickup_at(Vector2(76, 0), true): return
		"legacy-seed":
			controls.begin_retry("bow", 3)
			if not _pickup_at(Vector2(100, 0), false) or not _pickup_at(Vector2(76, 0), true): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "기존 능력 없는 저장 준비"): return
			if not _check(not store.load_checkpoint().growth.ranks.has(MAGNET_ID), "이전 저장에 자석 없음"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and player.recovery_orb_pickup_radius() == 76 and not player.orb_magnet_unlocked, "기존 저장은 기본 거리·소급 지급 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _pickup_at(Vector2(100, 0), false): return
		"combat":
			controls.begin_retry("sword", 3)
			if not await _choose_earned(MAGNET_ID): return
			if not await _test_magnet_combat(): return
		_:
			_check(false, "알 수 없는 단계")
			return
	paused = false
	sandbox.free()
	print("GP-153 runtime test: OK · " + phase)
	quit(0)

func _pickup_at(offset: Vector2, collect: bool) -> bool:
	orbs.orbs = [player.global_position + offset]
	player._input_lock_remaining_s = 0.0
	player.damage_receiver.health = 1
	var health := player.damage_receiver.health
	var expected := ceili(player.damage_receiver.max_health * RecoveryOrbController.HEAL_RATIO)
	var potions := player.potions_remaining
	var barrier := player.damage_receiver.barrier_health
	var collected := orbs.collected
	orbs._physics_process(0.02)
	if not _check(orbs.collected == collected + (1 if collect else 0) and orbs.orbs.size() == (0 if collect else 1) and player.damage_receiver.health == health + (expected if collect else 0) and player.potions_remaining == potions and player.damage_receiver.barrier_health == barrier, "거리 %.2fpx · 실제10%% 올림 회복·회복약/방벽 보존" % offset.length()): return false
	orbs._physics_process(0.02)
	if not _check(player.damage_receiver.health == health + (expected if collect else 0), "획득한 구슬은 재회복 없음"): return false
	return true

func _test_magnet_gates() -> bool:
	for ignored in 100:
		if not _check(not growth._draw_cards().any(func(card: Dictionary) -> bool: return card.id == MAGNET_ID), "최대1등급 후보 제외"): return false
	var before := growth.checkpoint_snapshot()
	if not _reject_card(MAGNET_ID): return false
	return _check(growth.checkpoint_snapshot() == before and player.recovery_orb_pickup_radius() == 152, "중복 확정 거부·범위/성향 불변")

func _test_magnet_save() -> bool:
	var saved := store.load_checkpoint()
	for invalid in [null, true, "1", 0, 2, 0.5]:
		var bad := saved.duplicate(true)
		bad.growth.ranks[MAGNET_ID] = invalid
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "등급 변조 거부·정상 저장 보호"): return false
	return _check(not saved.player.has("orb_magnet_unlocked") and not saved.player.has("recovery_orb_pickup_radius_m"), "기존 등급으로만 저장·효과 중복 필드 없음")

func _test_magnet_view() -> bool:
	var files := _files()
	var before: Dictionary = sandbox._capture_run_build()
	if not _check(controls.open_run_build() and paused, "현재 도전 실제 조회"): return false
	var abilities := PrototypeRunBuildView.cards(0, controls.run_build_state)
	if not _check(abilities.any(func(card: Dictionary) -> bool: return card.id == MAGNET_ID), "보유 능력에 자석 표시"): return false
	var health_card: Dictionary = PrototypeRunBuildView.cards(2, controls.run_build_state).filter(func(card: Dictionary) -> bool: return card.id == "health")[0]
	if not _check(health_card.lines.has("회복 구슬 획득 거리 1.52m") and orbs.pickup_hint() == "회복 +10% · 자석 1.52m", "현재 도전·구슬 표기 원본 효과"): return false
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls.run_build_tab = 2
		controls.run_build_page = 0
		var view: Dictionary = controls.run_build_snapshot()
		for rect in view.layout.cards:
			if not _check(controls.layout_snapshot().safe.encloses(rect), "현재 도전 두 화면비 안전 영역"): return false
		var rect: Rect2 = view.layout.cards[1]
		for line in health_card.lines:
			if not _check(ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= rect.size.x - 24, "생존 상태 설명 최소 글자 크기 수용"): return false
		controls.queue_redraw()
		await process_frame
	if not _check(sandbox._capture_run_build() == before and _files() == files, "조회는 효과·체력·대기·저장 무변경"): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(3.1)
	_disable_live()
	return _check(not paused and _files() == files, "3초 복귀·저장 보존")

func _files() -> Dictionary:
	var result := {}
	for path in [GP153_SAVE, GP153_SAVE + ".bak", GP153_META, GP153_RECORD, GP153_BOOK]:
		result[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return result

func _choose_earned(id: String, failure: bool = false) -> bool:
	var seed_value := -1
	for candidate in 512:
		growth.rng.seed = candidate
		for card in growth._draw_cards():
			if card.id == id: seed_value = candidate
		if seed_value >= 0: break
	if not _check(seed_value >= 0, "원본 후보 풀에서 다음 능력 발견: " + id): return false
	growth.rng.seed = seed_value
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
	if not _check(index >= 0 and growth.choosing and paused, "실제 처치 레벨업·자연 후보 UI: " + id): return false
	var original_radius := player.recovery_orb_pickup_radius()
	var before := growth.checkpoint_snapshot()
	var equipment := weapons.checkpoint_snapshot()
	var health := player.damage_receiver.health
	var potions := player.potions_remaining
	var bonus := _bonus()
	var barrier := player.damage_receiver.barrier_health
	var gauge := ultimate.gauge
	if failure:
		for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
			controls.size = dimensions
			controls._refresh_growth_layout()
			var rect: Rect2 = controls.growth_card_rects[index]
			if not _check(controls.layout_snapshot().safe.encloses(rect), "직업 강화 카드 두 화면비 안전 영역"): return false
			for line in growth.offered_cards[index].lines:
				if not _check(ThemeDB.fallback_font.get_string_size(String(line), HORIZONTAL_ALIGNMENT_LEFT, -1, mini(26, int(rect.size.x / 12.0)) - 3).x <= rect.size.x - 24, "강화 설명 글자 너비"): return false
			controls.queue_redraw()
			await process_frame
		book.save_path = "user://gp153_missing/abilities.jsonl"
		_tap(controls.growth_card_rects[index].get_center())
		if not _check(paused and growth.choosing and growth.checkpoint_snapshot() == before and _bonus() == bonus and player.recovery_orb_pickup_radius() == original_radius and not book.snapshot().has(id), "영구 발견 저장 실패·등급/성향/효과 미적용"): return false
		book.save_path = GP153_BOOK
	_tap(controls.growth_card_rects[index].get_center())
	if failure and not _check(is_equal_approx(_bonus(), bonus) and player.damage_receiver.barrier_health == barrier and player.damage_receiver.health == health and player.potions_remaining == potions and weapons.checkpoint_snapshot() == equipment and ultimate.gauge == gauge, "같은 카드 재시도·방벽 선택 자체는 즉시 회복 없음·회복/대기/게이지 보존"): return false
	if growth.awaiting_job_confirmation:
		_tap(controls.job_ultimate_rects[0].get_center())
		_tap(controls.job_confirm_rect.get_center())
	return _check(not paused and not growth.choosing and growth.ranks.has(id) and book.snapshot().has(id), "실제 카드 터치·영구 발견·재개")


func _test_magnet_combat() -> bool:
	var timers := weapons.checkpoint_snapshot()
	var gauge := ultimate.gauge
	if not _pickup_at(Vector2(152.1, 0), false) or not _pickup_at(Vector2(0, 152.1), false): return false
	if not _pickup_at(Vector2(152, 0), true) or not _pickup_at(Vector2(0, 152), true) or not _pickup_at(Vector2(90, 120), true): return false
	var original_max := player.damage_receiver.max_health
	for maximum in [100, 101, 105, 120]:
		player.damage_receiver.max_health = maximum
		if not _pickup_at(Vector2(100, 0), true): return false
	player.damage_receiver.max_health = original_max
	orbs.orbs = [player.global_position + Vector2(100, 0)]
	player.damage_receiver.health = player.damage_receiver.max_health
	orbs._physics_process(0.02)
	if not _check(orbs.orbs.size() == 1 and player.damage_receiver.health == player.damage_receiver.max_health, "만피는 자석으로도 구슬을 소비하지 않음"): return false
	player.damage_receiver.health -= 1
	orbs._physics_process(0.02)
	if not _check(orbs.orbs.is_empty() and player.damage_receiver.health == player.damage_receiver.max_health, "1부족은 최대 체력 상한까지"): return false
	for reason in ["hit", "fall", "dead", "paused", "environment", "stage", "ended", "main"]:
		orbs.orbs = [player.global_position + Vector2(100, 0)]
		player.damage_receiver.health = 1
		match reason:
			"hit": player._input_lock_remaining_s = 1.0
			"fall": player._fall_recovery_active = true
			"dead": player.damage_receiver.dead = true
			"paused": paused = true
			"environment": sandbox._combat_environment_suspended = true
			"stage": runner.stage_complete = true
			"ended": growth.run_active = false
			"main": controls.screen_mode = 2
		orbs._physics_process(0.02)
		if not _check(orbs.orbs.size() == 1 and player.damage_receiver.health == 1, reason + " 자석 획득 차단"): return false
		player._input_lock_remaining_s = 0.0
		player._fall_recovery_active = false
		player.damage_receiver.dead = false
		paused = false
		sandbox._combat_environment_suspended = false
		runner.stage_complete = false
		growth.run_active = true
		controls.screen_mode = 0
	if not _check(weapons.checkpoint_snapshot() == timers and ultimate.gauge == gauge, "자석 획득은 양 무기 대기/게이지 변경 없음"): return false
	orbs.clear_orbs()
	orbs.drop_chance = 1.0
	orbs.reset_stage()
	for ignored in 4:
		if runner.current_section == PrototypeStageRunner.Section.WAVE_TWO: break
		if not _step_section(): return false
	if not _check(runner.current_section == PrototypeStageRunner.Section.WAVE_TWO, "실제 다음 웨이브 진입"): return false
	_defeat(runner.leaf_slime)
	if not _resolve_growth(): return false
	if not _check(orbs.drops == 1 and orbs.orbs.size() == 1, "일반 적 실제 처치·안전 지면 드롭"): return false
	runner.leaf_slime.defeated.emit(runner.leaf_slime)
	if not _check(orbs.drops == 1, "중복 생명 드롭 추첨 없음"): return false
	player.global_position = orbs.orbs[0] - Vector2(100, 0)
	player.damage_receiver.health = 1
	player._input_lock_remaining_s = 0.0
	orbs._physics_process(0.02)
	if not _check(orbs.orbs.is_empty() and orbs.collected == 1, "실제 드롭 구슬을 기존 범위 밖100px에서 획득"): return false
	for enemy in [runner.seed_sack, runner.wind_spirit]: _defeat(enemy)
	if not _resolve_growth(): return false
	if not _check(orbs.drops == 2 and orbs.orbs.size() == 1 and orbs.drop_chance == 1.0, "자석은 스테이지 두 개 상한 유지"): return false
	orbs.queue_redraw()
	await process_frame
	if not _check(orbs.pickup_hint().contains("1.52m"), "실제 구슬 원호·표기 렌더"): return false
	orbs.drop_chance = 0.0
	if not _finish_stage() or not _check(orbs.orbs.size() == 1, "완료 화면의 남은 구슬 보존"): return false
	player.global_position = orbs.orbs[0]
	var health := player.damage_receiver.health
	orbs._physics_process(0.02)
	if not _check(orbs.orbs.size() == 1 and player.damage_receiver.health == health, "완료 화면은 자석 획득 차단"): return false
	if not _check(sandbox._claim_weapon_reward(""), "새 단계 보상"): return false
	_tap(controls.stage_route_rects[0].get_center())
	if not _check(orbs.drops == 0 and orbs.collected == 0 and player.recovery_orb_pickup_radius() == 152, "새 단계 드롭 상한 초기화·자석 유지"): return false
	orbs.orbs = [player.global_position + Vector2(100, 0)]
	player.damage_receiver.tick(2.0)
	if not _check(player.receive_damage(_event("gp153-death", 9999)) == DamageReceiver.Result.APPLIED and player.damage_receiver.dead and orbs.orbs.is_empty(), "실제 사망은 구슬 정리·자석 부활 없음"): return false
	return true
