extends "res://tests/gp121_runtime_test.gd"

const GP124_SAVE := "user://gp124_checkpoint.json"
const GP124_META := "user://gp124_meta.jsonl"
const GP124_RECORD := "user://gp124_records.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP124_SAVE
	legacy.save_path = GP124_META
	if phase == "seed":
		store.clear_checkpoint()
		for path in [GP124_META, GP124_RECORD]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP124_RECORD
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
			if not _check(not player.lifesteal_unlocked and player.lifesteal_progress == 0, "새 도전 흡수 없음"): return
			if not await _choose_lifesteal(): return
			if not _check(player.lifesteal_unlocked and growth.ranks.lifesteal == 1 and player.damage_receiver.max_health == 100 and player.growth_common_bonus == 0 and player.growth_sword_bonus == 0, "실제 카드 선택은 흡수만 해금"): return
			var target := _absorb_target("seed", Vector2(1450, 780))
			player.damage_receiver.health = 50
			var potions := player.potions_remaining
			var xp := growth.total_experience
			weapons.sword_combat._skill_1_cooldown_s = 3.25
			weapons.bow_combat._skill_2_cooldown_s = 4.75
			_sword_hit(target, 9)
			if not _check(player.damage_receiver.health == 50 and player.lifesteal_progress == 9, "작은 피해는 반올림하지 않고 누적"): return
			_sword_hit(target, 11)
			_sword_hit(target, 26)
			if not _check(player.damage_receiver.health == 52 and player.lifesteal_progress == 6 and player._lifesteal_flash_remaining_s > 0 and potions == player.potions_remaining and xp == growth.total_experience and weapons.sword_combat._skill_1_cooldown_s == 3.25 and weapons.bow_combat._skill_2_cooldown_s == 4.75, "실제 검 피해 46의 5%·소수·파동·약과 대기시간 유지"): return
			target.visible = false
			for ignored in 100:
				for card in growth._draw_cards():
					if not _check(card.id != "lifesteal", "소유 흡수는 모든 후보에서 제외"): return
			growth.choosing = true
			for card in PrototypeGrowthController.CARDS:
				if card.id == "lifesteal": growth.offered_cards = [card.duplicate(true)]
			if not _check(not growth.choose_card(0), "오래된 화면 중복 선택 차단"): return
			growth.choosing = false
			growth.offered_cards.clear()
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "첫 통과 저장"): return
			var saved := store.load_checkpoint()
			if not _check(saved.player.lifesteal_progress == 6 and saved.growth.ranks.lifesteal == 1, "능력·소수 저장"): return
			for invalid in [null, true, "7", [], {}, -1, 20, 0.5]:
				var bad := saved.duplicate(true)
				bad.player.lifesteal_progress = invalid
				if not _check(not RunCheckpointStore.valid_state(bad) and store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved, "변조 누적량 거부·정상 저장 보호"): return
			var capped := saved.duplicate(true)
			capped.growth.ranks.lifesteal = 2
			capped.growth.ranks.sword_power -= 1
			capped.player.sword -= 0.15
			if not _check(not RunCheckpointStore.valid_state(capped), "등급 총합을 맞춘 흡수 2등급 거부"): return
		"resume":
			if not _check(sandbox.continue_saved_run() and player.lifesteal_unlocked and player.lifesteal_progress == 6, "별도 프로세스 이어하기 능력·소수 복원"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _check(player.lifesteal_unlocked and player.lifesteal_progress == 6 and runner.stage_number == 2, "경로 이동 누적량 유지"): return
			var target := _absorb_target("resume", player.global_position + Vector2(280, 0))
			player.damage_receiver.health = 50
			_arrow_hit(target, 14, "resume14")
			_arrow_hit(target, 7, "resume7")
			if not _check(player.damage_receiver.health == 51 and player.lifesteal_progress == 7, "실제 화살 충돌·검 소수와 공유·중복 적중 차단"): return
			target.visible = false
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward("") and store.load_checkpoint().player.lifesteal_progress == 7, "두 번째 통과 소수 저장"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and player.lifesteal_unlocked and player.lifesteal_progress == 7, "연속 저장 복원"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("rescue"), "흡수 능력 실제 보스 완주"): return
			controls.begin_retry()
			if not _check(not player.lifesteal_unlocked and player.lifesteal_progress == 0, "새 도전 능력·소수 초기화"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 저장 준비"): return
			var old := store.load_checkpoint()
			old.player.erase("lifesteal_progress")
			if not _check(not old.growth.ranks.has("lifesteal") and store.save_checkpoint(old) == OK, "GP-123 이전 필드 없는 저장 호환"): return
		"legacy":
			if not _check(sandbox.continue_saved_run() and not player.lifesteal_unlocked and player.lifesteal_progress == 0, "이전 저장은 흡수 미해금"): return
			_tap(controls.stage_route_rects[0].get_center())
			var target := _absorb_target("legacy", player.global_position + Vector2(250, 0))
			player.damage_receiver.health = 50
			_sword_hit(target, 100)
			if not _check(player.damage_receiver.health == 50 and player.lifesteal_progress == 0, "미해금 검은 회복 없음"): return
			target.visible = false
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 저장 두 번째 통과"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("destroy"), "이전 저장 보스 완주"): return
		"combat":
			controls.begin_retry()
			if not await _choose_lifesteal(): return
			if not _test_absorption_combat(): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-124 runtime test: OK (" + phase + ")")
	quit(0)

func _choose_lifesteal() -> bool:
	var chosen_seed := -1
	for candidate in 128:
		growth.rng.seed = candidate
		for card in growth._draw_cards():
			if card.id == "lifesteal": chosen_seed = candidate
		if chosen_seed >= 0: break
	if not _check(chosen_seed >= 0, "공용 흡수 카드 등장"): return false
	growth.rng.seed = chosen_seed
	player.global_position.x = 1240
	runner._process(0.1)
	for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
	if not _check(growth.choosing and paused and growth.level == 2, "실제 처치로 첫 레벨업"): return false
	var index := -1
	for i in growth.offered_cards.size():
		if growth.offered_cards[i].id == "lifesteal": index = i
	if not _check(index >= 0, "실제 제안 흡수 카드"): return false
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_growth_layout()
		var safe: Rect2 = controls.layout_snapshot().safe
		for rect in controls.growth_card_rects:
			if not _check(safe.encloses(rect) and not rect.intersects(controls.growth_reroll_rect), "두 화면비 성장 카드 안전 영역"): return false
		controls.queue_redraw()
		await process_frame
	_tap(controls.growth_card_rects[index].get_center())
	return _check(not paused and not growth.choosing, "카드 터치 후 전투 재개")

func _absorb_target(key: String, point: Vector2) -> PrototypeTarget:
	var target := _combat_target(key, point)
	target.add_to_group("combat_enemy")
	target.damage_receiver.post_hit_invulnerability_s = 0.0
	return target

func _sword_hit(target: PrototypeTarget, damage: int) -> int:
	weapons.sword_combat._action_sequence += 1
	return weapons.sword_combat._damage_target(target, &"sword_basic", damage, 0, PackedStringArray(["sword", "basic"]), 0)

func _arrow_hit(target: PrototypeTarget, damage: int, id: String) -> void:
	weapons.bow_combat._spawn_projectile(id, &"bow_basic", damage, 1, Vector2.RIGHT, PackedStringArray(["bow", "basic"]))
	var shots := get_nodes_in_group("bow_projectile")
	var shot: BowProjectile = shots.back()
	shot.set_physics_process(false)
	var point := target.global_position + Vector2(0, -38)
	shot._check_hits(shot.global_position, point)
	shot._check_hits(shot.global_position, point)
	shot.free()

func _test_absorption_combat() -> bool:
	for target in get_nodes_in_group("targetable"): target.visible = false
	player.global_position = Vector2(1000, 780)
	player.facing_direction = 1
	player.damage_receiver.health = 50
	player.lifesteal_progress = 0
	var target := _absorb_target("overkill", Vector2(1300, 780))
	target.damage_receiver.health = 3
	_sword_hit(target, 200)
	if not _check(player.damage_receiver.health == 50 and player.lifesteal_progress == 3, "과잉 피해는 실제 체력 3만 누적"): return false
	var duplicate := weapons.sword_combat._damage_target(target, &"sword_basic", 200, 0, PackedStringArray(["sword", "basic"]), 0)
	if not _check(duplicate == DamageReceiver.Result.DUPLICATE_BLOCKED and _sword_hit(target, 20) == DamageReceiver.Result.DEAD_BLOCKED and player.lifesteal_progress == 3, "동일 타격·사망 대상 추가 회복 없음"): return false
	target = _absorb_target("blocked", Vector2(1350, 780))
	target.damage_receiver._post_hit_remaining_s = 1
	if not _check(_sword_hit(target, 20) == DamageReceiver.Result.INVULNERABLE_BLOCKED and player.lifesteal_progress == 3, "무적 대상 피해 차단 시 회복 없음"): return false
	target.damage_receiver.tick(2)
	target.remove_from_group("combat_enemy")
	_sword_hit(target, 20)
	if not _check(player.lifesteal_progress == 3, "훈련 대상 회복 제외"): return false
	target.add_to_group("combat_enemy")
	paused = true
	_sword_hit(target, 20)
	paused = false
	if not _check(player.lifesteal_progress == 3, "성장·일시정지 중 회복 제외"): return false
	player.damage_receiver.dead = true
	player.damage_receiver.health = 0
	_sword_hit(target, 20)
	if not _check(player.damage_receiver.health == 0 and player.lifesteal_progress == 3, "사망 후 잔류 공격은 부활 없음"): return false
	player.damage_receiver.revive_with_health(50, 0)
	target.visible = false
	var boar := runner.armored_boar
	boar.reset_target()
	boar.visible = true
	boar.set_process(false)
	player.lifesteal_progress = 0
	var before := boar.damage_receiver.health
	_sword_hit(boar, 40)
	var actual := before - boar.damage_receiver.health
	if not _check(actual < 40 and player.damage_receiver.health == 50 + actual / 20 and player.lifesteal_progress == actual % 20, "정예 갑옷으로 감소한 실제 피해만 회복"): return false
	boar.visible = false
	player.damage_receiver.health = 50
	# 실제 모바일 슬롯 시전으로 검 일섬과 활 화살비의 공통 피해 경로를 검사한다.
	player.lifesteal_progress = 0
	weapons.set_skill_loadout({"sword": ["sword_line", "sword_spin"], "bow": ["bow_piercing", "bow_arrow_rain"]})
	var sword := weapons.sword_combat
	var bow := weapons.bow_combat
	target = _absorb_target("skills", Vector2(1360, 780))
	sword._skill_1_cooldown_s = 0
	_press_skill(0)
	sword._update_skill_action(0.46)
	if not _check(target.damage_receiver.health == 940 and player.damage_receiver.health == 53 and player.lifesteal_progress == 0, "실제 일섬 60 피해는 3 회복"): return false
	sword._finish_action("검사")
	weapons.active_weapon_id = "bow"
	weapons._apply_active_weapon()
	weapons.target_selector.current_target = target
	bow._skill_2_cooldown_s = 0
	_press_skill(1)
	bow._update_skill_action(1.09)
	if not _check(target.damage_receiver.health == 892 and player.damage_receiver.health == 55 and player.lifesteal_progress == 8, "실제 화살비 8 피해 여섯 번은 2 회복·8 누적"): return false
	bow._finish_action("검사")
	player.damage_receiver.health = 100
	_sword_hit(target, 20)
	if not _check(player.damage_receiver.health == 100 and player.lifesteal_progress == 8, "최대 체력에서는 추가 회복량 적립 없음"): return false
	player.damage_receiver.health = 99
	_sword_hit(target, 100)
	if not _check(player.damage_receiver.health == 100 and player.lifesteal_progress == 8, "회복 최대 체력 제한"): return false
	# 처치 콜백이 즉시 레벨업을 열더라도 해당 유효 타격의 회복은 적용한다.
	target.visible = false
	var enemy := runner.leaf_slime
	enemy.reset_target()
	enemy.visible = true
	enemy.set_process(false)
	enemy.damage_receiver.health = 5
	enemy.damage_receiver.tick(1)
	player.damage_receiver.health = 50
	player.lifesteal_progress = 15
	growth.experience = 20
	_sword_hit(enemy, 20)
	if not _check(growth.choosing and paused and player.damage_receiver.health == 51 and player.lifesteal_progress == 0, "치명타 실제 5 피해·동기 레벨업 후에도 해당 타격 회복"): return false
	return _resolve_growth()

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-124 failed: " + message)
		paused = false
		quit(1)
	return condition
