extends SceneTree

const SANDBOX := preload("res://scenes/movement/ground_movement_sandbox.tscn")
const SAVE_PATH := "user://gp106_runtime_checkpoint.json"
const RECORD_PATH := "user://gp106_runtime_records.jsonl"
var sandbox: Node
var controls: Control
var player: PrototypePlayer
var growth: PrototypeGrowthController
var runner: PrototypeStageRunner
var weapons: PrototypeWeaponController
var ultimate: UltimateController
var recorder: LocalTestRecorder
var saw_job_card: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var store := RunCheckpointStore.new()
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
	ultimate = sandbox.get_node("Player/UltimateController")
	recorder = sandbox.get_node("LocalTestRecorder")
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	weapons.sword_combat.set_process(false)
	weapons.bow_combat.set_process(false)
	for viewport in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = viewport
		controls._refresh_layout()
		_tap(controls.main_start_rect.get_center())
		if not _check(controls.current_screen_mode() == 10 and not growth.run_active and recorder.summary_snapshot().run_count == 0, "확정 전 무기 선택에서는 도전을 시작하지 않음"):
			return
		var layout: Dictionary = controls.layout_snapshot()
		var safe: Rect2 = layout.safe
		var rectangles: Array = layout.start_weapon_cards.duplicate()
		rectangles.append(layout.start_weapon_confirm)
		rectangles.append(layout.start_weapon_cancel)
		for i in rectangles.size():
			if not _check(safe.encloses(rectangles[i]), "무기 선택의 두 화면 비율 안전 영역"):
				return
			for j in range(i + 1, rectangles.size()):
				if not _check(not rectangles[i].intersects(rectangles[j]), "카드와 버튼 비중첩"):
					return
		_tap(controls.start_weapon_card_rects[1].get_center())
		controls.notification(Control.NOTIFICATION_APPLICATION_PAUSED)
		controls.notification(Control.NOTIFICATION_APPLICATION_RESUMED)
		if not _check(controls.selected_starting_weapon == "bow" and controls.command_buffer.pending_count() == 0, "선택 중 앱 복귀 시 선택 유지·입력 해제"):
			return
		_tap(controls.start_weapon_cancel_rect.get_center())
		if not _check(controls.current_screen_mode() == 2 and not growth.run_active and weapons.active_weapon_id == "sword", "취소는 주 무기·도전 상태를 변경하지 않음"):
			return
	for weapon_index in 2:
		var weapon := "sword" if weapon_index == 0 else "bow"
		var other := "bow" if weapon_index == 0 else "sword"
		sandbox._finish_growth_selection()
		controls.show_main_screen()
		controls._refresh_layout()
		_tap(controls.main_start_rect.get_center())
		_tap(controls.start_weapon_card_rects[weapon_index].get_center())
		var confirm: Vector2 = controls.start_weapon_confirm_rect.get_center()
		_tap(confirm)
		if not _check(controls.current_screen_mode() == 0 and growth.run_active and weapons.active_weapon_id == weapon and weapons.switch_count == 0 and is_zero_approx(weapons._switch_cooldown_remaining_s) and runner.stage_number == 1 and player.damage_receiver.health == 100 and growth.level == 1 and ultimate.selected_profile.is_empty() and store.load_checkpoint().is_empty(), "확정한 검·활로 새 도전·전환 대기시간 없음"):
			return
		var primary := "strength" if weapon_index == 0 else "shooting"
		var secondary := "determination" if weapon_index == 0 else "nature"
		if not _check(is_equal_approx(growth.jobs.score(primary), 0.20) and is_equal_approx(growth.jobs.score(secondary), 0.12) and growth.jobs.job_id.is_empty() and growth.jobs.contributions.ability.is_empty(), "시작 무기 초기 성향만 반영·직업 미고정"):
			return
		var metrics: Dictionary = controls.movement_metrics
		if not _check(metrics.active_weapon_id == weapon and metrics.skill_1_button_label == ("돌진" if weapon_index == 0 else "관통") and metrics.skill_2_button_label == ("회전" if weapon_index == 0 else "화살비"), "주 무기와 HUD 스킬 일치"):
			return
		var runs: int = recorder.summary_snapshot().run_count
		_tap(confirm)
		controls.release_all_inputs()
		if not _check(recorder.summary_snapshot().run_count == runs, "확정 중복 터치로 도전 중복 시작 차단"):
			return
		player.global_position.x = 1240
		runner._process(0.1)
		for enemy in runner._active_enemies:
			enemy.set_process(false)
		player.global_position = Vector2(1420, 780)
		player.facing_direction = 1
		player._input_lock_remaining_s = 0.0
		var camera := player.get_node("Camera2D") as Camera2D
		camera.reset_smoothing()
		camera.force_update_scroll()
		weapons.target_selector.force_scan()
		weapons.request_skill_1()
		var combat: Node = weapons.sword_combat if weapon_index == 0 else weapons.bow_combat
		if not _check(float(combat.get("_skill_1_cooldown_s")) > 0.0, "선택 무기의 실제 스킬 발동"):
			return
		var cooldown: float = combat.get("_skill_1_cooldown_s")
		weapons.prepare_next_stage()
		player.prepare_next_stage(sandbox.TRACK_START)
		weapons.request_weapon_switch()
		if not _check(weapons.active_weapon_id == other and weapons.switch_count == 1 and is_equal_approx(float(combat.get("_skill_1_cooldown_s")), cooldown), "보조 무기 전환·무기별 쿨다운 유지"):
			return
		weapons._switch_cooldown_remaining_s = 0.0
		weapons.request_weapon_switch()
		for ignored in 100:
			growth.jobs.add_weapon_hit(weapon)
		if not _finish_stage():
			return
		var saved := store.load_checkpoint()
		if not _check(not saved.is_empty() and saved.weapons.active == weapon and growth.jobs.job_id == ("vanguard" if weapon_index == 0 else "tracker"), "두 시작 무기의 실전 성장·직업 발현·중간 저장"):
			return
		sandbox._finish_growth_selection()
		controls.show_main_screen()
		var contents := FileAccess.get_file_as_string(SAVE_PATH)
		var old_result: Dictionary = controls.current_result_snapshot()
		_tap(controls.main_start_rect.get_center())
		_tap(controls.start_weapon_card_rects[1 - weapon_index].get_center())
		_tap(controls.start_weapon_cancel_rect.get_center())
		if not _check(FileAccess.get_file_as_string(SAVE_PATH) == contents and controls.current_result_snapshot() == old_result and controls.checkpoint_available and weapons.active_weapon_id == weapon, "새 무기 선택 취소는 저장된 도전을 유지"):
			return
		_tap(controls.main_continue_rect.get_center())
		if not _check(paused and controls.current_screen_mode() == 9 and weapons.active_weapon_id == weapon and growth.jobs.job_id == saved.growth.job and player.damage_receiver.health == saved.player.health, "이어하기는 저장된 무기·직업을 복원"):
			return
		if not _check(not controls.begin_retry("invalid") and paused and not store.load_checkpoint().is_empty(), "잘못된 무기의 저장 삭제·도전 시작 차단"):
			return
	# 결과 화면의 재도전도 무기 선택을 거치고 취소하면 결과를 보존한다.
	sandbox._finish_growth_selection()
	controls.screen_mode = 1
	controls.result_snapshot = {"stage_count": 3, "completion_s": 99.0}
	controls._refresh_layout()
	_tap(controls.result_retry_rect.get_center())
	_tap(controls.start_weapon_cancel_rect.get_center())
	if not _check(controls.current_screen_mode() == 1 and controls.current_result_snapshot().completion_s == 99.0, "결과에서 재도전 선택·취소 시 결과 보존"):
		return
	store.clear_checkpoint()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORD_PATH))
	sandbox.free()
	print("GP-106 runtime test: OK")
	quit(0)

var _before_clear_health: int = 0


func _finish_stage() -> bool:
	if runner.current_section == PrototypeStageRunner.Section.ADVANCE_ONE:
		player.global_position.x = 1240
		runner._process(0.1)
	for enemy in runner._active_enemies.duplicate():
		_defeat(enemy)
	if not _resolve_growth():
		return false
	runner._process(0.1)
	player.global_position.x = 3840
	runner._process(0.1)
	for enemy in runner._active_enemies.duplicate():
		_defeat(enemy)
	if not _resolve_growth():
		return false
	runner._process(0.1)
	player.damage_receiver.health = 35
	_defeat(runner.armored_boar)
	if not _resolve_growth():
		return false
	_before_clear_health = player.damage_receiver.health
	runner._process(0.1)
	# 기존 회귀 검사는 현재 무기 유지 후 경로 선택을 이어간다.
	if controls.current_screen_mode() == 11:
		_tap(controls.weapon_reward_skip_rect.get_center())
	return true


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
	event.event_id = StringName("gp106:%s:%d" % [target.get_instance_id(), target.spawn_generation])
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
	push_error("GP-106 실패: %s" % label)
	paused = false
	quit(1)
	return false
