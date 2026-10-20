extends "res://tests/gp148_runtime_test.gd"

const BATCH_SAVE := "user://gp159_161_checkpoint.json"
const BATCH_META := "user://gp159_161_meta.jsonl"
const BATCH_RECORD := "user://gp159_161_records.jsonl"
const BATCH_BOOK := "user://gp159_161_abilities.jsonl"
const UPGRADES := {
	"evasive_barrier_boost": "evasive_barrier",
	"restorative_barrier_boost": "restorative_barrier",
	"victory_recovery_boost": "victory_recovery",
}
var _earned_kills: int = 0

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	store.save_path = BATCH_SAVE
	legacy.save_path = BATCH_META
	book.save_path = BATCH_BOOK
	if phase in ["seed", "legacy-seed", "evasion", "potions", "victory", "combined"]:
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
	growth.jobs_enabled = false
	match phase:
		"seed":
			controls.begin_retry("sword", 5)
			if not _test_upgrade_gates(): return
			if not await _earn("magic_barrier"): return
			for id in UPGRADES:
				if not await _earn(UPGRADES[id]): return
				if not _test_upgrade_gates(id): return
				if not await _earn(id, true): return
			if not await _earn("fortified_barrier"): return
			if not _test_upgrade_gates() or not await _test_upgrade_views(): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "실제 첫 정예 이후 강화 조합 저장"): return
			player.damage_receiver.health = 17
			player.damage_receiver.barrier_health = 13
			player.potions_remaining = 1
			ultimate.gauge = 31
			weapons.sword_combat._skill_1_cooldown_s = 3.25
			weapons.bow_combat._skill_2_cooldown_s = 5.5
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "세 강화·체력17·방벽13·회복약1·게이지31·양 대기 저장"): return
			if not _test_upgrade_save(): return
			controls.show_main_screen()
			controls.show_village()
			if not await _test_book_layout(): return
		"resume":
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and growth.evasive_barrier_amount() == 8 and player.potion_barrier_recovery() == 15 and growth.victory_recovery_amount() == ceili(player.damage_receiver.max_health * 3 / 100.0) and player.damage_receiver.health == 17 and player.damage_receiver.barrier_health == 13 and player.potions_remaining == 1 and ultimate.gauge == 31 and weapons.sword_combat._skill_1_cooldown_s == 3.25 and weapons.bow_combat._skill_2_cooldown_s == 5.5, "별도 프로세스 반복 복원·세 강화 한번씩·무료 회복/방벽/약 보충 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _test_upgrade_views() or not await _test_upgrade_combined(): return
			while not runner.awaiting_boss_choice():
				if not _finish_stage(): return
				if runner.awaiting_boss_choice(): break
				if not _check(sandbox._claim_weapon_reward(""), "정예 보상 유지"): return
				_tap(controls.stage_route_rects[0].get_center())
			for id in UPGRADES:
				if not _check(store.load_checkpoint().growth.ranks[id] == 1, "5단계 최종 저장의 강화 보존"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and sandbox._resolve_boss_choice("rescue"), "별도 보스 선택 복원·5단계 완주"): return
			controls.begin_retry("bow", 3)
			if not _check(growth.ranks.is_empty() and growth.evasive_barrier_amount() == 0 and player.potion_barrier_recovery() == 0 and not player.restorative_barrier_boost_unlocked and growth.victory_recovery_amount() == 0 and UPGRADES.keys().all(func(id: String) -> bool: return book.snapshot().has(id)), "새 도전 전체 효과 초기화·영구 발견만 보존"): return
		"legacy-seed":
			controls.begin_retry("bow", 3)
			for id in ["magic_barrier", "evasive_barrier", "restorative_barrier", "victory_recovery"]:
				if not await _earn(id): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "기존 기본 능력 저장 생성"): return
			if not _check(UPGRADES.keys().all(func(id: String) -> bool: return not store.load_checkpoint().growth.ranks.has(id)), "기존 저장에 세 강화 없음"): return
			player.damage_receiver.health = 17
			player.damage_receiver.barrier_health = 13
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "기존 저장 잔량 유지"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and growth.evasive_barrier_amount() == 5 and player.potion_barrier_recovery() == 10 and growth.victory_recovery_amount() == ceili(player.damage_receiver.max_health * 2 / 100.0) and not player.restorative_barrier_boost_unlocked and player.damage_receiver.health == 17 and player.damage_receiver.barrier_health == 13, "기존 저장5/10/2% 복원·새 강화 소급 지급 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _test_legacy_effects(): return
			while not runner.awaiting_boss_choice():
				if not _finish_stage(): return
				if runner.awaiting_boss_choice(): break
				if not _check(sandbox._claim_weapon_reward(""), "기존 저장 정예"): return
				_tap(controls.stage_route_rects[0].get_center())
			if not _check(sandbox._resolve_boss_choice("destroy"), "기존3단계 저장 완주"): return
		"evasion":
			controls.begin_retry()
			for id in ["magic_barrier", "evasive_barrier", "evasive_barrier_boost"]:
				if not await _earn(id): return
			if not await _test_boosted_evasion(): return
		"potions":
			controls.begin_retry()
			for id in ["magic_barrier", "restorative_barrier", "restorative_barrier_boost"]:
				if not await _earn(id): return
			if not await _test_boosted_potions(): return
		"victory":
			controls.begin_retry()
			for id in ["victory_recovery", "victory_recovery_boost"]:
				if not await _earn(id): return
			player.damage_receiver.health = 25
			if not _test_victory_rounding() or not _test_boosted_victory(): return
		"combined":
			controls.begin_retry("sword", 5)
			for id in ["magic_barrier", "evasive_barrier", "evasive_barrier_boost", "restorative_barrier", "restorative_barrier_boost", "victory_recovery", "victory_recovery_boost", "fortified_barrier", "lifesteal", "time_collector", "time_collector_boost"]:
				if not await _earn(id): return
			if not await _test_upgrade_combined() or not await _test_upgrade_views(): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-159/160/161 runtime test: OK (" + phase + ")")
	quit(0)

func _files() -> Dictionary:
	var result := {}
	for path in [BATCH_SAVE, BATCH_SAVE + ".bak", BATCH_META, BATCH_RECORD, BATCH_BOOK]:
		result[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return result

func _effects() -> Array:
	return [growth.evasive_barrier_amount(), player.potion_barrier_recovery(), growth.victory_recovery_amount()]

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
		book.save_path = "user://gp159_161_missing/abilities.jsonl"
		_tap(controls.growth_card_rects[index].get_center())
		book.save_path = BATCH_BOOK
		if not _check(paused and growth.choosing and growth.checkpoint_snapshot() == before and _effects() == effects and not book.snapshot().has(id) and _files() == files, "각 강화 기록 실패·등급/성향/효과/파일 롤백"): return false
	_tap(controls.growth_card_rects[index].get_center())
	if failure and not _check(player.damage_receiver.health == health and player.damage_receiver.barrier_health == barrier and player.potions_remaining == potions and ultimate.gauge == gauge and weapons.checkpoint_snapshot() == timers, "같은 카드 재시도·선택 자체는 회복/보충/충전 없음"): return false
	return _check(not paused and not growth.choosing and growth.ranks[id] == 1 and book.snapshot().has(id), "실제 터치·영구 발견·효과 적용: " + id)

func _test_upgrade_gates(available: String = "") -> bool:
	for id in UPGRADES:
		if id == available: continue
		for ignored in 50:
			if not _check(not growth._draw_cards().any(func(card: Dictionary) -> bool: return card.id == id), "선행 없는 강화/최대1등급 후보 제외"): return false
		var before := growth.checkpoint_snapshot()
		var effects := _effects()
		if not _reject_card(id): return false
		if not _check(before == growth.checkpoint_snapshot() and effects == _effects(), "위조/중복 선택은 등급/효과 보존"): return false
	return true

func _test_upgrade_save() -> bool:
	var saved := store.load_checkpoint()
	for id in UPGRADES:
		for invalid in [null, true, "1", 0, 2, 0.5]:
			var bad := saved.duplicate(true)
			bad.growth.ranks[id] = invalid
			if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "각 강화 등급 변조 거부·정상 파일 보호"): return false
		var bad := saved.duplicate(true)
		bad.growth.ranks.erase(UPGRADES[id])
		# 등급 개수·최대 체력은 맞춰 선행 조건 자체의 거부를 확인한다.
		bad.growth.ranks.vitality = int(bad.growth.ranks.get("vitality", 0)) + 1
		bad.player.max_health += 20
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "각 강화 선행 없는 저장 거부"): return false
	return true

func _test_victory_rounding() -> bool:
	var maximum := player.damage_receiver.max_health
	for pair in [[100, 3], [101, 4], [105, 4], [110, 4], [120, 4], [200, 6], [300, 9]]:
		player.damage_receiver.max_health = pair[0]
		if not _check(growth.victory_recovery_amount() == pair[1], "현재 최대 체력의3%·정수 올림"): return false
	player.damage_receiver.max_health = maximum
	return true

func _test_upgrade_combined() -> bool:
	player.damage_receiver.health = 1
	player.damage_receiver.barrier_health = 0
	player.damage_receiver.tick(2.0)
	player._input_lock_remaining_s = 0
	if not await _start_real_evade(1): return false
	_seed_hit("combined:%d" % _earned_kills)
	if not _check(player.damage_receiver.barrier_health == 8 and player.damage_receiver.health == 1, "조합의 실제 정확 회피8·체력 무변경"): return false
	player._update_mobility_timers(1.0)
	player.prepare_potions(PrototypePotionRecipes.BASIC)
	var potions := player.potions_remaining
	_press_potion()
	if not _check(player.damage_receiver.barrier_health == mini(player.barrier_capacity(), 23) and player.potions_remaining == potions - 1, "회피8 뒤 실제 약15 합산·20/30 상한·한 개 소비"): return false
	player.global_position = Vector2(1000, 780)
	player.facing_direction = 1
	var target := _collector_target("combined-kill:%d" % _earned_kills)
	player.damage_receiver.health = 1
	player.lifesteal_progress = 0
	var barrier := player.damage_receiver.barrier_health
	ultimate.gauge = 0
	player.relic_state = {"id": PrototypeRelic.HOURGLASS_ID, "used": false}
	var expected := growth.victory_recovery_amount() + (target.damage_receiver.health / 20 if player.lifesteal_unlocked else 0)
	var expected_gauge := 5 + (10 if growth.ranks.has("time_collector_boost") else 0)
	_sword_hit(target, 9999)
	if not _check(player.damage_receiver.health == 1 + expected and player.damage_receiver.barrier_health == barrier and ultimate.gauge == expected_gauge, "검 실제 처치3%+흡수·방벽 독립·모래시계 타격/처치 게이지 독립"): return false
	target.defeated.emit(target)
	if not _check(player.damage_receiver.health == 1 + expected and player.damage_receiver.barrier_health == barrier and ultimate.gauge == expected_gauge, "중복 처치는 세 강화/흡수/게이지 재지급 없음"): return false
	if not _resolve_growth(): return false
	target.free()
	player.relic_state = {}
	return true

func _test_upgrade_views() -> bool:
	var files := _files()
	var state := [player.damage_receiver.health, player.damage_receiver.barrier_health, player.potions_remaining, ultimate.gauge, weapons.checkpoint_snapshot()]
	if not _check(controls.open_run_build() and paused, "세 강화 현재 도전 조회"): return false
	var cards := PrototypeRunBuildView.cards(0, controls.run_build_state)
	for id in UPGRADES:
		var card: Dictionary = cards.filter(func(item: Dictionary) -> bool: return item.id == id)[0]
		if not _check(card.status == "이번 도전 1등급" and card.lines[0] == PrototypeAbilityCodex.profile(id).lines[0], "세 강화 보유 등급·원본 효과"): return false
	var survival := PrototypeRunBuildView.cards(2, controls.run_build_state)[1]
	if not _check(survival.lines[0].ends_with("정확 회피 +8") and survival.lines[2].ends_with("방벽 +15") and survival.lines.has("처치 회복 · 적마다 체력 +%d" % growth.victory_recovery_amount()), "생존 카드의 실제8/15/3% 표시"): return false
	if not await _test_layout(): return false
	await create_timer(0.12, true).timeout
	controls.close_run_build()
	controls.advance_mode_timer_for_test(2.9)
	if not _check(paused, "3초 복귀 유지"): return false
	controls.advance_mode_timer_for_test(0.2)
	if not _check(not paused and _files() == files and state == [player.damage_receiver.health, player.damage_receiver.barrier_health, player.potions_remaining, ultimate.gauge, weapons.checkpoint_snapshot()], "조회·복귀는 체력/방벽/약/게이지/대기/파일 무변경"): return false
	var codex := PrototypeAbilityCodex.cards(book.snapshot(), growth.ranks)
	if not _check(codex.size() == PrototypeGrowthController.CARDS.size() + PrototypeJobRewards.CARDS.size() and codex.size() >= 30, "30종 능력 도감"): return false
	for id in UPGRADES:
		var card: Dictionary = codex.filter(func(item: Dictionary) -> bool: return item.id == id)[0]
		if not _check(card.open and card.lines[2] == "조건: " + PrototypeAbilityCodex.profile(UPGRADES[id]).title + " 획득 후", "각 강화 도감 선행/발견/등급 표시"): return false
	return true

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-159/160/161 failed: " + message)
		paused = false
		quit(1)
	return condition

func _test_boosted_evasion() -> bool:
	for direction in [1, -1]:
		player.damage_receiver.barrier_health = 0
		ultimate.gauge = 0
		var health := player.damage_receiver.health
		if not await _start_real_evade(direction): return false
		if not _check(player.damage_receiver.barrier_health == 0, "회피 입력만으로 회복 없음"): return false
		_seed_hit("first:%d" % direction)
		if not _check(player.damage_receiver.barrier_health == 8 and player.damage_receiver.health == health and ultimate.gauge == 12, "실제 씨앗 정확 회피·방벽8·원본 게이지12"): return false
		_seed_hit("first:%d" % direction)
		_wave_hit("second:%d" % direction)
		ultimate.precise_evade_registered.emit()
		if not _check(player.damage_receiver.barrier_health == 8 and ultimate.gauge == 24 and player.damage_receiver.health == health, "중복 타격/충격파/중복 신호는 같은 회피8 상한·기존 게이지 유지"): return false
		player._update_mobility_timers(0.19)
		_seed_hit("exposed:%d" % direction)
		if not _check(not player.invincible and player.damage_receiver.barrier_health == 1 and player.damage_receiver.health == health, "무적 연장 없이0.19초 실제7·방벽7흡수/잔량1·체력 유지"): return false
		player._update_mobility_timers(1.0)
	if not await _start_real_evade(1): return false
	player.damage_receiver.barrier_health = 18
	_seed_hit("cap20")
	if not _check(player.damage_receiver.barrier_health == 20, "기본 방벽20 상한"): return false
	player.damage_receiver.barrier_health = 0
	_wave_hit("cap20-replay")
	if not _check(player.damage_receiver.barrier_health == 0, "가득 찬 회피도 기회 소비·같은 회피 재충전 없음"): return false
	player._update_mobility_timers(1.0)
	player.set_fortified_barrier_unlocked(true)
	if not await _start_real_evade(-1): return false
	player.damage_receiver.barrier_health = 28
	_wave_hit("cap30")
	if not _check(player.damage_receiver.barrier_health == 30 and controls.movement_metrics.barrier_health == 30, "견고한 방벽30 상한·HUD 즉시 갱신"): return false
	player._update_mobility_timers(1.0)
	# 실제 일반 적 근접 판정도 같은 신호를 사용한다.
	if not await _start_real_evade(1): return false
	player.damage_receiver.barrier_health = 0
	var template: PrototypeEnemy
	for enemy in get_nodes_in_group("combat_enemy"):
		if enemy is PrototypeEnemy:
			template = enemy
			break
	var contact := template.duplicate() as PrototypeEnemy
	contact.target_key = "gp146:contact"
	template.get_parent().add_child(contact)
	contact.set_physics_process(false)
	contact.global_position = player.global_position + Vector2(0, -38)
	contact._attack_hit_consumed = false
	contact._try_contact_damage(7, &"gp146_contact")
	contact.free()
	if not _check(player.damage_receiver.barrier_health == 8, "일반 적 실제 근접 공격 정확 회피8"): return false
	player._update_mobility_timers(1.0)
	if not await _test_boosted_evasion_view(): return false
	# 공중 대시와 부활/피격 보호는 정확한 지상 회피를 대신하지 않는다.
	player.damage_receiver.barrier_health = 0
	player._start_air_dash()
	ultimate.precise_evade_registered.emit()
	if not _check(player.damage_receiver.barrier_health == 0, "공중 대시는 무적/방벽 회복을 새로 주지 않음"): return false
	player._update_mobility_timers(1.0)
	player.invincible = true
	ultimate.precise_evade_registered.emit()
	if not _check(player.damage_receiver.barrier_health == 0, "실제 회피 동작 없는 무적 신호 거부"): return false
	player.invincible = false
	player.damage_receiver.revive_with_health(20, 1.0)
	_seed_hit("protection")
	if not _check(player.damage_receiver.barrier_health == 0 and player.damage_receiver.health == 20, "피격/부활 보호는 충전 없음"): return false
	growth.jobs_enabled = true
	growth.jobs.reset("sword")
	if not await _start_real_evade(1): return false
	var contributions := growth.jobs.contributions.duplicate(true)
	_seed_hit("job-score")
	var scored := growth.jobs.contributions.duplicate(true)
	_wave_hit("job-score-second")
	if not _check(player.damage_receiver.barrier_health == 8 and scored != contributions and growth.jobs.contributions == scored, "기존 직업 회피 성향1회와 방벽8 독립 적용"): return false
	growth.jobs_enabled = false
	player._update_mobility_timers(1.0)
	if not await _start_real_evade(1): return false
	player.damage_receiver.barrier_health = 0
	var stage_complete := runner.stage_complete
	runner.stage_complete = true
	ultimate.precise_evade_registered.emit()
	runner.stage_complete = stage_complete
	sandbox._combat_environment_suspended = true
	ultimate.precise_evade_registered.emit()
	sandbox._combat_environment_suspended = false
	if not _check(player.damage_receiver.barrier_health == 0, "단계 종료·전투 환경 정지 신호 미지급"): return false
	var owned := growth.run_active
	growth.run_active = false
	ultimate.precise_evade_registered.emit()
	growth.run_active = owned
	if not _check(player.damage_receiver.barrier_health == 0, "도전 종료 뒤 신호 거부"): return false
	player.damage_receiver.dead = true
	ultimate.precise_evade_registered.emit()
	if not _check(player.damage_receiver.barrier_health == 0, "사망 뒤 신호 거부"): return false
	player.damage_receiver.dead = false
	player._update_mobility_timers(1.0)
	return true

func _test_boosted_evasion_view() -> bool:
	var files := _files()
	if not await _start_real_evade(1): return false
	var barrier := player.damage_receiver.barrier_health
	var remaining := player._invincible_remaining_s
	if not _check(controls.open_run_build() and paused, "실제 회피 중 도전 상태 조회"): return false
	var abilities := PrototypeRunBuildView.cards(0, controls.run_build_state)
	var card: Dictionary = abilities.filter(func(item: Dictionary) -> bool: return item.id == EVASIVE_ID)[0]
	var health := PrototypeRunBuildView.cards(2, controls.run_build_state)[1]
	if not _check(card.status == "이번 도전 1등급" and health.lines[0].ends_with("정확 회피 +8"), "실제 보유 능력·방벽/회복량 조회"): return false
	ultimate.precise_evade_registered.emit()
	if not _check(player.damage_receiver.barrier_health == barrier, "조회 중 지연 신호는 방벽 미지급"): return false
	if not await _test_layout(): return false
	controls.notification(Control.NOTIFICATION_APPLICATION_PAUSED)
	controls.notification(Control.NOTIFICATION_APPLICATION_RESUMED)
	player.set_physics_process(true)
	await create_timer(0.12, true).timeout
	if not _check(player.damage_receiver.barrier_health == barrier and player._invincible_remaining_s == remaining and _files() == files, "앱 복귀·조회 동결 (방벽%d/%d, 무적%.5f/%.5f, 파일%s)" % [player.damage_receiver.barrier_health, barrier, player._invincible_remaining_s, remaining, _files() == files]): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(2.9)
	ultimate.precise_evade_registered.emit()
	if not _check(paused and player.damage_receiver.barrier_health == barrier, "3초 복귀 중 신호 미지급"): return false
	controls.advance_mode_timer_for_test(0.2)
	player.set_physics_process(false)
	if not _check(not paused and _files() == files and player._invincible_remaining_s == remaining, "복귀 원래 잔량 유지"): return false
	player._update_mobility_timers(1.0)
	return true

func _test_boosted_potions() -> bool:
	player.damage_receiver.max_health = 101
	player.set_potion_pouch_unlocked(true)
	var timers := weapons.checkpoint_snapshot()
	var gauge := ultimate.gauge
	for recipe in PrototypePotionRecipes.IDS:
		for dew in [false, true]:
			player.relic_state = {"id": PrototypeRelic.DEW_ID, "used": false} if dew else {}
			player.prepare_potions(recipe)
			player.damage_receiver.health = 1
			player.damage_receiver.barrier_health = 0
			var before := player.potions_remaining
			var expected := 1 + ceili(101 * player.potion_heal_ratio())
			_press_potion(true)
			if not _check(player.damage_receiver.health == expected and player.damage_receiver.barrier_health == 15 and player.potions_remaining == before - 1 and controls.movement_metrics.barrier_health == 15 and controls.movement_metrics.potion_barrier_recovery == 15, "기본/농축·이슬 조합 원래 회복률·실제1개 소비·방벽15·HUD"): return false
			for ignored in 20: controls._physics_process(0.05)
			if not _check(player.damage_receiver.barrier_health == 15 and player.damage_receiver.health == expected and player.potions_remaining == before - 1, "버튼 유지·반복 프레임은 중복 소비/무료 충전 없음"): return false
			controls._handle_touch_released(7)
			player.damage_receiver.health = 100
			_press_potion()
			if not _check(player.damage_receiver.health == 101 and player.damage_receiver.barrier_health == 20 and player.potions_remaining == before - 2, "실제 체력1 회복도1개 소비·방벽15·20 상한"): return false
	player.relic_state = {}
	for fortified in [false, true]:
		player.set_fortified_barrier_unlocked(fortified)
		var cap := player.barrier_capacity()
		player.prepare_potions(PrototypePotionRecipes.BASIC)
		player.damage_receiver.health = 101
		player.damage_receiver.barrier_health = 0
		_press_potion()
		if not _check(player.potions_remaining == 3 and player.damage_receiver.barrier_health == 0, "만피·방벽 소진에도 회복약 무료 사용 없음"): return false
		player.damage_receiver.health = 1
		player.damage_receiver.barrier_health = cap - 2
		_press_potion()
		if not _check(player.damage_receiver.barrier_health == cap and player.potion_log.ends_with("방벽 +2"), "기본20/강화30 상한·실제 보충2 로그"): return false
		player.damage_receiver.health = 1
		_press_potion()
		if not _check(player.damage_receiver.barrier_health == cap and player.potion_log.ends_with("방벽 +0") and player.potions_remaining == 1, "가득 찬 방벽은 체력 회복만·원래1개 소비"): return false
		player.damage_receiver.health = 1
		player.damage_receiver.barrier_health = 0
		player.potions_remaining = 0
		_press_potion()
		if not _check(player.damage_receiver.health == 1 and player.damage_receiver.barrier_health == 0, "소진 후 회복/방벽 없음"): return false
	player.set_fortified_barrier_unlocked(false)
	player.prepare_potions(PrototypePotionRecipes.BASIC)
	player.damage_receiver.health = 1
	player.damage_receiver.barrier_health = 0
	player.apply_growth_health(0, 1)
	if not _check(player.damage_receiver.barrier_health == 0 and player.potions_remaining == 3, "다른 회복·약 준비는 방벽 미지급"): return false
	_press_potion()
	var health := player.damage_receiver.health
	_barrier_hit("potion-impact17", 17)
	if not _check(player.damage_receiver.barrier_health == 0 and player.damage_receiver.health == health - 2, "회복된 방벽15은 실제17피해 흡수·체력2 차감"): return false
	player.damage_receiver.health = 1
	player.damage_receiver.barrier_health = 0
	player.prepare_potions(PrototypePotionRecipes.BASIC)
	player.damage_receiver.tick(2.0)
	for reason in ["hit", "fall", "dead", "paused", "environment", "stage", "ended", "main"]:
		match reason:
			"hit": player._input_lock_remaining_s = 1.0
			"fall": player._fall_recovery_active = true
			"dead": player.damage_receiver.dead = true
			"paused": paused = true
			"environment": sandbox._combat_environment_suspended = true
			"stage": runner.stage_complete = true
			"ended": growth.run_active = false
			"main": controls.screen_mode = 2
		if not _check(not sandbox._use_recovery_potion() and player.potions_remaining == 3 and player.damage_receiver.health == 1 and player.damage_receiver.barrier_health == 0, reason + " 차단·회복약/체력/방벽 보존"): return false
		player._input_lock_remaining_s = 0
		player._fall_recovery_active = false
		player.damage_receiver.dead = false
		paused = false
		sandbox._combat_environment_suspended = false
		runner.stage_complete = false
		growth.run_active = true
		controls.screen_mode = 0
	if not await _test_boosted_potion_view(): return false
	if not _check(weapons.checkpoint_snapshot() == timers and ultimate.gauge == gauge, "회복 방벽은 스킬/필살기 대기와 충전 독립"): return false
	player.set_barrier_unlocked(false)
	if not _check(player.potion_barrier_recovery() == 0 and not player.restorative_barrier_unlocked, "방벽 해제는 회복 방벽도 종료"): return false
	return true

func _test_boosted_potion_view() -> bool:
	var files := _files()
	var barrier := player.damage_receiver.barrier_health
	var health := player.damage_receiver.health
	var potions := player.potions_remaining
	if not _check(controls.open_run_build() and paused, "실제 도전 상태 조회"): return false
	var abilities := PrototypeRunBuildView.cards(0, controls.run_build_state)
	var card: Dictionary = abilities.filter(func(item: Dictionary) -> bool: return item.id == RESTORATIVE_ID)[0]
	var survival := PrototypeRunBuildView.cards(2, controls.run_build_state)[1]
	if not _check(card.status == "이번 도전 1등급" and survival.lines[2].ends_with("방벽 +15"), "실제 보유 능력·회복약 방벽 보충량 조회"): return false
	_press_potion()
	if not _check(not sandbox._use_recovery_potion(), "조회 중 지연된 회복약 명령 차단"): return false
	if not await _test_layout(): return false
	controls.notification(Control.NOTIFICATION_APPLICATION_PAUSED)
	controls.notification(Control.NOTIFICATION_APPLICATION_RESUMED)
	player.set_physics_process(true)
	await create_timer(0.12, true).timeout
	if not _check(player.damage_receiver.barrier_health == barrier and player.damage_receiver.health == health and player.potions_remaining == potions and _files() == files, "앱 복귀·조회 실제 프레임 동결/저장 무변경"): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(2.9)
	_press_potion()
	if not _check(paused and not sandbox._use_recovery_potion() and player.damage_receiver.barrier_health == barrier and player.potions_remaining == potions, "3초 복귀 중 회복약/방벽 미지급"): return false
	controls.advance_mode_timer_for_test(0.2)
	player.set_physics_process(false)
	return _check(not paused and _files() == files and player.damage_receiver.barrier_health == barrier and player.damage_receiver.health == health and player.potions_remaining == potions, "복귀 원래 체력/방벽/소진 유지")

func _test_boosted_victory() -> bool:
	for target in get_nodes_in_group("targetable"): target.visible = false
	player.global_position = Vector2(1000, 780)
	player.facing_direction = 1
	var target := _collector_target("gp142:sword")
	_sword_hit(target, 10)
	if not _check(player.damage_receiver.health == 25, "비치명 실제 검 타격 회복 없음"): return false
	var amount := growth.victory_recovery_amount()
	_sword_hit(target, 9999)
	if not _check(player.damage_receiver.health == 25 + amount, "실제 검 처치로 3% 회복"): return false
	target.defeated.emit(target)
	if not _check(player.damage_receiver.health == 25 + amount, "중복 처치 신호 추가 회복 없음"): return false
	if not _resolve_growth(): return false
	target.reset_target()
	var before := player.damage_receiver.health
	target.defeated.emit(target)
	if not _check(player.damage_receiver.health == before, "살아 있는 적 위조 처치 거부"): return false
	_defeat(target)
	if not _check(player.damage_receiver.health == before + growth.victory_recovery_amount(), "같은 적 새 생명 실제 처치는 한 번 회복"): return false
	if not _resolve_growth(): return false
	target.visible = false
	target = _collector_target("gp142:bow")
	before = player.damage_receiver.health
	_arrow_hit(target, 9999, "gp142:bow")
	if not _check(player.damage_receiver.health == before + growth.victory_recovery_amount(), "실제 활 투사체 처치 회복"): return false
	if not _resolve_growth(): return false
	target.visible = false
	for kind in ["ordinary", "elite", "boss"]:
		target = _collector_target("gp142:" + kind)
		if kind != "ordinary": target.add_to_group("elite_enemy")
		if kind == "boss": target.add_to_group("boss_enemy")
		player.damage_receiver.health = 25
		amount = growth.victory_recovery_amount()
		_defeat(target)
		if not _check(player.damage_receiver.health == 25 + amount, "일반/정예/보스 동일 비율 회복"): return false
		if not _resolve_growth(): return false
		target.visible = false
	var selected_profile: Dictionary = ultimate.selected_profile.duplicate(true)
	ultimate.selected_profile = PrototypeJobRewards.ultimates_for("vanguard")[0].duplicate(true)
	target = _collector_target("gp142:ultimate")
	target.damage_receiver.health = 1
	player.damage_receiver.health = 25
	amount = growth.victory_recovery_amount()
	ultimate.gauge = 100
	ultimate.request_ultimate()
	if not _check(target.damage_receiver.dead and player.damage_receiver.health == 25 + amount and ultimate._active, "실제 공격형 필살기 처치도 한 번 회복"): return false
	ultimate.finish_stage_effect()
	ultimate.selected_profile = selected_profile
	if not _resolve_growth(): return false
	target.visible = false
	var maximum := player.damage_receiver.max_health
	player.damage_receiver.max_health = 105
	player.damage_receiver.health = 104
	target = _collector_target("gp142:cap")
	if not _check(growth.victory_recovery_amount() == 4, "현재 최대105의3%는4로 올림"): return false
	_defeat(target)
	if not _check(player.damage_receiver.health == 105, "최대 체력 상한·초과 회복 없음"): return false
	player.damage_receiver.max_health = maximum
	if not _resolve_growth(): return false
	target.visible = false
	for mode in ["training", "hidden", "dead", "paused", "build", "editor", "intermission", "inactive"]:
		growth.experience = 0
		target = _collector_target("gp142:guard:" + mode)
		player.damage_receiver.health = 25
		match mode:
			"training": target.remove_from_group("combat_enemy")
			"hidden": target.visible = false
			"dead": player.damage_receiver.dead = true; player.damage_receiver.health = 0
			"paused": paused = true
			"build": controls.open_run_build()
			"editor": controls.open_layout_editor()
			"intermission": runner.stage_complete = true
			"inactive": growth.stop_run()
		before = player.damage_receiver.health
		_defeat(target)
		if not _check(player.damage_receiver.health == before, "회복 자격 차단: " + mode): return false
		match mode:
			"dead": player.damage_receiver.dead = false
			"paused": paused = false
			"build": controls.close_run_build(); controls.advance_mode_timer_for_test(3.1)
			"editor": controls.cancel_layout_editor(); controls.advance_mode_timer_for_test(3.1)
			"intermission": runner.stage_complete = false
		if mode in ["paused", "build", "editor", "intermission"]:
			var resumed_health := player.damage_receiver.health
			target.defeated.emit(target)
			if not _check(player.damage_receiver.health == resumed_health, "잠금 해제 후 신호 재전송·미지급 회복 누적 없음: " + mode): return false
		target.visible = false
	return true

func _test_legacy_effects() -> bool:
	player.damage_receiver.barrier_health = 0
	if not await _start_real_evade(1): return false
	_seed_hit("legacy-base")
	if not _check(player.damage_receiver.barrier_health == 5, "기존 저장 실제 정확 회피5"): return false
	player._update_mobility_timers(1.0)
	player.damage_receiver.health = 1
	player.damage_receiver.barrier_health = 0
	var count := player.potions_remaining
	_press_potion()
	if not _check(player.damage_receiver.barrier_health == 10 and player.potions_remaining == count - 1, "기존 저장 실제 소비10·한 개 감소"): return false
	player.damage_receiver.health = 1
	var amount := growth.victory_recovery_amount()
	var target := _collector_target("legacy-base-kill")
	_defeat(target)
	if not _check(player.damage_receiver.health == 1 + amount, "기존 저장 실제 처치2% 회복"): return false
	if not _resolve_growth(): return false
	target.free()
	return true
