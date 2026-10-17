extends SceneTree

const SANDBOX := preload("res://scenes/movement/ground_movement_sandbox.tscn")
var failed := false
var player: PrototypePlayer
var weapons: PrototypeWeaponController

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sandbox := SANDBOX.instantiate()
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	sandbox.get_node("CanvasLayer/GroundMovementControls").begin_retry("sword", 3, "standard", "roan")
	sandbox.process_mode = Node.PROCESS_MODE_DISABLED
	player = sandbox.get_node("Player")
	weapons = player.get_node("PrototypeWeaponController")
	var target: PrototypeTarget = sandbox.get_node("Targets/RearTarget")
	for character in PrototypeCharacters.IDS:
		_reset(character, "sword")
		var animator := player.combat_animation
		var image: Image = HeroCombatAnimation.SHEETS[character].get_image()
		_check(image != null and image.get_size() == Vector2i(1536, 1024), "combat sheet imports")
		_check(image.get_pixel(0, 0).a < 0.02, "background stays transparent")
		for index in 16:
			animator.apply_frame(player.avatar_sprite, character, index)
			var texture: AtlasTexture = player.avatar_sprite.texture
			var bounds: Rect2 = HeroCombatAnimation.REGIONS[character][index]
			_check(texture.get_size() == HeroCombatAnimation.FRAME_SIZE and texture.filter_clip, "padded atlas isolates frame")
			_check(Rect2(Vector2.ZERO, image.get_size()).encloses(texture.region), "no out-of-bounds sampling")
			var opaque := 0
			var last_y := 0
			for y in range(int(bounds.position.y), int(bounds.end.y)):
				for x in range(int(bounds.position.x), int(bounds.end.x)):
					if image.get_pixel(x, y).a > 0.5:
						opaque += 1
						last_y = y
			_check(opaque > 5000, "complete opaque character in every frame")
			var foot := texture.margin.position.y + last_y - texture.region.position.y - texture.get_height() * 0.5
			_check(absf(player.avatar_sprite.position.y + foot * player.avatar_sprite.scale.y - 60) < 2.5, "actual boot alpha touches floor")
			for other in 16:
				if other == index: continue
				_check(not bounds.intersects(HeroCombatAnimation.REGIONS[character][other]), "no neighboring pose inside frame")
		# Real automatic sword combo: pose starts on damage, without adding windup delay.
		target.global_position = player.global_position + Vector2(90, 0)
		target.visible = true
		target.reset_target()
		target.damage_receiver.max_health = 10000
		target.damage_receiver.reset()
		weapons.target_selector.current_target = target
		for combo in 3:
			weapons.sword_combat._basic_remaining_s = 0
			var health := target.damage_receiver.health
			weapons.sword_combat._update_basic_attack(0)
			_check(target.damage_receiver.health < health, "sword damage occurs on original tick")
			_check(animator.frame_index == (5 if combo == 2 else 1), "combo impact pose on the same tick")
		player._update_avatar_action_visual(0.25)
		_check(animator.clip.is_empty(), "basic recovery returns to movement")
		# Real bow projectile creation and empty-string release frame occur together.
		_reset(character, "bow")
		target.global_position = player.global_position + Vector2(140, 0)
		weapons.target_selector.current_target = target
		var shots := weapons.bow_combat.projectile_fired_count
		weapons.bow_combat._update_basic_attack()
		_check(weapons.bow_combat.projectile_fired_count == shots + 1 and animator.frame_index == 10, "bow release matches actual projectile")
		# Every existing skill uses its actual start/hit/finish controller paths.
		for weapon in ["sword", "bow"]:
			for skill_id in PrototypeSkillRewards.POOLS[weapon]:
				_reset(character, weapon)
				var combat: Node = weapons.sword_combat if weapon == "sword" else weapons.bow_combat
				var definition: SkillDefinition = PrototypeSkillRewards.SKILLS[skill_id]
				combat.skill_1 = definition
				combat.request_skill_1()
				_check(not animator.clip.is_empty() and animator.frame_index in [0, 4, 8, 12], "accepted skill starts anticipation: " + skill_id)
				var original_clip := animator.clip
				var original_time := animator.elapsed_s
				combat.request_skill_1()
				_check(animator.clip == original_clip and animator.elapsed_s == original_time, "rejected repeat does not restart animation")
				var elapsed := 0.0
				for time in definition.hit_times_s:
					var dt := float(time) - elapsed + 0.0001
					player._update_avatar_action_visual(dt)
					combat._update_skill_action(dt)
					elapsed += dt
					_check(animator.frame_index in [1, 5, 10, 14], "actual skill hit retriggers impact/release: " + skill_id)
					if weapon == "sword" and combat._action == SwordCombatController.Action.LINE_SLASH:
						_check(animator.direction == combat._line_visual_direction and player.facing_direction == 1, "cross/alternating visual follows actual hit direction only")
				combat._update_skill_action(definition.duration_s - elapsed + 0.001)
				_check(animator.clip.is_empty() and not player._combat_action_active, "skill finish restores movement: " + skill_id)
				for shot in get_nodes_in_group("player_projectile"): shot.queue_free()
		# A real evade signal cancels an accepted skill; no stale strike may return.
		_reset(character, "bow")
		weapons.bow_combat.request_skill_1()
		player.set_combat_evade_allowed(true)
		player._start_air_dash()
		player._update_avatar_action_visual()
		_check(weapons.bow_combat._action == BowCombatController.Action.NONE and animator.clip.is_empty() and player.movement_animation.state == "air_dash", "actual evade cancels skill animation")
		# Facing overrides belong only to the render and clear when the attack ends.
		_reset(character, "sword")
		player.strike_attack_visual("sword_slash", -1, false)
		_check(player.avatar_sprite.flip_h and player.facing_direction == 1, "left strike does not change gameplay facing")
		player._update_avatar_action_visual(0.25)
		_check(not player.avatar_sprite.flip_h, "movement facing restored after strike")
		player.strike_attack_visual("sword_slash", 1, false)
		weapons.request_weapon_switch()
		_check(animator.clip.is_empty() and weapons.active_weapon_id == "bow", "switch clears old weapon pose")
		for interrupt in ["hit", "evade", "air_dash", "fall", "death"]:
			_reset(character, "sword")
			player.begin_attack_visual("sword_slash", 1)
			match interrupt:
				"hit": player._hit_flash_remaining_s = 0.12
				"evade": player._mobility_action = PrototypePlayer.MobilityAction.GROUND_EVADE
				"air_dash": player._mobility_action = PrototypePlayer.MobilityAction.AIR_DASH
				"fall": player._fall_recovery_active = true
				"death": player.damage_receiver.dead = true
			player._update_avatar_action_visual()
			_check(animator.clip.is_empty() and player.avatar_sprite.texture.atlas == HeroMovementAnimation.SHEETS[character], "interruption takes priority: " + interrupt)
		_reset(character, "sword")
		player.strike_attack_visual("sword_thrust", 1, false)
		var snapshot := weapons.checkpoint_snapshot()
		var shape: CapsuleShape2D = player.get_node("CollisionShape2D").shape
		player._update_avatar_action_visual(0.05)
		_check(snapshot == weapons.checkpoint_snapshot() and player.damage_receiver.health == 100 and shape.height == 120, "animation does not mutate gameplay/save state")
		var paused_time := animator.elapsed_s
		await physics_frame
		await physics_frame
		_check(animator.elapsed_s == paused_time, "paused scene freezes animation")
		player.prepare_next_stage(Vector2(960, 780))
		_check(animator.clip.is_empty(), "stage transition clears attack")
		player.begin_attack_visual("bow_shot", 1)
		player.set_character(character)
		_check(animator.clip.is_empty(), "character selection clears attack")
	sandbox.queue_free()
	await process_frame
	if not failed: print("Hero combat animation runtime: OK (32 frames, all skills, timing, interruption, save invariance)")
	quit(1 if failed else 0)

func _reset(character: String, weapon: String) -> void:
	player.reset_movement_test(Vector2(960, 780))
	player.set_character(character)
	weapons.reset_combat(weapon)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("Hero combat animation: " + message)
