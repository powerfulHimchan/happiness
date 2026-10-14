class_name CityCoreLayout
extends RefCounted

## GP-310: 시계탑 회랑과 궁전 앞 광장. 보스 평지에는 높은 충돌 발판을 두지 않는다.
const TERRAIN_NAME := "시계탑 회랑 · 궁전 앞 광장"
const PLATFORMS: Array[Rect2] = [
	Rect2(2960, 840, 220, 40), Rect2(3130, 730, 280, 32),
	Rect2(3410, 650, 280, 40), Rect2(3690, 750, 210, 32),
	Rect2(3970, 840, 260, 40),
]
const WAVE_ONE := {"slime": Vector2(1530, 780), "seed": Vector2(2160, 600), "wind": Vector2(1830, 480)}
const WAVE_TWO := {"slime": Vector2(4090, 780), "seed": Vector2(4670, 780), "wind": Vector2(4380, 550)}

static func objective(index: int) -> String:
	return ["시계탑을 향해 중심부로 전진", "높은 회랑의 씨앗 포대·공중 정령 처치", "시계탑 발판을 건너 궁전 앞 광장으로 이동", "궁전 앞 양쪽 적과 공중 정령 처치"][index]

static func draw_backdrop(canvas: Node2D) -> void:
	var stone := Color("cdd9e6")
	var violet := Color("8d88b5")
	var gold := Color("e8bc65")
	# 장식은 플레이어·적보다 뒤에 표시하며 표적이나 충돌 몸체를 만들지 않는다.
	for x in range(900, 2900, 340):
		canvas.draw_rect(Rect2(x, 370, 220, 240), stone)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 15, 370), Vector2(x + 110, 295), Vector2(x + 235, 370)]), violet)
		for window_x in [x + 35, x + 135]: canvas.draw_rect(Rect2(window_x, 440, 50, 65), Color("f8e8ab"))
	canvas.draw_rect(Rect2(3400, 210, 290, 405), stone)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(3350, 210), Vector2(3545, 80), Vector2(3740, 210)]), violet)
	canvas.draw_rect(Rect2(3380, 595, 330, 25), violet)
	var clock_center := Vector2(3545, 355)
	canvas.draw_circle(clock_center, 105, Color("f6eccb"))
	canvas.draw_arc(clock_center, 105, 0, TAU, 48, gold, 9)
	for i in 12:
		var direction := Vector2.UP.rotated(i * TAU / 12.0)
		canvas.draw_line(clock_center + direction * 83, clock_center + direction * 95, violet, 4)
	canvas.draw_line(clock_center, clock_center + Vector2(0, -70), Color("526d89"), 7)
	canvas.draw_line(clock_center, clock_center + Vector2(24, 48), Color("526d89"), 7)
	canvas.draw_circle(clock_center, 9, gold)
	canvas.draw_string(ThemeDB.fallback_font, Vector2(3420, 535), "새벽을 기다리는 시계", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("354b64"))
	# 궁전과 계단은 배경이다. 실제 마지막 전투는 기존 높이840의 평지를 사용한다.
	canvas.draw_rect(Rect2(4140, 260, 690, 365), stone)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(4080, 260), Vector2(4485, 120), Vector2(4890, 260)]), violet)
	canvas.draw_rect(Rect2(4385, 350, 200, 275), Color("526d89"))
	canvas.draw_rect(Rect2(4468, 380, 34, 150), gold)
	for x in [4190, 4290, 4650, 4750]: canvas.draw_rect(Rect2(x, 330, 35, 260), Color("f6eccb"))
	for i in 3: canvas.draw_rect(Rect2(4300 - 45 * i, 625 + 25 * i, 370 + 90 * i, 25), stone.darkened(i * 0.07))
	canvas.draw_string(ThemeDB.fallback_font, Vector2(4210, 220), "행복의 나라 중심부", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("354b64"))
