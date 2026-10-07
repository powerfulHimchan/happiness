extends "res://tests/gp136_runtime_test.gd"

const GP138_SAVE := "user://gp138_checkpoint.json"
const GP138_META := "user://gp138_meta.jsonl"
const GP138_RECORD := "user://gp138_records.jsonl"
const GP138_BOOK := "user://gp138_abilities.jsonl"
var ultimate: UltimateController

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP138_SAVE
	legacy.save_path = GP138_META
	book.save_path = GP138_BOOK
	if phase in ["seed", "combat"]:
		store.clear_checkpoint()
		for path in [GP138_META, GP138_RECORD, GP138_BOOK]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.ability_discovery_store = book
	sandbox.get_node("LocalTestRecorder").record_path = GP138_RECORD
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
	ultimate = sandbox.get_node("Player/UltimateController")
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	for controller in [weapons.sword_combat, weapons.bow_combat, ultimate]:
		controller.set_process(false)
		controller.set_physics_process(false)
	player.set_physics_process(false)
	runner.set_process(false)
	match phase:
		"seed":
			controls.begin_retry()
			ultimate.gauge = 37
			ultimate.force_emit_metrics()
			if not await _choose_collector(): return
			if not _check(ultimate.gauge == 37, "선택 전 처치·선택 자체는 충전 없음"): return
			for ignored in 100:
				for card in growth._draw_cards():
					if not _check(card.id != "time_collector", "도전당1회 후보 제외"): return
			if not _reject_card("time_collector") or not _check(ultimate.gauge == 37, "중복 선택 충전 없음"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "첫 정예 실제 완료·보상 저장"): return
			ultimate.gauge = 37
			ultimate.force_emit_metrics()
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "현재37 게이지 저장"): return
			var saved := store.load_checkpoint()
			if not _check(saved.growth.ranks.time_collector == 1 and saved.ultimate.gauge == 37 and saved.ultimate.size() == 2, "기존 등급/게이지 필드만 사용"): return
			var bad := saved.duplicate(true)
			bad.growth.ranks.time_collector = 2
			if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "최대1등급 변조 거부·정상 파일 보호"): return
			store.save_path = "user://gp138_missing/checkpoint.json"
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) != OK and ultimate.gauge == 37 and growth.ranks.time_collector == 1, "저장 실패 게이지/능력 보존"): return
			store.save_path = GP138_SAVE
			controls.show_main_screen()
			controls.show_village()
			if not await _test_book_layout(): return
			controls.ability_codex_page = 4
			var cards: Array = controls.village_snapshot().cards
			if not _check(PrototypeAbilityCodex.definitions().size() == 18 and cards[1].id == "time_collector" and cards[1].open and cards[1].status == "이번 도전 1등급" and cards[1].lines[0] == "적 처치마다 필살기 게이지 +5", "18능력 도감·원본 효과·영구 발견·현재등급"): return
		"resume":
			if not _check(ultimate.gauge == 0 and not growth.ranks.has("time_collector") and book.snapshot().has("time_collector") and not controls._ultimate_hud_label().contains("처치 +5"), "영구 발견만으로 효과 지급 없음"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and growth.ranks.time_collector == 1 and ultimate.gauge == 37, "별도 프로세스 반복 이어하기37·중복 지급 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _check(ultimate.gauge == 37, "풀숲 다음 단계 게이지 유지"): return
			player.global_position.x = 1240
			runner._process(0.1)
			_defeat(runner._active_enemies[0])
			if not _check(ultimate.gauge == 42 and controls._ultimate_hud_label().contains("처치 +5"), "복원 후 실제 처치+5·HUD"): return
			if not _resolve_growth() or not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "두 번째 정예 실제 통과"): return
			ultimate.gauge = 0
			ultimate.force_emit_metrics()
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK and store.load_checkpoint().ultimate.gauge == 0, "소진0 저장"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and growth.ranks.time_collector == 1 and ultimate.gauge == 0, "소진0 복원·무료 충전 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("rescue"), "실제 보스 완주"): return
			if not _check(not controls._ultimate_hud_label().contains("처치 +5"), "완료 후 현재 도전 HUD 해제"): return
			controls.begin_retry()
			if not _check(not growth.ranks.has("time_collector") and ultimate.gauge == 0 and book.snapshot().has("time_collector"), "새 도전 등급/게이지 초기화·발견 유지"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "기존 능력 없는 저장 준비"): return
			# Deterministically remove a randomly selected collector from this legacy fixture.
			var old := store.load_checkpoint()
			if old.growth.ranks.has("time_collector"):
				old.growth.ranks.erase("time_collector")
				old.growth.ranks["vitality"] = int(old.growth.ranks.get("vitality", 0)) + 1
				old.player.max_health += 20
				old.player.health += 20
			if not _check(store.save_checkpoint(old) == OK and not store.load_checkpoint().growth.ranks.has("time_collector"), "시간 수집 이전 저장 호환 준비"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and not growth.ranks.has("time_collector") and not controls._ultimate_hud_label().contains("처치 +5"), "이전 저장 능력 자동 지급 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			player.global_position.x = 1240
			runner._process(0.1)
			var before := ultimate.gauge
			_defeat(runner._active_enemies[0])
			if not _check(ultimate.gauge == before, "미선택 실제 처치 충전 없음"): return
			if not _resolve_growth() or not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 저장 두 번째 통과"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("destroy"), "이전 저장 보스 완주"): return
		"combat":
			controls.begin_retry()
			if not await _choose_collector(): return
			if not await _test_collector_combat(): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-138 runtime test: OK (" + phase + ")")
	quit(0)

func _choose_collector() -> bool:
	var chosen_seed := -1
	for candidate in 256:
		growth.rng.seed = candidate
		for card in growth._draw_cards():
			if card.id == "time_collector": chosen_seed = candidate
		if chosen_seed >= 0: break
	if not _check(chosen_seed >= 0, "공용 시간 수집 후보 등장"): return false
	growth.rng.seed = chosen_seed
	var before_gauge := ultimate.gauge
	player.global_position.x = 1240
	runner._process(0.1)
	for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
	var index := -1
	for i in growth.offered_cards.size():
		if growth.offered_cards[i].id == "time_collector": index = i
	if not _check(index >= 0 and paused and growth.choosing and ultimate.gauge == before_gauge, "실제 처치 레벨업·선택 전 충전 없음"): return false
	var before := growth.checkpoint_snapshot()
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_growth_layout()
		var rect: Rect2 = controls.growth_card_rects[index]
		if not _check(controls.layout_snapshot().safe.encloses(rect), "카드 두 화면비 안전 영역"): return false
		for line in growth.offered_cards[index].lines:
			if not _check(ThemeDB.fallback_font.get_string_size(String(line), HORIZONTAL_ALIGNMENT_LEFT, -1, mini(26, int(rect.size.x / 12.0)) - 3).x <= rect.size.x - 24, "카드 설명 글자 너비"): return false
		controls.queue_redraw()
		await process_frame
	book.save_path = "user://gp138_missing/abilities.jsonl"
	_tap(controls.growth_card_rects[index].get_center())
	if not _check(paused and growth.choosing and growth.checkpoint_snapshot() == before and ultimate.gauge == before_gauge, "발견 기록 실패 효과/등급/성향/게이지 미적용"): return false
	book.save_path = GP138_BOOK
	_tap(controls.growth_card_rects[index].get_center())
	return _check(not paused and not growth.choosing and growth.ranks.time_collector == 1 and book.snapshot().has("time_collector") and ultimate.gauge == before_gauge, "같은 카드 재선택·영구 발견·즉시 충전 없음")

func _collector_target(key: String) -> PrototypeTarget:
	var target := _absorb_target("collector:" + key, player.global_position + Vector2(200, 0))
	if not target.defeated.is_connected(growth._on_enemy_defeated):
		target.defeated.connect(growth._on_enemy_defeated)
	return target

func _test_collector_combat() -> bool:
	for target in get_nodes_in_group("targetable"): target.visible = false
	player.global_position = Vector2(1000, 780)
	player.facing_direction = 1
	var target := _collector_target("sword")
	_sword_hit(target, 10)
	if not _check(ultimate.gauge == 4, "검 비치명 기본 타격 기존+4 유지"): return false
	_sword_hit(target, 9999)
	if not _check(ultimate.gauge == 13, "검 처치 기존 타격4+처치5 각각1회"): return false
	target.defeated.emit(target)
	if not _check(ultimate.gauge == 13, "중복 처치 신호 충전 없음"): return false
	target.reset_target()
	target.defeated.emit(target)
	if not _check(ultimate.gauge == 13, "살아 있는 적의 위조 처치 충전 없음"): return false
	_defeat(target)
	if not _check(ultimate.gauge == 18, "같은 적 새 생명 실제 처치+5"): return false
	if not _resolve_growth(): return false
	target.visible = false
	target = _collector_target("bow")
	_arrow_hit(target, 9999, "gp138:bow")
	if not _check(ultimate.gauge == 27, "활 화살 처치 기존4+5·반복 충돌 중복 없음"): return false
	if not _resolve_growth(): return false
	target.visible = false
	for kind in ["ordinary", "elite", "boss"]:
		target = _collector_target(kind)
		if kind != "ordinary": target.add_to_group("elite_enemy")
		if kind == "boss": target.add_to_group("boss_enemy")
		var before := ultimate.gauge
		_defeat(target)
		if not _check(ultimate.gauge == before + 5, "일반/정예/보스 동일5"): return false
		if not _resolve_growth(): return false
		target.visible = false
	target = _collector_target("guard")
	target.remove_from_group("combat_enemy")
	var before := ultimate.gauge
	_defeat(target)
	if not _check(ultimate.gauge == before, "연습 표적 처치 충전 제외"): return false
	target.add_to_group("combat_enemy")
	target.visible = false
	target.defeated.emit(target)
	if not _check(ultimate.gauge == before, "숨긴 적 처치 신호 충전 제외"): return false
	target.visible = true
	player.damage_receiver.dead = true
	target.defeated.emit(target)
	player.damage_receiver.dead = false
	growth.run_active = false
	target.defeated.emit(target)
	growth.run_active = true
	if not _check(ultimate.gauge == before, "플레이어 사망/도전 비활성 충전 차단"): return false
	ultimate.gauge = 98
	target.defeated.emit(target)
	if not _check(ultimate.gauge == 100, "98+5는100 상한"): return false
	if not _resolve_growth(): return false
	target.visible = false
	ultimate.request_ultimate()
	if not _check(ultimate._active and ultimate.gauge == 0, "공용 필살기 실제 사용·소비0"): return false
	var duration := ultimate._remaining_s
	target = _collector_target("active")
	_defeat(target)
	if not _check(ultimate.gauge == 5 and ultimate._remaining_s == duration, "발동 중 처치5·지속시간 연장 없음"): return false
	if not _resolve_growth(): return false
	target.visible = false
	ultimate.gauge = 100
	ultimate.request_ultimate()
	if not _check(ultimate.activation_count == 1 and ultimate.gauge == 100, "발동 중 재사용·재소비 차단"): return false
	ultimate.finish_stage_effect()
	for profile in PrototypeJobRewards.ULTIMATES:
		ultimate.reset_ultimate()
		if not _check(ultimate.select_job_ultimate(profile.job, profile.id), "네 직업 필살기 실제 선택"): return false
		var burst := _collector_target(String(profile.id) + ":burst")
		burst.damage_receiver.health = 1
		ultimate.gauge = 100
		ultimate.request_ultimate()
		var burst_gain := 5 if int(profile.get("damage", 0)) > 0 else 0
		if not _check(ultimate.gauge == burst_gain and burst.damage_receiver.dead == (burst_gain > 0), "직업 필살기 자체 처치도5·회복 필살기는 처치 없음"): return false
		burst.visible = false
		if not _resolve_growth(): return false
		duration = ultimate._remaining_s
		target = _collector_target(String(profile.id))
		_defeat(target)
		if not _check(ultimate._active and ultimate.gauge == burst_gain + 5 and ultimate._remaining_s == duration, "네 직업 필살기 발동 중 처치 충전 독립"): return false
		if not _resolve_growth(): return false
		target.visible = false
		if not await _test_collector_hud(): return false
		ultimate.finish_stage_effect()
	return true

func _test_collector_hud() -> bool:
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls.queue_redraw()
		await process_frame
		var text: String = controls._ultimate_hud_label()
		var width: float = controls.hud_rect.size.x * 0.36
		var font_size := 17
		while font_size > 10 and ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width: font_size -= 1
		if not _check(text.contains("처치 +5") and text.contains("발동 중") and ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width, "두 화면비 직업 이름/발동 상태/처치5 HUD 너비"): return false
	return true

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-138 failed: " + message)
		paused = false
		quit(1)
	return condition
