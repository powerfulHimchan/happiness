extends SceneTree

const SANDBOX_SCENE := preload("res://scenes/movement/ground_movement_sandbox.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sandbox := SANDBOX_SCENE.instantiate()
	root.add_child(sandbox)
	var player := sandbox.get_node("Player") as PrototypePlayer
	player.facing_direction = -1
	await process_frame
	await physics_frame

	var slime := sandbox.get_node("Targets/LeafSlime") as PrototypeEnemy
	var seed_sack := sandbox.get_node("Targets/SeedSack") as PrototypeEnemy
	var wind_spirit := sandbox.get_node("Targets/WindSpirit") as PrototypeEnemy
	if not _assert_equal(slime.damage_receiver.max_health, 36, "풀잎 슬라임 HP"):
		return
	if not _assert_equal(seed_sack.damage_receiver.max_health, 30, "씨앗 포대 HP"):
		return
	if not _assert_equal(wind_spirit.damage_receiver.max_health, 24, "바람 정령 HP"):
		return
	if not _assert_equal(slime.state, PrototypeEnemy.State.WARNING, "슬라임 사전 경고"):
		return
	if not _assert_equal(seed_sack.state, PrototypeEnemy.State.WARNING, "씨앗 포대 사전 경고"):
		return
	if not _assert_equal(wind_spirit.state, PrototypeEnemy.State.WARNING, "바람 정령 사전 경고"):
		return
	if not _assert_true(slime.warning_ring.visible, "슬라임 경고 링 표시"):
		return
	if not _assert_true(seed_sack.warning_line.visible, "씨앗 포대 조준선 표시"):
		return
	if not _assert_true(wind_spirit.warning_line.visible, "바람 정령 흰 경고선 표시"):
		return

	await create_timer(1.25).timeout
	await physics_frame
	if not _assert_true(slime.attack_count >= 1, "슬라임 점프 공격"):
		return
	if not _assert_true(seed_sack.attack_count >= 1, "씨앗 포대 3연발"):
		return
	if not _assert_true(wind_spirit.attack_count >= 1, "바람 정령 돌진"):
		return
	if not _assert_true(get_nodes_in_group("enemy_projectile").size() >= 1, "씨앗 투사체 생성"):
		return

	var seed_before_hit := seed_sack.global_position.x
	var melee_event := _damage_event(&"cp301:seed_melee", 1, player.global_position, ["sword"])
	seed_sack.receive_damage(melee_event)
	if not _assert_equal(seed_sack.state, PrototypeEnemy.State.RECOVERY, "근접 피격 사격 중단"):
		return
	if not _assert_true(seed_sack.global_position.x > seed_before_hit, "근접 피격 넉백"):
		return

	for enemy in [slime, seed_sack, wind_spirit]:
		var target := enemy as PrototypeEnemy
		target.receive_damage(_damage_event(
			StringName("cp301:defeat:%s" % target.target_key),
			999,
			player.global_position,
			["test"]
		))
		if not _assert_true(not target.is_targetable(), "%s 사망 처리" % target.enemy_name()):
			return
		if not _assert_equal(target.state, PrototypeEnemy.State.DEAD, "%s 사망 상태" % target.enemy_name()):
			return
		if not _assert_true(not target.warning_ring.visible and not target.warning_line.visible, "%s 경고 종료" % target.enemy_name()):
			return

	print("CP-301 runtime test: OK")
	quit(0)


func _damage_event(
	event_id: StringName,
	damage: int,
	source_position: Vector2,
	tags: Array[String]
) -> DamageEvent:
	var event := DamageEvent.new()
	event.event_id = event_id
	event.attacker_id = &"cp301_test"
	event.attack_id = &"test_hit"
	event.damage = damage
	event.stagger_s = 0.0
	event.source_position = source_position
	event.tags = PackedStringArray(tags)
	return event


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
