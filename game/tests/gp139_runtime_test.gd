extends "res://tests/gp138_runtime_test.gd"

const GP139_SAVE := "user://gp139_checkpoint.json"
const GP139_META := "user://gp139_meta.jsonl"
const GP139_RECORD := "user://gp139_records.jsonl"
const GP139_BOOK := "user://gp139_abilities.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP139_SAVE
	legacy.save_path = GP139_META
	book.save_path = GP139_BOOK
	if phase in ["seed", "flows"]:
		store.clear_checkpoint()
		for path in [GP139_META, GP139_RECORD, GP139_BOOK]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if phase == "seed" and not _check(legacy.grant("gp139-helper-source", "rescue") == OK, "다섯 단계 조력 준비"): return
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.ability_discovery_store = book
	sandbox.get_node("LocalTestRecorder").record_path = GP139_RECORD
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	growth.jobs_enabled = phase == "flows"
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
			if not await _test_length_preview(): return
			if not _start_length(5, "sword"): return
			if not _check(runner.stage_limit == 5 and player.boss_legacy.choice == "rescue" and legacy.pending_reward().is_empty(), "실제5단계 확정에서만 조력 소비"): return
			if not _choose_time_card(): return
			for number in [1, 2, 3]:
				if not _check(runner.stage_number == number and not runner.uses_boss() and runner.final_enemy() == runner.armored_boar, "1·2·3단계는 정예"): return
				if not _finish_stage() or not _check(controls.current_screen_mode() == 11 and growth.run_active and not runner.current_metrics().run_complete and not sandbox._resolve_boss_choice("rescue"), "3단계도 무기 보상·조기 완료/보스 확정 차단"): return
				if not _check(store.load_checkpoint().stage.number == number and not store.load_checkpoint().stage.reward_claimed, "유물을 가진3단계도 무기 선택 전 자동 저장"): return
				if number == 3:
					var before := store.load_checkpoint()
					var equipment := weapons.equipment.duplicate()
					store.save_path = "user://gp139_missing/checkpoint.json"
					if not _check(not sandbox._claim_weapon_reward("sword") and not runner.reward_claimed and weapons.equipment == equipment, "3단계 영웅 무기 저장 실패 롤백"): return
					store.save_path = GP139_SAVE
					if not _check(store.load_checkpoint() == before, "정상 중간 저장 보호"): return
				if not _check(sandbox._claim_weapon_reward("bow" if number == 2 else "sword") and not sandbox._claim_weapon_reward("bow"), "정예마다 실제 무기 보상·중복 확정 차단"): return
				if number == 2:
					_tap(controls.relic_reward_open_rect.get_center())
					if not _check(sandbox._claim_relic_reward(PrototypeRelic.CLOCK_ID), "두 번째 정예 유물 유지"): return
				if number < 3: _tap(controls.stage_route_rects[0].get_center())
			ultimate.gauge = 37
			weapons.sword_combat._skill_1_cooldown_s = 3.25
			ultimate.force_emit_metrics()
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "3/5 완료·능력/유물/게이지/대기 저장"): return
			var saved := store.load_checkpoint()
			if not _check(saved.stage.number == 3 and saved.stage.limit == 5 and saved.stage.history.size() == 3 and not saved.stage.history[-1].has("boss_choice") and saved.growth.ranks.time_collector == 1 and saved.ultimate.gauge == 37 and PackedInt32Array(saved.boss_legacy.assisted_stages) == PackedInt32Array([1, 2, 3]) and recorder.summary_snapshot().completed_run_count == 0, "보스 아닌3/5 저장·세 조력·완주 집계 없음"): return
			if not _test_invalid_lengths(saved): return
		"resume":
			controls.selected_stage_limit = 3
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and runner.stage_limit == 5 and runner.stage_number == 3 and ultimate.gauge == 37 and player.relic_state.id == PrototypeRelic.CLOCK_ID and is_equal_approx(weapons.sword_combat._skill_1_cooldown_s, 3.25) and growth.ranks.time_collector == 1 and player.boss_legacy.assisted_stages == [1, 2, 3], "별도 프로세스3/5 반복 이어하기·준비 선택3과 독립"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _check(runner.stage_number == 4 and ultimate.gauge == 62 and not runner.uses_boss(), "4/5 바람 실제 진입·게이지25·정예"): return
			if not _reach_final() or not _check(runner.armored_boar.damage_receiver.health == runner.armored_boar.damage_receiver.max_health - 20 and player.boss_legacy.assisted_stages == [1, 2, 3, 4], "4단계 실전 조력20·기존 세 사용 유지"): return
			var health := runner.armored_boar.damage_receiver.health
			runner.force_emit_metrics()
			if not _check(runner.armored_boar.damage_receiver.health == health and not legacy.spend_assist(player.boss_legacy, 6), "같은 정예 중복 조력·범위 밖6 차단"): return
			if not _finish_stage(): return
			if not _check(sandbox._claim_weapon_reward("bow"), "4단계 실제 무기 보상 확정"): return
			if not _check(controls.cleared_stage == 4 and controls.run_stage_count == 5 and weapons.equipment.bow == 2 and not controls.relic_offer_available, "4단계 정예 보상·영웅 상한·유물 재지급 없음"): return
			ultimate.gauge = 0
			ultimate.force_emit_metrics()
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK and store.load_checkpoint().stage.number == 4 and store.load_checkpoint().ultimate.gauge == 0, "4/5와 소진0 실제 저장"): return
		"boss":
			if not _check(sandbox.continue_saved_run() and runner.stage_number == 4 and runner.stage_limit == 5 and ultimate.gauge == 0 and player.boss_legacy.assisted_stages == [1, 2, 3, 4], "4/5 별도 재시작·최신 조력·0 보존"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _reach_final() or not _check(runner.uses_boss() and runner.stage_number == 5 and runner.final_enemy() == runner.boss and runner.boss.damage_receiver.max_health == 720 and runner.boss.damage_receiver.health == 700 and not runner.armored_boar.visible and controls.movement_metrics.run_stage_count == 5, "5/5 실제720 보스·다섯 번째 조력20·HUD"): return
			var event := _event("gp139-half-boss", 340)
			event.attacker_id = &"player"
			if not _check(runner.boss.receive_damage(event) == DamageReceiver.Result.APPLIED and runner.boss.damage_receiver.health == 360 and runner.boss.phase == 2, "720 보스 절반360에서 실제2페이즈"): return
			if not _finish_stage(): return
			var saved := store.load_checkpoint()
			if not _check(paused and runner.awaiting_boss_choice() and saved.stage.number == 5 and saved.stage.limit == 5 and saved.stage.history.size() == 5 and saved.stage.history[-1].boss_choice == "" and PackedInt32Array(saved.boss_legacy.assisted_stages) == PackedInt32Array([1, 2, 3, 4, 5]) and growth.total_experience == 400 and recorder.summary_snapshot().completed_run_count == 0, "5단계 승리 선택 대기 저장·400경험치·완주 미집계"): return
			if not _test_invalid_lengths(saved): return
			var bad := saved.duplicate(true)
			bad.stage.history[2].boss_choice = ""
			if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "5단계 도전의3단계 보스 기록 혼입 거부"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and runner.awaiting_boss_choice() and runner.stage_limit == 5 and player.boss_legacy.assisted_stages == [1, 2, 3, 4, 5], "별도 프로세스5/5 선택 대기·다섯 조력 재사용 없음"): return
			_tap(controls.boss_choice_rects[0].get_center())
			store.save_path = "user://gp139_missing/checkpoint.json"
			_tap(controls.boss_choice_confirm_rect.get_center())
			if not _check(runner.boss_choice == "" and runner.awaiting_boss_choice() and recorder.summary_snapshot().completed_run_count == 0, "5단계 선택 저장 실패·중복 완주 없음"): return
			store.save_path = GP139_SAVE
			_tap(controls.boss_choice_confirm_rect.get_center())
			var summary: Dictionary = recorder.summary_snapshot()
			if not _check(controls.current_screen_mode() == 1 and not growth.run_active and controls.current_result_snapshot().stage_count == 5 and controls.current_result_snapshot().target_s == 900 and summary.completed_run_count == 1 and summary.completion_by_stage_count["5"].completed_run_count == 1 and store.load_checkpoint().is_empty(), "5단계 결과·15분 목표·길이별 완주/최고 기록"): return
			if not _check(not sandbox._resolve_boss_choice("destroy") and recorder.summary_snapshot().completed_run_count == 1, "중복 결과·선택 변경 차단"): return
			if not _start_length(3, "bow", false) or not _check(runner.stage_limit == 3 and growth.level == 1 and not growth.ranks.has("time_collector") and ultimate.gauge == 0 and player.relic_state.is_empty() and weapons.equipment == {"sword": 0, "bow": 0}, "실제3단계 새 도전·긴 도전 능력/장비/유물/게이지 초기화"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward("") and store.load_checkpoint().stage.limit == 3, "기존3단계 저장 준비"): return
		"legacy":
			controls.selected_stage_limit = 5
			if not _check(sandbox.continue_saved_run() and runner.stage_limit == 3 and runner.stage_number == 1, "5단계 준비 선택과 기존3단계 이어하기 독립"): return
			var saved := store.load_checkpoint()
			if not await _test_length_preview(): return
			if not _check(store.load_checkpoint() == saved and runner.stage_limit == 3, "준비·취소는 저장 길이/기존 도전 변경 없음"): return
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run(), "기존 도전 다시 복귀"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "기존 두 번째 정예"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _reach_final() or not _check(runner.uses_boss() and runner.stage_number == 3 and runner.boss.damage_receiver.max_health == 480, "기존3/3 보스480 유지"): return
			if not _finish_stage(): return
			saved = store.load_checkpoint()
			var bad := saved.duplicate(true)
			bad.stage.limit = 5
			if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "기존 보스 대기를5단계 중간으로 변조 거부"): return
			if not _check(sandbox._resolve_boss_choice("rescue") and recorder.summary_snapshot().completion_by_stage_count["3"].completed_run_count == 1 and recorder.summary_snapshot().completion_by_stage_count["5"].completed_run_count == 1, "기존3단계 실제 완주·3/5 기록 분리"): return
		"flows":
			if not await _test_long_flows(): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-139 runtime test: OK (" + phase + ")")
	quit(0)

func _start_length(count: int, weapon: String, enabled: bool = true) -> bool:
	sandbox._finish_growth_selection()
	controls.show_main_screen()
	controls.show_start_weapon_selection()
	_tap(controls.start_length_rects[0 if count == 3 else 1].get_center())
	_tap(controls.start_weapon_card_rects[0 if weapon == "sword" else 1].get_center())
	controls.use_boss_legacy = enabled
	_tap(controls.start_weapon_confirm_rect.get_center())
	return _check(growth.run_active and runner.stage_number == 1 and runner.stage_limit == count and weapons.active_weapon_id == weapon, "실제 터치로3/5 길이와 검/활 시작")

func _choose_time_card() -> bool:
	var chosen := -1
	for candidate in 256:
		growth.rng.seed = candidate
		for card in growth._draw_cards():
			if card.id == "time_collector": chosen = candidate
		if chosen >= 0: break
	growth.rng.seed = chosen
	player.global_position.x = 1240
	runner._process(0.1)
	for target in runner._active_enemies.duplicate(): _defeat(target)
	for index in growth.offered_cards.size():
		if growth.offered_cards[index].id == "time_collector":
			_tap(controls.growth_card_rects[index].get_center())
			return _check(growth.ranks.get("time_collector", 0) == 1, "긴 도전에서 실제 시간 수집 획득")
	return _check(false, "시간 수집 후보")

func _reach_final() -> bool:
	for ignored in 10:
		if runner.current_section == PrototypeStageRunner.Section.ELITE: return true
		if not _step_section(): return false
	return _check(false, "마지막 정예 구간 도달")

func _test_invalid_lengths(saved: Dictionary) -> bool:
	for value in [null, true, "5", [], {}, 1, 2, 4, 6, 3.5]:
		var bad := saved.duplicate(true)
		bad.stage.limit = value
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "지원하지 않는 길이/타입/소수 거부·정상 파일 보호"): return false
	return true

func _test_length_preview() -> bool:
	sandbox._finish_growth_selection()
	controls.show_main_screen()
	var old_count: int = controls.selected_stage_limit
	var saved := store.load_checkpoint()
	var run := runner.checkpoint_snapshot()
	var pending := legacy.pending_reward()
	var equipment := weapons.checkpoint_snapshot()
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls.show_start_weapon_selection()
		controls.queue_redraw()
		await process_frame
		var rects: Array = controls.start_length_rects.duplicate()
		rects.append_array(controls.start_weapon_card_rects)
		rects.append_array(controls.memory_card_rects)
		rects.append_array([controls.boss_legacy_toggle_rect, controls.start_weapon_confirm_rect, controls.start_weapon_cancel_rect])
		var safe: Rect2 = controls.layout_snapshot().safe
		for i in rects.size():
			if not _check(safe.encloses(rects[i]), "두 화면비 길이/무기/기억/보상/확정/취소 안전 영역"): return false
			for j in range(i + 1, rects.size()):
				if not _check(not rects[i].intersects(rects[j]), "모든 선택 터치 영역 비중첩"): return false
		for index in 2:
			_tap(controls.start_length_rects[index].get_center())
			if not _check(controls.selected_stage_limit == (3 if index == 0 else 5) and runner.checkpoint_snapshot() == run and store.load_checkpoint() == saved and legacy.pending_reward() == pending and weapons.checkpoint_snapshot() == equipment, "길이 미리 선택은 실제 도전/저장/보상/장비 변경 없음"): return false
		controls.notification(Control.NOTIFICATION_APPLICATION_PAUSED)
		controls.notification(Control.NOTIFICATION_APPLICATION_RESUMED)
		if not _check(controls.selected_stage_limit == 5 and controls.command_buffer.pending_count() == 0, "준비 중 앱 복귀 길이 유지·이동 입력 해제"): return false
		_tap(controls.start_weapon_cancel_rect.get_center())
		if not _check(controls.selected_stage_limit == old_count and runner.checkpoint_snapshot() == run and store.load_checkpoint() == saved and legacy.pending_reward() == pending, "취소는 이전 길이/진행/저장/보상 보존"): return false
	for count in [1, 2, 4, 6]:
		if not _check(not controls.begin_retry("sword", count) and runner.checkpoint_snapshot() == run and store.load_checkpoint() == saved, "잘못된 길이 새 도전·저장 삭제 차단"): return false
	return true

func _test_long_flows() -> bool:
	for weapon in ["sword", "bow"]:
		if not _check(legacy.grant("gp139-flow-" + weapon, "rescue" if weapon == "sword" else "destroy") == OK, "긴 검/활 일회 보상 준비"): return false
		sandbox._update_boss_legacy_status()
		if not _start_length(5, weapon): return false
		for ignored in 100: growth.jobs.add_weapon_hit(weapon)
		for number in range(1, 6):
			if not _check(runner.stage_number == number and runner.uses_boss() == (number == 5), "검/활 5단계 마지막만 보스"): return false
			if not _finish_stage(): return false
			if number == 5: break
			if not _check(sandbox._claim_weapon_reward(weapon) and weapons.equipment[weapon] == mini(number, 2), "네 정예 실제 무기 교체·영웅 상한"): return false
			if number == 2:
				_tap(controls.relic_reward_open_rect.get_center())
				if not _check(sandbox._claim_relic_reward(PrototypeRelic.DEW_ID if weapon == "bow" else PrototypeRelic.PHOENIX_ID), "서로 다른 유물 실제 획득"): return false
			if number in [3, 4]:
				_tap(controls.skill_reward_open_rect.get_center())
				var id: String = controls.skill_reward_offers[0].id
				if not _check(sandbox._claim_skill_reward(id, 0) and runner.skills_claimed and not sandbox._claim_skill_reward(id, 0), "3·4단계 실제 스킬 교체·중복 보상 차단"): return false
			var saved := store.load_checkpoint()
			var health := player.damage_receiver.health
			var relic := player.relic_state.duplicate()
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and runner.stage_limit == 5 and runner.stage_number == number and player.damage_receiver.health == health and player.relic_state == relic and store.load_checkpoint() == saved and weapons.skills == saved.weapons.skills, "매 정예 실제 저장/복원·직업/스킬/유물/잔량·무료 보충 없음"): return false
			var routes := runner.available_routes()
			if not _check(routes.size() == (3 if number == 1 and weapon == "bow" else 2), "위험 경로는 파괴 적용 도전의2단계만"): return false
			_tap(controls.stage_route_rects[2 if number == 1 and weapon == "bow" else number % 2].get_center())
		if not _check(growth.jobs.job_id == ("vanguard" if weapon == "sword" else "tracker") and not ultimate.selected_profile.is_empty() and sandbox._resolve_boss_choice("destroy" if weapon == "sword" else "rescue"), "긴 검/활 직업·필살기 발현·양쪽 보스 선택 실제 완주"): return false
	var summary: Dictionary = recorder.summary_snapshot()
	return _check(summary.completed_run_count == 2 and summary.completion_by_stage_count["5"].completed_run_count == 2 and summary.boss_destroy_count == 1 and summary.boss_rescue_count == 1, "긴 도전 두 완주·구출/파괴·길이별 기록")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-139 failed: " + message)
		paused = false
		quit(1)
	return condition
