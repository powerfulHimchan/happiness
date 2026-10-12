extends "res://tests/gp148_runtime_test.gd"

const BATCH_SAVE := "user://gp207_212_checkpoint.json"
const BATCH_META := "user://gp207_212_meta.jsonl"
const BATCH_RECORD := "user://gp207_212_records.jsonl"
const BATCH_BOOK := "user://gp207_212_abilities.jsonl"
const UPGRADES := {"barrier_focus": "magic_barrier", "crisis_power": "power", "nimble_mastery": "nimble_evade", "orb_bloom": "orb_vitality", "potion_efficiency": "potion_mastery", "time_attunement": "time_collector"}
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
			for id in ["magic_barrier", "power", "nimble_evade", "orb_magnet", "orb_vitality", "potion_pouch", "potion_mastery", "time_collector", "lifesteal"]:
				if not await _earn(id): return
			player.lifesteal_progress = 7
			for id in UPGRADES:
				if not await _earn(id, true): return
			if not _gates(true) or not _test_effects() or not await _views(): return
			if phase == "combat":
				if not _combat_effects(): return
			else:
				if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "실제 첫 정예 저장"): return
				player.damage_receiver.health = 17
				player.potions_remaining = 1
				player.damage_receiver.barrier_health = 13
				player.lifesteal_progress = 9
				ultimate.gauge = 31
				weapons.sword_combat._skill_1_cooldown_s = 3.25
				if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "네 강화 실제 잔량 저장"): return
				if not _save_guards(): return
		"resume":
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and player.damage_receiver.health == 17 and player.potions_remaining == 1 and player.damage_receiver.barrier_health == 13 and player.lifesteal_progress == 9 and ultimate.gauge == 31 and weapons.sword_combat._skill_1_cooldown_s == 3.25, "반복 이어하기 무료 보충/회복/충전 없음"): return
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
			for id in ["magic_barrier", "power", "nimble_evade", "orb_magnet", "orb_vitality", "potion_pouch", "potion_mastery", "time_collector", "lifesteal"]:
				if not await _earn(id): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "새 강화 없는 기존 저장"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and UPGRADES.keys().all(func(id: String) -> bool: return not player.get(id + "_unlocked")), "기존 저장 새 강화 자동 지급 없음"): return
		_:
			_check(false, "검사 단계 오류")
			return
	paused = false
	sandbox.free()
	print("GP-207–212 runtime test: OK (" + phase + ")")
	quit(0)

func _effects() -> Array:
	return [player.barrier_focus_unlocked, player.crisis_power_unlocked, player.ground_evade_cooldown_s(), player.recovery_orb_heal_percent(), roundi(player.potion_heal_ratio() * 100), ultimate.weapon_hit_gauge_amount(false), ultimate.weapon_hit_gauge_amount(true)]

func _test_effects() -> bool:
	return _check(UPGRADES.keys().all(func(id: String) -> bool: return player.get(id + "_unlocked")) and is_equal_approx(player.ground_evade_cooldown_s(), 0.324) and player.recovery_orb_heal_percent() == 25 and roundi(player.potion_heal_ratio() * 100) == 35 and ultimate.weapon_hit_gauge_amount(false) == 5 and ultimate.weapon_hit_gauge_amount(true) == 10, "6개 선택 등급에서 파생 효과 한번 적용")

func _defaults() -> bool:
	return _check(growth.ranks.is_empty() and UPGRADES.keys().all(func(id: String) -> bool: return not player.get(id + "_unlocked")) and player.recovery_orb_heal_percent() == 10 and ultimate.weapon_hit_gauge_amount(true) == 8, "새 도전 여섯 효과 초기화")

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
		if UPGRADES[id] == "power": bad.player.common -= 0.10
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "선행 없는 저장 거부"): return false
	return _check(store.load_checkpoint() == saved, "검사 이후 실제 저장 보존")

func _views() -> bool:
	var files := _files()
	var effects := _effects()
	if not _check(controls.open_run_build(), "도전 상태 열기"): return false
	if not _check(controls.run_build_state.ultimate.basic_gain == 5 and controls.run_build_state.ultimate.skill_gain == 10, "도전 상태 시간 조율 실제 적중 게이지"): return false
	var cards := PrototypeRunBuildView.cards(2, controls.run_build_state)
	if not _check(cards[1].lines.has("회복 구슬 · 체력 25%% (+%d)" % player.recovery_orb_heal_amount()), "실제 흡수/처치 회복 상태 표시"): return false
	controls.close_run_build()
	controls._process(3.1)
	controls.show_main_screen()
	controls.show_village()
	paused = true
	if not await _test_book_layout(): return false
	controls.show_main_screen()
	# 도감 조회 뒤 동일 전투 상태로 돌아간다.
	controls.screen_mode = 0
	paused = false
	return _check(_files() == files and _effects() == effects, "도감 조회 효과/파일 불변")

func _combat_effects() -> bool:
	player.prepare_next_stage(Vector2(1000, 780))
	player.growth_common_bonus = 0
	player.damage_receiver.max_health = 100
	for health in [30, 31, 80]:
		player.damage_receiver.health = health
		for barrier in [0, 1]:
			player.damage_receiver.barrier_health = barrier
			for weapon in ["sword", "bow"]:
				if not _check(player.growth_damage(100, weapon) == (120 if health <= 30 else 100) and player.growth_damage(100, weapon, "skill") == (115 if barrier > 0 else 100) and player.growth_damage(100, weapon, "ultimate") == 100, "위기30%/방벽0과1 정수 경계·공격 종류 독립"): return false
	player.damage_receiver.health = 31
	player.damage_receiver.barrier_health = 1
	var target := _absorb_target("barrier-focus", player.global_position + Vector2(180, 0))
	ultimate.gauge = 0
	weapons.sword_combat._action_sequence += 1
	weapons.sword_combat._damage_target(target, &"sword_flurry", 100, 0, PackedStringArray(["sword", "skill"]), 0)
	if not _check(target.damage_receiver.health == 885 and ultimate.gauge == 10, "실제 스킬115 피해·조율10 충전"): return false
	target.free()
	player.damage_receiver.health = 1
	var orbs: RecoveryOrbController = sandbox.get_node("RecoveryOrbController")
	orbs.orbs = [player.global_position]
	orbs._physics_process(0.01)
	if not _check(player.damage_receiver.health == 26, "실제 구슬25 회복"): return false
	player.damage_receiver.health = 1
	player.potions_remaining = 1
	if not _check(player.use_recovery_potion() and player.damage_receiver.health == 36 and player.potions_remaining == 0, "실제 소비35 회복·개수 소모"): return false
	for relic in [PrototypeRelic.TEMPO_BELL_ID, PrototypeRelic.SKILL_PRISM_ID, PrototypeRelic.HOURGLASS_ID]:
		player.relic_state = {"id": relic, "used": false}
		if not _check(ultimate.weapon_hit_gauge_amount(false) == (7 if relic == PrototypeRelic.TEMPO_BELL_ID else 6 if relic == PrototypeRelic.HOURGLASS_ID else 5) and ultimate.weapon_hit_gauge_amount(true) == (13 if relic in [PrototypeRelic.SKILL_PRISM_ID, PrototypeRelic.HOURGLASS_ID] else 10), "시간 조율·기존/신규 유물 합산·최종 반올림"): return false
	player.relic_state = {"id": PrototypeRelic.BARRIER_LENS_ID, "used": false}
	player.damage_receiver.barrier_health = 1
	if not _check(player.growth_damage(100, "sword", "skill") == 144, "방벽 집중/렌즈 곱연산 한번 반올림"): return false
	player.relic_state = {"id": PrototypeRelic.WIND_ID, "used": false}
	if not _check(is_equal_approx(player.ground_evade_cooldown_s(), 0.2592), "회피 숙련·민첩·바람 매듭 곱연산"): return false
	player.damage_receiver.max_health = 101
	player.relic_state = {"id": PrototypeRelic.SEED_ID, "used": false}
	if not _check(player.recovery_orb_heal_percent() == 30 and player.recovery_orb_heal_amount() == 31, "구슬 개화·씨앗 합산·최대101 소수 올림"): return false
	player.relic_state = {"id": PrototypeRelic.DEW_ID, "used": false}
	return _check(roundi(player.potion_heal_ratio() * 100) == 45, "회복약 정통·숙련·이슬 합산")

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
		book.save_path = "user://gp207_212_missing/abilities.jsonl"
		_tap(controls.growth_card_rects[index].get_center())
		book.save_path = BATCH_BOOK
		if not _check(paused and growth.choosing and growth.checkpoint_snapshot() == before and _effects() == effects and not book.snapshot().has(id) and _files() == files, "각 강화 기록 실패·등급/성향/효과/파일 롤백"): return false
	_tap(controls.growth_card_rects[index].get_center())
	if failure and not _check(player.damage_receiver.health == health and player.damage_receiver.barrier_health == barrier and player.potions_remaining == potions and ultimate.gauge == gauge and weapons.checkpoint_snapshot() == timers, "같은 카드 재시도·선택 자체는 회복/보충/충전 없음"): return false
	return _check(not paused and not growth.choosing and growth.ranks[id] == 1 and book.snapshot().has(id), "실제 터치·영구 발견·효과 적용: " + id)
