extends "res://tests/gp116_runtime_test.gd"

var ultimate: UltimateController

const NEW_ULTIMATES := ["vanguard_shock", "vanguard_mend", "tracker_snipe", "tracker_shelter"]

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	var index := int(OS.get_cmdline_user_args()[1])
	var id: String = NEW_ULTIMATES[index]
	var job := "vanguard" if index < 2 else "tracker"
	store.save_path = "user://gp213_216_" + id + ".json"
	legacy.save_path = "user://gp213_216_" + id + ".jsonl"
	if phase == "seed":
		store.clear_checkpoint()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy.save_path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	var discoveries := AbilityDiscoveryStore.new()
	discoveries.save_path = "user://gp213_216_" + id + "_abilities.jsonl"
	sandbox.ability_discovery_store = discoveries
	sandbox.get_node("LocalTestRecorder").record_path = "user://gp213_216_" + id + "_records.jsonl"
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	recorder = sandbox.get_node("LocalTestRecorder")
	ultimate = sandbox.get_node("Player/UltimateController")
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	for actor in [player, weapons.sword_combat, weapons.bow_combat, ultimate]:
		actor.set_process(false)
		actor.set_physics_process(false)
	runner.set_process(false)
	for enemy in runner._all_combat_enemies():
		enemy.set_process(false)
		enemy.set_physics_process(false)
	match phase:
		"seed":
			controls.begin_retry("sword" if index < 2 else "bow", 5)
			for ignored in 3: _gain_card(0 if index < 2 else 1)
			if not _check(growth.awaiting_job_confirmation and growth.jobs.job_id == job and paused, "실제 능력 성향으로 직업 발현"): return
			ultimate.gauge = 46
			var selected := 2 + index % 2
			for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
				controls.size = dimensions
				controls._refresh_job_layout()
				if not _check(controls.job_ultimate_rects.size() == 4, "직업별4개 필살기 후보"): return
				for i in 4:
					var rect: Rect2 = controls.job_ultimate_rects[i]
					if not _check(controls.job_panel_rect.encloses(rect) and controls.layout_snapshot().safe.encloses(rect) and not rect.intersects(controls.job_confirm_rect), "두 화면비 후보 안전 영역"): return
					for j in range(i + 1, 4):
						if not _check(not rect.intersects(controls.job_ultimate_rects[j]), "네 후보 비중첩"): return
					for line in controls.job_ultimates[i].lines:
						if not _check(ThemeDB.fallback_font.get_string_size(String(line), HORIZONTAL_ALIGNMENT_LEFT, -1, mini(17, int(rect.size.y * .17))).x <= rect.size.x - 16, "필살기 설명 너비"): return
				controls.queue_redraw()
				await process_frame
			_tap(controls.job_ultimate_rects[selected].get_center())
			var meta_path: String = legacy.save_path
			legacy.save_path = "user://gp213_216_missing/meta.jsonl"
			_tap(controls.job_confirm_rect.get_center())
			legacy.save_path = meta_path
			if not _check(paused and ultimate.selected_profile.is_empty() and ultimate.gauge == 46 and controls.selected_job_ultimate == selected, "발현 기록 실패·프로필/게이지/선택 보존"): return
			_tap(controls.job_confirm_rect.get_center())
			if not _check(not paused and ultimate.selected_profile.id == id and ultimate.gauge == 46 and not ultimate.select_job_ultimate(job, id), "실제 확정·한 번 선택·충전 없음"): return
			if not _burst(id): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "첫 정예 이후 저장"): return
			player.damage_receiver.health = 37
			ultimate.gauge = 46
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "새 필살기 실제 저장"): return
			var saved := store.load_checkpoint()
			var bad := saved.duplicate(true)
			bad.ultimate.profile = NEW_ULTIMATES[2 if index < 2 else 0]
			if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "다른 직업 필살기 저장 거부"): return
			controls.show_main_screen()
			controls.show_village()
			controls.village_page = "jobs"
			var cards: Array = controls.village_snapshot().cards
			if not _check(cards.any(func(card: Dictionary) -> bool: return card.id == job and card.lines.has("필살기: " + String(ultimate.selected_profile.name))), "마을 도감 새 필살기 표시"): return
		"resume":
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and ultimate.selected_profile.id == id and ultimate.gauge == 46 and player.damage_receiver.health == 37, "별도 프로세스 반복 복원·프로필/잔량 보존"): return
			_tap(controls.stage_route_rects[0].get_center())
			while not runner.awaiting_boss_choice():
				if not _finish_stage(): return
				if runner.awaiting_boss_choice(): break
				if not _check(sandbox._claim_weapon_reward(""), "다음 정예 유지"): return
				_tap(controls.stage_route_rects[0].get_center())
			if not _check(store.load_checkpoint().ultimate.profile == id, "5스테이지 최종 보스까지 새 필살기 보존"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and sandbox._resolve_boss_choice("rescue"), "별도 프로세스 보스 선택·완주"): return
			controls.begin_retry("bow", 3)
			if not _check(ultimate.selected_profile.is_empty() and ultimate.gauge == 0, "새 도전 공용 필살기 초기화"): return
		_:
			_check(false, "알 수 없는 단계")
			return
	paused = false
	sandbox.free()
	print("GP-213–216 runtime test: OK · " + id + " · " + phase)
	quit(0)

func _burst(id: String) -> bool:
	for old in get_nodes_in_group("targetable"): old.visible = false
	player.prepare_next_stage(Vector2(1000, 780))
	player.facing_direction = 1
	player.damage_receiver.health = 40
	var front := _combat_target("ult-front", player.global_position + Vector2(140, 0))
	var rear := _combat_target("ult-rear", player.global_position + Vector2(-140, 0))
	var high := _combat_target("ult-high", player.global_position + Vector2(140, 180))
	for t in [front, rear, high]: t.add_to_group("combat_enemy")
	var def: Dictionary = ultimate.selected_profile
	ultimate.time_echo_unlocked = true
	ultimate.time_echo_boost_unlocked = true
	ultimate.gauge = 100
	ultimate.request_ultimate()
	var expected := player.growth_damage(int(def.damage), String(def.get("weapon", "bow")), "ultimate")
	var radius_hits := id == "vanguard_shock" or id == "vanguard_mend"
	if not _check(front.damage_receiver.health == 1000 - expected and rear.damage_receiver.health == 1000 - (expected if radius_hits else 0) and high.damage_receiver.health == 1000 - (expected if id == "vanguard_mend" else 0), "실제 필살기 전방/주변/높이 범위·성장 피해"): return false
	if not _check(player.damage_receiver.health == 40 + int(def.heal) and ultimate.gauge == 0 and ultimate._remaining_s == float(def.duration) + 2 and ultimate._active_profile.slow == def.slow and player.lifesteal_progress == 0, "실제 회복·게이지 소모·여운 합산·감속·흡수 제외"): return false
	ultimate.request_ultimate()
	if not _check(ultimate.activation_count == 1, "활성 중 재발동 차단"): return false
	ultimate._physics_process(10)
	if not _check(not ultimate._active, "실제 감속 정상 종료"): return false
	for t in [front, rear, high]: t.free()
	return true

func _combat_target(key: String, point: Vector2) -> PrototypeTarget:
	var template: PrototypeTarget = sandbox.get_node("Targets/CrossingTargetA")
	var target := template.duplicate() as PrototypeTarget
	target.target_key = "gp121:" + key
	target.position = point
	target.visible = true
	sandbox.add_child(target)
	target.damage_receiver.max_health = 1000
	target.reset_target()
	target.set_process(false)
	return target
