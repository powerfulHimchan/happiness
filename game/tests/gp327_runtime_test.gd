extends "res://tests/gp307_runtime_test.gd"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var character := args[1]
	var prefix := "user://gp327_" + character + ("_" + phase if phase in ["legacy", "late"] else "_flow")
	store.save_path = prefix + "_checkpoint.json"
	legacy.save_path = prefix + "_meta.jsonl"
	journal.save_path = prefix + "_story.jsonl"
	if phase != "resume":
		store.clear_checkpoint()
		for suffix in ["_meta.jsonl", "_records.jsonl", "_abilities.jsonl", "_story.jsonl"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.story_journal_store = journal
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
	festival_ultimate = sandbox.get_node("Player/UltimateController")
	festival_terrain = sandbox.get_node("RouteTerrain")
	for actor in [player, weapons, weapons.sword_combat, weapons.bow_combat, festival_ultimate, runner, sandbox.get_node("ClockTrapController"), festival_terrain]:
		actor.set_process(false)
		actor.set_physics_process(false)
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	match phase:
		"seed":
			if not _check(controls.begin_retry("sword", 10, "journey", character, false), "전체 여정 시작"): return
			for ignored in 5:
				if not _earn_card("sword_power"): return
			if not _resolve_growth() or not _real_sword_hits(): return
			if not _check(growth.jobs.can_evolve() and growth.jobs.job_id == "vanguard" and not growth.try_evolve_job(), "성향을 미리 채워도 7단계 전 진화 차단"): return
			for number in range(1, 7):
				if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
				if not _check(growth.jobs.job_id == "vanguard", "1~6단계 선봉대 유지"): return
				if number < 6 and not _next_without_layout(): return
			var before_max: int = player.damage_receiver.max_health
			var before_sword: float = player.growth_sword_bonus
			var last_save := store.load_checkpoint()
			festival_ultimate.gauge = 76
			legacy.fail_writes = true
			_tap(controls.stage_route_rects[-1].get_center())
			if not _check(runner.stage_number == 7 and paused and controls.current_screen_mode() == 8 and growth.awaiting_job_confirmation and growth.jobs.job_id == PrototypeJobProgress.DRAGON_ID and player.damage_receiver.max_health == before_max + 20 and is_equal_approx(player.growth_sword_bonus, before_sword + 0.15) and player.job_emblem_id == PrototypeJobProgress.DRAGON_ID, "7단계 진입 자동 진화·1회 패시브·전용 표식·일시정지"): return
			var expected_gauge: int = festival_ultimate.gauge
			if not await _layout_check(): return
			if not _check(not growth.acknowledge_job() and not growth.choose_job_ultimate(-1) and not growth.choose_job_ultimate(2), "기본 필살기는 진화 확정 요건 아님·잘못된 선택 차단"): return
			var choice := 0 if character == "roan" else 1
			_tap(controls.job_ultimate_rects[choice].get_center())
			_tap(controls.job_confirm_rect.get_center())
			if not _check(paused and growth.awaiting_job_confirmation and not legacy.progress_snapshot().jobs.has(PrototypeJobProgress.DRAGON_ID) and store.load_checkpoint() == last_save, "진화 영구 기록 실패 시 확인 보류·정상 저장 유지"): return
			legacy.fail_writes = false
			_tap(controls.job_confirm_rect.get_center())
			if not _check(not paused and not growth.awaiting_job_confirmation and festival_ultimate.gauge == expected_gauge and festival_ultimate.selected_profile.job == PrototypeJobProgress.DRAGON_ID and not growth.try_evolve_job() and not growth.choose_job_ultimate(1 - choice), "재시도 확정·게이지 보존·중복 진화/재선택 차단"): return
			for id in ["dragon_flame", "dragon_heart", "vanguard_edge"]:
				if not _earn_card(id) or not _resolve_growth(): return
			if not _check(not growth._card_available(PrototypeAbilityCodex.profile("dragon_flame")) and not growth._card_available(PrototypeAbilityCodex.profile("dragon_heart")), "상위 능력 1회 제한·기본 능력 계승"): return
			if not _test_ultimate(choice): return
			if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			var saved := store.load_checkpoint()
			if not _check(not saved.is_empty() and saved.growth.job == PrototypeJobProgress.DRAGON_ID and saved.stage.number == 7 and RunCheckpointStore.valid_state(saved), "진화·전용 카드·필살기 중간 저장"): return
			for mutation in ["score", "health", "bonus", "ultimate", "rank"]:
				var bad := saved.duplicate(true)
				match mutation:
					"score": bad.growth.contributions.weapon.clear()
					"health": bad.player.max_health += 20
					"bonus": bad.player.sword += 0.15
					"ultimate": bad.ultimate.profile = "vanguard_strike"
					"rank": bad.growth.ranks.dragon_heart = 2
				if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "변조 거부·정상 저장 보존: " + mutation): return
			var path := store.save_path
			store.save_path = "user://gp327_missing/checkpoint.json"
			if not _check(sandbox._save_checkpoint(runner.current_metrics(), false) != OK, "쓰기 실패 검출"): return
			store.save_path = path
			if not _check(store.load_checkpoint() == saved, "쓰기 실패 후 이전 진화 저장 보존"): return
		"resume":
			var saved := store.load_checkpoint()
			if not _restore_journey(7): return
			if not _check(growth.jobs.job_id == PrototypeJobProgress.DRAGON_ID and player.job_emblem_id == PrototypeJobProgress.DRAGON_ID and is_equal_approx(player.growth_sword_bonus, float(saved.player.sword)) and festival_ultimate.selected_profile.id == saved.ultimate.profile and not growth.awaiting_job_confirmation, "별도 프로세스 진화 복원·보상 중복 없음"): return
			controls.show_main_screen()
			controls.show_village()
			controls.village_page = "jobs"
			_tap(controls.village_snapshot().tabs.advanced_jobs.get_center())
			if not _check(controls.village_page == "advanced_jobs" and controls.village_snapshot().cards[0].status == "진화 · 현재 도전", "도감 탭 터치·영구 발견·현재 진화 표시"): return
			var journal_before := FileAccess.get_file_as_string(legacy.save_path)
			if not await _layout_check(): return
			if not _check(FileAccess.get_file_as_string(legacy.save_path) == journal_before and store.load_checkpoint() == saved, "도감 조회 저장 불변"): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			if not _next_without_layout() or not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			if not _check(store.load_checkpoint().growth.job == PrototypeJobProgress.DRAGON_ID and runner.stage_number == 8, "다음 스테이지 진화·성향·보너스 유지"): return
			recorder.clear_records()
			controls.show_main_screen()
			controls.begin_retry("bow", 3)
			if not _check(growth.jobs.job_id.is_empty() and player.job_emblem_id.is_empty() and player.growth_sword_bonus == 0.0 and player.damage_receiver.max_health == 100 and legacy.progress_snapshot().jobs.has(PrototypeJobProgress.DRAGON_ID), "새 도전 초기화·영구 발견은 독립"): return
		"late":
			controls.begin_retry("sword", 10, "journey", character, false)
			for ignored in 5:
				if not _earn_card("sword_power"): return
			for number in range(1, 7):
				if not _finish_stage() or not sandbox._claim_weapon_reward("") or not _next_without_layout(): return
			if not _check(runner.stage_number == 7 and growth.jobs.job_id == "vanguard" and not growth.try_evolve_job(), "후반에서도 성향 미충족 진화 차단"): return
			festival_ultimate.gauge = 100
			festival_ultimate.request_ultimate()
			var active := festival_ultimate._active_profile.duplicate(true)
			var remaining := festival_ultimate._remaining_s
			if not _real_sword_hits(): return
			if not _check(growth.awaiting_job_confirmation and paused and growth.jobs.job_id == PrototypeJobProgress.DRAGON_ID and festival_ultimate._active_profile == active and festival_ultimate._remaining_s == remaining, "후반 실제 적중 자동 진화·사용 중 필살기/타이머 보존"): return
			_tap(controls.job_ultimate_rects[1].get_center())
			_tap(controls.job_confirm_rect.get_center())
			if not _check(not paused and festival_ultimate.selected_profile.id == "dragon_guard" and festival_ultimate._active_profile == active and festival_ultimate._remaining_s == remaining, "확정 뒤 기존 효과 자연 종료·다음 발동만 교체"): return
			festival_ultimate._physics_process(remaining + 0.1)
			if not _check(not festival_ultimate._active and festival_ultimate.selected_profile.id == "dragon_guard", "기존 필살기 자연 종료 후 새 선택 유지"): return
			var profile: Dictionary = PrototypeAbilityCodex.profile("dragon_heart")
			player.expedition = 2
			player.damage_receiver.health = 20
			var before: int = player.damage_receiver.max_health
			if not _earn_card("dragon_heart"): return
			if not _check(player.damage_receiver.max_health == before + 30 and player.damage_receiver.health == 43, "상위 카드 최대체력 증가와 실제 회복75% 분리"): return
		"legacy":
			controls.begin_retry("sword", 3)
			for ignored in 5:
				if not _earn_card("sword_power"): return
			if not _resolve_growth() or not _real_sword_hits(): return
			if not _check(not growth.try_evolve_job() and growth.jobs.job_id == "vanguard", "기존 짧은 도전은 진화 비소급"): return
			if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			var saved := store.load_checkpoint()
			controls.show_main_screen()
			if not _check(not saved.is_empty() and saved.growth.job == "vanguard" and sandbox.continue_saved_run() and growth.jobs.job_id == "vanguard", "추가 필드 없는 이전 직업 저장 호환"): return
			if not _check(not growth._card_available(PrototypeAbilityCodex.profile("dragon_flame")), "미진화 상위 카드 차단"): return
			var probe := PrototypeJobProgress.new()
			probe.reset("bow")
			probe.job_id = "tracker"
			probe.contributions = growth.jobs.contributions.duplicate(true)
			if not _check(not probe.can_evolve(), "추적자와 미발현은 용염기사 진화 불가"): return
	paused = false
	sandbox.free()
	print("GP-327 runtime test: OK (%s %s)" % [phase, character])
	quit(0)

func _earn_card(id: String) -> bool:
	var card := PrototypeAbilityCodex.profile(id)
	if not _check(growth._card_available(card), "실제 선택 조건: " + id): return false
	var needed := growth.next_level_experience() - growth.experience
	growth.experience += needed
	growth.total_experience += needed
	growth._offer_next_level()
	growth.offered_cards.assign([card])
	sandbox._on_growth_choices_requested(growth.offered_cards, growth.level, growth.rerolls_remaining)
	if not _check(growth.choose_card(0), "실제 카드 선택: " + id): return false
	return _resolve_growth()

func _real_sword_hits() -> bool:
	var target := sandbox.get_node("Targets/LeafSlime") as PrototypeTarget
	target.visible = true
	target.set_process(false)
	target.set_physics_process(false)
	var original := target.damage_receiver.max_health
	target.damage_receiver.max_health = 10000
	target.damage_receiver.reset()
	for hit in 80:
		weapons.sword_combat._action_sequence += 1
		if not _check(weapons.sword_combat._damage_target(target, &"sword_basic", 1, 0.0, PackedStringArray(["sword"]), hit) == DamageReceiver.Result.APPLIED, "실제 검 적중 성향 누적"): return false
	target.damage_receiver.max_health = original
	target.reset_target()
	return true

func _test_ultimate(choice: int) -> bool:
	var target := sandbox.get_node("Targets/LeafSlime") as PrototypeTarget
	var original := target.damage_receiver.max_health
	target.visible = true
	target.set_process(false)
	target.set_physics_process(false)
	target.damage_receiver.max_health = 1000
	target.damage_receiver.reset()
	target.global_position = player.global_position + Vector2(100, 0)
	var before := player.damage_receiver.health
	player.damage_receiver.health = 20
	festival_ultimate.gauge = 100
	festival_ultimate.request_ultimate()
	var profile: Dictionary = festival_ultimate.selected_profile
	if not _check(festival_ultimate._active and festival_ultimate.gauge == 0 and target.damage_receiver.health == 1000 - player.growth_damage(int(profile.damage), "sword", "ultimate") and player.damage_receiver.health == (20 if choice == 0 else 70), "상위 필살기 실제 피해·회복·게이지"): return false
	festival_ultimate.finish_stage_effect()
	target.damage_receiver.max_health = original
	target.reset_target()
	player.damage_receiver.health = before
	return true

func _layout_check() -> bool:
	for dimensions in [Vector2(1280, 720), Vector2(1600, 720)]:
		controls.size = dimensions
		controls._refresh_job_layout()
		var safe: Rect2 = controls.layout_snapshot().safe
		if controls.current_screen_mode() == 8:
			if not _check(safe.encloses(controls.job_panel_rect) and controls.job_panel_rect.encloses(controls.job_confirm_rect) and controls.job_ultimate_rects.size() == 2 and not controls.job_ultimate_rects[0].intersects(controls.job_ultimate_rects[1]), "진화 확인 두 화면비 안전 영역"): return false
		else:
			var view: Dictionary = controls.village_snapshot()
			for rect in view.layout.cards + view.tabs.values():
				if not _check(safe.encloses(rect), "상위 도감 두 화면비 안전 영역"): return false
		controls.queue_redraw()
		await process_frame
	return true
