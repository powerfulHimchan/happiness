class_name StartScreenView
extends RefCounted

## The title screen shares its drawing and hit rectangles with the existing menus.
const TITLE := "행복 동화"
const BACKGROUND: Texture2D = preload("res://assets/title/dawn-road.png")
const SHADE: Texture2D = preload("res://assets/title/menu-shade.tres")
const PAPER := Color("fff9e9")
const GOLD := Color("f8df91")
const INK := Color("173d3c")


static func layout(safe: Rect2, has_checkpoint: bool) -> Dictionary:
	var unit := minf(safe.size.y / 1000.0, safe.size.x / 1550.0)
	var left := safe.position.x + safe.size.x * 0.055
	var width := minf(safe.size.x * 0.29, 540.0 * unit)
	var top := safe.position.y + safe.size.y * 0.44
	var step := 114.0 * unit
	var button_size := Vector2(width, 92.0 * unit)
	var rows := 3 if has_checkpoint else 2
	var links_y := top + rows * step + 10.0 * unit
	var link_gap := 12.0 * unit
	var link_width := (width - link_gap * 2.0) / 3.0
	return {
		"unit": unit,
		"kicker": Rect2(left, safe.position.y + safe.size.y * 0.09, width, 32.0 * unit),
		"title": Rect2(left, safe.position.y + safe.size.y * 0.14, width, 115.0 * unit),
		"subtitle": Rect2(left, safe.position.y + safe.size.y * 0.27, width, 42.0 * unit),
		"continue": Rect2(Vector2(left, top), button_size) if has_checkpoint else Rect2(),
		"start": Rect2(Vector2(left, top + (step if has_checkpoint else 0.0)), button_size),
		"village": Rect2(Vector2(left, top + step * (2 if has_checkpoint else 1)), button_size),
		"journal": Rect2(left, links_y, link_width, 66.0 * unit),
		"settings": Rect2(left + link_width + link_gap, links_y, link_width, 66.0 * unit),
		"controls": Rect2(left + (link_width + link_gap) * 2.0, links_y, link_width, 66.0 * unit),
		"notice": Rect2(left, safe.end.y - 78.0 * unit, width, 32.0 * unit),
		"progress": Rect2(left, safe.end.y - 40.0 * unit, width, 28.0 * unit),
	}


static func draw(canvas: Control) -> void:
	var full := Rect2(Vector2.ZERO, canvas.size)
	var image_size := BACKGROUND.get_size()
	var scale := maxf(canvas.size.x / image_size.x, canvas.size.y / image_size.y)
	var source_size := canvas.size / scale
	canvas.draw_texture_rect_region(BACKGROUND, full, Rect2((image_size - source_size) * 0.5, source_size))
	canvas.draw_texture_rect(SHADE, full, false)
	var boxes := layout(canvas._safe_area_in_viewport(), canvas.checkpoint_available)
	var unit: float = boxes.unit
	_text(canvas, "H A P P I N E S S   T A L E", boxes.kicker, int(22 * unit), GOLD)
	_text(canvas, TITLE, boxes.title, int(96 * unit), PAPER)
	_text(canvas, "Rewind to Dawn", boxes.subtitle, int(30 * unit), PAPER)
	if canvas.checkpoint_available:
		_button(canvas, canvas.main_continue_rect, "이어하기", true, unit)
	_button(canvas, canvas.main_start_rect, "새 도전", not canvas.checkpoint_available, unit)
	_button(canvas, canvas.main_village_rect, "시간의 닻 마을", false, unit)
	_link(canvas, canvas.story_journal_open_rect, "기억 수첩", unit)
	_link(canvas, canvas.main_feedback_rect, "설정", unit)
	_link(canvas, canvas.main_layout_rect, "조작 배치", unit)
	var notice := "마지막 여정이 기다리고 있어요" if canvas.checkpoint_available else "다시, 새벽을 향해"
	if not canvas.checkpoint_message.is_empty():
		notice = canvas.checkpoint_message
	elif not canvas.pending_boss_legacy.is_empty():
		notice = BossLegacyStore.description(String(canvas.pending_boss_legacy.get("choice", "")))
	_text(canvas, notice, boxes.notice, int(21 * unit), PAPER)
	var progress := "칭호 · " + PermanentAchievements.title_name(canvas.achievement_state) if not String(canvas.achievement_state.get("title", "")).is_empty() else "영구 업적 %d/50 · 광장 기록에서 확인" % PermanentAchievements.earned_count(canvas.achievement_state)
	_text(canvas, progress, boxes.progress, int(19 * unit), Color("d5e2d8"))


static func _button(canvas: Control, rect: Rect2, label: String, primary: bool, unit: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = GOLD if primary else Color(0.06, 0.17, 0.15, 0.91)
	style.border_color = GOLD if primary else Color(1.0, 0.98, 0.91, 0.45)
	style.set_border_width_all(maxi(1, int(2 * unit)))
	style.set_corner_radius_all(int(16 * unit))
	canvas.draw_style_box(style, rect)
	var inset := Vector2(30 * unit, 0)
	_text(canvas, label, Rect2(rect.position + inset, rect.size - inset * 2), int(32 * unit), INK if primary else PAPER)
	if primary:
		canvas._draw_text_centered("→", Rect2(rect.end.x - 72 * unit, rect.position.y, 56 * unit, rect.size.y), int(36 * unit), INK)


static func _link(canvas: Control, rect: Rect2, label: String, unit: float) -> void:
	canvas._draw_village_text(label, rect, int(24 * unit), PAPER)


static func _text(canvas: Control, value: String, rect: Rect2, requested_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var font_size := requested_size
	while font_size > 12 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x:
		font_size -= 1
	var baseline := rect.position + Vector2(0, (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	canvas._draw_text(value, baseline, font_size, color)
