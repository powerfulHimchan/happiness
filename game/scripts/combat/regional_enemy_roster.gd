class_name RegionalEnemyRoster
extends RefCounted

## Approved region roster. Repeated actors within one region share a species;
## no species is reused across the six journey regions.
const NAMES := {
	"rabbit": "바람뿔 토끼", "bird": "민들레 새", "moth": "포자 나방",
	"rewind_doll": "되감기 인형", "clown": "풍선 광대",
	"mask_guard": "미소 가면 경비병", "parade_doll": "행복 행렬 인형",
	"vine_hunter": "덩굴 사냥꾼", "clock_sentry": "시곗바늘 파수꾼", "drummer": "태엽 북장이",
}
const REGULAR := {
	"wind": ["slime", "rabbit", "wind_spirit"],
	"forest": ["moth", "seed_sack", "moth"],
	"ruins": ["rewind_doll", "clock_doll", "rewind_doll"],
	"festival": ["soldier", "turret", "clown"],
	"city_gate": ["mask_guard", "mask_guard", "mask_guard"],
	"city_core": ["parade_doll", "parade_doll", "parade_doll"],
}
const ELITES := {"wind": "boar", "forest": "vine_hunter", "ruins": "clock_sentry", "festival": "drummer", "city_gate": "mask_guard", "city_core": "parade_doll"}

static func region(route: String) -> String:
	return "wind" if route in ["meadow", "clockwork"] else route

static func regular_id(route: String, slot: int, wave: int = 1) -> String:
	var key := region(route)
	if key == "wind" and slot == 2 and wave == 2: return "bird"
	return String(REGULAR.get(key, REGULAR.wind)[clampi(slot, 0, 2)])

static func texture(id: String) -> Texture2D:
	return load("res://assets/enemies/%s.svg" % id) as Texture2D if NAMES.has(id) else null

static func is_custom(id: String) -> bool:
	return id in ["rabbit", "bird", "moth", "rewind_doll", "clown", "mask_guard", "parade_doll"]
