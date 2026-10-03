extends "res://tests/gp117_runtime_test.gd"

const GP118_SAVE := "user://gp118_checkpoint.json"
const GP118_META := "user://gp118_meta.jsonl"
const GP118_RECORD := "user://gp118_records.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP118_SAVE
	legacy.save_path = GP118_META
	if phase == "seed":
		store.clear_checkpoint()
		for path in [GP118_META, GP118_RECORD]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP118_RECORD
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	recorder = sandbox.get_node("LocalTestRecorder")
	var orbs: RecoveryOrbController = sandbox.get_node("RecoveryOrbController")
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	weapons.sword_combat.set_process(false)
	weapons.bow_combat.set_process(false)
	runner.set_process(false)
	player.set_physics_process(false)
	if phase == "seed":
		controls.begin_retry("sword")
		if not _check(is_equal_approx(orbs.drop_chance, 0.20), "일반 적 드롭 확률 20%"): return
		orbs.drop_chance = 0.0
		if not _step_section(): return
		_defeat(runner.leaf_slime)
		if not _check(orbs.drops == 0, "실제 처치의 미당첨 드롭 없음"): return
		orbs.drop_chance = 1.0
		runner.leaf_slime.defeated.emit(runner.leaf_slime)
		if not _check(orbs.drops == 0, "미당첨 처치도 생명당 한 번만 추첨"): return
		_defeat(runner.seed_sack)
		if not _resolve_growth(): return
		if not _check(orbs.drops == 1 and orbs.orbs.size() == 1, "성장 선택을 발생시킨 실제 처치도 구슬 생성"): return
		runner.seed_sack.defeated.emit(runner.seed_sack)
		if not _check(orbs.drops == 1, "중복 처치 신호는 추가 드롭 없음"): return
		player.global_position = orbs.orbs[0]
		player.damage_receiver.health = player.damage_receiver.max_health
		orbs._physics_process(0.02)
		if not _check(orbs.orbs.size() == 1 and orbs.collected == 0, "만피 구슬은 남김"): return
		_damage_player(50)
		var before := player.damage_receiver.health
		var hits := player.damage_receiver.applied_count
		var potion_count := player.potions_remaining
		player.begin_combat_action(0, false, false)
		orbs._physics_process(0.02)
		var expected := ceili(player.damage_receiver.max_health * 0.10)
		if not _check(player.damage_receiver.health == before + expected and orbs.collected == 1 and orbs.orbs.is_empty() and orbs.healed == expected and player.potions_remaining == potion_count and player.damage_receiver.applied_count == hits and player._combat_action_active, "근접 획득·10% 올림 회복·약 횟수/피격/공격 상태 보존"): return
		player.end_combat_action()
		orbs._physics_process(0.02)
		if not _check(player.damage_receiver.health == before + expected, "획득 구슬은 재회복 없음"): return
		if not _step_section() or not _step_section(): return
		_defeat(runner.leaf_slime)
		if not _resolve_growth(): return
		if not _check(orbs.drops == 2 and orbs.orbs.size() == 1, "다음 웨이브의 새 생명에서 두 번째 드롭"): return
		for enemy in [runner.seed_sack, runner.wind_spirit]:
			_defeat(enemy)
		if not _resolve_growth(): return
		if not _check(orbs.drops == 2, "남은 일반 적은 스테이지 2개 상한 유지"): return
		player.global_position = orbs.orbs[0] + Vector2(200, 0)
		orbs._physics_process(0.02)
		if not _check(orbs.orbs.size() == 1, "먼 구슬은 자동 회복 없음"): return
		player.global_position = orbs.orbs[0]
		player.damage_receiver.health = player.damage_receiver.max_health - 1
		player._fall_recovery_active = true
		orbs._physics_process(0.02)
		player._fall_recovery_active = false
		player.damage_receiver.dead = true
		orbs._physics_process(0.02)
		player.damage_receiver.dead = false
		paused = true
		orbs._physics_process(0.02)
		paused = false
		controls.open_layout_editor()
		if not _check(controls.start_layout_test(), "조작 배치 연습 진입"): return
		orbs._physics_process(0.02)
		if not _check(orbs.orbs.size() == 1 and player.damage_receiver.health == player.damage_receiver.max_health - 1 and not orbs.visible, "낙하·사망·일시정지·배치 연습 중 획득 차단·구슬 숨김"): return
		controls.finish_layout_test()
		controls.cancel_layout_editor()
		# 배치 연습 복귀 카운트다운도 획득을 막는다.
		orbs._physics_process(0.02)
		if not _check(orbs.orbs.size() == 1, "복귀 카운트다운 중 획득 차단"): return
		controls._process(3.1)
		orbs._physics_process(0.02)
		if not _check(player.damage_receiver.health == player.damage_receiver.max_health and orbs.collected == 2 and orbs.orbs.is_empty(), "복귀 후 실제 획득·최대 체력 상한"): return
		orbs.queue_redraw()
		await process_frame
		if not _test_surfaces(orbs): return
		orbs.drop_chance = 0.0
		if not _finish_stage(): return
		_tap(controls.weapon_reward_skip_rect.get_center())
		var saved := store.load_checkpoint()
		if not _check(not saved.is_empty() and saved.player.health == player.damage_receiver.health, "구슬 회복 결과는 기존 중간 저장에 반영"): return
		orbs.orbs.append(Vector2(4000, 808))
		player.global_position = orbs.orbs[0]
		var health := player.damage_receiver.health
		orbs._physics_process(0.02)
		if not _check(orbs.orbs.size() == 1 and player.damage_receiver.health == health, "스테이지 완료·보상 선택에서 획득 없음"): return
	elif phase == "resume":
		var saved := store.load_checkpoint()
		if not _check(sandbox.continue_saved_run() and player.damage_receiver.health == int(saved.player.health) and orbs.orbs.is_empty(), "별도 프로세스 이어하기에서 회복 보존·구슬 재생성 없음"): return
		_tap(controls.stage_route_rects[1].get_center())
		if not _check(runner.stage_number == 2 and orbs.drops == 0 and orbs.collected == 0 and orbs.orbs.is_empty(), "다음 스테이지에만 상한 초기화"): return
		orbs.drop_chance = 1.0
		if not _step_section(): return
		_defeat(runner.leaf_slime)
		if not _resolve_growth(): return
		if not _check(orbs.drops == 1, "이어간 스테이지 실제 적 드롭"): return
		controls.begin_retry("bow")
		if not _check(orbs.orbs.is_empty() and orbs.drops == 0 and player.damage_receiver.health == 100 and player.potions_remaining == 2, "새 도전은 구슬·집계·체력 초기화"): return
		if not _step_section(): return
		_defeat(runner.leaf_slime)
		if not _resolve_growth(): return
		_damage_player(9999)
		if not _check(player.damage_receiver.dead and orbs.orbs.is_empty() and not player.collect_recovery_orb(), "실제 사망은 구슬 제거·부활 없음"): return
	else:
		_check(false, "알 수 없는 단계")
		return
	paused = false
	sandbox.free()
	print("GP-118 runtime test: OK (" + phase + ")")
	quit(0)

func _test_surfaces(orbs: RecoveryOrbController) -> bool:
	for route in ["meadow", "wind", "clockwork"]:
		runner.route_terrain.configure(2, route)
		for origin in [Vector2(1900, 540), Vector2(3500, 480), Vector2(4380, 540)]:
			var point := orbs.drop_position(origin)
			var surfaces: Array[Rect2] = [sandbox.LEFT_FLOOR_RECT, sandbox.RIGHT_FLOOR_RECT, sandbox.PRACTICE_PLATFORM_RECT]
			surfaces.append_array(runner.route_terrain.platforms)
			var on_surface := false
			for rect in surfaces:
				if point.x >= rect.position.x + 36 and point.x <= rect.end.x - 36 and is_equal_approx(point.y, rect.position.y - 32):
					on_surface = true
			if not _check(on_surface, "세 경로의 공중·구덩이 드롭은 실제 지면 위"): return false
		runner.route_terrain.configure(1, "meadow")
	return true
