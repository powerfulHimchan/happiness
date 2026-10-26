class_name WeaponPreparationArt
extends RefCounted

## Texture assets only; neither drawing nor inspection changes equipment.
const WEAPONS := {
	"sword":preload("res://assets/preparation/weapons/sword.svg"),
	"bow":preload("res://assets/preparation/weapons/bow.svg"),
	"fist":preload("res://assets/preparation/weapons/fist.svg"),
	"staff":preload("res://assets/preparation/weapons/staff.svg"),
	"polearm":preload("res://assets/preparation/weapons/polearm.svg"),
	"shield":preload("res://assets/preparation/weapons/shield.svg"),
}
const FIST_PAIR := preload("res://assets/preparation/weapons/fist-pair.svg")
const SKILLS := {
	"sword_dash":preload("res://assets/preparation/skills/sword_dash.svg"),
	"sword_spin":preload("res://assets/preparation/skills/sword_spin.svg"),
	"bow_piercing":preload("res://assets/preparation/skills/bow_piercing.svg"),
	"bow_arrow_rain":preload("res://assets/preparation/skills/bow_arrow_rain.svg"),
	"fist_dash":preload("res://assets/preparation/skills/fist_dash.svg"),
	"fist_flurry":preload("res://assets/preparation/skills/fist_flurry.svg"),
	"staff_fireball":preload("res://assets/preparation/skills/staff_fireball.svg"),
	"staff_ice_lance":preload("res://assets/preparation/skills/staff_ice_lance.svg"),
	"polearm_sweep":preload("res://assets/preparation/skills/polearm_sweep.svg"),
	"polearm_thrust":preload("res://assets/preparation/skills/polearm_thrust.svg"),
	"shield_guard":preload("res://assets/preparation/skills/shield_guard.svg"),
	"shield_counter":preload("res://assets/preparation/skills/shield_counter.svg"),
}
const WORDS := {
	"heading":preload("res://assets/preparation/weapon-lettering/heading.svg"),
	"hero":preload("res://assets/preparation/weapon-lettering/hero.svg"),
	"settings":preload("res://assets/preparation/weapon-lettering/settings.svg"),
	"back":preload("res://assets/preparation/weapon-lettering/back.svg"),
	"return":preload("res://assets/preparation/weapon-lettering/return.svg"),
	"start":preload("res://assets/preparation/weapon-lettering/start.svg"),
	"backup":preload("res://assets/preparation/weapon-lettering/backup.svg"),
	"backup-selected":preload("res://assets/preparation/weapon-lettering/backup-selected.svg"),
	"primary":preload("res://assets/preparation/weapon-lettering/primary.svg"),
	"close":preload("res://assets/preparation/weapon-lettering/close.svg"),
	"sword":preload("res://assets/preparation/weapon-lettering/sword.svg"),
	"bow":preload("res://assets/preparation/weapon-lettering/bow.svg"),
	"fist":preload("res://assets/preparation/weapon-lettering/fist.svg"),
	"staff":preload("res://assets/preparation/weapon-lettering/staff.svg"),
	"polearm":preload("res://assets/preparation/weapon-lettering/polearm.svg"),
	"shield":preload("res://assets/preparation/weapon-lettering/shield.svg"),
	"sword_dash":preload("res://assets/preparation/weapon-lettering/sword_dash.svg"),
	"sword_spin":preload("res://assets/preparation/weapon-lettering/sword_spin.svg"),
	"bow_piercing":preload("res://assets/preparation/weapon-lettering/bow_piercing.svg"),
	"bow_arrow_rain":preload("res://assets/preparation/weapon-lettering/bow_arrow_rain.svg"),
	"fist_dash":preload("res://assets/preparation/weapon-lettering/fist_dash.svg"),
	"fist_flurry":preload("res://assets/preparation/weapon-lettering/fist_flurry.svg"),
	"staff_fireball":preload("res://assets/preparation/weapon-lettering/staff_fireball.svg"),
	"staff_ice_lance":preload("res://assets/preparation/weapon-lettering/staff_ice_lance.svg"),
	"polearm_sweep":preload("res://assets/preparation/weapon-lettering/polearm_sweep.svg"),
	"polearm_thrust":preload("res://assets/preparation/weapon-lettering/polearm_thrust.svg"),
	"shield_guard":preload("res://assets/preparation/weapon-lettering/shield_guard.svg"),
	"shield_counter":preload("res://assets/preparation/weapon-lettering/shield_counter.svg"),
}

static func word(ui: Control, id: String, area: Rect2, color: Color, shadow := false) -> void:
	var rect := SupplyShopArt.fitted(WORDS[id], area)
	if shadow:
		var dark := rect
		dark.position += Vector2(0, 2) * ui.size.y / 1080.0
		ui.draw_texture_rect(WORDS[id], dark, false, Color(.025, .10, .12, .85))
	ui.draw_texture_rect(WORDS[id], rect, false, color)

static func weapon(ui: Control, family: String, area: Rect2) -> void:
	var texture: Texture2D = FIST_PAIR if family == "fist" else WEAPONS[family]
	var angle := -PI * .5 if family == "bow" else .85 if family == "staff" else 0.0
	var natural := texture.get_size()
	var bounds := Vector2(absf(cos(angle)) * natural.x + absf(sin(angle)) * natural.y, absf(sin(angle)) * natural.x + absf(cos(angle)) * natural.y)
	var extent := natural * minf(area.size.x / bounds.x, area.size.y / bounds.y)
	ui.draw_set_transform(area.get_center(), angle)
	ui.draw_texture_rect(texture, Rect2(-extent * .5, extent), false)
	ui.draw_set_transform(Vector2.ZERO)

static func text(ui: Control, value: String, area: Rect2, font_size: int, color: Color, centered := true) -> void:
	if centered:
		ui._draw_village_text(value, area, font_size, color)
		return
	var size := mini(font_size, int(area.size.y * .9))
	var font := ThemeDB.fallback_font
	while size > 10 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > area.size.x: size -= 1
	ui._draw_text(value, area.position + Vector2(0, (area.size.y + font.get_ascent(size) - font.get_descent(size)) * .5), size, color)
