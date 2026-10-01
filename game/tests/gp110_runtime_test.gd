extends "res://tests/gp109_runtime_test.gd"

const LEGACY_PATH := "user://gp110_boss_legacy.jsonl"
const GP110_SAVE_PATH := "user://gp110_checkpoint.json"
const GP110_RECORD_PATH := "user://gp110_records.jsonl"
var legacy := FailingLegacyStore.new()

class FailingLegacyStore extends BossLegacyStore:
	var fail_writes: bool = false
	func _append(event: Dictionary) -> Error:
		return ERR_CANT_CREATE if fail_writes else super._append(event)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if not args.is_empty() else "reward-seed"
	store.save_path = GP110_SAVE_PATH
	legacy.save_path = LEGACY_PATH
	if mode == "reward-seed":
		store.clear_checkpoint()
		for path in [GP110_RECORD_PATH, LEGACY_PATH]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP110_RECORD_PATH
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
		"reward-seed":
			if not _reach_boss() or not _finish_stage(): return
			if not _check(sandbox._resolve_boss_choice("rescue") and legacy.pending_reward().choice == "rescue", "보스 구출 완료가 독립 보상 저장으로 연결됨"): return
			var source := String(recorder.checkpoint_snapshot().id)
			if not _check(legacy.grant(source, "rescue") == OK and legacy.grant(source, "destroy") == ERR_INVALID_DATA, "동일 완주 중복·선택 변경 차단"): return
			recorder.clear_records()
			if not _check(legacy.pending_reward().source == source, "테스트 기록 초기화는 보상을 지우지 않음"): return
		"rescue-start":
			if not _check(legacy.pending_reward().choice == "rescue", "앱 종료 후 구출 보상 유지"): return
			controls.show_main_screen()
			controls.show_start_weapon_selection()
			for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
				controls.size = dimensions
				controls._refresh_start_weapon_layout()
				var safe: Rect2 = controls.layout_snapshot().safe
				if not _check(safe.encloses(controls.boss_legacy_toggle_rect) and not controls.boss_legacy_toggle_rect.intersects(controls.start_weapon_card_rects[0]) and not controls.boss_legacy_toggle_rect.intersects(controls.start_weapon_confirm_rect), "두 화면 비율 보상 토글 안전 영역·입력 겹침 없음"): return
			_tap(controls.boss_legacy_toggle_rect.get_center())
			_tap(controls.start_weapon_cancel_rect.get_center())
			if not _check(not legacy.pending_reward().is_empty(), "선택 취소는 보상을 소비하지 않음"): return
			controls.show_start_weapon_selection()
			_tap(controls.start_weapon_card_rects[1].get_center())
			_tap(controls.start_weapon_confirm_rect.get_center())
			if not _check(player.boss_legacy.choice == "rescue" and player.damage_receiver.max_health == 110 and player.damage_receiver.health == 110 and weapons.active_weapon_id == "bow" and player.growth_damage(100, "bow") == 100 and legacy.pending_reward().is_empty(), "확정 시작에서만 소비·체력 +10·공격 유지"): return
			if not _reach_elite(): return
			var elite := runner.final_enemy()
			if not _check(elite.damage_receiver.health == elite.damage_receiver.max_health - 20 and player.boss_legacy.assisted_stages == [1], "정예 등장 자동 지원 피해 20"): return
			runner.force_emit_metrics()
			if not _check(elite.damage_receiver.health == elite.damage_receiver.max_health - 20, "정예 지원 중복 없음"): return
			if not _finish_stage(): return
			var saved := store.load_checkpoint()
			if not _check(not saved.is_empty() and saved.boss_legacy.choice == "rescue" and not saved.boss_legacy.rescue_used, "보너스 포함 정상 중간 저장"): return
			for malformed in [null, [], {"choice": "invalid"}, {"choice": "rescue", "source_run": "x", "run_id": "wrong", "rescue_used": false, "assisted_stages": []}]:
				var bad := saved.duplicate(true)
				bad.boss_legacy = malformed
				if not _check(not RunCheckpointStore.valid_state(bad), "손상 효과·도전 식별자 불일치 차단"): return
			var bad := saved.duplicate(true)
			bad.player.max_health += 10
			if not _check(not RunCheckpointStore.valid_state(bad), "체력 보너스 중복·변조 차단"): return
			if not _test_rescue_heal(): return
			if not _check(not store.load_checkpoint().boss_legacy.rescue_used and player.boss_legacy.rescue_used, "이전 체크포인트보다 구조 사용 기록이 최신인 종료 상황"): return
			if not _check(legacy.grant("gp110-destroy-source", "destroy") == OK, "별도 다음 보상 준비"): return
		"rescue-resume":
			if not _check(sandbox.continue_saved_run() and player.boss_legacy.choice == "rescue" and player.boss_legacy.rescue_used and legacy.pending_reward().choice == "destroy", "이어하기는 소비 없이 기존 효과·최신 구조 사용 복원"): return
			player.damage_receiver.health = 30
			player.damage_receiver.tick(1.0)
			_hit_player(10, "after-resume")
			if not _check(player.damage_receiver.health == 20, "이전 체크포인트로 구조 1회가 부활하지 않음"): return
			player.damage_receiver.tick(1.0)
			_hit_player(9999, "lethal")
			if not _check(player.damage_receiver.dead and store.load_checkpoint().is_empty(), "사망을 되돌리지 않고 완료 저장 삭제"): return
		"destroy-start":
			controls.show_main_screen()
			controls.show_start_weapon_selection()
			_tap(controls.start_weapon_confirm_rect.get_center())
			if not _check(player.boss_legacy.choice == "destroy" and player.damage_receiver.max_health == 100 and player.growth_damage(100, "sword") == 110 and player.growth_damage(100, "bow", "skill") == 110 and player.growth_damage(100, "sword", "ultimate") == 110, "핵은 모든 공격 +10%·체력 초기화"): return
			var event := _hit_player(10, "risk")
			if not _check(player.damage_receiver.health == 89 and event.damage == 10, "받는 전투 피해 +10%·원본 이벤트 보존"): return
			player.receive_damage(event)
			if not _check(player.damage_receiver.health == 89, "위험 피해에도 중복 타격 방지"): return
			weapons.set_equipment({"sword": 1, "bow": 0})
			if not _check(player.growth_damage(100, "sword", "skill") == 138, "장비 고유 효과와 핵 보너스 곱연산"): return
			weapons.set_equipment({"sword": 0, "bow": 0})
			if not _finish_stage(): return
			if not _check(store.load_checkpoint().boss_legacy.choice == "destroy", "핵 효과 중간 저장"): return
		"destroy-resume":
			if not _check(sandbox.continue_saved_run() and player.boss_legacy.choice == "destroy" and legacy.pending_reward().is_empty(), "재실행 핵 효과 복원·재지급 없음"): return
			controls.begin_retry()
			if not _check(player.boss_legacy.is_empty() and player.damage_receiver.max_health == 100 and player.growth_damage(100, "sword") == 100, "다음 새 도전은 효과·장비·성장 초기화"): return
			if not _check(legacy.grant("gp110-skip-source", "rescue") == OK, "건너뛰기 보상 준비"): return
			sandbox._update_boss_legacy_status()
			controls.show_main_screen()
			controls.show_start_weapon_selection()
			_tap(controls.boss_legacy_toggle_rect.get_center())
			_tap(controls.start_weapon_confirm_rect.get_center())
			if not _check(player.boss_legacy.is_empty() and legacy.pending_reward().is_empty() and legacy.grant("gp110-skip-source", "rescue") == OK and legacy.pending_reward().is_empty(), "보상 건너뛰기는 1회 기회 소비·재완주 통지로 부활 없음"): return
			var file := FileAccess.open(LEGACY_PATH, FileAccess.READ_WRITE)
			file.seek_end()
			file.store_string("interrupted trailing record")
			file.close()
			if not _check(legacy.grant("gp110-failure-source", "rescue") == OK and legacy.pending_reward().source == "gp110-failure-source", "손상 마지막 줄 무시·뒤따른 정상 보상 복원"): return
			legacy.fail_writes = true
			controls.use_boss_legacy = true
			var run_id := String(recorder.checkpoint_snapshot().id)
			controls.begin_retry()
			if not _check(controls.current_screen_mode() == 2 and player.boss_legacy.is_empty() and legacy.pending_reward().choice == "rescue" and String(recorder.checkpoint_snapshot().id) == run_id, "소비 저장 실패는 기존 상태·미사용 보상 보존"): return
			legacy.fail_writes = false
			controls.begin_retry()
			if not _check(player.boss_legacy.choice == "rescue" and legacy.pending_reward().is_empty(), "실패 후 재시도는 한 번만 보상 적용"): return
			legacy.fail_writes = true
			player.damage_receiver.health = 30
			_hit_player(10, "heal-failure")
			if not _check(player.damage_receiver.health == 20 and not player.boss_legacy.rescue_used, "구조 저장 실패는 회복·사용 상태 변경 없음"): return
			legacy.fail_writes = false
			player.damage_receiver.tick(1.0)
			_hit_player(1, "heal-retry")
			if not _check(player.damage_receiver.health == 52 and player.boss_legacy.rescue_used, "구조 저장 재시도 성공 후 회복 33"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-110 runtime test: OK (%s)" % mode)
	quit(0)

func _reach_elite() -> bool:
	for ignored in 8:
		if runner.current_section == PrototypeStageRunner.Section.ELITE: return true
		if not _step_section(): return false
	return _check(false, "정예 진입 실패")

func _test_rescue_heal() -> bool:
	var maximum := player.damage_receiver.max_health
	player.damage_receiver.health = floori(maximum * 0.25) + 5
	player.damage_receiver.tick(1.0)
	var event := _hit_player(5, "rescue")
	var expected := floori(maximum * 0.25) + ceili(maximum * 0.30)
	if not _check(player.damage_receiver.health == expected and player.boss_legacy.rescue_used, "25% 이하 비치명타 뒤 최대 체력 30% 구조 회복"): return false
	player.receive_damage(event)
	return _check(player.damage_receiver.health == expected, "구조 뒤 같은 타격·회복 중복 없음")

func _hit_player(amount: int, id: String) -> DamageEvent:
	var event := DamageEvent.new()
	event.event_id = StringName("gp110:" + id)
	event.attacker_id = &"enemy"
	event.damage = amount
	event.tags = PackedStringArray(["enemy", "test"])
	player.receive_damage(event)
	return event
