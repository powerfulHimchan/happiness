extends "res://tests/hero_stats_runtime_test.gd"

func _run() -> void:
	var rendering := OS.get_environment("HERO_STATUS_ART_RENDER_DIR")
	if not _art_catalog(): return
	var prefix := "user://gp830_art"
	store.save_path = prefix+"_checkpoint.json"
	legacy.save_path = prefix+"_meta.jsonl"
	journal.save_path = prefix+"_story.jsonl"
	store.clear_checkpoint()
	for suffix in ["_meta.jsonl","_records.jsonl","_abilities.jsonl","_story.jsonl"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix+suffix))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.story_journal_store = journal
	mastery_book = AbilityDiscoveryStore.new()
	mastery_book.save_path = prefix+"_abilities.jsonl"
	sandbox.ability_discovery_store = mastery_book
	sandbox.get_node("RecoveryOrbController").drop_chance = 0
	sandbox.get_node("LocalTestRecorder").record_path = prefix+"_records.jsonl"
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
	for id in PrototypeWeaponRewards.FAMILY_IDS:
		weapons.combat_for(id).set_process(false)
		weapons.combat_for(id).set_physics_process(false)
	sandbox.get_node("CombatFeedbackController").configure(0,false,false)
	if not rendering.is_empty():
		if not _check(DisplayServer.get_name() != "headless","real renderer for artwork QA"): return
		DirAccess.make_dir_recursive_absolute(rendering)
	for hero in PrototypeCharacters.IDS:
		controls.show_main_screen()
		if not _check(controls.begin_retry("sword" if hero == "roan" else "staff",5,"standard",hero,false,0,"bow" if hero == "roan" else "shield"),"both hero art paths with two distinct loadouts"): return
		var held := weapons.equipment.keys()
		var grades := {held[0]:2,held[1]:1}
		if not _check(weapons.set_equipment(grades),"rare and epic weapon frame content"): return
		if not rendering.is_empty():
			# Exercise Roan's active state and Lumi's armed state in the same visual panels.
			if hero == "roan":
				player.invincible = true
				(sandbox.get_node("Player/UltimateController") as UltimateController).register_precise_evade()
				player.invincible = false
			else: weapons.request_weapon_switch()
		var before: Dictionary = sandbox._capture_run_build()
		var rng_state := player.critical_rng.state
		var files := _art_files()
		for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,800)]:
			root.size = dimensions
			root.content_scale_size = Vector2i(1920,1080)
			await process_frame
			controls.size = root.get_visible_rect().size if not rendering.is_empty() else Vector2(dimensions)
			controls._refresh_layout()
			if not _layout_art(): return
			if not _check(controls.open_hero_status() and paused,"art status opens with existing pause ownership"): return
			var families := HeroStatusView.families(controls.run_build_state)
			for detail in ["","offense","defense","passive","weapon:"+String(families[0]),"weapon:"+String(families[1])]:
				controls.hero_status_detail = detail
				if not await _art_capture(rendering,"%s_%s_%dx%d" % [hero,detail.replace(":","_") if detail != "" else "overview",dimensions.x,dimensions.y]): return
			controls.close_run_build()
			controls.advance_mode_timer_for_test(3.1)
			if not _check(sandbox._capture_run_build() == before and player.critical_rng.state == rng_state and _art_files() == files,"new graphics and detail navigation never mutate combat/RNG/files"): return
			controls.show_main_screen()
			controls.show_new_run_preparation()
			controls.selected_character_id = hero
			if not _check(controls.current_screen_mode() == controls.ScreenMode.START_CHARACTER,"selection screen reached through real preparation flow"): return
			if not await _art_capture(rendering,"%s_selection_%dx%d" % [hero,dimensions.x,dimensions.y]): return
			controls._cancel_preparation()
			# Return to the same battle; preparation itself must not replace the selected hero.
			controls.screen_mode = controls.ScreenMode.COMBAT
			if not _check(sandbox._capture_run_build() == before and _art_files() == files,"hero selection badge browsing preserves active run"): return
	paused = false
	sandbox.free()
	print("GP-821–830 art runtime test: OK (%d assertions)" % stats_checks)
	quit(0)

func _art_catalog() -> bool:
	var textures: Array[Texture2D] = [HeroStatusArt.BACKGROUND,HeroStatusArt.MAIN_FRAME,HeroStatusArt.BACKUP_FRAME]
	for key in HeroStatusArt.ICONS: textures.append(HeroStatusArt.ICONS[key])
	if not _check(textures.size() == 11 and HeroStatusArt.STAT_IDS.size() == 6,"exactly ten new graphics"): return false
	var fingerprints := {}
	for texture in textures:
		var image := texture.get_image()
		if not _check(image != null and not image.is_empty() and image.get_used_rect().has_area(),"every SVG imports into nonempty artwork"): return false
		var fingerprint := image.get_data().hex_encode().sha256_text()
		if not _check(not fingerprints.has(fingerprint),"ten distinct images rather than duplicate placeholders"): return false
		fingerprints[fingerprint] = true
	for id in HeroStatusArt.ICONS:
		var texture: Texture2D = HeroStatusArt.ICONS[id]
		var image := texture.get_image()
		if not _check(texture.get_size() == Vector2(128,128) and image.get_pixel(0,0).a == 0 and image.get_pixel(64,64).a > .8,"crisp square badges with genuine transparent corners"): return false
	return _check(HeroStatusArt.detail_icon("passive","roan") == "roan" and HeroStatusArt.detail_icon("passive","lumi") == "lumi","traits use correct character-specific artwork")

func _layout_art() -> bool:
	var safe: Rect2 = controls._safe_area_in_viewport()
	var view := HeroStatusView.layout(safe)
	for index in HeroStatusArt.STAT_IDS.size():
		var areas := HeroStatusArt.stat_regions(safe,index)
		if not _check(view.stats.encloses(areas.icon) and view.stats.encloses(areas.label) and view.stats.encloses(areas.value) and not areas.icon.intersects(areas.label) and not areas.label.intersects(areas.value),"five badge/label/value rows remain separate inside stat panel"): return false
	var passive := HeroStatusArt.passive_regions(safe)
	if not _check(view.passive.encloses(passive.icon) and view.passive.encloses(passive.name) and view.passive.encloses(passive.status) and not passive.icon.intersects(passive.name) and not passive.icon.intersects(passive.status),"trait emblem never covers name or activation state"): return false
	for index in 2:
		var panel := RunPreparationView.box(safe,.055+index*.50,.605,.39,.128)
		var areas := HeroStatusArt.selection_regions(panel)
		for key in areas:
			if not _check(panel.encloses(areas[key]),"selection emblem and text stay within existing panel"): return false
		for key in ["name","effect","cooldown"]:
			if not _check(not areas.icon.intersects(areas[key]),"selection emblem never covers trait text"): return false
	return true

func _art_files() -> Array:
	var result := []
	for path in [store.save_path,legacy.save_path,journal.save_path,mastery_book.save_path,sandbox.get_node("LocalTestRecorder").record_path]:
		result.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray())
	return result

func _art_capture(folder: String,name: String) -> bool:
	controls.queue_redraw()
	await process_frame
	if folder.is_empty(): return true
	await RenderingServer.frame_post_draw
	return _check(root.get_texture().get_image().save_png(folder+"/"+name+".png") == OK,"actual art render: "+name)
