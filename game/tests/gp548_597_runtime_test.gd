extends SceneTree

const SANDBOX := preload("res://scenes/movement/ground_movement_sandbox.tscn")
const STEM := "user://gp548_597_"
var assertions := 0
var failures := 0
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
		printerr("GP-548–597: " + message)

func _remove(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))

func _ledger(id: String) -> AchievementStore:
	var ledger := AchievementStore.new()
	ledger.save_path = STEM + id + ".jsonl"
	return ledger

func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "catalog"
	match phase:
		"catalog": _catalog()
		"seed":
			_seed_sources()
			await _open_scene()
			_check(PermanentAchievements.earned_count(scene.achievement_store.snapshot()) == PermanentAchievements.DEFINITIONS.size(), "existing durable sources migrate all ninety-two goals at startup")
			await _ui(true)
		"resume":
			var before := _bytes(STEM + "main.jsonl")
			await _open_scene()
			_check(_bytes(STEM + "main.jsonl") == before, "startup does not append duplicate progress")
			_check(scene.achievement_store.snapshot().title == "secret_archive", "title survives a separate process")
			await _ui(false)
			var state: Dictionary = scene.achievement_store.snapshot()
			scene.test_recorder.clear_records()
			controls.show_main_screen()
			controls.begin_retry()
			_check(scene.achievement_store.snapshot() == state, "new run and telemetry deletion preserve earned progress and title")
			_check(scene.checkpoint_store.load_checkpoint().is_empty(), "achievements do not create a run checkpoint")
		"live": await _live()
		"failure": await _failure()
		"corrupt": _corrupt()
		"render":
			await _open_scene()
			await _render()
		_: _check(false, "unknown phase")
	if scene != null:
		paused = false
		scene.free()
	print("GP-548–597 runtime test: %s (%s, %d assertions)" % ["OK" if failures == 0 else "FAILED", phase, assertions])
	quit(0 if failures == 0 else 1)

func _catalog() -> void:
	var definitions := PermanentAchievements.DEFINITIONS
	_check(definitions.size() == 92, "original fifty plus forty-two research goals")
	var seen := {}
	var zero := PermanentAchievements.observations({}, {}, {})
	_check(zero.values().all(func(v: Variant) -> bool: return v == 0), "fresh player receives no achievements")
	var legacy := {"routes":{}, "jobs":{}, "unlocked":{}, "guardian_companion":true}
	for id in PrototypeRouteAtlas.IDS: legacy.routes[id] = true
	for job in PrototypeJobProgress.JOBS + PrototypeJobProgress.ADVANCED_JOBS: legacy.jobs[job.id] = true
	for id in ["clockwork_guard", "core_echo"]: legacy.unlocked[id] = true
	var story := {"fragments":{}, "endings":{}, "secrets":{FinalRitual.SECRET_SCENE:true}, "expedition_clears":{}}
	for id in PrototypeStory.FRAGMENTS: story.fragments[id] = true
	for id in [ArrivalEnding.ID] + FinalRitual.IDS: story.endings[id] = {"run_id":"old"}
	for level in range(1, 6): story.expedition_clears[str(level)] = level
	var abilities := {}
	for card in PrototypeAbilityCodex.definitions(): abilities[card.id] = true
	var full := PermanentAchievements.observations(legacy, story, abilities)
	_check(AchievementStore.valid_progress(full), "full observations satisfy bounded ledger schema")
	var all_ids: Array = abilities.keys()
	for index in definitions.size():
		var item: Dictionary = definitions[index]
		_check(not seen.has(item.id) and item.ticket == (548 + index if index < 50 else 718 + index - 50), "unique ordered feature ticket: " + item.id)
		seen[item.id] = true
		_check(full[item.id] == item.target, "real source can complete: " + item.id)
		var ledger := _ledger(item.id)
		_remove(ledger.save_path)
		_check(ledger.observe({item.id:0}) == OK and not FileAccess.file_exists(ledger.save_path), "zero progress does not write: " + item.id)
		_check(ledger.select_title(item.id) == ERR_INVALID_DATA, "locked title cannot equip: " + item.id)
		if item.target > 1:
			_check(ledger.observe({item.id:item.target - 1}) == OK and not PermanentAchievements.earned(ledger.snapshot(), item.id), "partial threshold stays locked: " + item.id)
		_check(ledger.observe({item.id:item.target}) == OK and PermanentAchievements.earned(ledger.snapshot(), item.id), "exact threshold unlocks: " + item.id)
		var bytes := _bytes(ledger.save_path)
		_check(ledger.observe({item.id:item.target}) == OK and ledger.observe({item.id:0}) == OK and _bytes(ledger.save_path) == bytes, "no duplicates or regressions: " + item.id)
		_check(ledger.select_title(item.id) == OK and ledger.snapshot().title == item.id, "cosmetic reward equips: " + item.id)
		_check(_ledger(item.id).snapshot() == ledger.snapshot(), "separate store restores title: " + item.id)
		_check(ledger.select_title("") == OK and ledger.snapshot().title == "", "cosmetic reward clears: " + item.id)
		if item.source == "abilities":
			var subset := {}
			for id in all_ids.slice(0, item.target - 1): subset[id] = true
			subset.unknown = true
			_check(PermanentAchievements.observations({}, {}, subset)[item.id] == item.target - 1, "unknown IDs cannot meet ability threshold")
	for family in PermanentAchievements.FAMILY_NAMES:
		var subset := {}
		for card in PrototypeAbilityCodex.definitions():
			if card.category == family and subset.size() < 2: subset[card.id] = true
		_check(PermanentAchievements.observations({}, {}, subset)["study_"+family] == 2, "family discovery partial threshold: " + family)
		for other in PermanentAchievements.FAMILY_NAMES:
			if other != family: _check(PermanentAchievements.observations({}, {}, subset)["study_"+other] == 0, "family discoveries remain independent")
	for invalid in [null, [], {"unknown":1}, {"route_wind":true}, {"route_wind":-1}, {"route_wind":0.5}, {"route_wind":2}, {"route_wind":1, "unknown":1}]:
		_check(not AchievementStore.valid_progress(invalid), "reject malformed/mixed progress atomically")

func _seed_sources() -> void:
	for name in ["main.jsonl", "legacy.jsonl", "story.jsonl", "abilities.jsonl", "checkpoint.json", "records.jsonl"]: _remove(STEM + name)
	var legacy := BossLegacyStore.new()
	legacy.save_path = STEM + "legacy.jsonl"
	_check(legacy.discover_routes(PrototypeRouteAtlas.IDS) == OK, "actual route journal")
	for job in PrototypeJobProgress.JOBS + PrototypeJobProgress.ADVANCED_JOBS: _check(legacy.discover_job(job.id) == OK, "actual job discovery: " + job.id)
	_check(legacy.grant("achievement-rescue", "rescue") == OK and legacy.grant("achievement-destroy", "destroy") == OK, "actual two memory rewards")
	_check(legacy.grant_guardian("achievement-guardian", "rescue") == OK, "actual guardian companion journal")
	var story := StoryJournalStore.new()
	story.save_path = STEM + "story.jsonl"
	_check(story.record_fragments(PrototypeStory.FRAGMENTS.keys()) == OK, "actual fragment journal")
	for id in [ArrivalEnding.ID] + FinalRitual.IDS: _check(story.record_ending("achievement-ending-"+id, id, "roan", "rescue") == OK, "actual ending journal: " + id)
	for level in range(1, 6):
		var run_id := "achievement-expedition-" + str(level)
		_check(story.record_ending(run_id, ArrivalEnding.ID, "lumi", "destroy") == OK and story.record_expedition_clear(run_id, level) == OK, "actual expedition journal")
	_check(story.record_secret(FinalRitual.SECRET_SCENE) == OK, "actual secret journal")
	var book := AbilityDiscoveryStore.new()
	book.save_path = STEM + "abilities.jsonl"
	var ids: Array = []
	for card in PrototypeAbilityCodex.definitions(): ids.append(card.id)
	_check(book.discover(ids) == OK, "actual complete ability discovery journal")

func _open_scene() -> void:
	scene = SANDBOX.instantiate()
	scene.achievement_store.save_path = STEM + "main.jsonl"
	scene.boss_legacy_store.save_path = STEM + "legacy.jsonl"
	scene.story_journal_store.save_path = STEM + "story.jsonl"
	scene.ability_discovery_store.save_path = STEM + "abilities.jsonl"
	scene.checkpoint_store.save_path = STEM + "checkpoint.json"
	scene.get_node("LocalTestRecorder").record_path = STEM + "records.jsonl"
	root.add_child(scene)
	current_scene = scene
	await process_frame
	controls = scene.get_node("CanvasLayer/GroundMovementControls")
	controls.show_main_screen()
	controls.show_village()

func _tap(position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 76
	event.position = position
	event.pressed = true
	controls._input(event)
	event.pressed = false
	controls._input(event)

func _ui(select_all: bool) -> void:
	var player: PrototypePlayer = scene.get_node("Player")
	var runner: PrototypeStageRunner = scene.get_node("StageRunner")
	var combat := [player.damage_receiver.health, player.damage_receiver.max_health, player.growth_damage(100, "sword"), runner.checkpoint_snapshot().duplicate(true)]
	var source_bytes := [_bytes(STEM+"legacy.jsonl"), _bytes(STEM+"story.jsonl"), _bytes(STEM+"abilities.jsonl"), _bytes(STEM+"checkpoint.json")]
	for dimensions in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 800)]:
		controls.size = dimensions
		controls._refresh_layout()
		controls.village_page = "village"
		_tap(controls.village_snapshot().layout.cards[2].get_center())
		_tap(controls.village_snapshot().tabs.achievements.get_center())
		_check(controls.village_page == "achievements" and controls.achievement_page == 0, "real plaza -> achievement tab")
		var before := _bytes(scene.achievement_store.save_path)
		var seen: Array[String] = []
		for page in ceili(float(PermanentAchievements.DEFINITIONS.size()) / 3.0):
			var view: Dictionary = controls.village_snapshot()
			_check(view.codex_page == page and view.codex_pages == ceili(float(PermanentAchievements.DEFINITIONS.size()) / 3.0) and view.cards.size() == (2 if page == view.codex_pages - 1 else 3), "all ninety-two cards, including last partial page")
			var rects: Array = view.layout.cards.duplicate()
			rects.append_array(view.tabs.values())
			rects.append_array(view.achievement_toolbar.values())
			rects.append_array(view.pager.values())
			rects.append_array([view.layout.back, view.layout.start])
			if controls.checkpoint_available: rects.append(view.layout["continue"])
			var safe: Rect2 = controls.layout_snapshot().safe
			for i in rects.size():
				_check(safe.encloses(rects[i]), "card/button/tab stays in safe area")
				for j in range(i+1, rects.size()): _check(not rects[i].intersects(rects[j]), "touch regions never overlap")
			for i in view.cards.size():
				var card: Dictionary = view.cards[i]
				_check(card.open and card.progress == card.target, "earned card uses persisted state")
				var regions := AchievementArt.regions(view.layout.cards[i])
				var category := String(PermanentAchievements.definition(card.id).category)
				_check(AchievementArt.CATEGORIES.has(category) and AchievementArt.ICONS.has(AchievementArt.symbol(card)), "every achievement category has an imported emblem: " + card.id)
				for area in regions.values():
					_check(view.layout.cards[i].encloses(area), "art and text stay within card")
				var keys: Array = regions.keys()
				for first in keys.size():
					for second in range(first + 1, keys.size()):
						_check(not regions[keys[first]].intersects(regions[keys[second]]), "emblem, category, title, details and bar do not overlap")
				seen.append(String(card.id))
				if select_all and dimensions == Vector2(1280, 720):
					_tap(view.layout.cards[i].get_center())
					_check(scene.achievement_store.snapshot().title == card.id, "actual title card equips: " + card.id)
					_tap(view.layout.cards[i].get_center())
					_check(scene.achievement_store.snapshot().title == "", "same title card clears")
			controls.queue_redraw()
			await process_frame
			_tap(view.pager.next.get_center())
		_check(seen.size() == PermanentAchievements.DEFINITIONS.size() and controls.achievement_page == ceili(float(PermanentAchievements.DEFINITIONS.size()) / 3.0) - 1, "page boundary cannot skip or exceed content")
		for ignored in 40: _tap(controls.village_snapshot().pager.previous.get_center())
		_check(controls.achievement_page == 0, "previous page lower bound")
		if not select_all or dimensions != Vector2(1280, 720): _check(_bytes(scene.achievement_store.save_path) == before, "read-only page navigation writes no ledger")
		_tap(controls.village_snapshot().tabs.history.get_center())
		_tap(controls.village_snapshot().tabs.achievements.get_center())
		_check(controls.achievement_page == 0, "tab return resets to first page")
	_check(source_bytes == [_bytes(STEM+"legacy.jsonl"), _bytes(STEM+"story.jsonl"), _bytes(STEM+"abilities.jsonl"), _bytes(STEM+"checkpoint.json")], "all browsing/title changes preserve source journals and checkpoint")
	_check(combat == [player.damage_receiver.health, player.damage_receiver.max_health, player.growth_damage(100, "sword"), runner.checkpoint_snapshot()], "cosmetic rewards preserve health, damage and stage state")
	if select_all:
		controls.achievement_page = 16
		var last: Dictionary = controls.village_snapshot()
		_tap(last.layout.cards[1].get_center())
		_check(scene.achievement_store.snapshot().title == "secret_archive", "last feature title selected for separate-process restore")

func _live() -> void:
	# Replace each authoritative journal with a fresh live fixture after scene startup.
	await _open_scene()
	for pair in [[scene.achievement_store, "live-achievements"], [scene.ability_discovery_store, "live-abilities"], [scene.story_journal_store, "live-story"], [scene.boss_legacy_store, "live-legacy"]]:
		pair[0].save_path = STEM + String(pair[1]) + ".jsonl"
		_remove(pair[0].save_path)
	_check(scene._sync_achievements() == OK and PermanentAchievements.earned_count(scene.achievement_store.snapshot()) == 0, "fresh live fixtures start locked")
	for id in ["sword_power", "sword_mastery_ground", "sword_mastery_air"]:
		_check(scene._record_abilities([id]) == OK, "real ability discovery callback")
	_check(PermanentAchievements.earned(scene.achievement_store.snapshot(), "study_sword"), "third distinct sword ability automatically unlocks its goal")
	_check(not PermanentAchievements.earned(scene.achievement_store.snapshot(), "study_bow"), "live discovery does not unlock another family")
	_check(scene._discover_job("vanguard") == OK and PermanentAchievements.earned(scene.achievement_store.snapshot(), "job_vanguard"), "real job callback unlocks job goal")
	scene._record_route_history([{"route":"wind"}])
	_check(PermanentAchievements.earned(scene.achievement_store.snapshot(), "route_wind"), "real route record callback unlocks route goal")
	_check(scene.boss_legacy_store.grant("live-knight", "rescue") == OK, "persist real knight rescue")
	scene._update_boss_legacy_status()
	_check(PermanentAchievements.earned(scene.achievement_store.snapshot(), "memory_clockwork_guard"), "memory refresh unlocks permanent bond goal")
	_check(scene.story_journal_store.record_ending("live-ending", ArrivalEnding.ID, "roan", "rescue") == OK, "persist real ending")
	scene._update_story_status()
	_check(PermanentAchievements.earned(scene.achievement_store.snapshot(), "ending_arrival"), "story refresh unlocks ending goal")
	var state: Dictionary = scene.achievement_store.snapshot()
	var bad_book := AbilityDiscoveryStore.new()
	bad_book.save_path = "user://gp548_missing/book.jsonl"
	scene.ability_discovery_store = bad_book
	_check(scene._record_abilities(["bow_power"]) != OK and scene.achievement_store.snapshot() == state, "failed source journal never produces achievement progress")
	controls.village_page = "achievements"
	_check(scene._select_achievement_title("route_wind"), "earned live title equips")
	_check(not scene._select_achievement_title("route_forest"), "unearned live title remains locked")


func _failure() -> void:
	await _open_scene()
	var failing := FailingStore.new()
	failing.save_path = scene.achievement_store.save_path
	scene.achievement_store = failing
	var before := _bytes(failing.save_path)
	controls.village_page = "achievements"
	_check(not scene._select_achievement_title("route_wind") and not controls.achievement_message.is_empty() and _bytes(failing.save_path) == before, "failed title write preserves selection and offers retry")
	failing.blocked = false
	_check(scene._select_achievement_title("route_wind") and controls.achievement_message.is_empty(), "same action retries and persists successfully")
	var locked := _ledger("failed-progress")
	_remove(locked.save_path)
	failing = FailingStore.new()
	failing.save_path = locked.save_path
	scene.achievement_store = failing
	_check(scene._sync_achievements() != OK and PermanentAchievements.earned_count(failing.snapshot()) == 0, "failed progress write never pretends to unlock")
	var original_book: AbilityDiscoveryStore = scene.ability_discovery_store
	var fresh_book := AbilityDiscoveryStore.new()
	fresh_book.save_path = STEM + "nonblocking-abilities.jsonl"
	_remove(fresh_book.save_path)
	scene.ability_discovery_store = fresh_book
	_check(scene._record_abilities(["sword_power"]) == OK and fresh_book.snapshot().has("sword_power"), "optional achievement failure does not block real ability recording")
	scene.ability_discovery_store = original_book
	failing.blocked = false
	_check(scene._sync_achievements() == OK and PermanentAchievements.earned_count(failing.snapshot()) == PermanentAchievements.DEFINITIONS.size(), "progress write recovers from authoritative discoveries")
	controls.show_main_screen()
	before = _bytes(failing.save_path)
	_check(not scene._select_achievement_title("route_wind") and _bytes(failing.save_path) == before, "title selection outside achievements is rejected")
	var state := failing.snapshot()
	failing.save_path = "user://gp548_missing/sub/ledger.jsonl"
	_check(failing.observe({"route_wind":1}) != OK, "missing parent is a real filesystem failure")
	_check(locked.snapshot() == state, "real filesystem failure leaves previous file intact")

func _corrupt() -> void:
	var ledger := _ledger("corrupt")
	_remove(ledger.save_path)
	_check(ledger.observe({"route_wind":1}) == OK and ledger.select_title("route_wind") == OK, "valid prefix")
	var good := ledger.snapshot()
	for event in [{"event":"progress", "progress":{"route_forest":1,"unknown":1}}, {"event":"progress", "progress":{"route_wind":-1}}, {"event":"title", "id":"route_forest"}]:
		_check(ledger._append(event) == OK and ledger.snapshot() == good, "invalid row rejected as a whole")
	var file := FileAccess.open(ledger.save_path, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_line(JSON.stringify({"version":1, "payload":"{}", "sha256":"bad"}))
	file.store_string("{truncated")
	file.close()
	_check(ledger.snapshot() == good, "checksum failure and torn tail preserve valid prefix")
	_check(ledger.observe({"route_forest":1}) == OK and ledger.select_title("route_forest") == OK and ledger.snapshot().title == "route_forest", "append after torn tail recovers and restores new title")
	var before := _bytes(ledger.save_path)
	_check(ledger.observe({"route_wind":0, "unknown":1}) == ERR_INVALID_DATA and _bytes(ledger.save_path) == before, "invalid mixed request cannot partially change ledger")

func _render() -> void:
	var output := OS.get_environment("ACHIEVEMENT_RENDER_DIR")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		_check(false, "real renderer and output directory required")
		return
	DirAccess.make_dir_recursive_absolute(output)
	var full := {"progress":{}, "title":"secret_archive"}
	for item in PermanentAchievements.DEFINITIONS: full.progress[item.id] = item.target
	var count := 0
	for dimensions in [Vector2i(1280,720), Vector2i(1600,720), Vector2i(1280,800)]:
		root.size = dimensions
		root.content_scale_size = Vector2i(1920,1080)
		controls.village_page = "achievements"
		controls.update_achievement_status(full)
		for page in ceili(float(PermanentAchievements.DEFINITIONS.size()) / 3.0):
			controls.achievement_page = page
			controls.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			_check(root.get_texture().get_image().save_png("%s/full_%d_%dx%d.png" % [output,page,dimensions.x,dimensions.y]) == OK, "save rendered page")
			count += 1
		for mode in ["empty", "partial", "error"]:
			var state := {"progress":{}, "title":""}
			if mode == "partial": state.progress = {"route_wind":1, "route_forest":0}
			controls.update_achievement_status(state, "업적 기록 실패 · 업적 카드를 눌러 재시도" if mode == "error" else "")
			controls.achievement_page = 0
			controls.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			_check(root.get_texture().get_image().save_png("%s/%s_%dx%d.png" % [output,mode,dimensions.x,dimensions.y]) == OK, "save empty/partial/error state")
			count += 1
		controls.update_achievement_status(full)
		controls.show_main_screen()
		await process_frame
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("%s/title_%dx%d.png" % [output,dimensions.x,dimensions.y]) == OK, "main menu title")
		count += 1
		controls.show_village()
	print("Achievement screens rendered: ", count)
