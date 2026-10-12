class_name PrototypeRouteTerrain
extends Node2D

## GP-107: 같은 전진 구간에 경로별 충돌 발판과 낙하 복귀점을 구성한다.
const MEADOW_BRIDGE := Rect2(3300, 840, 500, 40)
const WIND_STEPS: Array[Rect2] = [
	Rect2(3080, 720, 260, 32),
	Rect2(3410, 600, 240, 32),
	Rect2(3720, 720, 260, 32),
]
const PLAYER_HALF_HEIGHT := 60.0
const CLOCKWORK_STEPS: Array[Rect2] = [
	Rect2(3080, 720, 200, 32),
	Rect2(3400, 600, 200, 32),
	Rect2(3720, 720, 220, 32),
]
const SAFE_EDGE_MARGIN := 40.0
const FOREST_STEPS: Array[Rect2] = [
	Rect2(2960, 840, 220, 40),
	Rect2(3080, 720, 260, 32),
	Rect2(3410, 600, 240, 32),
	Rect2(3720, 720, 260, 32),
]
const FOREST_MOVING_INDICES := [1, 3]
const FOREST_PERIOD_S := 4.0
const RUINS_STEPS: Array[Rect2] = FOREST_STEPS
const RUINS_PERIOD_S := 6.0
var motion_elapsed_s: float = 0.0

@onready var player: PrototypePlayer = get_node("../Player") as PrototypePlayer
var stage_number: int = 1
var route_id: String = "meadow"
var platforms: Array[Rect2] = []
var _last_landed_platform: int = -1


func configure(stage: int, route: String, enabled: bool = true) -> void:
	for body in get_children():
		body.free()
	stage_number = stage
	route_id = route
	platforms.clear()
	_last_landed_platform = -1
	motion_elapsed_s = 0.0
	# 첫 스테이지와 자유 전투는 기존 이동 검증 지형을 사용한다.
	if enabled and stage > 1:
		if route == "meadow":
			platforms.append(MEADOW_BRIDGE)
		elif route == "wind":
			platforms.assign(WIND_STEPS)
		elif route == "clockwork":
			platforms.assign(CLOCKWORK_STEPS)
		elif route == "forest":
			platforms.assign(FOREST_STEPS)
		elif route == "ruins":
			platforms.assign(RUINS_STEPS)
	for index in platforms.size():
		var rect := platforms[index]
		var body: PhysicsBody2D = AnimatableBody2D.new() if route in ["forest", "ruins"] and index in FOREST_MOVING_INDICES else StaticBody2D.new()
		body.name = "RoutePlatform%d" % index
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = rect.size
		shape.shape = rectangle
		body.add_child(shape)
		add_child(body)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if route_id in ["forest", "ruins"] and not platforms.is_empty():
		var period := FOREST_PERIOD_S if route_id == "forest" else RUINS_PERIOD_S
		motion_elapsed_s = fmod(motion_elapsed_s + delta, period)
		for index in FOREST_MOVING_INDICES:
			var base := FOREST_STEPS[index]
			var offset := Vector2(40.0, -20.0) * sin(motion_elapsed_s * TAU / FOREST_PERIOD_S) if route_id == "forest" else Vector2(90.0, 0.0) * ruins_motion_ratio()
			offset *= 1.0 if index == 1 else -1.0
			platforms[index] = Rect2(base.position + offset, base.size)
			get_child(index).position = platforms[index].get_center()
		queue_redraw()
	if platforms.is_empty() or not player.is_on_floor():
		return
	for index in platforms.size():
		if route_id in ["forest", "ruins"] and index in FOREST_MOVING_INDICES:
			continue
		var rect := platforms[index]
		var feet_y := player.global_position.y + PLAYER_HALF_HEIGHT
		if absf(feet_y - rect.position.y) <= 3.0 and player.global_position.x >= rect.position.x + SAFE_EDGE_MARGIN and player.global_position.x <= rect.end.x - SAFE_EDGE_MARGIN:
			if index != _last_landed_platform:
				_last_landed_platform = index
				var label := "유적 고정 쉼터" if route_id == "ruins" else "숲 고정 쉼터" if route_id == "forest" else "태엽 발판" if route_id == "clockwork" else "바람 발판"
				player.set_safe_spawn(Vector2(rect.get_center().x, rect.position.y - PLAYER_HALF_HEIGHT), "풀숲 다리" if route_id == "meadow" else "%s %d" % [label, index + 1])
			return
	_last_landed_platform = -1


func ruins_motion_ratio() -> float:
	if motion_elapsed_s < 1.5: return 0.0
	if motion_elapsed_s < 3.0: return (motion_elapsed_s - 1.5) / 1.5
	if motion_elapsed_s < 4.5: return 1.0
	return (RUINS_PERIOD_S - motion_elapsed_s) / 1.5


func layout_snapshot() -> Dictionary:
	return {"stage": stage_number, "route": route_id, "platforms": platforms.duplicate(), "body_count": get_child_count(), "motion_elapsed": motion_elapsed_s}


func _draw() -> void:
	var base := Color("729452") if route_id == "meadow" else Color("5688a9")
	var rim := Color("d3e996") if route_id == "meadow" else Color("c5f2ff")
	if route_id == "clockwork":
		base = Color("8b5940")
		rim = Color("ffba66")
	if route_id == "forest":
		base = Color("467b55")
		rim = Color("e5ef9e")
		for x in range(900, 4800, 380):
			var stem := Vector2(x, 180)
			draw_line(stem, stem + Vector2(80, 420), Color("49795c"), 12)
			for y in range(60, 420, 60):
				draw_circle(stem + Vector2(y * 0.19, y), 24, Color("9bd394", 0.55))
	if route_id == "ruins":
		base = Color("567d9c")
		rim = Color("ffe5a0")
		for x in range(1000, 4800, 420):
			var center := Vector2(x, 330)
			draw_circle(center, 55, Color("6da4bc", 0.35))
			draw_arc(center, 55, 0, TAU, 32, rim, 3)
			draw_line(center, center + Vector2(0, -35), rim, 4)
			draw_line(center, center + Vector2(28, 14), rim, 4)
	for index in platforms.size():
		var rect := platforms[index]
		draw_rect(rect, base, true)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 8)), rim, true)
		for x in range(int(rect.position.x + 18), int(rect.end.x), 40):
			draw_line(Vector2(x, rect.position.y + 12), Vector2(x, rect.end.y - 4), rim.darkened(0.25), 2)
		var text := "풀숲 다리 · 그대로 전진" if route_id == "meadow" else "바람 발판 %d · 길게 점프" % (index + 1)
		if route_id == "clockwork":
			text = "태엽 발판 %d · 낙하 주의" % (index + 1)
		if route_id == "forest":
			text = "움직이는 덩굴 · 점프" if index in FOREST_MOVING_INDICES else "고정 쉼터 · 안전 복귀"
			draw_line(Vector2(rect.get_center().x, 300), Vector2(rect.get_center().x, rect.position.y), rim.darkened(0.30), 5)
		if route_id == "ruins":
			text = "시간 발판 · 멈춤/반복" if index in FOREST_MOVING_INDICES else "유적 고정 쉼터 · 안전 복귀"
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(4, -18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("173147"))
