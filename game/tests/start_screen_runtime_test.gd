extends SceneTree

const SANDBOX := preload("res://tests/fixtures/legacy_movement_sandbox.tscn")
const STEM := "user://start_screen_test_"
var checks := 0
var failures := 0
var ui: Control


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("Start screen: " + label)


func _tap(rect: Rect2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 91
	event.position = rect.get_center()
	event.pressed = true
	ui._input(event)
	event.pressed = false
	ui._input(event)


func _run() -> void:
	var scene := SANDBOX.instantiate()
	for store in [scene.checkpoint_store, scene.boss_legacy_store, scene.achievement_store, scene.story_journal_store, scene.ability_discovery_store]:
		store.save_path = STEM + store.get_script().resource_path.get_file() + ".json"
	scene.get_node("LocalTestRecorder").record_path = STEM + "records.jsonl"
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	ui = scene.get_node("CanvasLayer/GroundMovementControls")
	_check(StartScreenView.TITLE == "다시 피는 새벽" and ProjectSettings.get_setting("application/config/name") == StartScreenView.TITLE, "new title and app name agree")
	_check(ProjectSettings.get_setting("application/boot_splash/show_image") == false, "Godot logo hidden")
	_check(ProjectSettings.get_setting("application/config/custom_user_dir_name") == "godot/app_userdata/Happiness Tale- Rewind to Dawn", "desktop save folder preserved across rename")
	_check(OS.get_user_data_dir().to_lower().ends_with("godot/app_userdata/happiness tale- rewind to dawn"), "resolved desktop save folder preserved")
	_check(StartScreenView.BACKGROUND.get_width() > 1600, "selected background imported")
	ui.configure_layout_store_path_for_test(STEM + "controls.json")
	_check(StartScreenView.WORDS.size() == 5, "five image-lettered menu actions")
	for texture in StartScreenView.WORDS.values():
		_check(texture is Texture2D and texture.get_width() > 100, "outlined lettering imports as image")
	var render_dir := OS.get_environment("START_SCREEN_RENDER_DIR")
	if not render_dir.is_empty():
		_check(DisplayServer.get_name() != "headless", "real renderer required for screenshots")
		DirAccess.make_dir_recursive_absolute(render_dir)
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1280, 800)]:
		root.size = dimensions
		root.content_scale_size = Vector2i(1920, 1080)
		await process_frame
		ui.size = ui.get_viewport_rect().size
		for saved in [false, true]:
			ui.checkpoint_available = saved
			ui.show_main_screen()
			ui._refresh_layout()
			_check(not ui.main_layout_rect.has_area(), "no invisible control-layout target on home")
			var safe: Rect2 = ui._safe_area_in_viewport()
			var buttons: Array[Rect2] = [ui.main_start_rect, ui.main_village_rect, ui.main_feedback_rect, ui.story_journal_open_rect]
			if saved:
				buttons.append(ui.main_continue_rect)
			else:
				_check(not ui.main_continue_rect.has_area(), "no invisible continue target without a save")
			for i in buttons.size():
				_check(safe.encloses(buttons[i]), "button within safe area")
				_check(buttons[i].size.y >= 60, "touch target remains usable")
				for j in range(i + 1, buttons.size()):
					_check(not buttons[i].intersects(buttons[j]), "menu touch targets do not overlap")
			var boxes := StartScreenView.layout(safe, saved)
			_check(boxes.title.end.y < buttons[0].position.y, "title above menu")
			_check(boxes.journal.end.y < boxes.notice.position.y, "footer below navigation")
			ui.queue_redraw()
			await process_frame
			if not render_dir.is_empty() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var file := "main_%dx%d_%s.png" % [dimensions.x, dimensions.y, "saved" if saved else "new"]
				var before := root.get_texture().get_image()
				_check(before.save_png(render_dir.path_join(file)) == OK, "capture " + file)
				for frame in 20:
					ui._process(0.1)
				ui.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var after := root.get_texture().get_image()
				_check(before.get_data() != after.get_data(), "background animation changes rendered pixels")
				_check(after.save_png(render_dir.path_join(file.replace(".png", "_motion.png"))) == OK, "capture animated background")
		ui.checkpoint_available = false
		ui.show_main_screen()
		_tap(ui.main_feedback_rect)
		_check(ui.current_screen_mode() == ui.ScreenMode.FEEDBACK_SETTINGS, "settings input")
		var settings_buttons: Array[Rect2] = [ui.feedback_sound_down_rect, ui.feedback_sound_up_rect, ui.feedback_vibration_rect, ui.feedback_shake_rect, ui.feedback_layout_rect, ui.feedback_records_clear_rect, ui.feedback_back_rect]
		for i in settings_buttons.size():
			_check(ui.feedback_panel_rect.encloses(settings_buttons[i]), "settings actions contained")
			for j in range(i + 1, settings_buttons.size()):
				_check(not settings_buttons[i].intersects(settings_buttons[j]), "settings actions do not overlap")
		if not render_dir.is_empty() and DisplayServer.get_name() != "headless":
			ui.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			_check(root.get_texture().get_image().save_png(render_dir.path_join("settings_%dx%d.png" % [dimensions.x, dimensions.y])) == OK, "capture settings")
		var preferences: Dictionary = ui.feedback_settings_snapshot()
		_tap(ui.feedback_layout_rect)
		_check(ui.current_screen_mode() == ui.ScreenMode.LAYOUT_EDITOR, "settings opens control layout")
		var original: Dictionary = ui.control_layout_snapshot()
		ui.set_control_opacity(0.45)
		ui.cancel_layout_editor()
		_check(ui.current_screen_mode() == ui.ScreenMode.FEEDBACK_SETTINGS, "cancel returns to settings")
		_check(ui.control_layout_snapshot().opacity == original.opacity, "cancel restores original layout")
		_tap(ui.feedback_layout_rect)
		_check(ui.start_layout_test(), "settings-origin layout preview starts")
		ui.advance_mode_timer_for_test(10.0)
		_check(ui.current_screen_mode() == ui.ScreenMode.LAYOUT_EDITOR, "preview returns to editor")
		ui.configure_layout_store_path_for_test("user://missing_title_test_directory/control.json")
		_check(not ui.apply_layout_editor() and ui.current_screen_mode() == ui.ScreenMode.LAYOUT_EDITOR, "failed save stays in editor")
		ui.configure_layout_store_path_for_test(STEM + "controls.json")
		_check(ui.apply_layout_editor(), "layout saves from settings")
		_check(ui.current_screen_mode() == ui.ScreenMode.FEEDBACK_SETTINGS, "save returns to settings")
		_check(ui.feedback_settings_snapshot() == preferences, "layout navigation retains settings")
		_tap(ui.feedback_layout_rect)
		if not render_dir.is_empty() and DisplayServer.get_name() != "headless":
			ui.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			_check(root.get_texture().get_image().save_png(render_dir.path_join("layout_%dx%d.png" % [dimensions.x, dimensions.y])) == OK, "capture layout editor")
		var back := InputEventKey.new()
		back.keycode = KEY_ESCAPE
		back.pressed = true
		ui._input(back)
		_check(ui.current_screen_mode() == ui.ScreenMode.FEEDBACK_SETTINGS, "editor back returns to settings")
		ui._input(back)
		_check(ui.current_screen_mode() == ui.ScreenMode.MAIN, "settings back returns home")
		ui.show_main_screen()
		_tap(ui.main_village_rect)
		_check(ui.current_screen_mode() == ui.ScreenMode.VILLAGE, "village input")
		ui.show_main_screen()
		_tap(ui.story_journal_open_rect)
		_check(ui.current_screen_mode() == ui.ScreenMode.STORY_JOURNAL, "memory journal input")
		ui.show_main_screen()
		_tap(ui.main_start_rect)
		_check(ui.current_screen_mode() == ui.ScreenMode.START_CHARACTER, "new journey starts at hero selection")
		ui.show_main_screen()
	# Ambience freezes off-title and while the app is inactive, without RNG use.
	seed(58123)
	var expected_random := randf()
	seed(58123)
	var clock: float = ui.start_backdrop.elapsed_s
	ui.show_feedback_settings()
	ui._process(0.1)
	_check(ui.start_backdrop.elapsed_s == clock and not ui.start_backdrop.visible, "animation hidden and frozen outside title")
	ui.show_main_screen()
	ui.preview_application_active = false
	ui._process(0.1)
	_check(ui.start_backdrop.elapsed_s == clock, "animation frozen in background")
	ui.preview_application_active = true
	ui._process(0.1)
	_check(ui.start_backdrop.elapsed_s > clock, "animation resumes on title")
	_check(randf() == expected_random, "ambience does not consume gameplay RNG")
	var elapsed: float = ui.start_backdrop.elapsed_s
	ui.start_backdrop.tick(-1.0, true, true)
	_check(ui.start_backdrop.elapsed_s == elapsed, "negative time does not rewind animation")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STEM + "controls.json"))
	print("Start screen runtime test: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
