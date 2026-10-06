extends "res://tests/gp126_runtime_test.gd"

const GP128_SAVE := "user://gp128_checkpoint.json"
const GP128_META := "user://gp128_meta.jsonl"
const GP128_RECORD := "user://gp128_records.jsonl"
const GP128_BOOK := "user://gp128_abilities.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP128_SAVE
	legacy.save_path = GP128_META
	book.save_path = GP128_BOOK
	if phase in ["seed", "combat"]:
		store.clear_checkpoint()
		for path in [GP128_META, GP128_RECORD, GP128_BOOK]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.ability_discovery_store = book
	sandbox.get_node("LocalTestRecorder").record_path = GP128_RECORD
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
	for controller in [weapons.sword_combat, weapons.bow_combat]:
		controller.set_process(false)
		controller.set_physics_process(false)
	player.set_physics_process(false)
	runner.set_process(false)
	match phase:
		"seed":
			controls.begin_retry()
			if not _check(not player.barrier_unlocked and player.damage_receiver.barrier_health == 0, "새 도전 방벽 없음"): return
			if not await _choose_barrier(): return
			if not _check(player.barrier_unlocked and player.damage_receiver.barrier_health == 20 and growth.ranks.magic_barrier == 1 and book.snapshot().has("magic_barrier"), "실제 카드 20방벽·1등급·영구 발견"): return
			var health := player.damage_receiver.health
			if not _check(_barrier_hit("seed7", 7) == DamageReceiver.Result.APPLIED and player.damage_receiver.health == health and player.damage_receiver.barrier_health == 13, "실제 피격 7 흡수·체력 보존"): return
			for ignored in 100:
				for card in growth._draw_cards():
					if not _check(card.id != "magic_barrier", "소유 방벽 후보 제외"): return
			if not _finish_stage(): return
			if not _check(player.damage_receiver.barrier_health == 13, "휴식 화면 진입은 충전하지 않음"): return
			var saved := store.load_checkpoint()
			store.save_path = "user://gp128_missing/checkpoint.json"
			if not _check(not sandbox._claim_weapon_reward("") and not runner.reward_claimed and player.damage_receiver.barrier_health == 13, "보상 저장 실패는 방벽·보상 사용 유지"): return
			store.save_path = GP128_SAVE
			if not _check(store.load_checkpoint() == saved and sandbox._claim_weapon_reward(""), "정상 저장 보호·재시도"): return
			saved = store.load_checkpoint()
			if not _check(saved.player.barrier_health == 13 and saved.growth.ranks.magic_barrier == 1, "방벽 잔량 저장"): return
			for invalid in [null, true, "13", [], {}, -1, 21, 0.5]:
				var bad := saved.duplicate(true)
				bad.player.barrier_health = invalid
				if not _check(not RunCheckpointStore.valid_state(bad) and store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "변조 잔량 거부·정상 저장 보호"): return
			controls.show_main_screen()
			controls.show_village()
			if not await _test_book_layout(): return
			controls.ability_codex_page = 3
			var cards: Array = controls.village_snapshot().cards
			if not _check(cards[0].id == "magic_barrier" and cards[0].open and cards[0].status == "이번 도전 1등급" and cards[0].lines[0] == "피해 20을 먼저 흡수", "방벽 도감 원본 효과·발견·현재 등급"): return
		"resume":
			if not _check(not player.barrier_unlocked and player.damage_receiver.barrier_health == 0 and controls.discovered_abilities.has("magic_barrier"), "발견 기록만으로 시작 방벽 없음"): return
			if not _check(sandbox.continue_saved_run() and player.barrier_unlocked and player.damage_receiver.barrier_health == 13, "별도 프로세스 13 잔량 복원·충전 없음"): return
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and player.damage_receiver.barrier_health == 13, "이어하기 반복은 무료 충전 없음"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _check(runner.stage_number == 2 and player.damage_receiver.barrier_health == 20, "실제 다음 경로 진입에서 20 충전"): return
			_barrier_hit("resume21", 21)
			if not _check(player.damage_receiver.barrier_health == 0 and player.damage_receiver.last_absorbed_damage == 20 and player.damage_receiver.last_health_damage == 1, "20 초과분만 체력 피해"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward("") and store.load_checkpoint().player.barrier_health == 0, "소진 방벽 그대로 두 번째 저장"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and player.barrier_unlocked and player.damage_receiver.barrier_health == 0, "소진 잔량 재시작 복원"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _check(player.damage_receiver.barrier_health == 20, "세 번째 스테이지 충전"): return
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("rescue") and store.load_checkpoint().is_empty(), "방벽 보스 완주·저장 정리"): return
			controls.begin_retry()
			if not _check(not player.barrier_unlocked and player.damage_receiver.barrier_health == 0 and book.snapshot().has("magic_barrier"), "새 도전 방벽 초기화·영구 발견 유지"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 저장 준비"): return
			var old := store.load_checkpoint()
			old.player.erase("barrier_health")
			if not _check(not old.growth.ranks.has("magic_barrier") and store.save_checkpoint(old) == OK, "이전 필드 없는 저장 호환"): return
			old.player.barrier_health = 1
			if not _check(not RunCheckpointStore.valid_state(old), "능력 없는 양수 방벽 변조 거부"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and not player.barrier_unlocked and player.damage_receiver.barrier_health == 0, "이전 저장 방벽 미해금"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _check(player.damage_receiver.barrier_health == 0, "미해금은 스테이지 충전 없음"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 저장 두 번째 통과"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("destroy"), "이전 저장 실제 보스 완주"): return
		"combat":
			controls.begin_retry()
			if not await _choose_barrier(): return
			if not await _test_barrier_combat(): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-128 runtime test: OK (" + phase + ")")
	quit(0)

func _choose_barrier() -> bool:
	var chosen_seed := -1
	for candidate in 128:
		growth.rng.seed = candidate
		for card in growth._draw_cards():
			if card.id == "magic_barrier": chosen_seed = candidate
		if chosen_seed >= 0: break
	if not _check(chosen_seed >= 0, "공용 방벽 후보 등장"): return false
	growth.rng.seed = chosen_seed
	player.global_position.x = 1240
	runner._process(0.1)
	for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
	var index := -1
	for i in growth.offered_cards.size():
		if growth.offered_cards[i].id == "magic_barrier": index = i
	if not _check(index >= 0 and paused and growth.choosing, "실제 처치 첫 레벨업"): return false
	var before := growth.checkpoint_snapshot()
	book.save_path = "user://gp128_missing/abilities.jsonl"
	_tap(controls.growth_card_rects[index].get_center())
	if not _check(paused and growth.choosing and growth.checkpoint_snapshot() == before and not player.barrier_unlocked and player.damage_receiver.barrier_health == 0, "발견 저장 실패는 방벽·등급·성향 미적용"): return false
	book.save_path = GP128_BOOK
	_tap(controls.growth_card_rects[index].get_center())
	return _check(not paused and not growth.choosing and player.barrier_unlocked, "같은 카드 재선택·방벽 적용·전투 재개")

func _event(id: String, damage: int) -> DamageEvent:
	var event := DamageEvent.new()
	event.event_id = StringName("gp128:" + id)
	event.attacker_id = &"enemy"
	event.damage = damage
	event.stagger_s = 0.12
	event.tags = PackedStringArray(["enemy", "test"])
	return event

func _barrier_hit(id: String, damage: int) -> int:
	player.damage_receiver.tick(1.0)
	return player.receive_damage(_event(id, damage))

func _test_barrier_combat() -> bool:
	var receiver := player.damage_receiver
	var health := receiver.health
	var potions := player.potions_remaining
	if not _check(player.receive_damage(_event("invalid", 0)) == DamageReceiver.Result.INVALID_EVENT and receiver.barrier_health == 20, "무효 피해는 소모 없음"): return false
	if not _check(_barrier_hit("first8", 8) == DamageReceiver.Result.APPLIED and receiver.health == health and receiver.barrier_health == 12 and receiver.last_absorbed_damage == 8 and player._input_lock_remaining_s > 0 and receiver.is_post_hit_invulnerable(), "완전 흡수도 경직·피격 무적·8 소모"): return false
	if not _check(player.receive_damage(_event("first8", 8)) == DamageReceiver.Result.DUPLICATE_BLOCKED and receiver.barrier_health == 12, "동일 타격 중복은 추가 소모 없음"): return false
	if not _check(player.receive_damage(_event("iframe", 8)) == DamageReceiver.Result.INVULNERABLE_BLOCKED and receiver.barrier_health == 12, "피격 무적은 방벽 소모 없음"): return false
	receiver.tick(1.0)
	player.invincible = true
	if not _check(player.receive_damage(_event("dodge", 8)) == DamageReceiver.Result.INVULNERABLE_BLOCKED and receiver.barrier_health == 12, "회피 무적은 방벽 소모 없음"): return false
	player.invincible = false
	if not _check(player.receive_damage(_event("dodge", 8)) == DamageReceiver.Result.DUPLICATE_BLOCKED and receiver.barrier_health == 12, "회피로 막힌 타격 재전달도 소모 없음"): return false
	_barrier_hit("exact12", 12)
	if not _check(receiver.health == health and receiver.barrier_health == 0 and receiver.last_health_damage == 0 and potions == player.potions_remaining, "정확한 잔량 완전 흡수·체력과 회복약 보존"): return false
	_barrier_hit("after9", 9)
	if not _check(receiver.health == health - 9 and receiver.last_health_damage == 9, "소진 뒤 정상 체력 피해"): return false
	player.recharge_barrier()
	player.boss_legacy = {"choice": "destroy"}
	var original := _event("risk20", 20)
	receiver.tick(1.0)
	player.receive_damage(original)
	if not _check(original.damage == 20 and receiver.barrier_health == 0 and receiver.last_absorbed_damage == 20 and receiver.last_health_damage == 2, "파괴 위험 배율 뒤 방벽 흡수·원본 사건 유지"): return false
	player.boss_legacy = {}
	player.recharge_barrier()
	var before := receiver.health
	receiver.apply_environmental_damage(9, 1)
	if not _check(receiver.health == before - 9 and receiver.barrier_health == 20, "낙하 환경 피해는 방벽 우회"): return false
	_barrier_hit("partial6", 6)
	player._input_lock_remaining_s = 0
	receiver.health = 40
	if not _check(sandbox._use_recovery_potion() and receiver.health > 40 and receiver.barrier_health == 14 and player.potions_remaining == potions - 1, "회복약은 체력만 회복·방벽 잔량 유지"): return false
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls.queue_redraw()
		player.queue_redraw()
		await process_frame
		if not _check(controls.movement_metrics.barrier_health == 14 and controls.movement_metrics.barrier_unlocked and controls.movement_metrics.barrier_capacity == 20, "두 화면비 실제 HUD·방벽 원호 그리기·잔량"): return false
	var run_id := String(recorder.checkpoint_snapshot().id)
	if not _check(legacy.grant("gp128-rescue", "rescue") == OK, "구출 조력 준비"): return false
	player.boss_legacy = legacy.claim(run_id, true).state
	player.recharge_barrier()
	receiver.health = 5
	var journal := FileAccess.get_file_as_string(GP128_META)
	_barrier_hit("low-full6", 6)
	if not _check(receiver.health == 5 and not player.boss_legacy.rescue_used and FileAccess.get_file_as_string(GP128_META) == journal, "낮은 체력 완전 흡수는 구출 조력 소비 없음"): return false
	_barrier_hit("low-over16", 16)
	if not _check(receiver.health == 33 and player.boss_legacy.rescue_used, "초과분 체력 피해에는 기존 구출 조력 정상 발동"): return false
	player.relic_state = {"id": PrototypeRelic.PHOENIX_ID, "used": false}
	player.relic_run_id = run_id
	player.recharge_barrier()
	receiver.health = 5
	_barrier_hit("lethal1000", 1000)
	if not _check(not receiver.dead and receiver.health == 50 and receiver.barrier_health == 0 and player.relic_state.used and legacy.phoenix_used(run_id), "방벽 초과 치명타만 불사조 소비·부활은 방벽 충전 없음"): return false
	receiver.tick(2.0)
	_barrier_hit("death1000", 1000)
	if not _check(receiver.dead and not growth.run_active and receiver.barrier_health == 0, "유물 소진 후 사망·방벽 없음"): return false
	player.recharge_barrier()
	if not _check(receiver.barrier_health == 0, "사망 후 충전 거부"): return false
	receiver.barrier_health = 20
	if not _check(player.receive_damage(_event("dead", 10)) == DamageReceiver.Result.DEAD_BLOCKED and receiver.barrier_health == 20, "사망 후 타격은 방벽 소모 없음"): return false
	return true

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-128 failed: " + message)
		quit(1)
	return condition
