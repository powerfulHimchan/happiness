class_name SupplyShopView
extends RefCounted

static func layout(safe: Rect2, count: int) -> Dictionary:
	var cards: Array[Rect2] = []
	var width := safe.size.x*.28
	for index in count:
		cards.append(Rect2(safe.position+Vector2(safe.size.x*(.055+index*.305),safe.size.y*.23),Vector2(width,safe.size.y*.36)))
	var slots: Array[Rect2] = []
	for index in 2: slots.append(Rect2(safe.position+Vector2(safe.size.x*(.12+index*.40),safe.size.y*.65),Vector2(safe.size.x*.36,safe.size.y*.07)))
	return {"cards":cards,"slots":slots,"previous":Rect2(safe.position+Vector2(safe.size.x*.055,safe.size.y*.14),Vector2(safe.size.x*.18,safe.size.y*.06)),"next":Rect2(safe.position+Vector2(safe.size.x*.765,safe.size.y*.14),Vector2(safe.size.x*.18,safe.size.y*.06)),"back":Rect2(safe.position+Vector2(safe.size.x*.055,safe.size.y*.83),Vector2(safe.size.x*.23,safe.size.y*.09)),"reroll":Rect2(safe.position+Vector2(safe.size.x*.32,safe.size.y*.83),Vector2(safe.size.x*.25,safe.size.y*.09)),"confirm":Rect2(safe.position+Vector2(safe.size.x*.61,safe.size.y*.83),Vector2(safe.size.x*.335,safe.size.y*.09))}

static func draw(ui: Control) -> void:
	var view: Dictionary = ui.supply_shop_snapshot()
	var safe: Rect2 = ui._safe_area_in_viewport()
	var data: Dictionary = ui.shop_data
	ui.draw_texture_rect(SupplyShopArt.BACKDROP,Rect2(Vector2.ZERO,ui.size),false)
	ui._draw_village_text("여행 보급소",Rect2(safe.position+Vector2(safe.size.x*.25,safe.size.y*.035),Vector2(safe.size.x*.35,safe.size.y*.07)),32,Color("ffe1a3"))
	SupplyShopArt.draw_wallet(ui,Rect2(safe.position+Vector2(safe.size.x*.66,safe.size.y*.045),Vector2(safe.size.x*.285,safe.size.y*.055)),int(data.get("coins",0)))
	ui._draw_button(view.previous,"이전",view.page > 0)
	ui._draw_button(view.next,"다음",view.page < view.pages-1)
	ui._draw_village_text("%d/%d · %d스테이지 휴식" % [view.page+1,view.pages,int(data.get("stage",0))],Rect2(safe.position+Vector2(safe.size.x*.27,safe.size.y*.14),Vector2(safe.size.x*.46,safe.size.y*.06)),18,Color("bdd3df"))
	var selected: Dictionary = {}
	for index in view.items.size():
		var item: Dictionary = view.items[index]
		var rect: Rect2 = view.cards[index]
		SupplyShopArt.draw_card(ui,item,rect,item.id == ui.shop_selected_id)
		var regions := SupplyShopArt.card_regions(rect)
		ui._draw_village_text(item.name,regions.title,23,Color("f1e3ba"))
		ui._draw_village_text("%d전 · %s%s" % [int(item.cost),(PrototypeWeaponRewards.family_name(item.family)+" · ") if not item.family.is_empty() else "","구매 가능" if item.ready else item.reason],regions.price,17,Color("b3dbbd") if item.ready else Color("a6bac6"))
		for line in item.lines.size():
			ui._draw_village_text(String(item.lines[line]),Rect2(regions.details.position+Vector2(0,line*rect.size.y*.115),Vector2(regions.details.size.x,28)),17,Color("d6e5ec"))
	for item in data.get("cards",[]):
		if item.id == ui.shop_selected_id: selected = item
	if not selected.is_empty() and selected.kind == "skill":
		for slot in 2:
			var id: String = data.context.skills[selected.family][slot]
			ui._draw_button(view.slots[slot],"슬롯%d · %s" % [slot+1,PrototypeSkillRewards.SKILLS[id].display_name],ui.shop_slot == slot)
	else:
		ui._draw_village_text("상품을 선택한 뒤 가격과 효과를 확인하세요",Rect2(safe.position+Vector2(safe.size.x*.10,safe.size.y*.65),Vector2(safe.size.x*.80,safe.size.y*.07)),18,Color("b2cbd8"))
	ui._draw_village_text(ui.shop_message,Rect2(safe.position+Vector2(safe.size.x*.055,safe.size.y*.745),Vector2(safe.size.x*.89,safe.size.y*.06)),18,Color("efc985"))
	ui._draw_button(view.back,"경로 선택으로",false)
	ui._draw_button(view.reroll,"기술 재입고 · 10전" if not data.get("rerolled",false) else "재입고 완료",not data.get("rerolled",false) and int(data.get("coins",0)) >= RunSupplyShop.REROLL_COST)
	SupplyShopArt.draw_symbol(ui,"restock",Rect2(view.reroll.position+Vector2(8,view.reroll.size.y*.22),Vector2.ONE*view.reroll.size.y*.56),Color("173944") if not data.get("rerolled",false) and int(data.get("coins",0)) >= RunSupplyShop.REROLL_COST else Color("8da9ad"))
	var ready: bool = not selected.is_empty() and selected.ready and (selected.kind != "skill" or ui.shop_slot in [0,1])
	ui._draw_button(view.confirm,"%d전 · 구매 확정" % int(selected.cost) if ready else "상품·교체 슬롯 선택",ready)
