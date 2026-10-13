class_name RegionStageLayout
extends RefCounted

## GP-308: 전체 여정의 지역 두 번째 구간. 경로 ID와 저장 버전은 유지한다.
const TITLES := {"wind": "바람꽃 능선", "forest": "수관 오솔길", "ruins": "엇갈린 시계 회랑", "festival": "기계 정원"}
const DESCRIPTIONS := {"wind": "높낮이 능선 · 고정 발판", "forest": "낮은 덩굴 · 수관 쉼터", "ruins": "엇갈린 시간 발판 · 이동한 함정", "festival": "회전 기구 · 승강대 · 중앙 쉼터"}
const WIND: Array[Rect2] = [Rect2(2960, 840, 240, 40), Rect2(3120, 720, 260, 32), Rect2(3370, 620, 280, 32), Rect2(3640, 720, 260, 32), Rect2(3900, 840, 240, 40)]
const FOREST: Array[Rect2] = [Rect2(2960, 840, 240, 40), Rect2(3120, 720, 260, 32), Rect2(3380, 640, 280, 40), Rect2(3650, 720, 260, 32), Rect2(3940, 840, 240, 40), Rect2(4260, 720, 320, 28)]
const RUINS: Array[Rect2] = [Rect2(2960, 840, 240, 40), Rect2(3120, 720, 260, 32), Rect2(3420, 600, 300, 40), Rect2(3710, 720, 300, 32), Rect2(4010, 840, 240, 40)]
const FESTIVAL: Array[Rect2] = [Rect2(2960, 840, 240, 40), Rect2(3120, 720, 280, 32), Rect2(3390, 620, 300, 40), Rect2(3700, 720, 300, 32), Rect2(4030, 840, 240, 40)]
const TRAP_ZONES: Array[Rect2] = [Rect2(1960, 702, 240, 96), Rect2(4490, 702, 240, 96)]
const WAVE_ONE := {
	"wind": {"slime": Vector2(1450, 780), "seed": Vector2(2180, 780), "wind": Vector2(1800, 540)},
	"forest": {"slime": Vector2(1480, 780), "seed": Vector2(2180, 600), "wind": Vector2(1850, 470)},
	"ruins": {"slime": Vector2(1510, 780), "seed": Vector2(2150, 780), "wind": Vector2(1780, 540)},
	"festival": {"slime": Vector2(1580, 780), "seed": Vector2(2220, 780), "wind": Vector2(1840, 570)},
}
const WAVE_TWO := {
	"wind": {"slime": Vector2(4440, 780), "seed": Vector2(4140, 780), "wind": Vector2(4690, 560)},
	"forest": {"slime": Vector2(4080, 780), "seed": Vector2(4410, 660), "wind": Vector2(4720, 510)},
	"ruins": {"slime": Vector2(4420, 780), "seed": Vector2(4680, 780), "wind": Vector2(4070, 540)},
	"festival": {"slime": Vector2(4580, 780), "seed": Vector2(4110, 780), "wind": Vector2(4420, 500)},
}

static func section(mode: String, number: int, route: String) -> int:
	return 2 if mode == JourneyRoutePlan.MODE and number in [2, 4, 6, 8] and TITLES.has(route) else 1

static func platforms(route: String) -> Array[Rect2]:
	match route:
		"wind": return WIND.duplicate()
		"forest": return FOREST.duplicate()
		"ruins": return RUINS.duplicate()
		"festival": return FESTIVAL.duplicate()
	return []

static func wave(route: String, number: int) -> Dictionary:
	return (WAVE_ONE if number == 1 else WAVE_TWO).get(route, {}).duplicate(true)

static func objective(route: String, index: int) -> String:
	if index == 0: return String(TITLES[route]) + " 입구까지 전진"
	if index == 2: return String(DESCRIPTIONS[route]) + " 건너기"
	if index == 1: return "슬라임·원거리 적·공중 정령 혼합 전투"
	if index == 3: return "수관 발판 위 적과 공중 정령 처치" if route == "forest" else "양쪽 적과 공중 정령 처치"
	return "두 번째 구간의 정예 처치"
