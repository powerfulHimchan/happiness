extends "res://tests/gp148_runtime_test.gd"

const BATCH_SAVE := "user://gp167_170_checkpoint.json"
const BATCH_META := "user://gp167_170_meta.jsonl"
const BATCH_RECORD := "user://gp167_170_records.jsonl"
const BATCH_BOOK := "user://gp167_170_abilities.jsonl"
const UPGRADES := {"potion_pouch_boost": "potion_pouch", "orb_magnet_boost": "orb_magnet", "time_echo_boost": "time_echo", "potion_mastery": "potion_pouch"}
var _earned_kills: int = 0

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	store.save_path = BATCH_SAVE
	legacy.save_path = BATCH_META
	book.save_path = BATCH_BOOK
	if phase in ["seed", "legacy-seed", "combat"]:
		store.clear_checkpoint()
		for path in [BATCH_META, BATCH_RECORD, BATCH_BOOK]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.ability_discovery_store = book
	sandbox.get_node("LocalTestRecorder").record_path = BATCH_RECORD
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
	_disable_live()
	for enemy in runner._all_combat_enemies():
		enemy.set_process(false)
		enemy.set_physics_process(false)
	growth.jobs_enabled = false
	match phase:
		"seed", "combat":
			controls.begin_retry("sword", 5)
			if not _gates(false): return
			for id in ["potion_pouch", "orb_magnet", "time_collector", "time_echo"]:
				if not await _earn(id): return
			player.potions_remaining = 0
			for id in UPGRADES:
				if not await _earn(id, true): return
			if not _gates(true) or not _test_effects() or not await _views(): return
			if phase == "combat":
				if not _combat_effects(): return
			else:
				if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "실제 첫 정예 저장"): return
				player.damage_receiver.health = 17
				player.potions_remaining = 1
				ultimate.gauge = 31
				weapons.sword_combat._skill_1_cooldown_s = 3.25
				if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "네 강화 실제 잔량 저장"): return
				if not _save_guards(): return
		"resume":
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and player.damage_receiver.health == 17 and player.potions_remaining == 1 and ultimate.gauge == 31 and weapons.sword_combat._skill_1_cooldown_s == 3.25, "반복 이어하기 무료 보충/회복/충전 없음"): return
				if not _test_effects(): return
			_tap(controls.stage_route_rects[0].get_center())
			while not runner.awaiting_boss_choice():
				if not _finish_stage(): return
				if runner.awaiting_boss_choice(): break
				if not _check(sandbox._claim_weapon_reward(""), "강화 유지 다음 정예"): return
				_tap(controls.stage_route_rects[0].get_center())
			if not _check(UPGRADES.keys().all(func(id: String) -> bool: return store.load_checkpoint().growth.ranks.has(id)), "5스테이지 최종 보스 저장 강화 보존"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and sandbox._resolve_boss_choice("rescue"), "5단계 보스 선택 복원 완주"): return
			controls.begin_retry("bow", 3)
			if not _defaults() or not _check(UPGRADES.keys().all(func(id: String) -> bool: return book.snapshot().has(id)), "영구 발견만 보존"): return
		"legacy-seed":
			controls.begin_retry("bow", 3)
			for id in ["potion_pouch", "orb_magnet", "time_collector", "time_echo"]:
				if not await _earn(id): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "새 강화 없는 기존 저장"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and not player.potion_pouch_boost_unlocked and not player.potion_mastery_unlocked and not player.orb_magnet_boost_unlocked and not ultimate.time_echo_boost_unlocked and player.potions_capacity() == 3 and player.recovery_orb_pickup_radius() == 152 and is_equal_approx(player.potion_heal_ratio(), 0.25) and ultimate.duration_for({}) == 4, "기존 저장은 강화 자동 지급 없이 복원"): return
		_:
			_check(false, "검사 단계 오류")
			return
	paused = false
	sandbox.free()
	print("GP-167–170 runtime test: OK (" + phase + ")")
	quit(0)

func _effects() -> Array:
	return [player.potions_capacity(), player.recovery_orb_pickup_radius(), player.potion_heal_ratio(), ultimate.duration_for({})]

func _test_effects() -> bool:
	return _check(player.potions_capacity() == 4 and player.recovery_orb_pickup_radius() == 228 and is_equal_approx(player.potion_heal_ratio(), 0.30) and ultimate.duration_for({}) == 5.0, "네 강화 합산 효과 4개/2.28m/30%/5초")

func _defaults() -> bool:
	return _check(growth.ranks.is_empty() and player.potions_capacity() == 2 and player.recovery_orb_pickup_radius() == 76 and player.potion_heal_ratio() == 0.25 and ultimate.duration_for({}) == 3, "새 도전 기본 효과 초기화")

func _gates(owned: bool) -> bool:
	for id in UPGRADES:
		if not _check(not growth._card_available(PrototypeAbilityCodex.profile(id)), "선행/중복 후보 제외: " + id): return false
		if not _reject_card(id): return false
	return _check(UPGRADES.keys().all(func(id: String) -> bool: return growth.ranks.has(id) == owned), "거부된 선택 상태 보존")

func _save_guards() -> bool:
	var saved := store.load_checkpoint()
	for id in UPGRADES:
		for invalid in [2, 0, true, "1", 0.5]:
			var bad := saved.duplicate(true)
			bad.growth.ranks[id] = invalid
			if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "잘못된 강화 등급 정상파일 보호"): return false
		var bad := saved.duplicate(true)
		bad.growth.ranks.erase(UPGRADES[id])
		bad.growth.ranks.vitality = int(bad.growth.ranks.get("vitality", 0)) + 1
		bad.player.max_health += 20
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "선행 없는 저장 거부"): return false
	var full := saved.duplicate(true)
	full.player.potions_remaining = 4
	if not _check(store.save_checkpoint(full) == OK, "확장 주머니 실제 최대4 저장 허용"): return false
	full.player.potions_remaining = 5
	if not _check(store.save_checkpoint(full) == ERR_INVALID_DATA, "최대 초과 저장 거부"): return false
	return _check(store.save_checkpoint(saved) == OK, "검사 이후 실제 잔량 저장 복구")

func _views() -> bool:
	var files := _files()
	var effects := _effects()
	if not _check(controls.open_run_build(), "도전 상태 열기"): return false
	var cards := PrototypeRunBuildView.cards(2, controls.run_build_state)
	if not _check(cards[1].lines.has("회복 구슬 획득 거리 2.28m") and cards[1].lines[1].contains("/ 4개") and cards[2].lines.has("다음 필살기 감속 5.0초"), "현재 도전 합산 효과 표시"): return false
	controls.close_run_build()
	controls._process(3.1)
	controls.show_main_screen()
	controls.show_village()
	if not await _test_book_layout(): return false
	controls.show_main_screen()
	# 도감 조회 뒤 동일 전투 상태로 돌아간다.
	controls.screen_mode = 0
	paused = false
	return _check(_files() == files and _effects() == effects, "도감 조회 효과/파일 불변")

func _combat_effects() -> bool:
	# 기존 발동의 남은 시간은 강화 토글에도 그대로다.
	ultimate.gauge = 100
	ultimate.request_ultimate()
	var remaining := ultimate._remaining_s
	ultimate.time_echo_boost_unlocked = false
	if not _check(remaining == 5 and ultimate._remaining_s == remaining and ultimate.duration_for({}) == 4, "현재 감속 불변·다음 발동만 변경"): return false
	ultimate.time_echo_boost_unlocked = true
	ultimate.finish_stage_effect()
	for recipe in [PrototypePotionRecipes.BASIC, PrototypePotionRecipes.CONCENTRATED, PrototypePotionRecipes.PORTIONED]:
		player.prepare_potions(recipe)
		if not _check(player.potions_capacity() == int(PrototypePotionRecipes.profile(recipe).count) + 2, "세 조제 확장 소지량"): return false
		player.damage_receiver.max_health = 101
		player.damage_receiver.health = 1
		var before := player.potions_remaining
		player._input_lock_remaining_s = 0
		if not _check(player.use_recovery_potion() and player.damage_receiver.health == 1 + ceili(101 * roundi(player.potion_heal_ratio() * 100) / 100.0) and player.potions_remaining == before - 1, "세 조제 숙련 정수 올림/한개 소비"): return false
		player.damage_receiver.health = 101
		if not _check(not player.use_recovery_potion() and player.potions_remaining == before - 1, "만피 무료 소비 차단"): return false
	var orbs: RecoveryOrbController = sandbox.get_node("RecoveryOrbController")
	orbs.set_physics_process(false)
	player.damage_receiver.health = 1
	orbs.orbs = [player.global_position + Vector2(229, 0)]
	orbs._physics_process(0.01)
	if not _check(orbs.orbs.size() == 1, "넓은 자석 경계 바깥 유지"): return false
	orbs.orbs[0] = player.global_position + Vector2(228, 0)
	orbs._physics_process(0.01)
	return _check(orbs.orbs.is_empty() and player.damage_receiver.health == 12, "거리2.28m 실제 획득·기본10% 회복 유지")

func _files() -> Dictionary:
	var result := {}
	for path in [BATCH_SAVE, BATCH_SAVE + ".bak", BATCH_META, BATCH_RECORD, BATCH_BOOK]:
		result[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return result

func _earn(id: String, failure: bool = false) -> bool:
	var selected_seed := -1
	for candidate in 512:
		growth.rng.seed = candidate
		if growth._draw_cards().any(func(card: Dictionary) -> bool: return card.id == id):
			selected_seed = candidate
			break
	if not _check(selected_seed >= 0, "선행 후 실제 무작위 후보: " + id): return false
	growth.rng.seed = selected_seed
	# 실제 피해·처치 신호·경험치로 후보를 연다. 선택할 카드는 주입하지 않는다.
	for ignored in 80:
		if growth.choosing: break
		var target := _collector_target("earned:%d" % _earned_kills)
		_earned_kills += 1
		_defeat(target)
		target.free()
	var index := -1
	for i in growth.offered_cards.size():
		if growth.offered_cards[i].id == id: index = i
	if not _check(index >= 0 and growth.choosing and paused, "실제 처치 경험치·자연 후보·모바일 카드: " + id): return false
	var before := growth.checkpoint_snapshot()
	var effects := _effects()
	var health := player.damage_receiver.health
	var barrier := player.damage_receiver.barrier_health
	var potions := player.potions_remaining
	var gauge := ultimate.gauge
	var timers := weapons.checkpoint_snapshot()
	var files := _files()
	if failure:
		for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
			controls.size = dimensions
			controls._refresh_growth_layout()
			var rect: Rect2 = controls.growth_card_rects[index]
			if not _check(controls.layout_snapshot().safe.encloses(rect), "새 강화 카드 두 화면비 안전 영역"): return false
			for line in growth.offered_cards[index].lines:
				if not _check(ThemeDB.fallback_font.get_string_size(String(line), HORIZONTAL_ALIGNMENT_LEFT, -1, mini(26, int(rect.size.x / 12.0)) - 3).x <= rect.size.x - 24, "새 강화 설명 너비"): return false
		book.save_path = "user://gp167_170_missing/abilities.jsonl"
		_tap(controls.growth_card_rects[index].get_center())
		book.save_path = BATCH_BOOK
		if not _check(paused and growth.choosing and growth.checkpoint_snapshot() == before and _effects() == effects and not book.snapshot().has(id) and _files() == files, "각 강화 기록 실패·등급/성향/효과/파일 롤백"): return false
	_tap(controls.growth_card_rects[index].get_center())
	if failure and not _check(player.damage_receiver.health == health and player.damage_receiver.barrier_health == barrier and player.potions_remaining == (mini(player.potions_capacity(), potions + 1) if id == "potion_pouch_boost" else potions) and ultimate.gauge == gauge and weapons.checkpoint_snapshot() == timers, "같은 카드 재시도·선택 자체는 회복/보충/충전 없음"): return false
	return _check(not paused and not growth.choosing and growth.ranks[id] == 1 and book.snapshot().has(id), "실제 터치·영구 발견·효과 적용: " + id)

