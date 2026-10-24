class_name RelicArt
extends RefCounted

## GP-608–617: original vector illustrations, shared by rewards and the codex.
## Drawing only: no reward selection, combat effects, timers or saved state.
const ICONS := {
	"phoenix_feather": preload("res://assets/relics/phoenix_feather.svg"),
	"clock_fragment": preload("res://assets/relics/clock_fragment.svg"),
	"spring_dew": preload("res://assets/relics/spring_dew.svg"),
	"dawn_ember": preload("res://assets/relics/dawn_ember.svg"),
	"hourglass": preload("res://assets/relics/hourglass.svg"),
	"guardian_seal": preload("res://assets/relics/guardian_seal.svg"),
	"wind_knot": preload("res://assets/relics/wind_knot.svg"),
	"vital_seed": preload("res://assets/relics/vital_seed.svg"),
	"duelist_emblem": preload("res://assets/relics/duelist_emblem.svg"),
	"arcane_emblem": preload("res://assets/relics/arcane_emblem.svg"),
}

static func supports(id: String) -> bool:
	return ICONS.has(id)

static func reward_region(rect: Rect2) -> Rect2:
	var side := minf(128.0, minf(rect.size.x - 28.0, rect.size.y * 0.32))
	return Rect2(rect.position + rect.size * Vector2(0.5, 0.37) - Vector2.ONE * side * 0.5, Vector2.ONE * side)

static func codex_regions(rect: Rect2, line_count: int) -> Dictionary:
	var side := minf(72.0, rect.size.y * 0.25)
	var inset := 14.0
	var title_left := inset + side + 8.0
	var regions := {
		"icon": Rect2(rect.position + Vector2(inset, rect.size.y * 0.045), Vector2.ONE * side),
		"title": Rect2(rect.position + Vector2(title_left, rect.size.y * 0.10), Vector2(rect.size.x - title_left - inset, rect.size.y * 0.13)),
		"status": Rect2(rect.position + Vector2(inset, rect.size.y * 0.33), Vector2(rect.size.x - inset * 2, rect.size.y * 0.08)),
	}
	var line_height := rect.size.y * 0.46 / maxi(6, line_count)
	for index in line_count:
		regions["line_" + str(index)] = Rect2(rect.position + Vector2(inset, rect.size.y * 0.45 + index * line_height), Vector2(rect.size.x - inset * 2, line_height - 1.0))
	return regions

static func draw_reward(ui: Control, id: String, rect: Rect2) -> void:
	var region := reward_region(rect)
	ui.draw_circle(region.get_center(), region.size.x * 0.48, Color("d3c58e", 0.06))
	ui.draw_texture_rect(ICONS[id], region, false)

static func draw_codex_card(ui: Control, card: Dictionary, rect: Rect2) -> void:
	var areas := codex_regions(rect, card.lines.size())
	var used := String(card.status).contains("사용 완료")
	ui.draw_texture_rect(ICONS[card.id], areas.icon, false, Color("a5afb3") if used else Color.WHITE)
	ui._draw_village_text(String(card.name), areas.title, 26, ui.TEXT_COLOR)
	ui._draw_village_text(String(card.status), areas.status, 17, ui.ACTIVE_COLOR if card.open else ui.MUTED_TEXT_COLOR)
	for index in card.lines.size():
		ui._draw_village_text(String(card.lines[index]), areas["line_" + str(index)], 18, ui.TEXT_COLOR)
	if card.open:
		var seal: Vector2 = areas.icon.end - Vector2(7, 7)
		ui.draw_circle(seal, 9, Color("183340"))
		if used:
			ui.draw_arc(seal, 5, 0, TAU, 20, ui.MUTED_TEXT_COLOR, 1.5, true)
			ui.draw_line(seal + Vector2(-3, 3), seal + Vector2(3, -3), ui.MUTED_TEXT_COLOR, 2, true)
		else:
			ui.draw_polyline(PackedVector2Array([seal + Vector2(-5, 0), seal + Vector2(-1, 4), seal + Vector2(5, -4)]), ui.ACTIVE_COLOR, 2, true)
