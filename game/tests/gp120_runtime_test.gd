extends "res://tests/gp117_runtime_test.gd"

const GP120_SAVE := "user://gp120_checkpoint.json"
const GP120_META := "user://gp120_meta.jsonl"
const GP120_RECORD := "user://gp120_records.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP120_SAVE
	legacy.save_path = GP120_META
	if phase == "seed":
		store.clear_checkpoint()
		for path in [GP120_META, GP120_RECORD]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP120_RECORD
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
	weapons.sword_combat.set_process(false)
	weapons.bow_combat.set_process(false)
	runner.set_process(false)
	player.set_physics_process(false)
	match phase:
		"seed":
			controls.show_village()
			var before := legacy.progress_snapshot()
			if not await _test_apothecary_layout(false): return
			_tap(controls.village_snapshot().layout.cards[1].get_center())
			if not _check(legacy.progress_snapshot() == before and not sandbox._select_potion_recipe("concentrated") and not sandbox._select_potion_recipe("other") and store.load_checkpoint().is_empty(), "잠긴 농축·알 수 없는 조제 차단·방문은 저장 미변경"): return
			controls.show_main_screen()
			if not _reach_boss() or not _finish_stage(): return
			if not _check(sandbox._resolve_boss_choice("rescue"), "실제 보스 구출 완주로 약초사 영구 정착"): return
			controls.show_village()
			if not await _test_apothecary_layout(true): return
			before = legacy.progress_snapshot()
			legacy.fail_writes = true
			_tap(controls.village_snapshot().layout.cards[1].get_center())
			if not _check(controls.preferred_potion_recipe == "basic" and legacy.progress_snapshot() == before and controls.potion_recipe_message.contains("실패"), "조제 저장 실패는 이전 선택·저널 보존·재시도 안내"): return
			legacy.fail_writes = false
			_tap(controls.village_snapshot().layout.cards[1].get_center())
			if not _check(controls.preferred_potion_recipe == "concentrated" and legacy.progress_snapshot().potion_recipe == "concentrated", "실제 터치로 농축 조제 저장"): return
			var contents := FileAccess.get_file_as_string(GP120_META)
			_tap(controls.village_snapshot().layout.cards[1].get_center())
			if not _check(FileAccess.get_file_as_string(GP120_META) == contents, "같은 조제 재선택은 저널 중복 없음"): return
			var record := recorder.checkpoint_snapshot()
			_tap(controls.village_snapshot().layout.start.get_center())
			_tap(controls.start_weapon_cancel_rect.get_center())
			if not _check(controls.current_screen_mode() == 13 and recorder.checkpoint_snapshot() == record and legacy.progress_snapshot().potion_recipe == "concentrated", "새 도전 준비 취소는 도전·조제 보존"): return
			_tap(controls.village_snapshot().layout.start.get_center())
			_tap(controls.boss_legacy_toggle_rect.get_center())
			_tap(controls.start_weapon_confirm_rect.get_center())
			if not _check(player.potion_recipe == "concentrated" and player.potions_remaining == 1 and controls._action_label(&"recovery_potion") == "회복 1/1" and not sandbox._select_potion_recipe("basic"), "새 도전 농축 1개·진행 중 조제 변경 차단"): return
			_press_potion()
			if not _check(player.potions_remaining == 1 and player.damage_receiver.health == 100, "만피 농축은 소비 없음"): return
			player.damage_receiver.max_health = 101
			player.damage_receiver.health = 101
			_hit_player(61, "concentrated-hit")
			weapons.sword_combat._skill_1_cooldown_s = 3.25
			weapons.bow_combat._skill_2_cooldown_s = 4.75
			var xp := growth.total_experience
			var hits := player.damage_receiver.applied_count
			_press_potion()
			if not _check(player.damage_receiver.health == 81 and player.potions_remaining == 0 and controls._action_label(&"recovery_potion") == "회복 0/1" and growth.total_experience == xp and player.damage_receiver.applied_count == hits and is_equal_approx(weapons.sword_combat._skill_1_cooldown_s, 3.25) and is_equal_approx(weapons.bow_combat._skill_2_cooldown_s, 4.75), "실제 터치 농축 40% 정수 올림·HUD·성장·양 무기 대기시간 보존"): return
			_press_potion()
			if not _check(player.damage_receiver.health == 81 and player.potions_remaining == 0, "소진한 농축은 재사용 없음"): return
			player.damage_receiver.max_health = 100
			player.damage_receiver.health = 100
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			var saved := store.load_checkpoint()
			if not _check(saved.player.potion_recipe == "concentrated" and saved.player.potions_remaining == 0, "농축과 남은 0개 중간 저장"): return
			for invalid in [null, false, 1, "other", {}, []]:
				var bad := saved.duplicate(true)
				bad.player.potion_recipe = invalid
				if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "손상 조제 거부·정상 저장 보호"): return
			var bad := saved.duplicate(true)
			bad.player.potions_remaining = 2
			if not _check(not RunCheckpointStore.valid_state(bad), "농축 두 개 변조 차단"): return
			bad = saved.duplicate(true)
			bad.player.erase("potions_remaining")
			if not _check(not RunCheckpointStore.valid_state(bad), "새 조제 저장에서 남은 개수 누락 차단"): return
			controls.show_main_screen()
			controls.show_village()
			_tap(controls.village_snapshot().layout.cards[4].get_center())
			_tap(controls.village_snapshot().layout.cards[0].get_center())
			if not _check(controls.preferred_potion_recipe == "basic" and player.potion_recipe == "concentrated" and player.potions_remaining == 0 and store.load_checkpoint() == saved, "약방 기본 선택은 현재 도전·중간 저장의 농축 소진 상태 보존"): return
		"resume":
			if not _check(controls.preferred_potion_recipe == "basic", "재시작은 다음 도전 기본 조제 복원"): return
			controls.show_village()
			_tap(controls.village_snapshot().layout["continue"].get_center())
			if not _check(player.potion_recipe == "concentrated" and player.potions_remaining == 0 and controls.preferred_potion_recipe == "basic" and controls._action_label(&"recovery_potion") == "회복 0/1", "마을 이어하기는 최신 조제와 독립적으로 농축·소진 복원"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _check(player.potions_remaining == 0, "스테이지 이동은 소진한 농축 충전 없음"): return
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			var saved := store.load_checkpoint()
			if not _check(saved.player.potion_recipe == "concentrated" and saved.player.potions_remaining == 0, "두 번째 스테이지에도 조제·개수 저장"): return
			# 조제 필드가 없는 GP-119 저장은 남은 개수만 보존한다.
			saved.player.erase("potion_recipe")
			if not _check(store.save_checkpoint(saved) == OK, "이전 GP-119 저장 준비"): return
			controls.show_main_screen()
			controls.show_village()
			_tap(controls.village_snapshot().layout.cards[4].get_center())
			_tap(controls.village_snapshot().layout.cards[1].get_center())
			recorder.clear_records()
			if not _check(legacy.progress_snapshot().potion_recipe == "concentrated" and legacy.progress_snapshot().unlocked.has("clockwork_guard") and store.load_checkpoint() == saved, "도전 기록 초기화는 조제·정착·기존 저장 보존"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and player.potion_recipe == "basic" and player.potions_remaining == 0 and controls.preferred_potion_recipe == "concentrated", "이전 저장은 기본 조제·남은 0개로 복원·다음 도전 선택 무시"): return
			var old := store.load_checkpoint()
			old.player.erase("potions_remaining")
			if not _check(store.save_checkpoint(old) == OK, "회복약 필드도 없는 초기 저장 준비"): return
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and player.potion_recipe == "basic" and player.potions_remaining == 2, "초기 저장은 기본 25%·2개로 호환"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage(): return
			if not _check(sandbox._resolve_boss_choice("destroy"), "이전 저장 이어하기 실제 보스 파괴 완주"): return
			controls.show_village()
			if not await _test_apothecary_layout(true): return
			if not _check(controls.preferred_potion_recipe == "concentrated", "이후 파괴 완주도 약초사·조제 유지"): return
			_tap(controls.village_snapshot().layout.start.get_center())
			_tap(controls.boss_legacy_toggle_rect.get_center())
			_tap(controls.start_weapon_confirm_rect.get_center())
			if not _check(player.potion_recipe == "concentrated" and player.potions_remaining == 1 and player.damage_receiver.max_health == 100, "다음 새 도전은 저장한 농축 1개로 준비"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-120 runtime test: OK (" + phase + ")")
	quit(0)

func _test_apothecary_layout(unlocked: bool) -> bool:
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls.village_page = "village"
		if not _check(controls.village_snapshot().cards.size() == 5 and controls.village_snapshot().cards[4].open == unlocked, "다섯 시설·약초사 정착 상태"): return false
		for page in ["village", "apothecary"]:
			controls.village_page = page
			var snapshot: Dictionary = controls.village_snapshot()
			var safe: Rect2 = controls.layout_snapshot().safe
			var rects: Array = snapshot.layout.cards.duplicate()
			rects.append_array([snapshot.layout.back, snapshot.layout.start])
			if controls.checkpoint_available: rects.append(snapshot.layout["continue"])
			for i in rects.size():
				if not _check(safe.encloses(rects[i]), "두 화면비 약방·마을 안전 영역"): return false
				for j in range(i + 1, rects.size()):
					if not _check(not rects[i].intersects(rects[j]), "시설·조제·복귀·시작 버튼 겹침 없음"): return false
			controls.queue_redraw()
			await process_frame
		controls.village_page = "village"
		_tap(controls.village_snapshot().layout.cards[4].get_center())
		if not _check(controls.village_page == "apothecary" and controls.village_snapshot().cards[0].open and controls.village_snapshot().cards[1].open == unlocked, "약방 실제 터치·기본 항상 제공·농축 잠금 조건"): return false
	var elapsed := runner.stage_elapsed_s
	var position := player.position
	for ignored in 3: await physics_frame
	return _check(sandbox.is_combat_environment_suspended() and player.position == position and runner.stage_elapsed_s == elapsed and not sandbox._use_recovery_potion(), "약방 방문은 전투·물리 동결·회복약 사용 차단")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-120 failed: " + message)
		quit(1)
	return condition
