extends SceneTree

const SANDBOX := preload("res://scenes/movement/ground_movement_sandbox.tscn")
const SAVE_PATH := "user://gp109_runtime_checkpoint.json"
const RECORD_PATH := "user://gp109_runtime_records.jsonl"
var sandbox: Node
var controls: Control
var player: PrototypePlayer
var growth: PrototypeGrowthController
var runner: PrototypeStageRunner
var weapons: PrototypeWeaponController
var recorder: LocalTestRecorder
var store := RunCheckpointStore.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if not args.is_empty() else "seed"
	store.save_path = SAVE_PATH
	if mode in ["seed", "resolved-seed"]:
		store.clear_checkpoint()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORD_PATH))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
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
	recorder = sandbox.get_node("LocalTestRecorder")
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	weapons.sword_combat.set_process(false)
	weapons.bow_combat.set_process(false)
	runner.set_process(false)
	if mode in ["seed", "resolved-seed"]:
		if not _reach_boss():
			return
		if not _test_boss_patterns():
			return
		if not _finish_stage():
			return
		var saved := store.load_checkpoint()
		if not _check(paused and controls.current_screen_mode() == 12 and not saved.is_empty() and saved.stage.number == 3 and saved.stage.boss_choice == "" and not runner.current_metrics().run_complete and growth.run_active and recorder.summary_snapshot().completed_run_count == 0 and growth.total_experience == 240, "보스 승리는 선택 대기로 저장·아직 완주 집계 없음"):
			return
		for value in [null, [], "invalid", "rescue"]:
			var invalid := saved.duplicate(true)
			invalid.stage.boss_choice = value
			if not _check(store.save_checkpoint(invalid) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "손상 선택·이력 불일치 저장 차단"):
				return
		var invalid := saved.duplicate(true)
		invalid.stage.erase("boss_choice")
		if not _check(not RunCheckpointStore.valid_state(invalid), "보스 완료 저장은 선택 상태 필수"):
			return
		var contents := FileAccess.get_file_as_string(SAVE_PATH)
		var broken := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		broken.store_string("interrupted boss save")
		broken.close()
		if not _check(store.load_checkpoint().stage.number == 2 and "복구" in store.message, "보스 저장 손상 시 이전 두 번째 완료 복구"):
			return
		var repaired := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		repaired.store_string(contents)
		repaired.close()
		if mode == "resolved-seed":
			# 저장 성공 직후 완료 이벤트 전 강제 종료를 별도 프로세스로 재현한다.
			runner.boss_choice = "destroy"
			runner.stage_history[-1]["boss_choice"] = "destroy"
			if not _check(sandbox._save_checkpoint(runner.current_metrics(), false) == OK and recorder.summary_snapshot().completed_run_count == 0, "확정 저장 이후 완료 기록 전 종료 준비"):
				return
	elif mode in ["resolve", "resolved-resume"]:
		var saved := store.load_checkpoint()
		if not _check(not saved.is_empty() and controls.current_screen_mode() == 2 and controls.checkpoint_available, "새 프로세스에 보스 이어하기 표시"):
			return
		_tap(controls.main_continue_rect.get_center())
		if mode == "resolved-resume":
			if not _check(controls.current_screen_mode() == 1 and not paused and controls.current_result_snapshot().boss_choice == "destroy" and recorder.summary_snapshot().boss_destroy_count == 1 and recorder.summary_snapshot().completed_run_count == 1 and store.load_checkpoint().is_empty(), "확정 후 중단은 파괴 결과 복원·한 번만 집계"):
				return
		else:
			if not _check(paused and controls.current_screen_mode() == 12 and runner.awaiting_boss_choice() and weapons.active_weapon_id == saved.weapons.active and weapons.equipment.sword == int(saved.weapons.equipment.sword) and weapons.equipment.bow == int(saved.weapons.equipment.bow) and player.damage_receiver.health == saved.player.health, "보스 대기 재실행은 재전투 없이 장비·체력 보존"):
				return
			for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
				controls.size = dimensions
				controls._refresh_layout()
				controls._refresh_boss_choice_layout()
				var safe: Rect2 = controls.layout_snapshot().safe
				for index in controls.boss_choice_rects.size():
					if not _check(safe.encloses(controls.boss_choice_rects[index]) and not controls.boss_choice_rects[index].intersects(controls.boss_choice_confirm_rect), "두 화면 비율 선택 카드·확정 버튼 안전 영역"):
						return
				if not _check(safe.encloses(controls.boss_choice_confirm_rect) and not controls.boss_choice_rects[0].intersects(controls.boss_choice_rects[1]), "두 카드와 확정 입력 겹침 없음"):
					return
			_tap(controls.boss_choice_confirm_rect.get_center())
			sandbox._continue_stage("wind")
			if not _check(runner.awaiting_boss_choice() and not sandbox._resolve_boss_choice("invalid") and controls.current_screen_mode() == 12, "미선택 확정·잘못된 선택·경로 우회 차단"):
				return
			_tap(controls.boss_choice_rects[0].get_center())
			controls.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
			controls.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
			if not _check(paused and controls.selected_boss_choice == 0, "앱 복귀 후 구출 선택·전투 정지 유지"):
				return
			store.save_path = "user://gp109_missing_directory/checkpoint.json"
			_tap(controls.boss_choice_confirm_rect.get_center())
			if not _check(controls.current_screen_mode() == 12 and runner.boss_choice == "" and runner.stage_history[-1].boss_choice == "" and recorder.summary_snapshot().completed_run_count == 0 and controls.checkpoint_message.begins_with("중간 저장 실패"), "저장 실패 시 선택·이력 롤백·완주 기록 미생성"):
				return
			store.save_path = SAVE_PATH
			if not _check(store.load_checkpoint() == saved, "실패한 확정은 이전 보스 저장 보존"):
				return
			_tap(controls.boss_choice_confirm_rect.get_center())
			if not _check(not paused and controls.current_screen_mode() == 1 and controls.current_result_snapshot().boss_choice == "rescue" and not growth.run_active and recorder.summary_snapshot().boss_rescue_count == 1 and recorder.summary_snapshot().completed_run_count == 1 and store.load_checkpoint().is_empty(), "구출 확정·결과 표시·완주 기록·중간 저장 정리"):
				return
			_tap(controls.boss_choice_confirm_rect.get_center())
			runner.force_emit_metrics()
			if not _check(not sandbox._resolve_boss_choice("destroy") and recorder.summary_snapshot().completed_run_count == 1 and recorder.summary_snapshot().boss_destroy_count == 0, "중복 터치와 완료 통지로 선택 변경·중복 집계 없음"):
				return
			if not _reach_boss() or not _finish_stage():
				return
			_tap(controls.boss_choice_rects[1].get_center())
			_tap(controls.boss_choice_confirm_rect.get_center())
			if not _check(controls.current_result_snapshot().boss_choice == "destroy" and recorder.summary_snapshot().completed_run_count == 2 and recorder.summary_snapshot().boss_rescue_count == 1 and recorder.summary_snapshot().boss_destroy_count == 1 and runner.stage_history[-1].boss_choice == "destroy", "다음 도전은 파괴 선택·구출/파괴 각 1회 집계"):
				return
	elif mode in ["empty", "empty-resolved"]:
		var summary := recorder.summary_snapshot()
		if not _check(store.load_checkpoint().is_empty() and not controls.checkpoint_available and summary.boss_destroy_count == 1 and summary.boss_rescue_count == (1 if mode == "empty" else 0) and summary.completed_run_count == (2 if mode == "empty" else 1), "재실행 후 선택 이력 유지·완료 저장 없음"):
			return
		store.clear_checkpoint()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORD_PATH))
	else:
		_check(false, "잘못된 검사 단계")
		return
	paused = false
	sandbox.free()
	print("GP-109 runtime test: OK (%s)" % mode)
	quit(0)

func _reach_boss() -> bool:
	controls.begin_retry("bow")
	if not _check(runner.boss_choice == "" and not runner.boss.visible and weapons.equipment == {"sword": 0, "bow": 0}, "새 도전은 보스·이전 선택·장비 초기화"):
		return false
	for stage in [1, 2]:
		if not _finish_stage():
			return false
		_tap(controls.weapon_reward_rects[stage - 1].get_center())
		_tap(controls.weapon_reward_confirm_rect.get_center())
		_tap(controls.stage_route_rects[stage % 2].get_center())
	for ignored in 8:
		if runner.current_section == PrototypeStageRunner.Section.ELITE:
			break
		if not _step_section():
			return false
	return _check(runner.stage_number == 3 and runner.final_enemy() == runner.boss and runner.boss.visible and not runner.armored_boar.visible and runner.boss.damage_receiver.max_health == 480 and runner.current_metrics().stage_section_name == "보스 · 웃는 태엽 기사", "마지막 관문에서 480 HP 전용 보스 교체·HUD 표시")

func _test_boss_patterns() -> bool:
	var boss := runner.boss
	boss.set_process(false)
	boss._begin_next_pattern()
	boss._process(0.64)
	if not _check(boss.state == EliteArmoredBoar.State.WARNING and boss.warning_feedback_snapshot().shape == "직선", "돌진 예고가 먼저 유지됨"):
		return false
	boss._process(0.02)
	boss.position.x = BossClockworkKnight.ARENA_LEFT_X + 10
	boss._charge_direction = -1
	player.global_position.x = BossClockworkKnight.ARENA_LEFT_X - 600
	boss._process(0.1)
	if not _check(boss.state == EliteArmoredBoar.State.STUNNED and boss.position.x == BossClockworkKnight.ARENA_LEFT_X, "돌진은 평지 경계에서 기절·낙하 구간 진입 없음"):
		return false
	if not _hit_boss(40, "sword", 70):
		return false
	boss._set_state(EliteArmoredBoar.State.IDLE, "검사")
	if not _hit_boss(40, "bow", 50) or not _hit_boss(50, "sword", 30):
		return false
	boss._begin_next_pattern()
	boss._process(0.84)
	if not _check(boss.current_pattern == EliteArmoredBoar.Pattern.SHOCKWAVE and boss.state == EliteArmoredBoar.State.WARNING and boss.warning_feedback_snapshot().shape == "원형", "충격파 예고·돌진과 패턴 구분"):
		return false
	boss._process(0.02)
	var waves := get_nodes_in_group("enemy_projectile").size()
	if not _check(waves == 2, "1페이즈 지면 충격파 2개 생성"):
		return false
	boss._process(0.35)
	boss._process(0.76)
	boss._begin_next_pattern()
	boss._process(0.99)
	if not _check(boss.current_pattern == BossClockworkKnight.VOLLEY_PATTERN and boss.state == EliteArmoredBoar.State.WARNING and boss.warning_feedback_snapshot().shape == "부채꼴" and boss.warning_line.visible, "세 번째 패턴은 부채꼴 탄막 예고"):
		return false
	boss._process(0.02)
	var shots := _boss_shots()
	if not _check(shots.size() == 3 and boss.pattern_history == [EliteArmoredBoar.Pattern.CHARGE, EliteArmoredBoar.Pattern.SHOCKWAVE, BossClockworkKnight.VOLLEY_PATTERN], "1페이즈 탄막 3개·세 패턴 순환"):
		return false
	var shot := shots[1]
	player.global_position = shot.global_position + shot.direction * 200 + Vector2(0, 42)
	player.damage_receiver.tick(1.0)
	var health := player.damage_receiver.health
	shot._physics_process(0.5)
	if not _check(player.damage_receiver.health == health - 8 and shot.attacker_id == &"clockwork_knight" and shot.damage_tags.has("boss"), "보스 탄막 실제 충돌·8 피해·보스 출처"):
		return false
	for projectile in get_nodes_in_group("enemy_projectile"):
		projectile.free()
	if not _hit_boss(100, "test", 100):
		return false
	if not _check(boss.phase == 2 and boss.state == EliteArmoredBoar.State.PHASE_TRANSITION and boss.damage_receiver.health == 230, "체력 절반 이하 실제 타격으로 2페이즈"):
		return false
	boss._process(0.75)
	boss.last_pattern = EliteArmoredBoar.Pattern.SHOCKWAVE
	boss._begin_next_pattern()
	boss.set_enemy_time_scale(0.5)
	boss._process(1.0)
	if not _check(boss.state == EliteArmoredBoar.State.WARNING and _boss_shots().is_empty(), "시간 감속은 보스 경고·발사를 함께 늦춤"):
		return false
	boss.set_enemy_time_scale(1.0)
	boss._process(0.26)
	shots = _boss_shots()
	if not _check(shots.size() == 5 and shots[0].damage == 10 and is_equal_approx(shots[0].speed_px_s, 600), "2페이즈 탄막 5개·10 피해·가속"):
		return false
	boss.last_pattern = EliteArmoredBoar.Pattern.CHARGE
	boss._begin_next_pattern()
	boss._process(0.61)
	boss._process(0.23)
	if not _check(get_nodes_in_group("enemy_projectile").size() == 9 and boss._charge_warning_duration() < 0.65, "2페이즈 추가 충격파·돌진 예고 단축"):
		return false
	for projectile in get_nodes_in_group("enemy_projectile"):
		projectile.free()
	player.prepare_next_stage(Vector2(4300, 780))
	return true

func _boss_shots() -> Array[EnemySeedProjectile]:
	var result: Array[EnemySeedProjectile] = []
	for node in get_nodes_in_group("enemy_projectile"):
		if node is EnemySeedProjectile and node.attacker_id == &"clockwork_knight":
			result.append(node)
	return result

func _hit_boss(amount: int, tag: String, expected: int) -> bool:
	var event := DamageEvent.new()
	event.event_id = StringName("gp109:hit:%d" % runner.boss.damage_receiver.health)
	event.attacker_id = &"player"
	event.damage = amount
	event.tags = PackedStringArray([tag])
	var health := runner.boss.damage_receiver.health
	var first := runner.boss.receive_damage(event)
	var second := runner.boss.receive_damage(event)
	return _check(first == DamageReceiver.Result.APPLIED and second == DamageReceiver.Result.DUPLICATE_BLOCKED and runner.boss.damage_receiver.health == health - expected, "보스 갑옷·활 약점·기절 검 약점·중복 타격 방지")

func _finish_stage() -> bool:
	for ignored in 10:
		if runner.stage_complete:
			return true
		if not _step_section():
			return false
	return _check(false, "스테이지 완료 대기 해소")

func _step_section() -> bool:
	match runner.current_section:
		PrototypeStageRunner.Section.ADVANCE_ONE:
			player.global_position.x = 1240
		PrototypeStageRunner.Section.ADVANCE_TWO:
			player.global_position.x = 3840
		PrototypeStageRunner.Section.WAVE_ONE, PrototypeStageRunner.Section.WAVE_TWO:
			for enemy in runner._active_enemies.duplicate():
				_defeat(enemy)
		PrototypeStageRunner.Section.ELITE:
			_defeat(runner.final_enemy())
	if not _resolve_growth():
		return false
	runner._process(0.1)
	return true

func _resolve_growth() -> bool:
	for ignored in 12:
		if growth.awaiting_job_confirmation:
			_tap(controls.job_ultimate_rects[0].get_center())
			_tap(controls.job_confirm_rect.get_center())
		elif growth.choosing:
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
	event.event_id = StringName("gp109:defeat:%s:%d" % [target.get_instance_id(), target.spawn_generation])
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
	push_error("GP-109 실패: %s" % label)
	paused = false
	quit(1)
	return false
