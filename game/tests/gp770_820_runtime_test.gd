extends "res://tests/hero_stats_runtime_test.gd"

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	var prefix := "user://gp820"
	store.save_path = prefix+"_checkpoint.json"
	legacy.save_path = prefix+"_meta.jsonl"
	journal.save_path = prefix+"_story.jsonl"
	if phase != "resume":
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
	if phase == "resume":
		var saved := store.load_checkpoint()
		if not _check(not saved.is_empty() and saved.growth.ranks.has("sword_stat_precision"),"save exists across processes"): return
		for ignored in 2:
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and player.stat_specializations == PrototypeStatSpecializations.selected(saved.growth.ranks) and player.active_weapon_family == saved.weapons.active,"all acquired specializations restore without stacking"): return
		_tap(controls.stage_route_rects[0].get_center())
		if not _ui_checks(false): return
		controls.show_main_screen()
		if not _check(controls.begin_retry("bow",3,"standard","roan",false,0,"sword") and player.stat_specializations.is_empty() and player.critical_chance_stat() == 0,"new run clears temporary effects"): return
	else:
		if not _check(controls.begin_retry("sword",5,"standard","roan",false,0,"bow"),"start two-weapon run"): return
		if not _catalog(): return
		if phase == "acquisition":
			if not _all_acquisition(): return
		elif phase == "combat":
			if not _golden_math() or not _actual_hits(): return
		else:
			# Real choices exercise prerequisites, discovery persistence, and stat reconstruction.
			for card in PrototypeStatSpecializations.CARDS:
				if card.category in ["common","sword","bow"] and not _gain(String(card.id)): return
			if not _ui_checks(phase == "render"): return
			if phase == "render": await _render_status()
			if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK,"new growth saves using existing rank schema"): return
			var saved := store.load_checkpoint()
			for invalid in [-1,2,0.5,"1"]:
				var bad := saved.duplicate(true)
				bad.growth.ranks.sword_stat_precision = invalid
				if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved,"tampered rank rejected atomically"): return
	paused = false
	sandbox.free()
	print("GP-770–820 runtime test: OK (%s; %d assertions)" % [phase,stats_checks])
	quit(0)

func _gain(id: String) -> bool:
	if growth.ranks.has(id): return true
	var card := PrototypeAbilityCodex.profile(id)
	for required in card.get("requires",[]):
		if not _gain(String(required)): return false
	return _earn_card(id)

func _catalog() -> bool:
	if not _check(PrototypeStatSpecializations.CARDS.size() == 42,"36 family plus six common specializations"): return false
	var ids := {}
	for card in PrototypeStatSpecializations.CARDS:
		if not _check(not ids.has(card.id) and card.max_rank == 1 and card.lines.size() == 2 and card.ticket >= 771 and card.ticket <= 812,"unique complete definitions with stable feature IDs"): return false
		ids[card.id] = true
		for required in card.requires:
			if not _check(not PrototypeAbilityCodex.profile(String(required)).is_empty(),"prerequisite exists in live catalog"): return false
		if not _check(not PrototypeAbilityCodex.profile(card.id).is_empty(),"each specialization is discoverable and selectable"): return false
	return true

func _golden_math() -> bool:
	player.stat_ranks.clear()
	player.hero_traits.reset()
	for card in PrototypeStatSpecializations.CARDS:
		player.stat_specializations = {card.id:1}
		var family_id := String(card.category) if card.category != "common" else "sword"
		var other := "bow" if family_id != "bow" else "sword"
		for family in [family_id,other]:
			player.active_weapon_family = family
			for hp in [0,30,31,79,80,100]:
				player.damage_receiver.health = hp
				player.damage_receiver.max_health = 100
				for barrier in [0,1]:
					player.damage_receiver.barrier_health = barrier
					for kind in ["basic","skill","ultimate"]:
						var armor := 0
						var chance := 0.0
						var critical_damage := 150.0
						var applies: bool = hp > 0 and (card.category == "common" or family == card.category)
						if applies:
							match String(card.get("stat_style",card.id)):
								"precision": chance = 8.0
								"potency": critical_damage += 25.0
								"armor": armor = 12
								"calm": chance = 10.0 if hp >= 80 else 0.0
								"barrier": critical_damage += 35.0 if barrier > 0 else 0.0
								"ultimate": critical_damage += 40.0 if kind == "ultimate" else 0.0
								"stat_iron_body": armor = 20
								"stat_insight": chance = 5.0
								"stat_finisher": critical_damage += 40.0
								"stat_crisis_guard": armor = 20 if hp <= 30 else 0
								"stat_calm_aim": chance = 8.0 if hp >= 80 else 0.0
								"stat_barrier_edge": critical_damage += 30.0 if barrier > 0 else 0.0
						if not _check(player.defense_stat() == armor and player.critical_chance_stat(family) == chance and player.critical_damage_stat(family,kind) == critical_damage,"golden stat increments at health/barrier/family/kind boundaries"): return false
	# Defense follows the actual active weapon and never leaks from a backup weapon.
	player.damage_receiver.health = 100
	player.damage_receiver.barrier_health = 0
	player.stat_specializations = {"sword_stat_armor":1}
	weapons.reset_combat("sword","bow")
	if not _check(player.defense_stat() == 12,"active family defense"): return false
	weapons._perform_switch("test")
	return _check(player.active_weapon_family == "bow" and player.defense_stat() == 0,"switch updates family defense")

func _actual_hits() -> bool:
	player.set_character("lumi")
	player.damage_receiver.health = 100
	player.damage_receiver.barrier_health = 1
	player.stat_ranks.clear()
	var target := get_first_node_in_group("targetable").duplicate(Node.DUPLICATE_SCRIPTS|Node.DUPLICATE_GROUPS) as PrototypeTarget
	target.target_key = "gp820_dummy"
	sandbox.add_child(target)
	target.visible = true
	target.set_process(false)
	target.damage_receiver.max_health = 1000
	for family in PrototypeWeaponRewards.FAMILY_IDS:
		for style in ["potency","barrier","ultimate"]:
			for kind in ["basic","skill","ultimate"]:
				player.stat_specializations = {family+"_stat_"+style:1}
				player.hero_traits.reset()
				player.hero_traits.weapon_switched("lumi",family)
				target.reset_target()
				var event := DamageEvent.new()
				event.event_id = &"gp820:hit"
				event.attacker_id = &"player"
				event.damage = 100
				event.tags = PackedStringArray([family,kind])
				var expected := 175 if style == "potency" else 185 if style == "barrier" else 190 if kind == "ultimate" else 150
				if not _check(player.deal_weapon_damage(target,event) == DamageReceiver.Result.APPLIED and target.damage_receiver.health == 1000-expected and event.outgoing_damage() == expected,"actual damage includes specialization and Lumi guarantee exactly once"): return false
				player.deal_weapon_damage(target,event)
				if not _check(target.damage_receiver.health == 1000-expected,"duplicate event cannot add specialized damage"): return false
	player.set_character("roan")
	player.stat_specializations = {"sword_stat_armor":1}
	player.active_weapon_family = "sword"
	player.damage_receiver.reset()
	var incoming := DamageEvent.new()
	incoming.event_id = &"gp820:incoming"
	incoming.attacker_id = &"enemy"
	incoming.damage = 30
	if not _check(player.receive_damage(incoming) == DamageReceiver.Result.APPLIED and player.damage_receiver.health == 73,"actual defense 12 reduces 30 damage to 27"): return false
	# Callers may reuse a DamageEvent object for a later hit with a new ID and damage.
	player.stat_specializations.clear()
	player.stat_ranks.clear()
	player.hero_traits.reset()
	target.reset_target()
	var reused := DamageEvent.new()
	reused.event_id = &"gp820:reused:first"
	reused.attacker_id = &"player"
	reused.damage = 80
	reused.tags = PackedStringArray(["sword","basic"])
	player.deal_weapon_damage(target,reused)
	if not _check(target.damage_receiver.health == 920 and reused.outgoing_damage() == 80,"first reused event uses original damage"): return false
	reused.event_id = &"gp820:reused:second"
	reused.damage = 9999
	if not _check(reused.outgoing_damage() == 9999,"changing source identity invalidates cached critical result"): return false
	player.deal_weapon_damage(target,reused)
	return _check(target.damage_receiver.dead and reused.outgoing_damage() == 9999,"new hit reusing an event object resolves new damage and can kill")

func _ui_checks(_render: bool) -> bool:
	var before: Dictionary = sandbox._capture_run_build()
	var rng_state := player.critical_rng.state
	_tap(controls.combat_build_rect.get_center())
	if not _check(paused and controls.hero_status_open,"actual HUD opens dedicated status view and acquires existing pause owner"): return false
	var families_now := HeroStatusView.families(controls.run_build_state)
	var inspect_ids := ["weapon:"+String(families_now[0]),"weapon:"+String(families_now[1]),"skill:%s:0" % families_now[0],"skill:%s:1" % families_now[0],"skill:%s:0" % families_now[1],"skill:%s:1" % families_now[1],"passive","defense","offense","conditions"]
	for dimensions in [Vector2(1280,720),Vector2(1600,720),Vector2(1280,800),Vector2(2400,1080)]:
		controls.size = dimensions
		controls._refresh_layout()
		var safe: Rect2 = controls._safe_area_in_viewport()
		var view := HeroStatusView.layout(safe)
		var targets: Array = view.gear+view.skills+[view.defense,view.offense,view.passive,view.conditions,view.browse,view.back]
		for i in targets.size():
			if not _check(safe.encloses(targets[i]),"status interactive control inside safe area"): return false
			for j in range(i+1,targets.size()):
				if not _check(not targets[i].intersects(targets[j]),"status interactive controls never overlap"): return false
		for id in inspect_ids:
			var entry := HeroStatusView.inspect(id,controls.run_build_state)
			if not _check(not entry.is_empty() and not entry.title.is_empty() and not entry.lines.is_empty(),"all equipment/skill/passive/stat/condition inspection content exists"): return false
			controls.hero_status_detail = id
			controls.hero_status_page = 0
			for ignored in 30: HeroStatusView.handle_touch(controls,view.next.get_center())
			var pages := maxi(1,ceili(float(entry.lines.size())/HeroStatusView.PAGE_LINES))
			if not _check(controls.hero_status_page == pages-1,"inspection next page clamps to content"): return false
			HeroStatusView.handle_touch(controls,view.close.get_center())
			if not _check(controls.hero_status_detail == "" and paused,"inspection close preserves status pause"): return false
		HeroStatusView.handle_touch(controls,view.gear[0].get_center())
		if not _check(controls.hero_status_detail == inspect_ids[0],"main gear touch opens correct detail"): return false
		var escape := InputEventKey.new()
		escape.pressed = true
		escape.keycode = KEY_ESCAPE
		controls._input(escape)
		if not _check(controls.hero_status_detail == "" and controls.hero_status_open and paused,"back key closes detail first"): return false
		HeroStatusView.handle_touch(controls,view.browse.get_center())
		if not _check(not controls.hero_status_open and paused,"legacy ability browser reachable without resuming battle"): return false
		controls._handle_run_build_touch(HeroStatusView.return_rect(safe).get_center())
		if not _check(controls.hero_status_open,"return from legacy browser to status"): return false
	if not _check(before == sandbox._capture_run_build() and player.critical_rng.state == rng_state,"all navigation read-only, no RNG consumed"): return false
	controls.close_run_build()
	controls.advance_mode_timer_for_test(3.1)
	return _check(not paused and not controls.hero_status_open and sandbox._capture_run_build() == before,"return restores same combat state after countdown")

func _render_status() -> void:
	var output := OS.get_environment("HERO_STATUS_RENDER_DIR")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		_check(false,"real renderer required")
		return
	DirAccess.make_dir_recursive_absolute(output)
	for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,800)]:
		root.size = dimensions
		root.content_scale_size = Vector2i(1920,1080)
		controls.size = root.get_visible_rect().size
		controls.open_hero_status()
		for detail_id in ["","weapon:sword","weapon:bow","skill:sword:0","skill:bow:1","passive","offense","defense","conditions"]:
			controls.hero_status_detail = detail_id
			controls.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			_check(root.get_texture().get_image().save_png("%s/%s_%dx%d.png" % [output,detail_id.replace(":","_") if detail_id != "" else "overview",dimensions.x,dimensions.y]) == OK,"actual status render")
		controls.close_run_build()
		controls.advance_mode_timer_for_test(3.1)
	player.set_character("lumi")
	weapons.request_weapon_switch()
	root.size = Vector2i(1280,720)
	controls.size = root.get_visible_rect().size
	controls.open_hero_status()
	controls.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(output+"/lumi_overview_1280x720.png") == OK,"Lumi status with switched weapons and guaranteed critical pending")
	controls.close_run_build()
	controls.advance_mode_timer_for_test(3.1)

func _all_acquisition() -> bool:
	for family in PrototypeWeaponRewards.FAMILY_IDS:
		controls.show_main_screen()
		var other := "bow" if family == "sword" else "sword"
		if not _check(controls.begin_retry(family,5,"standard","roan",false,0,other),"start each of six actual family loadouts"): return false
		for card in PrototypeStatSpecializations.CARDS:
			if card.category in [family,"common"]:
				if not _gain(String(card.id)): return false
				if not _check(player.stat_specializations.has(card.id) and not growth._card_available(card),"actual card acquisition updates stats once and removes repeated offer"): return false
			elif card.category not in weapons.equipment:
				if not _check(not growth._card_available(card),"unheld weapon specializations are not offered"): return false
	for card in PrototypeStatSpecializations.CARDS:
		if not _check(mastery_book.snapshot().has(card.id),"all 42 specialization discoveries are durable"): return false
	return true
