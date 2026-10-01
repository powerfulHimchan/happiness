extends SceneTree

const SANDBOX := preload("res://scenes/movement/ground_movement_sandbox.tscn")
const SAVE_PATH := "user://gp108_runtime_checkpoint.json"
const RECORD_PATH := "user://gp108_runtime_records.jsonl"
var sandbox: Node
var controls: Control
var player: PrototypePlayer
var growth: PrototypeGrowthController
var runner: PrototypeStageRunner
var weapons: PrototypeWeaponController
var store := RunCheckpointStore.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if not args.is_empty() else "seed"
	store.save_path = SAVE_PATH
	if mode in ["seed", "legacy-seed"]:
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
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	weapons.sword_combat.set_process(false)
	weapons.bow_combat.set_process(false)
	runner.set_process(false)
	if mode in ["seed", "legacy-seed"]:
		controls.begin_stage_from_main("bow")
		weapons.sword_combat._skill_1_cooldown_s = 3.25
		weapons.bow_combat._skill_2_cooldown_s = 4.5
		if not _finish_stage():
			return
		var saved := store.load_checkpoint()
		if not _check(paused and controls.current_screen_mode() == 11 and not saved.is_empty() and not saved.stage.reward_claimed and saved.weapons.equipment == {"sword": 0, "bow": 0}, "정예 처치 후 보상 대기 저장: pause=%s mode=%d saved=%s message=%s choosing=%s job_wait=%s active=%s" % [paused, controls.current_screen_mode(), saved, controls.checkpoint_message, growth.choosing, growth.awaiting_job_confirmation, growth.run_active]):
			return
		for bad in [null, {}, {"sword": -1, "bow": 0}, {"sword": 0.5, "bow": 0}, {"sword": 3, "bow": 0}, {"sword": "1", "bow": 0}, {"sword": NAN, "bow": 0}, {"sword": 1, "bow": 0}]:
			var invalid := saved.duplicate(true)
			invalid.weapons.equipment = bad
			if not _check(store.save_checkpoint(invalid) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "손상·미래 등급 저장 차단"):
				return
		var invalid := saved.duplicate(true)
		invalid.stage.number = []
		if not _check(not RunCheckpointStore.valid_state(invalid), "손상된 스테이지 타입을 안전하게 거부"):
			return
		if mode == "legacy-seed":
			saved.stage.erase("reward_claimed")
			saved.weapons.erase("equipment")
			if not _check(store.save_checkpoint(saved) == OK, "이전 버전 저장 준비"):
				return
	else:
		var saved := store.load_checkpoint()
		if not _check(not saved.is_empty() and controls.current_screen_mode() == 2, "별도 프로세스 이어하기 표시"):
			return
		_tap(controls.main_continue_rect.get_center())
		if mode == "claim":
			if not _check(paused and controls.current_screen_mode() == 11 and not runner.reward_claimed and weapons.active_weapon_id == "bow", "보상 대기 상태 재실행 복원"):
				return
			for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
				controls.size = dimensions
				controls._refresh_layout()
				controls._refresh_weapon_reward_layout()
				var safe: Rect2 = controls.layout_snapshot().safe
				var rects: Array[Rect2] = controls.weapon_reward_rects.duplicate()
				rects.append(controls.weapon_reward_confirm_rect)
				rects.append(controls.weapon_reward_skip_rect)
				for index in rects.size():
					if not _check(safe.encloses(rects[index]), "두 화면 비율에서 보상 입력 안전 영역"):
						return
					for other in range(index + 1, rects.size()):
						if not _check(not rects[index].intersects(rects[other]), "카드·확정·유지 버튼 겹침 없음"):
							return
			_tap(controls.weapon_reward_confirm_rect.get_center())
			sandbox._continue_stage("wind")
			if not _check(controls.current_screen_mode() == 11 and runner.stage_number == 1, "미선택 확정·보상 전 경로 진행 차단"):
				return
			_tap(controls.weapon_reward_rects[0].get_center())
			controls.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
			controls.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
			if not _check(paused and controls.current_screen_mode() == 11 and controls.selected_weapon_reward == 0, "백그라운드 복귀에서 보상 선택 유지"):
				return
			store.save_path = "user://gp108_missing_directory/checkpoint.json"
			_tap(controls.weapon_reward_confirm_rect.get_center())
			if not _check(controls.current_screen_mode() == 11 and not runner.reward_claimed and weapons.equipment == {"sword": 0, "bow": 0} and controls.checkpoint_message.begins_with("중간 저장 실패"), "저장 실패 시 장비·확정 상태 롤백"):
				return
			store.save_path = SAVE_PATH
			if not _check(store.load_checkpoint() == saved, "실패한 교체가 기존 저장을 보존"):
				return
			_tap(controls.weapon_reward_confirm_rect.get_center())
			if not _check(controls.current_screen_mode() == 9 and runner.reward_claimed and weapons.equipment == {"sword": 1, "bow": 0} and weapons.active_weapon_id == "bow" and is_equal_approx(weapons.sword_combat._skill_1_cooldown_s, 3.25) and is_equal_approx(weapons.bow_combat._skill_2_cooldown_s, 4.5), "희귀 검 교체·주 무기와 개별 쿨다운 유지"):
				return
			if not _check(store.load_checkpoint().stage.reward_claimed and not sandbox._claim_weapon_reward("bow"), "확정 상태 저장·중복 보상 차단"):
				return
		elif mode == "finish":
			if not _check(controls.current_screen_mode() == 9 and weapons.equipment == {"sword": 1, "bow": 0} and player.weapon_equipment == weapons.equipment, "확정 후 재실행은 경로 선택·장비 복원"):
				return
			if not _test_damage_paths():
				return
			_tap(controls.stage_route_rects[1].get_center())
			if not _finish_stage():
				return
			if not _check(controls.current_screen_mode() == 11 and controls.weapon_reward_cards[1].grade == 2 and weapons.equipment.sword == 1, "두 번째 정예는 영웅 등급·기존 장비 유지"):
				return
			_tap(controls.weapon_reward_rects[1].get_center())
			_tap(controls.weapon_reward_confirm_rect.get_center())
			var backup := store._read(SAVE_PATH + ".bak")
			if not _check(weapons.equipment == {"sword": 1, "bow": 2} and backup.stage.number == 1 and backup.weapons.equipment == {"sword": 1, "bow": 0}, "영웅 활 교체·이전 스테이지 복구 파일 보존"):
				return
			var before := weapons.checkpoint_snapshot()
			weapons._switch_cooldown_remaining_s = 0
			weapons.request_weapon_switch()
			if not _check(weapons.active_weapon_id == "sword" and weapons.equipment.bow == 2 and weapons.checkpoint_snapshot().bow == before.bow and "+10%" in controls.movement_metrics.weapon_backup_effect, "교체한 장비 전환·영웅 보조 효과·쿨다운 보존"):
				return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage():
				return
			if not _check(controls.current_screen_mode() == 1 and runner.stage_history.size() == 3 and growth.total_experience == 240 and store.load_checkpoint().is_empty(), "장비 보존 3스테이지 완주·저장 정리"):
				return
			controls.begin_retry("sword")
			if not _check(weapons.equipment == {"sword": 0, "bow": 0} and player.weapon_equipment == weapons.equipment, "새 도전은 일반 등급으로 초기화"):
				return
			store.clear_checkpoint()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORD_PATH))
		elif mode == "legacy-resume":
			if not _check(controls.current_screen_mode() == 9 and runner.reward_claimed and weapons.equipment == {"sword": 0, "bow": 0}, "이전 버전은 일반 장비·경로 선택으로 호환 복원"):
				return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage():
				return
			_tap(controls.weapon_reward_skip_rect.get_center())
			if not _check(controls.current_screen_mode() == 9 and store.load_checkpoint().stage.reward_claimed and weapons.equipment == {"sword": 0, "bow": 0}, "현재 무기 유지도 저장하고 다음 경로로 진행"):
				return
			store.clear_checkpoint()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORD_PATH))
		else:
			_check(false, "알 수 없는 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-108 runtime test: OK (%s)" % mode)
	quit(0)

func _test_damage_paths() -> bool:
	var equipment := weapons.equipment.duplicate()
	var bonuses := [player.growth_common_bonus, player.growth_sword_bonus, player.growth_bow_bonus]
	player.growth_common_bonus = 0
	player.growth_sword_bonus = 0
	player.growth_bow_bonus = 0
	var target := sandbox.get_node("Targets/CrossingTargetA") as PrototypeTarget
	target.set_process(false)
	target.visible = true
	player.facing_direction = 1
	target.damage_receiver.max_health = 5000
	weapons.set_equipment({"sword": 1, "bow": 0})
	for attack in [{"id": &"sword_basic", "damage": 115}, {"id": &"sword_spin", "damage": 125}]:
		target.reset_target()
		weapons.sword_combat._action_sequence += 1
		weapons.sword_combat._damage_target(target, attack.id, 100, 0, PackedStringArray(["test"]), 0)
		if not _check(target.damage_receiver.health == 5000 - int(attack.damage), "검 일반 공격·스킬의 실제 피해에 희귀 등급과 고유 효과 적용"):
			return false
	weapons.set_equipment({"sword": 0, "bow": 1})
	target.reset_target()
	weapons.sword_combat._action_sequence += 1
	weapons.sword_combat._damage_target(target, &"sword_basic", 100, 0, PackedStringArray(["test"]), 0)
	if not _check(target.damage_receiver.health == 4895 and player.growth_damage(100, "sword", "skill") == 100, "보조 활 고유 효과는 기본 공격에만 5%%·등급 피해는 미적용"):
		return false
	weapons.set_equipment({"sword": 1, "bow": 2})
	for is_skill in [false, true]:
		target.reset_target()
		target.global_position = player.global_position + Vector2(250, 0)
		var tags := PackedStringArray(["bow", "skill"] if is_skill else ["bow", "basic"])
		weapons.bow_combat._spawn_projectile("gp108:arrow:%s" % is_skill, &"bow_test", 100, 1, Vector2.RIGHT, tags)
		var projectile := get_nodes_in_group("bow_projectile")[-1] as BowProjectile
		projectile._physics_process(0.2)
		var expected := 135 if is_skill else 150
		if not _check(projectile.damage == expected and target.damage_receiver.health == 5000 - expected, "활 실제 투사체: 영웅 고유 효과·희귀 보조 검 효과 구분"):
			return false
		projectile.free()
	target.reset_target()
	target.global_position = player.global_position + Vector2(250, 0)
	weapons.bow_combat._action = BowCombatController.Action.ARROW_RAIN
	weapons.bow_combat._rain_anchor = target.global_position
	weapons.bow_combat._action_sequence += 1
	weapons.bow_combat._execute_skill_hit(weapons.bow_combat.skill_2, 0)
	weapons.bow_combat._action = BowCombatController.Action.NONE
	if not _check(target.damage_receiver.health == 4989, "화살비 실제 영역 타격에 등급과 보조 검 스킬 효과 적용"):
		return false
	target.visible = false
	if not _check(player.growth_damage(100, "bow", "ultimate") == 100 and not weapons.equip_reward("bow", 1) and not weapons.equip_reward("axe", 2), "필살기 제외·장비 하향과 미지원 무기 거부"):
		return false
	weapons.set_equipment(equipment)
	player.growth_common_bonus = bonuses[0]
	player.growth_sword_bonus = bonuses[1]
	player.growth_bow_bonus = bonuses[2]
	return true

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
	event.event_id = StringName("gp108:%s:%d" % [target.get_instance_id(), target.spawn_generation])
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
	push_error("GP-108 실패: %s" % label)
	paused = false
	quit(1)
	return false
