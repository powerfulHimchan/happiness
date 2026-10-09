class_name SwordWave
extends Node2D

## 시전 방향으로 진행하는 검기. 큰 프레임에도 가까운 적부터 관통한다.
signal hit_registered(target: PrototypeTarget, damage: int, result: int, projectile_id: String)

const SPEED_PX_S := 1200.0
var damage_handler: Callable
var projectile_id: String = ""
var damage: int = 0
var direction: int = 1
var max_distance_px: float = 600.0
var hit_radius_px: float = 60.0
var max_hits: int = 3
var origin: Vector2
var _travelled_px: float = 0.0
var _previous_travelled_px: float = 0.0
var _hit_count: int = 0
var _hit_target_keys: Dictionary = {}

func _ready() -> void:
	add_to_group("sword_wave")
	z_index = 60
	z_as_relative = false
	origin = global_position
	queue_redraw()

func _draw() -> void:
	var points := PackedVector2Array()
	for index in 17:
		var angle := -PI / 2 + PI * index / 16
		points.append(Vector2(cos(angle) * 28 * direction, sin(angle) * hit_radius_px))
	draw_polyline(points, Color("8aeaff", 0.30), 18, true)
	draw_polyline(points, Color("d9fbff"), 6, true)

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	if not damage_handler.is_valid():
		queue_free()
		return
	_previous_travelled_px = _travelled_px
	_travelled_px = minf(max_distance_px, _travelled_px + maxf(0.0, delta) * SPEED_PX_S)
	global_position = origin + Vector2(direction * _travelled_px, 0)
	_check_hits()
	if _hit_count >= max_hits or _travelled_px >= max_distance_px:
		queue_free()

func _check_hits() -> void:
	if is_queued_for_deletion() or _hit_count >= max_hits: return
	var candidates: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("targetable"):
		var target := node as PrototypeTarget
		if target == null or not target.is_targetable() or target.damage_receiver.dead \
		or _hit_target_keys.has(target.target_key): continue
		var offset := target.global_position + PrototypeTarget.BODY_CENTER - origin
		var forward := offset.x * direction
		if forward < 0 or forward > max_distance_px or absf(offset.y) > hit_radius_px: continue
		var contact := maxf(0.0, forward - sqrt(maxf(0.0, hit_radius_px * hit_radius_px - offset.y * offset.y)))
		# 현재 검기 뒤로 이동한 적을 과거 경로에서 다시 명중시키지 않는다.
		if contact > _travelled_px or forward + hit_radius_px < _previous_travelled_px: continue
		candidates.append({"target": target, "contact": contact})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.contact < b.contact)
	for candidate in candidates:
		var target: PrototypeTarget = candidate.target
		_hit_target_keys[target.target_key] = true
		var event := DamageEvent.new()
		event.event_id = StringName("%s:%s" % [projectile_id, target.target_key])
		event.attacker_id = &"player"
		event.attack_id = &"sword_wave"
		event.damage = damage
		event.stagger_s = 0.10
		event.tags = PackedStringArray(["sword", "skill", "wave"])
		event.source_position = origin
		var result: int = damage_handler.call(target, event)
		if result == DamageReceiver.Result.APPLIED: _hit_count += 1
		hit_registered.emit(target, damage, result, projectile_id)
		if _hit_count >= max_hits: return
