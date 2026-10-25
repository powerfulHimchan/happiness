class_name RicochetArrow
extends BowProjectile

## 첫 실제 적중 후 가까운 다른 생명 하나를 고정하고 한 번만 도탄한다.
var ricochet_damage: int = 0
var ricochet_range_px: float = 0.0
var _first_target_id: int = 0
var _bounce_target: WeakRef
var _bounce_generation: int = -1

func _ready() -> void:
	super._ready()
	arrow_sprite.modulate = Color("ffb347")

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	if _hit_count == 1 and _locked_target() == null:
		queue_free()
		return
	var start := global_position
	var distance := minf(maxf(0.0, delta) * speed_px_s, maxf(0.0, max_distance_px - _travelled_px))
	var end := start + direction * distance
	var previous_hits := _hit_count
	_check_hits(start, end)
	if is_queued_for_deletion(): return
	# 도탄 방향은 적중 위치에서 다음 프레임부터 적용한다. 남은 첫 경로를 관통하지 않는다.
	if previous_hits == _hit_count:
		global_position = end
		_travelled_px += distance
	if _travelled_px >= max_distance_px or not _is_near_screen(): queue_free()

func _check_hits(segment_start: Vector2, segment_end: Vector2) -> void:
	if is_queued_for_deletion() or _hit_count >= 2: return
	var target: PrototypeTarget
	if _hit_count == 1:
		target = _locked_target()
		if target == null:
			queue_free()
			return
		if _distance_to_segment(target.global_position + PrototypeTarget.BODY_CENTER, segment_start, segment_end) > HIT_RADIUS_PX: return
	else:
		# 그룹 등록 순서 대신 비행 경로의 가장 가까운 교차부터 판정한다.
		var nearest := INF
		for node in get_tree().get_nodes_in_group("targetable"):
			var candidate := node as PrototypeTarget
			if not _eligible(candidate): continue
			var point := candidate.global_position + PrototypeTarget.BODY_CENTER
			if _distance_to_segment(point, segment_start, segment_end) > HIT_RADIUS_PX: continue
			var along := segment_start.distance_to(Geometry2D.get_closest_point_to_segment(point, segment_start, segment_end))
			if along < nearest:
				nearest = along
				target = candidate
	if target == null: return
	var point := target.global_position + PrototypeTarget.BODY_CENTER
	global_position = Geometry2D.get_closest_point_to_segment(point, segment_start, segment_end)
	var event := DamageEvent.new()
	event.event_id = StringName("%s:%s" % [projectile_id, target.attack_life_key()])
	event.attacker_id = &"player"
	event.attack_id = attack_id
	event.damage = damage
	event.stagger_s = 0.08
	event.tags = tags
	event.source_position = segment_start
	var result: int = damage_handler.call(target, event) if damage_handler.is_valid() else target.receive_damage(event)
	if result == DamageReceiver.Result.APPLIED: _hit_count += 1
	hit_registered.emit(target, event.outgoing_damage(), result, projectile_id)
	if result != DamageReceiver.Result.APPLIED or _hit_count >= 2:
		queue_free()
		return
	_first_target_id = target.get_instance_id()
	var next := _nearest_bounce_target()
	if next == null:
		queue_free()
		return
	_bounce_target = weakref(next)
	_bounce_generation = next.spawn_generation
	direction = (next.global_position + PrototypeTarget.BODY_CENTER - global_position).normalized()
	rotation = direction.angle()
	damage = ricochet_damage
	_travelled_px = 0.0
	max_distance_px = ricochet_range_px
	arrow_sprite.modulate = Color("ff7b72")

func _eligible(target: PrototypeTarget) -> bool:
	return is_instance_valid(target) and not target.is_queued_for_deletion() \
	and target.is_targetable() and not target.damage_receiver.dead \
	and Rect2(Vector2.ZERO, get_viewport_rect().size).grow(-20.0).has_point(target.get_global_transform_with_canvas() * Vector2.ZERO)

func _nearest_bounce_target() -> PrototypeTarget:
	var result: PrototypeTarget
	var nearest := ricochet_range_px
	for node in get_tree().get_nodes_in_group("combat_enemy"):
		var candidate := node as PrototypeTarget
		if not _eligible(candidate) or candidate.get_instance_id() == _first_target_id: continue
		var distance := global_position.distance_to(candidate.global_position + PrototypeTarget.BODY_CENTER)
		if distance <= nearest:
			nearest = distance
			result = candidate
	return result

func _locked_target() -> PrototypeTarget:
	var target: PrototypeTarget = _bounce_target.get_ref() as PrototypeTarget if _bounce_target != null else null
	return target if _eligible(target) and target.spawn_generation == _bounce_generation else null
