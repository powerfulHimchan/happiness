extends "res://tests/gp117_runtime_test.gd"

const GP119_SAVE := "user://gp119_checkpoint.json"
const GP119_META := "user://gp119_meta.jsonl"
const GP119_RECORD := "user://gp119_records.jsonl"
var phoenix_count: int = 0
var death_count: int = 0

class FailingCheckpointStore extends RunCheckpointStore:
	var fail_writes: bool = false
	func _write(path: String, contents: String) -> Error:
		return ERR_CANT_CREATE if fail_writes else super._write(path, contents)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	var checked_store := FailingCheckpointStore.new()
	store = checked_store
	store.save_path = GP119_SAVE
	legacy.save_path = GP119_META
	if phase == "seed":
		store.clear_checkpoint()
		for path in [GP119_META, GP119_RECORD]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP119_RECORD
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	recorder = sandbox.get_node("LocalTestRecorder")
	player.phoenix_revived.connect(func(): phoenix_count += 1)
	player.player_died.connect(func(): death_count += 1)
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	weapons.sword_combat.set_process(false)
	weapons.bow_combat.set_process(false)
	runner.set_process(false)
	player.set_physics_process(false)
	match phase:
		"seed":
			controls.begin_retry("sword")
			if not _reach_feather_reward(): return
			for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
				controls.size = dimensions
				controls._refresh_stage_routes()
				var safe: Rect2 = controls.layout_snapshot().safe
				if not _check(safe.encloses(controls.relic_reward_open_rect) and not controls.relic_reward_open_rect.intersects(controls.skill_reward_open_rect), "두 화면비 유물·스킬 버튼 안전 영역·비중첩"): return
				_tap(controls.relic_reward_open_rect.get_center())
				controls._refresh_relic_reward_layout()
				for rect in [controls.relic_reward_card_rect, controls.relic_reward_confirm_rect, controls.relic_reward_cancel_rect]:
					if not _check(safe.encloses(rect), "유물 카드·확정·취소 안전 영역"): return
				controls.queue_redraw()
				await process_frame
				_tap(controls.relic_reward_cancel_rect.get_center())
				if not _check(controls.current_screen_mode() == 9 and player.relic_state.is_empty(), "나중에 선택은 획득·소비 없음"): return
			_tap(controls.relic_reward_open_rect.get_center())
			var saved := store.load_checkpoint()
			var health := player.damage_receiver.health
			checked_store.fail_writes = true
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(controls.current_screen_mode() == 15 and player.relic_state.is_empty() and store.load_checkpoint() == saved and player.damage_receiver.health == health, "획득 저장 실패는 상태·건강·기존 저장 롤백"): return
			checked_store.fail_writes = false
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(controls.current_screen_mode() == 9 and not controls.relic_offer_available and player.relic_state == {"id": PrototypeRelic.PHOENIX_ID, "used": false} and store.load_checkpoint().relic == player.relic_state and player.damage_receiver.health == health, "실제 터치 확정은 1개 획득·체력 유지·원자적 저장"): return
			if not _check(not sandbox._claim_relic_reward(), "획득 중복 호출 차단"): return
			var valid := store.load_checkpoint()
			for relic in [null, "phoenix_feather", {"id": "other", "used": false}, {"id": PrototypeRelic.PHOENIX_ID, "used": 0}, {"id": PrototypeRelic.PHOENIX_ID}, {"id": PrototypeRelic.PHOENIX_ID, "used": false, "extra": 1}]:
				var bad := valid.duplicate(true)
				bad.relic = relic
				if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == valid, "잘못된 유물 저장 거부·정상 파일 보호"): return
		"resume":
			if not _check(sandbox.continue_saved_run() and not player.relic_state.used and not controls.relic_offer_available and player.relic_run_id == String(store.load_checkpoint().recorder.id), "별도 프로세스 미사용 유물 복원"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _check(runner.stage_number == 3 and controls.current_screen_mode() == 0, "유물을 가지고 보스 스테이지 진입"): return
			if not _test_locked_revival(): return
			player.damage_receiver.health = 10
			player.damage_receiver.tick(2.0)
			weapons.sword_combat._skill_1_cooldown_s = 3.5
			weapons.bow_combat._skill_2_cooldown_s = 4.75
			player.begin_combat_action(400, false, false)
			var potion_count := player.potions_remaining
			var xp := growth.total_experience
			var fatal := _hit_player(9999, "phoenix-fatal")
			var expected := ceili(player.damage_receiver.max_health * 0.50)
			if not _check(not player.damage_receiver.dead and player.damage_receiver.health == expected and player.relic_state.used and phoenix_count == 1 and death_count == 0 and growth.run_active and growth.total_experience == xp and player.potions_remaining == potion_count and not player._combat_action_active and is_equal_approx(player.damage_receiver.post_hit_remaining_s(), 1.0), "실제 치명타는 50% 올림 부활·1초 보호·사망/보상/회복약 유지"): return
			if not _check(is_equal_approx(weapons.sword_combat._skill_1_cooldown_s, 3.5) and is_equal_approx(weapons.bow_combat._skill_2_cooldown_s, 4.75), "부활은 양 무기 대기시간 보존"): return
			player.receive_damage(fatal)
			if not _check(player.damage_receiver.health == expected and player.damage_receiver.duplicate_blocked_count == 1, "치명타 이벤트 재전달은 피해·부활 중복 없음"): return
			_hit_player(20, "protected-after-revive")
			if not _check(player.damage_receiver.health == expected and phoenix_count == 1, "연속 다른 피격도 1초 보호"): return
			if not _check(legacy.phoenix_used(player.relic_run_id) and not store.load_checkpoint().relic.used, "중간 저장보다 최신인 소비 저널 기록"): return
			recorder.clear_records()
			if not _check(legacy.phoenix_used(player.relic_run_id) and not store.load_checkpoint().relic.used, "진단 기록 초기화는 부활 소비·완료 지점 저장 유지"): return
		"spent":
			if not _check(sandbox.continue_saved_run() and player.relic_state.used and String(controls.movement_metrics.relic_hud).contains("사용 완료"), "이전 미사용 체크포인트도 소비 저널로 복원"): return
			_tap(controls.stage_route_rects[0].get_center())
			player.damage_receiver.tick(2.0)
			_hit_player(9999, "spent-fatal")
			if not _check(player.damage_receiver.dead and death_count == 1 and phoenix_count == 0 and store.load_checkpoint().is_empty(), "사용한 깃털은 재부활 없음·정상 사망·저장 삭제"): return
			controls.begin_retry("bow")
			if not _check(player.relic_state.is_empty() and not legacy.phoenix_used(player.relic_run_id) and player.damage_receiver.health == 100, "새 도전은 유물 초기화·이전 도전 소비 독립"): return
			if not _reach_feather_reward(): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			_tap(controls.stage_route_rects[1].get_center())
			legacy.fail_writes = true
			_hit_player(9999, "consume-write-failure")
			if not _check(player.damage_receiver.dead and not player.relic_state.used and phoenix_count == 0 and not legacy.phoenix_used(player.relic_run_id), "사용 기록 쓰기 실패는 무상 부활·잘못된 소비 없음"): return
			legacy.fail_writes = false
			controls.begin_retry()
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			var old := store.load_checkpoint()
			old.erase("relic")
			if not _check(store.save_checkpoint(old) == OK, "유물 필드 없는 이전 저장 준비"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and player.relic_state.is_empty(), "GP-118 이전 저장은 유물 없는 상태로 호환"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			_tap(controls.stage_route_rects[0].get_center())
			if not _check(player.relic_state.is_empty(), "선택을 건너뛰면 유물 자동 지급 없음"): return
			if not _finish_stage(): return
			if not _check(sandbox._resolve_boss_choice("destroy") and not growth.run_active and recorder.has_completed_run(player.relic_run_id), "유물 없이 실제 보스 완주와 파괴 보상 유지"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-119 runtime test: OK (" + phase + ")")
	quit(0)

func _reach_feather_reward() -> bool:
	if not _finish_stage(): return false
	_tap(controls.weapon_reward_skip_rect.get_center())
	if not _check(not controls.relic_offer_available, "첫 정예는 유물 보상 없음"): return false
	_tap(controls.stage_route_rects[1].get_center())
	if not _finish_stage(): return false
	_tap(controls.weapon_reward_skip_rect.get_center())
	return _check(runner.stage_number == 2 and controls.current_screen_mode() == 9 and controls.relic_offer_available, "두 번째 정예 완료에 유물 선택 가능")

func _test_locked_revival() -> bool:
	player.damage_receiver.dead = true
	for mode in [2, 3, 4, 5, 7, 8, 9, 13, 15]:
		controls.screen_mode = mode
		if not _check(not player._try_phoenix_revival() and not player.relic_state.used, "비전투 화면에서는 깃털 소비 없음"): return false
	controls.screen_mode = 0
	paused = true
	if not _check(not player._try_phoenix_revival() and not player.relic_state.used, "일시정지 중 깃털 소비 없음"): return false
	paused = false
	player.damage_receiver.dead = false
	return _check(not player._try_phoenix_revival() and not player.relic_state.used, "치명타 없는 호출에서는 깃털 소비 없음")
