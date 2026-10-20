extends "res://tests/gp148_runtime_test.gd"

const BATCH_SAVE := "user://gp177_180_checkpoint.json"
const BATCH_META := "user://gp177_180_meta.jsonl"
const BATCH_RECORD := "user://gp177_180_records.jsonl"
const BATCH_BOOK := "user://gp177_180_abilities.jsonl"
const UPGRADES := {"survival_instinct": "fortified_barrier", "calm_focus": "power", "healing_flow": "lifesteal_depth", "victory_resilience": "victory_recovery_boost"}
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
			for id in ["magic_barrier", "fortified_barrier", "power", "lifesteal", "lifesteal_depth", "victory_recovery", "victory_recovery_boost"]:
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
			for id in ["magic_barrier", "fortified_barrier", "power", "lifesteal", "lifesteal_depth", "victory_recovery", "victory_recovery_boost"]:
				if not await _earn(id): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "새 강화 없는 기존 저장"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and not player.survival_instinct_unlocked and not player.calm_focus_unlocked and not player.healing_flow_unlocked and not growth.ranks.has("victory_resilience") and player.lifesteal_rate_percent() == 10 and growth.victory_recovery_amount() == ceili(player.damage_receiver.max_health * 3 / 100.0), "기존 저장은 새 조건부 강화 자동 지급 없이 복원"): return
		_:
			_check(false, "검사 단계 오류")
			return
	paused = false
	sandbox.free()
	print("GP-177–180 runtime test: OK (" + phase + ")")
	quit(0)

func _effects() -> Array:
	return [player.incoming_damage_multiplier(), player.calm_damage_multiplier("skill"), player.lifesteal_rate_percent(), growth.victory_recovery_amount()]

func _test_effects() -> bool:
	return _check(player.survival_instinct_unlocked and player.calm_focus_unlocked and player.healing_flow_unlocked and player.lifesteal_rate_percent() == 15 and growth.victory_recovery_amount() == ceili(player.damage_receiver.max_health * 4 / 100.0), "네 강화 등급에서 효과 한번 적용")

func _defaults() -> bool:
	return _check(growth.ranks.is_empty() and not player.survival_instinct_unlocked and not player.calm_focus_unlocked and not player.healing_flow_unlocked and player.lifesteal_rate_percent() == 0 and growth.victory_recovery_amount() == 0, "새 도전 전체 추가 효과 초기화")

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
	var cards := PrototypeRunBuildView.cards(2, controls.run_build_state)
	if not _check(cards[1].lines[3].contains("15%") and cards[1].lines.has("처치 회복 · 적마다 체력 +%d" % growth.victory_recovery_amount()), "실제 흡수/처치 회복 상태 표시"): return false
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
	for health in [30, 31, 80, 79]:
		player.damage_receiver.health = health
		player.damage_receiver.barrier_health = 0
		player.damage_receiver.tick(2)
		if not _check(player.growth_damage(100, "sword", "skill") == (115 if health >= 80 else 100) and player.growth_damage(100, "bow") == 100 and player.growth_damage(100, "sword", "ultimate") == 100, "80% 정수 경계·검/활 스킬만 강화"): return false
		var event := DamageEvent.new()
		event.event_id = StringName("instinct:" + str(health))
		event.damage = 10
		event.tags = PackedStringArray(["enemy"])
		if not _check(player.receive_damage(event) == DamageReceiver.Result.APPLIED and event.damage == 10 and player.damage_receiver.last_health_damage == (9 if health <= 30 else 10), "실제30% 경계 전투 피해·공유 이벤트 불변"): return false
	player.damage_receiver.health = 30
	player.damage_receiver.barrier_health = 7
	player.damage_receiver.tick(2)
	var barrier_hit := DamageEvent.new()
	barrier_hit.event_id = &"instinct:barrier"
	barrier_hit.damage = 10
	player.receive_damage(barrier_hit)
	if not _check(player.damage_receiver.health == 28 and player.damage_receiver.barrier_health == 0, "생존 본능 감소9 뒤 방벽7 먼저 흡수"): return false
	player.prepare_next_stage(Vector2(1000, 780))
	player.damage_receiver.health = 1
	player.damage_receiver.barrier_health = 0
	player.lifesteal_progress = 7
	var target := _absorb_target("flow-fraction", player.global_position + Vector2(180, 0))
	_sword_hit(target, 7)
	if not _check(player.damage_receiver.health == 2 and player.lifesteal_progress == 8, "실제 깊은 흡수15%·소수7+21→체력1/잔여8"): return false
	target.free()
	player.damage_receiver.max_health = 101
	player.damage_receiver.health = 1
	target = _collector_target("resilience")
	_defeat(target)
	if not _check(player.damage_receiver.health == 6, "실제 처치 최대101의4% 올림5 회복"): return false
	target.defeated.emit(target)
	target.free()
	return _check(player.damage_receiver.health == 6, "동일 생명 중복 처치 회복 없음")

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
				var line_font_size := mini(26, int(rect.size.x / 12.0)) - 3
				while line_font_size > 10 and ThemeDB.fallback_font.get_string_size(String(line), HORIZONTAL_ALIGNMENT_LEFT, -1, line_font_size).x > rect.size.x - 24:
					line_font_size -= 1
				if not _check(ThemeDB.fallback_font.get_string_size(String(line), HORIZONTAL_ALIGNMENT_LEFT, -1, line_font_size).x <= rect.size.x - 24, "새 강화 설명 너비"): return false
		book.save_path = "user://gp177_180_missing/abilities.jsonl"
		_tap(controls.growth_card_rects[index].get_center())
		book.save_path = BATCH_BOOK
		if not _check(paused and growth.choosing and growth.checkpoint_snapshot() == before and _effects() == effects and not book.snapshot().has(id) and _files() == files, "각 강화 기록 실패·등급/성향/효과/파일 롤백"): return false
	_tap(controls.growth_card_rects[index].get_center())
	if failure and not _check(player.damage_receiver.health == health and player.damage_receiver.barrier_health == barrier and player.potions_remaining == potions and ultimate.gauge == gauge and weapons.checkpoint_snapshot() == timers, "같은 카드 재시도·선택 자체는 회복/보충/충전 없음"): return false
	return _check(not paused and not growth.choosing and growth.ranks[id] == 1 and book.snapshot().has(id), "실제 터치·영구 발견·효과 적용: " + id)
