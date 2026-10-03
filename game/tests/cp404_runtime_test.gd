extends SceneTree

const SANDBOX_SCENE := preload("res://scenes/movement/ground_movement_sandbox.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sandbox := SANDBOX_SCENE.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	root.add_child(sandbox)
	var controls := sandbox.get_node("CanvasLayer/GroundMovementControls") as Control
	var feedback := sandbox.get_node("CombatFeedbackController") as CombatFeedbackController
	var player := sandbox.get_node("Player") as PrototypePlayer
	var targets := sandbox.get_node("Targets") as Node
	targets.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame

	var defaults: Dictionary = controls.feedback_settings_snapshot()
	if not _assert_true(is_equal_approx(float(defaults["sound_volume"]), 0.80), "효과음 기본값 80퍼센트"):
		return
	if not _assert_true(bool(defaults["vibration_enabled"]), "진동 기본값 켜짐"):
		return
	if not _assert_true(bool(defaults["screen_shake_enabled"]), "화면 흔들기 기본값 켜짐"):
		return

	controls.show_feedback_settings()
	if not _assert_equal(controls.current_screen_mode(), 6, "피드백 설정 화면 진입"):
		return
	controls.set_feedback_vibration_enabled(false)
	controls.set_feedback_screen_shake_enabled(false)
	controls.set_feedback_sound_volume(0.60)
	var disabled: Dictionary = feedback.feedback_snapshot()
	if not _assert_true(not bool(disabled["vibration_enabled"]), "진동 독립 끄기"):
		return
	if not _assert_true(not bool(disabled["screen_shake_enabled"]), "화면 흔들기 독립 끄기"):
		return
	if not _assert_true(is_equal_approx(float(disabled["sound_volume"]), 0.60), "효과음 음량 적용"):
		return

	feedback.trigger_hit_feedback_for_test(false, 12, Vector2(500.0, 400.0))
	var basic_hit: Dictionary = feedback.feedback_snapshot()
	if not _assert_true(is_equal_approx(float(basic_hit["last_hit_stop_s"]), 0.04), "기본 타격 정지 0.04초"):
		return
	if not _assert_true(is_zero_approx(float(basic_hit["shake_remaining_s"])), "화면 흔들기 끄기 적용"):
		return
	if not _assert_equal(int(basic_hit["vibration_request_count"]), 0, "기본 타격 진동 없음"):
		return

	player.reset_movement_test(Vector2(960.0, 780.0))
	var health_before := int(player.feedback_snapshot()["health"])
	var event := DamageEvent.new()
	event.event_id = &"cp404_settings_independence"
	event.attacker_id = &"cp404_test"
	event.attack_id = &"danger_attack"
	event.damage = 13
	event.stagger_s = 0.20
	event.tags = PackedStringArray(["enemy", "danger"])
	var damage_result := player.receive_damage(event)
	var player_feedback: Dictionary = player.feedback_snapshot()
	if not _assert_equal(damage_result, DamageReceiver.Result.APPLIED, "피드백 설정과 무관한 피해 판정"):
		return
	if not _assert_equal(int(player_feedback["health"]), health_before - 13, "피드백 설정과 무관한 피해량"):
		return
	if not _assert_true(is_equal_approx(float(player_feedback["hit_flash_remaining_s"]), 0.12), "플레이어 피격 점멸 0.12초"):
		return
	if not _assert_equal(int(feedback.feedback_snapshot()["player_hit_count"]), 1, "피격 피드백 신호"):
		return

	controls.set_feedback_vibration_enabled(true)
	controls.set_feedback_screen_shake_enabled(true)
	feedback.trigger_hit_feedback_for_test(true, 35, Vector2(520.0, 400.0))
	var strong_hit: Dictionary = feedback.feedback_snapshot()
	if not _assert_true(is_equal_approx(float(strong_hit["last_hit_stop_s"]), 0.07), "강한 타격 정지 0.07초"):
		return
	if not _assert_true(float(strong_hit["shake_remaining_s"]) > 0.0, "강한 타격 화면 흔들기"):
		return
	if not _assert_equal(int(strong_hit["vibration_request_count"]), 1, "강한 타격 선택 진동"):
		return

	for node_path in ["Targets/LeafSlime", "Targets/WindSpirit", "Targets/ArmoredBoar"]:
		var enemy := sandbox.get_node(node_path)
		var warning: Dictionary = enemy.warning_feedback_snapshot()
		var color: Color = warning["color"]
		if not _assert_true(bool(warning["uses_color_and_shape"]), "%s 색상·도형 이중 경고" % node_path):
			return
		if not _assert_true(not String(warning["shape"]).is_empty(), "%s 경고 도형" % node_path):
			return
		if not _assert_true(color.r > color.g and color.r > color.b, "%s 붉은 계열 경고" % node_path):
			return

	print("CP-404 runtime test: OK")
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
