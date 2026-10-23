class_name RegionalLandscapeArt
extends RefCounted

## GP-512–514 / GP-545–547: cached drawing; no bodies, timers or saved state.
const LANDMARKS := {
	"wind": preload("res://assets/landscapes/windmill.svg"),
	"forest": preload("res://assets/landscapes/inverted_grove.svg"),
	"ruins": preload("res://assets/landscapes/star_observatory.svg"),
	"clockwork": preload("res://assets/landscapes/clockwork_foundry.svg"),
	"festival": preload("res://assets/landscapes/festival_carousel.svg"),
	"city_gate": preload("res://assets/landscapes/smiling_city_gate.svg"),
}
const PALETTES := {
	"wind": {"sky": Color("a9d8df"), "horizon": Color("e6ecce"), "far": Color("b0cdba"), "near": Color("97bda3"), "soil": Color("6d9474"), "edge": Color("c5d99b"), "accent": Color("f1e5b9")},
	"forest": {"sky": Color("739eaa"), "horizon": Color("c8dbc5"), "far": Color("8ab4aa"), "near": Color("75a096"), "soil": Color("507e70"), "edge": Color("bdd6a4"), "accent": Color("d7ddb7")},
	"ruins": {"sky": Color("7088aa"), "horizon": Color("c4d3da"), "far": Color("93abc1"), "near": Color("809cb5"), "soil": Color("637e97"), "edge": Color("c2c8b4"), "accent": Color("e0d6b3")},
	"clockwork": {"sky": Color("8eaaa9"), "horizon": Color("ddd4b7"), "far": Color("aeb7a3"), "near": Color("9aa99b"), "soil": Color("7b897b"), "edge": Color("d4c49d"), "accent": Color("e3d5b2")},
	"festival": {"sky": Color("9caac4"), "horizon": Color("e3d5cc"), "far": Color("b9b4bd"), "near": Color("aaa4b4"), "soil": Color("897f96"), "edge": Color("dcc9ac"), "accent": Color("e4d5b5")},
	"city_gate": {"sky": Color("96bdcc"), "horizon": Color("e5e4ce"), "far": Color("b5c8c3"), "near": Color("9fb6ba"), "soil": Color("809aa7"), "edge": Color("d9d1b4"), "accent": Color("e5d7b7")},
}

static func canonical_route(route: String) -> String:
	return "wind" if route in ["wind", "meadow"] else route

static func supports(route: String) -> bool:
	return PALETTES.has(canonical_route(route))

static func palette(route: String) -> Dictionary:
	return PALETTES[canonical_route(route)]

static func draw_backdrop(canvas: Node2D, route: String, section: int) -> void:
	var key := canonical_route(route)
	var colors := palette(key)
	# Wide enough for the full track, tall jumps, camera shake and tablet viewports.
	for stripe in 256:
		var ratio := float(stripe) / 255.0
		canvas.draw_rect(Rect2(-2000, -1400 + stripe * 10, 10000, 11), colors.sky.lerp(colors.horizon, clampf((ratio - 0.45) / 0.4, 0.0, 1.0)))
	if key == "ruins":
		_draw_constellations(canvas, colors.accent)
	else:
		canvas.draw_circle(Vector2(850, 100), 76, Color(colors.accent, 0.25))
		canvas.draw_circle(Vector2(850, 100), 53, Color(colors.accent, 0.55))
		for x in range(-700, 5900, 950):
			_draw_cloud(canvas, Vector2(x, 130 + 35 * sin(x * 0.007)), Color(colors.horizon, 0.42))
	_draw_ridge(canvas, 520.0, 92.0, 0.0018, colors.far)
	_draw_ridge(canvas, 620.0, 58.0, 0.0031, colors.near)
	if key == "forest":
		_draw_distant_grove(canvas, colors)
	elif key == "ruins":
		_draw_distant_columns(canvas, colors)
	elif key == "clockwork":
		_draw_workshop_skyline(canvas, colors)
	elif key == "festival":
		_draw_festival_stalls(canvas, colors)
	elif key == "city_gate":
		_draw_city_wall(canvas, colors)
	else:
		_draw_meadow_fences(canvas, colors)
	# Landmarks stop above the combat floor; actors and warnings render afterward.
	if key == "city_gate":
		canvas.draw_texture_rect(LANDMARKS[key], Rect2(3050, -128, 1000, 800), false, Color(1, 1, 1, 0.86))
		CityGateLayout.draw_residents(canvas)
		return
	for index in 3:
		var x := 850.0 + index * 1950.0
		var size := Vector2(710, 568) if key == "forest" else Vector2(600, 480)
		if section == 2: x += 200.0
		canvas.draw_texture_rect(LANDMARKS[key], Rect2(Vector2(x, 652 - size.y), size), false, Color(1, 1, 1, 0.86))

static func _draw_workshop_skyline(canvas: Node2D, colors: Dictionary) -> void:
	for x in range(-600, 6200, 530):
		var height := 130 + posmod(x, 4) * 27
		var shade := Color(colors.soil, 0.24)
		canvas.draw_rect(Rect2(x, 620 - height, 195, height), shade)
		canvas.draw_rect(Rect2(x + 125, 510 - height, 27, 120), shade)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 10, 620 - height), Vector2(x + 90, 560 - height), Vector2(x + 205, 620 - height)]), shade)
		canvas.draw_line(Vector2(x + 195, 580), Vector2(x + 295, 580), Color(colors.soil, 0.30), 9, true)
		canvas.draw_arc(Vector2(x + 320, 592), 45, PI, TAU, 24, Color(colors.edge, 0.45), 8, true)

static func _draw_festival_stalls(canvas: Node2D, colors: Dictionary) -> void:
	for x in range(-600, 6200, 480):
		canvas.draw_rect(Rect2(x, 530, 210, 100), Color(colors.soil, 0.22))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 20, 530), Vector2(x + 105, 425), Vector2(x + 230, 530)]), Color(colors.soil, 0.26))
		canvas.draw_line(Vector2(x, 350), Vector2(x + 480, 350), Color(colors.edge, 0.45), 2, true)
		for flag in range(0, 480, 60):
			var p := Vector2(x + flag, 350)
			canvas.draw_colored_polygon(PackedVector2Array([p, p + Vector2(28, 0), p + Vector2(14, 28)]), Color(colors.accent if flag % 120 == 0 else colors.soil, 0.40))

static func _draw_city_wall(canvas: Node2D, colors: Dictionary) -> void:
	for x in range(-600, 6200, 340):
		canvas.draw_rect(Rect2(x, 450, 220, 180), Color(colors.soil, 0.24))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 15, 450), Vector2(x + 110, 365), Vector2(x + 235, 450)]), Color(colors.soil, 0.30))
		canvas.draw_rect(Rect2(x + 85, 490, 50, 60), Color(colors.accent, 0.55))
	# Balcony keeps the established welcoming residents above the combat lane.
	canvas.draw_rect(Rect2(2380, 380, 620, 250), colors.near.lightened(0.20))
	for x in range(2390, 3000, 65):
		canvas.draw_rect(Rect2(x, 350, 38, 40), colors.near.lightened(0.20))
	canvas.draw_rect(Rect2(2380, 470, 620, 22), colors.soil.lightened(0.10))
	for y in [520, 580]:
		canvas.draw_line(Vector2(2400, y), Vector2(2980, y), Color(colors.soil, 0.22), 3, true)

static func _draw_ridge(canvas: Node2D, height: float, amplitude: float, frequency: float, color: Color) -> void:
	var points := PackedVector2Array([Vector2(-2000, 1140)])
	for x in range(-2000, 8100, 140):
		points.append(Vector2(x, height + sin(x * frequency) * amplitude + cos(x * frequency * 0.63) * amplitude * 0.25))
	points.append(Vector2(8100, 1140))
	canvas.draw_colored_polygon(points, color)

static func _draw_cloud(canvas: Node2D, center: Vector2, color: Color) -> void:
	canvas.draw_circle(center, 28, color)
	canvas.draw_circle(center + Vector2(40, -15), 40, color)
	canvas.draw_circle(center + Vector2(82, 1), 26, color)
	canvas.draw_rect(Rect2(center + Vector2(0, 2), Vector2(82, 24)), color)

static func _draw_meadow_fences(canvas: Node2D, colors: Dictionary) -> void:
	for x in range(-300, 5600, 420):
		var color := Color(colors.soil, 0.26)
		canvas.draw_line(Vector2(x, 650), Vector2(x + 240, 650), color, 6, true)
		for post in [0, 120, 240]:
			canvas.draw_line(Vector2(x + post, 625), Vector2(x + post, 680), color, 8, true)

static func _draw_distant_grove(canvas: Node2D, colors: Dictionary) -> void:
	for x in range(-600, 6000, 430):
		var top := Vector2(x, 175 + 35 * sin(x))
		canvas.draw_line(top, top + Vector2(15, 330), Color(colors.soil, 0.24), 23, true)
		for side in [-1, 1]:
			canvas.draw_line(top + Vector2(0, 45), top + Vector2(side * 75, -25), Color(colors.soil, 0.24), 12, true)
		canvas.draw_circle(top + Vector2(-35, 330), 70, Color(colors.near, 0.65))
		canvas.draw_circle(top + Vector2(45, 320), 85, Color(colors.near, 0.65))

static func _draw_distant_columns(canvas: Node2D, colors: Dictionary) -> void:
	for x in range(-600, 6000, 400):
		var height := 100 + posmod(x, 3) * 45
		canvas.draw_rect(Rect2(x, 630 - height, 42, height), Color(colors.soil, 0.23))
		canvas.draw_rect(Rect2(x - 9, 630 - height, 60, 14), Color(colors.horizon, 0.35))
		canvas.draw_rect(Rect2(x - 14, 630, 70, 13), Color(colors.soil, 0.23))

static func _draw_constellations(canvas: Node2D, color: Color) -> void:
	for x in range(-500, 5900, 760):
		var center := Vector2(x, 110 + 45 * sin(x * 0.01))
		var points := PackedVector2Array([center + Vector2(-75, 20), center + Vector2(-25, -25), center + Vector2(35, 10), center + Vector2(80, -40)])
		canvas.draw_polyline(points, Color(color, 0.20), 2, true)
		for point in points: canvas.draw_circle(point, 3.5, Color(color, 0.65))

static func draw_floor_details(canvas: Node2D, route: String, floors: Array[Rect2]) -> void:
	var key := canonical_route(route)
	var colors := palette(key)
	for floor_rect in floors:
		for x in range(int(floor_rect.position.x + 30), int(floor_rect.end.x - 10), 115):
			var surface := Vector2(x, floor_rect.position.y)
			if key == "wind":
				canvas.draw_line(surface, surface + Vector2(3, -15), colors.soil.darkened(0.1), 2, true)
				for offset in [Vector2(-4, -15), Vector2(4, -15), Vector2(0, -20)]:
					canvas.draw_circle(surface + offset, 3.5, colors.accent)
				canvas.draw_circle(surface + Vector2(0, -15), 2.5, colors.edge)
			elif key == "forest":
				canvas.draw_arc(surface + Vector2(0, 14), 17, PI, TAU, 12, Color(colors.edge, 0.55), 3, true)
				canvas.draw_line(surface + Vector2(-15, 12), surface + Vector2(-22, 32), Color(colors.edge, 0.38), 2, true)
			elif key == "ruins":
				canvas.draw_line(surface + Vector2(0, 18), surface + Vector2(12, 34), Color(colors.edge, 0.45), 2, true)
				canvas.draw_line(surface + Vector2(12, 34), surface + Vector2(6, 55), Color(colors.edge, 0.45), 2, true)
			elif key == "clockwork":
				canvas.draw_line(surface + Vector2(-18, 30), surface + Vector2(72, 30), Color(colors.edge, 0.35), 5, true)
				canvas.draw_circle(surface + Vector2(0, 30), 4, colors.edge)
			elif key == "festival":
				canvas.draw_line(surface + Vector2(-15, 25), surface + Vector2(8, 48), Color(colors.edge, 0.40), 4, true)
				canvas.draw_circle(surface + Vector2(44, 22), 3, Color(colors.edge, 0.50))
			else:
				canvas.draw_line(surface + Vector2(-22, 32), surface + Vector2(72, 32), Color(colors.edge, 0.30), 2, true)
				canvas.draw_line(surface + Vector2(20, 32), surface + Vector2(20, 60), Color(colors.edge, 0.30), 2, true)
			canvas.draw_line(surface + Vector2(30, 60), surface + Vector2(70, 60), Color(colors.edge, 0.16), 2, true)

static func draw_platform_inlay(canvas: Node2D, route: String, rect: Rect2) -> void:
	if not supports(route): return
	var key := canonical_route(route)
	var colors := palette(key)
	for x in range(int(rect.position.x + 30), int(rect.end.x - 16), 60):
		var center := Vector2(x, rect.position.y + rect.size.y * 0.65)
		if key == "ruins":
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-6, 0), center + Vector2(0, -6), center + Vector2(6, 0), center + Vector2(0, 6), center + Vector2(-6, 0)]), Color(colors.accent, 0.75), 1.5, true)
		elif key == "clockwork":
			canvas.draw_circle(center, 3, Color(colors.accent, 0.65))
		elif key == "festival":
			canvas.draw_line(center + Vector2(-5, -5), center + Vector2(5, 5), Color(colors.accent, 0.60), 2, true)
		elif key == "city_gate":
			canvas.draw_rect(Rect2(center - Vector2(8, 3), Vector2(16, 6)), Color(colors.accent, 0.55), false, 1.5)
		else:
			canvas.draw_arc(center, 7, PI, TAU, 12, Color(colors.accent, 0.55), 2, true)
