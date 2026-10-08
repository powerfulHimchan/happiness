extends "res://tests/gp141_runtime_test.gd"

const ECHO_SAVE := "user://gp144_checkpoint.json"
const ECHO_META := "user://gp144_meta.jsonl"
const ECHO_RECORD := "user://gp144_records.jsonl"
const ECHO_BOOK := "user://gp144_abilities.jsonl"

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	store.save_path = ECHO_SAVE
	legacy.save_path = ECHO_META
	book.save_path = ECHO_BOOK
	if phase in ["seed", "legacy-seed", "combat"]:
		store.clear_checkpoint()
		for path in [ECHO_META, ECHO_RECORD, ECHO_BOOK]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.ability_discovery_store = book
	sandbox.get_node("LocalTestRecorder").record_path = ECHO_RECORD
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
			if not _test_gates(false): return
			if not await _choose_earned("time_collector"): return
			ultimate.gauge = 100
			ultimate.request_ultimate()
			ultimate._physics_process(0.5)
			var remaining := ultimate._remaining_s
			if not await _choose_echo(true): return
			if not _check(ultimate.time_echo_unlocked and ultimate._active and is_equal_approx(ultimate._remaining_s, remaining) and ultimate._active_duration_s == 3.0 and ultimate.duration_for({}) == 4.0, "발동 도중 획득은 현재 감속3초/잔량 유지·다음부터4초"): return
			if not _test_gates(true) or not await _test_echo_view(): return
			ultimate._physics_process(remaining)
			if not _test_cast({}, true): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "실제 정예 보상 저장"): return
			player.damage_receiver.health = 17
			ultimate.gauge = 37
			weapons.sword_combat._skill_1_cooldown_s = 3.25
			weapons.bow_combat._skill_2_cooldown_s = 5.5
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "여운/선행 등급·체력·게이지·양 대기 저장"): return
			if not _test_echo_save(): return
		"resume":
			if not _check(not ultimate.time_echo_unlocked and book.snapshot().has("time_echo"), "영구 발견만으로 강화 지급 없음"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and ultimate.time_echo_unlocked and ultimate.duration_for(ultimate.selected_profile) == 4.0 and ultimate.gauge == 37 and player.damage_receiver.health == 17 and weapons.sword_combat._skill_1_cooldown_s == 3.25 and weapons.bow_combat._skill_2_cooldown_s == 5.5, "별도 프로세스·반복 이어하기·시간/체력/대기/게이지 비누적"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _test_cast({}, true) or not await _test_echo_view(): return
			if not await _test_freeze_and_resume(): return
			while not runner.awaiting_boss_choice():
				if not _finish_stage(): return
				if runner.awaiting_boss_choice(): break
				if not _check(sandbox._claim_weapon_reward(""), "긴 도전 정예 보상·여운 유지"): return
				_tap(controls.stage_route_rects[0].get_center())
			if not _check(store.load_checkpoint().growth.ranks.time_echo == 1 and runner.stage_number == 5, "5스테이지 최종 선택 저장·강화 유지"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and ultimate.time_echo_unlocked and sandbox._resolve_boss_choice("rescue") and store.load_checkpoint().is_empty(), "별도 보스 선택 복원·완주"): return
			controls.begin_retry("bow", 3)
			if not _check(not ultimate.time_echo_unlocked and ultimate.duration_for({}) == 3.0 and growth.ranks.is_empty() and book.snapshot().has("time_echo"), "새 도전 기본시간 복원·능력 초기화·발견 유지"): return
			if not _test_cast({}, false): return
		"legacy-seed":
			controls.begin_retry("bow", 3)
			if not await _choose_earned("time_collector"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward("") and not store.load_checkpoint().growth.ranks.has("time_echo"), "여운 이전의 시간수집 저장 준비"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and not ultimate.time_echo_unlocked and growth.ranks.has("time_collector") and ultimate.duration_for(ultimate.selected_profile) == 3.0, "기존 저장 호환·여운 소급 지급 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _test_cast({}, false): return
			while not runner.awaiting_boss_choice():
				if not _finish_stage(): return
				if runner.awaiting_boss_choice(): break
				if not _check(sandbox._claim_weapon_reward(""), "이전 저장 정예 보상"): return
				_tap(controls.stage_route_rects[0].get_center())
			if not _check(sandbox._resolve_boss_choice("destroy"), "이전3스테이지 저장 완주"): return
		"combat":
			controls.begin_retry()
			if not await _choose_earned("time_collector") or not await _choose_echo(false): return
			if not _test_cast({}, true): return
			for candidate in PrototypeJobRewards.ULTIMATES:
				if not _test_cast(candidate, true): return
			if not await _test_profile_preview(): return
			if not _test_combat_locks(): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-144 runtime test: OK (" + phase + ")")
	quit(0)

func _choose_echo(failure: bool) -> bool:
	var seed_value := -1
	for candidate in 512:
		growth.rng.seed = candidate
		if growth._draw_cards().any(func(card: Dictionary) -> bool: return card.id == "time_echo"):
			seed_value = candidate
			break
	if not _check(seed_value >= 0, "선행 획득 뒤 실제 여운 후보"): return false
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
		if growth.offered_cards[i].id == "time_echo": index = i
	if not _check(index >= 0 and paused, "실제 처치 경험치·레벨업·강화 카드"): return false
	var before := growth.checkpoint_snapshot()
	var gauge := ultimate.gauge
	var remaining := ultimate._remaining_s
	var profile := ultimate.selected_profile.duplicate(true)
	var loadout := weapons.checkpoint_snapshot()
	if failure:
		for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
			controls.size = dimensions
			controls._refresh_growth_layout()
			var rect: Rect2 = controls.growth_card_rects[index]
			if not _check(controls.layout_snapshot().safe.encloses(rect), "여운 카드 두 화면비 안전 영역"): return false
			for line in growth.offered_cards[index].lines:
				if not _check(ThemeDB.fallback_font.get_string_size(String(line), HORIZONTAL_ALIGNMENT_LEFT, -1, mini(26, int(rect.size.x / 12.0)) - 3).x <= rect.size.x - 24, "강화 카드 글자 너비"): return false
			controls.queue_redraw()
			await process_frame
		book.save_path = "user://gp144_missing/abilities.jsonl"
		_tap(controls.growth_card_rects[index].get_center())
		if not _check(paused and growth.choosing and growth.checkpoint_snapshot() == before and not ultimate.time_echo_unlocked and ultimate._remaining_s == remaining, "기록 실패·강화/성향/등급/현재시간 미변경"): return false
		book.save_path = ECHO_BOOK
	_tap(controls.growth_card_rects[index].get_center())
	return _check(not paused and ultimate.time_echo_unlocked and growth.ranks.time_echo == 1 and book.snapshot().has("time_echo") and ultimate.gauge == gauge and ultimate._remaining_s == remaining and ultimate.selected_profile == profile and weapons.checkpoint_snapshot() == loadout, "실제 터치·실패 재시도·1초 해금·원본/게이지/타격/대기 유지")

func _test_gates(owned: bool) -> bool:
	for ignored in 128:
		if not _check(not growth._draw_cards().any(func(card: Dictionary) -> bool: return card.id == "time_echo"), "선행 미충족 또는 최대1등급의 여운 후보 제외"): return false
	var before := growth.checkpoint_snapshot()
	var duration := ultimate.duration_for(ultimate.selected_profile)
	growth.choosing = true
	growth.offered_cards = [PrototypeAbilityCodex.profile("time_echo")]
	var rejected := not growth.choose_card(0)
	growth.choosing = false
	growth.offered_cards.clear()
	return _check(rejected and growth.checkpoint_snapshot() == before and ultimate.time_echo_unlocked == owned and ultimate.duration_for(ultimate.selected_profile) == duration, "위조 선행/오래된 중복 카드 확정 거부·시간 비누적")

func _test_cast(candidate: Dictionary, enhanced: bool) -> bool:
	ultimate.finish_stage_effect()
	ultimate.selected_profile.clear()
	if not candidate.is_empty():
		if not _check(ultimate.select_job_ultimate(candidate.job, candidate.id), "원본 직업 필살기 선택"): return false
	var original := ultimate.selected_profile.duplicate(true)
	var base := float(candidate.get("duration", 3.0))
	var duration := base + (1.0 if enhanced else 0.0)
	var projectile := preload("res://scenes/combat/enemy_seed_projectile.tscn").instantiate() as EnemySeedProjectile
	projectile.configure("gp144:slow", Vector2.RIGHT)
	sandbox.add_child(projectile)
	projectile.set_physics_process(false)
	ultimate.gauge = 100
	ultimate.request_ultimate()
	if not _check(ultimate._active and ultimate.gauge == 0 and ultimate._remaining_s == duration and ultimate.selected_profile == original, "실제 필살기 발동·4/6초·원본 프로필 불변"): return false
	if not _check(projectile.enemy_time_scale == float(candidate.get("slow", 0.15)) and Engine.time_scale == 1.0, "적 투사체 감속 비율·전역/플레이어 시간 유지"): return false
	for actor in get_nodes_in_group("enemy_actor"):
		if actor.has_method("enemy_time_scale") and not _check(is_equal_approx(actor.enemy_time_scale(), float(candidate.get("slow", 0.15))), "적 감속 비율 유지"): return false
	var captured: Dictionary = sandbox._capture_run_build()
	if not _check(captured.ultimate.next_duration == duration, "도전 상태 실제 다음 감속시간"): return false
	ultimate._physics_process(base)
	if not _check(ultimate._active == enhanced and is_equal_approx(ultimate._remaining_s, 1.0 if enhanced else 0.0), "원본 종료시각 후 정확히1초 연장"): return false
	if enhanced: ultimate._physics_process(1.0)
	if not _check(not ultimate._active and ultimate._remaining_s == 0.0 and ultimate.selected_profile == original, "정확한 강화시간 종료·원본 비누적"): return false
	if not _check(projectile.enemy_time_scale == 1.0, "강화 종료 후 적 투사체 시간 정상화"): return false
	projectile.free()
	for actor in get_nodes_in_group("enemy_actor"):
		if actor.has_method("enemy_time_scale") and not _check(actor.enemy_time_scale() == 1.0, "강화 종료 후 적 시간 정상화"): return false
	return true

func _test_echo_save() -> bool:
	var saved := store.load_checkpoint()
	for invalid in [2, 0, null, true, "1", 0.5]:
		var bad := saved.duplicate(true)
		bad.growth.ranks.time_echo = invalid
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "여운 등급/타입 변조 거부·정상저장 보호"): return false
	var bad := saved.duplicate(true)
	bad.growth.ranks.erase("time_collector")
	bad.growth.ranks.vitality = int(bad.growth.ranks.get("vitality", 0)) + 1
	bad.player.max_health += 20
	if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "선행 없는 저장은 합계/체력이 정상이어도 거부"): return false
	store.save_path = "user://gp144_missing/checkpoint.json"
	var rejected: bool = sandbox._save_checkpoint(runner.current_metrics()) != OK
	store.save_path = ECHO_SAVE
	return _check(rejected and store.load_checkpoint() == saved and ultimate.time_echo_unlocked and sandbox._save_checkpoint(runner.current_metrics()) == OK, "저장 실패·정상파일/능력 유지·재시도")

func _test_echo_view() -> bool:
	var before: Dictionary = sandbox._capture_run_build()
	var files := _files()
	var definition := PrototypeAbilityCodex.profile("time_echo")
	if not _check(PrototypeAbilityCodex.definitions().size() == 22 and definition.requires == ["time_collector"] and definition.max_rank == 1, "22능력 도감·원본 선행/최대 등급"): return false
	if not _check(controls.open_run_build() and paused, "여운 보유 도전 상태 실제 조회"): return false
	if not await _test_layout(): return false
	_tap(controls.run_build_snapshot().layout.tabs[2].get_center())
	var cards := PrototypeRunBuildView.cards(2, before)
	var job_cards := cards.filter(func(card: Dictionary) -> bool: return card.id == "job")
	if not _check(job_cards.size() == 1 and job_cards[0].lines.has("다음 필살기 감속 %.1f초" % float(before.ultimate.next_duration)), "원본 다음 발동 시간 표시·현재 잔량과 구분"): return false
	if not _check(controls.close_run_build(), "조회 종료"): return false
	controls.advance_mode_timer_for_test(3.1)
	return _check(not paused and sandbox._capture_run_build() == before and _files() == files, "조회/카드 터치/복귀는 강화/시간/실제저장 무변경")

func _files() -> Dictionary:
	var result := {}
	for path in [ECHO_SAVE, ECHO_SAVE + ".bak", ECHO_META, ECHO_RECORD, ECHO_BOOK]:
		result[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return result

func _test_profile_preview() -> bool:
	for job in PrototypeJobProgress.JOBS:
		controls.show_job_manifestation(job, 1.0)
		for candidate in controls.job_ultimates:
			if not _check(candidate.lines[1].begins_with("%.0f초" % (float(candidate.duration) + 1.0)), "발현 전에 얻은 여운은 직업 선택시간에도 표시"): return false
		for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
			controls.size = dimensions
			controls._refresh_job_layout()
			for i in controls.job_ultimates.size():
				var rect: Rect2 = controls.job_ultimate_rects[i]
				for line in controls.job_ultimates[i].lines:
					if not _check(ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x <= rect.size.x, "강화 직업 설명 두 화면비 너비"): return false
			controls.queue_redraw()
			await process_frame
	controls.finish_growth_selection()
	return true

func _test_combat_locks() -> bool:
	ultimate.gauge = 100
	player.damage_receiver.dead = true
	ultimate.request_ultimate()
	if not _check(not ultimate._active and ultimate.gauge == 100, "사망 중 필살기/강화 발동 차단"): return false
	player.damage_receiver.dead = false
	ultimate.selected_profile.clear()
	ultimate.request_ultimate()
	var remaining := ultimate._remaining_s
	ultimate.request_ultimate()
	if not _check(ultimate._active and ultimate._remaining_s == remaining and remaining == 4.0, "발동 중 재입력 연장·중복 소비 없음"): return false
	ultimate.finish_stage_effect()
	return _check(not ultimate._active and ultimate.time_echo_unlocked and ultimate.duration_for({}) == 4.0, "스테이지 효과 종료는 강화 보존·적 감속 해제")
