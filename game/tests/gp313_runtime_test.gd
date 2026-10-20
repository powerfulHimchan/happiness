extends "res://tests/gp312_runtime_test.gd"

func _run() -> void:
	auto_guardian_choice = false
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var character := args[1]
	var weapon := args[2]
	var choice := args[3]
	var prefix := "user://gp313_%s_%s_%s_%s" % ["flow" if phase in ["seed", "resume", "finish"] else phase, character, weapon, choice]
	store.save_path = prefix + "_checkpoint.json"
	legacy.save_path = prefix + "_meta.jsonl"
	journal.save_path = prefix + "_story.jsonl"
	if phase not in ["resume", "finish"]:
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
			if not _prepare_guardian_choice(character, weapon) or not _ack_scene(true): return
			if not _check(sandbox.guardian_companion.is_empty() and legacy.progress_snapshot().blueprints.is_empty(), "해금 전 현재 도전은 동행 없음"): return
			if not _select_choice(choice) or not _check_unlock(choice): return
			var source := String(recorder.checkpoint_snapshot().id)
			var raw := FileAccess.get_file_as_string(legacy.save_path)
			if not _check(legacy.grant_guardian(source, choice) == OK and legacy.grant_guardian(source, "destroy" if choice == "rescue" else "rescue") == ERR_INVALID_DATA and raw == FileAccess.get_file_as_string(legacy.save_path) and legacy.pending_reward().is_empty(), "성문 해금 멱등·충돌 거부·최종 보상 독립"): return
			if not await _check_forge(choice): return
			controls.selected_story_enabled = false
			controls.selected_character_id = character
			controls.begin_retry(weapon, 3, "standard", character)
			if not _check(player.guardian_choice.is_empty() and sandbox.guardian_companion.is_empty() == (choice == "destroy"), "다음 새 도전부터 영구 동행·현재 여정 배율 초기화"): return
			if not _check_support(choice) or not _finish_stage(): return
			if not await _claim_guardian_weapon(weapon, choice, 1): return
		"resume":
			if not _restore_companion(1, choice, weapon) or not _check_unlock(choice): return
			if not _next_without_layout() or not _check_support(choice) or not _finish_stage(): return
			if not await _claim_guardian_weapon(weapon, choice, 2): return
		"finish":
			if not _restore_companion(2, choice, weapon) or not _next_without_layout() or not _check_support(choice) or not _finish_stage(): return
			if not _check(controls.current_screen_mode() == 12 and sandbox._resolve_boss_choice("destroy" if choice == "rescue" else "rescue") and controls.current_result_snapshot().boss_choice == ("destroy" if choice == "rescue" else "rescue") and sandbox.guardian_companion.is_empty(), "3단계 완주·최종 보상·동행 현재 상태 정리"): return
			if not _check_unlock(choice): return
			controls.show_main_screen()
			controls.show_start_weapon_selection()
			if not _check(controls.guardian_companion_unlocked == (choice == "rescue"), "새 도전 준비에 영구 동행 표시"): return
		"fault":
			if not _prepare_guardian_choice(character, weapon) or not _ack_scene(true): return
			player.damage_receiver.health = 45
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "실패 전 잔량 저장"): return
			var path := store.save_path
			store.save_path = "user://gp313_missing/checkpoint.json"
			if not _check(not sandbox._resolve_guardian_choice(choice) and not legacy.progress_snapshot().guardian_companion and legacy.progress_snapshot().blueprints.is_empty(), "체크포인트 실패는 영구 해금 없음"): return
			store.save_path = path
			var meta := legacy.save_path
			legacy.save_path = "user://gp313_missing/meta.jsonl"
			if not _check(sandbox._resolve_guardian_choice(choice) and store.load_checkpoint().stage.guardian_choice == choice and not sandbox._guardian_reward_saved and not sandbox._claim_weapon_reward(weapon), "선택 확정 저장 후 저널 실패는 보상 진행 차단"): return
			var health := player.damage_receiver.health
			var selected := store.load_checkpoint()
			controls.begin_retry(weapon, 3, "standard", character)
			if not _check(runner.stage_number == 9 and store.load_checkpoint() == selected and controls.current_screen_mode() == 2, "미기록 해금이 있으면 새 도전으로 덮어쓰지 않음"): return
			legacy.save_path = meta
			if not _check(sandbox.continue_saved_run() and sandbox._guardian_reward_saved and player.damage_receiver.health == health and controls.current_screen_mode() == 11, "이어하기로 확정 선택 해금 복구·체력 재지급 없음"): return
			if not _check_unlock(choice): return
		"validate":
			if not _prepare_guardian_choice(character, weapon) or not _ack_scene(true) or not _select_choice(choice): return
			controls.selected_story_enabled = false
			controls.begin_retry(weapon, 5, "standard", character)
			if not _check_support(choice) or not _finish_stage(): return
			var saved := store.load_checkpoint()
			var old := saved.duplicate(true)
			old.erase("guardian_companion")
			if not _check(RunCheckpointStore.valid_state(old), "이전 버전1 동행 필드 생략 허용"): return
			for bad in [null, [], true, {"run_id": "other", "assisted_stages": []}, {"run_id": saved.recorder.id, "assisted_stages": [1, 1]}, {"run_id": saved.recorder.id, "assisted_stages": [2]}, {"run_id": saved.recorder.id, "assisted_stages": [1.5]}, {"run_id": saved.recorder.id, "assisted_stages": [true]}]:
				var corrupt := saved.duplicate(true)
				corrupt.guardian_companion = bad
				if not _check(store.save_checkpoint(corrupt) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "동행 타입/ID/중복/미래/소수/불리언 거부·정상 저장 보존"): return
			if not _check(store.save_checkpoint(old) == OK, "이전 저장 실제 기록"): return
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and sandbox.guardian_companion.is_empty(), "이전 진행 중 도전에 뒤늦게 동행 부여하지 않음"): return
		"journal":
			if not _check(legacy.grant_guardian("rescued", "rescue") == OK and legacy.grant_guardian("destroyed", "destroy") == OK and legacy.grant("final", "destroy") == OK, "두 영구 해금과 최종 보상 공존"): return
			var state := legacy.guardian_for_run("run")
			var path := legacy.save_path
			legacy.save_path = "user://gp313_missing/meta.jsonl"
			if not _check(not legacy.spend_guardian_assist(state, 1, 10) and state.assisted_stages.is_empty(), "소비 기록 실패는 지원 상태 보존"): return
			legacy.save_path = path
			if not _check(legacy.spend_guardian_assist(state, 10, 10) and not legacy.spend_guardian_assist(state, 10, 10) and not legacy.spend_guardian_assist(state, 6, 5) and not legacy.spend_guardian_assist(state, 0, 10), "10단계 지원·중복/범위 제한"): return
			var backup := {"run_id": "run", "assisted_stages": []}
			if not _check(legacy.restore_guardian(backup).assisted_stages == [10] and not legacy.spend_guardian_assist(backup, 10, 10), "이전 백업으로도 이미 쓴 지원 재사용 불가"): return
			var file := FileAccess.open(path, FileAccess.READ_WRITE)
			file.seek_end()
			file.store_string("broken-tail")
			file.close()
			if not _check(legacy.grant_guardian("again", "rescue") == OK and legacy.progress_snapshot().guardian_companion and legacy.progress_snapshot().blueprints.size() == 4 and legacy.pending_reward().source == "final", "불완전 저널 뒤 유효 기록 복구·최종 보상 독립"): return
		"modes":
			if not _check(legacy.grant_guardian("rescue", "rescue") == OK and legacy.grant("final", "rescue") == OK, "두 조력자 해금"): return
			sandbox._update_boss_legacy_status()
			for mode in 4:
				controls.show_main_screen()
				controls.show_start_weapon_selection()
				controls.selected_story_enabled = false
				controls.selected_starting_weapon = weapon
				controls.selected_backup_weapon = "sword" if weapon == "bow" else "bow"
				_tap(controls.start_length_rects[mode].get_center())
				_tap(controls.start_weapon_confirm_rect.get_center())
				if not _check_support("rescue", 50 if mode == 0 else 30): return
				var raw := FileAccess.get_file_as_string(legacy.save_path)
				var state: Dictionary = sandbox._capture_run_build()
				var cards := PrototypeRunBuildView.cards(2, state)
				if not _check(cards.any(func(card: Dictionary) -> bool: return card.id == "guardian_companion") and raw == FileAccess.get_file_as_string(legacy.save_path), "네 모드 현재 도전 동행 조회·저널 불변"): return
				if not _finish_stage(): return
		_:
			_check(false, "알 수 없는 영구 해금 검사")
			return
	paused = false
	sandbox.free()
	print("GP-313 runtime test: OK (%s %s %s %s)" % [phase, character, weapon, choice])
	quit(0)

func _check_unlock(choice: String) -> bool:
	var progress := legacy.progress_snapshot()
	return _check(progress.guardian_companion == (choice == "rescue") and progress.blueprints.get("guardian_sword", false) == (choice == "destroy") and progress.blueprints.get("guardian_bow", false) == (choice == "destroy") and controls.guardian_companion_unlocked == (choice == "rescue"), "성문 영구 동행/설계도 실제 해금·표시")

func _check_support(choice: String, damage: int = 30) -> bool:
	if not _reach_journey_elite(): return false
	var enemy := runner.final_enemy()
	var expected := damage if choice == "rescue" else 0
	if not _check(enemy.damage_receiver.health == enemy.damage_receiver.max_health - expected and sandbox.guardian_companion.is_empty() == (choice == "destroy"), "정예 진입 실제 지원 피해·두 조력자 독립 합산"): return false
	var health := enemy.damage_receiver.health
	runner.force_emit_metrics()
	runner.force_emit_metrics()
	return _check(enemy.damage_receiver.health == health and (sandbox.guardian_companion.is_empty() or runner.stage_number in sandbox.guardian_companion.assisted_stages), "정예 지표 반복은 추가 타격 없음")

func _claim_guardian_weapon(weapon: String, choice: String, grade: int) -> bool:
	var id := "guardian_" + weapon
	var offers := PrototypeWeaponRewards.offers(runner.stage_number, weapons.equipment, weapons.unlocked_blueprints, weapons.blueprints)
	if choice == "rescue":
		return _check(not offers.any(func(item: Dictionary) -> bool: return item.id in PrototypeWeaponRewards.GUARDIAN_DESIGNS) and not weapons.equip_reward(id, grade) and sandbox._claim_weapon_reward(weapon), "미해금 수호 무기 보상/직접 장착 차단")
	for dimensions in [Vector2(1280, 720), Vector2(1600, 720)]:
		controls.size = dimensions
		controls.show_weapon_rewards(runner.stage_number, offers)
		for page in controls.weapon_reward_pages():
			var safe: Rect2 = controls.layout_snapshot().safe
			if not _check(controls.weapon_reward_rects.all(func(rect: Rect2) -> bool: return safe.encloses(rect)) and controls.weapon_reward_cards.size() <= 4, "수호 무기 포함 보상 페이지 안전 영역·최대4장"): return false
			if page < controls.weapon_reward_pages() - 1: _tap(controls.weapon_reward_next_rect.get_center())
	controls.size = Vector2(1280, 720)
	controls.show_weapon_rewards(runner.stage_number, offers)
	for page in controls.weapon_reward_pages():
		for index in controls.weapon_reward_cards.size():
			if controls.weapon_reward_cards[index].id == id:
				_tap(controls.weapon_reward_rects[index].get_center())
				_tap(controls.weapon_reward_confirm_rect.get_center())
				var kind := "skill" if weapon == "sword" else "basic"
				var expected := 135 if grade == 1 else 155
				if not _check(weapons.blueprints[weapon] == id and weapons.equipment[weapon] == grade and player.growth_damage(100, weapon, kind) == roundi(100 * PrototypeWeaponRewards.damage_multiplier(weapons.equipment, weapon, kind, weapons.blueprints) * (1.0 + player.growth_common_bonus + (player.growth_sword_bonus if weapon == "sword" else player.growth_bow_bonus))), "수호 무기 실제 카드 장착·희귀/영웅 피해 적용"): return false
				if not _check(roundi(PrototypeWeaponRewards.damage_multiplier({"sword": grade if weapon == "sword" else 0, "bow": grade if weapon == "bow" else 0}, weapon, kind, {"sword": id if weapon == "sword" else "", "bow": id if weapon == "bow" else ""}) * 100) == expected, "희귀35%·영웅55% 성능"): return false
				return true
		_tap(controls.weapon_reward_next_rect.get_center())
	return _check(false, "해금 수호 무기 실제 보상에 존재")

func _restore_companion(stage: int, choice: String, weapon: String) -> bool:
	var saved := store.load_checkpoint()
	for ignored in 2:
		controls.show_main_screen()
		if not _check(sandbox.continue_saved_run() and runner.stage_number == stage and store.load_checkpoint() == saved and (sandbox.guardian_companion.is_empty() if choice == "destroy" else sandbox.guardian_companion.assisted_stages.size() == stage) and (weapons.blueprints[weapon] == "guardian_" + weapon if choice == "destroy" else weapons.blueprints[weapon].is_empty()), "별도 프로세스 반복 이어하기·동행 사용/장착 유지"): return false
	return true

func _next_without_layout() -> bool:
	var number := runner.stage_number
	var route: String = controls.stage_route_options[-1].id
	_tap(controls.stage_route_rects[-1].get_center())
	return _check(not paused and runner.stage_number == number + 1 and runner.route_id == route, "실제 다음 경로 카드 입력")


func _check_forge(choice: String) -> bool:
	var saved := store.load_checkpoint()
	var progress := legacy.progress_snapshot()
	controls.show_main_screen()
	controls.show_village()
	for dimensions in [Vector2(1280, 720), Vector2(1600, 720)]:
		controls.size = dimensions
		controls.village_page = "forge"
		controls.weapon_codex_page = 0
		controls.queue_redraw()
		for ignored in 2: await process_frame
		var first: Dictionary = controls.village_snapshot()
		if not _check(first.codex_pages == 3 and first.cards.map(func(card: Dictionary) -> String: return card.id) == ["clockwork_sword", "clockwork_bow"], "대장간 첫 페이지 기존 태엽 설계도 보존"): return false
		_tap(first.pager.next.get_center())
		var second: Dictionary = controls.village_snapshot()
		if not _check(second.codex_page == 1 and second.cards.map(func(card: Dictionary) -> String: return card.id) == PrototypeWeaponRewards.GUARDIAN_DESIGNS and second.cards.all(func(card: Dictionary) -> bool: return card.open == (choice == "destroy") and (card.lines[0].contains("희귀") if choice == "destroy" else card.lines[0].contains("수호기사 파괴"))), "대장간 둘째 페이지 실제 입력·수호 설계도 잠금/해금 표시"): return false
		var safe: Rect2 = controls.layout_snapshot().safe
		for rect in second.layout.cards + [second.pager.previous, second.pager.next]:
			if not _check(safe.encloses(rect), "두 화면비 대장간 카드/페이지 안전 영역"): return false
		_tap(second.pager.next.get_center())
		if not _check(controls.village_snapshot().codex_page == 2, "세라 설계도 셋째 페이지"): return false
		_tap(second.pager.previous.get_center())
		_tap(second.pager.previous.get_center())
		if not _check(controls.village_snapshot().codex_page == 0, "설계도 페이지 이전 입력"): return false
	controls.size = Vector2(1280, 720)
	controls.show_main_screen()
	return _check(store.load_checkpoint() == saved and legacy.progress_snapshot() == progress, "설계도 비교·페이지 조회는 보상/저장 불변")
