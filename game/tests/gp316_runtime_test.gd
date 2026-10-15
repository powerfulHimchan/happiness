extends "res://tests/gp315_runtime_test.gd"

class FaultStore extends FailingLegacyStore:
	var fail_sera := false
	func grant_sera(source: String, choice: String) -> Error:
		return ERR_CANT_CREATE if fail_sera else super.grant_sera(source, choice)


func _run() -> void:
	auto_guardian_choice = false
	legacy_final_boss_for_tests = false
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var character := args[1]
	var weapon := args[2]
	var choice := args[3]
	legacy = FaultStore.new()
	var continuing := phase in ["resume", "finish"]
	var prefix := "user://gp316_%s_%s_%s_%s" % ["flow" if phase == "seed" or continuing else phase, character, weapon, choice]
	store.save_path = prefix + "_checkpoint.json"
	legacy.save_path = prefix + "_meta.jsonl"
	journal.save_path = prefix + "_story.jsonl"
	if not continuing:
		store.clear_checkpoint()
		for suffix in ["_meta.jsonl", "_records.jsonl", "_abilities.jsonl", "_story.jsonl"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix + suffix))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.story_journal_store = journal
	var book := AbilityDiscoveryStore.new()
	book.save_path = prefix + "_abilities.jsonl"
	sandbox.ability_discovery_store = book
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.get_node("LocalTestRecorder").record_path = prefix + "_records.jsonl"
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	recorder = sandbox.get_node("LocalTestRecorder")
	festival_ultimate = sandbox.get_node("Player/UltimateController")
	festival_terrain = sandbox.get_node("RouteTerrain")
	for actor in [player, weapons, weapons.sword_combat, weapons.bow_combat, festival_ultimate, runner, sandbox.get_node("ClockTrapController"), festival_terrain]:
		actor.set_process(false)
		actor.set_physics_process(false)
	growth.jobs_enabled = false
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	match phase:
		"seed":
			if not _complete_sera(character, weapon, choice): return
			if not _sera_unlock(choice) or not await _sera_views(choice): return
			var raw := FileAccess.get_file_as_string(legacy.save_path)
			var id := String(recorder.checkpoint_snapshot().id)
			if not _check(legacy.grant_sera(id, choice) == OK and legacy.grant_sera(id, "destroy" if choice == "rescue" else "rescue") == ERR_INVALID_DATA and raw == FileAccess.get_file_as_string(legacy.save_path), "세라 영구 선택 멱등·반대 선택 거부"): return
			controls.begin_retry(weapon, 3, "standard", character, false)
			if not _sera_support(choice) or not _finish_stage() or not await _sera_equip(weapon, choice, 1): return
		"resume":
			if not _sera_restore(1, choice, weapon) or not _next_without_layout() or not _sera_support(choice) or not _finish_stage() or not await _sera_equip(weapon, choice, 2): return
		"finish":
			if not _sera_restore(2, choice, weapon) or not _next_without_layout() or not _sera_support(choice) or not _finish_stage() or not sandbox._resolve_boss_choice("destroy"): return
			if not _check(sandbox.sera_companion.is_empty() and legacy.progress_snapshot().sera_choices.get(choice, false) and legacy.pending_reward().choice == "destroy", "현재 동행 정리·영구 선택 보존·태엽 기사 일회 보상 독립"): return
			var progress := legacy.progress_snapshot()
			recorder.clear_records()
			if not _check(legacy.progress_snapshot() == progress, "도전 기록 초기화에도 영구 선택 유지"): return
		"fault":
			if not _prepare_sera(character, weapon, "rescue") or not _enter_sera() or not _intro_input(true) or not _finish_stage() or not _ack_scene(true): return
			var saved := store.load_checkpoint()
			var path := store.save_path
			store.save_path = "user://gp316_missing/checkpoint.json"
			if not _check(not sandbox._resolve_boss_choice(choice) and not legacy.progress_snapshot().sera_choices.has(choice), "선택 저장 실패는 영구 보상 없음"): return
			store.save_path = path
			if not _check(store.load_checkpoint() == saved, "선택 실패는 정상 파일 보존"): return
			legacy.fail_sera = true
			if not _choose_sera(choice): return
			if not _check(not sandbox._sera_reward_saved and not store.load_checkpoint().is_empty() and store.load_checkpoint().stage.boss_choice == choice and controls.checkpoint_message.contains("세라"), "세라만 저널 쓰기 실패·선택 체크포인트 보존·오류 표시"): return
			controls.begin_retry(weapon, 3, "standard", character, false)
			if not _check(runner.stage_number == 10 and controls.current_screen_mode() == 2 and not sandbox.continue_saved_run(), "보상 미기록 시 새 도전/이어하기 진행 차단"): return
			legacy.fail_sera = false
			sandbox._refresh_checkpoint()
			if not _check(sandbox._sera_reward_saved and store.load_checkpoint().is_empty() and recorder.summary_snapshot().completed_run_count == 1, "재시도 한 번으로 영구 보상 확정·완주 중복 없음"): return
			if not _sera_unlock(choice): return
		"validate":
			if legacy.grant_sera("old", "rescue") != OK: return
			controls.begin_retry(weapon, 3, "standard", character, false)
			if not _sera_support("rescue") or not _finish_stage(): return
			var saved := store.load_checkpoint()
			for bad in [null, [], true, {"run_id": "other", "assisted_stages": []}, {"run_id": saved.recorder.id, "assisted_stages": [1, 1]}, {"run_id": saved.recorder.id, "assisted_stages": [2]}, {"run_id": saved.recorder.id, "assisted_stages": [1.5]}, {"run_id": saved.recorder.id, "assisted_stages": [true]}, {"run_id": saved.recorder.id, "assisted_stages": [0]}, {"run_id": saved.recorder.id, "assisted_stages": [11]}]:
				var corrupt := saved.duplicate(true)
				corrupt.sera_companion = bad
				if not _check(store.save_checkpoint(corrupt) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "세라 동행 타입/ID/중복/미래/범위 위변조 차단"): return
			var old := saved.duplicate(true)
			old.erase("sera_companion")
			if store.save_checkpoint(old) != OK: return
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and sandbox.sera_companion.is_empty(), "필드 없는 진행 중 이전 저장에 세라 소급 동행 없음"): return
		"journal":
			if not _check(legacy.grant_sera("rescue", "rescue") == OK and legacy.grant_sera("destroy", "destroy") == OK and legacy.grant_guardian("gate", "rescue") == OK and legacy.grant("knight", "destroy") == OK, "세라 두 선택·기사 보상 공존"): return
			var state := legacy.sera_for_run("run")
			var path := legacy.save_path
			legacy.save_path = "user://gp316_missing/meta.jsonl"
			if not _check(not legacy.spend_sera_assist(state, 1, 10) and state.assisted_stages.is_empty(), "소비 기록 실패는 세라 타격/소비 없음"): return
			legacy.save_path = path
			if not _check(legacy.spend_sera_assist(state, 10, 10) and not legacy.spend_sera_assist(state, 10, 10) and not legacy.spend_sera_assist(state, 6, 5) and not legacy.spend_sera_assist(state, 0, 10), "10단계 세라 지원·중복/범위 차단"): return
			var backup := {"run_id": "run", "assisted_stages": []}
			if not _check(legacy.restore_sera(backup).assisted_stages == [10] and not legacy.spend_sera_assist(backup, 10, 10) and legacy.restore_guardian(backup).assisted_stages.is_empty(), "이전 저장 소비 병합·기사 소비 독립"): return
			var file := FileAccess.open(path, FileAccess.READ_WRITE)
			file.seek_end()
			file.store_string("broken-tail")
			file.close()
			if not _check(legacy.grant_sera("again", "rescue") == OK and legacy.progress_snapshot().sera_choices.size() == 2 and legacy.progress_snapshot().blueprints.size() == 4 and legacy.pending_reward().source == "knight", "손상 꼬리 뒤 기록 복구·태엽 보상 보존"): return
		"modes":
			if legacy.grant_sera("sera", "rescue") != OK or legacy.grant_guardian("gate", "rescue") != OK or legacy.grant("knight", "rescue") != OK: return
			sandbox._update_boss_legacy_status()
			for mode in 4:
				controls.show_main_screen()
				controls.show_start_weapon_selection()
				controls.selected_story_enabled = false
				_tap(controls.start_length_rects[mode].get_center())
				_tap(controls.start_weapon_confirm_rect.get_center())
				if not _sera_support("rescue", 20 if mode == 0 else 0): return
				var snapshot: Dictionary = sandbox._capture_run_build()
				if not _check(PrototypeRunBuildView.cards(2, snapshot).any(func(card: Dictionary) -> bool: return card.id == "sera_companion"), "네 모드 실제 지원·현재 도전 정보"): return
				if not _finish_stage(): return
		"previous-choice":
			if not _prepare_sera(character, weapon, "rescue") or not _enter_sera() or not _intro_input(true) or not _finish_stage() or not _ack_scene(true): return
			var old := store.load_checkpoint()
			old.erase("sera_companion")
			old.stage.boss_choice = choice
			old.stage.history[-1].boss_choice = choice
			if not _check(store.save_checkpoint(old) == OK, "이전 세라 선택 확정 체크포인트 구성"): return
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run(), "이전 확정 선택 복원"): return
			if not _check(legacy.progress_snapshot().sera_choices.get(choice, false) and legacy.pending_reward().is_empty() and store.load_checkpoint().is_empty(), "이전 확정 선택도 복원 시 영구 해금·보상 독립"): return
		_:
			_check(false, "알 수 없는 세라 영구 보상 검사")
			return
	paused = false
	sandbox.free()
	print("GP-316 runtime test: OK (%s %s %s %s)" % [phase, character, weapon, choice])
	quit(0)

func _complete_sera(character: String, weapon: String, choice: String) -> bool:
	if not _prepare_sera(character, weapon, "rescue") or not _enter_sera() or not _intro_input(true) or not _finish_stage() or not _ack_scene(true): return false
	if not _check(sandbox.sera_companion.is_empty(), "세라 해금 전 현재 도전에는 동행 없음"): return false
	return _choose_sera(choice) and _check(store.load_checkpoint().is_empty() and legacy.pending_reward().is_empty(), "세라 완주·영구 보상 저장 후 체크포인트 정리")

func _sera_unlock(choice: String) -> bool:
	var progress := legacy.progress_snapshot()
	return _check(progress.sera_choices.get(choice, false) and progress.sera_companion == (choice == "rescue") and progress.blueprints.get("sera_sword", false) == (choice == "destroy") and progress.blueprints.get("sera_bow", false) == (choice == "destroy") and controls.sera_companion_unlocked == (choice == "rescue"), "세라 실제 영구 기록·조력/설계도 해금·UI 표시")

func _sera_support(choice: String, knight_bonus: int = 0) -> bool:
	if not _reach_journey_elite(): return false
	var enemy := runner.final_enemy()
	var expected := (40 if choice == "rescue" else 0) + (30 if not sandbox.guardian_companion.is_empty() else 0) + knight_bonus
	if not _check(enemy.damage_receiver.health == enemy.damage_receiver.max_health - expected and sandbox.sera_companion.is_empty() == (choice == "destroy"), "실제 세라 정예 피해·기사 지원 독립 합산 (실제 %d / 기대 %d / 모드 %s / legacy %s)" % [enemy.damage_receiver.max_health - enemy.damage_receiver.health, expected, runner.run_mode, str(player.boss_legacy)]): return false
	var health := enemy.damage_receiver.health
	runner.force_emit_metrics()
	runner.force_emit_metrics()
	return _check(enemy.damage_receiver.health == health, "지표 반복으로 세라 재타격 없음")

func _sera_restore(stage: int, choice: String, weapon: String) -> bool:
	var saved := store.load_checkpoint()
	for ignored in 2:
		controls.show_main_screen()
		if not _check(sandbox.continue_saved_run() and runner.stage_number == stage and store.load_checkpoint() == saved and (sandbox.sera_companion.is_empty() if choice == "destroy" else sandbox.sera_companion.assisted_stages.size() == stage) and (weapons.blueprints[weapon] == "sera_" + weapon if choice == "destroy" else weapons.blueprints[weapon].is_empty()), "별도 프로세스 반복 복원·세라 소비/장착 보존"): return false
	return true

func _sera_equip(weapon: String, choice: String, grade: int) -> bool:
	var offers := PrototypeWeaponRewards.offers(runner.stage_number, weapons.equipment, weapons.unlocked_blueprints, weapons.blueprints)
	var id := "sera_" + weapon
	if choice == "rescue":
		return _check(not offers.any(func(item: Dictionary) -> bool: return item.id in PrototypeWeaponRewards.SERA_DESIGNS) and not weapons.equip_reward(id, grade) and sandbox._claim_weapon_reward(""), "미해금 세라 무기 보상·장착 차단")
	controls.show_weapon_rewards(runner.stage_number, offers)
	for page in controls.weapon_reward_pages():
		for i in controls.weapon_reward_cards.size():
			if controls.weapon_reward_cards[i].id != id: continue
			_tap(controls.weapon_reward_rects[i].get_center())
			_tap(controls.weapon_reward_confirm_rect.get_center())
			var kind := "basic" if weapon == "sword" else "skill"
			if not _check(weapons.blueprints[weapon] == id and weapons.equipment[weapon] == grade, "실제 보상 페이지·카드로 세라 무기 장착"): return false
			if not _check(player.growth_damage(100, weapon, kind) == roundi(100 * PrototypeWeaponRewards.damage_multiplier(weapons.equipment, weapon, kind, weapons.blueprints) * (1.0 + player.growth_common_bonus + (player.growth_sword_bonus if weapon == "sword" else player.growth_bow_bonus))), "세라 무기 실제 피해 합산"): return false
			return _sera_damage(weapon, grade)
		_tap(controls.weapon_reward_next_rect.get_center())
	return _check(false, "해금 세라 무기 보상에 존재")

func _sera_views(choice: String) -> bool:
	var before := legacy.progress_snapshot()
	var raw := FileAccess.get_file_as_string(legacy.save_path)
	controls.show_main_screen()
	controls.show_village()
	var facility: Dictionary = controls.village_snapshot().cards[1]
	if not _check(facility.open and facility.status.contains("세라의 인연") and facility.lines[0].contains("세라 인연 1/2"), "마을 시설에서도 세라 인연 해금과 메뉴 안내"): return false
	for dimensions in [Vector2(1280, 720), Vector2(1600, 720)]:
		controls.size = dimensions
		controls.village_page = "memories"
		_tap(controls.village_snapshot().tabs.bonds.get_center())
		var snapshot: Dictionary = controls.village_snapshot()
		if not _check(snapshot.page == "bonds" and snapshot.cards.size() == 2 and snapshot.cards[0].open == (choice == "rescue") and snapshot.cards[1].open == (choice == "destroy"), "실제 인연 탭 입력·독립 영구 선택 표시"): return false
		for rect in snapshot.layout.cards + snapshot.tabs.values():
			if not _check(controls.layout_snapshot().safe.encloses(rect), "인연 카드·탭 두 화면비 안전 영역"): return false
		controls.village_page = "forge"
		controls.weapon_codex_page = 0
		for ignored in 2: _tap(controls.village_snapshot().pager.next.get_center())
		snapshot = controls.village_snapshot()
		if not _check(snapshot.codex_pages == 3 and snapshot.codex_page == 2 and snapshot.cards.map(func(card: Dictionary) -> String: return card.id) == PrototypeWeaponRewards.SERA_DESIGNS and snapshot.cards.all(func(card: Dictionary) -> bool: return card.open == (choice == "destroy")), "셋째 설계도 페이지 잠금/해금·기존 순서 보존"): return false
		_tap(snapshot.pager.next.get_center())
		if not _check(controls.village_snapshot().codex_page == 2, "설계도 페이지 상한"): return false
		if choice == "destroy":
			if not _check(snapshot.cards[0].lines[4] == "검: 기본 공격 강화" and snapshot.cards[1].lines[4] == "활: 스킬 강화", "세라 무기 고유 효과 안내 일치"): return false
		for rect in snapshot.layout.cards + snapshot.pager.values():
			if not _check(controls.layout_snapshot().safe.encloses(rect), "세라 설계도 두 화면비 안전 영역"): return false
		for ignored in 2: await process_frame
	controls.size = Vector2(1280, 720)
	controls.show_main_screen()
	return _check(before == legacy.progress_snapshot() and raw == FileAccess.get_file_as_string(legacy.save_path), "인연·설계도 조회는 영구 기록 불변")

func _next_without_layout() -> bool:
	var number := runner.stage_number
	var route: String = controls.stage_route_options[-1].id
	_tap(controls.stage_route_rects[-1].get_center())
	return _check(not paused and runner.stage_number == number + 1 and runner.route_id == route, "실제 현재 페이지의 다음 경로 입력")


func _sera_damage(weapon: String, grade: int) -> bool:
	var bonuses := [player.growth_common_bonus, player.growth_sword_bonus, player.growth_bow_bonus]
	player.growth_common_bonus = 0
	player.growth_sword_bonus = 0
	player.growth_bow_bonus = 0
	var target := sandbox.get_node("Targets/CrossingTargetA") as PrototypeTarget
	target.set_process(false)
	target.visible = true
	target.damage_receiver.max_health = 5000
	for kind in ["basic", "skill"]:
		var unique: bool = kind == ("basic" if weapon == "sword" else "skill")
		var expected: int = (120 if grade == 1 else 130) + ((15 if grade == 1 else 25) if unique else 0)
		target.reset_target()
		if weapon == "sword":
			weapons.sword_combat._action_sequence += 1
			weapons.sword_combat._damage_target(target, &"sword_basic" if kind == "basic" else &"sword_spin", 100, 0, PackedStringArray(["test"]), 0)
		else:
			target.global_position = player.global_position + Vector2(250, 0)
			weapons.bow_combat._spawn_projectile("gp316:%d:%s" % [grade, kind], &"bow_test", 100, 1, Vector2.RIGHT, PackedStringArray(["bow", kind]))
			var arrow := get_nodes_in_group("bow_projectile")[-1] as BowProjectile
			arrow._physics_process(0.2)
			arrow.free()
		if not _check(target.damage_receiver.health == 5000 - expected, "세라 희귀/영웅 검 실제 타격·활 투사체 기본/스킬 고유 피해"): return false
		var other := "bow" if weapon == "sword" else "sword"
		if not _check(player.growth_damage(100, other, kind) == roundi(100.0 + ((7.5 if grade == 1 else 12.5) if unique else 0.0)), "세라 보조 고유 효과 절반·해당 공격 종류만 적용"): return false
	if not _check(player.growth_damage(100, weapon, "ultimate") == 100, "세라 장비 필살기 제외"): return false
	player.growth_common_bonus = bonuses[0]
	player.growth_sword_bonus = bonuses[1]
	player.growth_bow_bonus = bonuses[2]
	return true
