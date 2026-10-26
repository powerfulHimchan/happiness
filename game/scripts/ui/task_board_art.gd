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
	if card.kind == "compound":
		if card.get("category","") == "trade": return "trade"
		return card.get("family",card.get("families",["map"])[0])
	return {"stage":"path","route":"map","damage":"battle","hits":"skill","family":card.get("family","skill"),"level":"growth","job":"growth","advanced":"growth","equipment":"gear","purchases":"trade","rerolls":"trade","services":"trade"}.get(card.kind,"path")

static func state(card: Dictionary) -> String:
	return "claimed" if card.claimed else "ready" if card.ready else "unavailable" if card.get("unavailable",false) else "progress"

static func status_text(card: Dictionary) -> String:
	if not card.get("unavailable",false) or card.claimed or card.ready: return card.status
	if card.kind == "compound": return "조건 확인"
	if card.kind == "family": return "미휴대 무기"
	if card.kind == "stage": return "더 긴 도전"
	if card.kind == "advanced" or card.get("route","") == "city_gate": return "전체 여정"
	return "5단계 이상"

static func regions(rect: Rect2) -> Dictionary:
	return {"icon":Rect2(rect.position+Vector2(12,10),Vector2.ONE*32),"title":Rect2(rect.position+Vector2(62,7),Vector2(rect.size.x-103,32)),"hint":Rect2(rect.position+Vector2(12,rect.size.y*.31),Vector2(rect.size.x-24,26)),"bar":Rect2(rect.position+Vector2(14,rect.size.y*.58),Vector2(rect.size.x-28,8)),"status":Rect2(rect.position+Vector2(12,rect.size.y*.70),Vector2(rect.size.x*.66-12,28)),"reward":Rect2(rect.position+Vector2(rect.size.x*.68,rect.size.y*.70),Vector2(rect.size.x*.28,28)),"seal":Rect2(rect.position+Vector2(rect.size.x-34,13),Vector2.ONE*20)}

static func draw_card(ui: Control, card: Dictionary, rect: Rect2, selected: bool, pose: Dictionary = {}) -> void:
	var status := state(card)
	var color: Color = {"claimed":Color("91c8b0"),"ready":Color("f2ce85"),"unavailable":Color("81949c"),"progress":Color("a5c7d4")}[status]
	if status == "progress": color = SupplyShopArt.ACCENTS.get(card.get("family",card.get("families",[""])[0]),color)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("274a4c") if status == "ready" else Color("233a43") if status == "claimed" else Color("1d323e")
	panel.border_color = Color("ffe6a1") if selected else color.darkened(.5)
	panel.set_border_width_all(2 if selected else 1)
	panel.set_corner_radius_all(9)
	panel.shadow_color = Color(0,0,0,.20)
	panel.shadow_size = 3
	panel.shadow_offset = Vector2(0,2)
	ui.draw_style_box(panel,rect)
	ui.draw_rect(Rect2(rect.position+Vector2(1,10),Vector2(3,rect.size.y-20)),color)
	var areas := regions(rect)
	TaskBoardDetailArt.emblem(ui,card,areas.icon,color,pose.get("offset",Vector2.ZERO),float(pose.get("selection",0)))
	TaskBoardDetailArt.seal(ui,status,areas.seal.grow(2),float(pose.get("ready",0)))
	if status == "progress": ui.draw_arc(areas.seal.get_center(),8,-PI*.5,PI*.8,24,color,1.5,true)
	TaskBoardDetailArt.progress(ui,card,areas.bar,float(pose.get("fraction",TaskBoardMotion.fraction(card))),color)
	var alpha := float(pose.get("alpha",1))
	ui._draw_village_text(card.name,areas.title,21,Color(Color("f6e2b6"),alpha))
	ui._draw_village_text(card.hint,areas.hint,16,Color(Color("d0dfe1"),alpha))
	ui._draw_village_text("%d/%d · %s" % [card.progress,card.target,status_text(card)],areas.status,15,color)
	var coin := Rect2(areas.reward.position,Vector2.ONE*24)
	ui.draw_texture_rect(TaskBoardDetailArt.MEDAL,SupplyShopArt.fitted(TaskBoardDetailArt.MEDAL,coin),false)
	var glint := float(pose.get("glint",0))
	if glint > .001:
		var center := coin.get_center()+Vector2(4,-4)
		ui.draw_line(center-Vector2(4,0),center+Vector2(4,0),Color(Color("fff1c5"),glint),1.5,true)
		ui.draw_line(center-Vector2(0,4),center+Vector2(0,4),Color(Color("fff1c5"),glint),1.5,true)
	ui._draw_village_text("%d전" % int(card.coins),Rect2(areas.reward.position+Vector2(24,0),Vector2(areas.reward.size.x-24,areas.reward.size.y)),17,color)
	TaskBoardDetailArt.chrome(ui,rect,color,selected,pose)
