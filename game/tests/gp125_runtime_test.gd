extends "res://tests/gp124_runtime_test.gd"

const GP125_SAVE := "user://gp125_checkpoint.json"
const GP125_META := "user://gp125_meta.jsonl"
const GP125_RECORD := "user://gp125_records.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP125_SAVE
	legacy.save_path = GP125_META
	if phase == "seed":
		store.clear_checkpoint()
		for path in [GP125_META, GP125_RECORD]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP125_RECORD
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
	for controller in [weapons.sword_combat, weapons.bow_combat]:
		controller.set_process(false)
		controller.set_physics_process(false)
	player.set_physics_process(false)
	runner.set_process(false)
	match phase:
		"seed":
			controls.begin_retry()
			for ignored in 64:
				for card in growth._draw_cards():
					if not _check(card.id not in ["lifesteal_depth", "lifesteal_crisis"], "흡수 없는 도전에는 강화 후보 없음"): return
			if not _reject_card("lifesteal_depth") or not _reject_card("lifesteal_crisis"): return
			if not await _choose_lifesteal(): return
			var target := _absorb_target("seed", Vector2(1450, 780))
			player.damage_receiver.health = 50
			_sword_hit(target, 7)
			if not await _choose_branch("lifesteal_depth"): return
			if not _check(player.lifesteal_branch == "lifesteal_depth" and player.lifesteal_progress == 7 and player.damage_receiver.health == 50 and player.damage_receiver.max_health == 100 and player.growth_common_bonus == 0 and player.growth_sword_bonus == 0, "강화 선택은 기존 소수·체력·피해 보존"): return
			_sword_hit(target, 7)
			if not _check(player.damage_receiver.health == 51 and player.lifesteal_progress == 1 and controls.movement_metrics.lifesteal_rate_percent == 10, "기존 7/20 + 강화 14/20 = 체력 1·나머지 1·HUD 10%"): return
			if not _test_exclusive_candidates(): return
			target.visible = false
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "깊은 흡수 첫 통과 저장"): return
			var saved := store.load_checkpoint()
			if not _check(saved.growth.ranks.lifesteal_depth == 1 and saved.player.lifesteal_progress == 1 and RunCheckpointStore.valid_state(saved), "강화·소수 기존 스키마 저장"): return
			var missing := saved.duplicate(true)
			missing.growth.ranks.erase("lifesteal")
			missing.growth.ranks.sword_power = 1
			missing.player.sword += 0.15
			missing.player.lifesteal_progress = 0
			if not _check(not RunCheckpointStore.valid_state(missing), "등급 총합을 맞춘 선행 능력 없는 강화 거부"): return
			for id in ["lifesteal_crisis", "lifesteal_depth"]:
				var bad := saved.duplicate(true)
				bad.growth.ranks[id] = int(bad.growth.ranks.get(id, 0)) + 1
				bad.growth.total_xp += 20 + (int(bad.growth.level) - 1) * 5
				bad.growth.level += 1
				if not _check(not RunCheckpointStore.valid_state(bad) and store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "양쪽 강화·2등급 변조 거부·정상 저장 보호"): return
		"resume":
			if not _check(sandbox.continue_saved_run() and player.lifesteal_branch == "lifesteal_depth" and player.lifesteal_progress == 1, "별도 프로세스 깊은 흡수·소수 복원"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _check(player.lifesteal_multiplier() == 2 and player.lifesteal_progress == 1, "경로 이동 강화·소수 유지"): return
			var target := _absorb_target("resume", player.global_position + Vector2(280, 0))
			player.damage_receiver.health = 50
			_arrow_hit(target, 10, "gp125-depth-arrow")
			if not _check(player.damage_receiver.health == 51 and player.lifesteal_progress == 1, "강화된 실제 화살 10 피해 = 1 회복"): return
			target.visible = false
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "강화 연속 스테이지 저장"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("rescue"), "강화 도전 실제 보스 완주"): return
			controls.begin_retry()
			if not _check(not player.lifesteal_unlocked and player.lifesteal_branch.is_empty() and player.lifesteal_progress == 0, "새 도전 강화·기본 능력·소수 초기화"): return
		"crisis":
			controls.begin_retry()
			if not await _choose_lifesteal() or not await _choose_branch("lifesteal_crisis"): return
			if not _test_exclusive_candidates() or not _test_crisis_threshold(): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "위기의 흡수 저장"): return
		"restore":
			if not _check(sandbox.continue_saved_run() and player.lifesteal_branch == "lifesteal_crisis" and player.lifesteal_progress == 9, "별도 프로세스 위기 강화·소수 복원"): return
			_tap(controls.stage_route_rects[1].get_center())
			player.damage_receiver.health = 30
			var target := _absorb_target("restore", player.global_position + Vector2(280, 0))
			_arrow_hit(target, 7, "gp125-crisis-restored-arrow")
			if not _check(player.damage_receiver.health == 31 and player.lifesteal_progress == 10 and player.lifesteal_branch == "lifesteal_crisis", "복원 뒤 경로 이동·실제 화살 위기 배율 유지"): return
			target.visible = false
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "위기 강화 두 번째 통과 저장"): return
			var old := store.load_checkpoint()
			old.growth.ranks.erase("lifesteal_crisis")
			old.growth.ranks.sword_power = int(old.growth.ranks.get("sword_power", 0)) + 1
			old.player.sword += 0.15
			if not _check(store.save_checkpoint(old) == OK, "GP-124 기본 흡수·소수 형식 준비"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and player.lifesteal_unlocked and player.lifesteal_branch.is_empty() and player.lifesteal_progress == 10, "이전 기본 흡수 저장은 5%·소수 10 복원"): return
			_tap(controls.stage_route_rects[0].get_center())
			var target := _absorb_target("legacy", player.global_position + Vector2(250, 0))
			player.damage_receiver.health = 50
			_damage_event(target, 10)
			if not _check(player.damage_receiver.health == 51 and player.lifesteal_progress == 0 and player.lifesteal_multiplier() == 1, "이전 소수 10 + 기본 피해 10 = 정확히 1 회복"): return
			target.visible = false
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("destroy"), "이전 기본 흡수 도전 보스 완주"): return
		"combat":
			controls.begin_retry()
			if not await _choose_lifesteal() or not await _choose_branch("lifesteal_crisis"): return
			if not _test_crisis_skills(): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-125 runtime test: OK (" + phase + ")")
	quit(0)

func _choose_branch(id: String) -> bool:
	var chosen_seed := -1
	for candidate in 256:
		growth.rng.seed = candidate
		for card in growth._draw_cards():
			if card.id == id: chosen_seed = candidate
		if chosen_seed >= 0: break
	if not _check(chosen_seed >= 0, "실제 선행 능력 뒤 강화 후보 등장"): return false
	growth.rng.seed = chosen_seed
	for ignored in 10:
		match runner.current_section:
			PrototypeStageRunner.Section.ADVANCE_TWO: player.global_position.x = 3840
			PrototypeStageRunner.Section.WAVE_ONE, PrototypeStageRunner.Section.WAVE_TWO:
				for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
			PrototypeStageRunner.Section.ELITE: _defeat(runner.final_enemy())
		if growth.choosing: break
		runner._process(0.1)
	if not _check(growth.choosing and paused and growth.level == 3, "실제 두 번째 웨이브·정예 처치로 강화 레벨업"): return false
	var index := -1
	for i in growth.offered_cards.size():
		if growth.offered_cards[i].id == id: index = i
	if not _check(index >= 0, "실제 제안된 강화 카드"): return false
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_growth_layout()
		var safe: Rect2 = controls.layout_snapshot().safe
		for rect in controls.growth_card_rects:
			if not _check(safe.encloses(rect) and not rect.intersects(controls.growth_reroll_rect), "두 화면비 강화 카드 안전 영역"): return false
		controls.queue_redraw()
		await process_frame
	_tap(controls.growth_card_rects[index].get_center())
	return _check(not paused and not growth.choosing and growth.ranks.get(id) == 1, "실제 강화 카드 터치·전투 재개")

func _reject_card(id: String) -> bool:
	growth.choosing = true
	for card in PrototypeGrowthController.CARDS:
		if card.id == id: growth.offered_cards = [card.duplicate(true)]
	var rejected := not growth.choose_card(0)
	growth.choosing = false
	growth.offered_cards.clear()
	return _check(rejected, "선행 조건·배타적 강화·중복 카드 오래된 선택 거부")

func _test_exclusive_candidates() -> bool:
	for ignored in 100:
		for card in growth._draw_cards():
			if not _check(card.id not in ["lifesteal", "lifesteal_depth", "lifesteal_crisis"], "강화 선택 뒤 기본·양쪽 가지 모두 제외"): return false
	if not _reject_card("lifesteal_depth") or not _reject_card("lifesteal_crisis"): return false
	var rerolls := growth.rerolls_remaining
	growth.choosing = true
	growth.offered_cards = growth._draw_cards()
	growth.rerolls_remaining = 1
	if not _check(growth.reroll(), "실제 재추첨"): return false
	for card in growth.offered_cards:
		if not _check(card.id not in ["lifesteal", "lifesteal_depth", "lifesteal_crisis"], "재추첨도 배타적 강화 제외"): return false
	growth.choosing = false
	growth.offered_cards.clear()
	growth.rerolls_remaining = rerolls
	sandbox._finish_growth_selection()
	return true

func _damage_event(target: PrototypeTarget, damage: int) -> int:
	var event := DamageEvent.new()
	event.event_id = StringName("gp125:%d:%d" % [target.get_instance_id(), target.damage_receiver.applied_count])
	event.attacker_id = &"player"
	event.damage = damage
	event.tags = PackedStringArray(["sword", "basic"])
	return player.deal_weapon_damage(target, event)

func _test_crisis_threshold() -> bool:
	var target := _absorb_target("threshold", Vector2(1450, 780))
	player.damage_receiver.health = 30
	player.lifesteal_progress = 0
	_sword_hit(target, 1)
	_sword_hit(target, 6)
	if not _check(player.damage_receiver.health == 31 and player.lifesteal_progress == 1 and controls.movement_metrics.lifesteal_rate_percent == 5, "30%에서 두 타격 15%·문턱 넘으면 HUD 즉시 5%"): return false
	_sword_hit(target, 20)
	if not _check(player.damage_receiver.health == 32 and player.lifesteal_progress == 1, "문턱 위 다음 타격은 5%·소수 유지"): return false
	for maximum in [100, 135, 140]:
		player.damage_receiver.max_health = maximum
		var boundary: int = maximum * 3 / 10
		player.damage_receiver.health = boundary
		if not _check(player.lifesteal_multiplier() == 3, "최대 체력 성장에도 30% 이하 판정"): return false
		player.damage_receiver.health = boundary + 1
		if not _check(player.lifesteal_multiplier() == 1, "정수 문턱 바로 위는 기본 흡수"): return false
	player.damage_receiver.max_health = 100
	player.damage_receiver.health = 20
	var potions := player.potions_remaining
	if not _check(player.use_recovery_potion() and player.damage_receiver.health == 45 and player.potions_remaining == potions - 1, "강화는 기존 25% 회복약의 효과를 바꾸지 않음"): return false
	player.damage_receiver.health = 30
	player.lifesteal_progress = 0
	_sword_hit(target, 3)
	if not _check(player.damage_receiver.health == 30 and player.lifesteal_progress == 9, "위기 소수 9 누적"): return false
	player.damage_receiver.health = 50
	target.visible = false
	return true

func _test_crisis_skills() -> bool:
	for node in get_nodes_in_group("targetable"): node.visible = false
	player.global_position = Vector2(1000, 780)
	player.facing_direction = 1
	player.damage_receiver.health = 30
	player.lifesteal_progress = 0
	var target := _absorb_target("rain", Vector2(1360, 780))
	weapons.active_weapon_id = "bow"
	weapons._apply_active_weapon()
	weapons.target_selector.current_target = target
	var bow := weapons.bow_combat
	bow._skill_2_cooldown_s = 0
	_press_skill(1)
	bow._update_skill_action(1.09)
	if not _check(target.damage_receiver.health == 952 and player.damage_receiver.health == 33 and player.lifesteal_progress == 4, "실제 화살비: 첫 타격만 위기 배율·후속 5%·소수 공유"): return false
	bow._finish_action("검사")
	target.visible = false
	player.damage_receiver.health = 30
	player.lifesteal_progress = 0
	var targets: Array[PrototypeTarget] = []
	for i in 3: targets.append(_absorb_target("piercing%d" % i, Vector2(1200 + i * 160, 780)))
	bow._skill_1_cooldown_s = 0
	_press_skill(0)
	bow._update_skill_action(0.13)
	var shots := get_nodes_in_group("bow_projectile")
	if not _check(shots.size() == 1, "실제 모바일 관통 화살 시전"): return false
	var shot: BowProjectile = shots[0]
	shot.set_physics_process(false)
	shot._check_hits(shot.global_position, Vector2(1600, 742))
	shot._check_hits(shot.global_position, Vector2(1600, 742))
	if not _check(shot._hit_count == 3 and player.damage_receiver.health == 39 and player.lifesteal_progress == 0, "관통 세 대상은 각각 타격 시 체력 판정·중복 회복 없음"): return false
	for victim in targets:
		if not _check(victim.damage_receiver.health == 964, "각 대상 실제 관통 36 피해"): return false
		victim.visible = false
	shot.free()
	bow._finish_action("검사")
	weapons.set_skill_loadout({"sword": ["sword_line", "sword_spin"], "bow": ["bow_piercing", "bow_arrow_rain"]})
	weapons.active_weapon_id = "sword"
	weapons._apply_active_weapon()
	player.damage_receiver.health = 30
	player.lifesteal_progress = 0
	target = _absorb_target("line", Vector2(1360, 780))
	weapons.sword_combat._skill_1_cooldown_s = 0
	_press_skill(0)
	weapons.sword_combat._update_skill_action(0.46)
	if not _check(target.damage_receiver.health == 940 and player.damage_receiver.health == 39 and player.lifesteal_progress == 0, "일섬 한 타격은 공격 시점 15% 전체 적용"): return false
	weapons.sword_combat._finish_action("검사")
	player.damage_receiver.health = 100
	_sword_hit(target, 100)
	if not _check(player.damage_receiver.health == 100 and player.lifesteal_progress == 0, "강화도 최대 체력 적립 없음"): return false
	player.damage_receiver.dead = true
	player.damage_receiver.health = 0
	_sword_hit(target, 100)
	return _check(player.damage_receiver.health == 0 and player.lifesteal_progress == 0, "위기 15%도 사망 플레이어 부활 없음")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-125 failed: " + message)
		paused = false
		quit(1)
	return condition
