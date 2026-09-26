extends SceneTree

const SANDBOX_SCENE := preload("res://scenes/movement/ground_movement_sandbox.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sandbox := SANDBOX_SCENE.instantiate()
	root.add_child(sandbox)
	var player := sandbox.get_node("Player") as PrototypePlayer
	var boar := sandbox.get_node("Targets/ArmoredBoar") as EliteArmoredBoar
	for node in get_nodes_in_group("prototype_enemy"):
		node.set_process(false)
		node.visible = false
	player.facing_direction = -1
	player.global_position = Vector2(100.0, 780.0)
	boar.global_position = Vector2(220.0, 780.0)
	await process_frame
	await physics_frame

	if not _assert_equal(boar.damage_receiver.max_health, 180, "정예 HP"):
		return
	var hp_before_armored_sword := boar.damage_receiver.health
	boar.receive_damage(_damage_event(&"cp302:armor_sword", 10, ["sword"]))
	if not _assert_equal(hp_before_armored_sword - boar.damage_receiver.health, 6, "갑옷 중 검 60%"):
		return
	var hp_before_armored_bow := boar.damage_receiver.health
	boar.receive_damage(_damage_event(&"cp302:armor_bow", 20, ["bow"]))
	if not _assert_equal(hp_before_armored_bow - boar.damage_receiver.health, 25, "갑옷 중 활 125%"):
		return
	await create_timer(0.55).timeout
	if not _assert_equal(boar.state, EliteArmoredBoar.State.WARNING, "돌진 사전 경고"):
		return
	if not _assert_equal(boar.current_pattern, EliteArmoredBoar.Pattern.CHARGE, "첫 패턴 돌진"):
		return
	if not _assert_true(boar.warning_line.visible, "돌진 경고선 표시"):
		return

	await create_timer(0.90).timeout
	if not _assert_equal(boar.state, EliteArmoredBoar.State.STUNNED, "벽 충돌 기절"):
		return
	if not _assert_equal(boar.charge_count, 1, "돌진 횟수"):
		return
	var hp_before_sword := boar.damage_receiver.health
	boar.receive_damage(_damage_event(&"cp302:stun_sword", 20, ["sword"]))
	if not _assert_equal(hp_before_sword - boar.damage_receiver.health, 35, "기절 중 검 175%"):
		return
	var hp_before_bow := boar.damage_receiver.health
	boar.receive_damage(_damage_event(&"cp302:stun_bow", 20, ["bow"]))
	if not _assert_equal(hp_before_bow - boar.damage_receiver.health, 20, "기절 중 활 100%"):
		return

	boar.receive_damage(_damage_event(&"cp302:phase_two", 10, ["test"]))
	if not _assert_equal(boar.phase, 2, "체력 50% 2페이즈 전환"):
		return
	if not _assert_equal(boar.state, EliteArmoredBoar.State.PHASE_TRANSITION, "분노 전환 상태"):
		return
	await create_timer(1.02).timeout
	if not _assert_equal(boar.current_pattern, EliteArmoredBoar.Pattern.SHOCKWAVE, "돌진 다음 충격파"):
		return
	if not _assert_equal(boar.state, EliteArmoredBoar.State.WARNING, "2페이즈 충격파 경고"):
		return
	if not _assert_true(boar.warning_ring.visible, "충격파 경고 링 표시"):
		return

	await create_timer(0.78).timeout
	if not _assert_true(boar.shockwave_count >= 1, "충격파 패턴 실행"):
		return
	if not _assert_true(get_nodes_in_group("enemy_projectile").size() >= 1, "충격파 투사체 생성"):
		return
	if not _assert_no_triple_pattern(boar.pattern_history):
		return

	boar.receive_damage(_damage_event(&"cp302:defeat", 999, ["test"]))
	if not _assert_true(not boar.is_targetable(), "정예 사망 처리"):
		return
	if not _assert_equal(boar.state, EliteArmoredBoar.State.DEAD, "정예 사망 상태"):
		return

	print("CP-302 runtime test: OK")
	quit(0)


func _damage_event(event_id: StringName, damage: int, tags: Array[String]) -> DamageEvent:
	var event := DamageEvent.new()
	event.event_id = event_id
	event.attacker_id = &"cp302_test"
	event.attack_id = &"test_hit"
	event.damage = damage
	event.stagger_s = 0.0
	event.source_position = Vector2(100.0, 780.0)
	event.tags = PackedStringArray(tags)
	return event


func _assert_no_triple_pattern(history: Array[int]) -> bool:
	for index in range(2, history.size()):
		if history[index] == history[index - 1] and history[index] == history[index - 2]:
			push_error("같은 패턴 3연속 실패: %s" % [history])
			quit(1)
			return false
	return true


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
