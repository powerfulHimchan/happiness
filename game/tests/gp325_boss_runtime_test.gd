extends SceneTree

const SANDBOX := preload("res://tests/fixtures/legacy_movement_sandbox.tscn")
var failures := 0
var cases := 0
var player: PrototypePlayer
var stage: Node

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	stage = SANDBOX.instantiate()
	stage.get_node("RecoveryOrbController").drop_chance = 0.0
	root.add_child(stage)
	current_scene = stage
	await process_frame
	stage.get_node("StageRunner").set_stage_enabled(false)
	stage.get_node("CombatFeedbackController").configure(0.0, false, false)
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	player = stage.get_node("Player")
	player.damage_receiver.max_health = 10000
	player.damage_receiver.health = 10000
	for actor in ["ClockworkKnight", "HappinessGuardian", "Sera", "HappinessHeart"]:
		var boss: ExpeditionBoss = stage.get_node("Targets/" + actor)
		for level in [3, 4]:
			for phase in [1, 2]:
				for direction in [-1, 1]:
					for pattern in ([3, 4] if boss is BossHappinessHeart else [3]):
						_exercise(boss, level, phase, direction, pattern)
		# Ordinary charge/wave attacks retain the original single pattern group.
		for pattern in [1, 2]:
			if boss is BossHappinessHeart and pattern == 1: continue
			_prepare(boss, 4, 1, -1)
			boss.current_pattern = pattern
			boss._begin_pattern_warning()
			_check(not boss._follow_up_pending, "charge and pulse do not gain an unannounced repeat")
		# Phase transition and death cancel queued follow-ups immediately.
		_prepare(boss, 4, 1, -1)
		boss.current_pattern = 3
		boss._begin_pattern_warning()
		var hit := DamageEvent.new()
		hit.event_id = StringName("gp325:phase:" + actor)
		hit.damage = ceili(boss.damage_receiver.max_health * 0.6)
		boss.receive_damage(hit)
		_check(boss.state == EliteArmoredBoar.State.PHASE_TRANSITION and not boss._follow_up_pending, "real phase transition cancels pending attack")
		hit = DamageEvent.new()
		hit.event_id = StringName("gp325:dead:" + actor)
		hit.damage = 99999
		boss.receive_damage(hit)
		_check(boss.state == EliteArmoredBoar.State.DEAD and not boss._follow_up_pending and not boss._follow_up_active, "death cancels both repeat states")
		boss._process(10.0)
		_check(boss.attack_count == 0, "dead boss cannot fire a deferred attack")
		boss.reset_target()
		_check(not boss._follow_up_pending and not boss._follow_up_active and boss.attack_count == 0, "pooled reset clears repeats")
		boss.visible = false
	_clear_shots()
	stage.free()
	print("GP-325 boss runtime: %s (%d level/phase/direction/pattern cases)" % ["OK" if failures == 0 else "FAILED", cases])
	quit(0 if failures == 0 else 1)

func _prepare(boss: ExpeditionBoss, level: int, phase: int, direction: int) -> void:
	_clear_shots()
	boss.expedition_patterns = level == 4
	boss.set_stage_spawn(Vector2(4450, 780))
	boss.reset_target()
	boss.visible = true
	boss.phase = phase
	player.damage_receiver.tick(2.0)
	player._input_lock_remaining_s = 0.0
	player.position = boss.position + Vector2(direction * 280, 0)

func _exercise(boss: ExpeditionBoss, level: int, phase: int, direction: int, pattern: int) -> void:
	_prepare(boss, level, phase, direction)
	boss.last_pattern = (2 if pattern == 4 else 4) if boss is BossHappinessHeart else 2
	boss._begin_next_pattern()
	var duration := (0.72 if phase == 2 else 1.05) if boss is BossHappinessHeart else (0.75 if phase == 2 else 1.0) if boss is BossClockworkKnight else (0.80 if phase == 2 else 1.10)
	var groups := 2 if level == 4 else 1
	var first_aim := boss.warning_line.points
	for cycle in groups:
		_check(boss.state == EliteArmoredBoar.State.WARNING and boss.warning_line.visible and boss.current_pattern == pattern, "each attack group starts with its visible trajectory")
		_check(boss.attack_count == cycle, "no immediate repeat damage")
		var before := boss._state_elapsed_s
		boss.set_enemy_time_scale(0.0)
		boss._process(2.0)
		_check(boss._state_elapsed_s == before and boss.attack_count == cycle, "zero slow freezes both warnings")
		boss.set_enemy_time_scale(0.5)
		boss._process((duration - 0.01) * 2.0)
		_check(boss.state == EliteArmoredBoar.State.WARNING and boss.attack_count == cycle, "each warning respects slow and its full duration")
		boss.set_enemy_time_scale(1.0)
		if boss is BossHappinessHeart and pattern == BossHappinessHeart.BEAM:
			# The beam hits the warned height, and can be dodged by changing height.
			player.damage_receiver.tick(2.0)
			player._input_lock_remaining_s = 0.0
		var hp := player.damage_receiver.health
		boss._process(0.02)
		_check(boss.attack_count == cycle + 1 and boss.state == EliteArmoredBoar.State.RECOVERY, "attack resolves exactly once before the normal weakness window")
		if boss is BossHappinessHeart and pattern == BossHappinessHeart.BEAM:
			_check(player.damage_receiver.health == hp - (20 if phase == 2 else 16), "each warned beam causes its original real damage")
		# Sera's existing phase-2 rotating second ring is retained inside each group.
		boss._process(0.30)
		var shots := get_nodes_in_group("enemy_projectile")
		var per_group := (5 if phase == 2 else 3) if boss is BossClockworkKnight or boss is BossHappinessHeart else (3 if phase == 2 else 1) if boss is BossHappinessGuardian else (16 if phase == 2 else 8)
		if not (boss is BossHappinessHeart and pattern == BossHappinessHeart.BEAM):
			_check(shots.size() == per_group, "original projectile count in each boss/phase group")
			var ids := {}
			for shot in shots:
				_check(not ids.has(shot.projectile_id), "unique projectile damage events")
				ids[shot.projectile_id] = true
			var shot = shots[shots.size() / 2]
			player.damage_receiver.tick(2.0)
			player._input_lock_remaining_s = 0.0
			player.position = shot.position + shot.direction * 100 + Vector2(0, 42)
			hp = player.damage_receiver.health
			shot._physics_process(0.3)
			_check(player.damage_receiver.health == hp - shot.damage, "follow-up projectiles cause real damage")
		_clear_shots()
		player.position = boss.position + Vector2(-direction * 280, -90 if boss is BossHappinessHeart and pattern == BossHappinessHeart.BEAM else 0)
		var remaining := (0.55 if phase == 2 else 0.75) - 0.30
		boss._process(remaining - 0.01)
		_check(boss.state == EliteArmoredBoar.State.RECOVERY, "full original weakness window before a repeat")
		boss._process(0.02)
		if cycle + 1 < groups:
			_check(boss.state == EliteArmoredBoar.State.WARNING and boss.last_enemy_log.contains("원정 4") and boss._state_elapsed_s == 0.0, "one new telegraph after recovery")
			if not boss is BossSera:
				_check(boss.warning_line.points != first_aim, "follow-up captures the player's new direction or height")
			# New aim stays locked throughout the warning.
			var aim := boss.warning_line.points
			player.position.x = boss.position.x + direction * 280
			boss._update_warning()
			_check(boss.warning_line.points == aim, "captured follow-up aim stays fixed")
		else:
			_check(boss.state == EliteArmoredBoar.State.IDLE and not boss._follow_up_pending and not boss._follow_up_active, "repeat budget exhausted; return to normal rotation")
	cases += 1
	# Difficulty changes cannot leave a repeat queued on a reused actor.
	boss.reset_target()
	boss.current_pattern = pattern
	boss._begin_pattern_warning()
	boss.expedition_patterns = false
	_check(not boss._follow_up_pending and not boss._follow_up_active, "disabling expedition clears queued work")

func _clear_shots() -> void:
	for shot in get_nodes_in_group("enemy_projectile"): shot.free()

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("GP-325 boss: " + label)
