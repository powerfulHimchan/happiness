class_name WeaponFamilyPresentation
extends RefCounted

## Vector equipment and event-driven effects. This layer never changes combat state.
const TEXTURES := {
	"fist": preload("res://assets/weapons/fist.svg"),
	"staff": preload("res://assets/weapons/staff.svg"),
	"polearm": preload("res://assets/weapons/polearm.svg"),
	"shield": preload("res://assets/weapons/shield.svg"),
}
const COLORS := {"fist": Color("ffcd82"), "staff": Color("d4b7ff"), "polearm": Color("a8ebc1"), "shield": Color("a9dfff")}

const MOTIFS := {
	"striker": preload("res://assets/weapons/motif_striker.svg"),
	"weaver": preload("res://assets/weapons/motif_weaver.svg"),
	"balanced": preload("res://assets/weapons/motif_balanced.svg"),
}

static func appearance(family: String, grade: int, design: String = "") -> Dictionary:
	var item := PrototypeWeaponRewards.profile(family, grade, design)
	if item.is_empty(): return {}
	var motif := design.get_slice("_",0) if design in PrototypeWeaponRewards.EXPANSION_DESIGNS else ""
	var accent: Color = {"striker": Color("ffd18b"), "weaver": Color("d2bcff"), "balanced": Color("b6edc4")}.get(motif,COLORS.get(family,Color.WHITE))
	var tint := Color("97a6ad") if grade == 0 else Color("d4eafa") if grade == 1 else Color("ffe1a4")
	return {"family": family, "grade": grade, "design": design, "motif": motif, "accent": accent, "tint": tint}

static func _draw_badge(canvas: CanvasItem, center: Vector2, look: Dictionary, size_px: float) -> void:
	if look.grade > 0:
		var color := Color("c9e6ff") if look.grade == 1 else Color("ffe39a")
		canvas.draw_arc(center, size_px*.6, 0, TAU, 24, color, 2, true)
		if look.grade == 2:
			canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(-size_px*.65,-size_px*.7),center+Vector2(-size_px*.3,-size_px*.48),center+Vector2(0,-size_px),center+Vector2(size_px*.3,-size_px*.48),center+Vector2(size_px*.65,-size_px*.7),center+Vector2(size_px*.45,-size_px*.2),center+Vector2(-size_px*.45,-size_px*.2)]),color)
	if MOTIFS.has(look.motif):
		canvas.draw_texture_rect(MOTIFS[look.motif],Rect2(center-Vector2.ONE*size_px*.5,Vector2.ONE*size_px),false)

static func draw_icon(canvas: CanvasItem, family: String, grade: int, design: String, area: Rect2) -> void:
	if not TEXTURES.has(family): return
	var look := appearance(family,grade,design)
	if look.is_empty(): return
	var texture: Texture2D = TEXTURES[family]
	var scale_factor := minf(area.size.x/texture.get_width(),area.size.y/texture.get_height())
	var bounds := Rect2(area.get_center()-texture.get_size()*scale_factor*.5,texture.get_size()*scale_factor)
	canvas.draw_texture_rect(texture,bounds,false,look.tint)
	_draw_badge(canvas,area.get_center()+Vector2(area.size.x*.28,area.size.y*.18),look,minf(area.size.x,area.size.y)*.32)


static func draw_equipment(canvas: Node2D, family: String, direction: int, striking: bool, time_s: float = 0.0) -> void:
	var player := canvas.get_parent() as PrototypePlayer
	if player == null or player.damage_receiver.dead or player._fall_recovery_active: return
	var look := appearance(family, int(player.weapon_equipment.get(family,0)), String(player.weapon_blueprints.get(family,"")))
	var accent: Color = look.accent if not String(look.motif).is_empty() else Color("ffb49e") if player.character_id == "lumi" else Color("8de1d7")
	var tint: Color = look.tint
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(direction, 1))
	match family:
		"fist":
			canvas.draw_texture_rect(TEXTURES.fist, Rect2(10, -55, 31, 31), false, tint.darkened(.15))
			canvas.draw_texture_rect(TEXTURES.fist, Rect2(48 if striking else 27, -60 if striking else -39, 36, 36), false, tint)
			canvas.draw_circle(Vector2(64 if striking else 43, -32 if striking else -11), 3, accent)
			_draw_badge(canvas,Vector2(67 if striking else 46,-45 if striking else -24),look,14)
		"staff":
			canvas.draw_set_transform(Vector2(43 * direction, -43), (-0.2 if striking else 0.08) * direction, Vector2(direction, 1))
			canvas.draw_texture_rect(TEXTURES.staff, Rect2(-17, -63, 35, 102), false,tint)
			_draw_badge(canvas,Vector2(0,-48),look,18)
			if striking: canvas.draw_arc(Vector2(0, -48), 20, 0, TAU, 24, Color(COLORS.staff, 0.65), 2, true)
		"polearm":
			canvas.draw_set_transform(Vector2(22 * direction, -38), (sin(time_s * 18) * 0.6 if striking else -0.38) * direction, Vector2(direction, 1))
			canvas.draw_texture_rect(TEXTURES.polearm, Rect2(-91, -13, 223, 35), false,tint)
			_draw_badge(canvas,Vector2(113,4),look,17)
		"shield":
			canvas.draw_texture_rect(TEXTURES.shield, Rect2(23 if striking else 12, -87, 61, 78), false,tint)
			_draw_badge(canvas,Vector2(53 if striking else 42,-48),look,22)
			if look.motif.is_empty(): canvas.draw_circle(Vector2(53 if striking else 42, -48), 4, accent)
	canvas.draw_set_transform(Vector2.ZERO)

static func draw_impact(canvas: Node2D, family: String, direction: int, radius: float, ring: bool, remaining_s: float, rising: bool = false) -> void:
	if remaining_s <= 0.0: return
	var color: Color = COLORS[family]
	var player := canvas.get_parent() as PrototypePlayer
	if player != null and player.weapon_equipment.has(family):
		color = appearance(family,int(player.weapon_equipment[family]),String(player.weapon_blueprints.get(family,""))).accent
	var alpha := clampf(remaining_s / 0.16, 0.0, 1.0)
	var center := Vector2(0, -38)
	var angle := 0.0 if direction > 0 else PI
	var from := 0.0 if ring else angle - PI * 0.32
	var to := TAU if ring else angle + PI * 0.32
	if rising:
		center = Vector2(55 * direction, -50)
		from = -PI if direction > 0 else -PI * 0.5
		to = -PI * 0.5 if direction > 0 else 0.0
	canvas.draw_arc(center, radius, from, to, 48, Color(color, alpha * 0.15), 18, true)
	canvas.draw_arc(center, radius, from, to, 48, Color(color, alpha * 0.8), 4, true)
	canvas.draw_arc(center, radius - 8, from + 0.08, to - 0.08, 48, Color("fff5df", alpha * 0.8), 2, true)
	for index in 5:
		var theta := lerpf(from, to, (index + 0.5) / 5.0)
		var tip := center + Vector2.from_angle(theta) * radius
		canvas.draw_line(tip - Vector2.from_angle(theta) * 15, tip, Color(color, alpha), 2, true)
