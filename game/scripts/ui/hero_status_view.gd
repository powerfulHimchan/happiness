class_name HeroStatusView
extends RefCounted

const PAGE_LINES := 7
const INK := Color("e9f2fb")
const MUTE := Color("9ab2c2")
const GOLD := Color("ffd166")
const PANEL := Color("193b4c")

static func box(safe: Rect2,x: float,y: float,w: float,h: float) -> Rect2:
	return Rect2(safe.position+safe.size*Vector2(x,y),safe.size*Vector2(w,h))

static func return_rect(safe: Rect2) -> Rect2:
	return box(safe,.81,.13,.15,.065)

static func layout(safe: Rect2) -> Dictionary:
	var gear: Array[Rect2] = []
	var skills: Array[Rect2] = []
	for index in 2:
		gear.append(box(safe,.61+index*.185,.17,.17,.26))
		for slot in 2: skills.append(box(safe,.61+index*.185,.45+slot*.09,.17,.078))
	return {"portrait":box(safe,.035,.17,.21,.65),"stats":box(safe,.265,.17,.325,.40),"gear":gear,"skills":skills,"defense":box(safe,.28,.595,.145,.07),"offense":box(safe,.44,.595,.135,.07),"passive":box(safe,.265,.70,.325,.12),"conditions":box(safe,.61,.66,.355,.07),"browse":box(safe,.28,.865,.30,.08),"back":box(safe,.62,.865,.345,.08),"modal":box(safe,.10,.14,.80,.72),"previous":box(safe,.14,.755,.18,.065),"next":box(safe,.68,.755,.18,.065),"close":box(safe,.37,.755,.26,.065)}

static func families(state: Dictionary) -> Array:
	var result := [String(state.get("active","sword"))]
	for family in state.get("equipment",{}):
		if family != result[0]: result.append(String(family))
	return result

static func inspect(id: String,state: Dictionary) -> Dictionary:
	if state.is_empty(): return {}
	var parts := id.split(":")
	var stats: Dictionary = state.get("combat_stats",{})
	var sources: Dictionary = state.get("stat_sources",{})
	var active := String(state.active)
	var family_stats: Dictionary = state.get("family_stats",{}).get(active,{})
	var title := ""
	var status := ""
	var lines: Array[String] = []
	match parts[0]:
		"weapon":
			if parts.size() != 2 or not state.equipment.has(parts[1]): return {}
			var family := String(parts[1])
			var item := PrototypeWeaponRewards.profile(family,int(state.equipment[family]),String(state.blueprints[family]))
			title = String(item.name)
			status = "주 무기" if family == active else "보조 무기"
			for line in item.lines: lines.append(String(line))
			var values: Dictionary = state.get("family_stats",{}).get(family,{})
			lines.append("기본 피해100 기준 · 기본%d / 스킬%d" % [state.damage[family].basic,state.damage[family].skill])
			lines.append("치명타 확률 %.1f%% · 치명타 피해 %.1f%%" % [float(values.get("chance",0)),float(values.get("damage",150))])
			lines.append("공격형 필살기 치명타 피해 %.1f%%" % float(values.get("ultimate_damage",150)))
		"skill":
			if parts.size() != 3 or parts[2] not in ["0","1"] or not state.skills.has(parts[1]): return {}
			var family := String(parts[1])
			var slot := int(parts[2])
			var skill_id := String(state.skills[family][slot])
			title = String(PrototypeSkillRewards.SKILLS[skill_id].display_name)
			status = "%s · 슬롯%d · %s" % [PrototypeWeaponRewards.family_name(family),slot+1,"주 무기" if family == active else "보조 무기"]
			for line in PrototypeSkillRewards.lines(skill_id,float(state.get("family_recharge",{}).get(family,state.recharge))): lines.append(String(line))
			lines.append("남은 재사용 대기 %.1f초" % float(state.cooldowns[family][slot]))
			var hits: Array = state.get("skill_damage",{}).get(family,[[],[]])[slot]
			var hit_labels: Array[String] = []
			for value in hits: hit_labels.append(str(int(value)))
			lines.append("현재 조건의 타격 피해 · "+(" / ".join(hit_labels) if not hit_labels.is_empty() else "공격 피해 없음"))
			lines.append("실제 피해는 거리·적 방어·치명타에 따라 달라집니다")
		"passive":
			var passive: Dictionary = state.get("hero_trait",{})
			title = String(passive.get("name","고유 특성"))
			status = String(passive.get("status",""))
			for line in passive.get("lines",[]): lines.append(String(line))
		"defense":
			title = "방어력과 생존"
			status = "방어력 %d · 피해 감소 %.1f%%" % [int(stats.get("defense",0)),float(stats.get("damage_reduction",0))]
			lines.assign(["단련으로 얻은 방어력 %d" % int(sources.get("base_defense",0)),"현재 특화 방어력 +%d" % int(sources.get("specializations",{}).get("defense",0)),"방어력 감소율 = 방어력 ÷ (100 + 방어력)","방벽 %d / %d · 체력보다 먼저 흡수" % [state.health.barrier,state.health.barrier_max],"추가 받는 피해 배율 %.2f배" % float(state.health.get("incoming_multiplier",1)),"체력 %d / %d" % [state.health.current,state.health.maximum],"낙하 체력 비용에는 방어력이 적용되지 않습니다"])
		"offense":
			title = "공격력과 치명타"
			status = PrototypeWeaponRewards.family_name(active)+" 기준"
			lines.assign(["기본 공격력 %d + 성장 %d" % [int(sources.get("base_attack",100)),int(sources.get("growth_attack",0))],"고유 특성 공격력 배율 %.2f배" % float(sources.get("trait_multiplier",1)),"현재 공격력 %d" % int(stats.get("attack",100)),"기본 치명타 확률 %.1f%% + 특화 %.1f%%p" % [float(sources.get("base_chance",0)),float(sources.get("specializations",{}).get("chance",0))],"현재 치명타 확률 %.1f%% (최대100%%)" % float(stats.get("critical_chance",0)),"현재 치명타 피해 %.1f%%" % float(stats.get("critical_damage",150)),"필살기 치명타 피해 %.1f%%" % float(family_stats.get("ultimate_damage",150)),"무기별 피해 강화는 장비 상세에서 확인할 수 있습니다"])
		"conditions":
			title = "능력치 특화 조건"
			status = PrototypeWeaponRewards.family_name(active)+" · 현재 체력과 방벽 기준"
			for line in state.get("stat_conditions",[]): lines.append(String(line))
			if lines.is_empty(): lines.append("아직 능력치 특화를 획득하지 않았습니다")
		_:
			return {}
	return {"id":id,"title":title,"status":status,"lines":lines}

static func panel(ui: Control,rect: Rect2,color: Color = PANEL) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("4c7385")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	ui.draw_style_box(style,rect)

static func text(ui: Control,label: String,rect: Rect2,size: int = 23,color: Color = INK) -> void:
	ui._draw_village_text(label,rect,size,color)

static func draw(ui: Control) -> void:
	var safe: Rect2 = ui._safe_area_in_viewport()
	var view := layout(safe)
	var state: Dictionary = ui.run_build_state
	var stats: Dictionary = state.get("combat_stats",{})
	var character := String(state.get("character_id","roan"))
	var held := families(state)
	HeroStatusArt.background(ui)
	text(ui,"주인공 상태",box(safe,.25,.035,.50,.065),34,GOLD)
	text(ui,"장비와 스킬을 눌러 자세한 효과를 확인하세요",box(safe,.18,.105,.64,.035),18,MUTE)
	panel(ui,view.portrait,Color("193b4c",.88))
	text(ui,PrototypeCharacters.display_name(character),box(safe,.055,.19,.17,.05),28,GOLD)
	var portrait := RunPreparationView.portrait(character)
	ui.draw_texture_rect(portrait,SupplyShopArt.fitted(portrait,box(safe,.045,.25,.19,.38)),false)
	var job := PrototypeJobProgress.profile(String(state.growth.growth_job_id))
	text(ui,String(job.get("name","직업 미발현")),box(safe,.05,.64,.18,.04),19,MUTE)
	text(ui,"체력 %d / %d" % [state.health.current,state.health.maximum],box(safe,.05,.69,.18,.04),22)
	var bar := box(safe,.06,.74,.16,.018)
	ui.draw_rect(bar,Color("152a34"))
	ui.draw_rect(Rect2(bar.position,Vector2(bar.size.x*clampf(float(state.health.current)/maxf(1,float(state.health.maximum)),0,1),bar.size.y)),Color("66d9ac"))
	text(ui,"레벨 %d · 방벽 %d" % [state.growth.growth_level,state.health.barrier],box(safe,.045,.775,.19,.03),18,MUTE)
	panel(ui,view.stats)
	text(ui,"현재 능력치",box(safe,.28,.19,.295,.045),25,GOLD)
	var labels := ["공격력","방어력","치명타 확률","치명타 피해","체력"]
	var values := [str(int(stats.get("attack",100))),str(int(stats.get("defense",0))),"%.1f%%" % float(stats.get("critical_chance",0)),"%.1f%%" % float(stats.get("critical_damage",150)),"%d / %d" % [state.health.current,state.health.maximum]]
	for index in 5:
		var areas := HeroStatusArt.stat_regions(safe,index)
		HeroStatusArt.icon(ui,HeroStatusArt.STAT_IDS[index],areas.icon)
		text(ui,labels[index],areas.label,22)
		text(ui,values[index],areas.value,24)
	ui._draw_button(view.defense,"방어 상세",true)
	ui._draw_button(view.offense,"공격 상세",true)
	panel(ui,view.passive)
	var passive: Dictionary = state.get("hero_trait",{})
	var passive_areas := HeroStatusArt.passive_regions(safe)
	HeroStatusArt.icon(ui,character,passive_areas.icon)
	text(ui,String(passive.get("name","고유 특성")),passive_areas.name,23,GOLD)
	text(ui,String(passive.get("status","")),passive_areas.status,18)
	for index in mini(2,held.size()):
		var family := String(held[index])
		var rect: Rect2 = view.gear[index]
		var item := PrototypeWeaponRewards.profile(family,int(state.equipment[family]),String(state.blueprints[family]))
		panel(ui,rect,Color("265366") if index == 0 else PANEL)
		HeroStatusArt.gear_frame(ui,rect,index == 0)
		text(ui,"주 무기" if index == 0 else "보조 무기",Rect2(rect.position+rect.size*Vector2(.05,.045),rect.size*Vector2(.90,.14)),19,GOLD if index == 0 else MUTE)
		SupplyShopArt.draw_symbol(ui,family,Rect2(rect.position+rect.size*Vector2(.25,.24),rect.size*Vector2(.50,.40)))
		text(ui,String(item.name),Rect2(rect.position+rect.size*Vector2(.04,.70),rect.size*Vector2(.92,.20)),21)
		for slot in 2:
			var skill_id := String(state.skills[family][slot])
			var skill_rect: Rect2 = view.skills[index*2+slot]
			panel(ui,skill_rect)
			text(ui,String(PrototypeSkillRewards.SKILLS[skill_id].display_name),Rect2(skill_rect.position+skill_rect.size*Vector2(.04,.06),skill_rect.size*Vector2(.92,.43)),19)
			var remaining := float(state.cooldowns[family][slot])
			text(ui,"준비 완료" if remaining <= 0 else "%.1f초" % remaining,Rect2(skill_rect.position+skill_rect.size*Vector2(.05,.55),skill_rect.size*Vector2(.90,.32)),16,MUTE)
	ui._draw_button(view.conditions,"특화 조건 · %d개" % state.get("stat_conditions",[]).size(),true)
	text(ui,PrototypeRelic.hud(state.relic),box(safe,.615,.75,.345,.035),18,MUTE)
	text(ui,String(PrototypeMemoryAbilities.profile(String(state.memory)).name),box(safe,.615,.795,.345,.03),18,MUTE)
	ui._draw_button(view.browse,"보유 능력·장비 목록",true)
	ui._draw_button(view.back,"전투로 돌아가기",true)
	if not ui.hero_status_detail.is_empty(): draw_detail(ui,safe,view)

static func draw_detail(ui: Control,safe: Rect2,view: Dictionary) -> void:
	var entry := inspect(String(ui.hero_status_detail),ui.run_build_state)
	if entry.is_empty(): return
	ui.draw_rect(Rect2(Vector2.ZERO,ui.size),Color(0.01,.04,.07,.83))
	panel(ui,view.modal,Color("193644"))
	var detail_symbol := HeroStatusArt.detail_icon(String(ui.hero_status_detail),String(ui.run_build_state.get("character_id","roan")))
	if not detail_symbol.is_empty(): HeroStatusArt.icon(ui,detail_symbol,box(safe,.145,.18,.045,.065))
	text(ui,String(entry.title),box(safe,.205,.18,.63,.065) if not detail_symbol.is_empty() else box(safe,.14,.18,.72,.065),30,GOLD)
	text(ui,String(entry.status),box(safe,.14,.27,.72,.045),21,MUTE)
	var pages := maxi(1,ceili(float(entry.lines.size())/PAGE_LINES))
	var page := clampi(ui.hero_status_page,0,pages-1)
	for index in mini(PAGE_LINES,entry.lines.size()-page*PAGE_LINES):
		text(ui,String(entry.lines[page*PAGE_LINES+index]),box(safe,.14,.355+index*.052,.72,.043),21)
	ui._draw_button(view.previous,"이전",page > 0)
	ui._draw_button(view.next,"다음",page < pages-1)
	ui._draw_button(view.close,"상태로 돌아가기",true)
	text(ui,"%d / %d" % [page+1,pages],box(safe,.43,.825,.14,.025),17,MUTE)

static func handle_touch(ui: Control,point: Vector2) -> void:
	var view := layout(ui._safe_area_in_viewport())
	if not ui.hero_status_detail.is_empty():
		var entry := inspect(String(ui.hero_status_detail),ui.run_build_state)
		var pages := maxi(1,ceili(float(entry.get("lines",[]).size())/PAGE_LINES))
		if view.close.has_point(point):
			ui.hero_status_detail = ""
			ui.hero_status_page = 0
		elif view.previous.has_point(point): ui.hero_status_page = maxi(0,ui.hero_status_page-1)
		elif view.next.has_point(point): ui.hero_status_page = mini(pages-1,ui.hero_status_page+1)
		ui.queue_redraw()
		return
	if view.back.has_point(point):
		ui.close_run_build()
		return
	if view.browse.has_point(point):
		ui.hero_status_open = false
		ui.queue_redraw()
		return
	var held := families(ui.run_build_state)
	for index in mini(2,held.size()):
		if view.gear[index].has_point(point): ui.hero_status_detail = "weapon:"+String(held[index])
		for slot in 2:
			if view.skills[index*2+slot].has_point(point): ui.hero_status_detail = "skill:%s:%d" % [held[index],slot]
	for id in ["defense","offense","passive","conditions"]:
		if view[id].has_point(point): ui.hero_status_detail = id
	ui.hero_status_page = 0
	ui.queue_redraw()
