extends SceneTree

const SANDBOX := preload("res://tests/fixtures/legacy_movement_sandbox.tscn")
const STEM := "user://gp718_767_"
var failures := 0
var assertions := 0
var scene: Node2D
var controls: Control

class FailingStore extends AchievementStore:
	var blocked := true
	func _append(event: Dictionary) -> Error:
		return ERR_CANT_CREATE if blocked else super._append(event)

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("GP-718–767: "+message)

func _remove(path: String) -> void:
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _ids(item: Dictionary) -> Array:
	if item.source == "research": return item.required.duplicate()
	var result := []
	for card in PrototypeAbilityCodex.definitions():
		if card.category == item.key and result.size() < item.target: result.append(card.id)
	return result

func _observed(ids: Array) -> Dictionary:
	var known := {}
	for id in ids: known[id] = true
	return PermanentAchievements.observations({}, {}, known)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "catalog"
	match phase:
		"catalog": _catalog()
		"seed": _seed()
		"resume": _resume()
		"live", "ui", "render":
			await _open()
			if phase == "live": await _live()
			elif phase == "ui": await _ui()
			else: await _render()
		_: _check(false, "unknown phase")
	if scene != null:
		paused = false
		scene.free()
	print("GP-718–767 runtime test: %s (%s, %d assertions)" % ["OK" if failures == 0 else "FAILED",phase,assertions])
	quit(0 if failures == 0 else 1)

func _catalog() -> void:
	var additions := AchievementResearch.definitions()
	_check(additions.size() == 42 and PermanentAchievements.DEFINITIONS.size() == 92, "forty-two goals extend the original fifty")
	var seen := {}
	for index in additions.size():
		var item := additions[index]
		_check(item.ticket == 718+index and not seen.has(item.id), "unique ordered ticket")
		seen[item.id] = true
		var ids := _ids(item)
		_check(ids.size() == item.target and PrototypeAbilityCodex.valid_ids(ids), "all goals reachable through real discoveries: "+item.id)
		_check(_observed(ids)[item.id] == item.target, "exact source meets threshold")
		for missing in ids:
			var partial := ids.duplicate()
			partial.erase(missing)
			partial.append("unknown")
			_check(_observed(partial)[item.id] == item.target-1, "every missing condition remains incomplete: "+item.id)
		if item.source == "research":
			_check(_observed(["sword_power", "bow_power", "nimble"])[item.id] == 0, "unrelated abilities never advance named requirements")
		else:
			var other := "bow" if item.key == "sword" else "sword"
			var ids_other := []
			for card in PrototypeAbilityCodex.definitions():
				if card.category == other: ids_other.append(card.id)
			_check(_observed(ids_other)[item.id] == 0, "family counting is isolated")
		_check(AchievementArt.CATEGORIES.has(item.category), "new categories use existing imported emblems")
	var duplicate_known := {"sword_power":true, "not_real":true, "sword_mastery_ground":false}
	_check(PermanentAchievements.observations({}, {}, duplicate_known).research_sword_study_5 == 1, "only validated true discoveries count")
	var view := AchievementBrowser.query({})
	_check(view.earned == 0 and view.locked == 92 and view.visible == 92, "fresh summary")
	view.cards[0].name = "mutated"
	_check(AchievementBrowser.query({}).cards[0].name != "mutated", "returned query is independent")

func _seed() -> void:
	var upgrade := AchievementStore.new()
	upgrade.save_path = STEM+"upgrade.jsonl"
	_remove(upgrade.save_path)
	_check(upgrade.observe({"route_wind":1,"abilities_5":4}) == OK and upgrade.select_title("route_wind") == OK, "old-format journal fixture")
	var prefix := FileAccess.get_file_as_bytes(upgrade.save_path)
	_check(upgrade.observe(_observed(["sword_mastery_ground","sword_tactic_ground_skill"])) == OK, "existing journal accepts new research progress")
	_check(upgrade.snapshot().title == "route_wind" and upgrade.snapshot().progress.route_wind == 1 and upgrade.snapshot().progress.abilities_5 == 4 and PermanentAchievements.earned(upgrade.snapshot(),"research_sword_ground"), "upgrade keeps original title and larger old progress")
	_check(FileAccess.get_file_as_bytes(upgrade.save_path).slice(0,prefix.size()) == prefix, "upgrade preserves exact prior journal bytes")
	for item in AchievementResearch.definitions():
		var book := AbilityDiscoveryStore.new()
		book.save_path = STEM+item.id+"_abilities.jsonl"
		var ledger := AchievementStore.new()
		ledger.save_path = STEM+item.id+".jsonl"
		_remove(book.save_path)
		_remove(ledger.save_path)
		var ids := _ids(item)
		var final_id: Variant = ids.pop_back()
		if not ids.is_empty(): _check(book.discover(ids) == OK, "partial discovery writes")
		_check(ledger.observe(PermanentAchievements.observations({}, {}, book.snapshot())) == OK, "partial progress persists")
		_check(not PermanentAchievements.earned(ledger.snapshot(),item.id) and ledger.select_title(item.id) == ERR_INVALID_DATA, "partial goal cannot equip title")
		_check(book.discover([final_id]) == OK, "last required ability is independently discovered")
		_check(ledger.observe(PermanentAchievements.observations({}, {}, book.snapshot())) == OK, "completed goal persists")
		_check(ledger.select_title(item.id) == OK and ledger.snapshot().title == item.id, "each cosmetic reward equips")

func _resume() -> void:
	var upgrade := AchievementStore.new()
	upgrade.save_path = STEM+"upgrade.jsonl"
	_check(upgrade.snapshot().title == "route_wind" and upgrade.snapshot().progress.abilities_5 == 4 and PermanentAchievements.earned(upgrade.snapshot(),"research_sword_ground"), "separate process restores migrated old and new goals")
	for item in AchievementResearch.definitions():
		var book := AbilityDiscoveryStore.new()
		book.save_path = STEM+item.id+"_abilities.jsonl"
		var ledger := AchievementStore.new()
		ledger.save_path = STEM+item.id+".jsonl"
		var state := ledger.snapshot()
		_check(PermanentAchievements.earned(state,item.id) and state.title == item.id, "separate process restores goal and title")
		var before := FileAccess.get_file_as_bytes(ledger.save_path)
		_check(ledger.observe(PermanentAchievements.observations({}, {}, book.snapshot())) == OK and ledger.observe({item.id:0}) == OK and FileAccess.get_file_as_bytes(ledger.save_path) == before, "no duplicate event or regression")

func _open() -> void:
	scene = SANDBOX.instantiate()
	for pair in [[scene.achievement_store,"main"],[scene.ability_discovery_store,"abilities"],[scene.boss_legacy_store,"legacy"],[scene.story_journal_store,"story"]]:
		pair[0].save_path = STEM+String(pair[1])+".jsonl"
		_remove(pair[0].save_path)
	scene.checkpoint_store.save_path = STEM+"checkpoint.json"
	_remove(scene.checkpoint_store.save_path)
	scene.get_node("LocalTestRecorder").record_path = STEM+"records.jsonl"
	root.add_child(scene)
	current_scene = scene
	await process_frame
	controls = scene.get_node("CanvasLayer/GroundMovementControls")
	controls.show_main_screen()
	controls.show_village()
	controls.village_page = "achievements"

func _live() -> void:
	for hero in ["roan","lumi"]:
		_check(scene.get_node("Player").set_character(hero), "select actual hero")
		for item in AchievementResearch.definitions():
			_remove(scene.ability_discovery_store.save_path)
			_remove(scene.achievement_store.save_path)
			_check(scene._sync_achievements() == OK, "fresh live snapshot")
			var ids := _ids(item)
			var final_id: Variant = ids.pop_back()
			if not ids.is_empty(): _check(scene._record_abilities(ids) == OK, "live partial discoveries")
			_check(not PermanentAchievements.earned(scene.achievement_store.snapshot(),item.id), "live partial goal remains locked")
			_check(scene._record_abilities([final_id]) == OK and PermanentAchievements.earned(scene.achievement_store.snapshot(),item.id), "live callback completes "+hero+"/"+item.id)
			_check(scene._select_achievement_title(item.id) and scene.achievement_store.snapshot().title == item.id, "live cosmetic reward persists")
	controls.achievement_filter = 3
	var equipped: Dictionary = controls.village_snapshot()
	_check(equipped.cards[0].id == "research_nimble_master", "equipped filter shows actual persisted title")
	_tap(equipped.layout.cards[0].get_center())
	_check(scene.achievement_store.snapshot().title == "" and controls.village_snapshot().cards[0].id == "", "filtered title touch clears and becomes empty")
	controls._reset_achievement_browser()
	var previous: Dictionary = scene.achievement_store.snapshot()
	controls.show_main_screen()
	controls.begin_retry()
	_check(scene.achievement_store.snapshot() == previous, "new challenge preserves permanent discoveries")
	controls.show_main_screen()
	controls.show_village()
	controls.village_page = "achievements"
	var failing := FailingStore.new()
	failing.save_path = STEM+"failed.jsonl"
	_remove(failing.save_path)
	scene.achievement_store = failing
	_check(scene._sync_achievements() != OK and not controls.achievement_message.is_empty() and failing.snapshot().progress.is_empty(), "failed optional ledger never reports false achievement")
	controls.achievement_filter = 3
	var empty: Dictionary = controls.village_snapshot()
	_check(empty.cards[0].id == "", "equipped filter can be empty during retry")
	failing.blocked = false
	_tap(empty.layout.cards[0].get_center())
	_check(controls.achievement_message.is_empty() and not failing.snapshot().progress.is_empty() and failing.snapshot().title == "", "empty card retries progress without equipping a title")

func _tap(point: Vector2) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 73
	touch.position = point
	touch.pressed = true
	controls._input(touch)
	touch.pressed = false
	controls._input(touch)

func _fixture() -> Dictionary:
	var state := {"progress":{}, "title":"research_sword_ground"}
	for item in PermanentAchievements.DEFINITIONS:
		state.progress[item.id] = item.target if item.source == "research" else maxi(0,item.target-1)
	return state

func _ui() -> void:
	var state := _fixture()
	controls.update_achievement_status(state)
	var original := state.duplicate(true)
	var player: PrototypePlayer = scene.get_node("Player")
	var combat := [player.damage_receiver.health,player.damage_receiver.max_health,player.growth_damage(100,"sword"),scene.get_node("StageRunner").checkpoint_snapshot()]
	var ledger_path: String = scene.achievement_store.save_path
	var bytes := FileAccess.get_file_as_bytes(ledger_path) if FileAccess.file_exists(ledger_path) else PackedByteArray()
	for dimensions in [Vector2(1280,720),Vector2(1600,720),Vector2(1280,800),Vector2(2400,1080)]:
		controls.size = dimensions
		controls._refresh_layout()
		controls._reset_achievement_browser()
		for f in AchievementBrowser.FILTERS.size():
			for c in AchievementBrowser.categories().size():
				for s in AchievementBrowser.SORTS.size():
					var view: Dictionary = controls.village_snapshot()
					_check(controls.achievement_filter == f and controls.achievement_category == c and controls.achievement_sort == s, "real toolbar cycles all combinations")
					var expected := AchievementBrowser.query(state,f,c,s)
					_check(view.achievement_view == expected, "screen displays selected query")
					for card in expected.cards:
						_check((f != 1 or card.open) and (f != 2 or not card.open) and (f != 3 or card.selected), "independent status filter predicate")
						_check(c == 0 or card.category == AchievementBrowser.categories()[c], "independent category predicate")
					_check(view.codex_pages == maxi(1,ceili(float(expected.visible)/3.0)) and view.codex_page == 0, "query resets page and empty query has one page")
					var regions: Array = view.layout.cards.duplicate()
					regions.append_array(view.tabs.values())
					regions.append_array(view.achievement_toolbar.values())
					regions.append_array(view.pager.values())
					regions.append_array([view.layout.back,view.layout.start])
					var safe: Rect2 = controls.layout_snapshot().safe
					for i in regions.size():
						_check(safe.encloses(regions[i]), "safe touch region")
						for j in range(i+1,regions.size()): _check(not regions[i].intersects(regions[j]), "nonoverlapping touch regions")
					if expected.visible == 0: _check(view.cards.size() == 1 and view.cards[0].id == "", "empty filter placeholder")
					for i in range(1,expected.cards.size()):
						var a: Dictionary = expected.cards[i-1]
						var b: Dictionary = expected.cards[i]
						if s == 1: _check(float(a.progress)/a.target >= float(b.progress)/b.target, "descending progress")
						if s == 2: _check(String(a.name).naturalnocasecmp_to(b.name) <= 0, "ascending names")
						if s == 3: _check(AchievementBrowser._group(a) <= AchievementBrowser._group(b), "recommended: equipped, incomplete, earned")
					_tap(view.achievement_toolbar.sort.get_center())
				_tap(controls.village_snapshot().achievement_toolbar.category.get_center())
			_tap(controls.village_snapshot().achievement_toolbar.filter.get_center())
		controls.achievement_page = 999
		var last: Dictionary = controls.village_snapshot()
		_check(last.codex_page == last.codex_pages-1, "upper page clamp")
		_tap(last.achievement_toolbar.filter.get_center())
		_check(controls.achievement_page == 0, "filter changes reset a deep page")
		_tap(controls.village_snapshot().tabs.history.get_center())
		_tap(controls.village_snapshot().tabs.achievements.get_center())
		_check(controls.achievement_page == 0 and controls.achievement_filter == 0 and controls.achievement_category == 0 and controls.achievement_sort == 0, "reentry resets view state")
	_check(controls.achievement_state == original and bytes == (FileAccess.get_file_as_bytes(ledger_path) if FileAccess.file_exists(ledger_path) else PackedByteArray()), "query and UI never mutate progress or ledger")
	_check(combat == [player.damage_receiver.health,player.damage_receiver.max_health,player.growth_damage(100,"sword"),scene.get_node("StageRunner").checkpoint_snapshot()], "browsing preserves live combat state")
	var earned := PermanentAchievements.earned_count(state)
	_check(earned == 30, "known fixture contains thirty earned research goals")
	_check(AchievementBrowser.query(state,1).visible == earned and AchievementBrowser.query(state,2).visible == 92-earned and AchievementBrowser.query(state,3).visible == 1, "summary and status counts agree")

func _render() -> void:
	var output := OS.get_environment("ACHIEVEMENT_RENDER_DIR")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		_check(false, "real renderer and output required")
		return
	DirAccess.make_dir_recursive_absolute(output)
	controls.update_achievement_status(_fixture())
	for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,800)]:
		root.size = dimensions
		root.content_scale_size = Vector2i(1920,1080)
		for mode in ["research", "equipped", "empty", "recommended", "support"]:
			controls._reset_achievement_browser()
			match mode:
				"research": controls.achievement_page = 17
				"equipped": controls.achievement_filter = 3
				"empty":
					controls.achievement_filter = 3
					controls.achievement_category = 1
				"recommended": controls.achievement_sort = 3
				"support": controls.achievement_category = AchievementBrowser.categories().find("공용 연구")
			controls.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			_check(root.get_texture().get_image().save_png("%s/%s_%dx%d.png" % [output,mode,dimensions.x,dimensions.y]) == OK, "render "+mode)
