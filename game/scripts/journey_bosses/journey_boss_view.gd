class_name JourneyBossView
extends RefCounted

static func layout(safe: Rect2, count: int) -> Dictionary:
	var choices: Array[Rect2] = []
	for i in count: choices.append(Rect2(safe.position+safe.size*Vector2(.46,.56+i*.09),safe.size*Vector2(.49,.072)))
	return {"portrait":Rect2(safe.position+safe.size*Vector2(.045,.20),safe.size*Vector2(.35,.58)),"title":Rect2(safe.position+safe.size*Vector2(.06,.06),safe.size*Vector2(.88,.095)),"choices":choices,"body":Rect2(safe.position+safe.size*Vector2(.46,.22),safe.size*Vector2(.49,.29)),"footer":Rect2(safe.position+safe.size*Vector2(.06,.90),safe.size*Vector2(.88,.065))}

static func draw(ui: Control) -> void:
	var state: Dictionary = ui.story_scene
	var safe: Rect2 = ui._safe_area_in_viewport()
	var view := layout(safe,state.actions.size())
	ui.draw_texture_rect(JourneyBossProgress.ARENAS[state.boss],Rect2(Vector2.ZERO,ui.size),false)
	ui.draw_rect(Rect2(Vector2.ZERO,ui.size),Color(.025,.06,.10,.75))
	ui.draw_texture_rect(JourneyBoss.ART[state.boss],SupplyShopArt.fitted(JourneyBoss.ART[state.boss],view.portrait),false)
	ui._draw_village_text(state.name,view.title,32,Color("ffe2a1"))
	var unit := safe.size.y/1080.0
	var y: float = view.body.position.y
	for paragraph in state.lines:
		var lines := PrototypeStoryView.wrap(paragraph,ThemeDB.fallback_font,int(27*unit),view.body.size.x)
		for line in lines:
			ui._draw_text(line,Vector2(view.body.position.x,y+26*unit),int(27*unit),Color("f5f0dd"))
			y += 34*unit
		y += 10*unit
	for i in state.actions.size(): ui._draw_button(view.choices[i],state.actions[i].name,state.actions[i].get("enabled",true))
	ui._draw_village_text(ui.story_message if not ui.story_message.is_empty() else state.footer,view.footer,19,Color("b8dfd8"))
