class_name SupplyShopDetailArt
extends RefCounted

const SIGN := preload("res://assets/supplies/header_sign.svg")
const SERVICE := preload("res://assets/supplies/service_seal.svg")
const STAR := preload("res://assets/supplies/rarity_star.svg")
const TOME := preload("res://assets/supplies/skill_tome.svg")
const PRICE := preload("res://assets/supplies/price_tag.svg")
const SOLD := preload("res://assets/supplies/sold_ribbon.svg")
const LOCKED := preload("res://assets/supplies/locked_tag.svg")
const SLOT := preload("res://assets/supplies/slot_frame.svg")
const EMPTY := preload("res://assets/supplies/empty_crate.svg")

static func emblem(ui: Control, item: Dictionary, rect: Rect2, pose: Dictionary, color: Color) -> void:
	var center: Vector2 = rect.get_center()+pose.get("offset",Vector2.ZERO)
	var scale_factor := 1.0+float(pose.get("selection",0))*.06
	var area := Rect2(center-rect.size*scale_factor*.5,rect.size*scale_factor)
	if item.kind == "service":
		ui.draw_texture_rect(SERVICE,area.grow(5),false,Color(Color.WHITE,.65))
		SupplyShopArt.draw_symbol(ui,item.id,area.grow(-4),color)
	elif item.kind == "weapon": SupplyShopArt.draw_symbol(ui,item.family,area,color)
	else:
		ui.draw_texture_rect(TOME,area,false,color)
		SupplyShopArt.draw_symbol(ui,item.family,Rect2(center+Vector2(rect.size.x*.16,rect.size.y*.07),rect.size*.48),SupplyShopArt.ACCENTS.get(item.family,color))

static func rarity(ui: Control, item: Dictionary, rect: Rect2) -> void:
	if item.kind != "weapon": return
	var count: int = clampi(int(item.get("grade",0)),0,3)
	for index in count:
		var center := Vector2(rect.get_center().x+(index-(count-1)*.5)*17,rect.position.y+rect.size.y*.30)
		ui.draw_texture_rect(STAR,Rect2(center-Vector2.ONE*7,Vector2.ONE*14),false)

static func price(ui: Control, rect: Rect2, ready: bool) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("153a3c") if ready else Color("1a303d")
	panel.border_color = Color("6e9d83") if ready else Color("536975")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(6)
	ui.draw_style_box(panel,rect)
	ui.draw_texture_rect(PRICE,Rect2(rect.position+Vector2(4,2),Vector2.ONE*(rect.size.y-4)),false,Color.WHITE if ready else Color("92a3ac"))

static func slot(ui: Control, rect: Rect2, selected: bool, motion: SupplyShopMotion) -> void:
	var side := minf(28,rect.size.y-8)
	ui.draw_texture_rect(SLOT,Rect2(rect.position+Vector2(6,(rect.size.y-side)*.5),Vector2.ONE*side),false,Color.WHITE if selected else Color("8596aa"))
	if selected:
		var t := motion.slotting/SupplyShopMotion.SLOT
		var width := rect.size.x*SupplyShopMotion.smooth(t)
		ui.draw_line(rect.position+Vector2(4,rect.size.y-3),rect.position+Vector2(width-4,rect.size.y-3),Color("e6cf9d"),2,true)

static func empty(ui: Control, safe: Rect2) -> void:
	var side := safe.size.y*.14
	ui.draw_texture_rect(EMPTY,Rect2(safe.position+safe.size*Vector2(.5,.36)-Vector2.ONE*side*.5,Vector2.ONE*side),false)
	ui._draw_village_text("조건에 맞는 상품이 없습니다",HeroStatusView.box(safe,.18,.46,.64,.055),23,Color("decda6"))
	ui._draw_village_text("상품 종류·상태·무기 필터를 바꿔보세요",HeroStatusView.box(safe,.18,.52,.64,.045),17,Color("a8c2c6"))

static func effects(ui: Control, safe: Rect2, motion: SupplyShopMotion) -> void:
	var wallet := HeroStatusView.box(safe,.66,.045,.285,.055)
	if motion.wallet_age < SupplyShopMotion.WALLET:
		var pulse := sin(motion.wallet_age/SupplyShopMotion.WALLET*PI)
		ui.draw_rect(wallet.grow(-2),Color(Color("f0d295"),pulse*.6),false,2)
	var origin := safe.position+safe.size*Vector2(.78,.81)
	for piece in motion.purchase_pieces(): ui.draw_circle(origin+piece.offset,2.5,Color(Color("c8e8bc"),piece.alpha))
	if motion.purchased_cost > 0:
		ui._draw_village_text("구매 완료 · %d전" % motion.purchased_cost,Rect2(origin+Vector2(-120,-50-motion.purchase_age*14),Vector2(240,28)),19,Color(Color("c8e8bc"),1-motion.purchase_age/SupplyShopMotion.PURCHASE))

static func restock(ui: Control, rect: Rect2, motion: SupplyShopMotion, tint: Color) -> void:
	var side := rect.size.y*.56
	var center := rect.position+Vector2(8+side*.5,rect.size.y*.5)
	var angle := TAU*SupplyShopMotion.smooth(motion.restock_age/SupplyShopMotion.RESTOCK)
	ui.draw_set_transform(center,angle)
	SupplyShopArt.draw_symbol(ui,"restock",Rect2(-Vector2.ONE*side*.5,Vector2.ONE*side),tint)
	ui.draw_set_transform(Vector2.ZERO)
