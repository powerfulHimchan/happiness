extends "res://tests/gp385_414_runtime_test.gd"

var shop_combat: Node
var shop_id: String
var run_prefix: String

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	shop_id = args[1]
	character = args[2]
	var product := RunSupplyShop.product(shop_id,1)
	family = String(product.get("family",""))
	if family.is_empty(): family = args[3] if args.size() > 3 else "sword"
	facing = 1
	run_prefix = "user://gp444_%s_%s_%s" % [shop_id,character,family]
	store.save_path = run_prefix+"_checkpoint.json"
	legacy.save_path = run_prefix+"_meta.jsonl"
	journal.save_path = run_prefix+"_story.jsonl"
	if phase not in ["resume","next"]:
		store.clear_checkpoint()
		for suffix in ["_meta.jsonl","_records.jsonl","_abilities.jsonl","_story.jsonl"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(run_prefix+suffix))
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
	growth.jobs_enabled = false
	automatic_growth_card_id = family+"_power"
	for actor in [player,weapons,runner,sandbox.get_node("Player/UltimateController"),sandbox.get_node("ClockTrapController"),sandbox.get_node("RouteTerrain")]:
		actor.set_process(false)
		actor.set_physics_process(false)
	for id in PrototypeWeaponRewards.FAMILY_IDS:
		weapons.combat_for(id).set_process(false)
		weapons.combat_for(id).set_physics_process(false)
	sandbox.get_node("CombatFeedbackController").configure(0,false,false)
	if phase in ["resume","next"]:
		if not _restore_shop(): return
		if phase == "next":
			var coins := int(sandbox.run_shop.coins)
			sandbox._close_supply_shop()
			if not _advance_standard() or not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			if not _check(sandbox.run_shop.cleared == 2 and int(sandbox.run_shop.coins) == coins+RunSupplyShop.reward(runner.route_id) and not RunSupplyShop.sold(sandbox.run_shop,shop_id),"다음 스테이지 추가 재화·새 재고·구매 횟수 초기화"): return
			if not _shop_save_guards(): return
			controls.show_main_screen()
			if not _check(controls.begin_retry(family,3,"standard",character,false,0,"bow" if family == "sword" else "sword") and sandbox.run_shop.coins == 0 and sandbox.run_shop.actions.is_empty(),"새 도전 재화·구매·재고 초기화"): return
	else:
		if not _check(controls.begin_retry(family,5,"standard",character,false,0,"bow" if family == "sword" else "sword"),"상점 포함 새 도전"): return
		if not _check(not sandbox._buy_supply(shop_id) and not sandbox._reroll_supplies() and controls.current_screen_mode() == 0,"전투 중 구매·재입고 차단"): return
		player.damage_receiver.health = 30
		player.potions_remaining = 1
		for id in weapons.equipment:
			weapons.combat_for(id).set("_skill_1_cooldown_s",3.5)
			weapons.combat_for(id).set("_skill_2_cooldown_s",6.25)
		if not _finish_stage(): return
		sandbox._open_supply_shop()
		if not _check(controls.current_screen_mode() == 11,"정예 무기 보상 확정 전 상점 진입 차단"): return
		if not sandbox._claim_weapon_reward(""): return
		if not _check(int(sandbox.run_shop.coins) == 40 and sandbox.run_shop.cleared == 1 and controls.shop_data.enabled,"첫 완료40전·HUD/상점 노출"): return
		var before: Dictionary = sandbox.run_shop.duplicate(true)
		for ignored in 3:
			RunSupplyShop.grant(sandbox.run_shop,runner.checkpoint_snapshot(),weapons.skills)
			sandbox._on_growth_stage_metrics(runner.current_metrics())
		if not _check(sandbox.run_shop == before,"완료 알림·저장 재시도 재화 중복 방지"): return
		match phase:
			"seed":
				if not _ui_purchase(true): return
			"progression":
				if not _progression(): return
			"rules":
				if not _rules(): return
			"legacy":
				if not _legacy_shop(): return
			"render":
				if not await _render_shop(): return
			_:
				_check(false,"잘못된 단계")
				return
	paused = false
	sandbox.free()
	print("GP-415–444 runtime test: OK (%s %s %s %s)" % [phase,shop_id,character,family])
	quit(0)

func _select_product() -> bool:
	if controls.current_screen_mode() == 9:
		_tap(controls.shop_open_rect.get_center())
	if not _check(controls.current_screen_mode() == 20 and paused,"실제 상점 진입·전투 정지"): return false
	var snapshot := _shop_snapshot()
	var seen: Array[String] = []
	for dimensions in [Vector2(1280,720),Vector2(1600,720)]:
		controls.size = dimensions
		controls.shop_page = 0
		seen.clear()
		for page in controls.supply_shop_snapshot().pages:
			var view: Dictionary = controls.supply_shop_snapshot()
			for i in view.items.size():
				if not _check(view.items[i].id not in seen and controls.layout_snapshot().safe.encloses(view.cards[i]),"상점10상품·페이지 중복 없음·안전 영역"): return false
				seen.append(view.items[i].id)
			_tap(view.next.get_center())
		if not _check(seen.size() == 10 and shop_id in seen and _shop_snapshot() == snapshot,"비교·페이지는 재화/효과/파일 무변경"): return false
	controls.shop_page = 0
	for page in controls.supply_shop_snapshot().pages:
		var view: Dictionary = controls.supply_shop_snapshot()
		for i in view.items.size():
			if view.items[i].id == shop_id:
				_tap(view.cards[i].get_center())
				if RunSupplyShop.product(shop_id,1).kind == "skill":
					_tap(view.slots[0 if shop_id.ends_with("_0") else 1].get_center())
				return _check(_shop_snapshot() == snapshot,"상품·슬롯 선택만으로 구매하지 않음")
		_tap(view.next.get_center())
	return _check(false,"구매할 상품 표시 누락")

func _shop_snapshot() -> Dictionary:
	return {"supplies":sandbox.run_shop.duplicate(true),"context":sandbox._supply_context(),"weapons":weapons.checkpoint_snapshot(),"file":FileAccess.get_file_as_string(store.save_path)}

func _ui_purchase(failure: bool) -> bool:
	if not _select_product(): return false
	var before := _shop_snapshot()
	var item := RunSupplyShop.product(shop_id,1)
	var offer := RunSupplyShop.find_offer(sandbox.run_shop,shop_id).duplicate()
	var slot := 0 if shop_id.ends_with("_0") else 1
	if failure:
		store.save_path = "user://gp444_missing/checkpoint.json"
		_tap(controls.supply_shop_snapshot().confirm.get_center())
		store.save_path = run_prefix+"_checkpoint.json"
		if not _check(_shop_snapshot() == before and controls.shop_selected_id == shop_id,"구매 저장 실패·재화/체력/게이지/약/스킬/장비 완전 복구"): return false
	_tap(controls.supply_shop_snapshot().confirm.get_center())
	if not _check(int(sandbox.run_shop.coins) == int(before.supplies.coins)-int(item.cost) and RunSupplyShop.sold(sandbox.run_shop,shop_id) and not sandbox._buy_supply(shop_id,slot if item.kind == "skill" else -1),"가격 차감·품절·동일 휴식 중복 구매 차단"): return false
	match item.kind:
		"weapon":
			if not _check(weapons.equipment[family] == 1 and weapons.skills == before.weapons.skills,"여섯 계열 희귀 승급·스킬 유지"): return false
		"skill":
			if not _check(weapons.skills[family][slot] == offer.skill and float(shop_combat.get("_skill_%d_cooldown_s" % (slot+1))) >= PrototypeSkillRewards.SKILLS[offer.skill].cooldown_s and not runner.skills_claimed,"추천1/2 슬롯 교체·원본 대기·무료 보상 유지"): return false
		"service":
			match shop_id:
				"heal":
					if not _check(player.damage_receiver.health == mini(before.context.max_health,before.context.health+ceili(before.context.max_health*.30)),"식사 최대 체력30%·상한"): return false
				"potion":
					if not _check(player.potions_remaining == before.context.potions+1,"현재 조제의 회복약1개 보충"): return false
				"gauge":
					if not _check(sandbox.get_node("Player/UltimateController").gauge == mini(100,before.context.gauge+30),"게이지30충전·상한"): return false
				"refresh":
					for id in weapons.equipment:
						if not _check(weapons.combat_for(id)._skill_1_cooldown_s == 0 and weapons.combat_for(id)._skill_2_cooldown_s == 0,"주/보조 네 스킬 정비"): return false
	return _shop_save_guards()

func _restore_shop() -> bool:
	var saved := store.load_checkpoint()
	if not _check(not saved.is_empty() and saved.has("supplies"),"상점 중간 저장 존재"): return false
	for ignored in 2:
		controls.show_main_screen()
		if not _check(sandbox.continue_saved_run() and sandbox.run_shop == saved.supplies and _weapons_restored(saved.weapons) and player.damage_receiver.health == saved.player.health and player.potions_remaining == saved.player.potions_remaining and sandbox.get_node("Player/UltimateController").gauge == saved.ultimate.gauge,"별도 프로세스 반복 복원·잔액/재고/효과 이중 지급 없음"): return false
		_tap(controls.shop_open_rect.get_center())
		if not _check(controls.current_screen_mode() == 20 and RunSupplyShop.sold(sandbox.run_shop,shop_id),"상점 재진입·품절 보존"): return false
	return _shop_save_guards()

func _shop_save_guards() -> bool:
	var saved := store.load_checkpoint()
	if not _check(not saved.is_empty() and RunCheckpointStore.valid_state(saved),"상점 정상 저장 검증"): return false
	for mutation in ["coins","seed","future","stock","receipt"]:
		var bad := saved.duplicate(true)
		match mutation:
			"coins": bad.supplies.coins += 1
			"seed": bad.supplies.seed += 1
			"future": bad.supplies.cleared += 1
			"stock": bad.supplies.stock[0].id = "unknown"
			"receipt":
				if bad.supplies.actions.is_empty(): bad.supplies.actions.append({"stage":1,"id":"heal","slot":-1,"skill":""})
				else: bad.supplies.actions.append(bad.supplies.actions[-1].duplicate(true))
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved,"재화/시드/미래 지급/재고/중복 영수증 변조 거부: "+mutation): return false
	return true

func _rules() -> bool:
	sandbox._open_supply_shop()
	var before := _shop_snapshot()
	store.save_path = "user://gp444_missing/checkpoint.json"
	if not _check(not sandbox._reroll_supplies(),"재입고 저장 실패"): return false
	store.save_path = run_prefix+"_checkpoint.json"
	if not _check(_shop_snapshot() == before,"재입고 실패의 원본 재고·재화 보존"): return false
	var old_stock: Array = sandbox.run_shop.stock.duplicate(true)
	if not _check(sandbox._reroll_supplies() and sandbox.run_shop.coins == 30 and RunSupplyShop.rerolled(sandbox.run_shop,1) and sandbox.run_shop.stock != old_stock and not sandbox._reroll_supplies(),"유료 기술 재입고·10전·한 번·재화 중복 차감 없음"): return false
	player.damage_receiver.health = player.damage_receiver.max_health
	player.prepare_potions(player.potion_recipe,player.potions_capacity())
	sandbox.get_node("Player/UltimateController").gauge = 100
	for id in weapons.equipment:
		weapons.combat_for(id)._skill_1_cooldown_s = 0
		weapons.combat_for(id)._skill_2_cooldown_s = 0
	sandbox._sync_supply_shop()
	for id in ["heal","potion","gauge","refresh"]:
		if not _check(not RunSupplyShop.blocked(sandbox.run_shop,id,sandbox._supply_context()).is_empty() and not sandbox._buy_supply(id),"만충전/정비 불필요 구매 차단: "+id): return false
	if not _check(not sandbox._buy_supply("weapon_"+family),"잔액 부족 승급 차단"): return false
	# A shop is still an intermission: health recovery uses the expedition modifier.
	player.expedition = 2
	player.damage_receiver.health = 20
	if not _check(sandbox._buy_supply("heal") and player.damage_receiver.health == 43,"원정 회복75%·정수 올림"): return false
	player.expedition = 0
	if not _shop_save_guards(): return false
	var saved := store.load_checkpoint()
	controls.show_main_screen()
	if not _check(sandbox.continue_saved_run() and sandbox.run_shop == saved.supplies,"재입고·구매 후 잔액과 후보 복원"): return false
	sandbox._open_supply_shop()
	return _check(not sandbox._reroll_supplies() and sandbox.run_shop == saved.supplies,"복원 뒤 재입고 중복 차감 차단")

func _legacy_shop() -> bool:
	var old := store.load_checkpoint()
	old.erase("supplies")
	if not _check(store.save_checkpoint(old) == OK,"상점 필드 없는 이전 저장"): return false
	controls.show_main_screen()
	if not _check(sandbox.continue_saved_run() and sandbox.run_shop.is_empty() and not controls.shop_data.enabled,"이전 저장은 재화 소급 지급 없음"): return false
	sandbox._open_supply_shop()
	if not _check(controls.current_screen_mode() == 9,"이전 도전 상점 차단"): return false
	if not _advance_standard() or not _finish_stage() or not sandbox._claim_weapon_reward(""): return false
	return _check(not store.load_checkpoint().has("supplies") and sandbox.run_shop.is_empty(),"이전 도전 다음 스테이지도 저장 형식 유지")

func _render_shop() -> bool:
	var mode := OS.get_environment("SHOP_RENDER_MODE")
	if mode == "route":
		if not _advance_standard() or not _finish_stage() or not sandbox._claim_weapon_reward(""): return false
	elif mode == "hud":
		if not _advance_standard(): return false
	else:
		sandbox._open_supply_shop()
		controls.shop_page = int(OS.get_environment("SHOP_RENDER_PAGE"))
		controls.shop_selected_id = String(controls.supply_shop_snapshot().items[0].id)
		controls.shop_slot = 0
	controls.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("HAPPINESS_RENDER_DIR")
	if not output.is_empty():
		if not _check(root.get_texture().get_image().save_png(output+"/shop_"+family+"_"+character+"_"+str(controls.shop_page)+mode+".png") == OK,"상점 실제 화면 렌더"): return false
	return true

func _progression() -> bool:
	for route in RunSupplyShop.ROUTE_BONUS:
		if not _check(RunSupplyShop.reward(route) == 40+int(RunSupplyShop.ROUTE_BONUS[route]),"경로별 추가 보급전: "+route): return false
	if not _advance_standard() or not _finish_stage() or not sandbox._claim_weapon_reward(""): return false
	sandbox._open_supply_shop()
	var coins := int(sandbox.run_shop.coins)
	if not _check(sandbox._buy_supply("weapon_"+family) and weapons.equipment[family] == 2 and sandbox.run_shop.coins == coins-70,"두 번째 휴식 영웅 승급70전"): return false
	var saved := store.load_checkpoint()
	controls.show_main_screen()
	if not _check(sandbox.continue_saved_run() and sandbox.run_shop == saved.supplies and weapons.equipment[family] == 2,"영웅 승급·장부 복원"): return false
	while runner.stage_number < runner.stage_limit:
		if not _advance_standard() or not _finish_stage(): return false
		if runner.stage_number < runner.stage_limit and not sandbox._claim_weapon_reward(""): return false
	var before: Dictionary = sandbox.run_shop.duplicate(true)
	sandbox._open_supply_shop()
	return _check(not sandbox._buy_supply("heal") and not sandbox._reroll_supplies() and sandbox.run_shop == before and int(sandbox.run_shop.cleared) == 4,"최종 전투 보급전 제외·상점/구매/재입고 차단")
