class_name TaskBoardDetailArt
extends RefCounted

const CREST := preload("res://assets/tasks/compass_crest.svg")
const LINK := preload("res://assets/tasks/partnership_link.svg")
const SATCHEL := preload("res://assets/tasks/service_satchel.svg")
const MEDAL := preload("res://assets/tasks/reward_medal.svg")
const READY := preload("res://assets/tasks/ready_wax.svg")
const CLAIMED := preload("res://assets/tasks/claimed_stamp.svg")
const LOCKED := preload("res://assets/tasks/locked_plate.svg")
const CORNERS := preload("res://assets/tasks/selection_corners.svg")
const EMPTY := preload("res://assets/tasks/empty_trail.svg")

static func emblem(ui: Control, card: Dictionary, rect: Rect2, color: Color, offset: Vector2, pulse: float) -> void:
	var center := rect.get_center()+offset
	var icon_rect := Rect2(center-rect.size*.5,rect.size)
	ui.draw_circle(center,rect.size.x*.60,Color(color,.10))
	ui.draw_arc(center,rect.size.x*.60,-PI*.75,PI*.75,24,Color(color,.45),1,true)
	if card.has("families"):
		var side := rect.size.x*.68*(1+pulse*.06)
		for index in 2:
			var item := Rect2(center+Vector2((-0.44 if index == 0 else .02)*rect.size.x,-side*.5),Vector2.ONE*side)
			SupplyShopArt.draw_symbol(ui,card.families[index],item,SupplyShopArt.ACCENTS.get(card.families[index],color))
		ui.draw_texture_rect(LINK,Rect2(center+Vector2(-8,7),Vector2(16,16)),false)
	elif card.get("category","") == "trade":
		ui.draw_texture_rect(SATCHEL,SupplyShopArt.fitted(SATCHEL,icon_rect),false)
	else:
		var icon := TaskBoardArt.symbol(card)
		if TaskBoardArt.ICONS.has(icon): ui.draw_texture_rect(TaskBoardArt.ICONS[icon],SupplyShopArt.fitted(TaskBoardArt.ICONS[icon],icon_rect),false,color)
		else: SupplyShopArt.draw_symbol(ui,icon,icon_rect,color)

static func progress(ui: Control, card: Dictionary, rect: Rect2, value: float, color: Color) -> void:
	ui.draw_rect(rect.grow(1),Color("49616a"))
	ui.draw_rect(rect,Color("102631"))
	ui.draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(value,0,1),rect.size.y)),color)
	var count: int = card.get("conditions",[]).size()
	if count > 1:
		for index in range(1,count):
			var x: float = rect.position.x+rect.size.x*float(index)/count
			ui.draw_line(Vector2(x,rect.position.y),Vector2(x,rect.end.y),Color("102631"),2)

static func chrome(ui: Control, rect: Rect2, color: Color, selected: bool, pose: Dictionary) -> void:
	if float(pose.get("ready",0)) > .001:
		ui.draw_rect(rect.grow(-4),Color(color,.28*float(pose.ready)),false,2)
	if selected:
		var frame := rect.grow(-3)
		for index in 4:
			var right := index%2 == 1
			var bottom := index >= 2
			var position := Vector2(frame.end.x-18 if right else frame.position.x,frame.end.y-18 if bottom else frame.position.y)
			ui.draw_texture_rect_region(CORNERS,Rect2(position,Vector2.ONE*18),Rect2(Vector2(96 if right else 0,96 if bottom else 0),Vector2.ONE*32),Color(Color.WHITE,.75+.25*float(pose.get("selection",0))))
	if float(pose.get("query",0)) > .001:
		ui.draw_line(rect.position+Vector2(10,3),rect.position+Vector2(rect.size.x-10,3),Color(color,.55*float(pose.query)),2,true)

static func seal(ui: Control, status: String, rect: Rect2, pulse: float) -> void:
	var texture: Texture2D = {"ready":READY,"claimed":CLAIMED,"unavailable":LOCKED}.get(status)
	if texture != null:
		var scale_factor := 1.0+0.08*pulse
		ui.draw_texture_rect(texture,Rect2(rect.get_center()-rect.size*scale_factor*.5,rect.size*scale_factor),false)

static func empty(ui: Control, safe: Rect2, alpha: float) -> void:
	var rect := Rect2(safe.position+safe.size*Vector2(.46,.38),safe.size*Vector2(.08,.16))
	ui.draw_texture_rect(EMPTY,SupplyShopArt.fitted(EMPTY,rect),false,Color(Color.WHITE,alpha))
	ui._draw_village_text("이 조건에 맞는 과제가 없습니다",Rect2(safe.position+safe.size*Vector2(.15,.55),safe.size*Vector2(.70,.06)),22,Color("d6e5ec"))
	ui._draw_village_text("분류나 무기를 바꾸거나 조건을 초기화하세요",Rect2(safe.position+safe.size*Vector2(.15,.615),safe.size*Vector2(.70,.05)),16,Color("a5bfc3"))

static func effects(ui: Control, safe: Rect2, motion: TaskBoardMotion) -> void:
	if motion.press_age < TaskBoardMotion.PRESS:
		var progress := motion.press_age/TaskBoardMotion.PRESS
		# Keep every ripple inside the viewport, including edge controls.
		var center := motion.press_position.clamp(safe.position+Vector2.ONE*18,safe.end-Vector2.ONE*18)
		ui.draw_arc(center,4+progress*12,0,TAU,24,Color(Color("ffe4a0"),.55*(1-progress)),1.5,true)
	var origin := safe.position+safe.size*Vector2(.73,.84)
	for particle in motion.particles():
		ui.draw_circle(origin+particle.offset,particle.radius,Color(Color("ffe4a0"),particle.alpha))
	if motion.claim_coins > 0:
		ui._draw_village_text("+%d전" % motion.claim_coins,Rect2(origin+Vector2(-55,-60-motion.claim_age*24),Vector2(110,30)),23,Color(Color("ffe4a0"),1-motion.claim_age/TaskBoardMotion.CLAIM))
