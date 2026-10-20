extends "res://tests/gp329_runtime_test.gd"

func _ultimate_choice(character: String) -> int:
	return 2 if character == "roan" else 3

func _specializations() -> Array:
	return {
		"dragon_knight": ["dragon_inferno", "dragon_aegis", 0.30, 40, 50],
		"breaker": ["breaker_ruin", "breaker_endure", 0.35, 40, 50],
		"storm_archer": ["storm_tempest", "storm_shelter", 0.30, 40, 50],
		"forest_warden": ["warden_thorns", "warden_bloom", 0.25, 50, 60],
	}[advanced_id]

func _selected_specialization() -> String:
	return String(_specializations()[0 if OS.get_cmdline_user_args()[1] == "roan" else 1])

func _test_additional_cards() -> bool:
	var specs := _specializations()
	for index in 2:
		var card := PrototypeAbilityCodex.profile(String(specs[index]))
		if not _check(growth._card_available(card), "선행 능력 뒤 두 특화 후보: " + String(card.id)): return false
		var required := String(card.requires[0])
		var rank := int(growth.ranks[required])
		growth.ranks.erase(required)
		var blocked := not growth._card_available(card)
		growth.ranks[required] = rank
		if not _check(blocked, "선행 없는 특화 선택 차단"): return false
	var id := _selected_specialization()
	var card := PrototypeAbilityCodex.profile(id)
	var attack := id == String(specs[0])
	var before_bonus := _weapon_bonus()
	var before_max := player.damage_receiver.max_health
	var before_damage: Array[int] = []
	for kind in ["basic", "skill", "ultimate"]:
		before_damage.append(player.growth_damage(100, starting_weapon, kind))
	player.damage_receiver.health = 20
	player.expedition = 2
	var needed := growth.next_level_experience() - growth.experience
	growth.experience += needed
	growth.total_experience += needed
	growth._offer_next_level()
	growth.offered_cards.assign([card])
	sandbox._on_growth_choices_requested(growth.offered_cards, growth.level, growth.rerolls_remaining)
	var record := growth.record_ability
	growth.record_ability = func(_ids: Array) -> Error: return ERR_CANT_CREATE
	var blocked := not growth.choose_card(0)
	growth.record_ability = record
	if not _check(blocked and growth.choosing and not growth.ranks.has(id) and is_equal_approx(_weapon_bonus(), before_bonus) and player.damage_receiver.max_health == before_max and player.damage_receiver.health == 20, "특화 발견 기록 실패 시 선택·수치 보존"): return false
	if not _check(growth.choose_card(0) and not growth.choosing, "같은 특화 선택 재시도 성공"): return false
	player.expedition = 0
	var expected_bonus := before_bonus + (float(specs[2]) if attack else 0.0)
	var expected_max := before_max + (0 if attack else int(specs[3]))
	var expected_health := 20 + (0 if attack else ceili(float(specs[4]) * 0.75))
	if not _check(is_equal_approx(_weapon_bonus(), expected_bonus) and player.damage_receiver.max_health == expected_max and player.damage_receiver.health == expected_health, "공격/생존 특화 실제 수치·회복75% 분리"): return false
	for index in 3:
		var kind: String = ["basic", "skill", "ultimate"][index]
		if not _check(player.growth_damage(100, starting_weapon, kind) == before_damage[index] + (roundi(float(specs[2]) * 100) if attack else 0), "특화 기본·스킬·필살기 피해 반영"): return false
	for index in 2:
		if not _check(not growth._card_available(PrototypeAbilityCodex.profile(String(specs[index]))), "선택한 특화 재선택·반대 특화 차단"): return false
	var codex := PrototypeAbilityCodex.cards(growth.ranks, growth.ranks)
	var own: Array = codex.filter(func(entry: Dictionary) -> bool: return entry.id == id)
	if not _check(own.size() == 1 and own[0].status == "이번 도전 1등급" and own[0].lines[1].ends_with("하나만 선택"), "능력 도감 보유·상호 배제 설명"): return false
	return _test_progress_model()

func _test_progress_model() -> bool:
	var run: Dictionary = controls.movement_metrics.duplicate(true)
	run.growth_job_id = parent_id
	run.growth_run_active = true
	run.run_mode = JourneyRoutePlan.MODE
	run.run_stage_number = 6
	run.growth_ranks = growth.ranks.duplicate(true)
	run.growth_job_contributions = growth.jobs.contributions.duplicate(true)
	var original: Dictionary = run.duplicate(true)
	var progress := PrototypeJobProgress.evolution_progress(advanced_id, run)
	if not _check(not progress.ready and progress.hint == "성향 충족 · 7단계 진입 대기" and progress.stage.contains("현재6단계"), "현재 점수와7단계 대기 표시"): return false
	run.run_stage_number = 7
	if not _check(PrototypeJobProgress.evolution_progress(advanced_id, run).ready, "성향·분기·단계 모두 충족 표시"): return false
	var required := "vanguard_dawn_edge" if parent_id == "vanguard" else "tracker_forest_aim"
	if run.growth_ranks.has(required): run.growth_ranks.erase(required)
	else: run.growth_ranks[required] = 1
	if not _check(not PrototypeJobProgress.evolution_progress(advanced_id, run).ready, "반대 진화 분기 충족으로 오표시 차단"): return false
	run = original.duplicate(true)
	run.growth_job_contributions.ability.clear()
	if not _check(PrototypeJobProgress.evolution_progress(advanced_id, run).hint == "성향 점수를 더 모으세요", "부족한 실제 성향 표시"): return false
	run = original.duplicate(true)
	run.growth_job_id = ""
	if not _check(PrototypeJobProgress.evolution_progress(advanced_id, run).hint.begins_with("먼저 "), "미발현 안내"): return false
	run.growth_job_id = "tracker" if parent_id == "vanguard" else "vanguard"
	if not _check(PrototypeJobProgress.evolution_progress(advanced_id, run).hint == "현재 기본 직업이 다릅니다", "다른 기본 직업 안내"): return false
	run.run_mode = "standard"
	if not _check(PrototypeJobProgress.evolution_progress(advanced_id, run).hint == "전체 여정에서만 진화합니다", "짧은 도전 안내"): return false
	run.growth_job_id = advanced_id
	if not _check(PrototypeJobProgress.evolution_progress(advanced_id, run).hint == "이번 도전에서 진화 완료" and not PrototypeJobProgress.evolution_progress(advanced_id, run).ready, "이미 진화한 도전 재진화 안내 차단"): return false
	var empty := PrototypeJobProgress.evolution_progress(advanced_id, {})
	if not _check(not empty.ready and empty.hint == "새 전체 여정에서 조건을 채우세요" and PrototypeJobProgress.evolution_progress("unknown", {}).is_empty(), "진행 중인 도전 없음·알 수 없는 직업 처리"): return false
	return _check(growth.jobs.job_id == advanced_id and growth.jobs.contributions == original.growth_job_contributions and growth.ranks == original.growth_ranks, "진화 비교는 실제 직업·성향·랭크 불변")

func _validate_additional_save(saved: Dictionary) -> bool:
	var id := _selected_specialization()
	if not _check(saved.growth.ranks.get(id, 0) == 1 and saved.ultimate.profile == festival_ultimate.selected_profile.id, "특화·추가 필살기 저장"): return false
	var card := PrototypeAbilityCodex.profile(id)
	var opposite := PrototypeAbilityCodex.profile(String(card.excludes[0]))
	var bad := saved.duplicate(true)
	# 레벨·랭크 합계·보너스를 맞춰도 상호 배제만으로 거부해야 한다.
	bad.growth.ranks[opposite.id] = 1
	bad.growth.ranks[starting_weapon + "_power"] -= 1
	bad.player[starting_weapon] += float(opposite.job_effect.get("damage", 0.0)) - 0.15
	bad.player.max_health += int(opposite.job_effect.get("health", 0))
	if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "양 특화 동시 보유 변조 거부"): return false
	var required := String(card.requires[0])
	bad = saved.duplicate(true)
	bad.growth.ranks.erase(required)
	bad.growth.ranks[starting_weapon + "_power"] += 1
	if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA, "특화 선행 능력 누락 거부"): return false
	bad = saved.duplicate(true)
	bad.growth.ranks[id] = 2
	if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA, "특화2등급 변조 거부"): return false
	if advanced_id == PrototypeJobProgress.WARDEN_ID:
		bad = saved.duplicate(true)
		bad.growth.ranks.erase("tracker_forest_aim")
		bad.growth.ranks.bow_power += 1
		bad.player.bow -= 0.15
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA, "파수꾼 분기 선행 카드 누락 거부"): return false
	return true

func _test_restored_additions(saved: Dictionary) -> bool:
	var id := _selected_specialization()
	if not _check(growth.ranks.get(id, 0) == 1 and player.damage_receiver.max_health == int(saved.player.max_health) and player.damage_receiver.health == int(saved.player.health) and festival_ultimate.selected_profile.id == saved.ultimate.profile, "별도 프로세스 특화·추가 필살기 복원·회복 미재지급"): return false
	controls.show_main_screen()
	controls.show_village()
	controls.village_page = "jobs"
	_tap(controls.village_snapshot().tabs.advanced_jobs.get_center())
	var meta := FileAccess.get_file_as_string(legacy.save_path)
	var abilities := FileAccess.get_file_as_string(sandbox.ability_discovery_store.save_path)
	for dimensions in [Vector2(1280, 720), Vector2(1600, 720)]:
		controls.size = dimensions
		_tap(controls.village_snapshot().pager.previous.get_center())
		_tap(controls.village_snapshot().pager.previous.get_center())
		if not _check(controls.village_snapshot().advanced_page == 0, "도감 첫 페이지 이전 경계"): return false
		var ids: Array[String] = []
		for page in controls.village_snapshot().advanced_pages:
			var view: Dictionary = controls.village_snapshot()
			if not _check(view.advanced_page == page and view.cards.size() == 2, "직업별 두 장 비교 페이지"): return false
			var safe: Rect2 = controls.layout_snapshot().safe
			for rect in view.layout.cards + view.tabs.values() + view.pager.values():
				if not _check(safe.encloses(rect), "비교 도감·페이지 버튼 두 화면비 안전 영역"): return false
			for entry in view.cards:
				ids.append(String(entry.id))
				if not _check(entry.lines.size() == 10 and entry.lines[6].begins_with("강화:") and entry.lines[8].begins_with("필살기:"), "조건·특화·추가 필살기 설명"): return false
				if entry.id == advanced_id and not _check(entry.progress.hint == "이번 도전에서 진화 완료", "실제 복원 상태의 진화 현황"): return false
			_tap(view.pager.next.get_center())
		if not _check(ids == PrototypeJobProgress.ADVANCED_JOBS.map(func(job: Dictionary) -> String: return job.id) and controls.village_snapshot().advanced_page == controls.village_snapshot().advanced_pages - 1, "네 직업 전체 비교·마지막 페이지 경계"): return false
		_tap(controls.village_snapshot().tabs.jobs.get_center())
		_tap(controls.village_snapshot().tabs.advanced_jobs.get_center())
		if not _check(controls.village_snapshot().advanced_page == 0, "도감 탭 재진입 첫 페이지"): return false
	return _check(FileAccess.get_file_as_string(legacy.save_path) == meta and FileAccess.get_file_as_string(sandbox.ability_discovery_store.save_path) == abilities and store.load_checkpoint() == saved, "비교·페이지·탭 조회 중 파일 불변")
