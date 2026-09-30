extends SceneTree

const SANDBOX_SCENE := preload("res://scenes/movement/ground_movement_sandbox.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sandbox := SANDBOX_SCENE.instantiate()
	(sandbox.get_node("StageRunner") as PrototypeStageRunner).stage_limit = 1
	root.add_child(sandbox)
	var controls := sandbox.get_node("CanvasLayer/GroundMovementControls") as Control
	var player := sandbox.get_node("Player") as PrototypePlayer
	var weapon_controller := sandbox.get_node("Player/PrototypeWeaponController") as PrototypeWeaponController
	var sword := sandbox.get_node("Player/SwordCombatController") as SwordCombatController
	var bow := sandbox.get_node("Player/BowCombatController") as BowCombatController
	await process_frame
	controls.begin_stage_from_main()
	await process_frame

	# 1280x720 소형 화면에서도 상단 HUD가 이동/전투 조작 영역과 분리된다.
	controls.size = Vector2(1280.0, 720.0)
	controls.notification(Control.NOTIFICATION_RESIZED)
	var layout: Dictionary = controls.layout_snapshot()
	var safe: Rect2 = layout["safe"]
	var hud: Rect2 = layout["hud"]
	var move: Rect2 = layout["move"]
	if not _assert_true(safe.encloses(hud), "HUD 안전 영역 포함"):
		return
	if not _assert_true(not hud.intersects(move), "HUD와 이동 영역 분리"):
		return
	var actions: Dictionary = layout["actions"]
	for action_rect_value in actions.values():
		var action_rect: Rect2 = action_rect_value
		if not _assert_true(not hud.intersects(action_rect), "HUD와 전투 버튼 분리"):
			return

	var seed_event := DamageEvent.new()
	seed_event.event_id = &"cp304:seed:1"
	seed_event.attacker_id = &"seed_sack"
	seed_event.attack_id = &"seed_volley"
	seed_event.damage = 7
	seed_event.tags = PackedStringArray(["enemy", "projectile", "seed"])
	player.receive_damage(seed_event)
	if not _assert_equal(int(player.damage_cause_counts.get("씨앗탄", 0)), 1, "피격 원인 누적"):
		return
	sword.basic_attack_count = 4
	sword.skill_hit_count = 2
	sword.total_damage = 92
	bow.basic_attack_count = 1
	bow.skill_hit_count = 1
	bow.total_damage = 38
	weapon_controller.force_emit_metrics()
	await process_frame
	controls.update_stage_metrics({
		"stage_complete": true,
		"stage_elapsed_s": 176.4,
		"stage_target_s": 180.0,
		"stage_actual_times": [38.0, 34.2, 33.7, 39.1, 31.4],
		"stage_last_log": "스테이지 완료 · 2:56",
	})
	if not _assert_equal(controls.current_screen_mode(), 1, "완료 결과 화면 전환"):
		return
	var result: Dictionary = controls.current_result_snapshot()
	if not _assert_equal(String(result["damage_causes"]), "씨앗탄 1회", "피격 원인 기록"):
		return
	if not _assert_true(is_equal_approx(float(result["sword_ratio"]), 0.75), "검 사용 비율"):
		return
	if not _assert_true(is_equal_approx(float(result["bow_ratio"]), 0.25), "활 사용 비율"):
		return
	if not _assert_equal((result["actual_times"] as Array).size(), 5, "구간 기록 5개"):
		return

	controls.show_main_screen()
	if not _assert_equal(controls.current_screen_mode(), 2, "메인 화면 복귀"):
		return
	var retry_count := [0]
	controls.retry_requested.connect(func() -> void: retry_count[0] += 1)
	controls.begin_stage_from_main()
	if not _assert_equal(controls.current_screen_mode(), 0, "메인에서 스테이지 시작"):
		return
	if not _assert_equal(retry_count[0], 1, "스테이지 초기화 요청"):
		return

	print("CP-304 runtime test: OK")
	quit(0)


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
