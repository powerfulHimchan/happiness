extends SceneTree

const SANDBOX := preload("res://scenes/movement/ground_movement_sandbox.tscn")
var failures := 0
var cases := 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var stage := SANDBOX.instantiate()
	stage.get_node("RecoveryOrbController").drop_chance = 0.0
	root.add_child(stage)
	current_scene = stage
	await process_frame
	stage.get_node("StageRunner").set_stage_enabled(false)
	stage.get_node("CombatFeedbackController").configure(0.0, false, false)
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	var player: PrototypePlayer = stage.get_node("Player")
	player.damage_receiver.max_health = 10000
	player.damage_receiver.health = 10000
	for level in [2, 3]:
		for route in ["meadow", "forest", "ruins", "festival"]:
			for facing in [-1, 1]:
				for actor in ["LeafSlime", "SeedSack", "WindSpirit"]:
					var enemy: PrototypeEnemy = stage.get_node("Targets/" + actor)
					enemy.expedition_patterns = level == 3
					enemy.configure_route(route)
					enemy.set_stage_spawn(Vector2(2200, 615 if enemy.enemy_type == 2 else 780))
					enemy.reset_target()
					enemy.visible = true
					player.position = Vector2(2200 + facing * (500 if enemy.enemy_type == 1 else 200), 780)
					enemy._process(0.0)
					var attacks := 1 + (1 if level == 3 else 0) + (1 if (route == "forest" and enemy.enemy_type != 1) or (route == "ruins" and enemy.enemy_type == 1) else 0)
					for cycle in attacks:
						_check(enemy.state == PrototypeEnemy.State.WARNING and enemy.warning_line.visible, "every attack has a visible warning")
						var frozen := enemy._state_elapsed_s
						enemy.set_enemy_time_scale(0.0)
						enemy._process(0.2)
						_check(enemy._state_elapsed_s == frozen and enemy.attack_count == cycle, "zero slow freezes warning and follow-up")
						enemy.set_enemy_time_scale(1.0)
						var duration := 0.65 if route == "festival" and enemy.enemy_type == 0 else 1.1 if route == "festival" and enemy.enemy_type == 1 else 0.35 if enemy.enemy_type == 0 else 0.6 if enemy.enemy_type == 2 else 0.7 if route == "ruins" and cycle > 0 else 1.0
						enemy._process(duration - 0.01)
						_check(enemy.attack_count == cycle and enemy.state == PrototypeEnemy.State.WARNING, "full original warning before each attack")
						enemy._process(0.02)
						_check(enemy.attack_count == cycle + 1, "exactly one attack after warning")
						for ignored in 100:
							if enemy.state == PrototypeEnemy.State.RECOVERY: break
							enemy._process(0.02)
						_check(enemy.state == PrototypeEnemy.State.RECOVERY, "attack ends in recovery")
						if enemy.enemy_type == 1:
							var volley_size := 5 if route in ["forest", "festival"] else 3
							_check(enemy._projectile_sequence == volley_size * (cycle + 1), "original volley size on each shot")
							var ids := {}
							for shot in get_nodes_in_group("enemy_projectile"):
								_check(not ids.has(shot.projectile_id) and shot.damage == 7, "unique shot events and unchanged damage")
								ids[shot.projectile_id] = true
							# Hit the player with a real centre projectile from this volley.
							var shots := get_nodes_in_group("enemy_projectile")
							var shot = shots[-(volley_size / 2 + 1)]
							player.position = shot.global_position + shot.direction * 120 + Vector2(0, 42)
							player.damage_receiver.tick(1.0)
							player._input_lock_remaining_s = 0.0
							var hp := player.damage_receiver.health
							shot._physics_process(0.3)
							_check(player.damage_receiver.health == hp - 7, "each volley causes real projectile damage: %s %d %d %d" % [route, level, facing, cycle])
						for shot in get_nodes_in_group("enemy_projectile"): shot.free()
						# Move across the actor before the next warning to exercise re-aim.
						player.position = enemy.position + Vector2(-facing * (500 if enemy.enemy_type == 1 else 200), 165 if enemy.enemy_type == 2 else 0)
						if cycle + 1 < attacks:
							enemy._process(0.35 if enemy.enemy_type == 1 or route == "festival" else 0.30)
						else:
							enemy._process(1.41)
					_check(enemy.attack_count == attacks and enemy.state == PrototypeEnemy.State.IDLE and enemy._combo_remaining == 0, "one extra attack then return to normal cooldown")
					cases += 1
					# Sword interrupts cancel every remaining repeat for ranged/soldier actors.
					if level == 3 and (enemy.enemy_type == 1 or route == "festival" and enemy.enemy_type == 0):
						enemy.reset_target()
						player.position = enemy.position + Vector2(facing * (500 if enemy.enemy_type == 1 else 200), 0)
						enemy._process(0.0)
						var hit := DamageEvent.new()
						hit.event_id = StringName("gp324:interrupt:%s:%s:%s" % [route, facing, actor])
						hit.damage = 1
						hit.tags = PackedStringArray(["sword"])
						hit.source_position = player.position
						enemy.receive_damage(hit)
						_check(enemy.state == PrototypeEnemy.State.RECOVERY and enemy._combo_remaining == 0, "sword cancels queued follow-up")
						enemy._process(0.5)
						_check(enemy.attack_count == 0, "interrupted attack does not fire later")
					var fatal := DamageEvent.new()
					fatal.event_id = StringName("gp324:dead:%s" % cases)
					fatal.damage = 99999
					enemy.receive_damage(fatal)
					enemy._process(1.0)
					_check(enemy.state == PrototypeEnemy.State.DEAD and enemy._combo_remaining == 0, "death cancels repeat")
					enemy.reset_target()
					_check(enemy._combo_remaining == 0 and enemy.attack_count == 0, "pooled actor reset")
	stage.free()
	print("GP-324 enemy runtime: %s (%d level/route/direction/type cases)" % ["OK" if failures == 0 else "FAILED", cases])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("GP-324 enemy: " + label)
