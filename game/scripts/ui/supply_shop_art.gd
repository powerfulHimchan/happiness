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
	var side := minf(rect.size.x*.23,rect.size.y*.23)
	return {"icon":Rect2(Vector2(rect.get_center().x-side*.5,rect.position.y+rect.size.y*.045),Vector2.ONE*side),"title":Rect2(rect.position+Vector2(12,rect.size.y*.36),Vector2(rect.size.x-24,34)),"price":Rect2(rect.position+Vector2(12,rect.size.y*.52),Vector2(rect.size.x-24,28)),"details":Rect2(rect.position+Vector2(12,rect.size.y*.66),Vector2(rect.size.x-24,rect.size.y*.32)),"stamp":Rect2(rect.position+Vector2(rect.size.x-42,12),Vector2(26,40))}

static func draw_card(ui: Control, item: Dictionary, rect: Rect2, selected: bool, pose: Dictionary = {}) -> void:
	var status := state(item)
	var accent: Color = ACCENTS.get(item.family,Color("b8e3bc"))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("244954") if status == "ready" else Color("233a45")
	panel.border_color = Color("f4cf80") if selected else accent.darkened(.46)
	panel.set_border_width_all(2 if selected else 1)
	panel.set_corner_radius_all(14)
	panel.shadow_color = Color(0,0,0,.22)
	panel.shadow_size = 4
	panel.shadow_offset = Vector2(0,3)
	ui.draw_style_box(panel,rect)
	var areas := card_regions(rect)
	var tint := Color.WHITE if status == "ready" else Color("8fa7ad")
	SupplyShopDetailArt.emblem(ui,item,areas.icon,pose,tint)
	SupplyShopDetailArt.rarity(ui,item,rect)
	SupplyShopDetailArt.price(ui,areas.price,status == "ready")
	if status == "sold": ui.draw_texture_rect(SupplyShopDetailArt.SOLD,SupplyShopArt.fitted(SupplyShopDetailArt.SOLD,areas.stamp),false)
	elif status == "blocked": ui.draw_texture_rect(SupplyShopDetailArt.LOCKED,SupplyShopArt.fitted(SupplyShopDetailArt.LOCKED,areas.stamp),false,tint)
	if selected:
		var pulse := float(pose.get("selection",0))
		ui.draw_line(rect.position+Vector2(5,18),rect.position+Vector2(5,rect.size.y-18),Color(Color("f4cf80"),.55+.45*pulse),2,true)

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
