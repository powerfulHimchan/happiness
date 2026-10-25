extends "res://tests/gp515_544_runtime_test.gd"

var stats_checks := 0

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	var prefix := "user://hero_stats"
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
		for ignored in 2:
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run(),"separate-process resume"): return
			if not _check(player.stat_ranks == {"stat_defense":2,"stat_critical_chance":2,"stat_critical_damage":2},"stat ranks restored without stacking"): return
			if not _check(player.attack_stat() == 110 and player.defense_stat() == 20 and player.damage_receiver.max_health == 120,"attack defense health preserved"): return
		_tap(controls.stage_route_rects[0].get_center())
		if not _check_ui(): return
		controls.show_main_screen()
		if not _check(controls.begin_retry("bow",3,"standard","roan",false,0,"sword") and player.stat_ranks.is_empty(),"new run clears temporary stats"): return
	elif phase in ["seed","render"]:
		if not _check(controls.begin_retry("sword",5,"standard","lumi",false,0,"bow"),"new run"): return
		if not _check(player.combat_stats_snapshot() == {"attack":100,"defense":0,"critical_chance":0.0,"critical_damage":150.0,"health":100,"max_health":100,"damage_reduction":0.0},"base five stats"): return
		for id in ["stat_defense","stat_critical_chance","stat_critical_damage"]:
			for ignored in 2:
				if not _earn_card(id): return
		if not _earn_card("power") or not _earn_card("vitality"): return
		if not _check(player.growth_damage_preview(100,"bow","basic",true) == 110 and player.combat_stats_snapshot().critical_chance == 10.0,"attack scaling and crit chance"): return
		if not _check_ui(): return
		if phase == "render": await _render_stats()
		if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
		if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK,"actual checkpoint saves derived stats"): return
		var saved := store.load_checkpoint()
		for bad_rank in [-1,6,1.5,"2"]:
			var bad := saved.duplicate(true)
			bad.growth.ranks.stat_defense = bad_rank
			if not _check(store.save_checkpoint(bad) != OK and store.load_checkpoint() == saved,"invalid stat rank rejected atomically"): return
	else:
		if not _check(controls.begin_retry("sword",3,"standard","roan",false,0,"bow"),"combat run"): return
		if not _combat_math() or not _actual_attack_paths(): return
	paused = false
	sandbox.free()
	print("Hero stats runtime test: OK (%s; %d assertions)" % [phase,stats_checks])
	quit(0)

func _check(condition: bool,label: String) -> bool:
	stats_checks += 1
	return super._check(condition,label)

func _check_ui() -> bool:
	var state: Dictionary = sandbox._capture_run_build()
	var cards := PrototypeRunBuildView.browse(2,state)
	var stat_cards := cards.filter(func(card: Dictionary) -> bool: return card.id == "combat_stats")
	if not _check(stat_cards.size() == 1 and cards[1].id == "combat_stats" and stat_cards[0].lines.size() == 6,"five-stat card visible on first info page"): return false
	var before := player.critical_rng.state
	for ignored in 3:
		PrototypeRunBuildView.cards(2,sandbox._capture_run_build())
	return _check(player.critical_rng.state == before,"view never rolls critical hits")

func _combat_math() -> bool:
	# Threshold rolls are reproducible; test both sides of exactly 50%.
	player.stat_ranks = {"stat_critical_chance":10,"stat_critical_damage":2,"stat_defense":5}
	var seed_value := 777
	player.critical_rng.seed = seed_value
	var probe := RandomNumberGenerator.new()
	probe.seed = seed_value
	var dummy := sandbox.get_node_or_null("PracticeTargets/Dummy") as PrototypeTarget
	if dummy == null: dummy = get_first_node_in_group("targetable") as PrototypeTarget
	var critical_count := 0
	var normal_count := 0
	for family in PrototypeWeaponRewards.FAMILY_IDS:
		for kind in ["basic","skill","ultimate"]:
			for ignored in 4:
				dummy.reset_target()
				dummy.damage_receiver.max_health = 1000
				dummy.damage_receiver.reset()
				var event := DamageEvent.new()
				event.event_id = StringName("hero_stats:%s:%s:%d" % [family,kind,ignored])
				event.attacker_id = &"player"
				event.damage = 20
				event.tags = PackedStringArray([family,kind])
				var is_critical := probe.randf() < 0.5
				if is_critical: critical_count += 1
				else: normal_count += 1
				if not _check(player.deal_weapon_damage(dummy,event) == DamageReceiver.Result.APPLIED and dummy.damage_receiver.health == (960 if is_critical else 980),"all six weapons and three hit kinds resolve critical"): return false
				if not _check(event.damage == 20 and event.tags == PackedStringArray([family,kind]) and event.outgoing_damage() == (40 if is_critical else 20),"original damage and tags preserved; telemetry resolved"): return false
				if not _check(player.deal_weapon_damage(dummy,event) == DamageReceiver.Result.DUPLICATE_BLOCKED and dummy.damage_receiver.health == (960 if is_critical else 980),"duplicate event cannot deal damage again"): return false

	if not _check(critical_count > 0 and normal_count > 0,"seed covers both outcomes"): return false
	var hit := DamageEvent.new()
	hit.event_id = &"hero_stats:incoming"
	hit.damage = 30
	hit.attacker_id = &"enemy"
	hit.tags = PackedStringArray(["enemy"])
	player.damage_receiver.reset()
	player.damage_receiver.barrier_health = 10
	if not _check(player.receive_damage(hit) == DamageReceiver.Result.APPLIED and player.damage_receiver.health == 90 and player.damage_receiver.barrier_health == 0,"defense before barrier:30→20→10 health loss"): return false
	if not _check(hit.damage == 30 and player.receive_damage(hit) == DamageReceiver.Result.DUPLICATE_BLOCKED and player.damage_receiver.health == 90,"defense preserves source and duplicate protection"): return false
	player.damage_receiver.reset()
	player.invincible = true
	hit.event_id = &"hero_stats:invincible"
	if not _check(player.receive_damage(hit) == DamageReceiver.Result.INVULNERABLE_BLOCKED and player.damage_receiver.health == 100,"defense preserves invulnerability"): return false
	player.invincible = false
	player.damage_receiver.apply_environmental_damage(10,1)
	if not _check(player.damage_receiver.health == 90,"environmental health cost independent of defense"): return false
	player.stat_ranks.clear()
	var old := store.load_checkpoint()
	if not old.is_empty(): return _check(false,"combat fixture isolated")
	return true

func _force_next_critical() -> void:
	for seed_value in 100:
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		if probe.randf() < 0.5:
			player.critical_rng.seed = seed_value
			return

func _actual_attack_paths() -> bool:
	player.stat_ranks = {"stat_critical_chance":10,"stat_critical_damage":2}
	var target := get_first_node_in_group("targetable").duplicate(Node.DUPLICATE_SCRIPTS|Node.DUPLICATE_GROUPS) as PrototypeTarget
	target.target_key = "hero_stats_dummy"
	sandbox.add_child(target)
	target.visible = true
	target.global_position = player.global_position+Vector2(150,0)
	target.set_process(false)
	for family_id in ["sword","fist","polearm","shield"]:
		target.reset_target()
		target.damage_receiver.max_health = 1000
		target.damage_receiver.reset()
		_force_next_critical()
		var actor := weapons.combat_for(family_id) as SwordCombatController
		var before := actor.total_damage
		actor._damage_target(target,StringName(family_id+"_basic"),20,0.0,PackedStringArray([family_id,"basic"]),0)
		if not _check(target.damage_receiver.health == 960 and actor.total_damage-before == 40,"actual melee hit and total damage include critical"): return false
	target.reset_target()
	target.damage_receiver.max_health = 1000
	target.damage_receiver.reset()
	_force_next_critical()
	var arrow := load("res://scenes/combat/bow_projectile.tscn").instantiate() as BowProjectile
	arrow.configure("stats:arrow",&"bow_basic",20,10.0,8.0,1,Vector2.RIGHT,PackedStringArray(["bow","basic"]))
	arrow.damage_handler = player.deal_weapon_damage
	sandbox.add_child(arrow)
	arrow.set_physics_process(false)
	var point := target.global_position+PrototypeTarget.BODY_CENTER
	arrow._check_hits(point,point)
	if not _check(target.damage_receiver.health == 960 and arrow.damage == 20,"actual arrow crit does not multiply projectile base"): return false
	arrow.free()
	target.reset_target()
	target.damage_receiver.max_health = 1000
	target.damage_receiver.reset()
	_force_next_critical()
	var bolt := StaffMagicBolt.new()
	bolt.projectile_id = "stats:bolt"
	bolt.damage = 20
	bolt.damage_handler = player.deal_weapon_damage
	sandbox.add_child(bolt)
	bolt.set_physics_process(false)
	bolt._damage(target,point)
	if not _check(target.damage_receiver.health == 960 and bolt.damage == 20,"actual magic bolt crit keeps base damage"): return false
	bolt.free()
	target.reset_target()
	target.damage_receiver.max_health = 1000
	target.damage_receiver.reset()
	var grouped := target.is_in_group("combat_enemy")
	if not grouped: target.add_to_group("combat_enemy")
	var ultimate := sandbox.get_node("Player/UltimateController") as UltimateController
	ultimate._active_profile = {"id":"stats_ultimate","weapon":"sword","damage":20,"range":100000.0}
	_force_next_critical()
	ultimate._apply_job_effect()
	if not _check(target.damage_receiver.health == 960,"actual ultimate shares critical damage path"): return false
	if not grouped: target.remove_from_group("combat_enemy")
	player.damage_receiver.health = 50
	player.lifesteal_unlocked = true
	player.lifesteal_allowed = func() -> bool: return true
	target.add_to_group("combat_enemy")
	target.reset_target()
	target.damage_receiver.max_health = 1000
	target.damage_receiver.reset()
	_force_next_critical()
	var event := DamageEvent.new()
	event.event_id = &"stats:lifesteal"
	event.attacker_id = &"player"
	event.damage = 20
	event.tags = PackedStringArray(["sword","basic"])
	player.deal_weapon_damage(target,event)
	return _check(player.damage_receiver.health == 52,"lifesteal uses actual critical health damage")

func _render_stats() -> void:
	var output := OS.get_environment("HERO_STATS_RENDER_DIR")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		_check(false,"real renderer and output required")
		return
	DirAccess.make_dir_recursive_absolute(output)
	controls.open_run_build()
	controls.run_build_tab = 2
	for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,800)]:
		root.size = dimensions
		root.content_scale_size = Vector2i(1920,1080)
		controls.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("%s/stats_%dx%d.png" % [output,dimensions.x,dimensions.y]) == OK,"render stat card")
	controls.close_run_build()
	controls.advance_mode_timer_for_test(3.1)
