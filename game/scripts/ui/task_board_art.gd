class_name TaskBoardArt
extends RefCounted

## GP-508–510: display-only board, goal emblems and receipt/progress states.
const BACKDROP := preload("res://assets/tasks/traveler_board.svg")
const ICONS := {
	"path": preload("res://assets/tasks/path.svg"),
	"map": preload("res://assets/tasks/map.svg"),
	"battle": preload("res://assets/tasks/battle.svg"),
	"skill": preload("res://assets/tasks/skill.svg"),
	"growth": preload("res://assets/tasks/growth.svg"),
	"gear": preload("res://assets/tasks/gear.svg"),
	"trade": preload("res://assets/tasks/trade.svg"),
}

static func symbol(card: Dictionary) -> String:
	return {"stage":"path","route":"map","damage":"battle","hits":"skill","family":card.get("family","skill"),"level":"growth","job":"growth","advanced":"growth","equipment":"gear","purchases":"trade","rerolls":"trade","services":"trade"}.get(card.kind,"path")

static func state(card: Dictionary) -> String:
	return "claimed" if card.claimed else "ready" if card.ready else "unavailable" if card.get("unavailable",false) else "progress"

static func status_text(card: Dictionary) -> String:
	if not card.get("unavailable",false) or card.claimed or card.ready: return card.status
	if card.kind == "family": return "미휴대 무기"
	if card.kind == "stage": return "더 긴 도전"
	if card.kind == "advanced" or card.get("route","") == "city_gate": return "전체 여정"
	return "5단계 이상"

static func regions(rect: Rect2) -> Dictionary:
	return {"icon":Rect2(rect.position+Vector2(12,10),Vector2.ONE*32),"title":Rect2(rect.position+Vector2(51,7),Vector2(rect.size.x-92,32)),"hint":Rect2(rect.position+Vector2(12,rect.size.y*.31),Vector2(rect.size.x-24,26)),"bar":Rect2(rect.position+Vector2(14,rect.size.y*.58),Vector2(rect.size.x-28,8)),"status":Rect2(rect.position+Vector2(12,rect.size.y*.70),Vector2(rect.size.x*.66-12,28)),"reward":Rect2(rect.position+Vector2(rect.size.x*.68,rect.size.y*.70),Vector2(rect.size.x*.28,28)),"seal":Rect2(rect.position+Vector2(rect.size.x-34,13),Vector2.ONE*20)}

static func draw_card(ui: Control, card: Dictionary, rect: Rect2, selected: bool) -> void:
	var status := state(card)
	var color: Color = {"claimed":Color("91c8b0"),"ready":Color("f2ce85"),"unavailable":Color("81949c"),"progress":Color("a5c7d4")}[status]
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("274a4c") if status == "ready" else Color("233a43") if status == "claimed" else Color("1d323e")
	panel.border_color = Color("ffe6a1") if selected else color.darkened(.5)
	panel.set_border_width_all(3 if selected else 1)
	panel.set_corner_radius_all(9)
	ui.draw_style_box(panel,rect)
	ui.draw_rect(Rect2(rect.position+Vector2(1,10),Vector2(4,rect.size.y-20)),color)
	var areas := regions(rect)
	ui.draw_circle(areas.icon.get_center(),20,Color(color,.09))
	var icon := symbol(card)
	if ICONS.has(icon): ui.draw_texture_rect(ICONS[icon],SupplyShopArt.fitted(ICONS[icon],areas.icon),false,color)
	else: SupplyShopArt.draw_symbol(ui,icon,areas.icon,color)
	var center: Vector2 = areas.seal.get_center()
	if status == "claimed":
		ui.draw_circle(center,11,color)
		ui.draw_polyline(PackedVector2Array([center+Vector2(-6,0),center+Vector2(-1,5),center+Vector2(7,-5)]),Color("183238"),2.5,true)
	elif status == "ready":
		ui.draw_colored_polygon(PackedVector2Array([center+Vector2(0,-10),center+Vector2(8,0),center+Vector2(0,10),center+Vector2(-8,0)]),color)
	elif status == "unavailable":
		ui.draw_arc(center+Vector2(0,-3),6,PI,TAU,16,color,2,true)
		ui.draw_rect(Rect2(center+Vector2(-7,-2),Vector2(14,11)),color)
	else:
		ui.draw_arc(center,8,-PI*.5,PI*.8,24,color,1.5,true)
	var bar: Rect2 = areas.bar
	ui.draw_rect(bar,Color("102631"))
	ui.draw_rect(Rect2(bar.position,Vector2(bar.size.x*clampf(float(card.progress)/maxf(1.0,float(card.target)),0.0,1.0),bar.size.y)),color)
	ui._draw_village_text(card.name,areas.title,21,Color("f6e2b6"))
	ui._draw_village_text(card.hint,areas.hint,16,Color("d0dfe1"))
	ui._draw_village_text("%d/%d · %s" % [card.progress,card.target,status_text(card)],areas.status,15,color)
	var coin := Rect2(areas.reward.position,Vector2.ONE*22)
	SupplyShopArt.draw_symbol(ui,"coin",coin,color)
	ui._draw_village_text("%d전" % int(card.coins),Rect2(areas.reward.position+Vector2(24,0),Vector2(areas.reward.size.x-24,areas.reward.size.y)),17,color)
