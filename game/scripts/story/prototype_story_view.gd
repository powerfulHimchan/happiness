class_name PrototypeStoryView
extends RefCounted

const SERA_PORTRAIT := preload("res://assets/prototype_sera.svg")
const HEART_PORTRAIT := preload("res://assets/heart_threshold.svg")

static func wrap(value: String, font: Font, font_size: int, width: float) -> Array[String]:
	var lines: Array[String] = []
	var line := ""
	for character in value:
		if not line.is_empty() and font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			lines.append(line)
			line = ""
		line += character
	if not line.is_empty(): lines.append(line)
	return lines

static func scene_layout(safe: Rect2) -> Dictionary:
	return {
		"portrait": Rect2(safe.position + safe.size * Vector2(0.06, 0.27), safe.size * Vector2(0.20, 0.35)),
		"speaker": Rect2(safe.position + safe.size * Vector2(0.05, 0.65), safe.size * Vector2(0.22, 0.07)),
		"paragraphs": [Rect2(safe.position + safe.size * Vector2(0.30, 0.26), safe.size * Vector2(0.64, 0.20)), Rect2(safe.position + safe.size * Vector2(0.30, 0.50), safe.size * Vector2(0.64, 0.20))],
		"next": Rect2(safe.position + safe.size * Vector2(0.53, 0.86), safe.size * Vector2(0.40, 0.09)),
		"skip": Rect2(safe.position + safe.size * Vector2(0.07, 0.86), safe.size * Vector2(0.40, 0.09)),
	}

static func journal_layout(safe: Rect2, count: int) -> Dictionary:
	var cards: Array[Rect2] = []
	var gap := safe.size.x * 0.025
	var width := (safe.size.x * 0.90 - gap * 2) / 3.0
	for i in count: cards.append(Rect2(safe.position + Vector2(safe.size.x * 0.05 + i * (width + gap), safe.size.y * 0.30), Vector2(width, safe.size.y * 0.43)))
	var tabs: Array[Rect2] = []
	for i in 3: tabs.append(Rect2(safe.position + Vector2(safe.size.x * 0.05 + i * (width + gap), safe.size.y * 0.18), Vector2(width, safe.size.y * 0.075)))
	return {"cards": cards, "tabs": tabs, "previous": Rect2(safe.position + safe.size * Vector2(0.05, 0.77), safe.size * Vector2(0.24, 0.065)), "next": Rect2(safe.position + safe.size * Vector2(0.71, 0.77), safe.size * Vector2(0.24, 0.065)), "back": Rect2(safe.position + safe.size * Vector2(0.05, 0.87), safe.size * Vector2(0.43, 0.075)), "retry": Rect2(safe.position + safe.size * Vector2(0.52, 0.87), safe.size * Vector2(0.43, 0.075))}
