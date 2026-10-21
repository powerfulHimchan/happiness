class_name StaffMagicBolt
extends Node2D

## 이동 구간 전체를 검사해 낮은 프레임에서도 가까운 적부터 맞힌다.
signal hit_registered(target: PrototypeTarget, damage: int, result: int)
var damage_handler: Callable
var projectile_id: String
var attack_id: StringName = &"staff_basic"
var damage: int = 22
var direction := Vector2.RIGHT
var speed_px_s: float = 600.0
var max_distance_px: float = 700.0
var max_hits: int = 1
var explosion_radius_px: float = 0.0
var element: String = "magic"
var _travelled: float = 0.0
var _hit_keys: Dictionary = {}
var _hit_count: int = 0

func _ready() -> void:
	add_to_group("staff_magic_bolt")
	z_index = 60
	z_as_relative = false

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	if not damage_handler.is_valid():
		queue_free()
		return
	var before := global_position
	var distance := minf(max_distance_px - _travelled,maxf(0,delta) * speed_px_s)
	var end := before + direction * distance
	var candidates: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("targetable"):
		var target := node as PrototypeTarget
		if target == null or not target.is_targetable() or _hit_keys.has(target.target_key): continue
		var offset := target.global_position + PrototypeTarget.BODY_CENTER - before
		var forward := offset.dot(direction)
		var perpendicular := absf(offset.cross(direction))
		if perpendicular > 25.0 or forward < -25.0 or forward > distance + 25.0: continue
		var contact := maxf(0.0,forward - sqrt(maxf(0.0,625.0 - perpendicular * perpendicular)))
		if contact <= distance: candidates.append({"target":target,"contact":contact})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.contact < b.contact)
	for candidate in candidates:
		var target: PrototypeTarget = candidate.target
		global_position = before + direction * float(candidate.contact)
		if explosion_radius_px > 0.0:
			var center := target.global_position
			for node in get_tree().get_nodes_in_group("targetable"):
				var victim := node as PrototypeTarget
				if victim != null and victim.is_targetable() and victim.global_position.distance_to(center) <= explosion_radius_px: _damage(victim,before)
			queue_free()
			return
		_damage(target,before)
		_hit_count += 1
		if _hit_count >= max_hits:
			queue_free()
			return
	global_position = end
	_travelled += distance
	if _travelled >= max_distance_px: queue_free()

func _damage(target: PrototypeTarget, source: Vector2) -> void:
	if _hit_keys.has(target.target_key): return
	_hit_keys[target.target_key] = true
	var event := DamageEvent.new()
	event.event_id = StringName(projectile_id + ":" + target.target_key)
	event.attacker_id = &"player"
	event.attack_id = attack_id
	event.damage = damage
	event.stagger_s = 0.1
	event.tags = PackedStringArray(["staff","basic" if attack_id == &"staff_basic" else "skill",element,"projectile"])
	event.source_position = source
	var result: int = damage_handler.call(target,event)
	hit_registered.emit(target,damage,result)

func _draw() -> void:
	var color := Color("ffb36b") if element == "fire" else Color("a5eeff") if element == "ice" else Color("d9b6ff")
	draw_line(-direction * 25,Vector2.ZERO,Color(color,0.35),12,true)
	draw_circle(Vector2.ZERO,12,color)
	draw_circle(Vector2.ZERO,5,Color("fff6dc"))
