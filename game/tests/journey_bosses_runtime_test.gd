extends "res://tests/gp277_306_runtime_test.gd"

class FailingBossCheckpointStore extends RunCheckpointStore:
	var fail_at := 0
	var writes := 0
	func save_checkpoint(value: Dictionary) -> Error:
		writes += 1
		if fail_at > 0 and writes == fail_at: return ERR_CANT_CREATE
		return super.save_checkpoint(value)

var assertions := 0
var output := ""
var new_director: JourneyBossDirector
var phase := "full"

func _check(ok: bool, label: String) -> bool:
	assertions += 1
	return super._check(ok,"Journey bosses: "+label)

func _run() -> void:
	store=FailingBossCheckpointStore.new()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): phase=args[0]
	output=OS.get_environment("JOURNEY_BOSS_RENDER_DIR")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	var prefix := "user://journey_bosses_"+(phase.replace("seed","restore").replace("resume","restore") if phase.begins_with("seed") or phase.begins_with("resume") else phase)
	store.save_path=prefix+"_checkpoint.json"
	legacy.save_path=prefix+"_meta.jsonl"
	journal.save_path=prefix+"_story.jsonl"
	if not phase.begins_with("resume"):
		store.clear_checkpoint()
		for suffix in ["_meta.jsonl","_story.jsonl","_records.jsonl","_achievements.jsonl"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix+suffix))
	sandbox=SANDBOX.instantiate()
	sandbox.checkpoint_store=store;sandbox.boss_legacy_store=legacy;sandbox.story_journal_store=journal
	sandbox.achievement_store.save_path=prefix+"_achievements.jsonl"
	sandbox.get_node("StageRunner").journey_bosses_enabled=true
	sandbox.get_node("RecoveryOrbController").drop_chance=0
	sandbox.get_node("LocalTestRecorder").record_path=prefix+"_records.jsonl"
	root.add_child(sandbox);current_scene=sandbox
	await process_frame
	controls=sandbox.get_node("CanvasLayer/GroundMovementControls")
	player=sandbox.get_node("Player");growth=sandbox.get_node("PrototypeGrowthController")
	runner=sandbox.get_node("StageRunner");weapons=sandbox.get_node("Player/PrototypeWeaponController")
	recorder=sandbox.get_node("LocalTestRecorder");festival_ultimate=sandbox.get_node("Player/UltimateController")
	new_director=sandbox.journey_bosses
	sandbox.get_node("CombatFeedbackController").configure(0.0,false,false)
	growth.jobs_enabled=false
	for node in [player,weapons,festival_ultimate,runner,new_director,sandbox.get_node("ClockTrapController"),sandbox.get_node("RouteTerrain")]: node.set_process(false);node.set_physics_process(false)
	if phase.begins_with("resume"):
		var resumed_id: String="ian" if phase.ends_with("ian") else "aurel" if phase.ends_with("aurel") else "belo"
		var restored: bool=sandbox.continue_saved_run()
		if not _check(restored and new_director.state.flow=="intro" and new_director.state.boss==resumed_id and runner.stage_number==({"belo":5,"ian":6,"aurel":10}[resumed_id]),"separate process resumes exact boss entrance"):return
		if not await _boss(resumed_id):return
	elif phase=="combat":
		if not await _combat():return
	elif phase=="validate":
		if not _validation():return
	else:
		var prior_clear := phase in ["hidden","render","fault","narrative","seed_ian","seed_aurel"]
		if prior_clear:
			if not _check(journal.record_ending("prior",ArrivalEnding.ID,"roan","rescue")==OK and sandbox._sync_achievements()==OK,"prior full journey durably earns first dawn"):return
		if not _check(controls.begin_retry("sword",10,"journey","roan",phase in ["narrative","first_story"],0,"bow") and not new_director.state.is_empty() and new_director.state.unlocked==prior_clear,"new journey initializes dedicated boss state and achievement gate"):return
		if not _settle_scenes():return
		for n in range(1,11):
			if n in [2,4,6]:
				player.position=Vector2(3130,780)
				new_director._process(.6)
				if not _check(n in new_director.state.sigils,"standing at real rune activates current stage once"):return
				var count: int=new_director.state.sigils.size()
				new_director._process(1)
				if not _check(new_director.state.sigils.size()==count,"rune cannot duplicate"):return
			if not _regular():return
			if n==5:
				if not _check(new_director.state.flow=="intro" and new_director.state.boss=="belo","mid boss interrupts after five regular stages"):return
				if phase=="seed":
					if not _check(RunCheckpointStore.valid_state(store.load_checkpoint()) and store.load_checkpoint().stage.number==5 and store.load_checkpoint().journey_bosses.boss=="belo","pre-boss checkpoint valid"):return
					_done();return
				if not await _capture("belo_intro"):return
				if not await _boss("belo"):return
			if n==6:
				if not _check(new_director.state.flow=="portal" and JourneyBossProgress.can_enter(new_director.state)==prior_clear,"portal requires both permanent achievement and all three runes"):return
				if not await _capture("ian_portal_"+str(prior_clear)):return
				if prior_clear:
					if not _check(_touch_action("enter"),"enter optional workshop"):return
					if phase=="seed_ian":
						if not _check(store.load_checkpoint().get("journey_bosses",{}).get("flow")=="intro" and store.load_checkpoint().journey_bosses.boss==new_director.state.boss and store.load_checkpoint().stage.number==runner.stage_number,"durable Ian entrance matches current state"):return
						_done();return
					if not await _boss("ian"):return
					if not _check(journal.snapshot().secrets.has(JourneyBossProgress.SECRET) and player.relic_state.id==PrototypeRelic.IAN_ID and is_equal_approx(player.skill_recharge_multiplier(),1/.85) and is_equal_approx(player.attack_speed_multiplier(),1.10) and is_equal_approx(player.combat_stats_snapshot().attack_speed,110.0),"Ian grants durable memory/unlock and working pocketwatch"):return
				else:
					var before := new_director.state.duplicate(true)
					if not _check(not new_director.action("enter") and not _touch_action("enter") and before==new_director.state,"locked portal cannot be forced through action API"):return
					if not _check(_touch_action("leave"),"optional route can be declined"):return
			if n<10:
				if not _intermission():return
			else:
				if controls.current_screen_mode()==12:
					if not _check(sandbox._resolve_boss_choice("rescue"),"existing Sera decision remains intact"):return
				if not _settle_scenes():return
				if runner.heart_battle==HeartEncounter.ACTIVE:
					_defeat(runner.heart);runner._process(.1)
					if controls.story_scene.get("id")==HeartEncounter.VICTORY_SCENE:
						if not _check(sandbox._acknowledge_heart_victory(),"existing heart victory remains intact"):return
				if not _check(new_director.state.boss=="aurel" and new_director.state.flow=="intro" and not runner.current_metrics().run_complete,"final dragon blocks ending and completion"):return
				if phase=="seed_aurel":
					if not _check(store.load_checkpoint().get("journey_bosses",{}).get("flow")=="intro" and store.load_checkpoint().journey_bosses.boss==new_director.state.boss and store.load_checkpoint().stage.number==runner.stage_number,"durable Aurel entrance matches current state"):return
					_done();return
				if not await _boss("aurel"):return
				if not _settle_scenes():return
				if runner.final_ritual.get("phase")==FinalRitual.CHOOSING:
					if not _check(sandbox._on_final_action("liberation") and sandbox._acknowledge_final_ending(),"existing ending choice follows dragon"):return
				if not _check(new_director.state.aurel=="done" and not growth.run_active and recorder.has_completed_run(recorder.checkpoint_snapshot().id),"all mandatory bosses required before recorded completion"):return
				if not _check(PermanentAchievements.earned(sandbox.achievement_store.snapshot(),"first_dawn"),"first-dawn achievement persists after real completion"):return
	_done()

func _touch_action(id: String) -> bool:
	var actions: Array=controls.story_scene.get("actions",[])
	for i in actions.size():
		if actions[i].id != id:continue
		var previous:Dictionary=new_director.state.duplicate(true)
		var view:=JourneyBossView.layout(controls._safe_area_in_viewport(),actions.size())
		_tap(view.choices[i].get_center())
		return new_director.state != previous
	return false

func _settle_scenes() -> bool:
	for ignored in 12:
		if controls.current_screen_mode()!=18 or controls.story_scene.get("id") in ["journey_boss",FinalRitual.CHOICE_SCENE]:return true
		var id:String=controls.story_scene.id
		if not _check(sandbox._acknowledge_story(id),"acknowledge original story scene: "+id):return false
	return _check(false,"original story scene sequence terminates")

func _regular() -> bool:
	for ignored in 12:
		if not _settle_scenes():return false
		if runner.stage_complete:break
		if runner.current_section==PrototypeStageRunner.Section.ADVANCE_ONE:player.position.x=1240
		elif runner.current_section==PrototypeStageRunner.Section.ADVANCE_TWO:player.position.x=3840
		else:
			for enemy in runner._active_enemies.duplicate():_defeat(enemy)
		if not _resolve_growth():return false
		runner._process(.1)
	if not _settle_scenes():return false
	return _check(runner.stage_complete,"regular stage completed by defeating actual enemies")

func _intermission() -> bool:
	if not _settle_scenes():return false
	if controls.current_screen_mode()==11 and not sandbox._claim_weapon_reward(""):return _check(false,"normal weapon reward after extra encounter")
	if runner.awaiting_guardian_choice() and not sandbox._resolve_guardian_choice("rescue"):return _check(false,"guardian choice preserved")
	if controls.current_screen_mode()==11 and not sandbox._claim_weapon_reward(""):return false
	var candidates := runner.available_routes()
	if not _check(not candidates.is_empty(),"regular route remains available"):return false
	sandbox._continue_stage(candidates[0].id)
	return _check(not runner.stage_complete,"resume regular journey without incrementing extra boss as a numbered region")

func _boss(id: String) -> bool:
	var saved := store.load_checkpoint()
	if not _check(saved.journey_bosses.flow=="intro" and saved.journey_bosses.boss==id,"entrance state saved before combat"):return false
	if phase == "fault":
		store.fail_at=store.writes+1
		if not _check(not new_director.action("start") and not runner.extra_boss_active and paused,"failed pre-entry save blocks combat"): return false
		store.fail_at=0
	if not await _capture(id+"_intro"): return false
	if not _check(_touch_action("start") and runner.extra_boss_active and not paused,"boss intro starts real combat"):return false
	var boss:JourneyBoss=new_director.actor
	boss.set_process(false)
	if not _check(boss.is_targetable() and runner.final_enemy()==boss and boss.damage_receiver.health==JourneyBoss.HP[id],"dedicated boss actor/health/target integration"):return false
	if not _check(not sandbox._claim_weapon_reward("") and not new_director.action("continue"),"underlying rewards and final action cannot bypass combat"):return false
	for pattern in 3:
		boss.attack_serial=pattern;boss._begin_next_pattern()
		if not _check(boss.state==boss.State.WARNING and not boss.pattern_name(pattern).is_empty(),"three telegraphed attack patterns per boss"):return false
	if not await _battle_capture(id):return false
	_defeat(boss)
	if not _resolve_growth():return false
	new_director._process(.1)
	if not _check(new_director.state.flow==("victory" if id=="aurel" else "reward") and paused,"defeat opens saved victory/reward screen"):return false
	if not await _capture(id+"_victory"):return false
	if phase == "fault" and id == "belo":
		var old_gear: Dictionary=weapons.checkpoint_snapshot()
		var hp: int=player.damage_receiver.health
		store.fail_at=store.writes+2
		if not _check(not new_director.action("weapon:sword") and weapons.checkpoint_snapshot()==old_gear and player.damage_receiver.health==hp and new_director.state.flow=="reward","reward commit failure rolls equipment/health/phase back"):return false
		store.fail_at=0
	if id=="belo":
		var action_id:String=""
		for item in controls.story_scene.actions:
			if item.get("enabled",true) and (phase!="skill" or item.id.begins_with("skill:")):action_id=item.id;break
		if not _check(_touch_action(action_id) and new_director.state.belo=="done","one bonus reward and recovery commit atomically"):return false
	elif id=="ian":
		if not _check(_touch_action("ian_equip"),"claim unique relic"):return false
	else:
		if not _check(_touch_action("continue") and runner.extra_completion_ready,"record dragon before ending"):return false
	if not _check(not new_director.action("continue"),"duplicate action never grants second reward"):return false
	return true

func _battle_capture(id:String)->bool:
	if output.is_empty():return true
	if not await _capture(id+"_battle"):return false
	return true

func _capture(name:String)->bool:
	if output.is_empty():return true
	for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,800)]:
		root.size=dimensions;await process_frame
		controls.size=controls.get_viewport_rect().size
		controls.queue_redraw();await RenderingServer.frame_post_draw
		if not _check(root.get_texture().get_image().save_png(output.path_join(name+"_%dx%d.png"%[dimensions.x,dimensions.y]))==OK,"render boss panel"):return false
	return true

func _combat() -> bool:
	controls.begin_retry("sword",10,"journey","roan",false,0,"bow")
	for id in JourneyBossProgress.BOSS_IDS:
		new_director.state.boss=id;new_director.state.flow="intro"
		new_director._start_battle()
		var boss:JourneyBoss=new_director.actor;boss.set_process(false)
		for p in 2:
			boss.phase=p+1
			for pattern in 3:
				boss.attack_serial=pattern;boss._begin_next_pattern()
				var health:int=player.damage_receiver.health
				boss._process(.3)
				if not _check(boss.state==boss.State.WARNING and player.damage_receiver.health==health,"warning deals no premature damage"):return false
				boss._state_elapsed_s=1.1;boss._update_warning()
				if not _check(boss.state==boss.State.CHARGING,"warning leads to intended attack"):return false
				if not output.is_empty():
					boss._set_state(boss.State.WARNING,"공격 예고")
					await process_frame;controls.queue_redraw();boss.queue_redraw();await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output.path_join(id+"_phase%d_pattern%d.png"%[p+1,pattern]))
				boss._state_elapsed_s=2.0;boss._update_charge(.1)
				if id=="aurel" and p==1 and boss.state==boss.State.WARNING:
					if not _check(boss._chain_active,"dragon phase two connects a second telegraphed attack"):return false
					boss._state_elapsed_s=1.1;boss._update_warning();boss._state_elapsed_s=2.0;boss._update_charge(.1)
				if not _check(boss.state==boss.State.RECOVERY,"every attack leaves punishable recovery"):return false
		player.damage_receiver.health=100
		player.damage_receiver.tick(100)
		player.invincible=false
		boss.attack_serial+=100
		var danger:=Rect2(player.position-Vector2(80,100),Vector2(160,180))
		boss._damage_area(danger,0)
		var after_hit: int=player.damage_receiver.health
		boss._damage_area(danger,0)
		if not _check(after_hit<100 and player.damage_receiver.health==after_hit,"real hazard hits once per attack identity"):return false
		player.damage_receiver.tick(100)
		player.invincible=true
		boss.attack_serial+=1
		boss._damage_area(danger,0)
		if not _check(player.damage_receiver.health==after_hit,"manual evade invulnerability blocks boss hazard"):return false
		player.invincible=false
		for family in PrototypeWeaponRewards.FAMILY_IDS:
			var e:=DamageEvent.new();e.damage=40;e.tags=PackedStringArray([family,"basic"])
			boss.state=boss.State.RECOVERY
			if not _check(boss._adjust_damage_event(e).damage==50,"all six families share fair vulnerability"):return false
		boss.reset_target()
		var threshold:=DamageEvent.new()
		threshold.event_id=StringName("phase-threshold:"+id)
		threshold.damage=JourneyBoss.HP[id]/2+1
		threshold.tags=PackedStringArray(["sword","basic"])
		boss.receive_damage(threshold)
		if not _check(boss.phase==2 and boss.state==boss.State.PHASE_TRANSITION,"actual damage at half health changes phase"):return false
		new_director.cleanup()
	return true

func _validation() -> bool:
	var value:=JourneyBossProgress.initial(false)
	var stage:Dictionary={"run_mode":"journey","limit":10,"number":1}
	if not _check(JourneyBossProgress.valid(value,stage),"new state valid"):return false
	for change in [{"sigils":[2,2]},{"sigils":[6,2]},{"flow":"battle"},{"unlocked":"yes"},{"aurel":"done"},{"ian":"done"},{"boss":"unknown"}]:
		var bad:=value.duplicate(true);bad.merge(change,true)
		if not _check(not JourneyBossProgress.valid(bad,stage),"reject corrupt or out-of-order state"):return false
	var unlocked:=JourneyBossProgress.initial(true)
	unlocked.sigils=[2,4,6];unlocked.belo="done";unlocked.boss="ian";unlocked.flow="intro"
	var roundtrip:Dictionary=JSON.parse_string(JSON.stringify(unlocked))
	if not _check(JourneyBossProgress.can_enter(roundtrip) and JourneyBossProgress.valid(roundtrip,{"run_mode":"journey","limit":10,"number":6}),"rune eligibility and entrance survive JSON numeric conversion"):return false
	roundtrip.sigils=[2,4]
	return _check(not JourneyBossProgress.can_enter(roundtrip),"earned achievement alone cannot bypass missing rune")

func _done() -> void:
	paused=false;sandbox.free()
	print("Journey bosses runtime test: OK (%s; %d assertions)"%[phase,assertions]);quit(0)
