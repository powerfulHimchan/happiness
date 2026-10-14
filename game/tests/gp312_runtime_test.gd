extends "res://tests/gp311_runtime_test.gd"

func _run() -> void:
	auto_guardian_choice = false
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var character := args[1]
	var weapon := args[2]
	var choice := args[3]
	var prefix := "user://gp312_%s_%s_%s_%s" % ["flow" if phase in ["seed", "resume", "selected", "finish"] else phase, character, weapon, choice]
	store.save_path = prefix + "_checkpoint.json"
	legacy.save_path = prefix + "_meta.jsonl"
	journal.save_path = prefix + "_story.jsonl"
	if phase not in ["resume", "selected", "finish"]:
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
	growth.jobs_enabled = false
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	match phase:
		"seed":
			if not _prepare_guardian_choice(character, weapon): return
			player.damage_receiver.health = 45
			player.damage_receiver.barrier_health = 7
			festival_ultimate.gauge = 88
			if not _check(player.barrier_unlocked and player.fortified_barrier_unlocked and sandbox._save_checkpoint(runner.current_metrics()) == OK, "실제 성장 방벽·잔량과 미선택 저장"): return
		"resume":
			if not _restore_journey(9) or not _check(controls.current_screen_mode() == 18 and runner.awaiting_guardian_choice() and not sandbox._resolve_guardian_choice(choice) and not sandbox._claim_weapon_reward(weapon), "선택 전 장면 대기 복원·우회 입력 차단"): return
			if not _ack_scene(true): return
			if not _select_choice(choice): return
		"selected":
			if not _restore_journey(9) or not _check(runner.guardian_choice == choice and player.guardian_choice == choice and not runner.awaiting_guardian_choice() and controls.current_screen_mode() == 11, "선택 확정 뒤 별도 프로세스·같은 보상 화면 반복 복원"): return
			var saved := store.load_checkpoint()
			var expected_health := mini(player.damage_receiver.max_health, 45 + ceili(player.damage_receiver.max_health * 0.20)) if choice == "rescue" else 45
			if not _check(player.damage_receiver.health == expected_health and player.damage_receiver.barrier_health == (27 if choice == "rescue" else 7) and festival_ultimate.gauge == (100 if choice == "rescue" else 88), "구출 보충은 저장된 잔량 그대로·중복 지급 없음"): return
			if not _check(not sandbox._resolve_guardian_choice(choice) and store.load_checkpoint() == saved, "확정 선택 재호출·재보상 차단"): return
			if not sandbox._claim_weapon_reward("") or not _next_without_layout(): return
			if not _check(runner.stage_number == 10 and player.guardian_choice == choice and runner.guardian_choice == choice, "선택을 유지하고 중심부 진입"): return
			if not _check_guardian_info(choice) or not _finish_stage(): return
		"finish":
			if not _restore_journey(10) or not _ack_scene(false): return
			if not _check(controls.boss_choice_profile.is_empty() and runner.guardian_choice == choice and controls.current_screen_mode() == 12, "마지막 태엽 기사 선택 화면·성문 선택과 독립"): return
			var final_choice := "destroy" if choice == "rescue" else "rescue"
			if not sandbox._resolve_boss_choice(final_choice): return
			var result: Dictionary = controls.current_result_snapshot()
			var recent: Dictionary = recorder.summary_snapshot().recent_runs[0]
			if not _check(result.guardian_choice == choice and result.boss_choice == final_choice and recent.guardian_choice == choice and recent.boss_choice == final_choice and legacy.pending_reward().choice == final_choice and player.guardian_choice.is_empty() and store.load_checkpoint().is_empty(), "결과·이력에 두 선택 독립 기록·최종 보상·효과/저장 정리"): return
			controls.show_main_screen()
			controls.show_village()
			controls.village_page = "history"
			if not _check(controls.village_snapshot().cards[0].lines.any(func(line: String) -> bool: return line.contains("수호기사 " + GuardianDecision.label(choice))), "실제 광장 이력에 성문 선택 표시"): return
			controls.begin_retry(weapon, 3)
			if not _check(player.guardian_choice.is_empty() and runner.guardian_choice.is_empty(), "새 도전에서 성문 효과 초기화"): return
		"fault":
			if not _prepare_guardian_choice(character, weapon) or not _ack_scene(true): return
			player.damage_receiver.health = 45
			player.damage_receiver.barrier_health = 7
			festival_ultimate.gauge = 88
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "실패 전 정상 저장"): return
			var saved := store.load_checkpoint()
			var path := store.save_path
			store.save_path = "user://gp312_missing/checkpoint.json"
			if not _check(not sandbox._resolve_guardian_choice(choice) and runner.guardian_choice.is_empty() and player.guardian_choice.is_empty() and player.damage_receiver.health == 45 and player.damage_receiver.barrier_health == 7 and festival_ultimate.gauge == 88 and controls.current_screen_mode() == 12, "실패 시 선택·체력·방벽·게이지 모두 되돌림"): return
			store.save_path = path
			if not _check(store.load_checkpoint() == saved and sandbox._resolve_guardian_choice(choice), "기존 저장 보존·재시도 성공"): return
		"legacy":
			if not _prepare_guardian_choice(character, weapon): return
			var old := store.load_checkpoint()
			old.stage.erase("guardian_choice")
			old.stage.history[8].erase("guardian_choice")
			if not _check(RunCheckpointStore.valid_state(old) and store.save_checkpoint(old) == OK, "이전 버전1 성문 저장 호환"): return
			if not _restore_journey(9) or not _ack_scene(true): return
			if not _check(runner.guardian_choice == GuardianDecision.LEGACY and player.guardian_choice == GuardianDecision.LEGACY and controls.current_screen_mode() == 11, "이전 성문 완료는 강제 재선택·추가 보상 없이 진행"): return
			if not sandbox._claim_weapon_reward("") or not _next_without_layout() or not _finish_stage(): return
			old = store.load_checkpoint()
			old.stage.erase("guardian_choice")
			old.stage.history[8].erase("guardian_choice")
			if not _check(store.save_checkpoint(old) == OK, "이전 중심부 완료 저장 호환"): return
			if not _restore_journey(10) or not _ack_scene(true) or not sandbox._resolve_boss_choice("rescue"): return
		"validate":
			if not _prepare_guardian_choice(character, weapon): return
			var saved := store.load_checkpoint()
			for bad_value in [null, 7, true, "other", [], {}]:
				var bad := saved.duplicate(true)
				bad.stage.guardian_choice = bad_value
				if not _check(not RunCheckpointStore.valid_state(bad) and store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "선택 타입/값 변조 거부·정상 저장 보존"): return
			var bad := saved.duplicate(true)
			bad.stage.history[8].guardian_choice = "destroy"
			if not _check(not RunCheckpointStore.valid_state(bad), "선택과 성문 이력 불일치 거부"): return
			bad = saved.duplicate(true)
			bad.stage.history[0].guardian_choice = "rescue"
			if not _check(not RunCheckpointStore.valid_state(bad), "성문 외 이력에 선택 필드 거부"): return
			bad = saved.duplicate(true)
			bad.stage.reward_claimed = true
			if not _check(not RunCheckpointStore.valid_state(bad), "미선택 보상 완료 변조 거부"): return
			if not _ack_scene(true) or not sandbox._resolve_guardian_choice(choice) or not sandbox._claim_weapon_reward("") or not _next_without_layout() or not _finish_stage(): return
			bad = store.load_checkpoint()
			bad.stage.guardian_choice = ""
			bad.stage.history[8].guardian_choice = ""
			if not _check(not RunCheckpointStore.valid_state(bad), "미선택 중심부 완료 저장 거부"): return
		"effects":
			if not _prepare_guardian_choice(character, weapon) or not _ack_scene(true) or not sandbox._resolve_guardian_choice(choice) or not sandbox._claim_weapon_reward("") or not _next_without_layout() or not _reach_journey_elite(): return
			if not await _guardian_effects(choice, weapon): return
		"flows":
			if not _prepare_guardian_choice(character, weapon) or not _ack_scene(true): return
			var saved := store.load_checkpoint()
			controls.open_run_build()
			if not _check(controls.current_screen_mode() == 12 and paused and store.load_checkpoint() == saved, "선택 중 조회 전환으로 진행 우회 불가"): return
			sandbox._continue_stage("city_core")
			if not _check(runner.stage_number == 9 and runner.awaiting_guardian_choice() and not runner.has_next_stage() and runner.available_routes().is_empty() and not runner.next_stage("city_core") and not sandbox._claim_weapon_reward(weapon), "미선택 다음 구간·보상 직접 호출 차단"): return
			for dimensions in [Vector2(1280, 720), Vector2(1600, 720)]:
				controls.size = dimensions
				controls.show_boss_choice(GuardianDecision.PROFILE)
				for ignored in 2: await process_frame
				var safe: Rect2 = controls.layout_snapshot().safe
				if not _check(controls.boss_choice_rects.all(func(rect: Rect2) -> bool: return safe.encloses(rect)) and safe.encloses(controls.boss_choice_confirm_rect) and not controls.boss_choice_rects[0].intersects(controls.boss_choice_rects[1]) and controls.selected_boss_choice == -1, "두 화면비 선택/확정 안전 영역·비중첩·초기 선택 없음"): return
			controls.size = Vector2(1280, 720)
			if not _select_choice(choice) or not sandbox._claim_weapon_reward("") or not _next_without_layout() or not _check_guardian_info(choice): return
		_:
			_check(false, "알 수 없는 선택 검사")
			return
	paused = false
	sandbox.free()
	print("GP-312 runtime test: OK (%s %s %s %s)" % [phase, character, weapon, choice])
	quit(0)

func _prepare_guardian_choice(character: String, weapon: String) -> bool:
	if not _start_gate(character, weapon) or not _finish_stage(): return false
	return _check(runner.awaiting_guardian_choice() and controls.current_screen_mode() == 18 and store.load_checkpoint().stage.guardian_choice == "" and not runner.reward_claimed, "성문 처치→이야기→구출/파괴 대기")

func _resolve_growth() -> bool:
	if growth.choosing:
		for id in ["magic_barrier", "fortified_barrier"]:
			for card in PrototypeGrowthController.CARDS:
				if card.id == id and growth._card_available(card):
					growth.offered_cards[0] = card.duplicate(true)
					controls.show_growth_choices(growth.offered_cards, growth.level, growth.rerolls_remaining)
					return super._resolve_growth()
	return super._resolve_growth()

func _select_choice(choice: String) -> bool:
	var health := player.damage_receiver.health
	var barrier := player.damage_receiver.barrier_health
	var gauge := festival_ultimate.gauge
	var saved := store.load_checkpoint()
	if not _check(controls.current_screen_mode() == 12 and paused and controls.boss_choice_profile == GuardianDecision.PROFILE and controls.selected_boss_choice == -1, "수호기사 전용 설명·일시 정지·미선택"): return false
	_tap(controls.boss_choice_rects[0 if choice == "rescue" else 1].get_center())
	if not _check(player.damage_receiver.health == health and player.damage_receiver.barrier_health == barrier and festival_ultimate.gauge == gauge and store.load_checkpoint() == saved, "카드 비교 입력은 보상·파일 불변"): return false
	_tap(controls.boss_choice_confirm_rect.get_center())
	return _check(runner.guardian_choice == choice and player.guardian_choice == choice and store.load_checkpoint().stage.history[8].guardian_choice == choice and controls.current_screen_mode() == 11 and not recorder._active_run_completed and runner.stage_complete and not runner.current_metrics().run_complete, "실제 확정→선택 저장→다음 보상·여정 미완료")

func _check_guardian_info(choice: String) -> bool:
	var saved := store.load_checkpoint()
	controls.open_run_build()
	var cards: Array = PrototypeRunBuildView.cards(2, sandbox._capture_run_build())
	var found := cards.filter(func(card: Dictionary) -> bool: return card.id == "guardian")
	if not _check(paused and found.size() == 1 and found[0].status == GuardianDecision.label(choice) and store.load_checkpoint() == saved, "현재 도전에서 실제 선택·효과 조회·저장 불변"): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(3.1)
	return _check(not paused, "선택 정보 조회 후 전투 복귀")

func _guardian_effects(choice: String, weapon: String) -> bool:
	var guard_multiplier := 1.10 if choice == "destroy" else 1.0
	for kind in ["basic", "skill", "ultimate"]:
		player.guardian_choice = ""
		var base := player.growth_damage(10000, weapon, kind)
		player.guardian_choice = choice
		if not _check(player.growth_damage(10000, weapon, kind) == roundi(base * guard_multiplier), "검·활·공격 필살기 성문 배율"): return false
	var boss := runner.boss
	boss.set_process(false)
	player.prepare_next_stage(Vector2(boss.position.x - 100, 780))
	var camera := player.get_node("Camera2D") as Camera2D
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	for ignored in 2: await process_frame
	var selector := player.get_node("AutoTargetSelector") as AutoTargetSelector
	selector.force_scan()
	var before := boss.damage_receiver.health
	if weapon == "sword":
		weapons.sword_combat._basic_remaining_s = 0
		weapons.sword_combat.combo_index = 0
		weapons.sword_combat._update_basic_attack(0.1)
	else:
		weapons.bow_combat._basic_remaining_s = 0
		weapons.bow_combat._update_basic_attack()
		for ignored in 40:
			await physics_frame
			if boss.damage_receiver.health < before: break
	if not _check(boss.damage_receiver.health < before and boss.last_adjusted_damage > 0, "실제 중심부 검 타격/활 충돌에 선택 적용"): return false
	player.relic_state = {}
	player.boss_legacy = {}
	player.survival_instinct_unlocked = false
	player.damage_receiver.max_health = 500
	player.damage_receiver.health = 500
	player.damage_receiver.barrier_health = 20
	player.damage_receiver.tick(2)
	player.prepare_next_stage(player.position)
	var event := DamageEvent.new()
	event.event_id = &"gp312:incoming"
	event.attacker_id = &"test"
	event.damage = 100
	event.tags = PackedStringArray(["enemy"])
	var first := player.receive_damage(event)
	var second := player.receive_damage(event)
	if not _check(first == DamageReceiver.Result.APPLIED and second == DamageReceiver.Result.DUPLICATE_BLOCKED and player.damage_receiver.health == 500 - roundi(100 * guard_multiplier) + 20 and event.damage == 100, "전투 피격 배율→방벽→체력·중복 차단·원본 보존"): return false
	player.damage_receiver.tick(2)
	player.invincible = true
	event.event_id = &"gp312:evade"
	var health := player.damage_receiver.health
	if not _check(player.receive_damage(event) == DamageReceiver.Result.INVULNERABLE_BLOCKED and player.damage_receiver.health == health, "성문 파괴 보정도 무적 유지"): return false
	return true

func _check(condition: bool, label: String) -> bool:
	if condition: return true
	push_error("GP-312 실패: " + label)
	paused = false
	quit(1)
	return false
