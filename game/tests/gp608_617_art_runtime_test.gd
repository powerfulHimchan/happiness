extends SceneTree

const SANDBOX := preload("res://scenes/movement/ground_movement_sandbox.tscn")
const STEM := "user://gp608_617_"
var scene: Node2D
var ui: Control
var checks := 0
var failures := 0
var images := 0
var render_dir := ""

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("GP-608–617: " + label)

func _tap(position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 88
	event.position = position
	event.pressed = true
	ui._input(event)
	event.pressed = false
	ui._input(event)

func _files() -> Array:
	var result: Array = []
	for store in [scene.checkpoint_store, scene.boss_legacy_store, scene.achievement_store, scene.story_journal_store, scene.ability_discovery_store]:
		result.append(FileAccess.get_file_as_bytes(store.save_path) if FileAccess.file_exists(store.save_path) else PackedByteArray())
	return result

func _capture(name: String) -> void:
	ui.queue_redraw()
	await process_frame
	if render_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(render_dir.path_join(name + ".png")) == OK, "render " + name)
	images += 1

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args[0] == "render":
		render_dir = OS.get_environment("RELIC_RENDER_DIR")
		_check(not render_dir.is_empty() and DisplayServer.get_name() != "headless", "real display and render output required")
		if failures > 0:
			quit(1)
			return
		DirAccess.make_dir_recursive_absolute(render_dir)
	scene = SANDBOX.instantiate()
	scene.checkpoint_store.save_path = STEM + "checkpoint.json"
	scene.boss_legacy_store.save_path = STEM + "legacy.jsonl"
	scene.achievement_store.save_path = STEM + "achievements.jsonl"
	scene.story_journal_store.save_path = STEM + "story.jsonl"
	scene.ability_discovery_store.save_path = STEM + "abilities.jsonl"
	scene.get_node("LocalTestRecorder").record_path = STEM + "records.jsonl"
	root.add_child(scene)
	current_scene = scene
	await process_frame
	# Freeze the world while exercising the actual controls and drawing callbacks.
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	ui = scene.get_node("CanvasLayer/GroundMovementControls")
	var player: PrototypePlayer = scene.get_node("Player")
	var runner: PrototypeStageRunner = scene.get_node("StageRunner")
	var before := [player.damage_receiver.health, player.relic_state.duplicate(true), runner.checkpoint_snapshot().duplicate(true), _files()]
	var offers := PrototypeRelic.OFFERS.duplicate(true)
	_check(RelicArt.ICONS.size() == 10, "exactly ten new relic illustrations")
	for id in RelicArt.ICONS:
		_check(PrototypeRelic.valid_id(id) and RelicArt.ICONS[id].get_size() == Vector2(128,128), "imported artwork maps to existing relic: " + id)
	_check(not RelicArt.supports("unknown") and not RelicArt.supports(PrototypeRelic.COMPASS_ID), "other relics keep their existing presentation")
	for dimensions in [Vector2i(1280,720), Vector2i(1600,720), Vector2i(1280,800)]:
		root.size = dimensions
		root.content_scale_size = Vector2i(1920,1080)
		await process_frame
		ui.size = Vector2(dimensions) if render_dir.is_empty() else ui.get_viewport_rect().size
		ui._refresh_layout()
		var suffix := "_%dx%d" % [dimensions.x,dimensions.y]
		ui.show_main_screen()
		ui.show_village()
		_tap(ui.village_snapshot().layout.cards[1].get_center())
		_tap(ui.village_snapshot().tabs.relics.get_center())
		_check(ui.village_page == "relics", "actual memory shelter -> relic codex")
		ui.movement_metrics.growth_run_active = false
		var seen: Array[String] = []
		for page in ceili(float(PrototypeRelic.OFFERS.size()) / PrototypeRelic.CODEX_PAGE_SIZE):
			var view: Dictionary = ui.village_snapshot()
			for index in view.cards.size():
				var card: Dictionary = view.cards[index]
				seen.append(card.id)
				if RelicArt.supports(card.id):
					var rect: Rect2 = view.layout.cards[index]
					var regions := RelicArt.codex_regions(rect, card.lines.size())
					var values: Array = regions.values()
					for first in values.size():
						_check(rect.encloses(values[first]), "codex artwork/text contained in card")
						for second in range(first + 1, values.size()): _check(not values[first].intersects(values[second]), "codex artwork, title, status and effects never overlap")
			await _capture("codex_" + str(page) + suffix)
			_tap(view.pager.next.get_center())
		_check(seen.size() == PrototypeRelic.OFFERS.size(), "new and unchanged relics remain reachable through real paging")
		for id in RelicArt.ICONS:
			var index := 0
			for offer in PrototypeRelic.OFFERS:
				if offer.id == id: break
				index += 1
			ui.movement_metrics.growth_run_active = true
			ui.movement_metrics.relic = {"id":id, "used":false}
			ui.relic_codex_page = int(index / PrototypeRelic.CODEX_PAGE_SIZE)
			var card: Dictionary = ui.village_snapshot().cards[index % PrototypeRelic.CODEX_PAGE_SIZE]
			_check(card.open and card.status.contains("보유 중"), "owned presentation uses actual codex state: " + id)
			await _capture("owned_" + id + suffix)
		ui.movement_metrics.relic = {"id":PrototypeRelic.PHOENIX_ID, "used":true}
		ui.relic_codex_page = 0
		_check(ui.village_snapshot().cards[0].status.contains("사용 완료"), "spent phoenix feather remains visible")
		await _capture("spent_phoenix" + suffix)
		ui.show_stage_routes(2, 5, 0)
		ui.relic_offer_available = true
		ui._refresh_stage_routes()
		_tap(ui.relic_reward_open_rect.get_center())
		_check(ui.current_screen_mode() == 15, "actual relic selection open button")
		for page in ui.relic_reward_pages():
			ui._refresh_relic_reward_layout()
			for index in ui.relic_reward_card_rects.size():
				var rect: Rect2 = ui.relic_reward_card_rects[index]
				var offer: Dictionary = PrototypeRelic.OFFERS[page * PrototypeRelic.REWARD_PAGE_SIZE + index]
				if RelicArt.supports(offer.id):
					var icon := RelicArt.reward_region(rect)
					var title := Rect2(rect.position + Vector2(12, rect.size.y * 0.07), Vector2(rect.size.x - 24,42))
					_check(rect.encloses(icon) and not title.intersects(icon) and icon.end.y < rect.position.y + rect.size.y * 0.57, "reward art stays between title and effects")
				_tap(rect.get_center())
				_check(ui.selected_relic_offer == page * PrototypeRelic.REWARD_PAGE_SIZE + index, "actual relic card still selects original reward")
			await _capture("reward_" + str(page) + suffix)
			_tap(ui.relic_reward_next_rect.get_center())
		ui.relic_reward_page = 0
		ui.checkpoint_message = "획득 저장 실패 · 다시 시도해 주세요"
		await _capture("reward_error" + suffix)
		_tap(ui.relic_reward_cancel_rect.get_center())
		_check(ui.current_screen_mode() == 9, "cancel leaves reward available")
	_check(before == [player.damage_receiver.health, player.relic_state, runner.checkpoint_snapshot(), _files()], "drawing, browsing and selection preserve combat, relic and saved journals")
	_check(offers == PrototypeRelic.OFFERS, "art does not mutate offer IDs, ordering or effects")
	scene.queue_free()
	await process_frame
	print("GP-608–617 art runtime test: ", "OK" if failures == 0 else "FAILED", " (", checks, " assertions, ", images, " rendered screens)")
	quit(0 if failures == 0 else 1)
