extends SceneTree

const SANDBOX := preload("res://tests/fixtures/legacy_movement_sandbox.tscn")
var failures: int = 0
var assertions: int = 0

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("REGIONAL ROSTER: " + message)

func _run() -> void:
	var scene := SANDBOX.instantiate()
	scene.get_node("RecoveryOrbController").drop_chance = 0.0
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var runner: PrototypeStageRunner = scene.get_node("StageRunner")
	runner.set_stage_enabled(false)
	scene.get_node("CombatFeedbackController").configure(0.0, false, false)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var player: PrototypePlayer = scene.get_node("Player")
	player.damage_receiver.max_health = 100000
	player.damage_receiver.health = 100000
	var ownership := {}
	var observed := {}
	for route in RegionalEnemyRoster.REGULAR:
		runner.run_mode = "journey"
		runner.stage_limit = 10
		runner.stage_number = 9 if route == "city_gate" else 10 if route == "city_core" else 1
		runner.route_id = route
		runner.stage_enabled = true
		runner.reset_stage()
		for wave in [1, 2]:
			runner._deactivate_all_combat_enemies()
			if wave == 1: runner._activate_wave_one()
			else: runner._activate_wave_two()
			_check(runner._active_enemies.size() >= 2, "wave keeps combat and gate progression: " + route)
			for enemy in runner._active_enemies:
				var id: String = enemy.roster_id
				_check(not id.is_empty() and enemy.is_targetable(), "real wave activates configured species")
				_check(not ownership.has(id) or ownership[id] == route, "no species leaks into another region: " + id)
				ownership[id] = route
				observed[id] = true
				_check(enemy.body_sprite.texture != null, "wave texture loaded")
		_check(runner.armored_boar.region_species == RegionalEnemyRoster.ELITES[route], "regional elite also used for expedition reinforcement")
		if route in ["wind", "forest", "ruins", "festival"]:
			runner._activate_elite()
			_check(runner._active_enemies[0] == runner.armored_boar and runner.armored_boar.is_targetable(), "regional elite opens final gate when defeated")
	for id in ["slime", "rabbit", "bird", "wind_spirit", "seed_sack", "moth", "clock_doll", "rewind_doll", "soldier", "turret", "clown", "mask_guard", "parade_doll"]:
		_check(observed.has(id), "approved regular species appears in actual waves: " + id)
	runner.set_stage_enabled(false)
	# Seven new regular patterns: full warning, fixed aim, swept projectiles,
	# combat-clock freeze, cancellation, death and pooled actor reuse.
	var cases := [["wind", 1, 1], ["wind", 2, 2], ["forest", 2, 1], ["ruins", 0, 1], ["festival", 2, 1], ["city_gate", 0, 1], ["city_core", 0, 1]]
	for item in cases:
		var e: PrototypeEnemy = [runner.leaf_slime, runner.seed_sack, runner.wind_spirit][item[1]]
		for side in [-1, 1]:
			e.configure_route(item[0], true, item[2])
			e.set_stage_spawn(Vector2(2400, 650 if e.regional_pattern.airborne() else 780))
			e.reset_target()
			e.visible = true
			e.expedition_patterns = false
			player.position = e.position + Vector2(side * 300, 0)
			e._process(0.0)
			_check(e.state == PrototypeEnemy.State.WARNING and e.warning_line.visible, "warning visible: " + e.roster_id)
			var before := e.position
			var pose := e.body_sprite.transform
			e.set_enemy_time_scale(0.0)
			e._process(0.4)
			_check(e.position == before and e.body_sprite.transform == pose and e.attack_count == 0, "time stop freezes pose, movement and fire")
			e.set_enemy_time_scale(1.0)
			var duration := e.regional_pattern.warning_duration()
			e._process(duration - 0.01)
			_check(e.attack_count == 0, "no early attack")
			e._process(0.02)
			_check(e.attack_count == 1 and e.body_sprite.flip_h == (side < 0), "one actual attack facing player")
			if e.regional_pattern.ranged():
				_check(e._projectile_sequence == (1 if e.roster_id == "bird" else 3), "dedicated volley size")
				for p in get_nodes_in_group("enemy_projectile"):
					if p is EnemySeedProjectile and p.attacker_id == StringName(e.roster_id):
						_check(p.projectile_sprite.texture == p.projectile_texture and signf(p.direction.x) == side, "dedicated projectile art and attack direction")
			else:
				for ignored in 60:
					if e.state == PrototypeEnemy.State.RECOVERY: break
					e._process(0.02)
				_check(e.state == PrototypeEnemy.State.RECOVERY and e.position.x >= 100 and e.position.x <= 4900, "bounded lunge ends in recovery")
				if e.roster_id == "rewind_doll":
					e._process(0.56)
					_check(e.position == before, "rewind returns to recorded start without a second hit")
			e.reset_target()
			player.position = e.position + Vector2(side * 300, 0)
			e._process(0.0)
			e.apply_shield_stun(0.7)
			e._process(0.5)
			_check(e.attack_count == 0 and e.state == PrototypeEnemy.State.RECOVERY, "stun cancels pending attack")
			e.apply_pole_push(side * 40)
			e._process(0.6)
			_check(e.position.x >= 100 and e.attack_count == 0, "push cancels rewind and pending volley")
			var damage := DamageEvent.new()
			damage.event_id = StringName("roster_death_%s_%d" % [e.roster_id, side])
			damage.damage = 100000
			e.receive_damage(damage)
			_check(not e.is_targetable() and e.state == PrototypeEnemy.State.DEAD and not e.warning_line.visible, "death removes target and telegraph")
			e._process(0.4)
			_check(e.body_sprite.self_modulate.a < 0.4, "death animation settles")
			e.reset_target()
			_check(e.is_targetable() and e.attack_count == 0 and e.body_sprite.self_modulate.a == 1.0, "respawn clears death and pending pattern")
			for p in get_nodes_in_group("enemy_projectile"): p.free()
	# New regional elites use distinct patterns and life-scoped shockwave IDs.
	var elite := runner.armored_boar
	for route in ["forest", "ruins", "festival"]:
		for side in [-1, 1]:
			elite.configure_region(route)
			elite.set_stage_spawn(Vector2(2400, 780))
			elite.reset_target()
			elite.visible = true
			player.position = Vector2(2400 + side * 400, 780)
			elite._process(0.5)
			_check(elite.state == EliteArmoredBoar.State.WARNING, "elite full warning")
			var elapsed := elite._state_elapsed_s
			elite.set_enemy_time_scale(0.0)
			elite._process(1.0)
			_check(elite._state_elapsed_s == elapsed and elite.attack_count == 0, "elite time stop")
			elite.set_enemy_time_scale(1.0)
			elite._process(1.0)
			_check(elite.attack_count == 1, "elite executes one pattern")
			if route == "festival":
				_check(elite.current_pattern == EliteArmoredBoar.Pattern.SHOCKWAVE and elite.charge_count == 0, "drummer beats instead of boar charge")
			else:
				for ignored in 90:
					if elite.state == EliteArmoredBoar.State.RECOVERY: break
					elite._process(0.02)
				_check(elite.state == EliteArmoredBoar.State.RECOVERY, "regional lunge has bounded counterattack window")
				if route == "ruins": _check(elite.position == Vector2(2400, 780), "clock sentry rewinds its lunge")
			elite.damage_receiver.tick(5.0)
			var shield: ShieldCombatController = scene.get_node("Player/ShieldCombatController")
			var applied := shield._damage_target(elite, &"shield_slam", 1, 0.1, PackedStringArray(["shield", "skill"]), 0)
			_check(applied == DamageReceiver.Result.APPLIED, "actual shield strike reaches regional elite")
			elite._process(0.4)
			_check(elite.state == EliteArmoredBoar.State.STUNNED, "elite stun cancels queued beat")
			elite.damage_receiver.tick(5.0)
			var pole: PolearmCombatController = scene.get_node("Player/PolearmCombatController")
			var before_push := elite.position.x
			applied = pole._damage_target(elite, &"polearm_thrust", 1, 0.1, PackedStringArray(["polearm", "skill"]), 0)
			_check(applied == DamageReceiver.Result.APPLIED and absf(elite.position.x - before_push) == 100.0 and elite.state == EliteArmoredBoar.State.RECOVERY, "actual polearm strike pushes and interrupts regional elite")
			elite.damage_receiver.tick(5.0)
			var lethal := DamageEvent.new()
			lethal.event_id = StringName("regional_elite_death_%s_%d" % [route, side])
			lethal.damage = 100000
			elite.receive_damage(lethal)
			_check(not elite.is_targetable() and elite.state == EliteArmoredBoar.State.DEAD, "elite defeat removes combat target")
			elite.reset_target()
			_check(elite.is_targetable() and elite.phase == 1 and elite.attack_count == 0, "elite respawn clears patterns, phase and stun")
			if route != "festival":
				elite.set_stage_spawn(Vector2(4700 if side > 0 else 300, 780))
				player.position = Vector2(4890 if side > 0 else 90, 780)
				elite.reset_target()
				elite._process(0.5)
				elite._process(1.0)
				elite._process(1.0)
				_check(elite.position.x >= EliteArmoredBoar.LEFT_WALL_X and elite.position.x <= EliteArmoredBoar.RIGHT_WALL_X, "long frame cannot move regional elite outside arena")
			for p in get_nodes_in_group("enemy_projectile"): p.free()
	elite.configure_region("wind")
	_check(elite.region_enemy_name() == "갑옷 멧돼지" and elite.body_sprite.texture == elite._region_original_texture, "boar restored only in plains")
	scene.free()
	print("Regional roster runtime: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
