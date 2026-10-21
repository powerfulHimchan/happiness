class_name RunTaskView
extends RefCounted

const PAGE_SIZE := 6
const FILTERS := ["all","ready","claimed"]

static func layout(safe: Rect2, count: int) -> Dictionary:
	var cards: Array[Rect2] = []
	for index in count:
		cards.append(Rect2(safe.position+safe.size*Vector2(.055+(index%3)*.305,.28+int(index/3)*.235),safe.size*Vector2(.28,.21)))
	var tabs: Array[Rect2] = []
	for index in 3: tabs.append(Rect2(safe.position+safe.size*Vector2(.18+index*.22,.14),safe.size*Vector2(.20,.06)))
	return {"cards":cards,"tabs":tabs,"previous":Rect2(safe.position+safe.size*Vector2(.055,.215),safe.size*Vector2(.18,.05)),"next":Rect2(safe.position+safe.size*Vector2(.765,.215),safe.size*Vector2(.18,.05)),"back":Rect2(safe.position+safe.size*Vector2(.055,.84),safe.size*Vector2(.27,.09)),"confirm":Rect2(safe.position+safe.size*Vector2(.52,.84),safe.size*Vector2(.425,.09))}

static func snapshot(ui: Control) -> Dictionary:
	var all: Array = ui.task_data.get("cards",[])
	var filtered := all.filter(func(card: Dictionary) -> bool: return ui.task_filter == "all" or (ui.task_filter == "ready" and card.ready) or (ui.task_filter == "claimed" and card.claimed))
	var pages := maxi(1,ceili(float(filtered.size())/PAGE_SIZE))
	var page := clampi(ui.task_page,0,pages-1)
	var items: Array = filtered.slice(page*PAGE_SIZE,(page+1)*PAGE_SIZE)
	var result := layout(ui._safe_area_in_viewport(),items.size())
	result.merge({"items":items,"page":page,"pages":pages,"total":filtered.size()})
	return result

static func draw(ui: Control) -> void:
	var view := snapshot(ui)
	var safe: Rect2 = ui._safe_area_in_viewport()
	ui.draw_texture_rect(SupplyShopArt.BACKDROP,Rect2(Vector2.ZERO,ui.size),false)
	ui._draw_village_text("여행자의 과제 · 현재 도전30종",Rect2(safe.position+safe.size*Vector2(.055,.035),safe.size*Vector2(.55,.07)),29,Color("ffe1a3"))
	SupplyShopArt.draw_wallet(ui,Rect2(safe.position+safe.size*Vector2(.66,.045),safe.size*Vector2(.285,.055)),int(ui.task_data.get("coins",0)))
	for index in 3: ui._draw_button(view.tabs[index],["전체","수령 가능","수령 완료"][index],ui.task_filter == FILTERS[index])
	ui._draw_button(view.previous,"이전",view.page > 0)
	ui._draw_button(view.next,"다음",view.page < view.pages-1)
	ui._draw_village_text("%d/%d · %d개" % [view.page+1,view.pages,view.total],Rect2(safe.position+safe.size*Vector2(.30,.215),safe.size*Vector2(.4,.05)),17,Color("d6e5ec"))
	var selected: Dictionary = {}
	for card in ui.task_data.get("cards",[]):
		if card.id == ui.task_selected_id: selected = card
	for index in view.items.size():
		var card: Dictionary = view.items[index]
		var rect: Rect2 = view.cards[index]
		ui.draw_style_box(ui._panel_style(Color("294e58") if card.ready else Color("233b47")),rect)
		if card.id == ui.task_selected_id: ui.draw_rect(rect.grow(-3),Color("ffd166"),false,3)
		ui._draw_village_text(card.name+" · %d전" % int(card.coins),Rect2(rect.position+Vector2(8,4),Vector2(rect.size.x-16,32)),21,Color("f4d99c"))
		ui._draw_village_text(card.hint,Rect2(rect.position+Vector2(8,rect.size.y*.29),Vector2(rect.size.x-16,28)),16,Color("d6e5ec"))
		var track := Rect2(rect.position+Vector2(rect.size.x*.08,rect.size.y*.59),Vector2(rect.size.x*.84,8))
		ui.draw_rect(track,Color("142c38"))
		ui.draw_rect(Rect2(track.position,Vector2(track.size.x*float(card.progress)/float(card.target),track.size.y)),Color("8ac4b5") if card.claimed else Color("e7c77b"))
		ui._draw_village_text("%d/%d · %s" % [card.progress,card.target,card.status],Rect2(rect.position+Vector2(8,rect.size.y*.73),Vector2(rect.size.x-16,28)),15,Color("98c5bb") if card.claimed else Color("b9d0d9"))
	if view.items.is_empty(): ui._draw_village_text("이 분류에 표시할 과제가 없습니다",Rect2(safe.position+safe.size*Vector2(.15,.43),safe.size*Vector2(.70,.10)),23,Color("d6e5ec"))
	ui._draw_village_text(ui.task_message,Rect2(safe.position+safe.size*Vector2(.055,.765),safe.size*Vector2(.89,.05)),17,Color("e7c77b"))
	ui._draw_button(view.back,"보급소로",false)
	ui._draw_button(view.confirm,"%d전 · 보상 수령" % int(selected.coins) if not selected.is_empty() and selected.ready else "완료한 과제를 선택하세요",not selected.is_empty() and selected.ready)
