extends "res://tests/gp110_runtime_test.gd"

const GP111_LEGACY_PATH := "user://gp111_memories.jsonl"
const GP111_SAVE_PATH := "user://gp111_checkpoint.json"
const GP111_RECORD_PATH := "user://gp111_records.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if not args.is_empty() else "legacy-seed"
	store.save_path = GP111_SAVE_PATH
	legacy.save_path = GP111_LEGACY_PATH
	if mode == "legacy-seed":
		store.clear_checkpoint()
		for path in [GP111_LEGACY_PATH, GP111_RECORD_PATH]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP111_RECORD_PATH
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
	match mode:
		"legacy-seed":
			controls.show_start_weapon_selection()
			if not _check(controls.unlocked_memories.is_empty(), "처음에는 두 영구 기억 모두 잠김"): return
			_tap(controls.memory_card_rects[1].get_center())
			_tap(controls.memory_card_rects[2].get_center())
			if not _check(controls.selected_memory_id == "" and legacy.claim("invalid-run", false, "core_echo").error == ERR_INVALID_DATA, "잠긴 기억은 UI·저장 양쪽에서 장착 차단"): return
			_tap(controls.start_weapon_cancel_rect.get_center())
			# GP-110이 작성한 필드 그대로: 이미 소비한 구출도 영구 능력을 해금한다.
			if not _check(legacy._append({"event": "reward", "source": "gp110-old-rescue", "choice": "rescue"}) == OK and legacy._append({"event": "claim", "source": "gp110-old-rescue", "run_id": "gp110-old-run", "enabled": false}) == OK, "이전 버전 보상·소비 저널 준비"): return
			if not _check(legacy.progress_snapshot().unlocked == {"clockwork_guard": true} and legacy.pending_reward().is_empty(), "소비한 GP-110 구출의 영구 해금 호환"): return
			recorder.clear_records()
			if not _check(legacy.progress_snapshot().unlocked == {"clockwork_guard": true}, "테스트 기록 초기화와 해금 독립"): return
		"guard-start":
			if not _check(controls.unlocked_memories == {"clockwork_guard": true} and controls.preferred_memory_id == "" and player.memory_id == "", "재실행에 영구 해금 표시·시작 전 능력 미적용"): return
			controls.show_start_weapon_selection()
			for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
				controls.size = dimensions
				controls._refresh_start_weapon_layout()
				var safe: Rect2 = controls.layout_snapshot().safe
				var rectangles: Array = controls.start_weapon_card_rects.duplicate()
				rectangles.append_array(controls.memory_card_rects)
				rectangles.append_array([controls.boss_legacy_toggle_rect, controls.start_weapon_cancel_rect, controls.start_weapon_confirm_rect])
				for i in rectangles.size():
					if not _check(safe.encloses(rectangles[i]), "두 화면 비율 모든 선택 입력 안전 영역"): return
					for j in range(i + 1, rectangles.size()):
						if not _check(not rectangles[i].intersects(rectangles[j]), "무기·기억·보상·확정 입력 겹침 없음"): return
			_tap(controls.memory_card_rects[1].get_center())
			_tap(controls.memory_card_rects[2].get_center())
			controls.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
			controls.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
			if not _check(controls.selected_memory_id == "clockwork_guard", "잠긴 공격 기억 터치는 수호 선택 유지·앱 복귀 보존"): return
			_tap(controls.start_weapon_cancel_rect.get_center())
			if not _check(legacy.progress_snapshot().selected_memory == "" and player.damage_receiver.max_health == 100, "취소는 영구 선택·플레이어 변경 없음"): return
			controls.show_start_weapon_selection()
			_tap(controls.memory_card_rects[1].get_center())
			legacy.fail_writes = true
			var original := FileAccess.get_file_as_string(GP111_LEGACY_PATH)
			_tap(controls.start_weapon_confirm_rect.get_center())
			if not _check(controls.current_screen_mode() == 2 and FileAccess.get_file_as_string(GP111_LEGACY_PATH) == original and not growth.run_active and player.memory_id == "", "보상 없는 기억 선택 저장 실패는 시작 차단"): return
			legacy.fail_writes = false
			controls.show_start_weapon_selection()
			_tap(controls.memory_card_rects[1].get_center())
			var confirm: Vector2 = controls.start_weapon_confirm_rect.get_center()
			_tap(confirm)
			if not _check(player.memory_id == "clockwork_guard" and player.damage_receiver.max_health == 105 and player.damage_receiver.health == 105 and legacy.progress_snapshot().selected_memory == "clockwork_guard" and player.boss_legacy.is_empty() and player.growth_damage(100, "sword", "skill") == 100, "수호 단일 장착·체력 +5·공격 불변·선택 저장"): return
			var runs: int = recorder.summary_snapshot().run_count
			_tap(confirm)
			if not _check(recorder.summary_snapshot().run_count == runs, "확정 중복 터치로 새 도전 중복 없음"): return
			if not _finish_stage(): return
			var saved := store.load_checkpoint()
			if not _check(not saved.is_empty() and saved.memory_id == "clockwork_guard" and saved.player.max_health == 105 + int(saved.growth.ranks.get("vitality", 0)) * 20 + int(saved.growth.ranks.get("recovery", 0)) * 10 + int(saved.growth.ranks.get("vanguard_vigor", 0)) * 30 + int(saved.growth.ranks.get("tracker_breath", 0)) * 20, "성장 카드와 수호 체력 저장 공식 일치"): return
			for bad_id in [null, 1, [], ["clockwork_guard", "core_echo"], "unknown"]:
				var invalid := saved.duplicate(true)
				invalid.memory_id = bad_id
				if not _check(store.save_checkpoint(invalid) == ERR_INVALID_DATA, "미등록·복수·손상 기억 저장 거부"): return
			var doubled := saved.duplicate(true)
			doubled.player.max_health += 5
			if not _check(not RunCheckpointStore.valid_state(doubled), "수호 체력 중복 적용 저장 거부"): return
		"guard-resume":
			if not _check(controls.preferred_memory_id == "clockwork_guard" and player.damage_receiver.max_health == 100 and player.memory_id == "", "재실행은 선호 기억만 복원·전투 시작 전 체력 보너스 없음"): return
			var saved := store.load_checkpoint()
			if not _check(sandbox.continue_saved_run() and player.memory_id == "clockwork_guard" and player.damage_receiver.max_health == saved.player.max_health and player.damage_receiver.health == saved.player.health, "이어하기는 저장된 수호·체력 정확히 복원"): return
			if not _check(sandbox._claim_weapon_reward(""), "이어하기 장비 보상 유지 선택"): return
			sandbox._continue_stage("wind")
			if not _check(player.memory_id == "clockwork_guard" and player.damage_receiver.max_health == saved.player.max_health, "스테이지 전환에서 수호 보너스 재적용 없음"): return
			for stage in [2, 3]:
				if not _finish_stage(): return
				if stage == 2:
					if not _check(sandbox._claim_weapon_reward(""), "두 번째 장비 유지 선택"): return
					sandbox._continue_stage("meadow")
			if not _check(sandbox._resolve_boss_choice("destroy") and legacy.progress_snapshot().unlocked.size() == 2 and legacy.progress_snapshot().selected_memory == "clockwork_guard" and controls.current_result_snapshot().memory_id == "clockwork_guard", "반대 보스 선택 실제 완주로 두 기억 모두 해금·현재 장착 유지"): return
			var source := String(recorder.checkpoint_snapshot().id)
			if not _check(legacy.grant(source, "destroy") == OK and legacy.progress_snapshot().unlocked.size() == 2, "완주 중복 통지로 해금·능력 수치 누적 없음"): return
		"echo-start":
			if not _check(legacy.pending_reward().choice == "destroy" and controls.unlocked_memories.size() == 2, "재실행 양쪽 영구 기억·미사용 파괴 보상 유지"): return
			controls.show_start_weapon_selection()
			_tap(controls.memory_card_rects[2].get_center())
			legacy.fail_writes = true
			var before := FileAccess.get_file_as_string(GP111_LEGACY_PATH)
			_tap(controls.start_weapon_confirm_rect.get_center())
			if not _check(controls.current_screen_mode() == 2 and FileAccess.get_file_as_string(GP111_LEGACY_PATH) == before and legacy.pending_reward().choice == "destroy" and legacy.progress_snapshot().selected_memory == "clockwork_guard", "보상 소비·기억 선택 묶음 저장 실패는 둘 다 보존"): return
			legacy.fail_writes = false
			controls.show_start_weapon_selection()
			_tap(controls.memory_card_rects[2].get_center())
			_tap(controls.start_weapon_confirm_rect.get_center())
			if not _check(player.memory_id == "core_echo" and player.boss_legacy.choice == "destroy" and player.damage_receiver.max_health == 100 and player.growth_damage(100, "sword", "basic") == 110 and player.growth_damage(100, "sword", "skill") == 121 and player.growth_damage(100, "bow", "skill") == 121 and player.growth_damage(100, "sword", "ultimate") == 110 and legacy.pending_reward().is_empty(), "공격 기억·일회 핵 곱연산·스킬만 강화·수호 제거"): return
			weapons.set_equipment({"sword": 1, "bow": 0})
			if not _check(player.growth_damage(100, "sword", "skill") == 151 and player.growth_damage(100, "bow", "skill") == 127, "장비·보조 고유 효과·핵·기억 합성"): return
			weapons.set_equipment({"sword": 0, "bow": 0})
			if not _finish_stage(): return
			if not _check(store.load_checkpoint().memory_id == "core_echo", "공격 기억 중간 저장"): return
		"echo-resume":
			if not _check(controls.preferred_memory_id == "core_echo" and sandbox.continue_saved_run() and player.memory_id == "core_echo", "별도 프로세스 선호·도전 공격 기억 복원"): return
			var saved := store.load_checkpoint()
			var contents := FileAccess.get_file_as_string(GP111_SAVE_PATH)
			controls.show_main_screen()
			controls.show_start_weapon_selection()
			_tap(controls.memory_card_rects[1].get_center())
			_tap(controls.start_weapon_cancel_rect.get_center())
			if not _check(player.memory_id == "core_echo" and legacy.progress_snapshot().selected_memory == "core_echo" and FileAccess.get_file_as_string(GP111_SAVE_PATH) == contents, "다른 기억 선택 취소는 현재 도전·선호·체크포인트 유지"): return
			controls.show_start_weapon_selection()
			_tap(controls.memory_card_rects[0].get_center())
			_tap(controls.start_weapon_confirm_rect.get_center())
			if not _check(player.memory_id == "" and player.boss_legacy.is_empty() and player.damage_receiver.max_health == 100 and player.growth_damage(100, "sword", "skill") == 100 and legacy.progress_snapshot().unlocked.size() == 2, "기억 없이 새 도전·영구 해금은 유지·효과 초기화"): return
			# GP-105~110 형식에 기억 필드가 없으면 기존 효과를 추가하지 않는다.
			saved.erase("memory_id")
			if not _check(store.save_checkpoint(saved) == OK, "기억 필드 없는 이전 체크포인트 호환"): return
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and player.memory_id == "" and player.damage_receiver.max_health == saved.player.max_health, "이전 체크포인트 실제 이어하기에 기억 강제 적용 없음"): return
			var expected := roundi(100 * (1.0 + float(saved.player.common) + float(saved.player.sword)) * 1.10)
			if not _check(player.growth_damage(100, "sword", "skill") == expected, "이전 체크포인트는 일회 핵·카드만 적용"): return
			for ignored in 5:
				controls.show_main_screen()
				controls.show_start_weapon_selection()
				_tap(controls.memory_card_rects[1].get_center())
				_tap(controls.start_weapon_confirm_rect.get_center())
				if not _check(player.memory_id == "clockwork_guard" and player.damage_receiver.max_health == 105 and legacy.progress_snapshot().unlocked.size() == 2, "반복 도전 체력 +5 고정·두 능력 동시 장착 없음"): return
			recorder.clear_records()
			legacy._append({"event": "loadout", "run_id": "invalid", "memory_id": ["clockwork_guard", "core_echo"]})
			legacy._append({"event": "reward", "source": "invalid", "choice": "invalid"})
			if not _check(legacy.progress_snapshot().selected_memory == "clockwork_guard" and legacy.progress_snapshot().unlocked.size() == 2, "기록 초기화·잘못된 저널 이벤트는 선택·해금 유지"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-111 runtime test: OK (%s)" % mode)
	quit(0)

func _check(condition: bool, label: String) -> bool:
	if condition: return true
	push_error("GP-111 실패: %s" % label)
	paused = false
	quit(1)
	return false
