class_name StartScreenView
extends RefCounted

## Texture lettering, shared visual/input geometry, and read-only ambience.
const TITLE := "다시 피는 새벽"
const BACKGROUND: Texture2D = StartScreenBackdrop.BACKGROUND
const SHADE: Texture2D = preload("res://assets/title/menu-shade.tres")
const TITLE_ART: Texture2D = preload("res://assets/title/lettering/dawn-title.svg")
const SUBTITLE: Texture2D = preload("res://assets/title/lettering/subtitle.svg")
const WORDS := {
	"continue": preload("res://assets/title/lettering/continue.svg"),
	"start": preload("res://assets/title/lettering/new-journey.svg"),
	"village": preload("res://assets/title/lettering/village.svg"),
	"journal": preload("res://assets/title/lettering/journal.svg"),
	"settings": preload("res://assets/title/lettering/settings.svg"),
}
const PAPER := Color("fff9e9")
const GOLD := Color("f8df91")


static func word_size(id: String, height: float) -> Vector2:
	var texture: Texture2D = WORDS[id]
	return texture.get_size() * height / texture.get_height()


static func layout(safe: Rect2, has_checkpoint: bool) -> Dictionary:
	var unit := minf(safe.size.y / 1000.0, safe.size.x / 1550.0)
	var left := safe.position.x + safe.size.x * 0.055
	var width := minf(safe.size.x * 0.35, 650.0 * unit)
	var top := safe.position.y + safe.size.y * 0.44
	var step := 114.0 * unit
	var rows := 3 if has_checkpoint else 2
	var links_y := top + rows * step + 6.0 * unit
	var boxes := {
		"unit": unit,
		"title": Rect2(left - 24.0 * unit, safe.position.y + safe.size.y * 0.055, width, 326.0 * unit),
		"subtitle": Rect2(left + 45.0 * unit, safe.position.y + safe.size.y * 0.355, width * 0.70, 42.0 * unit),
		"continue": Rect2(),
		"controls": Rect2(),
		"notice": Rect2(left, safe.end.y - 78.0 * unit, width, 32.0 * unit),
		"progress": Rect2(left, safe.end.y - 40.0 * unit, width, 28.0 * unit),
	}
	var ids := ["start", "village"]
	if has_checkpoint:
		ids.push_front("continue")
	for index in ids.size():
		var extent := word_size(ids[index], 90.0 * unit)
		boxes[ids[index]] = Rect2(Vector2(left, top + step * index), extent + Vector2(32.0, 16.0) * unit)
	boxes.journal = Rect2(Vector2(left, links_y), word_size("journal", 52.0 * unit) + Vector2(24.0, 20.0) * unit)
	boxes.settings = Rect2(Vector2(boxes.journal.end.x + 54.0 * unit, links_y), word_size("settings", 52.0 * unit) + Vector2(24.0, 20.0) * unit)
	return boxes


static func draw(canvas: Control) -> void:
	canvas.start_backdrop.draw_motes(canvas)
	canvas.draw_texture_rect(SHADE, Rect2(Vector2.ZERO, canvas.size), false)
	var boxes := layout(canvas._safe_area_in_viewport(), canvas.checkpoint_available)
	var unit: float = boxes.unit
	_title(canvas, boxes)
	if canvas.checkpoint_available:
		_word(canvas, boxes["continue"], "continue", true, unit)
	_word(canvas, boxes.start, "start", not canvas.checkpoint_available, unit)
	_word(canvas, boxes.village, "village", false, unit)
	_word(canvas, boxes.journal, "journal", false, unit, true)
	_word(canvas, boxes.settings, "settings", false, unit, true)
	var notice := "마지막 여정이 기다리고 있어요" if canvas.checkpoint_available else "다시, 새벽을 향해"
	if not canvas.checkpoint_message.is_empty():
		notice = canvas.checkpoint_message
	elif not canvas.pending_boss_legacy.is_empty():
		notice = BossLegacyStore.description(String(canvas.pending_boss_legacy.get("choice", "")))
	_text(canvas, notice, boxes.notice, int(21 * unit), PAPER)
	var progress := "칭호 · " + PermanentAchievements.title_name(canvas.achievement_state) if not String(canvas.achievement_state.get("title", "")).is_empty() else "영구 업적 %d/%d · 광장 기록에서 확인" % [PermanentAchievements.earned_count(canvas.achievement_state), PermanentAchievements.DEFINITIONS.size()]
	_text(canvas, progress, boxes.progress, int(19 * unit), Color("d5e2d8"))


static func _title(canvas: Control, boxes: Dictionary) -> void:
	canvas.draw_texture_rect(TITLE_ART, _fitted(TITLE_ART, boxes.title), false)
	canvas.draw_texture_rect(SUBTITLE, _fitted(SUBTITLE, boxes.subtitle), false, PAPER)


static func _fitted(texture: Texture2D, area: Rect2) -> Rect2:
	var factor := minf(area.size.x / texture.get_width(), area.size.y / texture.get_height())
	var extent := texture.get_size() * factor
	return Rect2(area.get_center() - extent * 0.5, extent)


static func _word(canvas: Control, hit: Rect2, id: String, primary: bool, unit: float, small := false) -> void:
	var extent := word_size(id, (52.0 if small else 90.0) * unit)
	var art := Rect2(hit.get_center() - extent * 0.5, extent)
	var shadow := art
	shadow.position += Vector2(0, 2.5) * unit
	canvas.draw_texture_rect(WORDS[id], shadow, false, Color(0.015, 0.08, 0.08, 0.9))
	canvas.draw_texture_rect(WORDS[id], art, false, GOLD if primary else PAPER)
	if primary:
		var center := Vector2(hit.position.x - 24.0 * unit, hit.get_center().y)
		var radius := 10.0 * unit
		canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]), GOLD)


static func _text(canvas: Control, value: String, rect: Rect2, requested_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var font_size := requested_size
	while font_size > 12 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x:
		font_size -= 1
	var baseline := rect.position + Vector2(0, (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	canvas._draw_text(value, baseline, font_size, color)
