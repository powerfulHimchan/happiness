extends "res://tests/hero_stats_runtime_test.gd"

var sequence := 0
var callback_links := {}

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	var prefix := "user://gp890_"+("save" if phase in ["seed","resume"] else phase)
	store.save_path = prefix+"_checkpoint.json"
	legacy.save_path = prefix+"_meta.jsonl"
	journal.save_path = prefix+"_story.jsonl"
	if phase != "resume":
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
	if phase == "resume":
		var saved := store.load_checkpoint()
		if not _check(not saved.is_empty() and not saved.player.combat_links.is_empty(),"separate process has saved live windows"): return
		for ignored in 2:
			controls.show_main_screen()
			if not _check(sandbox.continue_saved_run() and player.combat_links.snapshot() == saved.player.combat_links and player.combat_links.ranks == PrototypeCombatLinks.selected(saved.growth.ranks),"resume restores choices/windows without refresh or stacking"): return
		controls.show_main_screen()
		if not _check(controls.begin_retry("sword",3,"standard","lumi") and player.combat_links.ranks.is_empty() and player.combat_links.windows.is_empty(),"new run clears temporary links"): return
	else:
		if not _check(controls.begin_retry("sword",5,"standard","roan",false,0,"bow"),"start real two-weapon run"): return
		match phase:
			"catalog":
				if not _catalog_links() or not _math_links(): return
			"combat":
				if not _combat_links(): return
			"acquisition":
				if not _acquire_all_links(): return
			"seed":
				if not _gain_held(): return
				if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
				player.combat_links.trigger("switch",weapons.equipment,"bow")
				player.combat_links.trigger("critical",weapons.equipment,"sword")
				player.combat_links.tick(.75)
				if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK,"actual checkpoint accepts learned live windows"): return
				if not _tamper_links(): return
			"ui","render":
				for id in ["sword_link_switch","sword_link_evade","sword_link_critical","bow_link_evade","link_extend_switch","link_extend_evade"]:
					if not _gain(id): return
				player.combat_links.trigger("switch",weapons.equipment,"sword")
				player.combat_links.trigger("evade",weapons.equipment)
				if not await _ui_links(phase == "render"): return
			_:
				_check(false,"known phase")
				return
	paused = false
	sandbox.free()
	print("GP-841–890 runtime: OK (%s; %d assertions)" % [phase,stats_checks])
	quit(0)

func _gain(id: String) -> bool:
	if growth.ranks.has(id): return true
	var card := PrototypeAbilityCodex.profile(id)
	for required in card.get("requires",[]):
		if not _gain(required): return false
	if card.has("requires_any") and not card.requires_any.any(func(key: String) -> bool: return growth.ranks.has(key)):
		var available: Array = card.requires_any.filter(func(key: String) -> bool: return PrototypeAbilityCodex.profile(key).category in weapons.equipment)
		if available.is_empty() or not _gain(available[0]): return false
	return _earn_card(id)

func _gain_held() -> bool:
	for card in PrototypeCombatLinks.CARDS:
		if card.category == "common" or card.category in weapons.equipment:
			if not _gain(card.id): return false
	return true

func _catalog_links() -> bool:
	if not _check(PrototypeCombatLinks.CARDS.size() == 42,"36 weapon effects and six shared extensions"): return false
	var ids := {}
	for card in PrototypeCombatLinks.CARDS:
		if not _check(not ids.has(card.id) and card.max_rank == 1 and card.ticket >= 841 and card.ticket <= 882 and card.lines.size() == 2 and not PrototypeAbilityCodex.profile(card.id).is_empty(),"unique full definition in acquisition/codex"): return false
		ids[card.id] = true
		if card.category == "common":
			if not _check(not PrototypeCombatLinks.prerequisites(card,{}) and PrototypeCombatLinks.prerequisites(card,{card.requires_any[3]:1}),"extension requires one real learned link, every weapon is eligible"): return false
		else:
			if not _check(not growth._card_available(card),"family power prerequisite enforced"): return false
	var source := {"sword_link_switch":1}
	for invalid in [-1,0,5.0,"1",NAN,INF,true]:
		if not _check(not PrototypeCombatLinks.valid_state({"sword_link_switch":invalid},source,["sword","bow"]),"invalid duration type/value rejected"): return false
	return _check(not PrototypeCombatLinks.valid_state({"bow_link_switch":1},source,["sword","bow"]) and not PrototypeCombatLinks.valid_state({"sword_link_switch":1},source,["fist","bow"]),"unlearned/unheld window rejected")

func _math_links() -> bool:
	for family in PrototypeWeaponRewards.FAMILY_IDS:
		for index in PrototypeCombatLinks.STYLES.size():
			var style: String = PrototypeCombatLinks.STYLES[index]
			var id := PrototypeCombatLinks.id_for(family,style)
			var links := PrototypeCombatLinks.new()
			links.learn({id:1})
			if not _check(links.multiplier(family,"basic") == 1,"learned effect stays dormant before event"): return false
			links.trigger(style,{family:0},family)
			for kind in ["basic","skill","ultimate"]:
				var allowed: bool = kind != "ultimate" and PrototypeCombatLinks.KINDS[index] in [kind,"all"]
				var expected := 1.0+float(PrototypeCombatLinks.BONUSES[index]) if allowed else 1.0
				if not _check(is_equal_approx(links.multiplier(family,kind),expected) and links.multiplier("unknown",kind) == 1,"exact family/kind multiplier"): return false
			links.tick(.5)
			links.trigger(style,{family:0},family)
			if not _check(links.windows[id] == PrototypeCombatLinks.DURATIONS[index],"repeat refreshes, never stacks duration or strength"): return false
			links.learn({id:1,"link_extend_"+style:1})
			if not _check(links.windows[id] == PrototypeCombatLinks.DURATIONS[index],"extension does not rewrite an existing timer"): return false
			links.trigger(style,{family:0},family)
			if not _check(links.windows[id] == PrototypeCombatLinks.DURATIONS[index]+1,"extension affects next actual trigger"): return false
			links.tick(float(PrototypeCombatLinks.DURATIONS[index])+1)
			if not _check(links.windows.is_empty(),"exact duration expires completely"): return false
	for hz in [30,60,120]:
		var links := PrototypeCombatLinks.new()
		links.learn({"sword_link_switch":1})
		links.trigger("switch",{"sword":0},"sword")
		for frame in hz: links.tick(1.0/hz)
		if not _check(is_equal_approx(links.windows.sword_link_switch,2.0),"frame independent timer"): return false
	return true

func _event(family: String, kind: String, damage: int = 100) -> DamageEvent:
	sequence += 1
	var event := DamageEvent.new()
	event.event_id = StringName("gp890:"+str(sequence))
	event.attacker_id = &"player"
	event.damage = damage
	event.tags = PackedStringArray([family,kind])
	return event

func _combat_links() -> bool:
	var target: PrototypeTarget = sandbox.get_node("Targets/RearTarget")
	for hero in PrototypeCharacters.IDS:
		for family in PrototypeWeaponRewards.FAMILY_IDS:
			player.reset_movement_test(Vector2(960,780))
			player.set_character(hero)
			weapons.reset_combat(family)
			var ranks := {}
			for style in PrototypeCombatLinks.STYLES: ranks[PrototypeCombatLinks.id_for(family,style)] = 1
			player.combat_links.learn(ranks)
			target.reset_target()
			target.visible = true
			target.damage_receiver.max_health = 10000
			target.damage_receiver.reset()
			target.global_position = player.global_position+Vector2(80,0)
			weapons.target_selector.current_target = target
			# Critical/skill events arm future basics, without buffing the triggering hit.
			player.stat_ranks = {"stat_critical_chance":10}
			var probe := RandomNumberGenerator.new()
			var critical_seed := 1
			probe.seed = critical_seed
			while probe.randf() >= .5:
				critical_seed += 1
				probe.seed = critical_seed
			player.critical_rng.seed = critical_seed
			var event := _event(family,"skill",100)
			if not _check(player.deal_weapon_damage(target,event) == DamageReceiver.Result.APPLIED and target.damage_receiver.health == 9850 and player.combat_links.windows.has(family+"_link_critical") and player.combat_links.windows.has(family+"_link_skill"),"actual skill critical arms both links after original damage"): return false
			if not _check(player.growth_damage(100,family,"basic") == 133 and player.growth_damage(100,family,"ultimate") == 100,"concurrent links add once and exclude ultimate"): return false
			player.combat_links.tick(.5)
			var before := player.combat_links.snapshot()
			player.deal_weapon_damage(target,event)
			if not _check(player.combat_links.snapshot() == before,"duplicate blocked event restores previous timers"): return false
			player.combat_links.windows.clear()
			player._start_ground_evade()
			if not _check(player.combat_links.windows.has(family+"_link_evade"),"real ground evade arms skill focus"): return false
			player.combat_links.windows.clear()
			player._start_air_dash()
			if not _check(player.combat_links.windows.has(family+"_link_evade"),"real air dash arms skill focus"): return false
			player._mobility_action = PrototypePlayer.MobilityAction.NONE
			player.invincible = false
			player._invincible_remaining_s = 0
			player.combat_links.windows.clear()
			var incoming := _event(family,"basic",1)
			incoming.attacker_id = &"enemy"
			incoming.tags = PackedStringArray(["enemy"])
			if not _check(player.receive_damage(incoming) == DamageReceiver.Result.APPLIED and player.combat_links.windows.has(family+"_link_hurt"),"only applied enemy damage arms counter resolve"): return false
			player.combat_links.windows.clear()
			player.damage_receiver.tick(.6)
			var hazard := _event(family,"basic",1)
			hazard.attacker_id = &"enemy"
			hazard.tags = PackedStringArray(["enemy","hazard","trap"])
			if not _check(player.receive_damage(hazard) == DamageReceiver.Result.APPLIED and player.combat_links.windows.is_empty(),"applied trap damage cannot arm counter resolve"): return false
			player._input_lock_remaining_s = 0
			player._hit_flash_remaining_s = 0
			player.combat_links.windows.clear()
			if not _check(player.use_recovery_potion() and player.combat_links.windows.has(family+"_link_potion"),"consumed potion arms recovery resolve"): return false
			player.combat_links.tick(.5)
			before = player.combat_links.snapshot()
			if not _check(not player.use_recovery_potion() and before == player.combat_links.snapshot(),"rejected full-health potion never refreshes link"): return false
			player.damage_receiver.post_hit_invulnerability_s = 0
			weapons._switch_cooldown_remaining_s = 0
			weapons.request_weapon_switch()
			player._input_lock_remaining_s = 0
			weapons._switch_cooldown_remaining_s = 0
			weapons.request_weapon_switch()
			if not _check(player.combat_links.windows.has(family+"_link_switch"),"successful switch to learned family arms opening"): return false
			player.combat_links.tick(.5)
			before = player.combat_links.snapshot()
			weapons.request_weapon_switch()
			if not _check(before == player.combat_links.snapshot(),"blocked rapid switch cannot refresh opening"): return false
			# Existing melee/projectile controllers use the multiplier at damage generation.
			player.stat_ranks.clear()
			player.hero_traits.reset()
			player.combat_links.windows.clear()
			player.combat_links.trigger("switch",weapons.equipment,family)
			target.reset_target()
			target.damage_receiver.max_health = 10000
			target.damage_receiver.reset()
			target.global_position = player.global_position+Vector2(80,0)
			weapons.target_selector.current_target = target
			var combat: Node = weapons.combat_for(family)
			combat._basic_remaining_s = 0
			var raw := int(combat.weapon.damage[0])
			var expected := player.growth_damage(raw,family,"basic")
			if family == "bow":
				target.global_position.x = player.global_position.x+350
				combat._update_basic_attack()
				var arrows := get_nodes_in_group("bow_projectile")
				if not _check(not arrows.is_empty() and arrows.back().damage == expected,"actual bow projectile snapshots linked damage"): return false
				for arrow in arrows: arrow.queue_free()
			elif family == "staff":
				combat._update_basic_attack(0)
				var bolts := get_nodes_in_group("staff_magic_bolt")
				if not _check(not bolts.is_empty() and bolts.back().damage == expected,"actual staff projectile snapshots linked damage"): return false
				for bolt in bolts: bolt.queue_free()
			else:
				combat.combo_index = 0
				combat._update_basic_attack(0)
				if not _check(target.damage_receiver.health == 10000-expected,"actual melee damage includes link once"): return false
			var stage_windows := player.combat_links.snapshot()
			player.prepare_next_stage(Vector2(960,780))
			if not _check(player.combat_links.snapshot() == stage_windows,"stage movement preserves remaining duration without refreshing"): return false
			# Save callbacks on a kill see armed windows; rejected hits cannot retain them.
			player.combat_links.windows.clear()
			target.reset_target()
			target.damage_receiver.max_health = 1
			target.damage_receiver.reset()
			target.defeated.connect(_capture_killing_links,CONNECT_ONE_SHOT)
			player.deal_weapon_damage(target,_event(family,"skill",1))
			if not _check(callback_links.has(family+"_link_skill"),"killing-blow callback captures next-hit window atomically"): return false
	return true

func _capture_killing_links(_target: PrototypeTarget) -> void:
	callback_links = player.combat_links.snapshot()

func _acquire_all_links() -> bool:
	for family in PrototypeWeaponRewards.FAMILY_IDS:
		controls.show_main_screen()
		if not controls.begin_retry(family,5,"standard","roan",false,0,"bow" if family != "bow" else "sword"): return false
		# A failed discovery write must leave the offered ability retryable and dormant.
		if not _gain(family+"_power"): return false
		var offered := PrototypeAbilityCodex.profile(family+"_link_switch")
		var needed := growth.next_level_experience()-growth.experience
		growth.experience += needed
		growth.total_experience += needed
		growth._offer_next_level()
		growth.offered_cards.assign([offered])
		sandbox._on_growth_choices_requested(growth.offered_cards,growth.level,growth.rerolls_remaining)
		var path := mastery_book.save_path
		mastery_book.save_path = "user://gp890_missing/abilities.jsonl"
		if not _check(not growth.choose_card(0) and not player.combat_links.ranks.has(offered.id) and player.combat_links.windows.is_empty() and growth.choosing,"failed discovery does not grant a live or learned link"): return false
		mastery_book.save_path = path
		if not _check(growth.choose_card(0) and player.combat_links.ranks.has(offered.id),"same offered link succeeds on retry"): return false
		if not _resolve_growth(): return false
		for card in PrototypeCombatLinks.CARDS:
			if card.category not in [family,"common"]: continue
			if not _gain(card.id): return false
			if not _check(player.combat_links.ranks.has(card.id) and mastery_book.snapshot().has(card.id) and not growth._card_available(card),"actual growth acquisition, discovery and one-rank limit: "+card.id): return false
			if not _check(player.combat_links.windows.is_empty(),"selecting a card never fabricates trigger history"): return false
	return true

func _tamper_links() -> bool:
	var saved := store.load_checkpoint()
	for value in [-1,0,100,"2",true]:
		var bad := saved.duplicate(true)
		bad.player.combat_links.bow_link_switch = value
		if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved,"invalid timer rejected atomically"): return false
	var old := saved.duplicate(true)
	old.player.erase("combat_links")
	if not _check(store.save_checkpoint(old) == OK,"previous checkpoints without link state still load"): return false
	return _check(store.save_checkpoint(saved) == OK,"restore current checkpoint after legacy validation")

func _ui_links(rendering: bool) -> bool:
	var directory := OS.get_environment("COMBAT_LINKS_RENDER_DIR") if rendering else ""
	if rendering:
		if not _check(DisplayServer.get_name() != "headless" and not directory.is_empty(),"real renderer and output directory"): return false
		DirAccess.make_dir_recursive_absolute(directory)
	var before: Dictionary = sandbox._capture_run_build()
	var rng := player.critical_rng.state
	var files := FileAccess.get_file_as_bytes(mastery_book.save_path)
	for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,800)]:
		root.size = dimensions
		root.content_scale_size = Vector2i(1920,1080)
		await process_frame
		controls.size = root.get_visible_rect().size if rendering else Vector2(dimensions)
		controls._refresh_layout()
		if not _check(controls.open_hero_status() and paused,"real status navigation pauses combat"): return false
		var stopped := player.combat_links.snapshot()
		player.set_physics_process(true)
		await physics_frame
		await physics_frame
		player.set_physics_process(false)
		if not _check(player.combat_links.snapshot() == stopped,"global pause freezes links even when player physics is enabled"): return false
		var safe: Rect2 = controls._safe_area_in_viewport()
		_tap(HeroStatusView.layout(safe).links.get_center())
		if not _check(controls.hero_status_detail == "links","dedicated links button opens overlay"): return false
		var view := CombatLinksView.layout(safe)
		var targets: Array = view.filters+view.cards+[view.previous,view.next,view.close]
		for i in targets.size():
			if not _check(safe.encloses(targets[i]),"safe touch bounds"): return false
			for j in range(i+1,targets.size()):
				if not _check(not targets[i].intersects(targets[j]),"no overlapping touch targets"): return false
		for index in 5:
			_tap(view.filters[index].get_center())
			if not _check(int(controls.combat_link_options[["family","kind","status","order","ownership"][index]]) == 1 and controls.combat_link_options.page == 0,"filter button updates corresponding real option and resets pagination"): return false
		controls.combat_link_options = CombatLinksView.defaults()
		var entries := CombatLinksView.cards(controls.run_build_state,controls.combat_link_options)
		_tap(view.cards[1].get_center())
		if not _check(controls.combat_link_options.selected == entries[1].id and CombatLinksView.detail(entries[1],controls.run_build_state).size() == 3,"effect selection exposes actual trigger/prerequisite guide"): return false
		for family_filter in 3:
			for kind_filter in 3:
				for status_filter in 3:
					for ownership_filter in 2:
						var options := {"family":family_filter,"kind":kind_filter,"status":status_filter,"ownership":ownership_filter,"order":1}
						var filtered := CombatLinksView.cards(controls.run_build_state,options)
						for card in filtered:
							if not _check((ownership_filter == 1 or card.learned) and (status_filter != 1 or card.live) and (status_filter != 2 or not card.live),"combined filters respect state without mutation"): return false
		for ignored in 30: _tap(view.next.get_center())
		var pages := maxi(1,ceili(float(entries.size())/CombatLinksView.PAGE_SIZE))
		if not _check(int(controls.combat_link_options.page) == pages-1,"pagination clamps at final page"): return false
		if rendering:
			for mode in ["owned","future","active"]:
				controls.combat_link_options = CombatLinksView.defaults()
				controls.combat_link_options.ownership = 1 if mode == "future" else 0
				if mode == "active": controls.combat_link_options.kind = 2; controls.combat_link_options.status = 1; controls.combat_link_options.family = 2
				controls.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				if not _check(root.get_texture().get_image().save_png(directory.path_join("%s_%dx%d.png" % [mode,dimensions.x,dimensions.y])) == OK,"real-rendered link overlay saved"): return false
		_tap(view.close.get_center())
		if not _check(controls.hero_status_detail == "" and paused,"closing overlay preserves status pause"): return false
		controls.close_run_build()
		controls.advance_mode_timer_for_test(3.1)
		if not _check(not paused and sandbox._capture_run_build() == before and player.critical_rng.state == rng and FileAccess.get_file_as_bytes(mastery_book.save_path) == files,"filters/pages/inspect never change timers, combat, RNG or files"): return false
	return true
