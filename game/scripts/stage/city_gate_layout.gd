class_name CityGateLayout
extends RefCounted

## GP-309: 성문 외곽·계단·성벽 쉼터. 장식은 충돌/보상/저장 상태를 갖지 않는다.
const TERRAIN_NAME := "성문 계단 · 성벽 쉼터"
const PLATFORMS: Array[Rect2] = [
	Rect2(2960, 840, 240, 40), Rect2(3120, 720, 260, 32),
	Rect2(3390, 620, 300, 40), Rect2(3690, 720, 280, 32),
	Rect2(3990, 840, 260, 40), Rect2(4260, 720, 320, 28),
]
const WAVE_ONE := {"slime": Vector2(1490, 780), "seed": Vector2(2210, 780), "wind": Vector2(1810, 530)}
const WAVE_TWO := {"slime": Vector2(4070, 780), "seed": Vector2(4420, 660), "wind": Vector2(4700, 520)}
const RESIDENTS: Array[Vector2] = [Vector2(2520, 470), Vector2(2690, 470), Vector2(2860, 470)]

static func objective(index: int) -> String:
	return ["하얀 성벽을 향해 전진", "성문 앞 미소 가면 경비병 처치", "성문 계단을 넘어 성벽 쉼터로 이동", "성벽 위 미소 가면 경비병의 창 찌르기 회피", "성문 정예를 처치하고 중심부로 이동"][index]

static func draw_backdrop(canvas: Node2D) -> void:
	var stone := Color("d3dfdf")
	var shade := Color("839eae")
	var gold := Color("e8bc65")
	# 지평선의 집들과 높은 성벽은 실제 적/플랫폼보다 뒤에 그린다.
	for x in range(800, 4800, 340):
		canvas.draw_rect(Rect2(x, 430, 220, 170), Color("b8cfcd"))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 15, 430), Vector2(x + 110, 345), Vector2(x + 235, 430)]), Color("b58eac"))
		canvas.draw_rect(Rect2(x + 85, 475, 50, 65), Color("f8e8ab"))
	canvas.draw_rect(Rect2(2400, 240, 600, 370), stone)
	canvas.draw_rect(Rect2(2400, 470, 600, 22), shade)
	for x in range(2420, 3000, 60):
		canvas.draw_rect(Rect2(x, 205, 35, 45), stone)
	for resident in RESIDENTS:
		canvas.draw_circle(resident + Vector2(0, -48), 22, Color("ffdbb4"))
		canvas.draw_rect(Rect2(resident + Vector2(-20, -25), Vector2(40, 25)), Color("748eae"))
		for eye_x in [-7, 7]: canvas.draw_circle(resident + Vector2(eye_x, -51), 2.5, Color("34465c"))
		canvas.draw_arc(resident + Vector2(0, -48), 10, 0.15, PI - 0.15, 12, Color("34465c"), 2)
	canvas.draw_string(ThemeDB.fallback_font, Vector2(2430, 565), "어서 오세요. 오늘도 행복한 하루예요.", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("354b64"))
	for x in [3180, 3770]:
		canvas.draw_rect(Rect2(x, 210, 140, 410), stone)
		canvas.draw_rect(Rect2(x - 12, 190, 164, 40), shade)
		for y in range(290, 600, 100): canvas.draw_rect(Rect2(x + 50, y, 40, 55), Color("526d89"))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 20, 190), Vector2(x + 70, 100), Vector2(x + 160, 190)]), Color("b58eac"))
		canvas.draw_line(Vector2(x + 70, 100), Vector2(x + 70, 40), gold, 4)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x + 70, 40), Vector2(x + 135, 65), Vector2(x + 70, 85)]), gold)
	canvas.draw_rect(Rect2(3320, 290, 450, 95), stone)
	canvas.draw_arc(Vector2(3545, 500), 210, PI, TAU, 40, gold, 18)
	canvas.draw_string(ThemeDB.fallback_font, Vector2(3390, 350), "행복의 나라", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color("354b64"))
