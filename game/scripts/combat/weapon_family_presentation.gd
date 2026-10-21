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

static func draw_equipment(canvas: Node2D, family: String, direction: int, striking: bool, time_s: float = 0.0) -> void:
	var player := canvas.get_parent() as PrototypePlayer
	if player == null or player.damage_receiver.dead or player._fall_recovery_active: return
	var accent := Color("ffb49e") if player.character_id == "lumi" else Color("8de1d7")
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(direction, 1))
	match family:
		"fist":
			canvas.draw_texture_rect(TEXTURES.fist, Rect2(10, -55, 31, 31), false, Color("c8b89b"))
			canvas.draw_texture_rect(TEXTURES.fist, Rect2(48 if striking else 27, -60 if striking else -39, 36, 36), false)
			canvas.draw_circle(Vector2(64 if striking else 43, -32 if striking else -11), 3, accent)
		"staff":
			canvas.draw_set_transform(Vector2(43 * direction, -43), (-0.2 if striking else 0.08) * direction, Vector2(direction, 1))
			canvas.draw_texture_rect(TEXTURES.staff, Rect2(-17, -63, 35, 102), false)
			if striking: canvas.draw_arc(Vector2(0, -48), 20, 0, TAU, 24, Color(COLORS.staff, 0.65), 2, true)
		"polearm":
			canvas.draw_set_transform(Vector2(22 * direction, -38), (sin(time_s * 18) * 0.6 if striking else -0.38) * direction, Vector2(direction, 1))
			canvas.draw_texture_rect(TEXTURES.polearm, Rect2(-91, -13, 223, 35), false)
		"shield":
			canvas.draw_texture_rect(TEXTURES.shield, Rect2(23 if striking else 12, -87, 61, 78), false)
			canvas.draw_circle(Vector2(53 if striking else 42, -48), 4, accent)
	canvas.draw_set_transform(Vector2.ZERO)

static func draw_impact(canvas: Node2D, family: String, direction: int, radius: float, ring: bool, remaining_s: float, rising: bool = false) -> void:
	if remaining_s <= 0.0: return
	var color: Color = COLORS[family]
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
