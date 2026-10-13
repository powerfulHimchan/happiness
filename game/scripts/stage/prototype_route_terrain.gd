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
const FESTIVAL_STEPS: Array[Rect2] = FOREST_STEPS
const FESTIVAL_PERIOD_S := 5.0
const FESTIVAL_ORBIT := Vector2(32, 24)
const FESTIVAL_LIFT_PX := 45.0
var region_section: int = 1
var base_platforms: Array[Rect2] = []
var motion_elapsed_s: float = 0.0

@onready var player: PrototypePlayer = get_node("../Player") as PrototypePlayer
var stage_number: int = 1
var route_id: String = "meadow"
var platforms: Array[Rect2] = []
var _last_landed_platform: int = -1


func configure(stage: int, route: String, enabled: bool = true, regional_start: bool = false, section: int = 1) -> void:
	for body in get_children():
		body.free()
	stage_number = stage
	route_id = route
	region_section = 2 if section == 2 and RegionStageLayout.TITLES.has(route) else 1
	platforms.clear()
	_last_landed_platform = -1
	motion_elapsed_s = 0.0
	# 첫 스테이지와 자유 전투는 기존 이동 검증 지형을 사용한다.
	if enabled and (stage > 1 or regional_start):
		if route in ["meadow", "city_gate", "city_core"]:
			platforms.append(MEADOW_BRIDGE)
		elif route == "wind":
			platforms.assign(WIND_STEPS)
		elif route == "clockwork":
			platforms.assign(CLOCKWORK_STEPS)
		elif route == "forest":
			platforms.assign(FOREST_STEPS)
		elif route == "ruins":
			platforms.assign(RUINS_STEPS)
		elif route == "festival":
			platforms.assign(FESTIVAL_STEPS)
	if enabled and region_section == 2:
		platforms.assign(RegionStageLayout.platforms(route))
	base_platforms.assign(platforms)
	for index in platforms.size():
		var rect := platforms[index]
		var body: PhysicsBody2D = AnimatableBody2D.new() if route in ["forest", "ruins", "festival"] and index in FOREST_MOVING_INDICES else StaticBody2D.new()
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
	if route_id in ["forest", "ruins", "festival"] and not platforms.is_empty():
		var period := FESTIVAL_PERIOD_S if route_id == "festival" else FOREST_PERIOD_S if route_id == "forest" else RUINS_PERIOD_S
		motion_elapsed_s = fmod(motion_elapsed_s + delta, period)
		for index in FOREST_MOVING_INDICES:
			var base := base_platforms[index]
			var offset := (Vector2(28.0, -12.0) if region_section == 2 else Vector2(40.0, -20.0)) * sin(motion_elapsed_s * TAU / FOREST_PERIOD_S) if route_id == "forest" else Vector2(55.0 if region_section == 2 else 90.0, 0.0) * ruins_motion_ratio()
			offset *= 1.0 if index == 1 else -1.0
			if route_id == "festival":
				# 발판은 수평을 유지한 채 놀이기구 궤도를 돌며 탑승자를 운반한다.
				var angle := motion_elapsed_s * TAU / FESTIVAL_PERIOD_S
				var orbit := Vector2(22, 16) if region_section == 2 else FESTIVAL_ORBIT
				offset = Vector2(orbit.x * sin(angle), orbit.y * (1.0 - cos(angle))) if index == 1 else Vector2(0, -(30.0 if region_section == 2 else FESTIVAL_LIFT_PX) * sin(angle))
			platforms[index] = Rect2(base.position + offset, base.size)
			get_child(index).position = platforms[index].get_center()
		queue_redraw()
	if platforms.is_empty() or not player.is_on_floor():
		return
	for index in platforms.size():
		if route_id in ["forest", "ruins", "festival"] and index in FOREST_MOVING_INDICES:
			continue
		var rect := platforms[index]
		var feet_y := player.global_position.y + PLAYER_HALF_HEIGHT
		if absf(feet_y - rect.position.y) <= 3.0 and player.global_position.x >= rect.position.x + SAFE_EDGE_MARGIN and player.global_position.x <= rect.end.x - SAFE_EDGE_MARGIN:
			if index != _last_landed_platform:
				_last_landed_platform = index
				var label := "축제 고정 쉼터" if route_id == "festival" else "유적 고정 쉼터" if route_id == "ruins" else "숲 고정 쉼터" if route_id == "forest" else "태엽 발판" if route_id == "clockwork" else "바람 발판"
				player.set_safe_spawn(Vector2(rect.get_center().x, rect.position.y - PLAYER_HALF_HEIGHT), "풀숲 다리" if route_id == "meadow" else "%s %d" % [label, index + 1])
			return
	_last_landed_platform = -1


func ruins_motion_ratio() -> float:
	if motion_elapsed_s < 1.5: return 0.0
	if motion_elapsed_s < 3.0: return (motion_elapsed_s - 1.5) / 1.5
	if motion_elapsed_s < 4.5: return 1.0
	return (RUINS_PERIOD_S - motion_elapsed_s) / 1.5


func layout_snapshot() -> Dictionary:
	return {"stage": stage_number, "route": route_id, "platforms": platforms.duplicate(), "body_count": get_child_count(), "motion_elapsed": motion_elapsed_s, "region_section": region_section, "base_platforms": base_platforms.duplicate()}


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
		if route_id == "festival":
			base = Color("b15e74")
			rim = Color("ffe2a3")
			if index == 1:
				var hub := base_platforms[1].get_center() + Vector2(0, 16 if region_section == 2 else FESTIVAL_ORBIT.y)
				draw_arc(hub, 72, 0, TAU, 32, rim, 5)
				draw_line(hub, rect.get_center(), Color("62768d"), 8)
			elif index == 3:
				for x in [rect.position.x + 32, rect.end.x - 32]:
					draw_line(Vector2(x, 660), Vector2(x, 850), Color("62768d"), 7)
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
		if route_id in ["city_gate", "city_core"]:
			text = "성문 다리 · 앞으로 전진" if route_id == "city_gate" else "중심부 다리 · 앞으로 전진"
		if route_id == "festival":
			text = "회전 놀이 발판" if index == 1 else "기계 승강대" if index == 3 else "축제 고정 쉼터 · 안전 복귀"
		if region_section == 2 and index == 0: text = String(RegionStageLayout.TITLES[route_id]) + " · 2/2"
		elif region_section == 2 and index == 4: text = "출구 쉼터 · 안전 복귀"
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(4, -18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("173147"))
	if route_id == "festival":
		for x in range(900, 4800, 400):
			draw_line(Vector2(x, 280), Vector2(x + 320, 280), rim, 3)
			for flag_x in range(x, x + 320, 40):
				draw_colored_polygon(PackedVector2Array([Vector2(flag_x, 280), Vector2(flag_x + 30, 280), Vector2(flag_x + 15, 320)]), base)
