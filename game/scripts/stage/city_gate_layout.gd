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

static func draw_residents(canvas: Node2D) -> void:
	for resident in RESIDENTS:
		canvas.draw_circle(resident + Vector2(0, -48), 22, Color("ffdbb4"))
		canvas.draw_rect(Rect2(resident + Vector2(-20, -25), Vector2(40, 25)), Color("748eae"))
		for eye_x in [-7, 7]: canvas.draw_circle(resident + Vector2(eye_x, -51), 2.5, Color("34465c"))
		canvas.draw_arc(resident + Vector2(0, -48), 10, 0.15, PI - 0.15, 12, Color("34465c"), 2)
	canvas.draw_string(ThemeDB.fallback_font, Vector2(2430, 565), "어서 오세요. 오늘도 행복한 하루예요.", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("354b64"))
