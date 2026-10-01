extends SceneTree

const SANDBOX := preload("res://scenes/movement/ground_movement_sandbox.tscn")
const SAVE_PATH := "user://gp107_runtime_checkpoint.json"
const RECORD_PATH := "user://gp107_runtime_records.jsonl"
var sandbox: Node
var controls: Control
var player: PrototypePlayer
var growth: PrototypeGrowthController
var runner: PrototypeStageRunner
var weapons: PrototypeWeaponController
var terrain: PrototypeRouteTerrain
var store := RunCheckpointStore.new()
var saw_job_card: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	store.save_path = SAVE_PATH
	store.clear_checkpoint()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORD_PATH))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.get_node("LocalTestRecorder").record_path = RECORD_PATH
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	terrain = sandbox.get_node("RouteTerrain")
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	weapons.sword_combat.set_process(false)
	weapons.bow_combat.set_process(false)
	runner.set_process(false)
	for order in 2:
		controls.begin_retry("sword" if order == 0 else "bow")
		if not _check(terrain.platforms.is_empty() and terrain.get_child_count() == 0, "새 도전은 기존 첫 스테이지 지형"):
			return
		if not _finish_stage():
			return
		for stage in [2, 3]:
			var route_index: int = (order + stage) % 2
			var route := "meadow" if route_index == 0 else "wind"
			_tap(controls.stage_route_rects[route_index].get_center())
			var expected_count := 1 if route == "meadow" else 3
			if not _check(not paused and runner.stage_number == stage and runner.route_id == route and terrain.route_id == route and terrain.get_child_count() == expected_count and player.last_safe_position == sandbox.TRACK_START, "실제 경로 터치가 지형·도전·복귀점을 함께 전환"):
				return
			if not _check(controls.movement_metrics.run_route_name == ("풀숲 길" if route == "meadow" else "바람 길"), "HUD 경로 이름 동기화"):
				return
			# 실제 1차 전투를 마친 뒤 두 번째 전진 구간에서 물리 이동을 검증한다.
			player.global_position.x = 1240
			runner._process(0.1)
			for enemy in runner._active_enemies.duplicate():
				_defeat(enemy)
			if not _resolve_growth():
				return
			runner._process(0.1)
			if not _check(runner.current_section == PrototypeStageRunner.Section.ADVANCE_TWO and ("다리" in runner.current_metrics().stage_objective if route == "meadow" else "발판" in runner.current_metrics().stage_objective), "경로별 전진 목표"):
				return
			if not await _cross_terrain(route):
				return
			# 플레이 이동으로 도착한 위치에서 후반 혼합 웨이브를 시작한다.
			runner._process(0.1)
			if not _check(runner.current_section == PrototypeStageRunner.Section.WAVE_TWO and runner._active_enemies.size() == 3, "지형 횡단 후 웨이브 관문 진입"):
				return
			var spacing := runner.seed_sack.global_position.x - runner.leaf_slime.global_position.x
			if not _check((spacing < 250 and runner.wind_spirit.global_position.y == 620) if route == "meadow" else (spacing > 500 and runner.wind_spirit.global_position.y == 540), "후반 웨이브의 실제 거리·고도 차이"):
				return
			if not _finish_stage():
				return
			if stage == 2:
				var layout := terrain.layout_snapshot()
				var saved := store.load_checkpoint()
				if not _check(not saved.is_empty() and saved.stage.route == route and saved.stage.history[-1].route == route, "두 경로의 저장 기록"):
					return
				sandbox._finish_growth_selection()
				controls.show_main_screen()
				_tap(controls.main_continue_rect.get_center())
				if not _check(paused and controls.current_screen_mode() == 9 and terrain.layout_snapshot() == layout and player.damage_receiver.health == saved.player.health, "이어하기로 동일 충돌 지형·체력 복원 및 발판 중복 없음"):
					return
			else:
				if not _check(not paused and controls.current_screen_mode() == 1 and runner.stage_history.size() == 3 and growth.total_experience == 240 and store.load_checkpoint().is_empty(), "두 경로 순서별 3스테이지 완주·경험치 보존"):
					return
	controls.begin_retry()
	if not _check(terrain.platforms.is_empty() and terrain.get_child_count() == 0 and player.last_safe_position == sandbox.TRACK_START, "재도전은 이전 발판과 복귀점을 정리"):
		return
	store.clear_checkpoint()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORD_PATH))
	sandbox.free()
	print("GP-107 runtime test: OK")
	quit(0)

func _cross_terrain(route: String) -> bool:
	await physics_frame
	await physics_frame
	player.prepare_next_stage(Vector2(3200, 780) if route == "meadow" else Vector2(3000, 780))
	for ignored in 4:
		await physics_frame
	var falls := player.fall_count
	var dashes := player.air_dash_count
	if route == "meadow":
		player.set_move_vector(Vector2.RIGHT)
		for ignored in 160:
			await physics_frame
			if player.global_position.x >= 3840:
				break
		player.set_move_vector(Vector2.ZERO)
		if not _check(player.global_position.x >= 3840 and player.fall_count == falls, "풀숲 다리는 점프 없이 물리 충돌로 횡단"):
			return false
	else:
		for destination in [Vector2(3210, 660), Vector2(3530, 540), Vector2(3850, 660)]:
			if not await _jump_to(destination):
				return false
		if not _check(player.fall_count == falls and player.air_dash_count == dashes, "바람 발판은 기본 점프만으로 모두 횡단"):
			return false
		# 실제 낙하 판정·회복을 발생시켜 마지막 착지한 새 발판으로 복귀한다.
		var safe := player.last_safe_position
		var health := player.damage_receiver.health
		player.global_position = Vector2(3380, 1120)
		player.velocity = Vector2.ZERO
		for ignored in 90:
			await physics_frame
			if player.fall_count > falls and not player._fall_recovery_active:
				break
		if not _check(player.fall_count == falls + 1 and player.global_position.distance_to(safe) < 4 and player.damage_receiver.health == health - ceili(player.damage_receiver.max_health * player.FALL_DAMAGE_RATIO), "바람 길 낙하 시 마지막 안전 발판 복귀·정상 피해"):
			return false
	return true

func _jump_to(destination: Vector2) -> bool:
	player.set_move_vector(Vector2.RIGHT)
	player.request_jump()
	var left_floor := false
	for ignored in 150:
		await physics_frame
		if not player.is_on_floor():
			left_floor = true
		# 공중에서 일찍 멈춰 착지점에 감속한다.
		if player.global_position.x >= destination.x - 34:
			player.set_move_vector(Vector2.ZERO)
		if left_floor and player.is_on_floor():
			break
	player.release_jump()
	player.set_move_vector(Vector2.ZERO)
	for ignored in 8:
		await physics_frame
	return _check(left_floor and player.is_on_floor() and absf(player.global_position.y - destination.y) < 4 and absf(player.global_position.x - destination.x) < 65 and player.last_safe_position == destination, "기본 점프 착지·새 발판 안전 복귀점: 위치 %s / 목적지 %s / 복귀 %s" % [player.global_position, destination, player.last_safe_position])

func _finish_stage() -> bool:
	for ignored in 10:
		if runner.stage_complete:
			return true
		match runner.current_section:
			PrototypeStageRunner.Section.ADVANCE_ONE:
				player.global_position.x = 1240
			PrototypeStageRunner.Section.ADVANCE_TWO:
				player.global_position.x = 3840
			PrototypeStageRunner.Section.WAVE_ONE, PrototypeStageRunner.Section.WAVE_TWO:
				for enemy in runner._active_enemies.duplicate():
					_defeat(enemy)
			PrototypeStageRunner.Section.ELITE:
				player.damage_receiver.health = 35
				_defeat(runner.armored_boar)
		if not _resolve_growth():
			return false
		runner._process(0.1)
	return _check(false, "스테이지 완료 대기 해소")


func _resolve_growth() -> bool:
	for ignored in 12:
		if growth.awaiting_job_confirmation:
			_tap(controls.job_ultimate_rects[0].get_center())
			_tap(controls.job_confirm_rect.get_center())
		elif growth.choosing:
			if growth.offered_cards[0].get("category", "") == "job":
				saw_job_card = true
			if growth.rerolls_remaining == 1:
				growth.reroll()
			_tap(controls.growth_card_rects[0].get_center())
		else:
			return true
	return _check(false, "성장 선택 대기 해소")


func _defeat(target: PrototypeTarget) -> void:
	if target.damage_receiver.dead:
		return
	target.set_process(false)
	target.damage_receiver.tick(1.0)
	var event := DamageEvent.new()
	event.event_id = StringName("gp107:%s:%d" % [target.get_instance_id(), target.spawn_generation])
	event.attacker_id = &"player"
	event.damage = 9999
	event.tags = PackedStringArray(["test"])
	target.receive_damage(event)


func _tap(position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 4
	event.pressed = true
	event.position = position
	controls._input(event)


func _check(condition: bool, label: String) -> bool:
	if condition:
		return true
	push_error("GP-107 실패: %s" % label)
	paused = false
	quit(1)
	return false
