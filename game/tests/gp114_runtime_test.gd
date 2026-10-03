extends "res://tests/gp110_runtime_test.gd"

const GP114_SAVE := "user://gp114_checkpoint.json"
const GP114_LEGACY := "user://gp114_meta.jsonl"
const GP114_RECORD := "user://gp114_records.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP114_SAVE
	legacy.save_path = GP114_LEGACY
	if phase == "seed":
		store.clear_checkpoint()
		for path in [GP114_LEGACY, GP114_RECORD]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP114_RECORD
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
	match phase:
		"seed":
			_tap(controls.main_village_rect.get_center())
			if not _check(controls.current_screen_mode() == 13 and not controls.village_snapshot().resident and not controls.village_snapshot().cards[0].open and not controls.village_snapshot().cards[1].open, "처음 마을·대장간·쉼터 잠금·기사 미정착"): return
			var meta := legacy.progress_snapshot()
			var elapsed := runner.stage_elapsed_s
			var position := player.position
			var health := player.damage_receiver.health
			runner.set_process(true)
			for ignored in 4:
				await physics_frame
			if not _check(sandbox.is_combat_environment_suspended() and runner.process_mode == Node.PROCESS_MODE_DISABLED and player.process_mode == Node.PROCESS_MODE_DISABLED and runner.stage_elapsed_s == elapsed and player.position == position and player.damage_receiver.health == health, "마을 방문 중 실제 전투·물리·타이머 동결"): return
			runner.set_process(false)
			if not await _test_layout_and_pages(): return
			_tap(controls.village_snapshot().layout.start.get_center())
			if not _check(controls.current_screen_mode() == 10 and sandbox.is_combat_environment_suspended(), "마을에서 준비·전투 동결 유지"): return
			_tap(controls.start_weapon_cancel_rect.get_center())
			if not _check(controls.current_screen_mode() == 13 and legacy.progress_snapshot() == meta and store.load_checkpoint().is_empty(), "준비 취소는 마을 복귀·메타와 저장 미변경"): return
			_tap(controls.village_snapshot().layout.back.get_center())
			if not _check(controls.current_screen_mode() == 2 and not sandbox.is_combat_environment_suspended() and player.process_mode != Node.PROCESS_MODE_DISABLED, "메인 복귀는 원래 환경 복원"): return
			if not _reach_boss() or not _finish_stage(): return
			if not _check(sandbox._resolve_boss_choice("rescue"), "실제 구출 완주"): return
			controls.show_village()
			if not _check(controls.village_snapshot().resident and controls.village_snapshot().cards[1].open and not controls.village_snapshot().cards[0].open, "구출 기사 영구 정착·쉼터만 해금"): return
			var reward := legacy.pending_reward()
			_tap(controls.village_snapshot().layout.start.get_center())
			legacy.fail_writes = true
			_tap(controls.start_weapon_confirm_rect.get_center())
			legacy.fail_writes = false
			if not _check(controls.current_screen_mode() == 2 and not sandbox.is_combat_environment_suspended() and legacy.pending_reward() == reward, "저장 실패는 메인 복구·보상 소비 없음·동결 해제"): return
			controls.show_village()
			_tap(controls.village_snapshot().layout.start.get_center())
			_tap(controls.memory_card_rects[1].get_center())
			_tap(controls.start_weapon_confirm_rect.get_center())
			if not _check(controls.current_screen_mode() == 0 and not sandbox.is_combat_environment_suspended() and player.memory_id == "clockwork_guard" and legacy.pending_reward().is_empty(), "마을 준비 확정·기억 장착·일회 보상 소비·전투 재개"): return
			if not _finish_stage(): return
			# 중간 완료 상태를 둔 채 마을을 방문해도 저장/보상/기억이 바뀌지 않는다.
			controls.show_main_screen()
			var checkpoint := store.load_checkpoint()
			meta = legacy.progress_snapshot()
			controls.show_village()
			_tap(controls.village_snapshot().layout.start.get_center())
			_tap(controls.start_weapon_cancel_rect.get_center())
			if not _check(store.load_checkpoint() == checkpoint and legacy.progress_snapshot() == meta and controls.village_snapshot().resident, "이어하기 저장·소비 후 정착·준비 취소 보존"): return
		"resume":
			controls.show_village()
			if not _check(controls.checkpoint_available and controls.village_snapshot().resident and legacy.pending_reward().is_empty(), "별도 프로세스에 영구 정착·미완료 저장 복원"): return
			if not await _test_layout_and_pages(): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			if not _check(controls.current_screen_mode() == 11 and not sandbox.is_combat_environment_suspended() and player.memory_id == "clockwork_guard" and player.boss_legacy.choice == "rescue", "마을 이어하기는 무기 선택·기억·소비한 보상 복원"): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage(): return
			if not _check(sandbox._resolve_boss_choice("destroy"), "이어하기 후 실제 파괴 완주"): return
			controls.show_village()
			if not _check(controls.village_snapshot().resident and controls.village_snapshot().cards[0].open and controls.village_snapshot().cards[1].open, "이후 파괴에도 기사 정착 유지·두 시설 열림"): return
			if not await _test_layout_and_pages(): return
			if not _check(recorder.summary_snapshot().completed_run_count == 2 and controls.test_record_summary.completed_run_count == 2, "광장 두 실제 완주 집계"): return
		"finish":
			controls.show_village()
			if not _check(controls.village_snapshot().resident and controls.unlocked_weapon_blueprints.size() == 2 and controls.unlocked_memories.size() == 2 and not controls.checkpoint_available, "재시작 후 정착·설계도·기억·완료 저장 정리"): return
			if not await _test_layout_and_pages(): return
			recorder.clear_records()
			controls.show_main_screen()
			controls.show_village()
			if not _check(controls.village_snapshot().resident and controls.village_snapshot().cards[0].open and controls.test_record_summary.run_count == 0, "도전 기록 삭제와 영구 정착·시설 독립"): return
		_:
			_check(false, "알 수 없는 검사 단계")
			return
	print("GP-114 runtime check: OK · " + phase)
	quit(0)

func _test_layout_and_pages() -> bool:
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_layout()
		for page in ["village", "forge", "memories", "records"]:
			controls.village_page = page
			var snapshot: Dictionary = controls.village_snapshot()
			var safe: Rect2 = controls.layout_snapshot().safe
			var rectangles: Array = snapshot.layout.cards.duplicate()
			rectangles.append_array([snapshot.layout.back, snapshot.layout.start])
			if controls.checkpoint_available:
				rectangles.append(snapshot.layout["continue"])
			for i in rectangles.size():
				if not _check(safe.encloses(rectangles[i]), "모든 페이지·두 화면비 안전 영역"): return false
				for j in range(i + 1, rectangles.size()):
					if not _check(not rectangles[i].intersects(rectangles[j]), "마을 입력 겹침 없음"): return false
			if page == "forge":
				for card in snapshot.cards:
					if card.open and not _check(card.lines.size() == 6 and "25%" in card.lines[1] and "35%" in card.lines[3], "대장간이 실제 희귀·영웅 고유 성능 표시"): return false
			controls.queue_redraw()
			await process_frame
		controls.village_page = "village"
		for i in 3:
			_tap(controls.village_snapshot().layout.cards[i].get_center())
			if not _check(controls.village_page == PrototypeVillageView.FACILITIES[i], "잠금 시설도 조건을 확인하는 실제 터치"): return false
			_tap(controls.village_snapshot().layout.back.get_center())
			if not _check(controls.village_page == "village", "시설 뒤로는 마을 복귀"): return false
	return true

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-114 failed: " + message)
		quit(1)
	return condition
