extends SceneTree

const SANDBOX_SCENE := preload("res://scenes/movement/ground_movement_sandbox.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sandbox := SANDBOX_SCENE.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	(sandbox.get_node("StageRunner") as PrototypeStageRunner).stage_limit = 1
	root.add_child(sandbox)
	var runner := sandbox.get_node("StageRunner") as PrototypeStageRunner
	var player := sandbox.get_node("Player") as PrototypePlayer
	var slime := sandbox.get_node("Targets/LeafSlime") as PrototypeEnemy
	var seed_sack := sandbox.get_node("Targets/SeedSack") as PrototypeEnemy
	var wind_spirit := sandbox.get_node("Targets/WindSpirit") as PrototypeEnemy
	var boar := sandbox.get_node("Targets/ArmoredBoar") as EliteArmoredBoar
	(sandbox.get_node("Player/SwordCombatController") as SwordCombatController).set_process(false)
	(sandbox.get_node("Player/BowCombatController") as BowCombatController).set_process(false)
	await process_frame
	await physics_frame

	if not _assert_equal(runner.current_section, PrototypeStageRunner.Section.ADVANCE_ONE, "첫 전진 구간"):
		return
	if not _assert_equal(_closed_gate_count(runner), 4, "초기 관문 전체 폐쇄"):
		return
	if not _assert_true(not slime.visible and not seed_sack.visible and not wind_spirit.visible and not boar.visible, "초기 적 미등장"):
		return

	# 3분은 실패 제한이 아니라 기록 목표다.
	runner.debug_set_stage_elapsed(181.0)
	await process_frame
	if not _assert_equal(runner.current_section, PrototypeStageRunner.Section.ADVANCE_ONE, "3분 초과 후 구간 유지"):
		return
	if not _assert_true(not runner.failed and bool(runner.current_metrics()["stage_overtime"]), "3분 초과 강제 실패 없음"):
		return
	runner.reset_stage()
	await physics_frame

	player.global_position = Vector2(1240.0, 780.0)
	await process_frame
	await physics_frame
	if not _assert_equal(runner.current_section, PrototypeStageRunner.Section.WAVE_ONE, "1차 웨이브 진입"):
		return
	if not _assert_true(not runner.is_gate_closed(0) and runner.is_gate_closed(1), "첫 관문만 개방"):
		return
	if not _assert_equal(int(runner.current_metrics()["stage_active_enemy_count"]), 2, "1차 웨이브 적 2기"):
		return

	# 좌표를 건너뛰어도 웨이브 처치 전에는 다음 구간으로 가지 않는다.
	player.global_position = Vector2(4700.0, 780.0)
	await process_frame
	if not _assert_equal(runner.current_section, PrototypeStageRunner.Section.WAVE_ONE, "웨이브 건너뛰기 차단"):
		return
	player.global_position = Vector2(2100.0, 780.0)
	_defeat(slime, &"cp303:wave1:slime")
	_defeat(seed_sack, &"cp303:wave1:seed")
	await process_frame
	await physics_frame
	if not _assert_equal(runner.current_section, PrototypeStageRunner.Section.ADVANCE_TWO, "2차 전진 진입"):
		return
	if not _assert_true(not runner.is_gate_closed(1) and runner.is_gate_closed(2), "2차 전진 관문 규칙"):
		return

	player.global_position = Vector2(3840.0, 780.0)
	await process_frame
	await physics_frame
	if not _assert_equal(runner.current_section, PrototypeStageRunner.Section.WAVE_TWO, "혼합 웨이브 진입"):
		return
	if not _assert_equal(int(runner.current_metrics()["stage_active_enemy_count"]), 3, "혼합 웨이브 적 3기"):
		return
	if not _assert_true(slime.global_position.x >= 3800.0 and seed_sack.global_position.x >= 3800.0, "오른쪽 전장 재배치"):
		return
	_defeat(slime, &"cp303:wave2:slime")
	_defeat(seed_sack, &"cp303:wave2:seed")
	_defeat(wind_spirit, &"cp303:wave2:wind")
	await process_frame
	await physics_frame
	if not _assert_equal(runner.current_section, PrototypeStageRunner.Section.ELITE, "정예 구간 진입"):
		return
	if not _assert_true(boar.visible and boar.is_targetable(), "정예 출현"):
		return
	if not _assert_true(runner.is_gate_closed(3), "정예 처치 전 출구 폐쇄"):
		return

	_defeat(boar, &"cp303:elite:boar")
	await process_frame
	await physics_frame
	if not _assert_true(runner.stage_complete, "스테이지 완료"):
		return
	if not _assert_true(not runner.is_gate_closed(3), "완료 후 출구 개방"):
		return
	if not _assert_equal(runner.section_actual_times.size(), 5, "5개 구간 실제 시간 기록"):
		return
	if not _assert_equal(float(runner.current_metrics()["stage_target_s"]), 180.0, "목표 시간 180초"):
		return
	if not _assert_true(runner.stage_elapsed_s < 180.0 and not runner.failed, "빠른 완료 허용"):
		return

	print("CP-303 runtime test: OK")
	quit(0)


func _defeat(target: PrototypeTarget, event_id: StringName) -> void:
	var event := DamageEvent.new()
	event.event_id = event_id
	event.attacker_id = &"cp303_test"
	event.attack_id = &"stage_clear"
	event.damage = 999
	event.stagger_s = 0.0
	event.tags = PackedStringArray(["test"])
	event.source_position = Vector2.ZERO
	target.receive_damage(event)


func _closed_gate_count(runner: PrototypeStageRunner) -> int:
	var count := 0
	for gate_index in 4:
		if runner.is_gate_closed(gate_index):
			count += 1
	return count


func _assert_equal(actual: Variant, expected: Variant, label: String) -> bool:
	if actual == expected:
		return true
	push_error("%s 실패: actual=%s expected=%s" % [label, actual, expected])
	quit(1)
	return false


func _assert_true(value: bool, label: String) -> bool:
	if value:
		return true
	push_error("%s 실패" % label)
	quit(1)
	return false
