extends SceneTree

const SANDBOX := preload("res://scenes/movement/ground_movement_sandbox.tscn")
const SAVE_PATH := "user://gp105_runtime_checkpoint.json"
const RECORD_PATH := "user://gp105_runtime_records.jsonl"
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
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if not args.is_empty() else "seed"
	var store := RunCheckpointStore.new()
	store.save_path = SAVE_PATH
	if mode in ["seed", "seed-bow"]:
		store.clear_checkpoint()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORD_PATH))
	if mode == "corrupt":
		var interrupted := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		interrupted.store_string("interrupted write")
		interrupted.close()
		print("GP-105 runtime test: OK (corrupt)")
		quit(0)
		return
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	# ready 전에 기록 경로를 지정해 다음 프로세스도 같은 기록을 읽는다.
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
	if mode in ["seed", "seed-bow"]:
		controls.begin_stage_from_main()
		# 성향 누적과 실제 처치·카드 선택으로 직업을 발현한다.
		if mode == "seed-bow":
			weapons.request_weapon_switch()
		for ignored in 100:
			growth.jobs.add_weapon_hit(weapons.active_weapon_id)
		weapons.sword_combat._skill_1_cooldown_s = 3.5
		weapons.bow_combat._skill_2_cooldown_s = 4.75
		ultimate.gauge = 60
		if not _finish_stage():
			return
		var saved := store.load_checkpoint()
		if not _check(not saved.is_empty() and saved.stage.number == 1 and controls.checkpoint_available and paused and growth.jobs.job_id == ("tracker" if mode == "seed-bow" else "vanguard"), "첫 중간 완료 저장·직업 보존"):
			return
		var health := player.damage_receiver.health
		runner.force_emit_metrics()
		runner.force_emit_metrics()
		if not _check(player.damage_receiver.health == health and store.load_checkpoint() == saved, "회복·저장 중복 없음"):
			return
		for key in ["level", "xp", "total_xp", "rerolls"]:
			var invalid := saved.duplicate(true)
			invalid.growth[key] = -1
			if not _check(store.save_checkpoint(invalid) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "손상된 성장 상태 저장 차단"):
				return
		for section in ["stage", "growth", "player", "weapons", "ultimate", "recorder"]:
			var invalid := saved.duplicate(true)
			invalid[section] = {"health": "잘못된 형식"}
			if not _check(not RunCheckpointStore.valid_state(invalid), "하위 필드 누락·타입 손상 차단"):
				return
	elif mode == "empty":
		if not _check(store.load_checkpoint().is_empty() and not controls.checkpoint_available and not sandbox.continue_saved_run(), "저장 삭제 후 별도 프로세스에서 이어하기 없음"):
			return
	else:
		var saved := store.load_checkpoint()
		if not _check(not saved.is_empty() and controls.current_screen_mode() == 2 and controls.checkpoint_available, "새 프로세스 메인에 이어하기 표시"):
			return
		for viewport_size in [Vector2(1280, 720), Vector2(2400, 1080)]:
			controls.size = viewport_size
			controls._refresh_layout()
			var safe: Rect2 = controls.layout_snapshot().safe
			if not _check(safe.encloses(controls.main_continue_rect) and not controls.main_continue_rect.intersects(controls.main_feedback_rect) and not controls.main_continue_rect.intersects(controls.main_start_rect), "이어하기 버튼 두 화면 비율 안전 영역"):
				return
		_tap(controls.main_continue_rect.get_center())
		if not _check(paused and controls.current_screen_mode() == 9 and runner.stage_number == saved.stage.number and player.damage_receiver.health == saved.player.health and player.damage_receiver.max_health == saved.player.max_health and is_equal_approx(player.growth_sword_bonus, saved.player.sword) and growth.level == saved.growth.level and growth.ranks == saved.growth.ranks and growth.jobs.contributions == saved.growth.contributions and ultimate.selected_profile.id == saved.ultimate.profile and weapons.active_weapon_id == saved.weapons.active and is_equal_approx(weapons.sword_combat._skill_1_cooldown_s, saved.weapons.sword._skill_1_cooldown_s), "터치 이어하기로 회복·패시브·성장·필살기·무기·쿨다운 그대로 복원"):
			return
		var health := player.damage_receiver.health
		runner.force_emit_metrics()
		if not _check(player.damage_receiver.health == health and not sandbox.continue_saved_run(), "복원 직후 회복·재호출 중복 차단"):
			return
		if mode == "death":
			player.player_died.emit()
			if not _check(not paused and store.load_checkpoint().is_empty(), "사망 시 주 저장·백업 삭제"):
				return
		elif mode == "new":
			controls.begin_retry()
			if not _check(not paused and store.load_checkpoint().is_empty() and growth.level == 1 and runner.stage_number == 1, "새 도전 저장 삭제·초기화"):
				return
		elif mode == "resume" or mode == "finish":
			_tap(controls.stage_route_rects[1].get_center())
			if not _check(not paused and runner.stage_number == int(saved.stage.number) + 1 and runner.route_id == "wind" and growth.rerolls_remaining == 1, "경로 터치로 다음 전투 재개"):
				return
			if not _finish_stage():
				return
			if mode == "resume":
				if not _check(store.load_checkpoint().stage.number == 2 and FileAccess.file_exists(SAVE_PATH + ".bak"), "2번째 중간 완료·첫 완료 백업"):
					return
				# 전투 중 종료는 직전 완료 시점으로 돌아가므로 임의 변경을 저장하지 않는다.
				_tap(controls.stage_route_rects[0].get_center())
				player.damage_receiver.health = 1
				growth.experience = 0
			elif not _check(store.load_checkpoint().is_empty() and recorder.summary_snapshot().completed_run_count == 1 and recorder.summary_snapshot().run_count == 1 and runner.stage_history.size() == 3 and controls.current_screen_mode() == 1, "3스테이지 완주 단일 기록·저장 삭제"):
				return
		elif mode == "recover":
			if not _check(saved.stage.number == 1 and "복구" in store.message, "손상된 최신 저장은 이전 정상 저장 복구"):
				return
			var malformed := saved.duplicate(true)
			malformed.player.health = 0
			var payload := JSON.stringify(malformed)
			var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
			file.store_string(JSON.stringify({"version": 1, "payload": payload, "sha256": payload.sha256_text()}))
			file.close()
			if not _check(store.load_checkpoint() == saved, "체크섬이 정상이어도 잘못된 상태는 백업 복구"):
				return
			var bad := FileAccess.open(SAVE_PATH + ".bak", FileAccess.WRITE)
			bad.store_string("broken")
			bad.close()
			if not _check(store.load_checkpoint().is_empty(), "양쪽 손상 시 이어하기 차단"):
				return
			store.clear_checkpoint()
	print("GP-105 runtime test: OK (" + mode + ")")
	sandbox.free()
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
	event.event_id = StringName("gp105:%s:%d" % [target.get_instance_id(), target.spawn_generation])
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
	push_error("GP-105 실패: %s" % label)
	paused = false
	quit(1)
	return false
