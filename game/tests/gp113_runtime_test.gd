extends "res://tests/gp110_runtime_test.gd"

const GP113_SAVE := "user://gp113_checkpoint.json"
const GP113_LEGACY := "user://gp113_blueprints.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if not args.is_empty() else "seed"
	store.save_path = GP113_SAVE
	legacy.save_path = GP113_LEGACY
	if mode == "seed":
		store.clear_checkpoint()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GP113_LEGACY))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = "user://gp113_records.jsonl"
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
	match mode:
		"seed":
			controls.begin_retry()
			if not _finish_stage(): return
			if not _check(controls.weapon_reward_cards.size() == 2 and controls.unlocked_weapon_blueprints.is_empty() and not sandbox._claim_weapon_reward("clockwork_sword") and not weapons.equip_reward("clockwork_bow", 1), "처음에는 기본 두 보상·잠긴 설계도 장착 차단"): return
			if not _reach_boss() or not _finish_stage(): return
			if not _check(sandbox._resolve_boss_choice("destroy") and controls.unlocked_weapon_blueprints.size() == 2 and weapons.unlocked_blueprints.size() == 2, "실제 보스 파괴 완주로 검·활 설계도 영구 해금"): return
			var source := String(recorder.checkpoint_snapshot().id)
			if not _check(legacy.grant(source, "destroy") == OK and legacy.progress_snapshot().blueprints.size() == 2, "중복 완주로 설계도 수치 누적 없음"): return
			# 이전 버전이 이미 소비한 파괴 이벤트도 같은 두 설계도를 복원한다.
			legacy._append({"event": "claim", "source": source, "run_id": "gp113-old-run", "enabled": false})
			recorder.clear_records()
			sandbox._update_boss_legacy_status()
			if not _check(legacy.pending_reward().is_empty() and legacy.progress_snapshot().blueprints.size() == 2, "이전 소비 형식·기록 초기화와 영구 해금 독립"): return
			controls.show_main_screen()
			controls.show_start_weapon_selection()
			_tap(controls.start_weapon_confirm_rect.get_center())
			if not _check(player.boss_legacy.is_empty() and player.memory_id == "" and weapons.blueprints == {"sword": "", "bow": ""}, "일회 보상 없이 해금만 유지·특수 무기 자동 지급 없음"): return
			if not _finish_stage(): return
			if not _check(controls.weapon_reward_cards.size() == 4 and controls.weapon_reward_cards[2].id == "clockwork_sword" and controls.weapon_reward_cards[3].id == "clockwork_bow", "해금 후 기본·태엽 검·활 네 종류 선택"): return
			for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
				controls.size = dimensions
				controls._refresh_weapon_reward_layout()
				var safe: Rect2 = controls.layout_snapshot().safe
				var rectangles: Array = controls.weapon_reward_rects.duplicate()
				rectangles.append_array([controls.weapon_reward_confirm_rect, controls.weapon_reward_skip_rect])
				for i in rectangles.size():
					if not _check(safe.encloses(rectangles[i]), "네 보상·확정·유지 입력 두 화면 비율 안전 영역"): return
					for j in range(i + 1, rectangles.size()):
						if not _check(not rectangles[i].intersects(rectangles[j]), "보상 입력 겹침 없음"): return
				for i in controls.weapon_reward_cards.size():
					var card: Dictionary = controls.weapon_reward_cards[i]
					var width: float = controls.weapon_reward_rects[i].size.x
					if not _check(ThemeDB.fallback_font.get_string_size(card.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x < width and ThemeDB.fallback_font.get_string_size("현재: " + card.previous_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x < width, "네 카드 제목·현재 무기 글자 너비"): return
					for line in card.lines:
						if not _check(ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x < width, "네 카드 효과 설명 너비"): return
			weapons.sword_combat._skill_1_cooldown_s = 3.25
			weapons.bow_combat._skill_2_cooldown_s = 4.5
			var saved := store.load_checkpoint()
			_tap(controls.weapon_reward_rects[2].get_center())
			controls.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
			controls.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
			store.save_path = "user://gp113_missing/checkpoint.json"
			_tap(controls.weapon_reward_confirm_rect.get_center())
			if not _check(controls.current_screen_mode() == 11 and not runner.reward_claimed and weapons.blueprints == {"sword": "", "bow": ""} and player.weapon_blueprints == weapons.blueprints and weapons.equipment == {"sword": 0, "bow": 0}, "저장 실패는 무기·설계·확정 상태 함께 롤백"): return
			store.save_path = GP113_SAVE
			if not _check(store.load_checkpoint() == saved, "실패한 특수 장착은 이전 저장 보존"): return
			_tap(controls.weapon_reward_confirm_rect.get_center())
			if not _check(controls.current_screen_mode() == 9 and weapons.equipment.sword == 1 and weapons.blueprints.sword == "clockwork_sword" and player.weapon_blueprints == weapons.blueprints and is_equal_approx(weapons.sword_combat._skill_1_cooldown_s, 3.25) and is_equal_approx(weapons.bow_combat._skill_2_cooldown_s, 4.5) and not sandbox._claim_weapon_reward("clockwork_bow"), "특수 검 터치 확정·양쪽 쿨다운 유지·중복 선택 거부"): return
			if not _test_damage_paths(): return
			saved = store.load_checkpoint()
			for bad in [null, {}, {"sword": "clockwork_bow", "bow": ""}, {"sword": "unknown", "bow": ""}, {"sword": 1, "bow": ""}, {"sword": "clockwork_sword", "bow": "", "extra": ""}]:
				var invalid := saved.duplicate(true)
				invalid.weapons.blueprints = bad
				if not _check(store.save_checkpoint(invalid) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "손상·다른 무기 설계도 저장 차단"): return
			var normal := saved.duplicate(true)
			normal.weapons.equipment.sword = 0
			if not _check(not RunCheckpointStore.valid_state(normal), "일반 등급의 특수 설계 저장 거부"): return
		"resume":
			if not _check(controls.unlocked_weapon_blueprints.size() == 2 and sandbox.continue_saved_run() and weapons.blueprints.sword == "clockwork_sword" and "태엽 검" in controls.movement_metrics.weapon_equipment_summary and weapons.equipment.sword == 1, "별도 프로세스 해금·희귀 태엽 검·HUD 복원"): return
			sandbox._continue_stage("wind")
			if not _check(weapons.blueprints.sword == "clockwork_sword", "스테이지 전환 설계도 무기 유지"): return
			if not _finish_stage(): return
			_tap(controls.weapon_reward_rects[3].get_center())
			_tap(controls.weapon_reward_confirm_rect.get_center())
			if not _check(weapons.equipment.bow == 2 and weapons.blueprints == {"sword": "clockwork_sword", "bow": "clockwork_bow"} and store.load_checkpoint().weapons.blueprints == weapons.blueprints, "영웅 태엽 활 추가·검 설계 유지·확정 저장"): return
			if not _test_damage_paths(): return
			# 같은 등급의 기본/특수 교체는 허용하되 똑같은 보상·하향은 거부한다.
			if not _check(weapons.equip_reward("bow", 2) and weapons.blueprints.bow == "" and not weapons.equip_reward("bow", 2) and weapons.equip_reward("clockwork_bow", 2) and not weapons.equip_reward("clockwork_bow", 1), "동일 등급 다른 설계 교체·동일 무기·등급 하향 거부"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and weapons.blueprints.bow == "clockwork_bow", "두 무기 설계 이어하기"): return
			var backup_percent := "17.5%" if weapons.active_weapon_id == "sword" else "12.5%"
			if not _check(backup_percent in controls.movement_metrics.weapon_backup_effect, "해당 보조 무기 등급의 소수 효과 복원"): return
			var old := store.load_checkpoint()
			sandbox._continue_stage("meadow")
			if not _finish_stage(): return
			if not _check(sandbox._resolve_boss_choice("rescue") and controls.current_result_snapshot().weapon_blueprints == weapons.blueprints and legacy.progress_snapshot().blueprints.size() == 2, "반대 보스 선택 완주·결과 무기·영구 설계 유지"): return
			controls.begin_retry()
			if not _check(weapons.equipment == {"sword": 0, "bow": 0} and weapons.blueprints == {"sword": "", "bow": ""} and player.weapon_blueprints == weapons.blueprints and weapons.unlocked_blueprints.size() == 2, "새 도전 장비·설계 초기화·영구 해금 유지"): return
			old.weapons.erase("blueprints")
			if not _check(store.save_checkpoint(old) == OK, "설계 필드 없는 이전 저장 준비"): return
		"legacy-resume":
			if not _check(sandbox.continue_saved_run() and weapons.equipment == {"sword": 1, "bow": 2} and weapons.blueprints == {"sword": "", "bow": ""} and not "태엽" in controls.movement_metrics.weapon_equipment_summary, "이전 저장은 기존 기본 무기·등급으로 복원"): return
			legacy._append({"event": "reward", "source": "invalid", "choice": "invalid"})
			if not _check(legacy.progress_snapshot().blueprints.size() == 2, "잘못된 저널은 해금 변경 없음"): return
			store.clear_checkpoint()
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-113 runtime test: OK (%s)" % mode)
	quit(0)

func _test_damage_paths() -> bool:
	var previous := weapons.equipment.duplicate()
	var previous_designs := weapons.blueprints.duplicate()
	var previous_active := weapons.active_weapon_id
	var bonuses := [player.growth_common_bonus, player.growth_sword_bonus, player.growth_bow_bonus]
	player.growth_common_bonus = 0
	player.growth_sword_bonus = 0
	player.growth_bow_bonus = 0
	var target := sandbox.get_node("Targets/CrossingTargetA") as PrototypeTarget
	target.set_process(false)
	target.visible = true
	target.damage_receiver.max_health = 5000
	weapons.set_loadout({"sword": 1, "bow": 0}, {"sword": "clockwork_sword", "bow": ""})
	for attack in [{"id": &"sword_basic", "damage": 110}, {"id": &"sword_spin", "damage": 135}]:
		target.reset_target()
		weapons.sword_combat._action_sequence += 1
		weapons.sword_combat._damage_target(target, attack.id, 100, 0, PackedStringArray(["test"]), 0)
		if not _check(target.damage_receiver.health == 5000 - int(attack.damage), "실제 태엽 검 기본·스킬 피해"): return false
	weapons.set_loadout({"sword": 0, "bow": 1}, {"sword": "", "bow": "clockwork_bow"})
	for is_skill in [false, true]:
		target.reset_target()
		target.global_position = player.global_position + Vector2(250, 0)
		weapons.bow_combat._spawn_projectile("gp113:arrow:%s" % is_skill, &"bow_test", 100, 1, Vector2.RIGHT, PackedStringArray(["bow", "skill"] if is_skill else ["bow", "basic"]))
		var projectile := get_nodes_in_group("bow_projectile")[-1] as BowProjectile
		projectile._physics_process(0.2)
		var expected := 110 if is_skill else 135
		if not _check(projectile.damage == expected and target.damage_receiver.health == 5000 - expected, "실제 태엽 활 기본·스킬 투사체 피해"): return false
		projectile.free()
	weapons.set_loadout({"sword": 2, "bow": 2}, {"sword": "clockwork_sword", "bow": "clockwork_bow"})
	if not _check(player.growth_damage(100, "sword", "skill") == 155 and player.growth_damage(100, "sword", "basic") == 138 and player.growth_damage(100, "bow", "basic") == 155 and player.growth_damage(100, "bow", "skill") == 138 and player.growth_damage(100, "sword", "ultimate") == 100, "영웅 고유 35%·보조 17.5%·필살기 제외"): return false
	weapons._switch_cooldown_remaining_s = 0
	weapons.request_weapon_switch()
	if not _check(player.weapon_blueprints == weapons.blueprints and "태엽" in controls.movement_metrics.weapon_name, "실제 전환 후 특수 프로필 유지"): return false
	weapons.set_loadout(previous, previous_designs)
	weapons.active_weapon_id = previous_active
	weapons._apply_active_weapon()
	player.growth_common_bonus = bonuses[0]
	player.growth_sword_bonus = bonuses[1]
	player.growth_bow_bonus = bonuses[2]
	target.visible = false
	return true

func _check(condition: bool, label: String) -> bool:
	if condition: return true
	push_error("GP-113 실패: %s" % label)
	paused = false
	quit(1)
	return false
