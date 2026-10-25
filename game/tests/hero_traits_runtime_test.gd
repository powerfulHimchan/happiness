extends "res://tests/hero_stats_runtime_test.gd"

var trait_hero := "roan"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	trait_hero = args[1] if args.size() > 1 else "roan"
	var prefix := "user://hero_traits_"+trait_hero
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
		if not _check(not saved.is_empty(),"trait checkpoint exists"): return
		for ignored in 2:
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and player.character_id == trait_hero and player.hero_traits.snapshot() == saved.player.hero_traits,"separate-process repeated trait restore, no new charge/reset"): return
		var old := saved.duplicate(true)
		old.player.erase("hero_traits")
		if not _check(store.save_checkpoint(old) == OK,"old checkpoint remains valid"): return
		controls.show_main_screen()
		if not _check(sandbox.continue_saved_run() and player.hero_traits.snapshot() == HeroTraits.new().snapshot(),"missing trait field defaults neutral, no free activation"): return
		controls.show_main_screen()
		if not _check(controls.begin_retry("sword",3,"standard",trait_hero,false,0,"bow") and player.hero_traits.snapshot() == HeroTraits.new().snapshot(),"new run clears trait timers and pending charge"): return
	else:
		if not _check(controls.begin_retry("sword",5,"standard",trait_hero,false,0,"bow"),"new trait run"): return
		if phase == "combat":
			if not _roan_effects() or not _lumi_effects(): return
			if not await _pause_clock(): return
		else:
			if trait_hero == "roan": _precise_evade()
			else: weapons.request_weapon_switch()
			player.hero_traits.tick(0.75)
			var before := player.hero_traits.snapshot()
			if not _check(before.roan_remaining == 2.25 if trait_hero == "roan" else before.lumi_weapon == "bow" and before.lumi_cooldown == 7.25,"actual activation before persistence"): return
			if phase == "render": await _render_traits()
			if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK,"save activated trait"): return
			var saved := store.load_checkpoint()
			if not _check(saved.player.hero_traits == before,"stage completion preserves remaining timers and charge"): return
			if not _invalid_saves(saved): return
	paused = false
	sandbox.free()
	print("Hero traits runtime test: OK (%s %s; %d assertions)" % [phase,trait_hero,stats_checks])
	quit(0)

func _precise_evade() -> void:
	player.invincible = true
	(sandbox.get_node("Player/UltimateController") as UltimateController).register_precise_evade()
	player.invincible = false

func _roan_effects() -> bool:
	player.set_character("roan")
	var ultimate := sandbox.get_node("Player/UltimateController") as UltimateController
	ultimate.register_precise_evade()
	if not _check(player.attack_stat() == 100,"ordinary/non-invincible movement cannot activate Roan"): return false
	_precise_evade()
	if not _check(player.attack_stat() == 125 and player.hero_traits.roan_remaining == 3.0 and player.hero_traits.roan_cooldown == 6.0,"precise evade gives 25 percent attack for 3s, 6s cooldown"): return false
	for family_id in PrototypeWeaponRewards.FAMILY_IDS:
		for kind in ["basic","skill","ultimate"]:
			if not _check(player.growth_damage_preview(100,family_id,kind,true) == 125,"Roan bonus applies to all six weapon attacks"): return false
	player.hero_traits.tick(1.0)
	_precise_evade()
	if not _check(player.hero_traits.roan_remaining == 2.0 and player.hero_traits.roan_cooldown == 5.0,"additional precise hits do not refresh cooldown or duration"): return false
	player.hero_traits.tick(2.0)
	if not _check(player.attack_stat() == 100 and player.hero_traits.roan_cooldown == 3.0,"exact duration ends bonus"): return false
	_precise_evade()
	if not _check(player.attack_stat() == 100,"cannot rearm before six seconds"): return false
	player.hero_traits.tick(3.0)
	_precise_evade()
	if not _check(player.attack_stat() == 125,"can rearm at six seconds"): return false
	player.set_character("lumi")
	_precise_evade()
	return _check(player.attack_stat() == 100 and player.hero_traits.roan_remaining == 0.0,"Roan passive never leaks into Lumi")

func _trait_event(id: String, family_id: String, kind: String = "basic") -> DamageEvent:
	var event := DamageEvent.new()
	event.event_id = StringName(id)
	event.attacker_id = &"player"
	event.damage = 20
	event.tags = PackedStringArray([family_id,kind])
	return event

func _lumi_effects() -> bool:
	player.set_character("lumi")
	player.stat_ranks.clear()
	var target := get_first_node_in_group("targetable").duplicate(Node.DUPLICATE_SCRIPTS|Node.DUPLICATE_GROUPS) as PrototypeTarget
	target.target_key = "hero_traits_dummy"
	sandbox.add_child(target)
	target.visible = true
	target.set_process(false)
	target.damage_receiver.max_health = 1000
	for family_id in PrototypeWeaponRewards.FAMILY_IDS:
		for kind in ["basic","skill","ultimate"]:
			player.hero_traits.reset()
			var other := "bow" if family_id == "sword" else "sword"
			weapons.reset_combat(other,family_id)
			weapons.request_weapon_switch()
			if not _check(weapons.active_weapon_id == family_id and player.hero_traits.lumi_weapon == family_id and player.hero_traits.lumi_cooldown == 8.0,"successful weapon switch arms matching family"): return false
			var state := player.hero_traits.snapshot()
			weapons.request_weapon_switch()
			if not _check(player.hero_traits.snapshot() == state,"blocked switch cannot activate or refresh trait"): return false
			target.reset_target()
			target.damage_receiver._post_hit_remaining_s = 1.0
			if not _check(player.deal_weapon_damage(target,_trait_event("blocked",family_id,kind)) == DamageReceiver.Result.INVULNERABLE_BLOCKED and player.hero_traits.lumi_weapon == family_id,"blocked hit preserves guarantee"): return false
			target.reset_target()
			player.deal_weapon_damage(target,_trait_event("old_projectile",other,kind))
			if not _check(target.damage_receiver.health == 980 and player.hero_traits.lumi_weapon == family_id,"old weapon projectile cannot consume new weapon guarantee"): return false
			target.reset_target()
			var event := _trait_event("guaranteed",family_id,kind)
			if not _check(player.deal_weapon_damage(target,event) == DamageReceiver.Result.APPLIED and target.damage_receiver.health == 970 and event.critical and event.outgoing_damage() == 30 and player.hero_traits.lumi_weapon.is_empty(),"one successful basic/skill/ultimate hit critically strikes"): return false
			player.deal_weapon_damage(target,event)
			if not _check(target.damage_receiver.health == 970,"duplicate delivery never deals damage twice"): return false
			target.reset_target()
			player.deal_weapon_damage(target,_trait_event("normal",family_id,kind))
			if not _check(target.damage_receiver.health == 980,"second target or multi-hit resumes normal chance"): return false
			player.hero_traits.tick(7.99)
			weapons._perform_switch("test")
			if not _check(player.hero_traits.lumi_weapon.is_empty(),"cannot reactivate before eight seconds"): return false
			player.hero_traits.tick(0.02)
			weapons._perform_switch("test")
			if not _check(player.hero_traits.lumi_weapon == family_id,"next actual switch after cooldown rearms"): return false
	# State must be consumed before a kill callback can write a checkpoint.
	target.damage_receiver.max_health = 20
	target.reset_target()
	var charge_seen: Array = []
	target.defeated.connect(func(_victim: PrototypeTarget) -> void: charge_seen.append(player.hero_traits.lumi_weapon))
	player.deal_weapon_damage(target,_trait_event("killing_hit",player.hero_traits.lumi_weapon))
	if not _check(charge_seen == [""],"kill callbacks observe consumed guarantee"): return false
	player.set_character("roan")
	weapons._perform_switch("test")
	return _check(player.hero_traits.lumi_weapon.is_empty(),"Lumi passive never activates on Roan")

func _pause_clock() -> bool:
	player.set_character("roan")
	_precise_evade()
	var before := player.hero_traits.snapshot()
	player.set_physics_process(true)
	paused = true
	await create_timer(0.05,true).timeout
	var same := player.hero_traits.snapshot() == before
	player.set_physics_process(false)
	paused = false
	return _check(same,"actual paused scene freezes passive duration and cooldown")

func _invalid_saves(saved: Dictionary) -> bool:
	for invalid in [null,[],{"roan_remaining":1}, {"roan_remaining":4.0,"roan_cooldown":6.0,"lumi_cooldown":0.0,"lumi_weapon":""},{"roan_remaining":0.0,"roan_cooldown":0.0,"lumi_cooldown":9.0,"lumi_weapon":"sword"},{"roan_remaining":0.0,"roan_cooldown":0.0,"lumi_cooldown":0.0,"lumi_weapon":"laser"}]:
		var bad := saved.duplicate(true)
		bad.player.hero_traits = invalid
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved,"invalid trait state rejected atomically"): return false
	var wrong := saved.duplicate(true)
	wrong.player.character_id = "lumi" if trait_hero == "roan" else "roan"
	return _check(not RunCheckpointStore.valid_state(wrong),"wrong character cannot carry other passive state")

func _render_traits() -> void:
	var output := OS.get_environment("HERO_TRAITS_RENDER_DIR")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		_check(false,"real renderer required")
		return
	DirAccess.make_dir_recursive_absolute(output)
	for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,800)]:
		root.size = dimensions
		root.content_scale_size = Vector2i(1920,1080)
		controls.open_run_build()
		controls.run_build_tab = 2
		controls.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("%s/%s_info_%dx%d.png" % [output,trait_hero,dimensions.x,dimensions.y]) == OK,"trait info render")
		controls.close_run_build()
		controls.advance_mode_timer_for_test(3.1)
	controls.show_main_screen()
	controls.show_new_run_preparation()
	_check(controls.current_screen_mode() == controls.ScreenMode.START_CHARACTER,"selection screen entered through actual preparation flow")
	controls.selected_character_id = trait_hero
	controls.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("%s/%s_selection.png" % [output,trait_hero]) == OK,"selection trait panels render")
	controls.show_main_screen()
	controls.begin_retry("sword",5,"standard",trait_hero,false,0,"bow")
	if trait_hero == "roan": _precise_evade()
	else: weapons.request_weapon_switch()
	player.hero_traits.tick(0.75)
