class_name SupplyShopArt
extends RefCounted

## Presentation only: all stock, prices, input rectangles and saves belong to the shop model.
const BACKDROP := preload("res://assets/supplies/travel_stall.svg")
const ICONS := {
	"heal":preload("res://assets/supplies/meal.svg"),
	"potion":preload("res://assets/supplies/potion.svg"),
	"gauge":preload("res://assets/supplies/charge.svg"),
	"refresh":preload("res://assets/supplies/refresh.svg"),
	"coin":preload("res://assets/supplies/coin.svg"),
	"sword":preload("res://assets/supplies/sword.svg"),
	"bow":preload("res://assets/supplies/bow.svg"),
	"skill":preload("res://assets/supplies/skill.svg"),
	"restock":preload("res://assets/supplies/restock.svg"),
}
const ACCENTS := {"sword":Color("f1c78d"),"bow":Color("b8e3bc"),"fist":Color("ffcd82"),"staff":Color("d4b7ff"),"polearm":Color("a8ebc1"),"shield":Color("a9dfff")}

static func fitted(texture: Texture2D, area: Rect2) -> Rect2:
	var scale_factor := minf(area.size.x/texture.get_width(),area.size.y/texture.get_height())
	return Rect2(area.get_center()-texture.get_size()*scale_factor*.5,texture.get_size()*scale_factor)

static func draw_symbol(ui: CanvasItem, id: String, area: Rect2, tint: Color = Color.WHITE) -> void:
	var texture: Texture2D = ICONS.get(id,WeaponFamilyPresentation.TEXTURES.get(id))
	if texture != null: ui.draw_texture_rect(texture,fitted(texture,area),false,tint)

static func state(item: Dictionary) -> String:
	if item.get("reason","") == "이번 휴식에서 구매 완료": return "sold"
	return "ready" if item.get("ready",false) else "blocked"

static func card_regions(rect: Rect2) -> Dictionary:
	var side := minf(rect.size.x*.25,rect.size.y*.29)
	return {"icon":Rect2(Vector2(rect.get_center().x-side*.5,rect.position.y+rect.size.y*.045),Vector2.ONE*side),"title":Rect2(rect.position+Vector2(12,rect.size.y*.32),Vector2(rect.size.x-24,34)),"price":Rect2(rect.position+Vector2(12,rect.size.y*.46),Vector2(rect.size.x-24,28)),"details":Rect2(rect.position+Vector2(12,rect.size.y*.60),Vector2(rect.size.x-24,rect.size.y*.36)),"stamp":Rect2(rect.position+Vector2(rect.size.x-42,12),Vector2(26,26))}

static func draw_card(ui: Control, item: Dictionary, rect: Rect2, selected: bool) -> void:
	var status := state(item)
	var accent: Color = ACCENTS.get(item.family,Color("b8e3bc"))
	var fill := Color("244954") if status == "ready" else Color("233a45")
	var panel := StyleBoxFlat.new()
	panel.bg_color = fill
	panel.border_color = Color("f4cf80") if selected else accent.darkened(.46)
	panel.set_border_width_all(3 if selected else 1)
	panel.set_corner_radius_all(16)
	ui.draw_style_box(panel,rect)
	var regions := card_regions(rect)
	var center: Vector2 = regions.icon.get_center()
	var radius: float = regions.icon.size.x*.55
	ui.draw_circle(center,radius,Color(accent,.08))
	ui.draw_arc(center,radius,0,TAU,48,Color(accent,.32),1.5,true)
	var tint := Color.WHITE if status == "ready" else Color("8fa7ad")
	if item.kind == "service": draw_symbol(ui,item.id,regions.icon,tint)
	elif item.kind == "weapon":
		draw_symbol(ui,item.family,regions.icon,tint)
		for index in int(item.grade):
			var mark := center+Vector2(radius*.90,(index*.19-.10)*regions.icon.size.y)
			ui.draw_circle(mark,3,Color("ffe0a0"))
	else:
		draw_symbol(ui,"skill",regions.icon,tint)
		draw_symbol(ui,item.family,Rect2(center+Vector2(radius*.20,radius*.05),regions.icon.size*.48),accent)
	var stamp: Rect2 = regions.stamp
	if status == "sold":
		ui.draw_circle(stamp.get_center(),stamp.size.x*.5,Color("93c5b0"))
		var origin := stamp.position
		ui.draw_polyline(PackedVector2Array([origin+Vector2(6,13),origin+Vector2(11,18),origin+Vector2(21,8)]),Color("183944"),3,true)
	elif status == "blocked":
		ui.draw_arc(stamp.get_center()+Vector2(0,-4),6,PI,TAU,16,Color("829ca7"),2,true)
		ui.draw_rect(Rect2(stamp.position+Vector2(5,10),Vector2(16,12)),Color("829ca7"))
	elif selected:
		var middle := stamp.get_center()
		ui.draw_colored_polygon(PackedVector2Array([middle+Vector2(0,-11),middle+Vector2(9,0),middle+Vector2(0,11),middle+Vector2(-9,0)]),Color("f4cf80"))

static func draw_wallet(ui: Control, rect: Rect2, coins: int) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("172f3b")
	panel.border_color = Color("b99b61")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(10)
	ui.draw_style_box(panel,rect)
	var side := rect.size.y*.76
	draw_symbol(ui,"coin",Rect2(rect.position+Vector2(rect.size.y*.12,rect.size.y*.12),Vector2.ONE*side))
	ui._draw_village_text("보급전 %d" % coins,Rect2(rect.position+Vector2(rect.size.y,0),Vector2(rect.size.x-rect.size.y-6,rect.size.y)),18,Color("f4d99c"))
