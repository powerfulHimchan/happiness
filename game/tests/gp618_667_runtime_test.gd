extends "res://tests/gp448_477_runtime_test.gd"

func _run() -> void:
	if OS.get_cmdline_user_args()[0] != "catalog":
		await super._run()
		return
	if not _compound_catalog(): return
	print("GP-618–667 catalog, condition boundaries, receipts and sorting: OK")
	quit(0)

func _compound_catalog() -> bool:
	var definitions := AdvancedRunTasks.definitions()
	if not _check(definitions.size() == 42 and RunTasks.DEFINITIONS.size() == 72,"42 new / 72 total unique tasks"): return false
	var ids := {}
	for entry in RunTasks.DEFINITIONS:
		if not _check(not ids.has(entry.id),"unique task id"): return false
		ids[entry.id] = true
	for entry in definitions:
		var state := _fixture(entry)
		if not _check(RunTasks.ready(state.supplies,entry.id,state) and AdvancedRunTasks.fraction(entry,state) == 1.0,"all conditions required: "+entry.id): return false
		if not _check(RunTasks.valid_receipt({"stage":9,"id":"task:"+entry.id,"skill":"","slot":-1},state.supplies,state),"valid compound receipt"): return false
		for index in entry.goals.size():
			var missing := _fixture(entry,index)
			if not _check(not RunTasks.ready(missing.supplies,entry.id,missing) and AdvancedRunTasks.progress(entry,missing) == entry.goals.size()-1 and AdvancedRunTasks.fraction(entry,missing) < 1.0,"one missing condition prevents award: "+entry.id): return false
			if not _check(not RunTasks.valid_receipt({"stage":9,"id":"task:"+entry.id,"skill":"","slot":-1},missing.supplies,missing),"incomplete compound receipt rejected"): return false
		state.supplies.actions.append({"id":"task:"+entry.id})
		if not _check(not RunTasks.ready(state.supplies,entry.id,state),"duplicate reward prevented"): return false
		state.supplies.erase("tasks")
		if not _check(not RunTasks.ready(state.supplies,entry.id,state),"legacy taskless checkpoint remains disabled"): return false
	var empty := {"weapons":{"equipment":{"sword":0,"bow":0}},"growth":{"level":1,"ranks":{}},"stage":{"history":[],"limit":3,"run_mode":"standard"},"supplies":{"tasks":1,"actions":[]}}
	var cards := RunTasks.cards(empty)
	if not _check(cards.all(func(card: Dictionary) -> bool: return not card.ready),"new run has no immediately free compound rewards"): return false
	for filter in RunTaskView.FILTERS:
		for category in RunTaskView.CATEGORIES:
			for order in RunTaskView.SORTS:
				var before := cards.duplicate(true)
				var sorted := RunTaskView.ordered(cards,filter,category,order)
				if not _check(cards == before and sorted.all(func(card: Dictionary) -> bool: return RunTaskView.matches(card,filter) and (category == "all" or card.category == category)),"filter/category/sort is read-only"): return false
	var mixed: Array = []
	for index in 5:
		var card: Dictionary = cards[index].duplicate(true)
		card.id = str(index)
		card.ready = index == 1
		card.claimed = index == 2
		card.unavailable = index == 3
		card.fraction = float(index)/5
		card.coins = (index+1)*5
		mixed.append(card)
	var recommended := RunTaskView.ordered(mixed,"all","all","recommended")
	if not _check(recommended.map(func(card: Dictionary) -> String: return card.id) == ["1","4","0","3","2"],"recommended puts ready then active then unavailable then claimed"): return false
	var by_progress := RunTaskView.ordered(mixed,"all","all","progress")
	var by_reward := RunTaskView.ordered(mixed,"all","all","reward")
	if not _check(by_progress[0].id == "4" and by_reward[0].id == "4" and RunTaskView.summary(mixed) == {"total":5,"claimed":1,"ready":1,"coins":10},"progress / reward sorts and exact pending reward summary"): return false
	return true

func _fixture(entry: Dictionary, missing: int = -1) -> Dictionary:
	var equipment := {}
	var state := {"weapons":{"equipment":equipment},"growth":{"level":1,"ranks":{}},"stage":{"history":[],"limit":10,"run_mode":"journey"},"supplies":{"tasks":1,"actions":[]}}
	for weapon in AdvancedRunTasks.FAMILIES:
		equipment[weapon] = 0
		state.weapons[weapon] = {"skill_hit_count":0,"total_damage":0}
	for index in entry.goals.size():
		var goal: Dictionary = entry.goals[index]
		var value := int(goal.target)-(1 if index == missing else 0)
		match goal.kind:
			"family_hits": state.weapons[goal.key].skill_hit_count = value
			"family_damage": state.weapons[goal.key].total_damage = value
			"family_grade": equipment[goal.key] = value
			"level": state.growth.level = value
			"rank": state.growth.ranks[goal.key] = value
			"stage":
				for n in value: state.stage.history.append({"stage":n+1,"route":"meadow"})
			"route":
				for n in value: state.stage.history.append({"stage":n+1,"route":goal.key})
			"hits": state.weapons.sword.skill_hit_count = value
			"damage": state.weapons.sword.total_damage = value
			"equipment":
				for n in value: equipment[AdvancedRunTasks.FAMILIES[n]] = 1
	return state

func _achieve_task() -> bool:
	# Earn real growth cards and real weapon hits, then advance through actual rewards/routes.
	var entry := task.duplicate(true)
	for ignored in 3:
		if not _earn_card(family+"_power"): return false
	var wanted_level := 1
	for goal in entry.goals:
		if goal.kind == "level": wanted_level = int(goal.target)
	while growth.level < wanted_level:
		if not _earn_card(family+"_power"): return false
	task = {"kind":"compound","target":2,"goals":[{"kind":"family_hits","key":family,"target":45,"label":"hits"},{"kind":"family_damage","key":family,"target":2500,"label":"damage"}]}
	if not _exercise_weapon(): return false
	task = entry
	for ignored in 9:
		if not _finish_stage() or not sandbox._claim_weapon_reward(family): return false
		if task.get("route","") == "festival" and runner.stage_number >= 2 and int(weapons.equipment.bow) == 0:
			sandbox._open_supply_shop()
			if not _check(sandbox._buy_supply("weapon_bow"),"second rare weapon from real shop"): return false
			sandbox._close_supply_shop()
		if RunTasks.ready(sandbox.run_shop,task_id,sandbox._task_context()): return true
		if not _advance_compound_route(): return false
	return _check(false,"reachable compound task: "+task_id)

func _advance_compound_route() -> bool:
	var wanted := String(task.get("route",""))
	for ignored in controls.stage_route_pages():
		for index in controls.stage_route_options.size():
			if controls.stage_route_options[index].id == wanted:
				_tap(controls.stage_route_rects[index].get_center())
				return _resolve_growth()
		_tap(controls.stage_route_next_rect.get_center())
	return _advance_standard() and _resolve_growth()

func _task_ui() -> bool:
	if not super._task_ui(): return false
	if task_id != "trial_sword_precision" or character != "roan": return true
	var before := _shop_snapshot()
	var selected: String = controls.task_selected_id
	var selected_page: int = controls.task_page
	for dimensions in [Vector2(1280,720),Vector2(1600,720),Vector2(1280,800)]:
		controls.size = dimensions
		for filter_index in RunTaskView.FILTERS.size():
			_tap(RunTaskView.snapshot(controls).tabs[filter_index].get_center())
			for category_index in RunTaskView.CATEGORIES.size():
				for sort_index in RunTaskView.SORTS.size():
					var view := RunTaskView.snapshot(controls)
					if not _check(controls.task_filter == RunTaskView.FILTERS[filter_index] and controls.task_category == RunTaskView.CATEGORIES[category_index] and controls.task_sort == RunTaskView.SORTS[sort_index],"actual filter/category/order touches"): return false
					var rects: Array = view.cards.duplicate()
					rects.append_array(view.tabs)
					for key in ["category","sort","previous","next","back","confirm"]: rects.append(view[key])
					for first in rects.size():
						if not _check(controls.layout_snapshot().safe.encloses(rects[first]),"all board targets inside safe area"): return false
						for second in range(first+1,rects.size()):
							if not _check(not rects[first].intersects(rects[second]),"board touch targets do not overlap"): return false
					_tap(view.sort.get_center())
				_tap(RunTaskView.snapshot(controls).category.get_center())
			if not _check(_shop_snapshot() == before,"UI controls never write saves or pay coins"): return false
	controls.task_filter = "ready"
	controls.task_page = selected_page
	controls.task_selected_id = selected
	controls.task_message = "previous reward receipt"
	var restored := RunTaskView.snapshot(controls)
	for index in restored.items.size():
		if restored.items[index].id == selected:
			_tap(restored.cards[index].get_center())
			if not _check(controls.task_message.is_empty() and not RunTaskView.details(restored.items[index]).is_empty(),"selecting another card replaces stale receipt with current conditions"): return false
	return true

func _render_tasks() -> bool:
	var output := OS.get_environment("HAPPINESS_RENDER_DIR")
	if not _check(not output.is_empty() and DisplayServer.get_name() != "headless","real render required"): return false
	DirAccess.make_dir_recursive_absolute(output)
	var before := _shop_snapshot()
	for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,800)]:
		root.size = dimensions
		await process_frame
		controls.size = controls.get_viewport_rect().size
		controls._refresh_layout()
		controls.task_filter = "all"
		controls.task_sort = "catalog"
		controls.task_category = "all"
		for page in 12:
			controls.task_page = page
			var view := RunTaskView.snapshot(controls)
			controls.task_selected_id = view.items[0].id
			controls.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			if not _check(root.get_texture().get_image().save_png(output+"/board_%dx%d_%02d.png" % [dimensions.x,dimensions.y,page]) == OK,"actual board render"): return false
	return _check(_shop_snapshot() == before,"rendering all pages is read-only")
