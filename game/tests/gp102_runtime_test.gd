extends SceneTree

const SANDBOX := preload("res://scenes/movement/ground_movement_sandbox.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _test_scoring():
		return
	var sandbox := SANDBOX.instantiate()
	root.add_child(sandbox)
	current_scene = sandbox
	var controls := sandbox.get_node("CanvasLayer/GroundMovementControls") as Control
	var growth := sandbox.get_node("PrototypeGrowthController") as PrototypeGrowthController
	var player := sandbox.get_node("Player") as PrototypePlayer
	var weapons := sandbox.get_node("Player/PrototypeWeaponController") as PrototypeWeaponController
	var ultimate := sandbox.get_node("Player/UltimateController") as UltimateController
	var runner := sandbox.get_node("StageRunner") as PrototypeStageRunner
	await process_frame
	weapons.sword_combat.set_process(false)
	weapons.bow_combat.set_process(false)
	(sandbox.get_node("CombatFeedbackController") as CombatFeedbackController).configure(0.0, false, false)
	for job_index in 2:
		controls.begin_retry()
		var expected := "vanguard" if job_index == 0 else "tracker"
		for index in 3:
			_offer_card(sandbox, growth, PrototypeGrowthController.CARDS[job_index])
			_tap(controls, controls.growth_card_rects[0].get_center())
			if index < 2 and not _check(growth.jobs.job_id.is_empty() and not paused, "선택 두 번만으로 직업 고정 없음"):
				return
		if not _check(growth.jobs.job_id == expected and paused and growth.awaiting_job_confirmation and controls.current_screen_mode() == 8 and player.job_emblem_id == expected, "두 직업 자동 발현·일시정지·표식"):
			return
		if not _check(player.growth_damage(20, "sword" if job_index == 0 else "bow") == 31, "능력 45%와 직업 패시브 10% 실제 합산"):
			return
		var previous_clock := runner.stage_elapsed_s
		var previous_position := player.global_position
		await create_timer(0.12, true).timeout
		if not _check(is_equal_approx(previous_clock, runner.stage_elapsed_s) and previous_position == player.global_position and controls.command_buffer.pending_count() == 0, "발현 알림 중 시간·이동·보류 입력 정지"):
			return
		for viewport_size in [Vector2(1280, 720), Vector2(2400, 1080)]:
			controls.size = viewport_size
			controls._refresh_job_layout()
			var layout: Dictionary = controls.layout_snapshot()
			var safe: Rect2 = layout["safe"]
			var panel: Rect2 = layout["job_panel"]
			if not _check(safe.encloses(panel) and panel.encloses(layout["job_confirm"]), "직업 패널·확인 버튼 두 비율 안전 영역"):
				return
		controls.notification(Control.NOTIFICATION_APPLICATION_PAUSED)
		controls.notification(Control.NOTIFICATION_APPLICATION_RESUMED)
		if not _check(paused and controls.current_screen_mode() == 8, "발현 화면 백그라운드 복귀 유지"):
			return
		_tap(controls, controls.job_ultimate_rects[0].get_center())
		_tap(controls, controls.job_confirm_rect.get_center())
		if not _check(not paused and not growth.awaiting_job_confirmation and not growth.acknowledge_job(), "확인 터치·중복 확인 차단·재개"):
			return
		var bonus_before := player.growth_damage(20, "sword" if job_index == 0 else "bow")
		for ignored in 4:
			growth.jobs.add_ability(PrototypeGrowthController.CARDS[1 - job_index]["tags"])
			growth._try_manifest_job()
		if not _check(growth.jobs.job_id == expected and player.growth_damage(20, "sword" if job_index == 0 else "bow") == bonus_before and not paused, "발현 뒤 직업 유지·패시브 중복 방지"):
			return
	controls.begin_retry()
	if not _check(growth.jobs.job_id.is_empty() and player.job_emblem_id.is_empty() and player.growth_damage(20, "sword") == 20 and player.growth_damage(20, "bow") == 20, "재도전 시 직업·패시브·표식 초기화"):
		return
	# 실제 적중 신호만 무기 성향에 반영하고 연습 표적은 제외한다.
	runner.set_stage_enabled(false)
	var slime := sandbox.get_node("Targets/LeafSlime") as PrototypeTarget
	var dummy := sandbox.get_node("Targets/RearTarget") as PrototypeTarget
	var before := growth.jobs.score("strength")
	weapons.sword_combat.hit_registered.emit(false, dummy, 12)
	if not _check(is_equal_approx(before, growth.jobs.score("strength")), "연습 표적 적중 성향 제외"):
		return
	weapons.sword_combat.hit_registered.emit(false, slime, 12)
	if not _check(is_equal_approx(growth.jobs.score("strength") - before, 0.02), "적중 무기 신호 가중치 20%"):
		return
	# 한 번의 실제 회피에 정확한 회피 신호가 여러 번 와도 한 번만 점수화한다.
	player.request_evade()
	var special_before := growth.jobs.score("strength")
	ultimate.register_precise_evade()
	ultimate.register_precise_evade()
	if not _check(is_equal_approx(growth.jobs.score("strength") - special_before, 0.05), "특수 행동 10%·동일 회피 중복 차단"):
		return
	controls.begin_retry()
	# 마지막 적중으로 발현했을 때 이미 열린 레벨업 선택을 잃지 않는다.
	for index in 2:
		_offer_card(sandbox, growth, PrototypeGrowthController.CARDS[0])
		growth.choose_card(0)
	growth.experience = 20
	growth._offer_next_level()
	var offered_before := growth.offered_cards.duplicate(true)
	slime.visible = true
	for hit in 65:
		weapons.sword_combat.hit_registered.emit(false, slime, 12)
	if not _check(growth.awaiting_job_confirmation and growth.choosing and paused and controls.current_screen_mode() == 8 and not growth.choose_card(0) and not growth.reroll(), "대기 카드 보존·발현 중 카드/재추첨 차단"):
		return
	growth.choose_job_ultimate(0)
	if not _check(paused and controls.current_screen_mode() == 7 and growth.offered_cards == offered_before, "직업 확인 뒤 기존 선택 복원"):
		return
	growth.choose_card(0)
	if not _check(not paused, "남은 카드 선택 뒤 재개"):
		return
	controls.begin_retry()
	for index in 3:
		_offer_card(sandbox, growth, PrototypeGrowthController.CARDS[1])
		growth.choose_card(0)
	growth.experience = 20
	growth.choose_job_ultimate(0)
	if not _check(paused and growth.choosing and growth.level == 2 and controls.current_screen_mode() == 7, "발현 알림 중 쌓인 경험치 선택 이어가기"):
		return
	growth.choose_card(0)
	controls.begin_retry()
	# 실제 스테이지 마지막 레벨업에서 발현을 확인한 뒤 결과로 이동한다.
	runner.set_stage_enabled(true)
	player.global_position.x = 1240.0
	await process_frame
	await physics_frame
	_defeat(slime, "wave1:slime")
	_defeat(sandbox.get_node("Targets/SeedSack"), "wave1:seed")
	growth.choose_card(0)
	await process_frame
	await physics_frame
	player.global_position.x = 3840.0
	await process_frame
	await physics_frame
	_defeat(slime, "wave2:slime")
	_defeat(sandbox.get_node("Targets/SeedSack"), "wave2:seed")
	_defeat(sandbox.get_node("Targets/WindSpirit"), "wave2:wind")
	growth.choose_card(0)
	await process_frame
	await physics_frame
	_defeat(sandbox.get_node("Targets/ArmoredBoar"), "elite")
	growth.choose_card(0)
	if not _check(paused and growth.awaiting_job_confirmation and not runner.stage_complete, "최종 카드 발현을 결과 화면보다 먼저 확인"):
		return
	growth.choose_job_ultimate(0)
	await process_frame
	await physics_frame
	if not _check(not paused and runner.stage_complete and controls.current_screen_mode() == 1, "직업 확인 뒤 스테이지 완료·결과 표시"):
		return
	controls.begin_retry()
	for index in 3:
		_offer_card(sandbox, growth, PrototypeGrowthController.CARDS[0])
		growth.choose_card(0)
	player.player_died.emit()
	if not _check(not paused and not growth.awaiting_job_confirmation and not growth.run_active, "사망 시 발현 일시정지 해제"):
		return
	controls.begin_retry()
	for index in 3:
		_offer_card(sandbox, growth, PrototypeGrowthController.CARDS[0])
		growth.choose_card(0)
	sandbox.free()
	await process_frame
	if not _check(not paused, "발현 화면 씬 종료 시 정지 복구"):
		return
	print("GP-102 runtime test: OK")
	quit(0)


func _test_scoring() -> bool:
	var model := PrototypeJobProgress.new()
	model.reset("sword")
	model.add_ability({"strength": 2.5, "determination": 1.5})
	model.add_weapon_hit("sword")
	model.add_special("sword")
	if not _check(is_equal_approx(model.score("strength"), 2.02) and is_equal_approx(model.score("determination"), 1.212), "70/20/10 실제 가중 점수"):
		return false
	model.reset("sword")
	for index in 2000:
		model.add_weapon_hit("sword")
		model.add_special("sword")
	if not _check(is_equal_approx(model.score("strength"), 3.0) and is_equal_approx(model.score("determination"), 1.8) and model.evaluate().is_empty(), "무기·특수 행동 상한과 단독 발현 차단"):
		return false
	model.reset("sword")
	model.add_ability({"strength": 10.0})
	if not _check(model.evaluate().is_empty(), "주 성향만 충족하면 발현 불가"):
		return false
	for preferred in ["vanguard", "tracker"]:
		model.reset("sword")
		model._add("weapon", {"shooting": 1.0, "nature": 0.6}, 1.0)
		model.add_ability({"strength": 10.0, "determination": 6.0, "shooting": 10.0, "nature": 6.0})
		model.recent_ability = {"strength": 2.5, "determination": 1.5} if preferred == "vanguard" else {"shooting": 2.5, "nature": 1.5}
		if not _check(model.evaluate()["id"] == preferred, "동점 최근 능력 우선"):
			return false
	model.reset("sword")
	model.add_ability({"strength": 10.0, "determination": 6.0, "shooting": 7.2, "nature": 4.4})
	model.recent_ability = {"shooting": 2.5, "nature": 1.5}
	if not _check(model.evaluate()["id"] == "vanguard", "동시 조건 충족 시 높은 총점 우선"):
		return false
	model.reset("sword")
	model.add_ability({"shooting": 2.5, "nature": 1.5})
	if not _check(model.closest_job()["id"] == "tracker" and "추적자" in model.hud_text(), "시작 검이 직업을 고정하지 않고 가까운 직업 표시"):
		return false
	return true


func _defeat(target: PrototypeTarget, event_id: String) -> void:
	var event := DamageEvent.new()
	event.event_id = StringName("gp102:" + event_id)
	event.attacker_id = &"player"
	event.attack_id = &"test"
	event.damage = 999
	event.tags = PackedStringArray(["test"])
	target.receive_damage(event)


func _offer_card(sandbox: Node, growth: PrototypeGrowthController, card: Dictionary) -> void:
	growth.offered_cards.assign([card])
	growth.choosing = true
	sandbox._on_growth_choices_requested(growth.offered_cards, growth.level, growth.rerolls_remaining)


func _tap(controls: Control, position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 6
	event.pressed = true
	event.position = position
	controls._input(event)


func _check(condition: bool, label: String) -> bool:
	if condition:
		return true
	push_error("GP-102 실패: %s" % label)
	paused = false
	quit(1)
	return false
