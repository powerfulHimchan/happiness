class_name SupplyShopInspector
extends RefCounted

const PAGE_SIZE := 6
const TABS := ["상품 상세","구매 내역","재입고 미리보기"]

static func layout(safe: Rect2) -> Dictionary:
	var tabs: Array[Rect2] = []
	for index in 3: tabs.append(HeroStatusView.box(safe,.12+index*.26,.22,.24,.065))
	return {"panel":HeroStatusView.box(safe,.075,.08,.85,.82),"tabs":tabs,"previous":HeroStatusView.box(safe,.12,.78,.18,.065),"next":HeroStatusView.box(safe,.70,.78,.18,.065),"close":HeroStatusView.box(safe,.37,.78,.26,.065)}

static func lines(ui: Control) -> Array[String]:
	var data: Dictionary = ui.shop_data
	var result: Array[String] = []
	if ui.shop_inspector_tab == 1:
		for line in data.get("ledger",{}).get("lines",[]): result.append(String(line))
		result.reverse()
		if result.is_empty(): result.append("이번 도전의 구매·재입고·과제 수령 내역이 없습니다")
	elif ui.shop_inspector_tab == 2:
		for line in data.get("restock",[]): result.append(String(line))
	else:
		var selected := {}
		for item in data.get("cards",[]):
			if item.id == ui.shop_selected_id: selected = item
		result = SupplyShopBrowser.details(selected,data)
	return result

static func draw(ui: Control) -> void:
	var safe: Rect2 = ui._safe_area_in_viewport()
	var view := layout(safe)
	var content := lines(ui)
	var pages := maxi(1,ceili(float(content.size())/PAGE_SIZE))
	var page := clampi(ui.shop_inspector_page,0,pages-1)
	ui.draw_rect(Rect2(Vector2.ZERO,ui.size),Color(.01,.04,.07,.88))
	HeroStatusView.panel(ui,view.panel)
	HeroStatusView.text(ui,"보급소 확인",HeroStatusView.box(safe,.12,.12,.76,.065),30,HeroStatusView.GOLD)
	for index in 3: ui._draw_button(view.tabs[index],TABS[index],ui.shop_inspector_tab == index)
	var ledger: Dictionary = ui.shop_data.get("ledger",{})
	var summary := "경로 %d전 + 과제 %d전 − 지출 %d전 = 잔액 %d전" % [ledger.get("route_income",0),ledger.get("task_income",0),ledger.get("spent",0),ledger.get("balance",0)]
	HeroStatusView.text(ui,summary,HeroStatusView.box(safe,.12,.31,.76,.04),21,HeroStatusView.GOLD)
	for index in mini(PAGE_SIZE,content.size()-page*PAGE_SIZE): HeroStatusView.text(ui,content[page*PAGE_SIZE+index],HeroStatusView.box(safe,.12,.39+index*.052,.76,.043),20)
	HeroStatusView.text(ui,"조회 전용 · %d / %d" % [page+1,pages],HeroStatusView.box(safe,.12,.72,.76,.03),18,HeroStatusView.MUTE)
	ui._draw_button(view.previous,"이전",page > 0)
	ui._draw_button(view.next,"다음",page < pages-1)
	ui._draw_button(view.close,"보급소로",true)

static func handle_touch(ui: Control,point: Vector2) -> void:
	var view := layout(ui._safe_area_in_viewport())
	for index in 3:
		if view.tabs[index].has_point(point): ui.shop_inspector_tab = index; ui.shop_inspector_page = 0
	var pages := maxi(1,ceili(float(lines(ui).size())/PAGE_SIZE))
	if view.previous.has_point(point): ui.shop_inspector_page = maxi(0,ui.shop_inspector_page-1)
	if view.next.has_point(point): ui.shop_inspector_page = mini(pages-1,ui.shop_inspector_page+1)
	if view.close.has_point(point): ui.shop_inspector_open = false
	ui.queue_redraw()
