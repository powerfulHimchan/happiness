extends "res://tests/gp127_runtime_test.gd"

const GP129_SAVE := "user://gp129_checkpoint.json"
const GP129_META := "user://gp129_meta.jsonl"
const GP129_RECORD := "user://gp129_records.jsonl"
var ultimate: UltimateController

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP129_SAVE
	legacy.save_path = GP129_META
	if phase == "seed":
		store.clear_checkpoint()
		for path in [GP129_META, GP129_RECORD]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP129_RECORD
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	recorder = sandbox.get_node("LocalTestRecorder")
	ultimate = sandbox.get_node("Player/UltimateController")
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	weapons.sword_combat.set_physics_process(false)
	weapons.bow_combat.set_physics_process(false)
	weapons.sword_combat.set_process(false)
	weapons.bow_combat.set_process(false)
	player.set_physics_process(false)
	runner.set_process(false)
	match phase:
		"seed":
			controls.begin_retry()
			if not _reach_relic_reward(): return
			var saved := store.load_checkpoint()
			if not await _test_relic_layout(): return
			if not _check(store.load_checkpoint() == saved and player.relic_state.is_empty() and player.skill_recharge_multiplier() == 1, "비교·취소는 유물·저장·효과 변화 없음"): return
			_tap(controls.relic_reward_open_rect.get_center())
			if not _check(controls.selected_relic_offer == 0 and not sandbox._claim_relic_reward("unknown"), "재조회 기본 깃털·알 수 없는 유물 지급 차단"): return
			_tap(controls.relic_reward_card_rects[1].get_center())
			_set_timers()
			var before := weapons.checkpoint_snapshot()
			var health := player.damage_receiver.health
			var potions := player.potions_remaining
			var gauge := ultimate.gauge
			store.save_path = "user://gp129_missing/checkpoint.json"
			_tap(controls.relic_reward_confirm_rect.get_center())
			store.save_path = GP129_SAVE
			if not _check(controls.current_screen_mode() == 15 and controls.selected_relic_offer == 1 and player.relic_state.is_empty() and player.skill_recharge_multiplier() == 1 and weapons.checkpoint_snapshot() == before and store.load_checkpoint() == saved, "선택 저장 실패는 효과·쿨다운·정상 파일 보존·재시도 가능"): return
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(controls.current_screen_mode() == 9 and player.relic_state == {"id": PrototypeRelic.CLOCK_ID, "used": false} and player.skill_recharge_multiplier() == 1.25 and not controls.relic_offer_available and weapons.checkpoint_snapshot() == before and store.load_checkpoint().weapons == JSON.parse_string(JSON.stringify(before)), "시계추 실제 확정·하나만 획득·원본 쿨다운 저장: %s" % [str([controls.current_screen_mode(), player.relic_state, player.skill_recharge_multiplier(), controls.relic_offer_available, weapons.checkpoint_snapshot() == before, store.load_checkpoint().weapons == JSON.parse_string(JSON.stringify(before))])]): return
			if not _check(player.damage_receiver.health == health and player.potions_remaining == potions and ultimate.gauge == gauge and not sandbox._claim_relic_reward() and String(controls.movement_metrics.relic_hud).contains("-20%"), "깃털 중복 획득 차단·체력/회복약/필살기 유지·HUD"): return
			if not _check(_real_timers_match(), "양 무기 네 슬롯 실제 남은 시간 HUD"): return
			var valid := store.load_checkpoint()
			for relic in [{"id": PrototypeRelic.CLOCK_ID, "used": true}, {"id": PrototypeRelic.CLOCK_ID, "used": 0}, {"id": 3, "used": false}, {"id": "unknown", "used": false}, {"id": PrototypeRelic.CLOCK_ID, "used": false, "extra": 1}]:
				var bad := valid.duplicate(true)
				bad.relic = relic
				if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == valid, "잘못된 시계추 상태 거부·정상 저장 보호"): return
			_tap(controls.skill_reward_open_rect.get_center())
			if not _check(controls.skill_reward_offers[2].lines[0].begins_with("재사용 9.6초"), "일섬 후보 비교도 실제 12→9.6초"): return
			_tap(controls.skill_reward_offer_rects[2].get_center())
			_tap(controls.skill_reward_slot_rects[1].get_center())
			controls.queue_redraw()
			await process_frame
			_tap(controls.skill_reward_cancel_rect.get_center())
			if not _check(store.load_checkpoint() == valid and weapons.checkpoint_snapshot() == before, "유물 획득 뒤 스킬 조회 취소는 구성·쿨다운 보존"): return
		"resume":
			var saved := store.load_checkpoint()
			if not _check(legacy.spend_phoenix(String(saved.recorder.id)) == OK, "동일 도전 깃털 소비 저널 준비"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and player.relic_state == {"id": PrototypeRelic.CLOCK_ID, "used": false} and player.skill_recharge_multiplier() == 1.25 and JSON.parse_string(JSON.stringify(weapons.checkpoint_snapshot())) == saved.weapons and _real_timers_match(), "별도 프로세스·반복 이어하기 원본 대기시간·20% 유지·깃털 저널 독립"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _check(runner.stage_number == 3 and player.skill_recharge_multiplier() == 1.25 and _real_timers_match(), "보스 경로 진입은 유물·대기시간 초기화 없음"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and player.skill_recharge_multiplier() == 1.25, "시계추 보스 완주 준비"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage(): return
			if not _check(sandbox._resolve_boss_choice("rescue") and store.load_checkpoint().is_empty(), "시계추 실제 보스 완주·저장 정리"): return
			controls.begin_retry()
			if not _check(player.relic_state.is_empty() and player.skill_recharge_multiplier() == 1 and weapons.sword_combat._skill_1_cooldown_s == 0, "새 도전 유물·배율·대기시간 초기화"): return
			if not _reach_relic_reward(): return
			var old := store.load_checkpoint()
			old.erase("relic")
			if not _check(store.save_checkpoint(old) == OK, "유물 필드 없는 이전 저장 준비"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and player.relic_state.is_empty() and player.skill_recharge_multiplier() == 1, "이전 저장 유물 없음·기본 속도 호환"): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[0].get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(player.relic_state.id == PrototypeRelic.PHOENIX_ID and player.skill_recharge_multiplier() == 1, "첫 후보 깃털 실제 선택·시계추 효과 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			player.damage_receiver.tick(2)
			_hit_player(9999, "legacy-feather")
			if not _check(not player.damage_receiver.dead and player.relic_state.used and player.damage_receiver.health == ceili(player.damage_receiver.max_health * 0.5) and legacy.phoenix_used(player.relic_run_id), "깃털 50% 부활·소비 저널 기존 동작 유지"): return
		"combat":
			controls.begin_retry()
			if not _reach_relic_reward(): return
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[1].get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			weapons.sword_combat._skill_2_cooldown_s = 18
			_tap(controls.skill_reward_open_rect.get_center())
			_select_offer("sword_line", 1)
			_tap(controls.skill_reward_confirm_rect.get_center())
			if not _check(weapons.skills.sword[1] == "sword_line" and weapons.sword_combat._skill_2_cooldown_s == 18 and is_equal_approx(weapons.sword_combat.current_metrics().skill_2_cooldown_s, 14.4) and store.load_checkpoint().weapons.sword._skill_2_cooldown_s == 18, "시계추 획득 후 스킬 교체도 긴 원본 대기시간 유지·실제 표시·저장"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _test_timer_speed(): return
			if not await _test_tactical_combat(): return
			if not _check(player.skill_recharge_multiplier() == 1.25 and is_equal_approx(weapons.bow_combat.current_metrics().skill_1_cooldown_s, 8), "집중 실제 시전 10초는 HUD 8초·전환 후 배율 유지"): return
			player.damage_receiver.tick(2)
			var run_id := player.relic_run_id
			_hit_player(9999, "clock-is-not-phoenix")
			if not _check(player.damage_receiver.dead and not player.relic_state.used and not legacy.phoenix_used(run_id) and store.load_checkpoint().is_empty(), "시계추 치명타는 정상 사망·부활 및 깃털 소비 없음"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-129 runtime test: OK (" + phase + ")")
	quit(0)

func _reach_relic_reward() -> bool:
	if not _finish_stage(): return false
	_tap(controls.weapon_reward_skip_rect.get_center())
	if not _check(not controls.relic_offer_available, "첫 정예 유물 없음"): return false
	_tap(controls.stage_route_rects[1].get_center())
	if not _finish_stage(): return false
	_tap(controls.weapon_reward_skip_rect.get_center())
	return _check(runner.stage_number == 2 and controls.current_screen_mode() == 9 and controls.relic_offer_available, "두 번째 정예 실제 유물 선택 가능")

func _test_relic_layout() -> bool:
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_stage_routes()
		_tap(controls.relic_reward_open_rect.get_center())
		controls._refresh_relic_reward_layout()
		var rects: Array = controls.relic_reward_card_rects.duplicate()
		if not _check(rects.size() == PrototypeRelic.OFFERS.size(), "전체 유물 후보 표시"): return false
		rects.append_array([controls.relic_reward_confirm_rect, controls.relic_reward_cancel_rect])
		var safe: Rect2 = controls.layout_snapshot().safe
		for i in rects.size():
			if not _check(safe.encloses(rects[i]), "두 화면비 유물·확정·취소 안전 영역"): return false
			for j in range(i + 1, rects.size()):
				if not _check(not rects[i].intersects(rects[j]), "두 후보·확정·취소 입력 비중첩"): return false
		for i in PrototypeRelic.OFFERS.size():
			_tap(controls.relic_reward_card_rects[i].get_center())
			if not _check(controls.selected_relic_offer == i, "실제 카드 터치 선택"): return false
			controls.queue_redraw()
			await process_frame
		_tap(controls.relic_reward_cancel_rect.get_center())
	return true

func _set_timers() -> void:
	weapons.sword_combat._skill_1_cooldown_s = 10
	weapons.sword_combat._skill_2_cooldown_s = 7
	weapons.bow_combat._skill_1_cooldown_s = 12
	weapons.bow_combat._skill_2_cooldown_s = 8

func _real_timers_match() -> bool:
	var sword := weapons.sword_combat.current_metrics()
	var bow := weapons.bow_combat.current_metrics()
	return is_equal_approx(sword.skill_1_cooldown_s, 8) and is_equal_approx(sword.skill_2_cooldown_s, 5.6) and is_equal_approx(bow.skill_1_cooldown_s, 9.6) and is_equal_approx(bow.skill_2_cooldown_s, 6.4) and is_equal_approx(controls.movement_metrics.sword_skill_1_cooldown_s, 8)

func _test_timer_speed() -> bool:
	var sword := weapons.sword_combat
	var bow := weapons.bow_combat
	for target in get_nodes_in_group("targetable"): target.visible = false
	for combat in [sword, bow]:
		combat.set_active(false)
		combat._basic_remaining_s = 10
		combat._skill_1_cooldown_s = 10
		combat._skill_2_cooldown_s = 10
	player.relic_state = {}
	sword._physics_process(1)
	bow._physics_process(1)
	if not _check(sword._skill_1_cooldown_s == 9 and bow._skill_2_cooldown_s == 9, "유물 없는 기준 대기시간 1배"): return false
	player.relic_state = {"id": PrototypeRelic.CLOCK_ID, "used": false}
	player._evade_cooldown_remaining_s = 10
	ultimate.gauge = 37
	for combat in [sword, bow]:
		combat._skill_1_cooldown_s = 10
		combat._skill_2_cooldown_s = 10
		combat._physics_process(7.99)
		if not _check(combat._skill_1_cooldown_s > 0 and combat._skill_2_cooldown_s > 0 and is_equal_approx(combat._basic_remaining_s, 1.01), "보조 무기 포함 두 슬롯 8초 직전·기본 공격 원래 속도"): return false
		combat._physics_process(0.011)
		if not _check(combat._skill_1_cooldown_s == 0 and combat._skill_2_cooldown_s == 0, "실제 8초 만에 재사용 가능·0 하한"): return false
		combat._physics_process(100)
		if not _check(combat._skill_1_cooldown_s == 0 and combat._skill_2_cooldown_s == 0, "긴 프레임 음수 없음"): return false
	player._update_mobility_timers(1)
	if not _check(player._evade_cooldown_remaining_s == 9 and ultimate.gauge == 37, "회피 대기 원래 속도·필살기 게이지 독립"): return false
	player._evade_cooldown_remaining_s = 0
	weapons.active_weapon_id = "sword"
	weapons._apply_active_weapon()
	return true

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-129 failed: " + message)
		paused = false
		quit(1)
	return condition
