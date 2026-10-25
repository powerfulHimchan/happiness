class_name CombatLinksView
extends RefCounted

const PAGE_SIZE := 3
const FAMILY_FILTERS := ["전체 무기","주 무기","보조 무기"]
const KIND_FILTERS := ["모든 공격","기본 공격","스킬"]
const STATUS_FILTERS := ["모든 상태","발동 중","발동 대기"]
const ORDER_FILTERS := ["목록순","남은 시간순"]
const OWNERSHIP_FILTERS := ["보유 능력","미획득 포함"]

static func defaults() -> Dictionary:
	return {"family":0,"kind":0,"status":0,"order":0,"ownership":0,"page":0,"selected":""}

static func layout(safe: Rect2) -> Dictionary:
	var filters: Array[Rect2] = []
	var cards: Array[Rect2] = []
	for index in 5: filters.append(HeroStatusView.box(safe,.10+index*.164,.245,.145,.06))
	for index in 3: cards.append(HeroStatusView.box(safe,.10+index*.273,.33,.255,.28))
	return {"modal":HeroStatusView.box(safe,.06,.08,.88,.84),"filters":filters,"cards":cards,"previous":HeroStatusView.box(safe,.10,.81,.15,.065),"close":HeroStatusView.box(safe,.38,.81,.24,.065),"next":HeroStatusView.box(safe,.75,.81,.15,.065)}

static func cards(state: Dictionary, options: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state.is_empty(): return result
	var held := HeroStatusView.families(state)
	var ranks: Dictionary = state.growth.growth_ranks
	var active: Dictionary = state.get("combat_links",{})
	for definition in PrototypeCombatLinks.CARDS:
		var common: bool = definition.category == "common"
		if not common and definition.category not in held: continue
		var family_filter := int(options.get("family",0))
		if family_filter > 0 and not common and (family_filter >= held.size()+1 or definition.category != held[family_filter-1]): continue
		var learned := ranks.has(definition.id)
		if int(options.get("ownership",0)) == 0 and not learned: continue
		var style := String(definition.get("link_style",String(definition.id).trim_prefix("link_extend_")))
		var index := PrototypeCombatLinks.STYLES.find(style)
		var kind: String = PrototypeCombatLinks.KINDS[index]
		var kind_filter := int(options.get("kind",0))
		if kind_filter > 0 and kind not in ["all","basic" if kind_filter == 1 else "skill"]: continue
		var remaining := float(active.get(definition.id,0.0))
		var live := learned and (common or remaining > 0.0)
		var status_filter := int(options.get("status",0))
		if (status_filter == 1 and not live) or (status_filter == 2 and live): continue
		var card: Dictionary = definition.duplicate(true)
		card.learned = learned
		card.remaining = remaining
		card.live = live
		card.style = style
		card.duration = PrototypeCombatLinks.duration(style,ranks)
		if not common: card.lines[1] = String(card.lines[1]).replace("%.0f초간" % float(PrototypeCombatLinks.DURATIONS[index]),"%.0f초간" % float(card.duration))
		card.status = "상시 적용" if common and learned else "발동 중 %.1f초" % remaining if live else "발동 대기" if learned else "미획득 · 조건 살펴보기"
		result.append(card)
	if int(options.get("order",0)) == 1:
		result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.remaining) > float(b.remaining) if a.remaining != b.remaining else int(a.ticket) < int(b.ticket))
	return result

static func detail(card: Dictionary, state: Dictionary) -> Array[String]:
	var source: Dictionary = state.growth.growth_ranks
	var index := PrototypeCombatLinks.STYLES.find(card.style)
	var lines: Array[String] = []
	if card.category == "common":
		lines.append("선행: 휴대 무기의 "+PrototypeCombatLinks.LABELS[index]+" 중 하나 획득")
		lines.append("다음 발동부터 지속시간 +1초 · 이미 진행 중인 시간은 늘리지 않습니다")
	else:
		lines.append("발동: "+PrototypeCombatLinks.TRIGGERS[index]+" · 지속 %.0f초" % float(card.duration))
		var requirement := PrototypeAbilityCodex.profile(String(card.requires[0]))
		lines.append("선행: "+String(requirement.title)+(" · 충족" if PrototypeCombatLinks.prerequisites(card,source) else " · 미충족"))
	lines.append("성장 선택으로 획득 · 재발동은 시간 갱신 · 연계끼리 합산 · 필살기 제외")
	return lines

static func comparison(state: Dictionary, options: Dictionary) -> String:
	var parts: Array[String] = []
	var held := HeroStatusView.families(state)
	for index in held.size():
		if int(options.get("family",0)) > 0 and int(options.family)-1 != index: continue
		var family: String = held[index]
		var before: Dictionary = state.get("damage_without_links",{}).get(family,{"basic":100,"skill":100})
		var after: Dictionary = state.damage[family]
		parts.append("%s 기본 %d→%d / 스킬 %d→%d" % [PrototypeWeaponRewards.family_name(family),before.basic,after.basic,before.skill,after.skill])
	return "연계 전→현재 · "+"  |  ".join(parts)+" (원본 피해100)"

static func draw(ui: Control) -> void:
	var state: Dictionary = ui.run_build_state
	var options: Dictionary = ui.combat_link_options
	var safe: Rect2 = ui._safe_area_in_viewport()
	var view := layout(safe)
	var entries := cards(state,options)
	var pages := maxi(1,ceili(float(entries.size())/PAGE_SIZE))
	var page := clampi(int(options.page),0,pages-1)
	ui.draw_rect(Rect2(Vector2.ZERO,ui.size),Color(.01,.04,.07,.87))
	ui.draw_texture_rect(CombatLinksArt.BACKGROUND,view.modal,false)
	HeroStatusView.text(ui,"전투 연계",HeroStatusView.box(safe,.10,.10,.80,.05),30,HeroStatusView.GOLD)
	var active_count: int = state.get("combat_links",{}).size()
	HeroStatusView.text(ui,"발동 중 %d개 · 재발동은 시간 갱신 · 상태 화면에서는 시간이 멈춥니다" % active_count,HeroStatusView.box(safe,.10,.16,.80,.03),19,HeroStatusView.MUTE)
	HeroStatusView.text(ui,comparison(state,options),HeroStatusView.box(safe,.10,.20,.80,.03),19)
	var keys := ["family","kind","status","order","ownership"]
	var choices := [FAMILY_FILTERS,KIND_FILTERS,STATUS_FILTERS,ORDER_FILTERS,OWNERSHIP_FILTERS]
	for index in 5: ui._draw_button(view.filters[index],choices[index][int(options[keys[index]])],true)
	var highlight := String(options.selected)
	if highlight.is_empty() and not entries.is_empty(): highlight = String(entries[page*PAGE_SIZE].id)
	for index in mini(PAGE_SIZE,entries.size()-page*PAGE_SIZE):
		var card: Dictionary = entries[page*PAGE_SIZE+index]
		var highlighted: bool = card.id == highlight
		var pose: Dictionary = ui.combat_link_menu_motion.pose(index,highlighted)
		var rect := Rect2(view.cards[index].position+pose.offset,view.cards[index].size)
		var areas := CombatLinksArt.card_regions(rect)
		var alpha := float(pose.alpha)
		CombatLinksArt.frame(ui,card,rect,alpha)
		if highlighted: ui.draw_rect(rect.grow(-3),Color(HeroStatusView.GOLD,.25+float(pose.pulse)*.45),false,1.5+float(pose.pulse),true)
		var icon_rect: Rect2 = areas.icon
		icon_rect.position.y -= float(pose.pulse)*2.0
		CombatLinksArt.icon(ui,card.style,icon_rect,alpha)
		HeroStatusView.text(ui,String(card.title),areas.title,24,Color(HeroStatusView.GOLD,alpha))
		HeroStatusView.text(ui,String(card.status),areas.status,19,Color(Color("80e5c2") if card.live else HeroStatusView.MUTE,alpha))
		for line in mini(2,card.lines.size()): HeroStatusView.text(ui,String(card.lines[line]),areas.first if line == 0 else areas.second,19,Color(HeroStatusView.INK,alpha))
		if float(card.remaining) > 0.0:
			var bar: Rect2 = areas.bar
			ui.draw_rect(bar,Color("102d3e",alpha))
			ui.draw_rect(Rect2(bar.position,Vector2(bar.size.x*clampf(float(card.remaining)/float(card.duration),0,1),bar.size.y)),Color("80e5c2",alpha))
	var selected := entries.filter(func(card: Dictionary) -> bool: return card.id == options.selected)
	if selected.is_empty() and not entries.is_empty(): selected = [entries[page*PAGE_SIZE]]
	if not selected.is_empty():
		var lines := detail(selected[0],state)
		for index in lines.size(): HeroStatusView.text(ui,lines[index],HeroStatusView.box(safe,.10,.65+index*.033,.80,.029),18,HeroStatusView.MUTE)
	else:
		HeroStatusView.text(ui,"해당 조건의 연계가 없습니다 · 미획득 포함으로 다음 성장을 살펴보세요",HeroStatusView.box(safe,.10,.48,.80,.05),23,HeroStatusView.MUTE)
	HeroStatusView.text(ui,"카드를 눌러 발동·선행 조건 확인 · %d개 · %d / %d" % [entries.size(),page+1,pages],HeroStatusView.box(safe,.10,.765,.80,.03),18,HeroStatusView.MUTE)
	ui._draw_button(view.previous,"이전",page > 0)
	ui._draw_button(view.next,"다음",page < pages-1)
	ui._draw_button(view.close,"상태로 돌아가기",true)

static func handle_touch(ui: Control, point: Vector2) -> void:
	var options: Dictionary = ui.combat_link_options
	var view := layout(ui._safe_area_in_viewport())
	var keys := ["family","kind","status","order","ownership"]
	var counts := [3,3,3,2,2]
	for index in 5:
		if view.filters[index].has_point(point):
			options[keys[index]] = (int(options[keys[index]])+1)%int(counts[index])
			options.page = 0
			options.selected = ""
			ui.combat_link_menu_motion.page_changed()
	var previous_page := int(options.page)
	var entries := cards(ui.run_build_state,options)
	var pages := maxi(1,ceili(float(entries.size())/PAGE_SIZE))
	options.page = clampi(int(options.page),0,pages-1)
	if view.previous.has_point(point): options.page = maxi(0,int(options.page)-1); options.selected = ""
	if view.next.has_point(point): options.page = mini(pages-1,int(options.page)+1); options.selected = ""
	if int(options.page) != previous_page: ui.combat_link_menu_motion.page_changed()
	if view.close.has_point(point): ui.hero_status_detail = ""
	for index in mini(PAGE_SIZE,entries.size()-int(options.page)*PAGE_SIZE):
		if view.cards[index].has_point(point):
			options.selected = entries[int(options.page)*PAGE_SIZE+index].id
			ui.combat_link_menu_motion.selected()
	ui.queue_redraw()
