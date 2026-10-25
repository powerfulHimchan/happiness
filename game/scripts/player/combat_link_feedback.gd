class_name CombatLinkFeedback
extends RefCounted

## Reads successful link windows only. No signals, RNG, damage or checkpoint writes.
const BURST_DURATION := 0.46
const END_DURATION := 0.32
const MAX_BURSTS := 6
var clock_s := 0.0
var previous: Dictionary = {}
var active: Dictionary = {}
var bursts: Array[Dictionary] = []

static func summarize(windows: Dictionary) -> Dictionary:
	var result := {}
	for id in windows:
		var parts: PackedStringArray = String(id).split("_link_")
		if parts.size() == 2 and parts[1] in PrototypeCombatLinks.STYLES and float(windows[id]) > 0.0:
			result[parts[1]] = maxf(float(result.get(parts[1],0.0)),float(windows[id]))
	return result

func reset(baseline: Dictionary = {}) -> void:
	clock_s = 0.0
	previous = baseline.duplicate()
	active = summarize(baseline)
	bursts.clear()

func _emit(style: String, ending: bool) -> void:
	for index in range(bursts.size()-1,-1,-1):
		if bursts[index].style == style: bursts.remove_at(index)
	bursts.append({"style":style,"ending":ending,"age":0.0})
	if bursts.size() > MAX_BURSTS: bursts.pop_front()

func update(windows: Dictionary, delta: float, hidden: bool = false) -> void:
	if hidden:
		reset(windows)
		active.clear()
		return
	var dt := maxf(0.0,delta)
	clock_s = fposmod(clock_s+dt,TAU*8.0)
	for index in range(bursts.size()-1,-1,-1):
		bursts[index].age += dt
		if float(bursts[index].age) >= (END_DURATION if bursts[index].ending else BURST_DURATION): bursts.remove_at(index)
	var before := summarize(previous)
	active = summarize(windows)
	var triggered := {}
	for id in windows:
		if float(windows[id]) > float(previous.get(id,0.0))+0.00001:
			var parts: PackedStringArray = String(id).split("_link_")
			if parts.size() == 2 and parts[1] in PrototypeCombatLinks.STYLES: triggered[parts[1]] = true
	for style in PrototypeCombatLinks.STYLES:
		if triggered.has(style): _emit(style,false)
		elif before.has(style) and not active.has(style): _emit(style,true)
	previous = windows.duplicate()

static func origin(style: String) -> Vector2:
	return Vector2((PrototypeCombatLinks.STYLES.find(style)-2.5)*24.0,-112)

func pose(style: String) -> Dictionary:
	var position := origin(style)
	var scale_factor := 1.0
	var rotation := 0.0
	var alpha := 1.0
	for burst in bursts:
		if burst.style != style or burst.ending: continue
		var t := clampf(float(burst.age)/BURST_DURATION,0,1)
		match style:
			"switch": rotation = sin(t*TAU)*.28
			"evade": position.x -= pow(1.0-t,2.0)*10.0
			"critical": scale_factor += sin(t*PI)*.30
			"hurt": position.x += sin(t*TAU*2.0)*3.0*(1.0-t)
			"potion": position.y -= sin(t*PI)*5.0
			"skill": position.y += pow(1.0-t,2.0)*8.0
	if active.has(style) and float(active[style]) <= 1.0:
		var breath := (1.0+sin(clock_s*6.0))*.5
		scale_factor += breath*.06
		alpha = .82+breath*.18
	return {"position":position,"scale":scale_factor,"rotation":rotation,"alpha":alpha}

func draw(canvas: Node2D) -> void:
	for burst in bursts:
		var center := origin(burst.style)
		var t := clampf(float(burst.age)/(END_DURATION if burst.ending else BURST_DURATION),0,1)
		var color := Color(CombatLinksArt.COLORS[burst.style],pow(1.0-t,2.0)*.85)
		if burst.ending:
			CombatLinksArt.icon(canvas,burst.style,Rect2(center-Vector2.ONE*(10.0-4.0*t),Vector2.ONE*(20.0-8.0*t)),1.0-t)
			for side in [-1,1]: canvas.draw_arc(center+Vector2(side*t*8.0,-t*4.0),12.0+t*10.0,PI*.1,PI*.9,16,color,1.5,true)
			continue
		match String(burst.style):
			"switch":
				for side in [0,1]: canvas.draw_arc(center,13.0+t*12.0,t*TAU+side*PI,t*TAU+side*PI+PI*.65,20,color,2.0,true)
			"evade":
				for index in 3:
					var tip := center+Vector2(-6.0+t*18.0,(index-1)*7.0)
					canvas.draw_line(tip-Vector2(18.0*(1.0-t),0),tip,color,2.0,true)
			"critical":
				for index in 8:
					var point := center+Vector2(12+t*22,0).rotated(index*TAU/8.0)
					var size := 3.0*(1.0-t)
					canvas.draw_colored_polygon(PackedVector2Array([point+Vector2(0,-size*2),point+Vector2(size,0),point+Vector2(0,size*2),point-Vector2(size,0)]),color)
			"hurt":
				var size := 12.0+t*15.0
				canvas.draw_polyline(PackedVector2Array([center+Vector2(-size,-size*.6),center+Vector2(0,-size),center+Vector2(size,-size*.6),center+Vector2(size*.8,size*.4),center+Vector2(0,size),center+Vector2(-size*.8,size*.4),center+Vector2(-size,-size*.6)]),color,2.0,true)
			"potion":
				for index in 5:
					var point := center+Vector2(10.0+t*18.0,0).rotated(index*TAU/5.0+t*PI*.5)+Vector2(0,-t*12.0)
					canvas.draw_colored_polygon(PackedVector2Array([point+Vector2(0,-5),point+Vector2(3,0),point+Vector2(0,5),point-Vector2(3,0)]),color)
			"skill":
				for index in 3:
					var point := center+Vector2((index-1)*14,-8-t*25-index*3)
					canvas.draw_polyline(PackedVector2Array([point+Vector2(-4,0),point+Vector2(0,-6),point+Vector2(4,0),point+Vector2(0,6)]),color,2.0,true)
	for style in PrototypeCombatLinks.STYLES:
		if not active.has(style): continue
		var state := pose(style)
		canvas.draw_set_transform(state.position,state.rotation,Vector2.ONE*float(state.scale))
		CombatLinksArt.icon(canvas,style,Rect2(-10,-10,20,20),state.alpha)
		canvas.draw_set_transform(Vector2.ZERO)
		if float(active[style]) <= 1.0: canvas.draw_arc(state.position,13, -PI*.5,-PI*.5+TAU*float(active[style]),24,Color(CombatLinksArt.COLORS[style],state.alpha),1.5,true)
