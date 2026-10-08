extends "res://tests/gp141_runtime_test.gd"

const GP146_SAVE := "user://gp146_checkpoint.json"
const GP146_META := "user://gp146_meta.jsonl"
const GP146_RECORD := "user://gp146_records.jsonl"
const GP146_BOOK := "user://gp146_abilities.jsonl"
const EVASIVE_ID := "evasive_barrier"
const SEED_SCENE := preload("res://scenes/combat/enemy_seed_projectile.tscn")
const WAVE_SCENE := preload("res://scenes/combat/elite_shockwave.tscn")

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	store.save_path = GP146_SAVE
	legacy.save_path = GP146_META
	book.save_path = GP146_BOOK
	if phase in ["seed", "legacy-seed", "combat"]:
		store.clear_checkpoint()
		for path in [GP146_META, GP146_RECORD, GP146_BOOK]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.ability_discovery_store = book
	sandbox.get_node("LocalTestRecorder").record_path = GP146_RECORD
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
			if not _test_evasive_gates(false): return
			if not await _choose_earned("magic_barrier"): return
			_barrier_hit("seed7", 7)
			if not await _choose_earned(EVASIVE_ID, true): return
			if not _check(player.damage_receiver.barrier_health == 13 and growth.evasive_barrier_amount() == 5, "실제 선택은13잔량 유지·다음 회피부터5"): return
			if not _test_evasive_gates(true): return
			if not await _test_evasive_view(): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "실제 첫 정예 보상"): return
			player.damage_receiver.health = 17
			player.damage_receiver.barrier_health = 13
			ultimate.gauge = 31
			weapons.sword_combat._skill_1_cooldown_s = 3.25
			weapons.bow_combat._skill_2_cooldown_s = 5.5
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "회피 방벽·잔량·체력·게이지·양 대기 저장"): return
			if not _test_evasive_save(): return
			controls.show_main_screen()
			controls.show_village()
			if not await _test_book_layout(): return
			var cards := PrototypeAbilityCodex.cards(book.snapshot(), growth.ranks)
			var card: Dictionary = cards.filter(func(item: Dictionary) -> bool: return item.id == EVASIVE_ID)[0]
			if not _check(cards.size() == 23 and card.open and card.status == "이번 도전 1등급" and card.lines[2] == "조건: 마력 방벽 획득 후", "23능력 전체 도감·조건/발견/현재 등급"): return
		"resume":
			if not _check(growth.evasive_barrier_amount() == 0 and book.snapshot().has(EVASIVE_ID), "발견만으로 능력 지급 없음"): return
			for ignored in 2:
				controls.show_main_screen()
				if not _check(sandbox.continue_saved_run() and growth.evasive_barrier_amount() == 5 and player.damage_receiver.barrier_health == 13 and player.damage_receiver.health == 17 and ultimate.gauge == 31 and weapons.sword_combat._skill_1_cooldown_s == 3.25 and weapons.bow_combat._skill_2_cooldown_s == 5.5, "별도 프로세스·반복 복원·무료 충전 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			_barrier_hit("restored8", 8)
			if not await _start_real_evade(-1): return
			var before := player.damage_receiver.barrier_health
			_seed_hit("restored")
			if not _check(player.damage_receiver.barrier_health == before + 5, "복원 후 실제 회피5 회복"): return
			player._update_mobility_timers(1.0)
			if not await _test_evasive_view(): return
			while not runner.awaiting_boss_choice():
				if not _finish_stage(): return
				if runner.awaiting_boss_choice(): break
				if not _check(sandbox._claim_weapon_reward(""), "정예 보상에서 능력 유지"): return
				_tap(controls.stage_route_rects[0].get_center())
			if not _check(store.load_checkpoint().growth.ranks[EVASIVE_ID] == 1 and runner.stage_number == 5, "5스테이지 최종 저장"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and sandbox._resolve_boss_choice("rescue"), "보스 선택 복원·완주"): return
			controls.begin_retry("bow", 3)
			if not _check(growth.evasive_barrier_amount() == 0 and not player.barrier_unlocked and growth.ranks.is_empty() and book.snapshot().has(EVASIVE_ID), "새 도전 초기화·발견 유지"): return
		"legacy-seed":
			controls.begin_retry("bow", 3)
			if not await _choose_earned("magic_barrier"): return
			_barrier_hit("legacy7", 7)
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 기본 방벽 저장 준비"): return
			if not _check(not store.load_checkpoint().growth.ranks.has(EVASIVE_ID), "기존 저장에 새 능력 없음"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and player.damage_receiver.barrier_health == 13 and growth.evasive_barrier_amount() == 0, "이전 저장·능력 소급 지급 없음"): return
			_tap(controls.stage_route_rects[0].get_center())
			_barrier_hit("legacy8", 8)
			if not await _start_real_evade(1): return
			var before := player.damage_receiver.barrier_health
			_seed_hit("legacy")
			if not _check(player.damage_receiver.barrier_health == before, "미획득 실제 회피는 충전 없음"): return
			player._update_mobility_timers(1.0)
			while not runner.awaiting_boss_choice():
				if not _finish_stage(): return
				if runner.awaiting_boss_choice(): break
				if not _check(sandbox._claim_weapon_reward(""), "이전 저장 정예"): return
				_tap(controls.stage_route_rects[0].get_center())
			if not _check(sandbox._resolve_boss_choice("destroy"), "이전3스테이지 완주"): return
		"combat":
			controls.begin_retry()
			if not await _choose_earned("magic_barrier") or not await _choose_earned(EVASIVE_ID): return
			if not await _test_evasive_combat(): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-146 runtime test: OK (" + phase + ")")
	quit(0)

func _choose_earned(id: String, failure: bool = false) -> bool:
	var seed_value := -1
	for candidate in 512:
		growth.rng.seed = candidate
		for card in growth._draw_cards():
			if card.id == id: seed_value = candidate
		if seed_value >= 0: break
	if not _check(seed_value >= 0, "원본 후보 풀에서 다음 능력 발견: " + id): return false
	growth.rng.seed = seed_value
	for ignored in 12:
		if growth.choosing: break
		match runner.current_section:
			PrototypeStageRunner.Section.ADVANCE_ONE: player.global_position.x = 1240
			PrototypeStageRunner.Section.ADVANCE_TWO: player.global_position.x = 3840
			PrototypeStageRunner.Section.WAVE_ONE, PrototypeStageRunner.Section.WAVE_TWO:
				for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
			PrototypeStageRunner.Section.ELITE: _defeat(runner.final_enemy())
		if not growth.choosing: runner._process(0.1)
	var index := -1
	for i in growth.offered_cards.size():
		if growth.offered_cards[i].id == id: index = i
	if not _check(index >= 0 and growth.choosing and paused, "실제 처치 레벨업·자연 후보 UI: " + id): return false
	var before := growth.checkpoint_snapshot()
	var equipment := weapons.checkpoint_snapshot()
	var health := player.damage_receiver.health
	var potions := player.potions_remaining
	var bonus := _bonus()
	var barrier := player.damage_receiver.barrier_health
	var gauge := ultimate.gauge
	if failure:
		for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
			controls.size = dimensions
			controls._refresh_growth_layout()
			var rect: Rect2 = controls.growth_card_rects[index]
			if not _check(controls.layout_snapshot().safe.encloses(rect), "직업 강화 카드 두 화면비 안전 영역"): return false
			for line in growth.offered_cards[index].lines:
				if not _check(ThemeDB.fallback_font.get_string_size(String(line), HORIZONTAL_ALIGNMENT_LEFT, -1, mini(26, int(rect.size.x / 12.0)) - 3).x <= rect.size.x - 24, "강화 설명 글자 너비"): return false
			controls.queue_redraw()
			await process_frame
		book.save_path = "user://gp146_missing/abilities.jsonl"
		_tap(controls.growth_card_rects[index].get_center())
		if not _check(paused and growth.choosing and growth.checkpoint_snapshot() == before and _bonus() == bonus and not book.snapshot().has(id), "영구 발견 저장 실패·등급/성향/효과 미적용"): return false
		book.save_path = GP146_BOOK
	_tap(controls.growth_card_rects[index].get_center())
	if failure and not _check(is_equal_approx(_bonus(), bonus) and player.damage_receiver.barrier_health == barrier and player.damage_receiver.health == health and player.potions_remaining == potions and weapons.checkpoint_snapshot() == equipment and ultimate.gauge == gauge, "같은 카드 재시도·방벽 선택 자체는 즉시 회복 없음·회복/대기/게이지 보존"): return false
	if growth.awaiting_job_confirmation:
		_tap(controls.job_ultimate_rects[0].get_center())
		_tap(controls.job_confirm_rect.get_center())
	return _check(not paused and not growth.choosing and growth.ranks.has(id) and book.snapshot().has(id), "실제 카드 터치·영구 발견·재개")

func _files() -> Dictionary:
	var result := {}
	for path in [GP146_SAVE, GP146_SAVE + ".bak", GP146_META, GP146_RECORD, GP146_BOOK]:
		result[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return result

func _test_evasive_gates(owned: bool) -> bool:
	for ignored in 100:
		if not _check(not growth._draw_cards().any(func(card: Dictionary) -> bool: return card.id == EVASIVE_ID), "선행 없음/최대1등급 후보 차단"): return false
	var before := growth.checkpoint_snapshot()
	var barrier := player.damage_receiver.barrier_health
	if not _reject_card(EVASIVE_ID): return false
	return _check(before == growth.checkpoint_snapshot() and barrier == player.damage_receiver.barrier_health and growth.evasive_barrier_amount() == (5 if owned else 0), "선행/중복 확정 거부·등급/성향/잔량 무변경")

func _test_evasive_save() -> bool:
	var saved := store.load_checkpoint()
	for invalid in [null, true, "1", 0, 2, 0.5]:
		var bad := saved.duplicate(true)
		bad.growth.ranks[EVASIVE_ID] = invalid
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "등급 변조·정상 저장 보호"): return false
	var bad := saved.duplicate(true)
	bad.growth.ranks.erase("magic_barrier")
	bad.growth.ranks.vitality = int(bad.growth.ranks.get("vitality", 0)) + 1
	bad.player.max_health += 20
	bad.player.barrier_health = 0
	return _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "선행 없는 회피 방벽 저장 거부")

func _start_real_evade(direction: int) -> bool:
	player.prepare_next_stage(Vector2(960, 780))
	player.damage_receiver.tick(2.0)
	player.set_physics_process(true)
	for ignored in 8: await physics_frame
	player.set_physics_process(false)
	player._evade_cooldown_remaining_s = 0.0
	player.set_move_vector(Vector2(direction, 0))
	var touch := InputEventScreenTouch.new()
	touch.index = 6
	touch.position = controls.action_rects[&"evade"].get_center()
	touch.pressed = true
	controls._input(touch)
	controls._physics_process(0.001)
	controls._handle_touch_released(6)
	return _check(player.is_on_floor() and player.is_ground_evading() and player.facing_direction == direction and is_equal_approx(player._invincible_remaining_s, 0.18) and is_equal_approx(player._mobility_remaining_s, 0.24), "실제 바닥·양방향 모바일 회피·원본 무적/동작 유지")

func _seed_hit(id: String) -> void:
	var projectile := SEED_SCENE.instantiate() as EnemySeedProjectile
	projectile.configure("gp146:" + id, Vector2.LEFT, 7)
	sandbox.add_child(projectile)
	projectile.set_physics_process(false)
	var point := player.global_position + Vector2(0, -42)
	projectile._try_hit_player(point + Vector2(80, 0), point - Vector2(80, 0))
	projectile.free()

func _wave_hit(id: String) -> void:
	var wave := WAVE_SCENE.instantiate() as EliteShockwave
	wave.configure("gp146:" + id, -1, 12)
	sandbox.add_child(wave)
	wave.set_physics_process(false)
	var point := player.global_position + Vector2(0, -20)
	wave._try_hit_player(point + Vector2(80, 0), point - Vector2(80, 0))
	wave.free()

func _test_evasive_combat() -> bool:
	for direction in [1, -1]:
		player.damage_receiver.barrier_health = 0
		ultimate.gauge = 0
		var health := player.damage_receiver.health
		if not await _start_real_evade(direction): return false
		if not _check(player.damage_receiver.barrier_health == 0, "회피 입력만으로 회복 없음"): return false
		_seed_hit("first:%d" % direction)
		if not _check(player.damage_receiver.barrier_health == 5 and player.damage_receiver.health == health and ultimate.gauge == 12, "실제 씨앗 정확 회피·방벽5·원본 게이지12"): return false
		_seed_hit("first:%d" % direction)
		_wave_hit("second:%d" % direction)
		ultimate.precise_evade_registered.emit()
		if not _check(player.damage_receiver.barrier_health == 5 and ultimate.gauge == 24 and player.damage_receiver.health == health, "중복 타격/충격파/중복 신호는 같은 회피5 상한·기존 게이지 유지"): return false
		player._update_mobility_timers(0.19)
		_seed_hit("exposed:%d" % direction)
		if not _check(not player.invincible and player.damage_receiver.barrier_health == 0 and player.damage_receiver.health == health - 2, "무적 연장 없이0.19초 실제7·방벽5흡수/체력2"): return false
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
	if not _check(player.damage_receiver.barrier_health == 5, "일반 적 실제 근접 공격 정확 회피5"): return false
	player._update_mobility_timers(1.0)
	if not await _test_evasive_view(): return false
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
	if not _check(player.damage_receiver.barrier_health == 5 and scored != contributions and growth.jobs.contributions == scored, "기존 직업 회피 성향1회와 방벽5 독립 적용"): return false
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

func _test_evasive_view() -> bool:
	var files := _files()
	if not await _start_real_evade(1): return false
	var barrier := player.damage_receiver.barrier_health
	var remaining := player._invincible_remaining_s
	if not _check(controls.open_run_build() and paused, "실제 회피 중 도전 상태 조회"): return false
	var abilities := PrototypeRunBuildView.cards(0, controls.run_build_state)
	var card: Dictionary = abilities.filter(func(item: Dictionary) -> bool: return item.id == EVASIVE_ID)[0]
	var health := PrototypeRunBuildView.cards(2, controls.run_build_state)[1]
	if not _check(card.status == "이번 도전 1등급" and health.lines[0].ends_with("정확 회피 +5"), "실제 보유 능력·방벽/회복량 조회"): return false
	ultimate.precise_evade_registered.emit()
	if not _check(player.damage_receiver.barrier_health == barrier, "조회 중 지연 신호는 방벽 미지급"): return false
	if not await _test_layout(): return false
	controls.notification(Control.NOTIFICATION_APPLICATION_PAUSED)
	controls.notification(Control.NOTIFICATION_APPLICATION_RESUMED)
	player.set_physics_process(true)
	await create_timer(0.12, true).timeout
	if not _check(player.damage_receiver.barrier_health == barrier and player._invincible_remaining_s == remaining and _files() == files, "앱 복귀·조회 실제 프레임 동결/저장 무변경"): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(2.9)
	ultimate.precise_evade_registered.emit()
	if not _check(paused and player.damage_receiver.barrier_health == barrier, "3초 복귀 중 신호 미지급"): return false
	controls.advance_mode_timer_for_test(0.2)
	player.set_physics_process(false)
	if not _check(not paused and _files() == files and player._invincible_remaining_s == remaining, "복귀 원래 잔량 유지"): return false
	player._update_mobility_timers(1.0)
	return true

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-146 failed: " + message)
		paused = false
		quit(1)
	return condition
