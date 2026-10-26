extends "res://tests/gp415_444_runtime_test.gd"

func _run() -> void:
	if not _art_contract() or not _motion_contract(): return
	print("GP-1031–1050 supply artwork and event-driven motion: OK")
	if OS.get_cmdline_user_args()[0] == "catalog":
		quit(0)
		return
	await super._run()

func _art_contract() -> bool:
	var textures: Array[Texture2D] = [SupplyShopArt.BACKDROP,SupplyShopDetailArt.SIGN,SupplyShopDetailArt.SERVICE,SupplyShopDetailArt.STAR,SupplyShopDetailArt.TOME,SupplyShopDetailArt.PRICE,SupplyShopDetailArt.SOLD,SupplyShopDetailArt.LOCKED,SupplyShopDetailArt.SLOT,SupplyShopDetailArt.EMPTY]
	var hashes := {}
	for texture in textures:
		var image := texture.get_image()
		if not _check(image != null and image.get_used_rect().has_area(),"ten distinct visible supply artwork resources"): return false
		var hash := image.get_data().hex_encode().sha256_text()
		if not _check(not hashes.has(hash),"supply art has unique silhouettes"): return false
		hashes[hash] = true
	for dimensions in [Vector2(318,245),Vector2(430,260),Vector2(510,280)]:
		var rect := Rect2(Vector2(30,40),dimensions)
		var areas := SupplyShopArt.card_regions(rect)
		var regions: Array = areas.values()
		for index in regions.size():
			if not _check(rect.encloses(regions[index]),"supply text and emblems inside card touch area"): return false
			for other in range(index+1,regions.size()):
				if not _check(not regions[index].intersects(regions[other]),"icon/title/price/details/stamp never overlap"): return false
	return true

func _motion_contract() -> bool:
	var motion := SupplyShopMotion.new()
	var data := {"stage":1,"coins":40,"rerolled":false,"ledger":{"spent":0,"lines":[]},"cards":[{"id":"heal","cost":15,"ready":true,"reason":""}]}
	var before := data.duplicate(true)
	motion.open()
	motion.sync({},data)
	if not _check(motion.purchase_id.is_empty() and motion.restock_age == SupplyShopMotion.RESTOCK,"initial load cannot celebrate transactions"): return false
	motion.tick(.08)
	if not _check(motion.pose(0,false).alpha > motion.pose(2,false).alpha,"three cards enter at distinct times"): return false
	var frozen := motion.pose(0,false)
	motion.tick(-1)
	for ignored in 50: motion.pose(0,false)
	if not _check(motion.pose(0,false) == frozen and data == before,"drawing cannot mutate ledger or advance time"): return false
	motion.tick(10)
	if not _check(not motion.is_animating(),"all menu effects settle without indefinite animation"): return false
	motion.page_changed(-1)
	if not _check(motion.pose(0,false).offset.x < 0,"previous page has correct direction"): return false
	motion.page_changed(1)
	if not _check(motion.pose(0,false).offset.x > 0,"next page has correct direction"): return false
	motion.query_changed()
	motion.selected()
	motion.slot_selected()
	motion.inspect()
	motion.tick(.1)
	if not _check(motion.pose(0,true).selection > 0 and motion.slotting > 0 and motion.inspector_age > 0,"selection, slot and inspector motion advance independently"): return false
	motion.sync(data,data)
	if not _check(motion.purchase_id.is_empty() and motion.restock_age == SupplyShopMotion.RESTOCK,"failed/unchanged refresh cannot simulate purchase or restock"): return false
	var bought := data.duplicate(true)
	bought.coins = 25
	bought.ledger = {"spent":15,"lines":["purchase"]}
	bought.cards[0].ready = false
	bought.cards[0].reason = "이번 휴식에서 구매 완료"
	motion.sync(data,bought)
	if not _check(motion.purchase_id == "heal" and motion.purchased_cost == 15 and motion.purchase_pieces().size() == 8 and motion.wallet_age == 0,"confirmed sold state and ledger increment start purchase and wallet effects"): return false
	motion.tick(.2)
	var age := motion.purchase_age
	motion.sync(bought,bought)
	if not _check(motion.purchase_age == age,"repeated refresh does not restart purchase celebration"): return false
	var restocked := bought.duplicate(true)
	restocked.coins -= 10
	restocked.rerolled = true
	restocked.ledger.spent += 10
	restocked.ledger.lines.append("restock")
	motion.sync(bought,restocked)
	if not _check(motion.restock_age == 0 and motion.purchase_age == age,"confirmed restock rotates stock icon without fake product purchase"): return false
	motion.tick(10)
	if not _check(not motion.is_animating() and motion.purchase_pieces().is_empty() and motion.purchased_cost == 0,"finite effects release purchase data"): return false
	var restored := restocked.duplicate(true)
	restored.stage = 2
	motion.sync(data,restored)
	motion.open()
	return _check(motion.purchase_id.is_empty() and motion.restock_age == SupplyShopMotion.RESTOCK,"another rest stop or reopened save cannot replay transactions")

func _select_product() -> bool:
	if not super._select_product(): return false
	var before := _shop_snapshot()
	var page: int = controls.shop_page
	var slot: int = controls.shop_slot
	var selected: String = controls.shop_selected_id
	var options: Dictionary = controls.shop_browser_options.duplicate(true)
	var motion: SupplyShopMotion = controls.supply_shop_motion
	motion.tick(10)
	motion.selected()
	controls.preview_application_active = false
	controls._process(.1)
	if not _check(motion.selecting == 0,"background application freezes supply animation"): return false
	controls.preview_application_active = true
	controls._process(.1)
	if not _check(motion.selecting > 0 and paused,"menu animates while actual combat remains paused"): return false
	var view: Dictionary = controls.supply_shop_snapshot()
	_tap(view.filters[0].get_center())
	if not _check(motion.querying == 0,"actual filter button starts content transition"): return false
	controls.shop_browser_options = options.duplicate(true)
	controls.shop_page = 0
	view = controls.supply_shop_snapshot()
	_tap(view.next.get_center())
	if not _check(motion.paging == 0 and motion.direction == 1,"actual next-page button starts directional animation"): return false
	view = controls.supply_shop_snapshot()
	_tap(view.filters[4].get_center())
	if not _check(controls.shop_inspector_open and motion.inspector_age == 0,"actual detail opening starts inspector reveal"): return false
	motion.tick(.1)
	var next_tab := (int(controls.shop_inspector_tab)+1)%3
	_tap(SupplyShopInspector.layout(controls._safe_area_in_viewport()).tabs[next_tab].get_center())
	if not _check(controls.shop_inspector_tab == next_tab and motion.inspector_age == 0,"actual inspector tab starts short transition"): return false
	_tap(SupplyShopInspector.layout(controls._safe_area_in_viewport()).close.get_center())
	controls.shop_page = page
	controls.shop_selected_id = selected
	controls.shop_slot = -1
	if RunSupplyShop.product(shop_id,1).kind == "skill":
		_tap(controls.supply_shop_snapshot().slots[slot].get_center())
		if not _check(motion.slotting == 0,"actual skill-slot selection starts slot tracing"): return false
	controls.shop_slot = slot
	return _check(_shop_snapshot() == before,"presentation input preserves price, RNG, effects and checkpoint")

func _ui_purchase(failure: bool) -> bool:
	if failure:
		if not _select_product(): return false
		var before := _shop_snapshot()
		controls.supply_shop_motion.tick(10)
		store.save_path = "user://gp1050_missing/checkpoint.json"
		_tap(controls.supply_shop_snapshot().confirm.get_center())
		store.save_path = run_prefix+"_checkpoint.json"
		if not _check(_shop_snapshot() == before and controls.supply_shop_motion.purchase_id.is_empty() and controls.supply_shop_motion.wallet_age == SupplyShopMotion.WALLET,"actual failed save leaves ledger and success effects unchanged"): return false
	if not super._ui_purchase(false): return false
	var motion: SupplyShopMotion = controls.supply_shop_motion
	return _check(motion.purchase_id == shop_id and motion.purchased_cost == int(RunSupplyShop.product(shop_id,1).cost) and RunSupplyShop.sold(store.load_checkpoint().supplies,shop_id),"real committed purchase drives the correct receipt effect")

func _rules() -> bool:
	sandbox._open_supply_shop()
	var before := _shop_snapshot()
	controls.supply_shop_motion.tick(10)
	store.save_path = "user://gp1050_missing/checkpoint.json"
	var failed: bool = not sandbox._reroll_supplies()
	store.save_path = run_prefix+"_checkpoint.json"
	if not _check(failed and _shop_snapshot() == before and controls.supply_shop_motion.restock_age == SupplyShopMotion.RESTOCK,"actual failed restock never spins the confirmed-restock indicator"): return false
	# The established rule suite also checks prices, rollback, caps and restoration.
	return super._rules()

func _shop_save_guards() -> bool:
	if RunSupplyShop.rerolled(sandbox.run_shop,int(sandbox.run_shop.cleared)) and controls.current_screen_mode() == 20:
		if not _check(controls.supply_shop_motion.restock_age < SupplyShopMotion.RESTOCK,"saved restock reaches the event-driven indicator"): return false
	return super._shop_save_guards()

func _render_shop() -> bool:
	if not _select_product(): return false
	var output := OS.get_environment("HAPPINESS_RENDER_DIR")
	if not _check(not output.is_empty() and DisplayServer.get_name() != "headless","actual display required"): return false
	DirAccess.make_dir_recursive_absolute(output)
	var before := _shop_snapshot()
	for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,800)]:
		root.size = dimensions
		await process_frame
		controls.size = controls.get_viewport_rect().size
		controls._refresh_layout()
		for state in ["services","weapons","skills","empty","opening","inspector"]:
			controls.shop_browser_options = SupplyShopBrowser.defaults()
			controls.shop_page = 0
			controls.shop_inspector_open = false
			controls.supply_shop_motion.open()
			controls.supply_shop_motion.tick(10)
			match state:
				"services": controls.shop_browser_options.kind = 1
				"weapons": controls.shop_browser_options.kind = 2
				"skills": controls.shop_browser_options.kind = 3
				"empty":
					controls.shop_browser_options.kind = 2
					controls.shop_browser_options.ready = 2
				"opening":
					controls.supply_shop_motion.open()
					controls.supply_shop_motion.tick(.08)
				"inspector": controls.shop_inspector_open = true; controls.shop_inspector_tab = 2
			var view: Dictionary = controls.supply_shop_snapshot()
			controls.shop_selected_id = view.items[0].id if not view.items.is_empty() else ""
			controls.shop_slot = 0
			if not await _capture(output,"supply_%dx%d_%s" % [dimensions.x,dimensions.y,state]): return false
	if not _check(_shop_snapshot() == before,"real rendering is display-only"): return false
	controls.shop_inspector_open = false
	controls.shop_browser_options = SupplyShopBrowser.defaults()
	if not _ui_purchase(true): return false
	# The interaction matrix changes Control.size; restore the real viewport for QA.
	await process_frame
	controls.size = controls.get_viewport_rect().size
	controls._refresh_layout()
	controls.supply_shop_motion.tick(.2)
	var paid := _shop_snapshot()
	if not await _capture(output,"supply_purchased"): return false
	return _check(_shop_snapshot() == paid,"purchase animation never debits coins twice")

func _capture(output: String, label: String) -> bool:
	controls.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return _check(root.get_texture().get_image().save_png(output+"/"+label+".png") == OK,"actual supply capture: "+label)
