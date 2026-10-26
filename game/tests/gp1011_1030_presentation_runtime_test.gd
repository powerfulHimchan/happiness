extends "res://tests/gp961_1010_runtime_test.gd"

func _run() -> void:
	if not _art_contract() or not _motion_contract(): return
	print("GP-1011–1030 graphics and bounded menu motion: OK")
	await super._run()

func _art_contract() -> bool:
	var textures: Array[Texture2D] = [TaskBoardArt.BACKDROP,TaskBoardDetailArt.CREST,TaskBoardDetailArt.LINK,TaskBoardDetailArt.SATCHEL,TaskBoardDetailArt.MEDAL,TaskBoardDetailArt.READY,TaskBoardDetailArt.CLAIMED,TaskBoardDetailArt.LOCKED,TaskBoardDetailArt.CORNERS,TaskBoardDetailArt.EMPTY]
	var hashes := {}
	for texture in textures:
		var image := texture.get_image()
		if not _check(image != null and image.get_used_rect().has_area(),"new artwork imports with visible pixels"): return false
		var hash := image.get_data().hex_encode().sha256_text()
		if not _check(not hashes.has(hash),"ten distinct artwork resources"): return false
		hashes[hash] = true
	for dimensions in [Vector2(318,122),Vector2(400,140),Vector2(450,170)]:
		var rect := Rect2(Vector2(40,60),dimensions)
		var areas := TaskBoardArt.regions(rect)
		for area in areas.values():
			if not _check(rect.encloses(area),"card artwork and text inside fixed touch rectangle"): return false
		if not _check(not areas.icon.intersects(areas.title) and not areas.title.intersects(areas.seal) and not areas.status.intersects(areas.reward),"paired emblems, titles, seals and rewards do not overlap"): return false
	return true

func _motion_contract() -> bool:
	var card := {"id":"fixture","progress":3,"target":4,"fraction":.75,"coins":10,"ready":true,"claimed":false}
	var before := card.duplicate(true)
	var motion := TaskBoardMotion.new()
	motion.open([card])
	var first := motion.pose(card,0,true)
	motion.tick(.10)
	var second := motion.pose(card,0,true)
	if not _check(first.alpha < second.alpha and second.fraction > first.fraction and second.fraction < .75,"entry and progress interpolate without changing true counters"): return false
	if not _check(motion.pose(card,0,false).alpha > motion.pose(card,5,false).alpha,"card entrances are staggered"): return false
	var frozen := motion.pose(card,0,true)
	for ignored in 50: motion.pose(card,0,true)
	motion.tick(-1)
	if not _check(frozen == motion.pose(card,0,true) and card == before,"draw sampling and negative delta cannot mutate/age state"): return false
	motion.tick(10)
	if not _check(not motion.is_animating() and is_equal_approx(motion.pose(card,5,false).fraction,.75),"finite effects settle at exact progress"): return false
	motion.page_changed(1)
	if not _check(motion.pose(card,0,false).offset.x > 0,"next-page direction"): return false
	motion.page_changed(-1)
	if not _check(motion.pose(card,0,false).offset.x < 0,"previous-page direction"): return false
	motion.query_changed()
	motion.selected()
	motion.pressed(Vector2(30,40))
	if not _check(motion.pose(card,0,true).query == 1 and motion.press_position == Vector2(30,40),"query and touch feedback are event-driven"): return false
	motion.tick(.1)
	if not _check(motion.pose(card,0,true).selection > 0 and motion.pose(card,0,true).glint > 0,"selection and reward glint interpolate"): return false
	motion.sync([card],[card])
	if not _check(motion.claim_coins == 0,"failed or unchanged updates never celebrate"): return false
	var claimed := card.duplicate(true)
	claimed.claimed = true
	claimed.ready = false
	motion.sync([card],[claimed])
	if not _check(motion.claim_coins == 10 and motion.particles().size() == 10,"only confirmed claim transition starts bounded reward burst"): return false
	motion.tick(.2)
	var age := motion.claim_age
	motion.sync([claimed],[claimed])
	if not _check(motion.claim_age == age,"repeated model refresh cannot duplicate celebration"): return false
	motion.tick(10)
	if not _check(motion.particles().is_empty() and motion.claim_coins == 0 and not motion.is_animating(),"finished effects release transient state"): return false
	motion.open([claimed])
	if not _check(motion.claim_coins == 0,"restoring/reopening claimed tasks never simulates new earnings"): return false
	return true

func _task_ui() -> bool:
	if not super._task_ui(): return false
	var before := _shop_snapshot()
	var original_page: int = controls.task_page
	controls.task_board_motion.tick(10)
	controls.preview_application_active = false
	controls.task_board_motion.selected()
	controls._process(.1)
	if not _check(controls.task_board_motion.selecting == 0,"application-inactive menu freezes motion"): return false
	controls.preview_application_active = true
	controls._process(.1)
	if not _check(controls.task_board_motion.selecting > 0 and paused,"menu animates while game remains paused"): return false
	controls.task_board_motion.tick(10)
	var view := RunTaskView.snapshot(controls)
	_tap(view.reset.get_center())
	if not _check(controls.task_board_motion.querying == 0 and controls.task_board_motion.press_age == 0,"real reset touch triggers query fade and press ripple"): return false
	view = RunTaskView.snapshot(controls)
	_tap(view.next.get_center())
	if not _check(controls.task_board_motion.paging == 0 and controls.task_board_motion.direction == 1,"real next-page touch starts directional transition"): return false
	view = RunTaskView.snapshot(controls)
	_tap(view.cards[0].get_center())
	if not _check(controls.task_board_motion.selecting == 0,"real card touch starts selection emphasis"): return false
	controls.task_filter = "ready"
	controls.task_page = original_page
	controls.task_selected_id = task_id
	return _check(_shop_snapshot() == before,"all presentation events preserve combat, shop ledger and checkpoint")

func _take_task() -> bool:
	if not super._take_task(): return false
	if not _check(RunTasks.claimed(store.load_checkpoint().supplies,task_id),"successful presentation claim is persisted before process exit"): return false
	return _check(controls.task_board_motion.claim_coins == int(task.coins) and controls.task_board_motion.claim_age < TaskBoardMotion.CLAIM,"real saved award is connected to celebration")

func _render_tasks() -> bool:
	var output := OS.get_environment("HAPPINESS_RENDER_DIR")
	if not _check(not output.is_empty() and DisplayServer.get_name() != "headless","actual display rendering required"): return false
	DirAccess.make_dir_recursive_absolute(output)
	var before := _shop_snapshot()
	for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,800)]:
		root.size = dimensions
		await process_frame
		controls.size = controls.get_viewport_rect().size
		controls._refresh_layout()
		for view_case in ["pairs","supplies","locked","empty","opening","selection","ready"]:
			RunTaskView.reset(controls)
			controls.task_board_motion.open(controls.task_data.cards)
			controls.task_board_motion.tick(10)
			match view_case:
				"pairs": controls.task_page = 12
				"supplies": controls.task_category = "trade"
				"locked": controls.task_filter = "unavailable"
				"empty":
					controls.task_filter = "ready"
					controls.task_family = "fist"
				"opening":
					controls.task_page = 12
					controls.task_board_motion.open(controls.task_data.cards)
					controls.task_board_motion.tick(.1)
				"selection": controls.task_page = 12
				"ready": controls.task_filter = "ready"
			var view := RunTaskView.snapshot(controls)
			controls.task_selected_id = view.items[0].id if not view.items.is_empty() else ""
			if view_case == "selection":
				controls.task_board_motion.selected()
				controls.task_board_motion.tick(.12)
			if view_case == "ready":
				controls.task_board_motion.ready_age = .6
				controls.task_board_motion.glint_age = .4
			if not await _capture(output,"tasks_%dx%d_%s" % [dimensions.x,dimensions.y,view_case]): return false
	if not _check(_shop_snapshot() == before,"actual rendering never changes gameplay or saves"): return false
	# Capture a celebration only after the real save-failure/retry/claim flow.
	controls.task_selected_id = task_id
	if not _take_task(): return false
	var after := _shop_snapshot()
	controls.task_board_motion.tick(.2)
	if not await _capture(output,"tasks_claim"): return false
	return _check(_shop_snapshot() == after,"claim rendering never awards twice")

func _capture(output: String, label: String) -> bool:
	controls.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return _check(root.get_texture().get_image().save_png(output+"/"+label+".png") == OK,"actual presentation capture: "+label)
