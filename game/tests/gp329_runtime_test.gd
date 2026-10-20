extends "res://tests/gp327_runtime_test.gd"

var advanced_id: String
var starting_weapon: String
var parent_id: String
var advanced_cards: Array[String]

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	var character := args[1]
	advanced_id = args[2]
	starting_weapon = String(PrototypeJobProgress.profile(advanced_id).weapon)
	automatic_growth_card_id = starting_weapon + "_power"
	parent_id = PrototypeJobProgress.base_job(advanced_id)
	advanced_cards.assign({"dragon_knight": ["dragon_flame", "dragon_heart"], "breaker": ["breaker_edge", "breaker_vigor"], "storm_archer": ["storm_arrow", "storm_breath"], "forest_warden": ["warden_arrow", "warden_roots"]}[advanced_id])
	var prefix := "user://gp329_%s_%s_%s" % [advanced_id, character, "flow" if phase in ["seed", "resume"] else phase]
	store.save_path = prefix + "_checkpoint.json"
	legacy.save_path = prefix + "_meta.jsonl"
	journal.save_path = prefix + "_story.jsonl"
	if phase != "resume":
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
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	var advanced := PrototypeJobProgress.profile(advanced_id)
	match phase:
		"seed", "late", "legacy":
			if not _check(controls.begin_retry(starting_weapon, 3 if phase == "legacy" else 10, "standard" if phase == "legacy" else "journey", character, false), "진화 도전 시작"): return
			for ignored in 5:
				if not _earn_card(starting_weapon + "_power"): return
			if advanced_id == PrototypeJobProgress.BREAKER_ID:
				if not _earn_card("vanguard_edge") or not _earn_card("vanguard_dawn_edge"): return
			elif advanced_id == PrototypeJobProgress.WARDEN_ID:
				if not _earn_card("tracker_focus") or not _earn_card("tracker_forest_aim"): return
			if phase != "late" and not _real_weapon_hits(): return
			if not _check(growth.jobs.job_id == parent_id and not growth.try_evolve_job(), "초반 진화 차단"): return
			for id in advanced_cards:
				if not _check(not growth._card_available(PrototypeAbilityCodex.profile(id)), "미진화 전용 카드 차단"): return
			if phase == "legacy":
				if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
				var old := store.load_checkpoint()
				controls.show_main_screen()
				if not _check(not old.is_empty() and sandbox.continue_saved_run() and growth.jobs.job_id == parent_id and store.load_checkpoint() == old, "기존 기본 직업 저장 호환·비소급"): return
			else:
				for number in range(1, 7):
					if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
					if number < 6 and not _next_without_layout(): return
				var before_max := player.damage_receiver.max_health
				var before_bonus := _weapon_bonus()
				festival_ultimate.gauge = 76
				legacy.fail_writes = true
				_tap(controls.stage_route_rects[-1].get_center())
				var active: Dictionary = {}
				var remaining := 0.0
				if phase == "late":
					if not _check(growth.jobs.job_id == parent_id and not growth.try_evolve_job(), "후반 미충족 성향 차단"): return
					festival_ultimate.gauge = 100
					festival_ultimate.request_ultimate()
					active = festival_ultimate._active_profile.duplicate(true)
					remaining = festival_ultimate._remaining_s
					player.expedition = 2
					player.damage_receiver.health = 20
					if not _real_weapon_hits(): return
					if not _check(player.damage_receiver.health == 20 + ceili(float(advanced.health_bonus) * 0.75), "진화 패시브 실제 회복75%·파쇄자 회복 미지급"): return
				if not _check(runner.stage_number == 7 and paused and growth.awaiting_job_confirmation and growth.jobs.job_id == advanced_id and player.job_emblem_id == advanced_id and player.damage_receiver.max_health == before_max + int(advanced.health_bonus) and is_equal_approx(_weapon_bonus(), before_bonus + float(advanced.damage_bonus)), "7단계 실제 진화·패시브·표식·일시정지"): return
				if not await _layout_check(): return
				var gauge := festival_ultimate.gauge
				var saved_before := store.load_checkpoint()
				var choice := _ultimate_choice(character)
				legacy.fail_writes = true
				_tap(controls.job_ultimate_rects[choice].get_center())
				_tap(controls.job_confirm_rect.get_center())
				if not _check(paused and growth.awaiting_job_confirmation and store.load_checkpoint() == saved_before and not growth.acknowledge_job(), "영구 기록 실패 확인 보류·기존 필살기로 확정 차단"): return
				legacy.fail_writes = false
				_tap(controls.job_confirm_rect.get_center())
				if not _check(not paused and festival_ultimate.gauge == gauge and festival_ultimate.selected_profile.job == advanced_id and not growth.try_evolve_job() and not growth.choose_job_ultimate((choice + 1) % 4), "재시도·게이지 유지·재진화/재선택 차단"): return
				if phase == "late":
					if not _check(festival_ultimate._active_profile == active and festival_ultimate._remaining_s == remaining, "사용 중 기본 필살기 스냅샷 보존"): return
					festival_ultimate._physics_process(remaining + 0.1)
					player.expedition = 2
					player.damage_receiver.health = 20
					var max_before := player.damage_receiver.max_health
					if not _earn_card(advanced_cards[1]): return
					var health_gain := 30 if advanced_id in [PrototypeJobProgress.DRAGON_ID, PrototypeJobProgress.WARDEN_ID] else 20
					var healing := 23 if advanced_id == PrototypeJobProgress.DRAGON_ID else 34 if advanced_id == PrototypeJobProgress.WARDEN_ID else 30
					if not _check(player.damage_receiver.health == 20 + healing and player.damage_receiver.max_health == max_before + health_gain, "회복75%와 최대체력 증가 분리"): return
				else:
					for id in advanced_cards + ["vanguard_vigor" if starting_weapon == "sword" else "tracker_focus"]:
						if not _earn_card(id): return
					for id in advanced_cards:
						if not _check(not growth._card_available(PrototypeAbilityCodex.profile(id)), "전용 능력 도전당 1회"): return
					var foreign := "storm_arrow" if starting_weapon == "sword" else "breaker_edge"
					if not _check(not growth._card_available(PrototypeAbilityCodex.profile(foreign)) and not growth._card_available(PrototypeAbilityCodex.profile("dragon_flame" if advanced_id != PrototypeJobProgress.DRAGON_ID else "breaker_edge")), "다른 진화 가지 카드 차단"): return
					if not _test_additional_cards(): return
					if advanced_id == PrototypeJobProgress.STORM_ID:
						if not _earn_card("tracker_forest_aim"): return
						if not _check(growth.jobs.job_id == PrototypeJobProgress.STORM_ID and not growth.try_evolve_job(), "폭풍사수 진화 후 숲의 명중 선택은 기존 진화 유지"): return
					if not _advanced_ultimate_test(): return
					if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
					var saved := store.load_checkpoint()
					if not _check(not saved.is_empty() and saved.stage.number == 7 and saved.growth.job == advanced_id and RunCheckpointStore.valid_state(saved), "상위 직업·능력·필살기 저장"): return
					for mutation in ["score", "health", "bonus", "ultimate", "rank", "branch", "stage"]:
						var bad := saved.duplicate(true)
						match mutation:
							"score": bad.growth.contributions.weapon.clear()
							"health": bad.player.max_health += 10
							"bonus": bad.player[starting_weapon] += 0.20
							"ultimate": bad.ultimate.profile = "vanguard_strike" if starting_weapon == "sword" else "tracker_volley"
							"rank": bad.growth.ranks[advanced_cards[0]] = 2
							"branch":
								if starting_weapon == "sword":
									bad.growth.ranks.erase("vanguard_dawn_edge")
									bad.growth.ranks.sword_power += 1
									bad.player.sword -= 0.15
								else: bad.growth.job = PrototypeJobProgress.BREAKER_ID
							"stage": bad.stage.run_mode = "standard"
						if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "변조 저장 거부·이전 저장 유지: " + mutation): return
					if not _validate_additional_save(saved): return
					var path := store.save_path
					store.save_path = "user://gp329_missing/checkpoint.json"
					if not _check(sandbox._save_checkpoint(runner.current_metrics(), false) != OK, "저장 쓰기 실패 검출"): return
					store.save_path = path
					if not _check(store.load_checkpoint() == saved, "저장 오류 후 정상 저장 유지"): return
		"resume":
			var saved := store.load_checkpoint()
			if not _restore_journey(7): return
			if not _check(growth.jobs.job_id == advanced_id and player.job_emblem_id == advanced_id and is_equal_approx(_weapon_bonus(), float(saved.player[starting_weapon])) and festival_ultimate.selected_profile.id == saved.ultimate.profile and not growth.awaiting_job_confirmation, "별도 프로세스 복원·패시브 중복 없음"): return
			if not _test_restored_additions(saved): return
			controls.show_main_screen()
			controls.show_village()
			controls.village_page = "jobs"
			_tap(controls.village_snapshot().tabs.advanced_jobs.get_center())
			var cards: Array = controls.village_snapshot().cards
			if advanced_id in [PrototypeJobProgress.STORM_ID, PrototypeJobProgress.WARDEN_ID]:
				_tap(controls.village_snapshot().pager.next.get_center())
				cards = controls.village_snapshot().cards
			var current: Array = cards.filter(func(card: Dictionary) -> bool: return card.id == advanced_id)
			if not _check(cards.size() == 2 and controls.village_snapshot().advanced_pages == ceili(float(PrototypeJobProgress.ADVANCED_JOBS.size()) / PrototypeVillageView.ADVANCED_PAGE_SIZE) and current.size() == 1 and current[0].status == "진화 · 현재 도전" and current[0].open, "네 상위 직업 두 페이지·영구 발견·현재 진화"): return
			var meta := FileAccess.get_file_as_string(legacy.save_path)
			if not await _layout_check(): return
			if not _check(FileAccess.get_file_as_string(legacy.save_path) == meta and store.load_checkpoint() == saved, "도감 조회는 저장 불변"): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			if not _next_without_layout() or not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			if not _check(runner.stage_number == 8 and store.load_checkpoint().growth.job == advanced_id, "다음 단계 진화 유지"): return
			recorder.clear_records()
			controls.show_main_screen()
			controls.begin_retry(starting_weapon, 3)
			if not _check(growth.jobs.job_id.is_empty() and player.job_emblem_id.is_empty() and _weapon_bonus() == 0.0 and player.damage_receiver.max_health == 100 and legacy.progress_snapshot().jobs.has(advanced_id), "새 도전 초기화·발견 기록 유지"): return
	paused = false
	sandbox.free()
	print("GP-328/329 runtime test: OK (%s %s %s)" % [phase, character, advanced_id])
	quit(0)

func _weapon_bonus() -> float:
	return player.growth_sword_bonus if starting_weapon == "sword" else player.growth_bow_bonus

func _ultimate_choice(character: String) -> int:
	return 0 if character == "roan" else 1

func _test_additional_cards() -> bool:
	return true

func _validate_additional_save(_saved: Dictionary) -> bool:
	return true

func _test_restored_additions(_saved: Dictionary) -> bool:
	return true

func _real_weapon_hits() -> bool:
	if starting_weapon == "sword": return _real_sword_hits()
	var target := sandbox.get_node("Targets/LeafSlime") as PrototypeTarget
	target.visible = true
	target.set_process(false)
	target.set_physics_process(false)
	var original := target.damage_receiver.max_health
	target.damage_receiver.max_health = 10000
	target.damage_receiver.reset()
	for hit in 80:
		weapons.bow_combat._spawn_projectile("gp329:%d" % hit, &"bow_basic", 1, 1, Vector2.RIGHT, PackedStringArray(["bow"]))
		var arrow := get_nodes_in_group("bow_projectile")[-1] as BowProjectile
		var point := target.global_position + Vector2(0, -38)
		var before := target.damage_receiver.health
		arrow._check_hits(point, point)
		if not _check(target.damage_receiver.health < before, "실제 활 투사체 적중 성향 누적"): return false
		arrow.free()
	target.damage_receiver.max_health = original
	target.reset_target()
	return true

func _advanced_ultimate_test() -> bool:
	var target := sandbox.get_node("Targets/LeafSlime") as PrototypeTarget
	var original := target.damage_receiver.max_health
	target.visible = true
	target.set_process(false)
	target.set_physics_process(false)
	target.damage_receiver.max_health = 2000
	var profile: Dictionary = festival_ultimate.selected_profile
	var expected: Array = {
		"dragon_burst": [120, 0, 3.0, 0.15], "dragon_guard": [40, 50, 5.0, 0.25],
		"breaker_crush": [160, 0, 2.0, 0.20], "breaker_roar": [80, 30, 4.0, 0.30],
		"storm_volley": [120, 0, 3.0, 0.15], "storm_eye": [50, 45, 5.0, 0.20],
		"warden_rain": [90, 0, 4.0, 0.20], "warden_sanctuary": [30, 60, 5.0, 0.30],
		"dragon_lance": [150, 0, 2.0, 0.20, 600.0, 100.0], "dragon_rekindle": [0, 70, 4.0, 0.35, 0.0, -1.0],
		"breaker_rift": [180, 0, 2.0, 0.25, 500.0, 120.0], "breaker_surge": [100, 20, 3.0, 0.20, 250.0, -1.0],
		"storm_snipe": [180, 0, 2.0, 0.20, 1000.0, 80.0], "storm_restoration": [0, 65, 5.0, 0.25, 0.0, -1.0],
		"warden_thorn_wave": [130, 0, 3.0, 0.20, 700.0, 140.0], "warden_renewal": [0, 85, 4.0, 0.35, 0.0, -1.0],
	}[String(profile.id)]
	var offsets: Array[Vector2] = [Vector2(100, 0), Vector2(-100, 0), Vector2(0, 350), Vector2(1100, 0), Vector2(100, -81), Vector2(100, -101), Vector2(100, -121), Vector2(100, -141), Vector2(100, -221), Vector2(200, 0), Vector2(201, 0), Vector2(250, 0), Vector2(251, 0), Vector2(300, 0), Vector2(301, 0)]
	for offset in offsets:
		target.damage_receiver.reset()
		target.global_position = player.global_position + offset
		player.facing_direction = 1
		player.damage_receiver.health = 20
		festival_ultimate.gauge = 100
		festival_ultimate.request_ultimate()
		var hit := offset.length() <= float(profile.get("range", 0.0))
		if bool(profile.get("forward", false)): hit = offset.x >= 0.0 and offset.x <= float(profile.range) and absf(offset.y) <= float(profile.get("half_height", 220.0))
		if expected.size() > 4:
			hit = offset.length() <= float(expected[4]) if float(expected[5]) < 0.0 else offset.x >= 0.0 and offset.x <= float(expected[4]) and absf(offset.y) <= float(expected[5])
		if not _check(festival_ultimate._active and festival_ultimate.gauge == 0 and target.damage_receiver.health == 2000 - (player.growth_damage(int(expected[0]), starting_weapon, "ultimate") if hit else 0) and player.damage_receiver.health == 20 + int(expected[1]) and is_equal_approx(festival_ultimate._remaining_s, float(expected[2])) and is_equal_approx(target.enemy_time_scale(), float(expected[3])), "상위 필살기 실제 범위·피해·회복·시간·감속"): return false
		festival_ultimate.finish_stage_effect()
		if not _check(is_equal_approx(target.enemy_time_scale(), 1.0), "상위 필살기 종료 감속 해제"): return false
	target.damage_receiver.max_health = original
	target.reset_target()
	return true
