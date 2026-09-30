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
const SAFE_EDGE_MARGIN := 40.0

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
	# 첫 스테이지와 자유 전투는 기존 이동 검증 지형을 사용한다.
	if enabled and stage > 1:
		if route == "meadow":
			platforms.append(MEADOW_BRIDGE)
		elif route == "wind":
			platforms.assign(WIND_STEPS)
	for index in platforms.size():
		var rect := platforms[index]
		var body := StaticBody2D.new()
		body.name = "RoutePlatform%d" % index
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = rect.size
		shape.shape = rectangle
		body.add_child(shape)
		add_child(body)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if platforms.is_empty() or not player.is_on_floor():
		return
	for index in platforms.size():
		var rect := platforms[index]
		var feet_y := player.global_position.y + PLAYER_HALF_HEIGHT
		if absf(feet_y - rect.position.y) <= 3.0 and player.global_position.x >= rect.position.x + SAFE_EDGE_MARGIN and player.global_position.x <= rect.end.x - SAFE_EDGE_MARGIN:
			if index != _last_landed_platform:
				_last_landed_platform = index
				player.set_safe_spawn(Vector2(rect.get_center().x, rect.position.y - PLAYER_HALF_HEIGHT), "풀숲 다리" if route_id == "meadow" else "바람 발판 %d" % (index + 1))
			return
	_last_landed_platform = -1


func layout_snapshot() -> Dictionary:
	return {"stage": stage_number, "route": route_id, "platforms": platforms.duplicate(), "body_count": get_child_count()}


func _draw() -> void:
	var base := Color("729452") if route_id == "meadow" else Color("5688a9")
	var rim := Color("d3e996") if route_id == "meadow" else Color("c5f2ff")
	for index in platforms.size():
		var rect := platforms[index]
		draw_rect(rect, base, true)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 8)), rim, true)
		for x in range(int(rect.position.x + 18), int(rect.end.x), 40):
			draw_line(Vector2(x, rect.position.y + 12), Vector2(x, rect.end.y - 4), rim.darkened(0.25), 2)
		var text := "풀숲 다리 · 그대로 전진" if route_id == "meadow" else "바람 발판 %d · 길게 점프" % (index + 1)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(4, -18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("173147"))
