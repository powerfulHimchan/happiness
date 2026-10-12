class_name ClockTrapController
extends Node2D

## GP-240–241: 전투 웨이브 중 경고 후 한 번 타격하는 감속 가능한 시간 함정.
enum State { OFF, WARNING, ACTIVE, RECOVERY }
const ZONES: Array[Rect2] = [Rect2(1620, 702, 280, 96), Rect2(4100, 702, 280, 96)]
const WARNING_S := 1.0
const ACTIVE_S := 0.30
const RECOVERY_S := 2.5
const DAMAGE := 12
var state: int = State.OFF
var route_id: String = "meadow"
var zone_index: int = -1
var elapsed_s: float = 0.0
var enemy_time_scale: float = 1.0
var generation: int = 0
var cycle: int = 0
var hit_count: int = 0
var _hit_consumed: bool = false
@onready var player: PrototypePlayer = get_node("../Player") as PrototypePlayer

func _ready() -> void:
	add_to_group("enemy_time_scaled")
	add_to_group("stage_hazard")
	visible = false

func configure(stage: int, route: String) -> void:
	stop()
	route_id = route if stage > 1 else "meadow"
	generation += 1
	cycle = 0
	hit_count = 0
	enemy_time_scale = 1.0

func start_wave(wave: int) -> void:
	stop()
	if route_id != "ruins" or wave not in [1, 2] or player.damage_receiver.dead:
		return
	zone_index = wave - 1
	_begin_warning()

func stop() -> void:
	state = State.OFF
	elapsed_s = 0.0
	zone_index = -1
	_hit_consumed = false
	visible = false
	queue_redraw()

func set_enemy_time_scale(value: float) -> void:
	enemy_time_scale = clampf(value, 0.0, 1.0)

func _begin_warning() -> void:
	cycle += 1
	_hit_consumed = false
	elapsed_s = 0.0
	state = State.WARNING
	visible = true
	queue_redraw()

func _process(delta: float) -> void:
	if state == State.OFF:
		return
	if player.damage_receiver.dead:
		stop()
		return
	elapsed_s += delta * enemy_time_scale
	match state:
		State.WARNING:
			if elapsed_s >= WARNING_S:
				state = State.ACTIVE
				elapsed_s = 0.0
		State.ACTIVE:
			_try_hit_player()
			if elapsed_s >= ACTIVE_S:
				state = State.RECOVERY
				elapsed_s = 0.0
		State.RECOVERY:
			if elapsed_s >= RECOVERY_S:
				_begin_warning()
	queue_redraw()

func _try_hit_player() -> void:
	if _hit_consumed or state != State.ACTIVE or not player.can_continue_combat_action():
		return
	if not ZONES[zone_index].has_point(player.global_position + Vector2(0, -38)):
		return
	_hit_consumed = true
	var event := DamageEvent.new()
	event.event_id = StringName("clock_trap:%d:%d:%d:%d" % [get_instance_id(), generation, zone_index, cycle])
	event.attacker_id = &"star_clock_trap"
	event.attack_id = &"clock_pulse"
	event.damage = DAMAGE
	event.stagger_s = 0.14
	event.tags = PackedStringArray(["enemy", "hazard", "clock", "ruins"])
	event.source_position = ZONES[zone_index].get_center()
	var evading := player.invincible
	var result := player.receive_damage(event)
	if result == DamageReceiver.Result.APPLIED:
		hit_count += 1
	elif evading and result == DamageReceiver.Result.INVULNERABLE_BLOCKED:
		var ultimate := get_tree().get_first_node_in_group("ultimate_controller") as UltimateController
		if ultimate != null: ultimate.register_precise_evade()

func status_text() -> String:
	if state == State.WARNING: return "함정 경고 %.1f초" % maxf(0.0, WARNING_S - elapsed_s)
	if state == State.ACTIVE: return "함정 발동 · 점프/회피"
	if state == State.RECOVERY: return "함정 휴식"
	return "함정 정지"

func snapshot() -> Dictionary:
	return {"state": state, "route": route_id, "zone": zone_index, "elapsed": elapsed_s, "cycle": cycle, "generation": generation, "hits": hit_count, "consumed": _hit_consumed, "time_scale": enemy_time_scale}

func _draw() -> void:
	if state == State.OFF or zone_index < 0: return
	var rect := ZONES[zone_index]
	var color := Color("ffd166") if state == State.WARNING else Color("ff655b") if state == State.ACTIVE else Color("709aaa")
	draw_rect(rect, Color(color, 0.12 if state != State.ACTIVE else 0.32))
	if state == State.WARNING:
		for x in range(int(rect.position.x), int(rect.end.x), 28):
			draw_line(Vector2(x, rect.end.y), Vector2(minf(x + 14, rect.end.x), rect.end.y), color, 5)
	elif state == State.ACTIVE:
		draw_rect(rect, color, false, 4)
		for x in range(int(rect.position.x + 20), int(rect.end.x), 48):
			draw_line(Vector2(x, rect.end.y), Vector2(x, rect.position.y), color, 5)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, -14), status_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
