extends SceneTree

const SANDBOX := preload("res://scenes/movement/ground_movement_sandbox.tscn")
const ENEMY_PROJECTILE := preload("res://scenes/combat/enemy_seed_projectile.tscn")
var _sequence: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sandbox := SANDBOX.instantiate()
	root.add_child(sandbox)
	current_scene = sandbox
	var controls := sandbox.get_node("CanvasLayer/GroundMovementControls") as Control
	var growth := sandbox.get_node("PrototypeGrowthController") as PrototypeGrowthController
	var player := sandbox.get_node("Player") as PrototypePlayer
	var runner := sandbox.get_node("StageRunner") as PrototypeStageRunner
	var sword := sandbox.get_node("Player/SwordCombatController") as SwordCombatController
	var bow := sandbox.get_node("Player/BowCombatController") as BowCombatController
	var weapons := sandbox.get_node("Player/PrototypeWeaponController") as PrototypeWeaponController
	var slime := sandbox.get_node("Targets/LeafSlime") as PrototypeTarget
	var seed := sandbox.get_node("Targets/SeedSack") as PrototypeTarget
	var wind := sandbox.get_node("Targets/WindSpirit") as PrototypeTarget
	var boar := sandbox.get_node("Targets/ArmoredBoar") as PrototypeTarget
	await process_frame
	sword.set_process(false)
	bow.set_process(false)
	controls.begin_stage_from_main()
	(sandbox.get_node("CombatFeedbackController") as CombatFeedbackController).configure(0.0, false, false)
	growth.rng.seed = 101
	if not _check(growth.level == 1 and growth.experience == 0 and not paused, "초기 런 상태"):
		return
	# 실제 스테이지 적을 처치해 3회 레벨업한다. 표적/재발행 신호는 제외한다.
	player.global_position.x = 1240.0
	await process_frame
	await physics_frame
	_defeat(slime)
	if not _check(growth.experience == 10 and not growth.choosing, "일반 적 경험치 10"):
		return
	slime.defeated.emit(slime)
	if not _check(growth.experience == 10, "같은 생명 중복 보상 차단"):
		return
	var projectile := ENEMY_PROJECTILE.instantiate() as EnemySeedProjectile
	projectile.configure("gp101:pause", Vector2.RIGHT)
	sandbox.add_child(projectile)
	projectile.global_position = Vector2(1600.0, 300.0)
	var enemy_projectile_position := projectile.global_position
	bow._spawn_projectile("gp101:bow:pause", &"bow_basic", 20, 1, Vector2.RIGHT, PackedStringArray(["bow"]))
	var arrow := get_first_node_in_group("bow_projectile") as BowProjectile
	var arrow_position := arrow.global_position
	sword._skill_1_cooldown_s = 3.0
	controls._handle_touch_pressed(7, controls.move_zone.get_center())
	controls._handle_touch_dragged(7, controls.move_zone.get_center() + Vector2(60.0, 0.0))
	controls._handle_touch_pressed(8, (controls.action_rects[&"skill_1"] as Rect2).get_center())
	_defeat(seed)
	if not _check(paused and growth.level == 2 and controls.current_screen_mode() == 7, "레벨업 시 전투 정지와 선택 화면"):
		return
	if not _check(growth.offered_cards.size() == 3 and growth.offered_cards[0]["category"] == "sword" and growth.offered_cards[1]["category"] == "common", "관련·공용·무작위 카드 구성"):
		return
	var ids := {}
	for card in growth.offered_cards:
		ids[card["id"]] = true
	if not _check(ids.size() == 3 and controls.command_buffer.pending_count() == 0 and controls.pointer_controls.is_empty() and player.move_input_vector == Vector2.ZERO, "중복 카드와 보류·홀드 입력 없음"):
		return
	var clock := runner.stage_elapsed_s
	controls.notification(Control.NOTIFICATION_APPLICATION_PAUSED)
	controls.notification(Control.NOTIFICATION_APPLICATION_RESUMED)
	if not _check(paused and controls.current_screen_mode() == 7 and growth.choosing, "백그라운드 복귀 후 카드 선택 유지"):
		return
	var position_before := player.global_position
	var cooldown: float = float(sword.current_metrics()["skill_1_cooldown_s"])
	await create_timer(0.12, true).timeout
	if not _check(is_equal_approx(runner.stage_elapsed_s, clock) and player.global_position == position_before and projectile.global_position == enemy_projectile_position and arrow.global_position == arrow_position and sword.current_metrics()["skill_1_cooldown_s"] == cooldown, "선택 중 시간·이동·양쪽 투사체·쿨다운 정지"):
		return
	for viewport_size in [Vector2(1280.0, 720.0), Vector2(2400.0, 1080.0)]:
		controls.size = viewport_size
		controls._refresh_growth_layout()
		var layout: Dictionary = controls.layout_snapshot()
		var safe: Rect2 = layout["safe"]
		var rects: Array = layout["growth_cards"]
		for rect in rects:
			if not _check(safe.encloses(rect) and not rect.intersects(layout["growth_reroll"]), "카드와 재추첨 안전 영역/비중첩"):
				return
		if not _check(safe.encloses(layout["growth_reroll"]) and not rects[0].intersects(rects[1]) and not rects[1].intersects(rects[2]), "16:9·20:9 카드 비중첩"):
			return
	var old_cards := growth.offered_cards.duplicate(true)
	_tap(controls, controls.growth_reroll_rect.get_center())
	if not _check(growth.rerolls_remaining == 0 and growth.offered_cards != old_cards and not growth.reroll(), "터치 재추첨 변경·스테이지당 1회"):
		return
	if not _check(not growth.choose_card(-1) and paused, "잘못된 선택 차단"):
		return
	_tap(controls, controls.growth_card_rects[0].get_center())
	if not _check(not paused and not growth.choosing and controls.current_screen_mode() == 0 and is_equal_approx(player.growth_sword_bonus, 0.15) and not growth.choose_card(0), "터치 카드 선택·효과·중복 선택 차단"):
		return
	projectile.queue_free()
	arrow.queue_free()
	await process_frame
	await physics_frame
	player.global_position.x = 3840.0
	await process_frame
	await physics_frame
	_defeat(slime)
	_defeat(seed)
	weapons.active_weapon_id = "bow"
	_defeat(wind)
	if not _check(growth.level == 3 and growth.experience == 5 and growth.offered_cards[0]["category"] == "bow" and growth.rerolls_remaining == 0, "재소환 경험치·활 관련 카드·잔여 경험치 보존"):
		return
	growth.choose_card(0)
	await process_frame
	await physics_frame
	_defeat(boar)
	if not _check(growth.total_experience == 80 and growth.level == 4 and growth.experience == 5 and paused, "정예 경험치 30·총 3회 레벨업"):
		return
	growth.choose_card(0)
	await process_frame
	await physics_frame
	if not _check(runner.stage_complete and controls.current_screen_mode() == 1 and not growth.run_active and not paused, "최종 카드 선택 뒤 결과 화면"):
		return
	# 각 카드 실제 효과와 기존 피해 경로의 증폭을 단위 검증한다.
	controls.begin_retry()
	for card_id in ["power", "vitality", "recovery", "sword_power", "bow_power"]:
		for card in PrototypeGrowthController.CARDS:
			if card["id"] == card_id:
				growth.offered_cards.assign([card])
				growth.choosing = true
				growth.choose_card(0)
	if not _check(player.damage_receiver.max_health == 130 and player.damage_receiver.health == 130 and player.growth_damage(20, "sword") == 25 and player.growth_damage(20, "bow") == 25, "피해 보너스 합산·체력 상한 적용"):
		return
	var dummy := sandbox.get_node("Targets/RearTarget") as PrototypeTarget
	dummy.visible = true
	dummy.reset_target()
	sword._damage_target(dummy, &"gp101:sword", 20, 0.0, PackedStringArray(["sword"]), 0)
	if not _check(dummy.damage_receiver.health == dummy.damage_receiver.max_health - 25 and growth.total_experience == 0, "검 실제 피해 25·연습 표적 경험치 제외"):
		return
	bow._spawn_projectile("gp101:bow:damage", &"bow_basic", 20, 1, Vector2.RIGHT, PackedStringArray(["bow"]))
	var boosted_arrow := get_first_node_in_group("bow_projectile") as BowProjectile
	if not _check(boosted_arrow.damage == 25, "활 투사체 실제 피해 증폭"):
		return
	dummy.reset_target()
	boosted_arrow._check_hits(dummy.global_position + Vector2(0.0, -38.0), dummy.global_position + Vector2(1.0, -38.0))
	if not _check(dummy.damage_receiver.health == dummy.damage_receiver.max_health - 25, "활 투사체 실제 적중 피해 증폭"):
		return
	dummy.reset_target()
	dummy.global_position = player.global_position + Vector2(80.0, 0.0)
	var camera := player.get_node("Camera2D") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
	bow._rain_anchor = dummy.global_position
	bow._action = BowCombatController.Action.ARROW_RAIN
	bow._execute_skill_hit(bow.skill_2, 0)
	if not _check(dummy.damage_receiver.health == dummy.damage_receiver.max_health - 10, "화살비 실제 피해 증폭: HP %d/%d" % [dummy.damage_receiver.health, dummy.damage_receiver.max_health]):
		return
	controls.begin_retry()
	if not _check(growth.level == 1 and growth.ranks.is_empty() and growth.total_experience == 0 and growth.rerolls_remaining == 1 and player.damage_receiver.max_health == 100 and player.growth_damage(20, "sword") == 20 and player.growth_damage(20, "bow") == 20, "재도전 시 성장 효과 전부 초기화"):
		return
	# 큰 경험치 보상은 선택을 순차 처리하고 남는 경험치를 버리지 않는다.
	growth.experience = 75
	growth._offer_next_level()
	for expected_level in [2, 3, 4]:
		if not _check(paused and growth.level == expected_level, "연속 레벨업 선택 순서"):
			return
		growth.choose_card(0)
	if not _check(not paused and growth.experience == 0, "연속 레벨업 이후 정상 재개"):
		return
	growth.experience = 40
	growth._offer_next_level()
	player.player_died.emit()
	if not _check(not paused and not growth.run_active and not growth.choosing, "사망 시 대기 선택과 정지 해제"):
		return
	controls.begin_retry()
	growth.experience = 20
	growth._offer_next_level()
	sandbox.free()
	await process_frame
	if not _check(not paused, "선택 중 씬 종료 시 정지 복구"):
		return
	print("GP-101 runtime test: OK")
	quit(0)


func _defeat(target: PrototypeTarget) -> void:
	_sequence += 1
	var event := DamageEvent.new()
	event.event_id = StringName("gp101:kill:%d" % _sequence)
	event.attacker_id = &"player"
	event.attack_id = &"gp101_test"
	event.damage = 999
	event.tags = PackedStringArray(["test"])
	target.receive_damage(event)


func _tap(controls: Control, position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 4
	event.pressed = true
	event.position = position
	controls._input(event)


func _check(condition: bool, label: String) -> bool:
	if condition:
		return true
	push_error("GP-101 실패: %s" % label)
	paused = false
	quit(1)
	return false
