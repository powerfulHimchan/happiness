class_name AchievementArt
extends RefCounted

## GP-598–607: display-only hall and nine achievement emblems.
const BACKDROP := preload("res://assets/achievements/honors_hall.svg")
const ICONS := {
	"exploration": preload("res://assets/achievements/exploration.svg"),
	"vocation": preload("res://assets/achievements/vocation.svg"),
	"weapon": preload("res://assets/achievements/weapon.svg"),
	"growth": preload("res://assets/achievements/growth.svg"),
	"ending": preload("res://assets/achievements/ending.svg"),
	"expedition": preload("res://assets/achievements/expedition.svg"),
	"memory": preload("res://assets/achievements/memory.svg"),
	"bond": preload("res://assets/achievements/bond.svg"),
	"secret": preload("res://assets/achievements/secret.svg"),
}
const CATEGORIES := {"탐험":"exploration", "기본 직업":"vocation", "상위 직업":"vocation", "무기 탐구":"weapon", "능력 수집":"growth", "엔딩":"ending", "원정":"expedition", "기억":"memory", "인연":"bond", "비밀":"secret"}

static func symbol(card: Dictionary) -> String:
	return CATEGORIES.get(PermanentAchievements.definition(String(card.id)).get("category", ""), "exploration")

static func regions(rect: Rect2) -> Dictionary:
	var inset := 14.0
	var emblem_size := minf(56.0, rect.size.y * 0.21)
	return {
		"icon": Rect2(rect.position + Vector2(inset, rect.size.y * 0.045), Vector2.ONE * emblem_size),
		"title": Rect2(rect.position + Vector2(inset + emblem_size + 9, rect.size.y * 0.055), Vector2(rect.size.x - inset * 2 - emblem_size - 9, rect.size.y * 0.13)),
		"category": Rect2(rect.position + Vector2(inset + emblem_size + 9, rect.size.y * 0.19), Vector2(rect.size.x - inset * 2 - emblem_size - 9, rect.size.y * 0.07)),
		"status": Rect2(rect.position + Vector2(inset, rect.size.y * 0.29), Vector2(rect.size.x - inset * 2, rect.size.y * 0.08)),
		"details": Rect2(rect.position + Vector2(inset, rect.size.y * 0.42), Vector2(rect.size.x - inset * 2, rect.size.y * 0.36)),
		"bar": Rect2(rect.position + Vector2(inset, rect.size.y * 0.88), Vector2(rect.size.x - inset * 2, rect.size.y * 0.025)),
	}

static func draw_backdrop(ui: Control, safe: Rect2) -> void:
	ui.draw_rect(Rect2(Vector2.ZERO, ui.size), Color("142a3b"))
	ui.draw_texture_rect(BACKDROP, safe, false)
	# Keep the original layout and touch regions; quiet the central text area.
	ui.draw_rect(Rect2(safe.position + safe.size * Vector2(0.04, 0.035), safe.size * Vector2(0.92, 0.18)), Color("142a3b", 0.80))

static func draw_card(ui: Control, card: Dictionary, rect: Rect2) -> void:
	var areas := regions(rect)
	var accent := Color("f4d89a") if card.open else Color("9bb9c4")
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("29474f") if card.open else Color("213642")
	panel.border_color = Color("ffe9ad") if card.selected else Color("8e9b87") if card.open else Color("516b76")
	panel.set_border_width_all(3 if card.selected else 1)
	panel.set_corner_radius_all(8)
	ui.draw_style_box(panel, rect)
	ui.draw_texture_rect(ICONS[symbol(card)], areas.icon, false, Color.WHITE if card.open else Color("a2b0b9"))
	var item := PermanentAchievements.definition(String(card.id))
	var category := String(item.get("category", ""))
	# Advanced jobs share the vocation shield, with a second star on its rim.
	if category == "상위 직업":
		var center: Vector2 = areas.icon.end - Vector2(6, 6)
		ui.draw_circle(center, 8, Color("203743"))
		ui.draw_colored_polygon(PackedVector2Array([center + Vector2(0,-7), center + Vector2(3,-2), center + Vector2(7,0), center + Vector2(3,2), center + Vector2(0,7), center + Vector2(-3,2), center + Vector2(-7,0), center + Vector2(-3,-2)]), accent)
	ui._draw_village_text(String(card.name), areas.title, 24, Color("f5e9cd"))
	ui._draw_village_text(category, areas.category, 15, accent)
	ui._draw_village_text(String(card.status), areas.status, 16, accent)
	for index in card.lines.size():
		var line_rect := Rect2(areas.details.position + Vector2(0, index * areas.details.size.y / 4.0), Vector2(areas.details.size.x, areas.details.size.y / 4.0))
		ui._draw_village_text(String(card.lines[index]), line_rect, 16, Color("d4e0e1"))
	ui.draw_rect(areas.bar, Color("102936"))
	var progress := clampf(float(card.progress) / maxf(1.0, float(card.target)), 0.0, 1.0)
	ui.draw_rect(Rect2(areas.bar.position, Vector2(areas.bar.size.x * progress, areas.bar.size.y)), accent)
	# Text plus shape identifies locked, earned and equipped without color alone.
	var seal: Vector2 = areas.icon.get_center() + Vector2(areas.icon.size.x * 0.38, -areas.icon.size.y * 0.34)
	ui.draw_circle(seal, 8, Color("16303d"))
	if card.selected:
		ui.draw_colored_polygon(PackedVector2Array([seal + Vector2(-5,-4), seal + Vector2(-2,0), seal + Vector2(0,-5), seal + Vector2(2,0), seal + Vector2(5,-4), seal + Vector2(4,5), seal + Vector2(-4,5)]), accent)
	elif card.open:
		ui.draw_polyline(PackedVector2Array([seal + Vector2(-4,0), seal + Vector2(-1,3), seal + Vector2(5,-3)]), accent, 2, true)
	else:
		ui.draw_arc(seal + Vector2(0,-1), 3, PI, TAU, 12, accent, 1.5, true)
		ui.draw_rect(Rect2(seal + Vector2(-4,-1), Vector2(8,6)), accent)
