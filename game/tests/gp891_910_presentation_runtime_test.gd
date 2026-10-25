extends "res://tests/gp841_890_runtime_test.gd"

func _run() -> void:
	var rendering := OS.get_cmdline_user_args()[0] == "render"
	if not _art() or not _motion(): return
	var prefix := "user://gp910"
	store.save_path = prefix+"_checkpoint.json"
	legacy.save_path = prefix+"_meta.jsonl"
	journal.save_path = prefix+"_story.jsonl"
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
	if not _check(controls.begin_retry("sword",5,"standard","roan",false,0,"bow"),"start real combat link presentation fixture"): return
	if not _gain_held(): return
	if not _integration() or not await _menu(): return
	if rendering:
		if not await _screens() or not await _gallery(): return
	paused = false
	sandbox.free()
	print("GP-891–910 presentation: OK (%d assertions; rendering=%s)" % [stats_checks,rendering])
	quit(0)

func _art() -> bool:
	var textures: Array[Texture2D] = [CombatLinksArt.BACKGROUND]
	for value in CombatLinksArt.ICONS.values(): textures.append(value)
	for value in CombatLinksArt.FRAMES.values(): textures.append(value)
	if not _check(textures.size() == 10,"exactly ten unique art resources"): return false
	var hashes := {}
	for texture in textures:
		var image := texture.get_image()
		if not _check(image != null and not image.is_empty() and image.get_used_rect().has_area(),"SVG imported into visible artwork"): return false
		var hash := image.get_data().hex_encode().sha256_text()
		if not _check(not hashes.has(hash),"artwork content is distinct"): return false
		hashes[hash] = true
	for style in CombatLinksArt.ICONS:
		var image: Image = CombatLinksArt.ICONS[style].get_image()
		if not _check(image.get_size() == Vector2i(128,128) and image.get_pixel(0,0).a == 0 and image.get_used_rect().size.x > 90,"full silhouette with genuine transparent corners"): return false
	for dimensions in [Vector2(320,200),Vector2(400,240),Vector2(500,280)]:
		var rect := Rect2(Vector2(20,30),dimensions)
		var regions := CombatLinksArt.card_regions(rect)
		var areas: Array = regions.values()
		for index in areas.size():
			if not _check(rect.encloses(areas[index]),"art/text regions inside card"): return false
			for other in range(index+1,areas.size()):
				if not _check(not areas[index].intersects(areas[other]),"icon, title, status, text and timer never overlap"): return false
	return _check(CombatLinksArt.frame_key({"learned":false,"live":false}) == "locked" and CombatLinksArt.frame_key({"learned":true,"live":false}) == "dormant" and CombatLinksArt.frame_key({"learned":true,"live":true}) == "active","three frames reflect real state")

func _motion() -> bool:
	for style in PrototypeCombatLinks.STYLES:
		var feedback := CombatLinkFeedback.new()
		var id := "sword_link_"+String(style)
		feedback.update({id:3.0},0)
		if not _check(feedback.bursts.size() == 1 and feedback.bursts[0].style == style and not feedback.bursts[0].ending,"new successful window starts corresponding effect"): return false
		var first := feedback.pose(style)
		feedback.update({id:2.84},.16)
		if not _check(first != feedback.pose(style),"distinct continuous motion for trigger "+style): return false
		var clock := feedback.clock_s
		var age := float(feedback.bursts[0].age)
		feedback.update({id:2.84},0)
		if not _check(feedback.clock_s == clock and feedback.bursts[0].age == age,"zero-delta redraw never ages/restarts effect"): return false
		feedback.update({id:3.0},0)
		if not _check(feedback.bursts.size() == 1 and feedback.bursts[0].age == 0,"refresh coalesces into one effect"): return false
		feedback.update({},.01)
		if not _check(feedback.bursts.size() == 1 and feedback.bursts[0].ending,"expiry creates fading seal"): return false
		feedback.update({},CombatLinkFeedback.END_DURATION)
		if not _check(feedback.bursts.is_empty() and feedback.active.is_empty(),"expiry fully clears visual allocation"): return false
		feedback.reset({id:.8})
		feedback.update({id:.8},.05)
		first = feedback.pose(style)
		feedback.update({id:.7},.2)
		if not _check(first.alpha != feedback.pose(style).alpha,"last second uses a soft warning pulse"): return false
	var all := {}
	for family in ["sword","bow"]:
		for style in PrototypeCombatLinks.STYLES: all[family+"_link_"+style] = 3.0
	var feedback := CombatLinkFeedback.new()
	for repetition in 120:
		for id in all: all[id] = 3.0+float(repetition%2)*.1
		feedback.update(all,.01)
		if not _check(feedback.bursts.size() <= CombatLinkFeedback.MAX_BURSTS and feedback.active.size() == 6,"two families and rapid hits stay at six coalesced effects"): return false
	feedback.reset(all)
	feedback.update(all,.1)
	if not _check(feedback.bursts.is_empty(),"restore baseline never replays activation"): return false
	feedback.update(all,.1,true)
	if not _check(feedback.active.is_empty() and feedback.bursts.is_empty(),"death/fall hide effects"): return false
	feedback.update(all,.1)
	if not _check(feedback.bursts.is_empty(),"return from recovery does not replay existing windows"): return false
	var previous := {}
	for hz in [30,60,120]:
		feedback.reset()
		feedback.update({"sword_link_critical":2.0},0)
		for frame in hz/5: feedback.update({"sword_link_critical":2.0-(frame+1.0)/hz},1.0/hz)
		var pose := feedback.pose("critical")
		if hz != 30:
			if not _check(is_equal_approx(float(previous.scale),float(pose.scale)) and previous.position.is_equal_approx(pose.position),"frame-rate independent feedback settling"): return false
		previous = pose
	var menu := CombatLinksMenuMotion.new()
	menu.page_changed()
	menu.tick(.05)
	if not _check(menu.pose(2,false).offset.y > menu.pose(0,false).offset.y,"page rows settle with bounded stagger"): return false
	menu.tick(.3)
	if not _check(menu.pose(2,false).offset == Vector2.ZERO and menu.pose(2,false).alpha == 1,"page transition settles exactly"): return false
	menu.selected()
	menu.tick(.13)
	if not _check(menu.pose(0,true).pulse > .99 and menu.pose(0,false).pulse == 0,"selection glow belongs only to selected card"): return false
	menu.tick(.3)
	return _check(not menu.is_animating() and menu.pose(0,true).pulse < .00001,"selection settles and stops requesting frames")

func _integration() -> bool:
	for hero in PrototypeCharacters.IDS:
		player.set_character(hero)
		player.link_feedback.reset()
		player.combat_links.windows.clear()
		player.combat_links.trigger("evade",weapons.equipment)
		var before: Dictionary = sandbox._capture_run_build()
		var rng := player.critical_rng.state
		var position := player.position
		var shape: Shape2D = player.get_node("CollisionShape2D").shape
		player._update_avatar_action_visual(.03)
		if not _check(player.link_feedback.active.has("evade") and player.link_feedback.bursts.size() == 1,"actual player update reads successful windows for both heroes"): return false
		if not _check(before == sandbox._capture_run_build() and player.critical_rng.state == rng and player.position == position and player.get_node("CollisionShape2D").shape == shape,"effects cannot change timers, damage, save, RNG or collision"): return false
		player.prepare_next_stage(player.position)
		player._update_avatar_action_visual(0)
		if not _check(player.link_feedback.bursts.is_empty() and player.link_feedback.active.has("evade"),"stage movement keeps indicators without replaying activation"): return false
	return true

func _menu() -> bool:
	var before: Dictionary = sandbox._capture_run_build()
	if not _check(controls.open_hero_status() and paused,"menu owns existing combat pause"): return false
	var view := CombatLinksView.layout(controls._safe_area_in_viewport())
	_tap(HeroStatusView.layout(controls._safe_area_in_viewport()).links.get_center())
	if not _check(controls.combat_link_menu_motion.page_elapsed == 0,"opening overlay starts page motion"): return false
	controls._process(.08)
	if not _check(controls.combat_link_menu_motion.page_elapsed > 0 and sandbox._capture_run_build() == before,"menu animation moves while combat remains frozen"): return false
	controls.notification(Control.NOTIFICATION_APPLICATION_PAUSED)
	var time: float = controls.combat_link_menu_motion.page_elapsed
	controls._process(.1)
	if not _check(controls.combat_link_menu_motion.page_elapsed == time,"app suspension freezes menu motion"): return false
	controls.notification(Control.NOTIFICATION_APPLICATION_RESUMED)
	_tap(view.cards[1].get_center())
	if not _check(controls.combat_link_menu_motion.selected_elapsed == 0,"actual card touch starts selection motion"): return false
	_tap(view.next.get_center())
	if not _check(controls.combat_link_menu_motion.page_elapsed == 0,"actual next page starts transition"): return false
	controls._process(.3)
	_tap(view.filters[2].get_center())
	if not _check(controls.combat_link_menu_motion.page_elapsed == 0,"filter restarts bounded transition"): return false
	controls._process(.3)
	if not _check(sandbox._capture_run_build() == before,"all visual/menu interactions preserve gameplay state"): return false
	_tap(view.close.get_center())
	controls.close_run_build()
	controls.advance_mode_timer_for_test(3.1)
	await process_frame
	return _check(not paused,"normal combat resume remains available")

func _screens() -> bool:
	var directory := OS.get_environment("LINK_ART_RENDER_DIR")
	if not _check(DisplayServer.get_name() != "headless" and not directory.is_empty(),"real display and art QA directory"): return false
	DirAccess.make_dir_recursive_absolute(directory)
	for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,800)]:
		root.size = dimensions
		root.content_scale_size = Vector2i(1920,1080)
		await process_frame
		controls.size = root.get_visible_rect().size
		controls._refresh_layout()
		if not controls.open_hero_status(): return false
		controls.hero_status_detail = "links"
		controls.combat_link_menu_motion.reset()
		for mode in ["active","dormant","locked"]:
			controls.combat_link_options = CombatLinksView.defaults()
			controls.combat_link_options.ownership = 1
			var state: Dictionary = controls.run_build_state
			var held := HeroStatusView.families(state)
			var fixture_ranks: Dictionary = state.growth.growth_ranks.duplicate()
			var fixture_windows: Dictionary = state.combat_links.duplicate()
			if mode == "locked":
				# Display-only empty-build fixture; underlying run stays intact.
				state.growth.growth_ranks = {}
				state.combat_links = {}
			elif mode == "active":
				for style in PrototypeCombatLinks.STYLES: state.combat_links[held[0]+"_link_"+style] = 1.5
			else: state.combat_links = {}
			for page in 2:
				controls.combat_link_options.page = page
				controls.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				if not _check(root.get_texture().get_image().save_png(directory.path_join("%s_%d_%dx%d.png" % [mode,page,dimensions.x,dimensions.y])) == OK,"actual imported icons/frames and text rendered"): return false
			state.growth.growth_ranks = fixture_ranks
			state.combat_links = fixture_windows
		if dimensions == Vector2i(1280,720):
			var view := CombatLinksView.layout(controls._safe_area_in_viewport())
			controls.set_process(false)
			for transition in ["page","selection"]:
				controls.combat_link_options = CombatLinksView.defaults()
				controls.combat_link_menu_motion.reset()
				_tap(view.next.get_center() if transition == "page" else view.cards[1].get_center())
				for frame in 7:
					controls._process(0 if frame == 0 else .05)
					controls.queue_redraw()
					await process_frame
					await RenderingServer.frame_post_draw
					if not _check(root.get_texture().get_image().save_png(directory.path_join("menu_%s_%02d.png" % [transition,frame])) == OK,"real menu transition frame saved"): return false
			controls.set_process(true)
		controls.close_run_build()
		controls.advance_mode_timer_for_test(3.1)
	return true

class FeedbackSample extends Node2D:
	var feedback := CombatLinkFeedback.new()
	func _draw() -> void: feedback.draw(self)

func _gallery() -> bool:
	controls.visible = false
	sandbox.visible = false
	(player.get_node("Camera2D") as Camera2D).enabled = false
	root.canvas_transform = Transform2D.IDENTITY
	root.size = Vector2i(1500,640)
	root.content_scale_size = Vector2i(1500,640)
	var background := ColorRect.new()
	background.color = Color("182c3b")
	background.size = Vector2(1500,640)
	root.add_child(background)
	var directory := OS.get_environment("LINK_ART_RENDER_DIR")
	for hero in PrototypeCharacters.IDS:
		var gallery := Node2D.new()
		root.add_child(gallery)
		var samples: Array[FeedbackSample] = []
		for index in 6:
			var node := FeedbackSample.new()
			node.position = Vector2((index%3)*500+250,(index/3)*310+230)
			gallery.add_child(node)
			var sprite := Sprite2D.new()
			HeroMovementAnimation.new().apply_frame(sprite,hero,"idle",0)
			node.add_child(sprite)
			var label := Label.new()
			label.text = hero.capitalize()+" · "+PrototypeCombatLinks.LABELS[index]
			label.position = Vector2((index%3)*500+35,(index/3)*310+20)
			gallery.add_child(label)
			samples.append(node)
		for frame in 26:
			for index in 6:
				var style: String = PrototypeCombatLinks.STYLES[index]
				var remaining := .85-frame*.05
				samples[index].feedback.update({"sword_link_"+style:remaining} if remaining > .00001 else {},0 if frame == 0 else .05)
				samples[index].queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			if not _check(root.get_texture().get_image().save_png(directory.path_join("motion_%s_%02d.png" % [hero,frame])) == OK,"six trigger motions and expiry rendered"): return false
		gallery.free()
	background.free()
	return true
