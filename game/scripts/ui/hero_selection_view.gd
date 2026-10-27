class_name HeroSelectionView
extends RefCounted

## Two portraits first; one portrait + read-only profile after an explicit choice.
const INK := Color("123d49")
const PAPER := Color("fff9e9")
const SHADE := preload("res://assets/preparation/hero-detail-shade.svg")
const ART := {
	"heading": preload("res://assets/preparation/lettering/heading.svg"),
	"back": preload("res://assets/preparation/lettering/back.svg"),
	"reselect": preload("res://assets/preparation/lettering/reselect.svg"),
	"next": preload("res://assets/preparation/lettering/next.svg"),
	"roan": preload("res://assets/preparation/lettering/roan.svg"),
	"lumi": preload("res://assets/preparation/lettering/lumi.svg"),
	"journal": StartScreenView.WORDS.journal,
}
const STAT_IDS := ["health", "attack", "defense", "critical_chance", "critical_damage", "attack_speed"]
const STAT_LABELS := ["체력", "공격력", "방어력", "치명타 확률", "치명타 피해", "공격 속도"]
static var _story_cache: Dictionary = {}

static func box(safe: Rect2, x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(safe.position + safe.size * Vector2(x, y), safe.size * Vector2(w, h))

static func layout(safe: Rect2, detail: bool = false) -> Dictionary:
	var unit := safe.size.y / 1080.0
	var cards: Array[Rect2] = []
	for index in 2:
		var bounds := box(safe, 0.065 + index * 0.50, 0.15, 0.37, 0.71)
		cards.append(SupplyShopArt.fitted(PrototypeCharacters.texture(PrototypeCharacters.IDS[index]), bounds).grow(8 * unit) if not detail else Rect2())
	return {
		"cards": cards,
		"back": _word_hit("reselect" if detail else "back", box(safe, .035, .90, .23, .07), unit),
		"confirm": _word_hit("next", box(safe, .73, .90, .24, .07), unit) if detail else Rect2(),
		"story": Rect2(),
		"journal": _word_hit("journal", box(safe, .81, .035, .16, .07), unit),
		"heading": box(safe, .285, .022, .43, .11),
		"portrait": box(safe, .015, .15, .36, .71),
		"name": box(safe, .44, .17, .48, .10),
		"trait_icon": box(safe, .44, .295, .065, .115),
		"trait_name": box(safe, .52, .288, .44, .043),
		"trait_effect": box(safe, .52, .34, .44, .037),
		"trait_cooldown": box(safe, .52, .38, .44, .033),
		"story_heading": box(safe, .44, .445, .51, .04),
		"biography": box(safe, .44, .50, .52, .245),
		"stats_heading": box(safe, .44, .765, .52, .04),
		"stats": box(safe, .44, .815, .52, .06),
	}

static func _word_hit(id: String, area: Rect2, unit: float) -> Rect2:
	var art := SupplyShopArt.fitted(ART[id], area.grow(-8 * unit))
	return Rect2(art.get_center() - Vector2(art.size.x + 20 * unit, maxf(66 * unit, art.size.y + 16 * unit)) * .5, Vector2(art.size.x + 20 * unit, maxf(66 * unit, art.size.y + 16 * unit)))

static func _word(ui: Control, id: String, area: Rect2, color: Color, shadow := false) -> void:
	var rect := SupplyShopArt.fitted(ART[id], area)
	if shadow:
		var shade := rect
		shade.position += Vector2(0, 2) * ui.size.y / 1080.0
		ui.draw_texture_rect(ART[id], shade, false, Color(.03, .10, .12, color.a * .9))
	ui.draw_texture_rect(ART[id], rect, false, color)

static func biography_layout(safe: Rect2, id: String) -> Dictionary:
	var rect: Rect2 = layout(safe, true).biography
	var unit := safe.size.y / 1080.0
	var font := ThemeDB.fallback_font
	var cache_key := "%s:%s:%s" % [id, safe, font.get_rid()]
	if _story_cache.has(cache_key):
		return _story_cache[cache_key]
	var size := int(27 * unit)
	var lines := PrototypeStoryView.wrap(PrototypeCharacters.biography(id), font, size, rect.size.x)
	while size > int(19 * unit) and lines.size() * (font.get_height(size) + 3 * unit) > rect.size.y:
		size -= 1
		lines = PrototypeStoryView.wrap(PrototypeCharacters.biography(id), font, size, rect.size.x)
	var result := {"rect": rect, "font_size": size, "lines": lines, "line_height": font.get_height(size) + 3 * unit}
	if _story_cache.size() >= 16:
		_story_cache.clear()
	_story_cache[cache_key] = result
	return result

static func draw(ui: Control) -> void:
	var backdrop := StartScreenView.BACKGROUND
	var cover := maxf(ui.size.x / backdrop.get_width(), ui.size.y / backdrop.get_height())
	var source := ui.size / cover
	ui.draw_texture_rect_region(backdrop, Rect2(Vector2.ZERO, ui.size), Rect2((backdrop.get_size() - source) * .5, source))
	var safe: Rect2 = ui._safe_area_in_viewport()
	var view := layout(safe, ui.character_detail_open)
	var unit := safe.size.y / 1080.0
	_word(ui, "heading", view.heading, INK)
	var fade: float = smoothstep(0.0, 1.0, ui.character_reveal_progress) if ui.character_detail_open else 0.0
	for index in 2:
		var id: String = PrototypeCharacters.IDS[index]
		var texture := PrototypeCharacters.texture(id)
		var initial := box(safe, .065 + index * .50, .15, .37, .71)
		var selected: bool = ui.character_detail_open and ui.selected_character_id == id
		var bounds: Rect2 = Rect2(initial.position.lerp(view.portrait.position, fade), initial.size.lerp(view.portrait.size, fade)) if selected else initial
		var alpha: float = 1.0 if not ui.character_detail_open or selected else 1.0 - fade
		if alpha > 0:
			ui.hero_selection_motion.draw(ui, id, bounds, alpha)
	if ui.character_detail_open:
		ui.draw_texture_rect(SHADE, box(safe, .39, .125, .605, .775), false, Color(1, 1, 1, fade))
		_detail(ui, safe, view, fade)
	# Footer legibility, with no button panels or obsolete trait notice.
	ui.draw_rect(box(safe, 0, .895, 1, .105), Color(.035, .12, .13, .20))
	_word(ui, "reselect" if ui.character_detail_open else "back", ui.character_cancel_rect.grow(-8 * unit), PAPER, true)
	_word(ui, "journal", ui.story_journal_open_rect.grow(-8 * unit), PAPER, true)
	if ui.character_detail_open:
		_word(ui, "next", ui.character_confirm_rect.grow(-8 * unit), Color("ffe3a3"), true)

static func _detail(ui: Control, safe: Rect2, view: Dictionary, alpha: float) -> void:
	var unit := safe.size.y / 1080.0
	var id: String = ui.selected_character_id
	var ink := Color(INK, alpha)
	var name_area: Rect2 = view.name
	var texture: Texture2D = ART[id]
	var name_size := texture.get_size() * minf(name_area.size.y / texture.get_height(), name_area.size.x / texture.get_width())
	_word(ui, id, Rect2(name_area.position, name_size), ink)
	ui.draw_texture_rect(HeroStatusArt.ICONS[id], SupplyShopArt.fitted(HeroStatusArt.ICONS[id], view.trait_icon), false, Color(1, 1, 1, alpha))
	var passive := PrototypeCharacters.trait_profile(id)
	_text(ui, String(passive.name), view.trait_name, int(35 * unit), ink)
	_text(ui, String(passive.lines[0]) if id == "roan" else "무기 전환 후 다음 1타 확정 치명타", view.trait_effect, int(26 * unit), ink)
	_text(ui, "재발동 6초 · 모든 무기" if id == "roan" else "유효 적중 1회 · 재발동 8초", view.trait_cooldown, int(24 * unit), ink)
	_text(ui, "이야기", view.story_heading, int(31 * unit), ink)
	var story := biography_layout(safe, id)
	var y: float = story.rect.position.y + ThemeDB.fallback_font.get_ascent(story.font_size)
	for line in story.lines:
		ui._draw_text(line, Vector2(story.rect.position.x, y), story.font_size, ink)
		y += story.line_height
	_text(ui, "최초 전투 능력치", view.stats_heading, int(30 * unit), ink)
	var stats := PrototypeCharacters.initial_combat_stats()
	for index in STAT_IDS.size():
		var cell := Rect2(view.stats.position + Vector2(view.stats.size.x * index / 6.0, 0), Vector2(view.stats.size.x / 6.0, view.stats.size.y))
		var icon := Rect2(cell.position, Vector2(36, 42) * unit)
		ui.draw_texture_rect(HeroStatusArt.ICONS[STAT_IDS[index]], SupplyShopArt.fitted(HeroStatusArt.ICONS[STAT_IDS[index]], icon), false, Color(1, 1, 1, alpha))
		var body := Rect2(cell.position + Vector2(41 * unit, -5 * unit), cell.size - Vector2(43 * unit, 0))
		_text(ui, "체력" if index == 0 else String(STAT_LABELS[index]), Rect2(body.position, body.size * Vector2(1, .45)), int(22 * unit), ink)
		var value := "%d%%" % int(stats[STAT_IDS[index]]) if index > 2 else str(stats[STAT_IDS[index]])
		_text(ui, value, Rect2(body.position + Vector2(0, body.size.y * .45), body.size * Vector2(1, .6)), int(31 * unit), ink)

static func _text(ui: Control, value: String, rect: Rect2, requested: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var size := mini(requested, int(rect.size.y * .9))
	while size > 10 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > rect.size.x:
		size -= 1
	ui._draw_text(value, rect.position + Vector2(0, (rect.size.y + font.get_ascent(size) - font.get_descent(size)) * .5), size, color)
