class_name WindmillMeadow
extends Node2D

## Production first-map controller. Campaign rewards still use the five legacy milestones.
var runner: PrototypeStageRunner
var player: PrototypePlayer
var active := false
var powered := false
var cleared: Array[String] = []
var claimed: Array[int] = []
var encounter_id := ""
var encounter_locked := false
var device_hold_s := 0.0
var elapsed_s := 0.0
var message := "풍차를 작동시켜 바람길을 여세요"
var message_s := 0.0
var bodies: Node2D
var bridge: StaticBody2D
var barriers: Array[StaticBody2D] = []
var _old_world: Array[Dictionary] = []
var _camera_limits := Vector4i.ZERO
var _pending_save := false
var _save_retry_s := 0.0
var _attempt_health: Dictionary = {}

func configure(owner_runner: PrototypeStageRunner, enabled: bool) -> void:
	runner = owner_runner
	player = runner.player
	if active: _restore_world()
	active = enabled
	visible = enabled
	if is_instance_valid(bodies): bodies.free()
	bodies = null
	barriers.clear()
	powered = false
	cleared.clear()
	claimed.clear()
	encounter_id = ""
	encounter_locked = false
	device_hold_s = 0.0
	elapsed_s = 0.0
	message_s = 0.0
	message = "풍차를 작동시켜 바람길을 여세요"
	_pending_save = false
	_save_retry_s = 0.0
	_attempt_health.clear()
	if not enabled: return
	bodies = Node2D.new()
	add_child(bodies)
	for rect in WindmillMeadowLayout.surfaces(): _body(rect)
	for rect in WindmillMeadowLayout.ledges(): _body(rect, true)
	bridge = _body(WindmillMeadowLayout.WIND_BRIDGE)
	bridge.collision_layer = 0
	for index in 2:
		var barrier := _body(Rect2(0, -1600, 40, 3000))
		barrier.collision_layer = 0
		barriers.append(barrier)
	_replace_world()
	queue_redraw()

func _body(rect: Rect2, one_way: bool = false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.one_way_collision = one_way
	collision.one_way_collision_margin = 10.0
	body.add_child(collision)
	bodies.add_child(body)
	return body

func _replace_world() -> void:
	var scene := runner.get_parent()
	_old_world.clear()
	for path in ["LeftFloor", "RightFloor", "PracticePlatform", "RightWall", "LeftSafeZone", "RightSafeZone", "PracticeSafeZone"]:
		var node := scene.get_node(path) as CollisionObject2D
		_old_world.append({"node":node,"layer":node.collision_layer,"mask":node.collision_mask,"position":node.position})
		node.collision_layer = 0
		node.collision_mask = 0
	var boundary := _body(Rect2(WindmillMeadowLayout.WIDTH - 40, -1600, 40, 3000))
	boundary.name = "MeadowBoundary"
	var camera := player.get_node("Camera2D") as Camera2D
	_camera_limits = Vector4i(camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom)
	camera.limit_right = int(WindmillMeadowLayout.WIDTH)
	camera.limit_top = -700
	camera.limit_bottom = 1200
	(player.get_node("AutoTargetSelector") as AutoTargetSelector).visibility_filter = _target_visible
	runner.route_terrain.visible = false
	for enemy in [runner.leaf_slime,runner.seed_sack,runner.wind_spirit]:
		enemy.movement_bounds = Vector2(100, WindmillMeadowLayout.WIDTH - 100)
	runner.armored_boar.arena_bounds = Vector2(37400, 41000)
	for index in runner.gates.size(): runner._set_gate_closed(index, false)
	player.set_safe_spawn(Vector2(960,780), "풍차 들판 입구")
	scene.queue_redraw()

func _restore_world() -> void:
	for state in _old_world:
		var node: CollisionObject2D = state.node
		node.collision_layer = int(state.layer)
		node.collision_mask = int(state.mask)
		node.position = state.position
	_old_world.clear()
	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_left = _camera_limits.x
	camera.limit_top = _camera_limits.y
	camera.limit_right = _camera_limits.z
	camera.limit_bottom = _camera_limits.w
	(player.get_node("AutoTargetSelector") as AutoTargetSelector).visibility_filter = Callable()
	runner.route_terrain.visible = true
	for enemy in [runner.leaf_slime,runner.seed_sack,runner.wind_spirit]: enemy.movement_bounds = Vector2(100,4900)
	runner.armored_boar.arena_bounds = Vector2(120,4880)
	runner.get_parent().queue_redraw()

func advance(delta: float) -> void:
	if not active or player.damage_receiver.dead or runner.failed: return
	elapsed_s += delta
	_save_retry_s = maxf(0, _save_retry_s - delta)
	message_s = maxf(0.0, message_s - delta)
	_update_safe_spawn()
	_collect_rewards()
	if not encounter_id.is_empty():
		if runner._active_enemy_count() == 0:
			cleared.append(encounter_id)
			if encounter_id == "elite": _notify("정예 처치 · 열린 출구로 전진하세요")
			_pending_save = true
			encounter_id = ""
			_set_barriers(false)
		elif not encounter_locked and not runner._active_enemies.is_empty() and absf(player.position.x - runner._active_enemies[0].position.x) > 1800:
			var remaining: Array[int] = []
			for enemy in [runner.leaf_slime,runner.seed_sack,runner.wind_spirit]: remaining.append(enemy.damage_receiver.health if enemy in runner._active_enemies else 0)
			_attempt_health[encounter_id] = remaining
			runner._deactivate_all_combat_enemies()
			runner._active_enemies.clear()
			encounter_id = ""
		else:
			queue_redraw()
			return
	# Preserve the existing campaign's five milestone records without forcing its geometry.
	if runner.current_section == PrototypeStageRunner.Section.ADVANCE_ONE and player.position.x >= 11300:
		runner._finish_current_section()
	if runner.current_section == PrototypeStageRunner.Section.WAVE_ONE and cleared.has("farm_b"):
		runner._finish_current_section()
	_update_device(delta)
	if runner.current_section == PrototypeStageRunner.Section.ADVANCE_TWO and powered and player.position.x >= 28900:
		runner._finish_current_section()
	if runner.current_section == PrototypeStageRunner.Section.WAVE_TWO and cleared.has("hill_b") and player.position.x >= 37700:
		runner._finish_current_section()
		return
	if runner.current_section == PrototypeStageRunner.Section.ELITE:
		if not cleared.has("elite") and runner._active_enemy_count() == 0:
			cleared.append("elite")
			_set_barriers(false)
			_notify("출구로 전진하세요")
		if WindmillMeadowLayout.REQUIRED_ENCOUNTERS.all(func(id: String) -> bool: return cleared.has(id)) and player.position.x >= 41500:
			runner._finish_current_section()
		queue_redraw()
		return
	for encounter in WindmillMeadowLayout.encounters():
		if cleared.has(String(encounter.id)) or not encounter.trigger.has_point(player.position): continue
		if encounter.id == "farm_b" and not cleared.has("farm_a"): continue
		if encounter.id == "mill_b" and not cleared.has("mill_a"): continue
		if encounter.id.begins_with("hill") and not powered: continue
		if encounter.id == "hill_b" and not cleared.has("hill_a"): continue
		_start_encounter(encounter)
		break
	_try_save()
	queue_redraw()

func _start_encounter(data: Dictionary) -> void:
	runner._deactivate_all_combat_enemies()
	runner._active_enemies.clear()
	encounter_id = String(data.id)
	encounter_locked = bool(data.lock)
	var enemies := [runner.leaf_slime, runner.seed_sack, runner.wind_spirit]
	for index in data.points.size():
		var enemy: PrototypeEnemy = enemies[index]
		if _attempt_health.has(encounter_id) and int(_attempt_health[encounter_id][index]) <= 0: continue
		enemy.configure_route("wind", true, 1 if index < 2 else 2)
		var spawn: Vector2 = data.points[index]
		if is_equal_approx(spawn.y,780): spawn.y = WindmillMeadowLayout.ground_height(spawn.x)-60
		runner._activate_enemy(enemy, spawn)
		if _attempt_health.has(encounter_id): enemy.damage_receiver.health = int(_attempt_health[encounter_id][index])
		enemy.movement_bounds = Vector2(float(data.get("left", data.points[0].x-300)), float(data.get("right", data.points[-1].x+300)))
		runner._active_enemies.append(enemy)
	if encounter_locked:
		_set_barriers(true, float(data.left), float(data.right))
		player.set_safe_spawn(player.position, current_zone() + " · 전투 쉼터")
	_notify("주변의 적을 처치하면 길이 열립니다" if encounter_locked else "계속 전진하거나 주변의 적과 싸울 수 있어요")

func start_elite() -> void:
	runner._deactivate_all_combat_enemies()
	runner._activate_enemy(runner.final_enemy(), Vector2(39800,780))
	runner._active_enemies.assign([runner.final_enemy()])
	encounter_id = "elite"
	encounter_locked = true
	_set_barriers(true,37400,41000)
	player.set_safe_spawn(Vector2(37800,780), "출구 초원 · 정예 전투")
	_notify("돌진을 회피하고 벽에 부딪힌 뒤의 빈틈을 노리세요")

func _set_barriers(enabled: bool, left: float = 0, right: float = 0) -> void:
	for index in barriers.size():
		barriers[index].collision_layer = 1 if enabled else 0
		if enabled: barriers[index].position.x = left if index == 0 else right
	encounter_locked = enabled

func _update_device(delta: float) -> void:
	if powered: return
	var near := player.position.distance_to(WindmillMeadowLayout.DEVICE + Vector2(0,-60)) < 140
	if not near or not cleared.has("mill_b") or absf(player.move_input) > 0.15 or not player.is_on_floor():
		device_hold_s = 0.0
		return
	device_hold_s += delta
	if device_hold_s >= 0.8:
		powered = true
		_pending_save = true
		bridge.collision_layer = 1
		_notify("풍차 작동! 바람꽃 둔덕으로 가는 다리가 열렸습니다")

func _physics_process(delta: float) -> void:
	if not active or not powered or runner.stage_complete or player.damage_receiver.dead or not player.can_continue_combat_action(): return
	for zone in WindmillMeadowLayout.WIND_ZONES:
		if zone.has_point(player.position) and not player.is_on_floor():
			player.velocity.y = move_toward(player.velocity.y, -850.0, 4500.0 * delta)

func _update_safe_spawn() -> void:
	if not player.is_on_floor(): return
	for rect in collision_surfaces():
		if absf(player.position.y + 60 - rect.position.y) < 4 and player.position.x > rect.position.x + 45 and player.position.x < rect.end.x - 45:
			player.set_safe_spawn(Vector2(player.position.x,rect.position.y - 60), current_zone())
			return

func collision_surfaces() -> Array[Rect2]:
	var result := WindmillMeadowLayout.surfaces()
	result.append_array(WindmillMeadowLayout.ledges())
	if powered: result.append(WindmillMeadowLayout.WIND_BRIDGE)
	return result

func _collect_rewards() -> void:
	for index in WindmillMeadowLayout.REWARDS.size():
		if claimed.has(index) or player.position.distance_to(WindmillMeadowLayout.REWARDS[index]) > 110: continue
		if index == 0 and not cleared.has("ridge") or index == 1 and not cleared.has("approach"): continue
		claimed.append(index)
		_pending_save = true
		if index == 0:
			player.apply_growth_health(0,20)
			_notify("언덕 보물 · 체력 20 회복")
		elif index == 1:
			(runner.get_parent().get_node("Player/UltimateController") as UltimateController).grant_stage_gauge(35)
			_notify("풍차 밖 보물 · 필살기 게이지 +35")
		else:
			player.potions_remaining = mini(player.potions_capacity(), player.potions_remaining + 1)
			_notify("절벽 보물 · 회복약 1개 보충")

func current_zone() -> String:
	return String(WindmillMeadowLayout.ZONE_NAMES[WindmillMeadowLayout.zone_at(player.position.x)])

func objective() -> String:
	if runner.stage_complete: return "풍차 들판 통과"
	if message_s > 0: return message
	if not encounter_id.is_empty() and encounter_locked: return current_zone() + " · 주변 적 처치"
	if cleared.has("elite"): return "열린 출구로 전진"
	if player.position.x >= 26400 and not powered: return "풍차 위층 장치 옆에서 잠시 멈춰 작동"
	if player.position.x >= 23400 and not powered: return "위층의 적 처치 후 빛나는 장치 옆에서 잠시 멈추기"
	return current_zone() + " · " + ("열린 바람길을 따라 출구로 전진" if powered else "풍차를 향해 전진 · 위쪽 길에는 선택 보물")

func _notify(text: String) -> void:
	message = text
	message_s = 3.5

func _try_save() -> void:
	var scene := runner.get_parent()
	if not _pending_save or _save_retry_s > 0 or not encounter_id.is_empty() or runner.stage_complete or not scene._can_collect_recovery_orb(): return
	if scene.growth.choosing or scene.growth.awaiting_job_confirmation: return
	if scene._save_checkpoint(runner.current_metrics(), false) == OK:
		_pending_save = false
	else:
		_save_retry_s = 3.0
		_notify("중간 저장 실패 · 잠시 후 다시 저장합니다")

func progress_snapshot() -> Dictionary:
	return {"version":1,"powered":powered,"cleared":cleared.duplicate(),"claimed":claimed.duplicate(),"phase":runner.current_section,"section_elapsed":runner.section_elapsed_s,"attempt_health":_attempt_health.duplicate(true),"spawn":[player.last_safe_position.x,player.last_safe_position.y]}

func restore_progress(state: Dictionary) -> void:
	powered = bool(state.powered)
	cleared.assign(state.cleared)
	claimed.assign(state.claimed)
	_attempt_health = state.get("attempt_health",{}).duplicate(true)
	bridge.collision_layer = 1 if powered else 0
	player.position = Vector2(float(state.spawn[0]), float(state.spawn[1]))
	player.velocity = Vector2.ZERO
	player.set_safe_spawn(player.position, current_zone())
	(player.get_node("Camera2D") as Camera2D).reset_smoothing()
	_pending_save = false
	_notify("중간 저장에서 풍차 들판 탐험을 이어갑니다")

static func valid_progress(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1 or not value.get("powered") is bool: return false
	if not RunCheckpointStore._number(value.get("phase"),0,3,true) or not RunCheckpointStore._number(value.get("section_elapsed"),0,1000000): return false
	if not value.get("cleared") is Array or not value.get("claimed") is Array or not value.get("spawn") is Array or value.spawn.size() != 2: return false
	var ids := ["entry","ridge","farm_a","farm_b","approach","mill_a","mill_b","hill_a","hill_b"]
	if not value.get("attempt_health",{}) is Dictionary: return false
	for id in value.get("attempt_health",{}):
		if id not in ["entry","ridge","approach"]: return false
		var health: Variant = value.attempt_health[id]
		if not health is Array or health.size() != 3: return false
		for amount in health:
			if not RunCheckpointStore._number(amount,0,100000,true): return false
	var seen: Array = []
	for id in value.cleared:
		if not id is String or id not in ids or id in seen: return false
		seen.append(id)
	for pair in [["farm_b","farm_a"],["mill_b","mill_a"],["hill_b","hill_a"]]:
		if pair[0] in value.cleared and pair[1] not in value.cleared: return false
	if value.powered and "mill_b" not in value.cleared: return false
	if int(value.phase) >= 2 and "farm_b" not in value.cleared: return false
	if int(value.phase) == 3 and not value.powered: return false
	seen.clear()
	for index in value.claimed:
		if not RunCheckpointStore._number(index,0,2,true) or index in seen: return false
		seen.append(index)
	if 0 in value.claimed and "ridge" not in value.cleared or 1 in value.claimed and "approach" not in value.cleared: return false
	if not RunCheckpointStore._number(value.spawn[0],100,WindmillMeadowLayout.WIDTH-100) or not RunCheckpointStore._number(value.spawn[1],-650,1000): return false
	var surfaces := WindmillMeadowLayout.surfaces()
	surfaces.append_array(WindmillMeadowLayout.ledges())
	if value.powered: surfaces.append(WindmillMeadowLayout.WIND_BRIDGE)
	for rect in surfaces:
		if absf(float(value.spawn[1])+60-rect.position.y) < 4 and float(value.spawn[0]) >= rect.position.x+40 and float(value.spawn[0]) <= rect.end.x-40: return true
	return false

func _draw() -> void:
	if active: WindmillMeadowArt.draw_map(self)


func _target_visible(target: PrototypeTarget) -> bool:
	var origin := player.global_position + Vector2(0,-38)
	var query := PhysicsRayQueryParameters2D.create(origin, target.closest_hit_point(origin), 1, [player.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()
