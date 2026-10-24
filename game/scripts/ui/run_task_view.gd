class_name RunTaskView
extends RefCounted

const PAGE_SIZE := 6
const FILTERS := ["all","ready","claimed","active","unavailable"]
const CATEGORIES := ["all","combat","explore","growth","trade"]
const CATEGORY_NAMES := ["전체","전투","탐험","성장","보급"]
const SORTS := ["catalog","progress","reward","recommended"]
const SORT_NAMES := ["목록순","진행률순","보상순","추천순"]

static func layout(safe: Rect2, count: int) -> Dictionary:
	var cards: Array[Rect2] = []
	for index in count:
		cards.append(Rect2(safe.position+safe.size*Vector2(.055+(index%3)*.305,.35+int(index/3)*.20),safe.size*Vector2(.28,.18)))
	var tabs: Array[Rect2] = []
	for index in FILTERS.size(): tabs.append(Rect2(safe.position+safe.size*Vector2(.055+index*.18,.13),safe.size*Vector2(.17,.055)))
	return {"cards":cards,"tabs":tabs,"category":Rect2(safe.position+safe.size*Vector2(.055,.205),safe.size*Vector2(.235,.055)),"sort":Rect2(safe.position+safe.size*Vector2(.305,.205),safe.size*Vector2(.20,.055)),"summary":Rect2(safe.position+safe.size*Vector2(.52,.205),safe.size*Vector2(.425,.055)),"previous":Rect2(safe.position+safe.size*Vector2(.055,.28),safe.size*Vector2(.18,.05)),"next":Rect2(safe.position+safe.size*Vector2(.765,.28),safe.size*Vector2(.18,.05)),"back":Rect2(safe.position+safe.size*Vector2(.055,.86),safe.size*Vector2(.27,.085)),"confirm":Rect2(safe.position+safe.size*Vector2(.52,.86),safe.size*Vector2(.425,.085))}

static func matches(card: Dictionary, filter: String) -> bool:
	match filter:
		"ready": return card.ready
		"claimed": return card.claimed
		"active": return not card.claimed and not card.ready and not card.get("unavailable",false)
		"unavailable": return not card.claimed and not card.ready and card.get("unavailable",false)
	return true

static func ordered(cards: Array, filter: String, category: String, order: String) -> Array:
	var result := cards.filter(func(card: Dictionary) -> bool: return matches(card,filter) and (category == "all" or card.get("category",RunTasks.category(card)) == category))
	if order != "catalog":
		result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			if order == "recommended":
				var first := _priority(a)
				var second := _priority(b)
				if first != second: return first < second
			var first := float(a.coins) if order == "reward" else float(a.get("fraction",float(a.progress)/a.target))
			var second := float(b.coins) if order == "reward" else float(b.get("fraction",float(b.progress)/b.target))
			if not is_equal_approx(first,second): return first > second
			return String(a.id) < String(b.id))
	return result

static func _priority(card: Dictionary) -> int:
	return 0 if card.ready else 3 if card.claimed else 2 if card.get("unavailable",false) else 1

static func summary(cards: Array) -> Dictionary:
	var value := {"total":cards.size(),"claimed":0,"ready":0,"coins":0}
	for card in cards:
		if card.claimed: value.claimed += 1
		elif card.ready:
			value.ready += 1
			value.coins += int(card.coins)
	return value

static func details(card: Dictionary) -> String:
	var lines: Array[String] = []
	for goal in card.get("conditions",[]): lines.append("%s %d/%d" % [goal.label,goal.progress,goal.target])
	return " · ".join(lines) if not lines.is_empty() else card.get("hint","")

static func snapshot(ui: Control) -> Dictionary:
	var all: Array = ui.task_data.get("cards",[])
	var filtered := ordered(all,ui.task_filter,ui.task_category,ui.task_sort)
	var pages := maxi(1,ceili(float(filtered.size())/PAGE_SIZE))
	var page := clampi(ui.task_page,0,pages-1)
	var items: Array = filtered.slice(page*PAGE_SIZE,(page+1)*PAGE_SIZE)
	var result := layout(ui._safe_area_in_viewport(),items.size())
	result.merge({"items":items,"page":page,"pages":pages,"total":filtered.size(),"counts":summary(all)})
	return result

static func draw(ui: Control) -> void:
	var view := snapshot(ui)
	var safe: Rect2 = ui._safe_area_in_viewport()
	ui.draw_texture_rect(TaskBoardArt.BACKDROP,Rect2(Vector2.ZERO,ui.size),false)
	ui._draw_village_text("여행자의 과제 · 현재 도전%d종" % view.counts.total,Rect2(safe.position+safe.size*Vector2(.055,.035),safe.size*Vector2(.57,.065)),28,Color("ffe1a3"))
	SupplyShopArt.draw_wallet(ui,Rect2(safe.position+safe.size*Vector2(.66,.045),safe.size*Vector2(.285,.055)),int(ui.task_data.get("coins",0)))
	for index in FILTERS.size(): ui._draw_button(view.tabs[index],["전체","수령 가능","수령 완료","진행 중","진행 불가"][index],ui.task_filter == FILTERS[index])
	ui._draw_button(view.category,"분류: "+CATEGORY_NAMES[CATEGORIES.find(ui.task_category)],false)
	ui._draw_button(view.sort,SORT_NAMES[SORTS.find(ui.task_sort)],false)
	ui._draw_village_text("수령완료%d/%d · 가능%d개 %d전" % [view.counts.claimed,view.counts.total,view.counts.ready,view.counts.coins],view.summary,16,Color("e7c77b"))
	ui._draw_button(view.previous,"이전",view.page > 0)
	ui._draw_button(view.next,"다음",view.page < view.pages-1)
	ui._draw_village_text("%d/%d · %d개" % [view.page+1,view.pages,view.total],Rect2(safe.position+safe.size*Vector2(.30,.28),safe.size*Vector2(.4,.05)),17,Color("d6e5ec"))
	var selected: Dictionary = {}
	for card in ui.task_data.get("cards",[]):
		if card.id == ui.task_selected_id: selected = card
	for index in view.items.size():
		var card: Dictionary = view.items[index]
		TaskBoardArt.draw_card(ui,card,view.cards[index],card.id == ui.task_selected_id)
	if view.items.is_empty(): ui._draw_village_text("이 분류에 표시할 과제가 없습니다",Rect2(safe.position+safe.size*Vector2(.15,.43),safe.size*Vector2(.70,.10)),23,Color("d6e5ec"))
	var message: String = ui.task_message
	if message.is_empty() and not selected.is_empty(): message = details(selected)
	ui._draw_village_text(message,Rect2(safe.position+safe.size*Vector2(.055,.755),safe.size*Vector2(.89,.04)),16,Color("e7c77b"))
	if not selected.is_empty() and selected.get("unavailable",false) and not selected.ready and not selected.claimed: ui._draw_village_text(selected.status,Rect2(safe.position+safe.size*Vector2(.055,.805),safe.size*Vector2(.89,.035)),15,Color("c4d2db"))
	ui._draw_button(view.back,"보급소로",false)
	ui._draw_button(view.confirm,"%d전 · 보상 수령" % int(selected.coins) if not selected.is_empty() and selected.ready else "완료한 과제를 선택하세요",not selected.is_empty() and selected.ready)
