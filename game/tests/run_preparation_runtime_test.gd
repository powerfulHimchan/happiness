extends SceneTree

const SCENE := preload("res://tests/fixtures/legacy_movement_sandbox.tscn")
var checks := 0
var failures := 0
var scene: Node
var ui: Control
var output := ""

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("Preparation: "+label)
func tap(rect: Rect2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 77
	event.pressed = true
	event.position = rect.get_center()
	ui._input(event)
	event.pressed = false
	ui._input(event)
func escape() -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	ui._input(event)
func files() -> Array:
	var result := []
	for store in [scene.checkpoint_store,scene.boss_legacy_store,scene.achievement_store,scene.story_journal_store,scene.ability_discovery_store]:
		result.append(FileAccess.get_file_as_bytes(store.save_path) if FileAccess.file_exists(store.save_path) else PackedByteArray())
	return result
func capture(name: String) -> void:
	ui.queue_redraw()
	await process_frame
	if output.is_empty(): return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"real render: "+name)
func targets(rectangles: Array, safe: Rect2) -> void:
	rectangles = rectangles.filter(func(rect: Rect2): return rect.has_area())
	for i in rectangles.size():
		check(safe.encloses(rectangles[i]),"visible input inside safe area")
		for j in range(i+1,rectangles.size()): check(not rectangles[i].intersects(rectangles[j]),"visible inputs do not overlap")
func _run() -> void:
	output = OS.get_environment("PREPARATION_RENDER_DIR")
	if not output.is_empty():
		check(DisplayServer.get_name() != "headless","real display")
		DirAccess.make_dir_recursive_absolute(output)
	scene = SCENE.instantiate()
	for store in [scene.checkpoint_store,scene.boss_legacy_store,scene.achievement_store,scene.story_journal_store,scene.ability_discovery_store]:
		store.save_path = "user://preparation_"+store.get_script().resource_path.get_file()+".json"
	scene.get_node("LocalTestRecorder").record_path = "user://preparation_records.jsonl"
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	ui = scene.get_node("CanvasLayer/GroundMovementControls")
	var player: PrototypePlayer = scene.get_node("Player")
	var weapons: PrototypeWeaponController = scene.get_node("Player/PrototypeWeaponController")
	var original_files := files()
	var original_weapons := weapons.checkpoint_snapshot()
	var health := player.damage_receiver.health
	for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,800),Vector2i(2400,1080)]:
		root.size = dimensions
		await process_frame
		ui.size = ui.get_viewport_rect().size if not output.is_empty() else Vector2(dimensions)
		ui.show_main_screen()
		ui._refresh_layout()
		tap(ui.main_start_rect)
		check(ui.current_screen_mode() == ui.ScreenMode.START_CHARACTER,"main starts with hero selection")
		var safe: Rect2 = ui._safe_area_in_viewport()
		var hero := RunPreparationView.hero_layout(safe)
		check(not ui.character_detail_open and not ui.character_confirm_rect.has_area(), "initial choice hides profile and next target")
		ui._close_character_selection(true)
		check(ui.current_screen_mode() == ui.ScreenMode.START_CHARACTER, "cannot confirm without choosing a portrait")
		await capture("hero_choices_%dx%d" % [dimensions.x, dimensions.y])
		targets(hero.cards+[hero.back,hero.confirm,hero.story,hero.journal],safe)
		for character in PrototypeCharacters.IDS:
			if ui.character_detail_open: tap(ui.character_cancel_rect)
			tap(ui.character_card_rects[PrototypeCharacters.IDS.find(character)])
			check(ui.selected_character_id == character and ui.character_detail_open, "portrait opens selected profile")
			check(ui.character_card_rects.all(func(rect: Rect2): return not rect.has_area()), "hidden portrait has no target")
			var chosen: String = ui.selected_character_id
			tap(hero.cards[1 - PrototypeCharacters.IDS.find(character)])
			check(ui.selected_character_id == chosen, "hidden portrait cannot change selected hero")
			ui._process(.14)
			var reveal: float = ui.character_reveal_progress
			ui.notification(Control.NOTIFICATION_APPLICATION_PAUSED)
			ui._process(.5)
			check(ui.character_reveal_progress == reveal, "profile transition pauses with app")
			ui.notification(Control.NOTIFICATION_APPLICATION_RESUMED)
			ui._process(.01)
			check(ui.character_reveal_progress > reveal, "profile transition resumes")
			await capture("hero_transition_" + character + "_%dx%d" % [dimensions.x, dimensions.y])
			ui._process(.3)
			var story := HeroSelectionView.biography_layout(safe, character)
			check(story.lines.size() * story.line_height <= story.rect.size.y and "".join(story.lines) == PrototypeCharacters.biography(character), "complete biography fits without truncation")
			check(PrototypeCharacters.biography(character).length() >= 280 and PrototypeCharacters.biography(character).length() <= 340, "approved biography is approximately 300 characters")
			check(PrototypeCharacters.initial_combat_stats() == {"health":100,"attack":100,"defense":0,"critical_chance":0.0,"critical_damage":150.0}, "initial stats use gameplay defaults")
			check(files() == original_files and weapons.checkpoint_snapshot() == original_weapons and player.damage_receiver.health == health, "profile does not change current run or saves")
			await capture("hero_"+character+"_%dx%d"%[dimensions.x,dimensions.y])
			tap(ui.character_confirm_rect)
			check(ui.current_screen_mode() == ui.ScreenMode.START_WEAPON and ui.selected_character_id == character,"hero confirm opens weapon book")
			var view := RunPreparationView.weapon_layout(safe,false)
			targets(view.cards+[view.settings,view.character,view.back,view.confirm]+WeaponPreparationView.skill_regions(safe),safe)
			check(not ui.open_preparation_skill(-1) and not ui.open_preparation_skill(2), "invalid skill indices do not open modal")
			for family in PrototypeWeaponRewards.FAMILY_IDS:
				var index := PrototypeWeaponRewards.FAMILY_IDS.find(family)
				var card: Rect2 = ui.start_weapon_card_rects[index]
				# Upper icon selects primary; nested backup button remains a separate action.
				tap(Rect2(card.position,card.size*Vector2(1,.55)))
				check(ui.selected_starting_weapon == family and ui.selected_backup_weapon != family and ui.preview_weapon_id == family,"six distinct primary choices and preview sync")
				var first: Dictionary = ui.equipped_preview.snapshot(character,family,ui.preview_elapsed_s,view.preview)
				ui._process(.41)
				var second: Dictionary = ui.equipped_preview.snapshot(character,family,ui.preview_elapsed_s,view.preview)
				check(first.frame != second.frame and first.body != second.body and first.hand != second.hand and first.foot == second.foot and second.weapon_texture != null,"animated equipped hero for every family")
				var clock: float = ui.preview_elapsed_s
				ui.notification(Control.NOTIFICATION_APPLICATION_PAUSED)
				ui._process(.5)
				check(ui.preview_elapsed_s == clock,"preview pauses in background")
				ui.notification(Control.NOTIFICATION_APPLICATION_RESUMED)
				ui._process(.1)
				check(ui.preview_elapsed_s > clock,"preview resumes")
				await capture("weapon_"+character+"_"+family+"_%dx%d"%[dimensions.x,dimensions.y])
				var skill_ids := WeaponSkillPreview.ids(family)
				check(skill_ids.size() == 2 and skill_ids == PrototypeSkillRewards.defaults([family])[family], "weapon shows its actual two starting skills")
				for slot in 2:
					var skill: String = skill_ids[slot]
					var skill_area: Rect2 = ui.preparation_skill_rects[slot]
					# Both the icon and the name are inside the same skill action.
					tap(Rect2(skill_area.position + skill_area.size * Vector2(0, .63 if slot == 1 else 0), skill_area.size * Vector2(1, .35)))
					check(ui.preparation_skill_id == skill and ui.current_screen_mode() == ui.ScreenMode.START_WEAPON, "icon/name opens matching skill without leaving preparation")
					var skill_profile := WeaponSkillPreview.profile(skill)
					check(skill_profile.name == PrototypeSkillRewards.SKILLS[skill].display_name and not skill_profile.description.is_empty() and not skill_profile.effect.is_empty(), "description and effect agree with selected skill")
					check(WeaponPreparationArt.SKILLS[skill] is Texture2D and WeaponPreparationArt.SKILLS[skill].get_width() == 128, "individual characteristic icon imported")
					var selection := [ui.selected_starting_weapon,ui.selected_backup_weapon,ui.selected_character_id,ui.selected_run_mode]
					var frozen: float = ui.preview_elapsed_s
					ui._process(.5)
					check(ui.preview_elapsed_s == frozen, "skill description freezes equipped preview")
					tap(ui.start_weapon_confirm_rect)
					tap(ui.start_weapon_card_rects[(index+1)%6])
					tap(ui.start_backup_rects[(index+2)%6])
					tap(view.settings)
					check(ui.preparation_skill_id == skill and not ui.start_options_open and ui.current_screen_mode() == ui.ScreenMode.START_WEAPON and selection == [ui.selected_starting_weapon,ui.selected_backup_weapon,ui.selected_character_id,ui.selected_run_mode], "modal blocks underlying start, weapon, backup and settings")
					var popup := WeaponPreparationView.popup_layout(safe)
					check(safe.encloses(popup.panel) and popup.panel.encloses(popup.close) and popup.panel.encloses(popup.x) and not popup.close.intersects(popup.x), "skill dialog and close targets fit viewport")
					await capture("skill_"+character+"_"+skill+"_%dx%d"%[dimensions.x,dimensions.y])
					if dimensions.x == 2400: escape()
					else: tap(popup.x if slot == 0 else popup.close)
					check(ui.preparation_skill_id.is_empty() and ui.current_screen_mode() == ui.ScreenMode.START_WEAPON, "close/X/back dismisses only skill description")
					ui._process(.1)
					check(ui.preview_elapsed_s > frozen, "preview resumes after skill description closes")
					check(files() == original_files and weapons.checkpoint_snapshot() == original_weapons and player.damage_receiver.health == health, "skill inspection never changes current combat or saved state")
				tap(ui.start_backup_rects[index])
				check(ui.selected_backup_weapon == family and ui.selected_starting_weapon != family and ui.preview_elapsed_s == 0,"backup selection swaps duplicate primary and resets preview")
				check(files() == original_files and weapons.checkpoint_snapshot() == original_weapons and player.damage_receiver.health == health,"preview never changes combat or saves")
			# The overlay owns its inputs; underlying start/weapon targets cannot fire.
			tap(view.settings)
			check(ui.start_options_open,"settings button opens existing preparation options")
			check(not ui.open_preparation_skill(0) and ui.preparation_skill_id.is_empty(), "settings excludes skill modal")
			var option_clock: float = ui.preview_elapsed_s
			ui._process(.5)
			check(ui.preview_elapsed_s == option_clock,"settings pause the presentation clock")
			targets(view.lengths+[view.expedition,view.legacy,view.close]+view.memories,safe)
			var pair := [ui.selected_starting_weapon,ui.selected_backup_weapon]
			tap(ui.start_weapon_confirm_rect)
			check(ui.current_screen_mode() == ui.ScreenMode.START_WEAPON and [ui.selected_starting_weapon,ui.selected_backup_weapon] == pair,"overlay blocks underlying start button")
			tap(ui.start_length_rects[3])
			check(ui.selected_run_mode == "journey" and ui.selected_stage_limit == 10,"journey option preserved")
			await capture("options_"+character+"_%dx%d"%[dimensions.x,dimensions.y])
			tap(view.close)
			tap(view.settings)
			escape()
			check(not ui.start_options_open and ui.current_screen_mode() == ui.ScreenMode.START_WEAPON,"Escape closes settings first")
			if dimensions.x == 2400: escape()
			else: tap(ui.start_weapon_cancel_rect)
			check(ui.current_screen_mode() == ui.ScreenMode.START_CHARACTER and ui.selected_character_id == character,"weapon back keeps draft hero")
			var clock: float = ui.preview_elapsed_s
			ui._process(1)
			check(ui.preview_elapsed_s == clock,"hidden preview clock stops")
		if ui.character_detail_open:
			escape()
			check(not ui.character_detail_open and ui.current_screen_mode() == ui.ScreenMode.START_CHARACTER, "profile back restores two choices")
		if dimensions.x == 2400: escape()
		else: tap(ui.character_cancel_rect)
		check(ui.current_screen_mode() == ui.ScreenMode.MAIN and files() == original_files,"cancel returns to source without save writes")
	check(WeaponSkillPreview.profile("sword_dash").stats[0][1] == "35" and WeaponSkillPreview.profile("sword_dash").stats[1][1] == "6초", "dash description matches 35 base damage and six second cooldown")
	check(WeaponSkillPreview.profile("shield_guard").stats[0][1] == "전방 방어" and WeaponSkillPreview.profile("shield_counter").effect.contains("60"), "guard and conditional counter effects remain distinct")
	check(WeaponSkillPreview.profile("missing").is_empty(), "unknown skill has no invented description")
	# New-flow selections are propagated to a real run through existing creation code.
	ui.show_main_screen()
	tap(ui.main_start_rect)
	tap(ui.character_card_rects[1])
	tap(ui.character_confirm_rect)
	var sword: Rect2 = ui.start_weapon_card_rects[0]
	tap(Rect2(sword.position,sword.size*Vector2(1,.5)))
	tap(ui.start_backup_rects[3])
	tap(ui.start_weapon_confirm_rect)
	check(player.character_id == "lumi" and weapons.active_weapon_id == "sword" and weapons.equipment.has("staff") and scene.get_node("PrototypeGrowthController").run_active,"real run uses chosen hero and two weapons")
	paused = false
	scene.free()
	print("Preparation runtime test: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
