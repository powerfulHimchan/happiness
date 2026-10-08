extends "res://tests/gp138_runtime_test.gd"

const GP140_SAVE := "user://gp140_checkpoint.json"
const GP140_META := "user://gp140_meta.jsonl"
const GP140_RECORD := "user://gp140_records.jsonl"
const GP140_BOOK := "user://gp140_abilities.jsonl"
var mastery_id := "vanguard_dawn_edge"
var base_id := "vanguard_edge"
var job_id := "vanguard"
var weapon_id := "sword"
var attack_bonus := 0.0

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	weapon_id = "bow" if phase.ends_with("bow") else "sword"
	job_id = "tracker" if weapon_id == "bow" else "vanguard"
	base_id = "tracker_focus" if weapon_id == "bow" else "vanguard_edge"
	mastery_id = "tracker_forest_aim" if weapon_id == "bow" else "vanguard_dawn_edge"
	store.save_path = GP140_SAVE
	legacy.save_path = GP140_META
	book.save_path = GP140_BOOK
	if phase.begins_with("seed") or phase == "legacy-seed":
		store.clear_checkpoint()
		for path in [GP140_META, GP140_RECORD, GP140_BOOK]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.ability_discovery_store = book
	sandbox.get_node("LocalTestRecorder").record_path = GP140_RECORD
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
	for controller in [weapons.sword_combat, weapons.bow_combat, ultimate]:
		controller.set_process(false)
		controller.set_physics_process(false)
	player.set_physics_process(false)
	runner.set_process(false)
	if phase.begins_with("seed") or phase == "legacy-seed":
		controls.begin_retry(weapon_id, 5 if weapon_id == "sword" and phase != "legacy-seed" else 3)
		if not _test_gates(true): return
		for ignored in 3:
			if not await _choose_earned(weapon_id + "_power"): return
		if not _check(growth.jobs.job_id == job_id and not paused and not growth.awaiting_job_confirmation, "실제 전투/카드 성향으로 두 직업 발현·필살기 확인"): return
		if not _test_gates(true): return
		if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "실제 첫 정예 완료·기존 장비 유지"): return
		_tap(controls.stage_route_rects[0].get_center())
		if not await _choose_earned(base_id): return
		if phase == "legacy-seed":
			if not await _choose_earned("vitality"): return
		else:
			if not _test_gates(false): return
			if not await _choose_earned(mastery_id, true): return
			if not _test_gates(true): return
			if not _check(growth.ranks[mastery_id] == 1 and is_equal_approx(_bonus(), 1.05), "검/활 강화45+직업10+전용20+강화30 실제 합산"): return
		if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "두 번째 정예 보상·자동 저장"): return
		if phase != "legacy-seed":
			if not _test_invalid_save(): return
			controls.show_main_screen()
			controls.show_village()
			if not await _test_mastery_codex(): return
	elif phase.begins_with("resume"):
		if not _check(growth.ranks.is_empty() and _bonus() == 0.0 and book.snapshot().has(mastery_id), "영구 발견은 새 도전 효과 자동 지급 없음"): return
		for ignored in 2:
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and growth.jobs.job_id == job_id and growth.ranks[mastery_id] == 1 and is_equal_approx(_bonus(), 1.05) and runner.stage_number == 2, "별도 프로세스 반복 이어하기·보너스 재지급 없음"): return
		_tap(controls.stage_route_rects[0].get_center())
		if not await _test_mastery_combat(): return
		while not runner.awaiting_boss_choice():
			if not _finish_stage(): return
			if runner.awaiting_boss_choice(): break
			if not _check(sandbox._claim_weapon_reward(""), "강화 보존한 다음 정예 보상"): return
			_tap(controls.stage_route_rects[0].get_center())
		if not _check(store.load_checkpoint().growth.ranks[mastery_id] == 1 and store.load_checkpoint().stage.number == runner.stage_limit and not store.load_checkpoint().ultimate.profile.is_empty(), "3/5단계 보스 승리 대기에도 직업 강화 저장"): return
	elif phase.begins_with("finish"):
		if not _check(sandbox.continue_saved_run() and runner.awaiting_boss_choice() and growth.ranks[mastery_id] == 1 and is_equal_approx(_bonus(), 1.05), "최종 보스 선택 대기 별도 복원·강화 보존"): return
		if not _check(sandbox._resolve_boss_choice("rescue") and store.load_checkpoint().is_empty(), "보스 구출 완주·중간 저장 삭제"): return
		controls.begin_retry(weapon_id, 3)
		if not _check(growth.ranks.is_empty() and growth.jobs.job_id.is_empty() and _bonus() == 0.0 and book.snapshot().has(mastery_id), "새 도전 직업/강화 초기화·영구 발견 유지"): return
	elif phase == "legacy-resume":
		if not _check(sandbox.continue_saved_run() and growth.jobs.job_id == "vanguard" and growth.ranks.has(base_id) and not growth.ranks.has(mastery_id) and is_equal_approx(_bonus(), 0.75), "기존 직업 전용20 저장 호환·강화30 자동 지급 없음"): return
		_tap(controls.stage_route_rects[0].get_center())
		if not _finish_stage() or not _check(sandbox._resolve_boss_choice("destroy"), "이전 저장 그대로 보스 완주"): return
	else:
		_check(false, "잘못된 검사 단계")
		return
	paused = false
	sandbox.free()
	print("GP-140 runtime test: OK (" + phase + ")")
	quit(0)

func _bonus() -> float:
	return player.growth_sword_bonus if weapon_id == "sword" else player.growth_bow_bonus

func _reject_mastery(id: String) -> bool:
	var before := growth.checkpoint_snapshot()
	var damage := player.growth_damage(100, weapon_id)
	growth.choosing = true
	growth.offered_cards = [PrototypeAbilityCodex.profile(id)]
	var rejected := not growth.choose_card(0)
	growth.choosing = false
	growth.offered_cards.clear()
	return _check(rejected and growth.checkpoint_snapshot() == before and player.growth_damage(100, weapon_id) == damage, "발현/선행/중복 조건 없는 오래된 카드 확정 거부")

func _test_gates(excluded: bool) -> bool:
	var seen := false
	var other := "tracker_forest_aim" if weapon_id == "sword" else "vanguard_dawn_edge"
	for ignored in 128:
		var cards := growth._draw_cards()
		var ids: Array[String] = []
		for card in cards:
			if not _check(card.id not in ids and card.id != other and (not card.has("job") or card.job == growth.jobs.job_id), "세 후보 고유·다른 직업 강화 제외"): return false
			ids.append(card.id)
			if card.id == mastery_id: seen = true
		if not growth.jobs.job_id.is_empty() and not _check(cards[0].job == job_id and cards[1].category == "common", "강화 후보 필터 뒤 직업/공용 보장"): return false
	if not _check(seen == not excluded, "발현·선행·최대1등급에 맞는 실제 추첨"): return false
	if not _reject_mastery(other): return false
	if excluded and not _reject_mastery(mastery_id): return false
	var previous := growth.checkpoint_snapshot()
	growth.choosing = true
	growth.offered_cards = growth._draw_cards()
	growth.rerolls_remaining = 1
	if not _check(growth.reroll(), "실제 재추첨"): return false
	for card in growth.offered_cards:
		if not _check(growth._card_available(card), "재추첨도 선행/직업/최대등급 필터 적용"): return false
	growth.choosing = false
	growth.offered_cards.clear()
	growth.rerolls_remaining = int(previous.rerolls)
	paused = false
	return true

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
	var before := growth.checkpoint_snapshot()
	var equipment := weapons.checkpoint_snapshot()
	var health := player.damage_receiver.health
	var potions := player.potions_remaining
	var bonus := _bonus()
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
		book.save_path = "user://gp140_missing/abilities.jsonl"
		_tap(controls.growth_card_rects[index].get_center())
		if not _check(paused and growth.choosing and growth.checkpoint_snapshot() == before and _bonus() == bonus and not book.snapshot().has(id), "영구 발견 저장 실패·등급/성향/효과 미적용"): return false
		book.save_path = GP140_BOOK
	_tap(controls.growth_card_rects[index].get_center())
	if failure and not _check(is_equal_approx(_bonus(), bonus + 0.30) and player.damage_receiver.health == health and player.potions_remaining == potions and weapons.checkpoint_snapshot() == equipment and ultimate.gauge == gauge, "같은 카드 재시도·무기 피해30만 적용·회복/대기/게이지 보존"): return false
	if growth.awaiting_job_confirmation:
		_tap(controls.job_ultimate_rects[0].get_center())
		_tap(controls.job_confirm_rect.get_center())
	return _check(not paused and not growth.choosing and growth.ranks.has(id) and book.snapshot().has(id), "실제 카드 터치·영구 발견·재개")

func _resolve_growth() -> bool:
	for ignored in 12:
		if growth.awaiting_job_confirmation:
			_tap(controls.job_ultimate_rects[0].get_center())
			_tap(controls.job_confirm_rect.get_center())
		elif growth.choosing:
			# 뒤의 완주 검사에서 보너스를 바꾸지 않는 체력 카드를 고정한다.
			growth.offered_cards = [PrototypeAbilityCodex.profile("vitality")]
			sandbox._on_growth_choices_requested(growth.offered_cards, growth.level, growth.rerolls_remaining)
			_tap(controls.growth_card_rects[0].get_center())
		else: return true
	return _check(false, "성장/발현 대기 해소")

func _test_invalid_save() -> bool:
	var saved := store.load_checkpoint()
	if not _check(saved.growth.ranks[mastery_id] == 1 and is_equal_approx(float(saved.player[weapon_id]), 1.05), "기존 등급/무기 보너스 필드만 저장"): return false
	for invalid in [null, true, "1", 0, 2, 0.5]:
		var bad := saved.duplicate(true)
		bad.growth.ranks[mastery_id] = invalid
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "강화 등급 타입/0/2/소수 거부·정상 파일 보호"): return false
	var bad := saved.duplicate(true)
	bad.growth.ranks.erase(base_id)
	bad.growth.ranks.vitality = int(bad.growth.ranks.get("vitality", 0)) + 1
	bad.player.max_health += 20
	bad.player.health += 20
	bad.player[weapon_id] -= 0.20
	if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA, "다른 수치 일관성을 맞춰도 선행 없는 직업 강화 거부"): return false
	bad = saved.duplicate(true)
	bad.player[weapon_id] += 0.30
	if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA, "저장된 보너스 추가 지급 변조 거부"): return false
	bad = saved.duplicate(true)
	bad.growth.job = "tracker" if job_id == "vanguard" else "vanguard"
	if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA, "다른 직업의 강화 저장 차단"): return false
	store.save_path = "user://gp140_missing/checkpoint.json"
	var failed: bool = sandbox._save_checkpoint(runner.current_metrics()) != OK
	store.save_path = GP140_SAVE
	return _check(failed and growth.ranks[mastery_id] == 1 and is_equal_approx(_bonus(), 1.05) and store.load_checkpoint() == saved, "중간 저장 실패는 효과와 정상 파일 보존")

func _test_mastery_codex() -> bool:
	if not await _test_book_layout(): return false
	if not _check(PrototypeAbilityCodex.definitions().size() == PrototypeGrowthController.CARDS.size() + PrototypeJobRewards.CARDS.size(), "성장/직업 원본 전체 도감"): return false
	var cards := PrototypeAbilityCodex.cards(book.snapshot(), growth.ranks)
	var card: Dictionary = cards.filter(func(item: Dictionary) -> bool: return item.id == mastery_id)[0]
	var source := PrototypeAbilityCodex.profile(mastery_id)
	if not _check(card.open and card.status == "이번 도전 1등급" and card.lines[0] == source.lines[0] and card.lines[1] == source.lines[1] and String(PrototypeAbilityCodex.profile(base_id).title) in card.lines[2] and String(PrototypeJobProgress.profile(job_id).name) in card.lines[2] and card.lines[3] == "도전당 1회 선택", "원본 효과·직업과 선행 두 조건·최대1등급 도감"): return false
	controls.village_page = "jobs"
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_layout()
		var snapshot: Dictionary = controls.village_snapshot()
		for i in snapshot.cards.size():
			var item: Dictionary = snapshot.cards[i]
			var rect: Rect2 = snapshot.layout.cards[i]
			if not _check(item.lines.size() == 7 and item.lines[-1].contains("전용 강화"), "직업 도감에서 두 강화 안내"): return false
			for j in item.lines.size():
				var line_height := 0.48 / maxi(6, item.lines.size())
				var line_rect := Rect2(rect.position + Vector2(12, rect.size.y * (0.44 + j * line_height)), Vector2(rect.size.x - 24, rect.size.y * line_height))
				var font_size := mini(18, maxi(12, int(line_rect.size.y * 0.8)))
				while font_size > 10 and ThemeDB.fallback_font.get_string_size(item.lines[j], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > line_rect.size.x: font_size -= 1
				if not _check(rect.encloses(line_rect) and ThemeDB.fallback_font.get_string_size(item.lines[j], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= line_rect.size.x, "두 화면비 일곱 설명 줄이 카드 내부에 표시"): return false
		controls.queue_redraw()
		await process_frame
	return true

func _test_mastery_combat() -> bool:
	for target in get_nodes_in_group("targetable"): target.visible = false
	player.global_position = Vector2(1000, 780)
	player.facing_direction = 1
	var equipment := weapons.equipment.duplicate()
	weapons.set_equipment({"sword": 0, "bow": 0})
	for weapon in ["sword", "bow"]:
		for kind in ["basic", "skill"]:
			var target := _absorb_target("gp140:" + weapon + kind, player.global_position + Vector2(200, 0))
			var before := target.damage_receiver.health
			if weapon == "sword":
				weapons.sword_combat._action_sequence += 1
				weapons.sword_combat._damage_target(target, &"sword_basic" if kind == "basic" else &"sword_spin", 100, 0, PackedStringArray(["sword", kind]), 0)
			else:
				weapons.bow_combat._spawn_projectile("gp140:" + kind, &"bow_basic" if kind == "basic" else &"bow_piercing", 100, 1, Vector2.RIGHT, PackedStringArray(["bow", kind]))
				var shot: BowProjectile = get_nodes_in_group("bow_projectile").back()
				shot.set_physics_process(false)
				shot._check_hits(shot.global_position, target.global_position + Vector2(0, -38))
				shot.free()
			if not _check(before - target.damage_receiver.health == (205 if weapon == weapon_id else 100), "검 실제 타격·활 실제 투사체 기본/스킬205·반대 무기100"): return false
			target.free()
	var burst := _absorb_target("gp140:ultimate", player.global_position + Vector2(150, 0))
	var expected := 123 if weapon_id == "sword" else 92
	ultimate.gauge = 100
	ultimate.request_ultimate()
	if not _check(1000 - burst.damage_receiver.health == expected and ultimate._active and is_equal_approx(ultimate._remaining_s, 3.0) and ultimate.gauge == 0, "공격형 직업 필살기 실제 강화·감속/시간/게이지 유지"): return false
	ultimate.finish_stage_effect()
	burst.free()
	weapons.set_equipment(equipment)
	return _test_gates(true)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-140 failed: " + message)
		paused = false
		quit(1)
	return condition
