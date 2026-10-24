extends "res://tests/gp415_444_runtime_test.gd"

var task_id: String
var task: Dictionary

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	task_id = args[1]
	character = args[2]
	task = RunTasks.definition(task_id)
	if not _check(not task.is_empty(),"정의된30종 과제"): return
	family = task.get("family","sword")
	facing = 1
	run_prefix = "user://gp477_%s_%s" % [task_id,character]
	store.save_path = run_prefix+"_checkpoint.json"
	legacy.save_path = run_prefix+"_meta.jsonl"
	journal.save_path = run_prefix+"_story.jsonl"
	if phase not in ["resume","next"]:
		store.clear_checkpoint()
		for suffix in ["_meta.jsonl","_records.jsonl","_abilities.jsonl","_story.jsonl"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(run_prefix+suffix))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.story_journal_store = journal
	discoveries = AbilityDiscoveryStore.new()
	discoveries.save_path = run_prefix+"_abilities.jsonl"
	sandbox.ability_discovery_store = discoveries
	sandbox.get_node("RecoveryOrbController").drop_chance = 0
	sandbox.get_node("LocalTestRecorder").record_path = run_prefix+"_records.jsonl"
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	shop_combat = weapons.combat_for(family)
	growth.jobs_enabled = task.kind in ["job","advanced"]
	automatic_growth_card_id = family+"_power"
	for actor in [player,weapons,runner,sandbox.get_node("Player/UltimateController"),sandbox.get_node("ClockTrapController"),sandbox.get_node("RouteTerrain")]:
		actor.set_process(false)
		actor.set_physics_process(false)
	for id in PrototypeWeaponRewards.FAMILY_IDS:
		weapons.combat_for(id).set_process(false)
		weapons.combat_for(id).set_physics_process(false)
	sandbox.get_node("CombatFeedbackController").configure(0,false,false)
	if phase in ["resume","next"]:
		if not _resume_task(): return
		if phase == "next":
			sandbox._close_tasks()
			sandbox._close_supply_shop()
			var coins := int(sandbox.run_shop.coins)
			if not _advance_standard() or not _finish_stage(): return
			if runner.stage_number < runner.stage_limit and not sandbox._claim_weapon_reward(""): return
			var earned := RunSupplyShop.reward(runner.route_id) if runner.stage_number < runner.stage_limit else 0
			if not _check(RunTasks.claimed(sandbox.run_shop,task_id) and int(sandbox.run_shop.coins) == coins+earned and not sandbox._claim_task(task_id),"다음 스테이지/최종 전투 중복 과제 수입 없음"): return
			controls.show_main_screen()
			if not _check(controls.begin_retry(family,3,"standard",character,false,0,"bow" if family == "sword" else "sword") and not RunTasks.claimed(sandbox.run_shop,task_id) and sandbox.run_shop.coins == 0,"새 도전의 과제/지갑 초기화"): return
	else:
		var mode := "standard" if phase == "spend" or (task.get("route","") != "" and task.route != "city_gate") else "journey"
		if not _check(controls.begin_retry(family,5 if mode == "standard" else 10,mode,character,false,0,"bow" if family == "sword" else "sword"),"과제 포함 새 도전"): return
		if not _check(not sandbox._claim_task(task_id) and not RunTasks.claimed(sandbox.run_shop,task_id),"전투 중 과제 수령 차단"): return
		player.damage_receiver.health = 30
		player.potions_remaining = 0
		match phase:
			"catalog":
				if not _task_catalog(): return
			"spend":
				if not _spend_task_reward(): return
			"legacy":
				if not _legacy_tasks(): return
			"seed", "render":
				if not _achieve_task() or not _task_ui(): return
				if phase == "seed" and not _take_task(): return
				if phase == "render" and not await _render_tasks(): return
			_:
				_check(false,"잘못된 과제 검사 단계")
				return
	paused = false
	sandbox.free()
	print("GP-448–477 runtime test: OK (%s %s %s)" % [phase,task_id,character])
	quit(0)

func _achieve_task() -> bool:
	if task.kind in ["damage","hits","family"] and not _exercise_weapon(): return false
	if task.kind == "level":
		while growth.level < int(task.target):
			if not _earn_card(family+"_power"): return false
	if task.kind in ["job","advanced"]:
		combat = weapons.sword_combat
		for ignored in 5:
			if not _earn_card("sword_power"): return false
		if not _real_sword_hits() or not _resolve_growth(): return false
	for ignored in 9:
		if not _finish_stage(): return false
		var reward_id := family if task.kind == "equipment" else ""
		if not sandbox._claim_weapon_reward(reward_id): return false
		if task.kind == "equipment" and runner.stage_number >= int(task.grade):
			sandbox._open_supply_shop()
			var other := "bow" if family == "sword" else "sword"
			if not _check(sandbox._buy_supply("weapon_"+other),"실제 무기2개 승급 과제"): return false
			sandbox._close_supply_shop()
		if task.kind == "rerolls":
			sandbox._open_supply_shop()
			if not _check(sandbox._reroll_supplies(),"실제 서로 다른 휴식 재입고"): return false
			sandbox._close_supply_shop()
		if task.kind in ["services","purchases"] and runner.stage_number == 2:
			player.damage_receiver.health = 20
			player.potions_remaining = 0
			sandbox.get_node("Player/UltimateController").gauge = 0
			sandbox._open_supply_shop()
			for id in ["heal","potion","gauge"]:
				if not _check(sandbox._buy_supply(id),"실제 상점 구매 과제: "+id): return false
			sandbox._close_supply_shop()
		if RunTasks.ready(sandbox.run_shop,task_id,sandbox._task_context()): return true
		if not _advance_task_route(): return false
	return _check(false,"과제 목표 도달")

func _advance_task_route() -> bool:
	if task.kind != "route":
		var number := runner.stage_number
		var wanted: String = controls.stage_route_options[0].id
		_tap(controls.stage_route_rects[0].get_center())
		if not _resolve_growth(): return false
		return _check(not paused and runner.stage_number == number+1 and runner.route_id == wanted,"실제 다음 스테이지·직업 진화 확인")
	var wanted: String = task.route
	for ignored in controls.stage_route_pages():
		for index in controls.stage_route_options.size():
			if controls.stage_route_options[index].id == wanted:
				_tap(controls.stage_route_rects[index].get_center())
				return _check(not paused and runner.route_id == wanted,"과제 대상 실제 경로 선택")
		_tap(controls.stage_route_next_rect.get_center())
	return _advance_standard() if wanted == "city_gate" else _check(false,"선택 가능한 지역 과제")

func _exercise_weapon() -> bool:
	for target in get_nodes_in_group("targetable"): target.visible = false
	player.prepare_next_stage(sandbox.TRACK_START)
	player.facing_direction = 1
	weapons.target_selector.current_target = null
	var untouched := RunTasks.progress(task,sandbox._task_context())
	weapons.request_skill_1()
	shop_combat._update_skill_action(2.0)
	for group in ["bow_projectile","staff_magic_bolt","sword_wave"]:
		for bolt in get_nodes_in_group(group):
			bolt.set_physics_process(false)
			bolt._physics_process(1.2)
			bolt.free()
	if not _check(RunTasks.progress(task,sandbox._task_context()) == untouched,"빗나간 시전은 피해·적중 과제에 합산하지 않음"): return false
	var victim := _target_at("task",Vector2(100,0))
	victim.damage_receiver.max_health = 1000000
	victim.damage_receiver.reset()
	weapons.target_selector.current_target = victim
	for ignored in 100:
		var previous := int(shop_combat.skill_hit_count)
		shop_combat._skill_1_cooldown_s = 0
		shop_combat._skill_2_cooldown_s = 0
		if family == "shield": weapons.request_skill_2()
		else: weapons.request_skill_1()
		shop_combat._update_skill_action(2.0)
		for group in ["bow_projectile","staff_magic_bolt","sword_wave"]:
			for bolt in get_nodes_in_group(group):
				bolt.set_physics_process(false)
				bolt._physics_process(1.2)
				bolt.free()
		if not _check(int(shop_combat.skill_hit_count) > previous,"실제 계열 스킬 타격으로 적중 진행"): return false
		if RunTasks.progress(task,sandbox._task_context()) >= int(task.target):
			victim.free()
			return true
	victim.free()
	return _check(false,"실제 전투로 기술/피해 과제 완료")

func _task_ui() -> bool:
	sandbox._open_supply_shop()
	_tap(controls.supply_shop_snapshot().tasks.get_center())
	if not _check(controls.current_screen_mode() == 21 and paused,"실제 과제 게시판 진입·일시정지"): return false
	var before := _shop_snapshot()
	for dimensions in [Vector2(1280,720),Vector2(1600,720)]:
		controls.size = dimensions
		controls.task_filter = "all"
		controls.task_page = 0
		var seen: Array[String] = []
		for page in RunTaskView.snapshot(controls).pages:
			var view := RunTaskView.snapshot(controls)
			for index in view.items.size():
				if not _check(view.items[index].id not in seen and controls.layout_snapshot().safe.encloses(view.cards[index]),"30종 과제 페이지·안전 영역"): return false
				seen.append(view.items[index].id)
			_tap(view.next.get_center())
		if not _check(seen.size() == RunTasks.DEFINITIONS.size() and _shop_snapshot() == before,"게시판 열람·페이지는 효과와 저장 무변경"): return false
	_tap(RunTaskView.snapshot(controls).tabs[1].get_center())
	for ignored in RunTaskView.snapshot(controls).pages:
		var view := RunTaskView.snapshot(controls)
		for index in view.items.size():
			if view.items[index].id == task_id:
				_tap(view.cards[index].get_center())
				return _check(_shop_snapshot() == before,"수령 가능 필터·선택만으로 수령하지 않음")
		_tap(view.next.get_center())
	return _check(false,"실제 수령 가능한 과제 검색")

func _take_task() -> bool:
	var before := _shop_snapshot()
	store.save_path = "user://gp477_missing/checkpoint.json"
	_tap(RunTaskView.snapshot(controls).confirm.get_center())
	store.save_path = run_prefix+"_checkpoint.json"
	if not _check(_shop_snapshot() == before and controls.task_selected_id == task_id,"과제 저장 실패 · 잔액/장부/파일 복구 · 재시도 유지"): return false
	_tap(RunTaskView.snapshot(controls).confirm.get_center())
	if not _check(int(sandbox.run_shop.coins) == int(before.supplies.coins)+int(task.coins) and RunTasks.claimed(sandbox.run_shop,task_id) and not sandbox._claim_task(task_id),"보상 보급전 즉시 지급·같은 과제 중복 금지"): return false
	_tap(RunTaskView.snapshot(controls).tabs[2].get_center())
	var view := RunTaskView.snapshot(controls)
	if not _check(view.items.any(func(card: Dictionary) -> bool: return card.id == task_id and card.claimed),"수령 완료 필터"): return false
	return _task_save_guards()

func _resume_task() -> bool:
	var saved := store.load_checkpoint()
	if not _check(not saved.is_empty() and saved.supplies.has("tasks"),"과제 저장 존재"): return false
	for ignored in 2:
		controls.show_main_screen()
		if not _check(sandbox.continue_saved_run() and sandbox.run_shop == saved.supplies and _weapons_restored(saved.weapons) and player.damage_receiver.health == saved.player.health and player.potions_remaining == saved.player.potions_remaining and sandbox.get_node("Player/UltimateController").gauge == saved.ultimate.gauge,"반복 복원 · 잔액/실제 진행률/장부 유지"): return false
		sandbox._open_supply_shop()
		sandbox._open_tasks()
		if not _check(controls.current_screen_mode() == 21 and RunTasks.claimed(sandbox.run_shop,task_id) and not sandbox._claim_task(task_id),"별도 프로세스 복원 뒤 중복 수령 금지"): return false
	return _task_save_guards()

func _task_save_guards() -> bool:
	var saved := store.load_checkpoint()
	if not _check(not saved.is_empty() and RunCheckpointStore.valid_state(saved),"과제 정상 저장 검증"): return false
	for mutation in ["duplicate","unknown","coins","flag","future","slot","unearned","malformed","marker"]:
		var bad := saved.duplicate(true)
		match mutation:
			"duplicate": bad.supplies.actions.append(bad.supplies.actions[-1].duplicate(true))
			"unknown": bad.supplies.actions[-1].id = "task:missing"
			"coins": bad.supplies.coins += 1
			"flag": bad.supplies.tasks = 2
			"future": bad.supplies.actions[-1].stage = int(saved.stage.number)+1
			"slot": bad.supplies.actions[-1].slot = 0
			"malformed": bad.supplies.actions.append(null)
			"marker": bad.supplies.erase("tasks")
			"unearned":
				bad.supplies.actions[-1].id = "task:shield_training" if family != "shield" else "task:staff_training"
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved,"과제 변조 거부 · 정상 파일 보존: "+mutation): return false
	if task.kind in ["purchases","services","rerolls"]:
		var reordered := saved.duplicate(true)
		var receipt: Dictionary = reordered.supplies.actions.pop_back()
		reordered.supplies.actions.push_front(receipt)
		if not _check(store.save_checkpoint(reordered) == ERR_INVALID_DATA and store.load_checkpoint() == saved,"과제 수령 이전 지출·재입고 근거만 인정"): return false
	return true

func _legacy_tasks() -> bool:
	if not _finish_stage() or not sandbox._claim_weapon_reward(""): return false
	var old := store.load_checkpoint()
	old.supplies.erase("tasks")
	if not _check(store.save_checkpoint(old) == OK,"이전 보급소 저장 호환"): return false
	controls.show_main_screen()
	if not _check(sandbox.continue_saved_run() and not RunTasks.enabled(sandbox.run_shop),"이전 도전은 과제 소급 지급 없음"): return false
	sandbox._open_supply_shop()
	sandbox._open_tasks()
	if not _check(controls.current_screen_mode() == 20 and not sandbox._claim_task("first_steps"),"이전 도전 게시판·수령 차단"): return false
	sandbox._close_supply_shop()
	if not _advance_standard() or not _finish_stage() or not sandbox._claim_weapon_reward(""): return false
	return _check(not store.load_checkpoint().supplies.has("tasks"),"이전 저장 형식 계속 유지")

func _task_catalog() -> bool:
	var ids: Array[String] = []
	var context := {"weapons":{"equipment":{"sword":0,"bow":0}},"growth":{"level":1,"job":""},"stage":{"history":[]},"supplies":{"tasks":1,"actions":[]}}
	for entry in RunTasks.BASE_DEFINITIONS:
		if not _check(entry.id not in ids and entry.coins > 0 and entry.target > 0,"과제30종 고유 ID·양수 목표/보상"): return false
		ids.append(entry.id)
		if not _check(not RunTasks.ready(context.supplies,entry.id,context),"빈 도전 미달성 과제 수령 금지"): return false
	var cards := RunTasks.cards(context).filter(func(card: Dictionary) -> bool: return card.kind != "compound")
	if not _check(ids.size() == 30 and cards.filter(func(card: Dictionary) -> bool: return card.get("unavailable",false)).size() == 5,"30종 목록·미휴대 네 무기/성문 여정 조건 명시"): return false
	context.stage.limit = 3
	var short_cards := RunTasks.cards(context)
	return _check(short_cards.filter(func(card: Dictionary) -> bool: return card.id in ["steady_steps","long_road","toward_dawn","advanced_job","gate_scout","wind_scout","forest_scout","ruins_scout","festival_scout"] and card.unavailable).size() == 9,"짧은 도전의 길이/여정 제한 안내")

func _render_tasks() -> bool:
	controls.size = controls.get_viewport_rect().size
	controls.task_filter = OS.get_environment("TASK_RENDER_FILTER") if not OS.get_environment("TASK_RENDER_FILTER").is_empty() else "all"
	controls.task_page = int(OS.get_environment("TASK_RENDER_PAGE"))
	var mode := OS.get_environment("TASK_RENDER_STATE")
	if mode == "claimed" and not _check(sandbox._claim_task(task_id),"수령 후 게시판 렌더"): return false
	if mode == "failed":
		store.save_path = "user://gp477_missing/checkpoint.json"
		sandbox._claim_task(task_id)
		store.save_path = run_prefix+"_checkpoint.json"
	var before := _shop_snapshot()
	controls.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if not _check(_shop_snapshot() == before,"과제 화면 그리기는 진행률·보급전·저장 무변경"): return false
	var output := OS.get_environment("HAPPINESS_RENDER_DIR")
	if not output.is_empty():
		if not _check(root.get_texture().get_image().save_png(output+"/task_"+task_id+"_"+character+".png") == OK,"과제 실제 화면 캡처"): return false
	return true


func _spend_task_reward() -> bool:
	if not _finish_stage() or not sandbox._claim_weapon_reward("") or not _task_ui() or not _take_task(): return false
	sandbox._close_tasks()
	if not _check(sandbox.run_shop.coins == 45 and sandbox._buy_supply("potion") and sandbox._buy_supply("heal") and sandbox.run_shop.coins == 0,"과제5전으로 기존40전을 넘는45전 구매·저장"): return false
	var context: Dictionary = sandbox._task_context()
	if not _check(RunTasks.progress(RunTasks.definition("shop_regular"),context) == 2 and RunTasks.progress(RunTasks.definition("prepared_traveler"),context) == 2,"과제 영수증은 상품/서비스 구매 횟수에서 제외"): return false
	return _resume_task()
