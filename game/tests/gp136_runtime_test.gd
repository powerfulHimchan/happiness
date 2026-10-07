extends "res://tests/gp128_runtime_test.gd"

const GP136_SAVE := "user://gp136_checkpoint.json"
const GP136_META := "user://gp136_meta.jsonl"
const GP136_RECORD := "user://gp136_records.jsonl"
const GP136_BOOK := "user://gp136_abilities.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP136_SAVE
	legacy.save_path = GP136_META
	book.save_path = GP136_BOOK
	if phase in ["seed", "combat"]:
		store.clear_checkpoint()
		for path in [GP136_META, GP136_RECORD, GP136_BOOK]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.ability_discovery_store = book
	sandbox.get_node("LocalTestRecorder").record_path = GP136_RECORD
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	growth.jobs_enabled = false
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	recorder = sandbox.get_node("LocalTestRecorder")
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	for controller in [weapons.sword_combat, weapons.bow_combat]:
		controller.set_process(false)
		controller.set_physics_process(false)
	player.set_physics_process(false)
	runner.set_process(false)
	match phase:
		"seed":
			controls.begin_retry()
			if not _test_prerequisite(): return
			if not await _choose_barrier_card("magic_barrier"): return
			if not _check(player.barrier_capacity() == 20 and player.damage_receiver.barrier_health == 20, "선행 마력 방벽 실제20"): return
			_barrier_hit("fortified-seed7", 7)
			if not await _choose_barrier_card("fortified_barrier"): return
			if not _check(player.fortified_barrier_unlocked and player.barrier_capacity() == 30 and player.damage_receiver.barrier_health == 23 and growth.ranks.fortified_barrier == 1 and book.snapshot().has("fortified_barrier"), "실제 강화 선택·최대30·13잔량+10·1등급·영구 발견"): return
			for ignored in 100:
				for card in growth._draw_cards():
					if not _check(card.id != "fortified_barrier", "선택한 강화 도전당1회 후보 제외"): return
			if not _reject_card("fortified_barrier") or not _check(player.damage_receiver.barrier_health == 23, "중복 선택·추가 보충 차단"): return
			if not _finish_stage() or not _check(player.damage_receiver.barrier_health == 23, "정예 휴식은 강화 방벽 충전 없음"): return
			var saved := store.load_checkpoint()
			store.save_path = "user://gp136_missing/checkpoint.json"
			if not _check(not sandbox._claim_weapon_reward("") and not runner.reward_claimed and player.damage_receiver.barrier_health == 23, "중간 저장 실패는 강화 잔량/보상 보존"): return
			store.save_path = GP136_SAVE
			if not _check(store.load_checkpoint() == saved and sandbox._claim_weapon_reward(""), "정상 저장 보호·보상 재시도"): return
			saved = store.load_checkpoint()
			if not _check(saved.player.barrier_health == 23 and saved.growth.ranks.fortified_barrier == 1, "강화 등급과23잔량 저장·추가 저장 필드 없음"): return
			for invalid in [null, true, "23", [], {}, -1, 31, 0.5]:
				var bad := saved.duplicate(true)
				bad.player.barrier_health = invalid
				if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "강화 잔량 타입/음수/30초과/소수 변조 거부"): return
			var bad := saved.duplicate(true)
			bad.growth.ranks.fortified_barrier = 2
			if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA, "강화 최대1등급 변조 거부"): return
			bad = saved.duplicate(true)
			bad.growth.ranks.erase("magic_barrier")
			bad.growth.level -= 1
			if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "선행 없는 강화 저장 거부·정상 파일 보호"): return
			controls.show_main_screen()
			controls.show_village()
			if not await _test_book_layout(): return
			controls.ability_codex_page = 4
			var cards: Array = controls.village_snapshot().cards
			if not _check(cards[0].id == "fortified_barrier" and cards[0].open and cards[0].status == "이번 도전 1등급" and cards[0].lines[2] == "조건: 마력 방벽 획득 후", "17능력·강화 원본 효과/선행/발견/현재등급 도감"): return
		"resume":
			if not _check(not player.fortified_barrier_unlocked and not player.barrier_unlocked and book.snapshot().has("fortified_barrier"), "영구 발견만으로 시작 강화 지급 없음"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and player.fortified_barrier_unlocked and player.barrier_capacity() == 30 and player.damage_receiver.barrier_health == 23, "별도 프로세스 반복 이어하기·23잔량·중복 보충 없음"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _check(player.damage_receiver.barrier_health == 30 and controls.movement_metrics.barrier_capacity == 30, "실제 다음 스테이지30 충전·HUD 최대30"): return
			_barrier_hit("fortified-resume31", 31)
			if not _check(player.damage_receiver.barrier_health == 0 and player.damage_receiver.last_absorbed_damage == 30 and player.damage_receiver.last_health_damage == 1, "강화30 흡수·초과1 체력 피해"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward("") and store.load_checkpoint().player.barrier_health == 0, "강화 방벽 소진0 저장·휴식 충전 없음"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and player.fortified_barrier_unlocked and player.damage_receiver.barrier_health == 0, "소진 강화 재시작·무료 보충 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _check(player.damage_receiver.barrier_health == 30, "보스 스테이지도30 충전"): return
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("rescue"), "실제 강화 방벽 보스 완주"): return
			controls.begin_retry()
			if not _check(not player.barrier_unlocked and not player.fortified_barrier_unlocked and player.damage_receiver.barrier_health == 0 and player.barrier_capacity() == 20 and book.snapshot().has("fortified_barrier"), "새 도전 능력/잔량 초기화·발견 유지"): return
			if not await _choose_barrier_card("magic_barrier"): return
			_barrier_hit("fortified-old7", 7)
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward("") and not store.load_checkpoint().growth.ranks.has("fortified_barrier"), "기존 마력 방벽만 있는13잔량 저장 준비"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and player.barrier_unlocked and not player.fortified_barrier_unlocked and player.barrier_capacity() == 20 and player.damage_receiver.barrier_health == 13, "이전 기본 방벽13/20 호환·강화 자동 지급 없음"): return
			var saved := store.load_checkpoint()
			var bad := saved.duplicate(true)
			bad.player.barrier_health = 21
			if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "강화 없는 저장은 여전히20 상한"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _check(player.damage_receiver.barrier_health == 20, "기존 방벽 다음 스테이지20 충전"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 저장 두 번째 정예"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("destroy"), "이전 저장 실제 보스 완주"): return
		"combat":
			controls.begin_retry()
			if not await _choose_barrier_card("magic_barrier"): return
			if not await _choose_barrier_card("fortified_barrier"): return
			if not await _test_fortified_combat(): return
			controls.begin_retry()
			if not await _choose_barrier_card("magic_barrier"): return
			_barrier_hit("fortified-depleted", 20)
			if not await _choose_barrier_card("fortified_barrier"): return
			if not _check(player.damage_receiver.barrier_health == 10 and player.barrier_capacity() == 30, "소진 뒤 실제 강화 선택은10만 보충·30 전부 충전하지 않음"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-136 runtime test: OK (" + phase + ")")
	quit(0)

func _test_prerequisite() -> bool:
	for ignored in 100:
		for card in growth._draw_cards():
			if not _check(card.id != "fortified_barrier", "선행 없는 강화 후보 차단"): return false
	if not _reject_card("fortified_barrier"): return false
	player.set_fortified_barrier_unlocked(true, true)
	return _check(not player.fortified_barrier_unlocked and player.damage_receiver.barrier_health == 0, "직접 호출도 선행 방벽 없이 강화/보충 없음")

func _choose_barrier_card(id: String) -> bool:
	var chosen_seed := -1
	for candidate in 256:
		growth.rng.seed = candidate
		for card in growth._draw_cards():
			if card.id == id: chosen_seed = candidate
		if chosen_seed >= 0: break
	if not _check(chosen_seed >= 0, "실제 선행에 맞는 방벽 후보 등장"): return false
	growth.rng.seed = chosen_seed
	for ignored in 6:
		if growth.choosing: break
		if runner.current_section == PrototypeStageRunner.Section.ADVANCE_ONE: player.global_position.x = 1240
		elif runner.current_section == PrototypeStageRunner.Section.ADVANCE_TWO: player.global_position.x = 3840
		runner._process(0.1)
		for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
	var index := -1
	for i in growth.offered_cards.size():
		if growth.offered_cards[i].id == id: index = i
	if not _check(index >= 0 and paused and growth.choosing, "실제 처치 레벨업·방벽 카드 UI"): return false
	var before := growth.checkpoint_snapshot()
	var remaining := player.damage_receiver.barrier_health
	var health := player.damage_receiver.health
	var potions := player.potions_remaining
	var equipment := weapons.checkpoint_snapshot()
	var unlocked := player.fortified_barrier_unlocked
	var capacity := player.barrier_capacity()
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_growth_layout()
		var rect: Rect2 = controls.growth_card_rects[index]
		if not _check(controls.layout_snapshot().safe.encloses(rect), "실제 카드 두 화면비 안전 영역"): return false
		var font_size := mini(26, int(rect.size.x / 12.0)) - 3
		for line in growth.offered_cards[index].lines:
			if not _check(ThemeDB.fallback_font.get_string_size(String(line), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= rect.size.x - 24, "실제 방벽 카드 설명 글자 너비"): return false
		controls.queue_redraw()
		await process_frame
	book.save_path = "user://gp136_missing/abilities.jsonl"
	_tap(controls.growth_card_rects[index].get_center())
	if not _check(paused and growth.choosing and growth.checkpoint_snapshot() == before and player.damage_receiver.barrier_health == remaining and player.fortified_barrier_unlocked == unlocked and player.barrier_capacity() == capacity, "발견 기록 실패는 강화/보충/잔량/등급/성향 미적용"): return false
	book.save_path = GP136_BOOK
	_tap(controls.growth_card_rects[index].get_center())
	return _check(not paused and not growth.choosing and growth.ranks.get(id, 0) == 1 and book.snapshot().has(id) and player.damage_receiver.health == health and player.potions_remaining == potions and weapons.checkpoint_snapshot() == equipment, "같은 카드 재선택·효과/발견·체력/회복약/양 무기 대기 유지")

func _test_fortified_combat() -> bool:
	var receiver := player.damage_receiver
	var health := receiver.health
	if not _check(receiver.barrier_health == 30 and controls.movement_metrics.barrier_capacity == 30, "가득 찬 기본 방벽 강화 실제30·HUD"): return false
	if not _check(player.receive_damage(_event("fortified-invalid", 0)) == DamageReceiver.Result.INVALID_EVENT and receiver.barrier_health == 30, "무효 사건은 강화 방벽 소비 없음"): return false
	_barrier_hit("fortified-first8", 8)
	if not _check(receiver.health == health and receiver.barrier_health == 22 and receiver.last_absorbed_damage == 8 and player._input_lock_remaining_s > 0, "강화 실제8흡수·체력 유지·완전 흡수 경직"): return false
	if not _check(player.receive_damage(_event("fortified-first8", 8)) == DamageReceiver.Result.DUPLICATE_BLOCKED and receiver.barrier_health == 22, "동일 타격 중복 소비 없음"): return false
	if not _check(player.receive_damage(_event("fortified-iframe", 8)) == DamageReceiver.Result.INVULNERABLE_BLOCKED and receiver.barrier_health == 22, "피격 무적은 강화 방벽 보존"): return false
	receiver.tick(1)
	player.invincible = true
	if not _check(player.receive_damage(_event("fortified-dodge", 8)) == DamageReceiver.Result.INVULNERABLE_BLOCKED and receiver.barrier_health == 22, "회피 무적은 강화 방벽 보존"): return false
	player.invincible = false
	player.set_fortified_barrier_unlocked(true, true)
	if not _check(receiver.barrier_health == 22, "이미 강화한 능력 반복 호출은10 보충 없음"): return false
	_barrier_hit("fortified-exact22", 22)
	if not _check(receiver.health == health and receiver.barrier_health == 0, "잔량22 정확한 완전 흡수"): return false
	_barrier_hit("fortified-after9", 9)
	if not _check(receiver.health == health - 9 and receiver.last_health_damage == 9, "소진 뒤 정상 피해"): return false
	player.recharge_barrier()
	player.boss_legacy = {"choice": "destroy"}
	_barrier_hit("fortified-risk30", 30)
	if not _check(receiver.last_absorbed_damage == 30 and receiver.last_health_damage == 3 and receiver.barrier_health == 0, "파괴 위험 배율 뒤30흡수·초과3"): return false
	player.boss_legacy = {}
	player.recharge_barrier()
	var before := receiver.health
	receiver.apply_environmental_damage(9, 1)
	if not _check(receiver.health == before - 9 and receiver.barrier_health == 30, "낙하 피해는 강화 방벽 우회"): return false
	_barrier_hit("fortified-partial6", 6)
	player._input_lock_remaining_s = 0
	receiver.health = 40
	if not _check(sandbox._use_recovery_potion() and receiver.health > 40 and receiver.barrier_health == 24, "회복약은 강화 방벽 충전 없음"): return false
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls.queue_redraw()
		player.queue_redraw()
		await process_frame
		if not _check(controls.movement_metrics.barrier_health == 24 and controls.movement_metrics.barrier_capacity == 30 and controls.movement_metrics.fortified_barrier_unlocked, "두 화면비24/30 HUD·현재 최대치 기준 원호"): return false
	player.relic_state = {"id": PrototypeRelic.PHOENIX_ID, "used": false}
	player.relic_run_id = String(recorder.checkpoint_snapshot().id)
	receiver.health = 5
	_barrier_hit("fortified-lethal", 9999)
	if not _check(not receiver.dead and receiver.barrier_health == 0 and player.relic_state.used and player.barrier_capacity() == 30, "치명타30방벽 후 깃털 부활·강화 유지·방벽 무료 충전 없음"): return false
	receiver.tick(2)
	_barrier_hit("fortified-death", 9999)
	player.recharge_barrier()
	return _check(receiver.dead and receiver.barrier_health == 0, "강화 상태 사망 후 충전 거부")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-136 failed: " + message)
		paused = false
		quit(1)
	return condition
