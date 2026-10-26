extends SceneTree

const SANDBOX := preload("res://tests/fixtures/legacy_movement_sandbox.tscn")
var failed := false
var checks := 0
var player: PrototypePlayer
var weapons: PrototypeWeaponController

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sandbox := SANDBOX.instantiate()
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	sandbox.get_node("CanvasLayer/GroundMovementControls").begin_retry("sword",3,"standard","roan")
	sandbox.process_mode = Node.PROCESS_MODE_DISABLED
	player = sandbox.get_node("Player")
	weapons = player.get_node("PrototypeWeaponController")
	for hero in PrototypeCharacters.IDS:
		player.reset_movement_test(Vector2(960,780))
		player.set_character(hero)
		weapons.reset_combat("sword")
		var sprite := player.avatar_sprite
		var animation := HeroMovementAnimation.new()
		var polish := HeroMotionPolish.new()
		var baseline := Vector2.ONE * 154.0 / float(HeroMovementAnimation.REGIONS[hero][0].size.y)
		for state in ["idle","run","jump","land"]:
			polish.reset(sprite)
			var transforms: Array[Transform2D] = []
			for frame in 24:
				var t := frame / 120.0
				var velocity := Vector2(400,0) if state == "run" else Vector2(0,-1000 + frame * 80) if state == "jump" else Vector2.ZERO
				animation.apply_frame(sprite,hero,state,t)
				polish.update(sprite,1.0/120.0,state,t,velocity,1,0,false,false)
				transforms.append(sprite.transform)
				_check(sprite.scale.x > baseline.x*.9 and sprite.scale.y > baseline.y*.9 and sprite.scale.x < baseline.x*1.1 and sprite.scale.y < baseline.y*1.1,"bounded body deformation: "+state)
				var foot := sprite.transform * Vector2(0,128)
				_check(absf(foot.x) < .001 and (absf(foot.y-60) < .001 if state != "run" else foot.y <= 60.001 and foot.y >= 57.1),"planted foot / bounded run bounce: "+state)
			_check(transforms[3] != transforms[11],"continuous motion between atlas frames: "+state)
			if state == "land": _check(sprite.scale.is_equal_approx(baseline),"landing recovers without lingering squash")
		# Equal elapsed time produces equal idle/run transforms at 30/60/120 Hz.
		for state in ["idle","run"]:
			var previous := Transform2D.IDENTITY
			for hz in [30,60,120]:
				polish.reset(sprite)
				for frame in hz:
					animation.apply_frame(sprite,hero,state,1.0)
					polish.update(sprite,1.0/hz,state,1.0,Vector2(400,0),1,0,false,false)
				if hz != 30: _check(sprite.transform.is_equal_approx(previous),"frame rate independent "+state)
				previous = sprite.transform
		for mobility in [1,2]:
			polish.reset(sprite)
			sprite.flip_h = true
			for frame in 18:
				sprite.get_parent().position.x = frame * 6.0
				animation.apply_frame(sprite,hero,"evade" if mobility == 1 else "air_dash",frame/60.0)
				polish.update(sprite,1.0/60.0,"evade" if mobility == 1 else "air_dash",frame/60.0,Vector2(900,0),-1,mobility,false,false)
				_check(polish.trails.size() <= HeroMotionPolish.MAX_TRAILS,"strict residual allocation cap")
			_check(polish.trails.size() >= 3 and polish.trails[0].flip and polish.trails[0].air == (mobility == 2),"ground/air trail keeps actual facing and palette")
			var world: Transform2D = polish.trails[0].transform
			sprite.get_parent().position.x += 100
			_check(polish.trails[0].transform == world,"afterimage stays in world rather than following player")
			polish.update(sprite,0.2,"idle",0,Vector2.ZERO,1,0,false,false)
			_check(polish.trails.is_empty(),"afterimages expire after mobility")
		sprite.get_parent().position.x = 0
		# Integration: accepted attacks of all six families pulse on the original hit tick.
		var target: PrototypeTarget = sandbox.get_node("Targets/RearTarget")
		for family in PrototypeWeaponRewards.FAMILY_IDS:
			player.reset_movement_test(Vector2(960,780))
			weapons.reset_combat(family)
			target.visible = true
			target.reset_target()
			target.damage_receiver.max_health = 10000
			target.damage_receiver.reset()
			target.global_position = player.global_position + Vector2(80,0)
			weapons.target_selector.current_target = target
			var combat: Node = weapons.combat_for(family)
			if family == "bow": combat._update_basic_attack()
			else: combat._update_basic_attack(0)
			_check(player.motion_polish.attack_elapsed == 0 and player.motion_polish.attack_family == family,"accepted basic drives family pulse: "+family)
			var impact := sprite.rotation
			player._update_avatar_action_visual(.12)
			_check(absf(sprite.rotation) < absf(impact),"attack recovers smoothly: "+family)
			var candidates := PrototypeSkillRewards.pool_for(family).filter(func(id: String) -> bool: return not PrototypeSkillRewards.SKILLS[id].hit_times_s.is_empty())
			var definition: SkillDefinition = PrototypeSkillRewards.SKILLS[candidates[0]]
			combat.skill_1 = definition
			combat.request_skill_1()
			_check(player.motion_polish.anticipating and player.motion_polish.attack_elapsed == 0,"accepted skill has anticipation: "+family)
			player._update_avatar_action_visual(.04)
			var elapsed := player.motion_polish.attack_elapsed
			combat.request_skill_1()
			_check(player.motion_polish.attack_elapsed == elapsed,"rejected skill never restarts animation")
			combat._update_skill_action(float(definition.hit_times_s[0])+.001)
			_check(not player.motion_polish.anticipating and player.motion_polish.attack_elapsed == 0,"actual skill release pulses: "+family)
			for shot in get_nodes_in_group("player_projectile"): shot.queue_free()
		# Recoil is tied to an applied event, blocked duplicate damage does not restart it.
		player.reset_movement_test(Vector2(960,780))
		weapons.reset_combat("sword")
		for side in [-1,1]:
			player.damage_receiver.reset()
			var event := DamageEvent.new()
			event.event_id = StringName("polish_hit_%s_%d" % [hero,side])
			event.damage = 1
			event.source_position = player.global_position + Vector2(side*40,0)
			_check(player.receive_damage(event) == DamageReceiver.Result.APPLIED,"real damage accepted")
			player._update_avatar_action_visual(.01)
			_check(signf(sprite.rotation) == -side,"visual recoil goes away from attacker")
			var recoil := player.motion_polish.hit_remaining
			player.receive_damage(event)
			_check(player.motion_polish.hit_remaining == recoil,"duplicate/immune damage never retriggers recoil")
		player.reset_movement_test(Vector2(960,780))
		weapons.reset_combat("sword")
		_check(player.motion_polish.switch_elapsed < 0,"initial loadout has no switch flourish")
		weapons.request_weapon_switch()
		_check(player.motion_polish.switch_elapsed == 0 and weapons.active_weapon_id == "bow","successful switch starts flourish")
		player._update_avatar_action_visual(.05)
		var switch_time := player.motion_polish.switch_elapsed
		weapons.request_weapon_switch()
		_check(player.motion_polish.switch_elapsed == switch_time,"cooldown blocked switch does not restart flourish")
		var before := weapons.checkpoint_snapshot()
		var rng := player.critical_rng.state
		var position := player.position
		var velocity := player.velocity
		player._update_avatar_action_visual(.4)
		_check(player.motion_polish.switch_elapsed < 0,"switch flourish fades fully")
		_check(before == weapons.checkpoint_snapshot() and player.critical_rng.state == rng and player.position == position and player.velocity == velocity,"animation never changes save/RNG/physics")
		var paused_clock := player.motion_polish.clock_s
		await physics_frame
		await physics_frame
		_check(player.motion_polish.clock_s == paused_clock,"paused scene freezes all presentation clocks")
		for interruption in ["hit","death","fall","evade"]:
			player.reset_movement_test(Vector2(960,780))
			player.begin_attack_visual("sword_slash",1)
			player.motion_polish.switch_weapon(hero)
			match interruption:
				"hit": player._hit_flash_remaining_s = .12
				"death": player.damage_receiver.dead = true
				"fall": player._fall_recovery_active = true
				"evade": player._mobility_action = PrototypePlayer.MobilityAction.GROUND_EVADE
			player._update_avatar_action_visual(.01)
			_check(player.motion_polish.attack_elapsed < 0,"interrupt clears anticipation: "+interruption)
			if interruption != "evade": _check(player.motion_polish.trails.is_empty() and player.motion_polish.switch_elapsed < 0,"interrupt clears stale effects: "+interruption)
		player.prepare_next_stage(Vector2(960,780))
		_check(player.motion_polish.trails.is_empty() and player.motion_polish.switch_elapsed < 0 and sprite.rotation == 0,"stage reset clears visual transforms/effects")
		player.motion_polish.switch_weapon(hero)
		player.set_character(hero)
		_check(player.motion_polish.switch_elapsed < 0 and sprite.rotation == 0,"character reset clears effects")
		var preview := EquippedHeroPreview.new()
		for family in PrototypeWeaponRewards.FAMILY_IDS:
			var area := Rect2(0,0,280,280)
			var a := preview.snapshot(hero,family,0,area)
			var b := preview.snapshot(hero,family,.31,area)
			_check(a.foot == b.foot and a.body != b.body and a.hand != b.hand and a.rotation != b.rotation,"preview breathing/sway with planted feet: "+family)
			_check(area.encloses(b.body) or b.body.get_center().distance_to(area.get_center()) < area.size.x*.4,"preview stays centered: "+family)
	sandbox.free()
	await process_frame
	var rendering := OS.get_environment("HERO_MOTION_RENDER_DIR")
	if not rendering.is_empty(): await _render_gallery(rendering)
	if not failed: print("GP-831–840 animation runtime: OK (%d assertions)" % checks)
	quit(1 if failed else 0)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("GP-831–840: "+message)

class MotionSample extends Node2D:
	var motion := HeroMotionPolish.new()
	func _draw() -> void: motion.draw(self)

class PreviewSample extends Control:
	var hero := "roan"
	var family := "sword"
	var time := 0.0
	var preview := EquippedHeroPreview.new()
	func _draw() -> void: preview.draw(self,hero,family,time,Rect2(0,0,240,200))

func _render_gallery(directory: String) -> void:
	_check(DisplayServer.get_name() != "headless","gallery uses actual rendering backend")
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(1500,650)
	root.content_scale_size = Vector2i(1500,650)
	var background := ColorRect.new()
	background.color = Color("182c3b")
	background.size = Vector2(1500,650)
	root.add_child(background)
	var names := ["Breathing","Running","Jump / apex","Landing","Ground evade","Air dash","Hit recoil","Attack timing","Weapon switch","Equipped preview"]
	for hero in PrototypeCharacters.IDS:
		var gallery := Node2D.new()
		root.add_child(gallery)
		var samples: Array[MotionSample] = []
		var preview := PreviewSample.new()
		preview.hero = hero
		preview.position = Vector2(1230,380)
		gallery.add_child(preview)
		for index in 10:
			var label := Label.new()
			label.text = hero.capitalize()+" · "+names[index]
			label.position = Vector2(index%5*300+24,index/5*310+24)
			gallery.add_child(label)
			if index == 9: continue
			var sample := MotionSample.new()
			sample.position = Vector2(index%5*300+150,index/5*310+228)
			gallery.add_child(sample)
			var sprite := Sprite2D.new()
			sample.add_child(sprite)
			samples.append(sample)
		for frame in 30:
			var time := frame*.05
			var phase := fposmod(time,.5)
			for index in samples.size():
				var sample := samples[index]
				var sprite: Sprite2D = sample.get_child(0)
				var state: String = ["idle","run","jump","land","evade","air_dash","hit","idle","idle"][index]
				var velocity := Vector2(420,0) if index == 1 else Vector2(0,-1000+phase*4000) if index == 2 else Vector2.ZERO
				if index == 2 and velocity.y >= 0: state = "fall"
				HeroMovementAnimation.new().apply_frame(sprite,hero,state,phase if index != 3 else minf(phase,.14))
				if index == 6 and frame%10 == 0: sample.motion.recoil(-1)
				if index == 7:
					if frame%10 == 0: sample.motion.attack("sword",1,true)
					if frame%10 == 2: sample.motion.attack("sword",1,false)
					var combat := HeroCombatAnimation.new()
					combat.begin("sword_slash",1)
					if phase >= .1: combat.strike("sword_slash",1,false)
					combat.elapsed_s = maxf(0,phase-.1)
					combat.apply(sprite,hero)
				if index == 8 and frame%10 == 0: sample.motion.switch_weapon(hero)
				# Move the rendered avatar across its cell; captured trails retain earlier positions.
				if index in [4,5]: sprite.position.x += (phase-.25)*180
				sample.motion.update(sprite,.05,state,minf(phase,.14),velocity,1,1 if index == 4 else 2 if index == 5 else 0,index == 7,false)
				sample.queue_redraw()
			preview.time = time
			preview.family = PrototypeWeaponRewards.FAMILY_IDS[(frame/5)%6]
			preview.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var path := directory.path_join("%s_%02d.png" % [hero,frame])
			_check(root.get_texture().get_image().save_png(path) == OK,"rendered gallery frame saved")
		gallery.free()
	background.free()
