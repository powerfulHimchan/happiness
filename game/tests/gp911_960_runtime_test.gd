extends "res://tests/gp841_890_runtime_test.gd"

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	var prefix := "user://gp960_"+("save" if phase in ["seed","resume"] else phase)
	store.save_path = prefix+"_checkpoint.json"
	legacy.save_path = prefix+"_meta.jsonl"
	journal.save_path = prefix+"_story.jsonl"
	if phase != "resume":
		store.clear_checkpoint()
		for suffix in ["_meta.jsonl","_records.jsonl","_abilities.jsonl","_story.jsonl"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix+suffix))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.story_journal_store = journal
	mastery_book = AbilityDiscoveryStore.new()
	mastery_book.save_path = prefix+"_abilities.jsonl"
	sandbox.ability_discovery_store = mastery_book
	sandbox.get_node("LocalTestRecorder").record_path = prefix+"_records.jsonl"
	sandbox.get_node("RecoveryOrbController").drop_chance = 0
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	growth.jobs_enabled = false
	for actor in [player,weapons,runner,sandbox.get_node("Player/UltimateController"),sandbox.get_node("ClockTrapController"),sandbox.get_node("RouteTerrain")]:
		actor.set_process(false)
		actor.set_physics_process(false)
	for family in PrototypeWeaponRewards.FAMILY_IDS:
		weapons.combat_for(family).set_process(false)
		weapons.combat_for(family).set_physics_process(false)
	sandbox.get_node("CombatFeedbackController").configure(0,false,false)
	if phase == "resume":
		var saved := store.load_checkpoint()
		if not _check(not saved.is_empty(),"conditional equipment save exists in a separate process"): return
		for ignored in 2:
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and weapons.blueprints == saved.weapons.blueprints and sandbox.run_shop == saved.supplies,"restore conditional weapons and shop ledger without duplicates"): return
		controls.show_main_screen()
		if not _check(controls.begin_retry("sword",3,"standard","roan") and weapons.blueprints == {"sword":"","bow":""} and sandbox.run_shop.coins == 0,"new run clears acquired designs and economy"): return
	else:
		if not _check(controls.begin_retry("staff",5,"standard","lumi",false,0,"shield"),"start conditional equipment run"): return
		automatic_growth_card_id = "staff_power"
		match phase:
			"catalog":
				if not _gear_catalog() or not _gear_math(): return
			"combat":
				if not _gear_hits(): return
			"acquisition":
				if not _gear_acquisition(): return
			"seed","ui","render":
				if not _prepare_gear_shop(): return
				if phase == "seed":
					if not _save_guards(): return
				else:
					if not await _shop_ui(phase == "render") or not await _catalog_ui(phase == "render"): return
			_:
				_check(false,"known test phase")
				return
	paused = false
	sandbox.free()
	print("GP-911–960 runtime: OK (%s; %d assertions)" % [phase,stats_checks])
	quit(0)

func _gear_catalog() -> bool:
	if not _check(ConditionalWeaponDesigns.DESIGNS.size() == 30 and PrototypeWeaponRewards.codex_cards({}).size() == 134,"thirty designs with two grades appended after original 74 entries"): return false
	var tickets := {}
	for id in ConditionalWeaponDesigns.DESIGNS:
		var definition: Dictionary = ConditionalWeaponDesigns.DESIGNS[id]
		if not _check(not tickets.has(definition.ticket) and definition.ticket >= 911 and definition.ticket <= 940 and PrototypeWeaponRewards.design_available(id,{}),"unique optional elite design without permanent unlock"): return false
		tickets[definition.ticket] = true
		for grade in [1,2]:
			var profile := PrototypeWeaponRewards.profile(definition.weapon,grade,id)
			if not _check(not profile.is_empty() and profile.condition == definition.condition and profile.lines[1].contains(definition.condition_label),"profile names the actual conditional effect"): return false
		if not _check(PrototypeWeaponRewards.profile(definition.weapon,0,id).is_empty(),"conditional designs reject normal grade"): return false
	return true

func _gear_math() -> bool:
	for id in ConditionalWeaponDesigns.DESIGNS:
		var definition: Dictionary = ConditionalWeaponDesigns.DESIGNS[id]
		var family: String = definition.weapon
		var other := "bow" if family != "bow" else "sword"
		for grade in [1,2]:
			for hp in [0,30,31,79,80,100]:
				for barrier in [0,1]:
					for grounded in [false,true]:
						var context := {"health":hp,"maximum":100,"barrier":barrier,"grounded":grounded}
						var applies: bool = hp > 0 and ((hp >= 80 if definition.condition == "calm" else hp <= 30 if definition.condition == "crisis" else barrier > 0 if definition.condition == "barrier" else grounded if definition.condition == "ground" else not grounded))
						for kind in ["basic","skill","ultimate"]:
							var expected := 1.0 if kind == "ultimate" else 1.0+(.10 if grade == 1 else .20)+((.25 if grade == 1 else .40) if applies and kind == definition.kind else 0.0)
							var value := PrototypeWeaponRewards.damage_multiplier({family:grade,other:0},family,kind,{family:id,other:""},context)
							if not _check(is_equal_approx(value,expected),"independent health/barrier/stance/grade/kind golden multiplier: "+id): return false
	var both := {"sword":2,"bow":2}
	var blueprints := {"sword":"stance_calm_sword","bow":"stance_calm_bow"}
	return _check(is_equal_approx(PrototypeWeaponRewards.damage_multiplier(both,"sword","basic",blueprints,{"health":80,"maximum":100}),1.80) and is_equal_approx(PrototypeWeaponRewards.damage_multiplier(both,"sword","basic",blueprints,{"health":79,"maximum":100}),1.20),"main full and backup half conditional bonuses at exact threshold")

func _gear_hits() -> bool:
	var target: PrototypeTarget = sandbox.get_node("Targets/RearTarget")
	for hero in PrototypeCharacters.IDS:
		for id in ConditionalWeaponDesigns.DESIGNS:
			var definition: Dictionary = ConditionalWeaponDesigns.DESIGNS[id]
			var family: String = definition.weapon
			player.reset_movement_test(Vector2(960,780))
			player.set_character(hero)
			weapons.reset_combat(family)
			if not _check(weapons.equip_reward(id,1),"real controller accepts conditional design"): return false
			player.damage_receiver.health = 30 if definition.condition == "crisis" else 100
			player.damage_receiver.barrier_health = 1 if definition.condition == "barrier" else 0
			var applies: bool = definition.condition != "ground" if not player.is_on_floor() else definition.condition != "air"
			for kind in ["basic","skill","ultimate"]:
				target.reset_target()
				target.damage_receiver.max_health = 10000
				target.damage_receiver.reset()
				var amount := 100 if kind == "ultimate" else 135 if applies and kind == definition.kind else 110
				var event := _event(family,kind,player.growth_damage(100,family,kind))
				if not _check(player.deal_weapon_damage(target,event) == DamageReceiver.Result.APPLIED and target.damage_receiver.health == 10000-amount,"actual outgoing damage includes condition once and excludes ultimate"): return false
	return true

func _gear_acquisition() -> bool:
	for family in PrototypeWeaponRewards.FAMILY_IDS:
		controls.show_main_screen()
		if not controls.begin_retry(family,5,"standard","roan",false,0,"bow" if family != "bow" else "sword"): return false
		automatic_growth_card_id = family+"_power"
		for style in ConditionalWeaponDesigns.STYLES:
			weapons.reset_combat(family)
			var id: String = "stance_"+String(style)+"_"+family
			if not _check(weapons.equip_reward(id,1) and weapons.equip_reward(id,2) and weapons.blueprints[family] == id,"both grades equip for all thirty designs"): return false
		weapons.reset_combat(family)
		if not _finish_stage(): return false
		var offers := PrototypeWeaponRewards.offers(1,weapons.equipment,{},weapons.blueprints)
		if not _check(offers.filter(func(item: Dictionary) -> bool: return String(item.id).begins_with("stance_")).size() == 10,"elite pool includes five designs per carried family only"): return false
		var seen: Array[String] = []
		for page in controls.weapon_reward_pages():
			controls._refresh_weapon_reward_layout()
			for index in controls.weapon_reward_cards.size():
				var item: Dictionary = controls.weapon_reward_cards[index]
				if not _check(item.id not in seen and controls._safe_area_in_viewport().encloses(controls.weapon_reward_rects[index]),"every real reward is unique and visible inside safe area"): return false
				seen.append(item.id)
			_tap(controls.weapon_reward_next_rect.get_center())
		if not _check(seen.size() == offers.size(),"reward pagination includes all conditional designs"): return false
		if not _check(sandbox._claim_weapon_reward("stance_calm_"+family) and store.load_checkpoint().weapons.blueprints[family] == "stance_calm_"+family,"real elite reward and checkpoint include new design"): return false
	return true

func _prepare_gear_shop() -> bool:
	if not _gain("staff_power") or not _gain("shield_power") or not _gain("magic_barrier"): return false
	if not _finish_stage() or not sandbox._claim_weapon_reward("stance_barrier_staff"): return false
	if not _check(weapons.equip_reward("stance_crisis_shield",1),"prepare conditional backup"): return false
	player.damage_receiver.health = 30
	player._emit_metrics()
	sandbox._open_supply_shop()
	return _check(sandbox._buy_supply("gauge") and controls.current_screen_mode() == 20,"real purchase saves both designs and economy")

func _save_guards() -> bool:
	var saved := store.load_checkpoint()
	for design in ["unknown","stance_calm_bow"]:
		var bad := saved.duplicate(true)
		bad.weapons.blueprints.staff = design
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved,"unknown/wrong-family blueprint rejects atomically"): return false
	var before := _fingerprint()
	var path := store.save_path
	store.save_path = "user://gp960_missing/checkpoint.json"
	player.potions_remaining = 0
	var coins := int(sandbox.run_shop.coins)
	if not _check(not sandbox._buy_supply("potion") and sandbox.run_shop.coins == coins and player.potions_remaining == 0,"failed purchase save rolls back money and effect"): return false
	store.save_path = path
	return _check(store.load_checkpoint() == saved and saved.weapons.blueprints == before.weapons.blueprints,"failed write preserves original equipment checkpoint")

func _fingerprint() -> Dictionary:
	return {"save":store.load_checkpoint(),"weapons":weapons.checkpoint_snapshot(),"growth":growth.checkpoint_snapshot(),"shop":sandbox.run_shop.duplicate(true),"health":player.damage_receiver.health,"potions":player.potions_remaining,"gauge":sandbox.get_node("Player/UltimateController").gauge,"rng":player.critical_rng.state}

func _shop_ui(rendering: bool) -> bool:
	var before := _fingerprint()
	var data: Dictionary = controls.shop_data
	if not _check(data.ledger.route_income+data.ledger.task_income-data.ledger.spent == data.coins and data.ledger.spent == 15,"ledger reconciles route/task income, spending and wallet"): return false
	for kind in 4:
		for ready in 3:
			for family in 3:
				var options := {"kind":kind,"ready":ready,"family":family,"order":1}
				var items := SupplyShopBrowser.query(data,options)
				for index in items.size():
					if not _check((kind == 0 or items[index].kind == ["service","weapon","skill"][kind-1]) and (ready != 1 or items[index].ready) and (ready != 2 or not items[index].ready),"combined shop filters"): return false
					if index > 0 and not _check(items[index-1].cost <= items[index].cost,"ascending price order"): return false
	for order in [2,3]:
		var items := SupplyShopBrowser.query(data,{"order":order})
		for index in range(1,items.size()):
			if order == 2 and not _check(items[index-1].cost >= items[index].cost,"descending price order"): return false
			if order == 3 and not _check(String(items[index-1].name).naturalnocasecmp_to(String(items[index].name)) <= 0,"natural item name order"): return false
	for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,800)]:
		if rendering: root.size = dimensions; root.content_scale_size = Vector2i(1920,1080); await process_frame
		controls.size = root.get_visible_rect().size if rendering else Vector2(dimensions)
		controls._refresh_layout()
		var view: Dictionary = controls.supply_shop_snapshot()
		var targets: Array = view.cards+view.slots+view.filters+[view.previous,view.next,view.back,view.reroll,view.confirm,view.tasks]
		if not _bounds(targets,controls._safe_area_in_viewport()): return false
		for index in 4: _tap(view.filters[index].get_center())
		if not _check(controls.shop_selected_id.is_empty() and controls.shop_slot == -1 and controls.shop_page == 0,"filters clear stale hidden purchase selection"): return false
		controls.shop_browser_options = SupplyShopBrowser.defaults()
		controls.shop_selected_id = "skill_staff_0"
		_tap(view.filters[4].get_center())
		var inspector := SupplyShopInspector.layout(controls._safe_area_in_viewport())
		if not _bounds(inspector.tabs+[inspector.previous,inspector.next,inspector.close],controls._safe_area_in_viewport()): return false
		for tab in 3:
			_tap(inspector.tabs[tab].get_center())
			if not _check(controls.shop_inspector_open and not SupplyShopInspector.lines(controls).is_empty(),"details, receipts and deterministic restock preview available"): return false
			if rendering and not await _capture("shop_%d_%dx%d" % [tab,dimensions.x,dimensions.y]): return false
		_tap(inspector.close.get_center())
		if rendering and not await _capture("shop_overview_%dx%d" % [dimensions.x,dimensions.y]): return false
		if not _check(not controls.shop_inspector_open and before == _fingerprint(),"shop browsing never spends or mutates run/save/RNG"): return false
	return true

func _catalog_ui(rendering: bool) -> bool:
	var before := _fingerprint()
	player._emit_metrics()
	weapons.force_emit_metrics()
	controls.show_main_screen()
	controls.show_village()
	controls.village_page = "weapons"
	controls.weapon_browser_options = WeaponCatalogBrowser.defaults()
	controls.weapon_browser_options.owner = 1
	var equipped_view: Dictionary = controls.village_snapshot()
	if not _check(equipped_view.cards.size() == 2 and equipped_view.cards.all(func(card: Dictionary) -> bool: return card.get("equipped",false)),"equipped filter identifies both actual current designs"): return false
	for key in ["family","grade","owner","condition","order"]:
		for index in {"family":7,"grade":4,"owner":3,"condition":7,"order":4}[key]:
			controls.weapon_browser_options = WeaponCatalogBrowser.defaults()
			controls.weapon_browser_options[key] = index
			var view: Dictionary = controls.village_snapshot()
			if not _check(not view.cards.is_empty() and view.weapon_pages >= 1,"every catalog filter including empty results has safe pagination"): return false
	controls.weapon_browser_options = WeaponCatalogBrowser.defaults()
	for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,800)]:
		controls.weapon_browser_options = WeaponCatalogBrowser.defaults()
		if rendering: root.size = dimensions; root.content_scale_size = Vector2i(1920,1080); await process_frame
		controls.size = root.get_visible_rect().size if rendering else Vector2(dimensions)
		controls._refresh_layout()
		var toolbar := WeaponCatalogBrowser.toolbar(controls._safe_area_in_viewport())
		var view: Dictionary = controls.village_snapshot()
		if not _bounds(toolbar+view.layout.cards+view.tabs.values()+[view.pager.previous,view.pager.next],controls._safe_area_in_viewport()): return false
		for index in 5:
			_tap(toolbar[index].get_center())
			if not _check(controls.weapon_browser_options[["family","grade","owner","condition","order"][index]] == 1,"actual codex toolbar input changes intended filter"): return false
		controls.weapon_browser_options = WeaponCatalogBrowser.defaults()
		controls.weapon_browser_options.condition = 4
		if rendering:
			if not await _capture("weapons_%dx%d" % [dimensions.x,dimensions.y]): return false
			controls.weapon_browser_options = WeaponCatalogBrowser.defaults()
			controls.weapon_browser_options.owner = 1
			if not await _capture("equipped_%dx%d" % [dimensions.x,dimensions.y]): return false
	return _check(before == _fingerprint(),"weapon browsing/comparison never equips or changes saves/RNG")

func _bounds(targets: Array,safe: Rect2) -> bool:
	for index in targets.size():
		if not _check(safe.encloses(targets[index]),"touch target inside safe area"): return false
		for other in range(index+1,targets.size()):
			if not _check(not targets[index].intersects(targets[other]),"touch targets do not overlap"): return false
	return true

func _capture(name: String) -> bool:
	var directory := OS.get_environment("GEAR_RENDER_DIR")
	if not _check(not directory.is_empty() and DisplayServer.get_name() != "headless","real display for gear/shop QA"): return false
	DirAccess.make_dir_recursive_absolute(directory)
	controls.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return _check(root.get_texture().get_image().save_png(directory.path_join(name+".png")) == OK,"rendered screen saved")
