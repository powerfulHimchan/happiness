extends "res://tests/gp448_477_runtime_test.gd"

func _run() -> void:
	if OS.get_cmdline_user_args()[0] != "catalog":
		await super._run()
		return
	if not _catalog(): return
	print("GP-961–1010 catalog, supply ledger boundaries and board controls: OK")
	quit(0)

func _catalog() -> bool:
	var definitions := PartnershipRunTasks.definitions()
	if not _check(definitions.size() == 42 and RunTasks.DEFINITIONS.size() == 114,"30 pair + 12 supply tasks appended to 72 existing tasks"): return false
	var ids := {}
	for entry in RunTasks.DEFINITIONS:
		if not _check(not ids.has(entry.id),"unique persistent objective IDs"): return false
		ids[entry.id] = true
	for entry in definitions:
		var state := _fixture(entry)
		if not _check(RunTasks.ready(state.supplies,entry.id,state),"reachable conditions: "+entry.id): return false
		var receipt := {"stage":9,"id":RunTasks.PREFIX+entry.id,"skill":"","slot":-1}
		if not _check(RunTasks.valid_receipt(receipt,state.supplies,state),"earned receipt accepted"): return false
		for index in entry.goals.size():
			var missing := _fixture(entry,index)
			if not _check(not RunTasks.ready(missing.supplies,entry.id,missing) and not RunTasks.valid_receipt(receipt,missing.supplies,missing),"each condition is mandatory: "+entry.id): return false
		if entry.has("families"):
			for carried in entry.families:
				var absent := state.duplicate(true)
				absent.weapons.equipment.erase(carried)
				if not _check(not RunTasks.ready(absent.supplies,entry.id,absent) and not AdvancedRunTasks.restriction(entry,absent).is_empty(),"both carried families required"): return false
		state.supplies.actions.append(receipt)
		if not _check(not RunTasks.ready(state.supplies,entry.id,state),"no repeated award"): return false
		state.supplies.erase("tasks")
		if not _check(not RunTasks.ready(state.supplies,entry.id,state),"legacy taskless run is unchanged"): return false
	var state := _fixture(definitions[0],0)
	state.weapons.sword.skill_hit_count = 6
	state.weapons.bow.skill_hit_count = 6
	var cards := RunTasks.cards(state)
	for filter in RunTaskView.FILTERS:
		for selected_family in RunTaskView.FAMILIES:
			for order in RunTaskView.SORTS:
				var before := cards.duplicate(true)
				var result := RunTaskView.ordered(cards,filter,"all",order,selected_family)
				if not _check(cards == before and result.all(func(card: Dictionary) -> bool: return RunTaskView.matches(card,filter) and RunTaskView.family_matches(card,selected_family)),"combined board query is read-only"): return false
	var almost: Dictionary = cards.filter(func(card: Dictionary) -> bool: return card.id == "pair_sword_bow_practice")[0]
	if not _check(RunTaskView.matches(almost,"near") and not RunTaskView.matches(almost,"untouched"),"75 percent boundary and untouched filter"): return false
	var zero: Dictionary = RunTasks.cards(_fixture(definitions[0],-2)).filter(func(card: Dictionary) -> bool: return card.id == "pair_sword_bow_practice")[0]
	if not _check(RunTaskView.matches(zero,"untouched") and not RunTaskView.matches(zero,"near"),"zero progress boundary"): return false
	var supply := {"supplies":{"actions":[{"id":"task:shop_regular","stage":1},{"id":"reroll","stage":1},{"id":"weapon_sword","stage":1},{"id":"weapon_bow","stage":2},{"id":"unknown","stage":2}]}}
	if not _check(PartnershipRunTasks.value({"kind":"supply_spent"},supply) == 120 and PartnershipRunTasks.value({"kind":"supply_purchases"},supply) == 2 and PartnershipRunTasks.value({"kind":"supply_variety"},supply) == 2,"historical prices, reroll costs, rewards and unknown IDs excluded from purchases"): return false
	var complete := RunTasks.cards(_fixture(definitions[0]))[72]
	var mixed := [zero,complete]
	if not _check(RunTaskView.ordered(mixed,"all","all","remaining")[0].fraction == 1.0,"remaining condition ordering"): return false
	return true

func _fixture(entry: Dictionary, missing: int = -1) -> Dictionary:
	var state := {"weapons":{"equipment":{}},"growth":{"level":1,"ranks":{}},"stage":{"history":[],"limit":10,"run_mode":"journey"},"supplies":{"tasks":1,"actions":[]}}
	for weapon in entry.get("families",["sword","bow"]):
		state.weapons.equipment[weapon] = 0
		state.weapons[weapon] = {"skill_hit_count":0,"total_damage":0}
	for index in entry.goals.size():
		var goal: Dictionary = entry.goals[index]
		var value := 0 if missing == -2 else int(goal.target)-(1 if index == missing else 0)
		match goal.kind:
			"family_hits": state.weapons[goal.key].skill_hit_count = value
			"family_damage": state.weapons[goal.key].total_damage = value
			"family_grade": state.weapons.equipment[goal.key] = value
			"stage":
				for n in value: state.stage.history.append({"stage":n+1,"route":"meadow"})
			"supply_service":
				for n in value: state.supplies.actions.append({"id":goal.key,"stage":1})
			"supply_services", "supply_purchases", "supply_spent", "supply_rerolls", "supply_upgrades", "supply_skills", "supply_variety":
				# Use independent witnesses for the condition under test. Overlapping
				# spending/variety goals are intentionally generated separately below.
				var id: String = {"supply_services":"refresh","supply_purchases":"heal","supply_rerolls":"reroll","supply_upgrades":"weapon_sword","supply_skills":"skill_sword_0"}.get(goal.kind,"heal")
				if goal.kind == "supply_spent":
					for n in value: state.supplies.actions.append({"id":"reroll","stage":1})
					# Prices are multiples of five, so lower boundary uses nearest
					# attainable amount below target instead of a fabricated price.
					state.supplies.actions = state.supplies.actions.slice(0,int(value/10))
				elif goal.kind == "supply_variety":
					for n in value: state.supplies.actions.append({"id":["potion","gauge","refresh","skill_bow_1"][n],"stage":1})
				else:
					for n in value: state.supplies.actions.append({"id":id,"stage":1})
	# An extra variety witness can also count as a purchase. Keep one-under
	# purchase fixtures below the threshold while preserving their other goals.
	if entry.id == "supply_trial_varied_basket" and missing == 0:
		state.supplies.actions = [{"id":"heal","stage":1},{"id":"potion","stage":1},{"id":"gauge","stage":1},{"id":"heal","stage":2}]
	if missing >= 0 and entry.goals[missing].kind == "supply_variety":
		var allowed: Array = []
		for action in state.supplies.actions:
			if action.id != "reroll" and action.id not in allowed: allowed.append(action.id)
		allowed = allowed.slice(0,int(entry.goals[missing].target)-1)
		state.supplies.actions = state.supplies.actions.filter(func(action: Dictionary) -> bool: return action.id == "reroll" or action.id in allowed)
	return state

func _achieve_task() -> bool:
	var original_family := family
	if task.has("families"):
		var original := task.duplicate(true)
		for carried in original.families:
			family = carried
			shop_combat = weapons.combat_for(family)
			if weapons.active_weapon_id != family:
				weapons._switch_cooldown_remaining_s = 0
				weapons.request_weapon_switch()
			if not _check(weapons.active_weapon_id == family,"real weapon switch before recording hits"): return false
			task = {"kind":"family","family":family,"target":8} if original.id.ends_with("practice") else {"kind":"damage","target":999999}
			if not original.id.ends_with("practice"):
				task = {"kind":"compound","target":1,"goals":[AdvancedRunTasks._goal("family_damage",600,"damage",family)]}
			if not _exercise_weapon(): return false
			task = original
		family = original_family
		shop_combat = weapons.combat_for(family)
		if weapons.active_weapon_id != family:
			weapons._switch_cooldown_remaining_s = 0
			weapons.request_weapon_switch()
	for ignored in 9:
		if not _finish_stage() or not sandbox._claim_weapon_reward(""): return false
		sandbox._open_supply_shop()
		if task.has("families"):
			if task.id.ends_with("arsenal"):
				for carried in task.families:
					var id: String = "weapon_"+carried
					if RunSupplyShop.blocked(sandbox.run_shop,id,sandbox._supply_context()).is_empty() and not sandbox._buy_supply(id): return false
		else:
			player.damage_receiver.health = 20
			player.potions_remaining = 0
			sandbox.get_node("Player/UltimateController").gauge = 0
			for carried in weapons.equipment:
				weapons.combat_for(carried)._skill_1_cooldown_s = 3
			for id in _purchase_plan():
				if RunSupplyShop.SERVICES.has(id) and task_id != "supply_trial_long_investment" and sandbox.run_shop.actions.any(func(action: Dictionary) -> bool: return action.id == id): continue
				if id == "reroll":
					if int(sandbox.run_shop.coins) >= 10 and not RunSupplyShop.rerolled(sandbox.run_shop,runner.stage_number) and not sandbox._reroll_supplies(): return false
				elif RunSupplyShop.blocked(sandbox.run_shop,id,sandbox._supply_context()).is_empty():
					if not _check(sandbox._buy_supply(id,0 if id.begins_with("skill_") else -1),"real purchase contributes to task: "+id): return false
		sandbox._close_supply_shop()
		if RunTasks.ready(sandbox.run_shop,task_id,sandbox._task_context()): return true
		if not _advance_standard() or not _resolve_growth(): return false
	return _check(false,"reachable objective through actual play: "+task_id)

func _purchase_plan() -> Array:
	match task_id:
		"supply_trial_meal_clock": return ["heal","gauge"]
		"supply_trial_potion_workshop": return ["potion","refresh"]
		"supply_trial_recovery_plan": return ["heal","potion"]
		"supply_trial_battle_ready": return ["gauge","refresh"]
		"supply_trial_two_upgrades": return ["weapon_sword","weapon_bow"]
		"supply_trial_skill_basket": return ["skill_sword_0","skill_bow_0","refresh"]
		"supply_trial_stock_explorer": return ["reroll","heal","potion","gauge","refresh"]
		_: return ["heal","potion","gauge","refresh","skill_sword_0"]

func _task_ui() -> bool:
	if not super._task_ui(): return false
	var before := _shop_snapshot()
	for dimensions in [Vector2(1280,720),Vector2(1600,720),Vector2(1280,800)]:
		controls.size = dimensions
		for filter in RunTaskView.FILTERS.size():
			_tap(RunTaskView.snapshot(controls).tabs[filter].get_center())
			if not _check(controls.task_filter == RunTaskView.FILTERS[filter],"touch status filter"): return false
		for selected_family in RunTaskView.FAMILIES:
			if not _check(controls.task_family == selected_family,"touch carried-family filter"): return false
			_tap(RunTaskView.snapshot(controls).family.get_center())
		for order in RunTaskView.SORTS:
			if not _check(controls.task_sort == order,"touch sort control"): return false
			_tap(RunTaskView.snapshot(controls).sort.get_center())
		var view := RunTaskView.snapshot(controls)
		var rects: Array = view.tabs.duplicate()
		rects.append_array(view.cards)
		for key in ["category","sort","family","reset","previous","next","back","confirm"]: rects.append(view[key])
		for first in rects.size():
			if not _check(controls.layout_snapshot().safe.encloses(rects[first]),"all controls inside safe area"): return false
			for second in range(first+1,rects.size()):
				if not _check(not rects[first].intersects(rects[second]),"touch controls never overlap"): return false
		_tap(view.reset.get_center())
		if not _check(controls.task_filter == "all" and controls.task_sort == "catalog" and controls.task_family == "all" and controls.task_category == "all" and controls.task_page == 0 and controls.task_selected_id.is_empty() and controls.task_message.is_empty(),"one touch resets the board query"): return false
	if not _check(_shop_snapshot() == before,"browsing never pays or saves"): return false
	controls.task_filter = "ready"
	for ignored in RunTaskView.snapshot(controls).pages:
		var view := RunTaskView.snapshot(controls)
		for index in view.items.size():
			if view.items[index].id == task_id:
				_tap(view.cards[index].get_center())
				return true
		_tap(view.next.get_center())
	return _check(false,"earned objective remains selectable after resetting query")

func _task_save_guards() -> bool:
	if not super._task_save_guards(): return false
	if not task_id.begins_with("supply_trial_"): return true
	var saved := store.load_checkpoint()
	var bad := saved.duplicate(true)
	var receipt: Dictionary = bad.supplies.actions.pop_back()
	bad.supplies.actions.push_front(receipt)
	return _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved,"supply reward requires purchases before its receipt")

func _render_tasks() -> bool:
	var output := OS.get_environment("HAPPINESS_RENDER_DIR")
	if not _check(not output.is_empty() and DisplayServer.get_name() != "headless","real rendering required"): return false
	DirAccess.make_dir_recursive_absolute(output)
	var before := _shop_snapshot()
	for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,800)]:
		root.size = dimensions
		await process_frame
		controls.size = controls.get_viewport_rect().size
		controls._refresh_layout()
		for view_case in ["pairs","supplies","family","near","untouched","empty"]:
			RunTaskView.reset(controls)
			match view_case:
				"pairs": controls.task_page = 12
				"supplies": controls.task_category = "trade"
				"family": controls.task_family = "sword"
				"near": controls.task_filter = "near"
				"untouched": controls.task_filter = "untouched"
				"empty":
					controls.task_filter = "ready"
					controls.task_family = "fist"
			var view := RunTaskView.snapshot(controls)
			controls.task_selected_id = view.items[0].id if not view.items.is_empty() else ""
			controls.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			if not _check(root.get_texture().get_image().save_png(output+"/tasks_%dx%d_%s.png" % [dimensions.x,dimensions.y,view_case]) == OK,"actual board capture"): return false
	return _check(_shop_snapshot() == before,"rendering preserves state and save")
