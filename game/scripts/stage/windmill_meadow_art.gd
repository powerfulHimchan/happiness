class_name WindmillMeadowArt
extends RefCounted

## Code-native scenery: terrain and decoration share world coordinates, never a flattened panorama.
const INK := Color("294d49")
const GRASS := Color("78ad64")
const EDGE := Color("cee99c")
const WOOD := Color("9b7252")
const GOLD := Color("f0cd7c")

static func draw_map(map: WindmillMeadow) -> void:
	var center := map.player.position.x
	var left := center - 2200.0
	var right := center + 2600.0
	map.draw_rect(Rect2(left,-1900,4800,3300),Color("bde3ec"))
	map.draw_circle(Vector2(center + 740,-420),105,Color("fff1b6"))
	for band in 36:
		var ratio := float(band)/35.0
		map.draw_rect(Rect2(left,-900+band*50,4800,51),Color(0.89,0.95,0.84,ratio*0.30))
	for cloud in range(int(floor(left/1100))-1,int(ceil(right/1100))+1):
		var point := Vector2(cloud*1100+200, -280+80*sin(cloud*1.7))
		map.draw_circle(point,45,Color(1,1,0.95,0.55))
		map.draw_circle(point+Vector2(55,-25),65,Color(1,1,0.95,0.55))
		map.draw_circle(point+Vector2(120,0),42,Color(1,1,0.95,0.55))
	# Parallax-like distant ridgelines follow the camera more slowly than the foreground.
	for index in range(int(floor(left / 1200)) - 1, int(ceil(right / 1200)) + 1):
		var x := index * 1200.0
		map.draw_colored_polygon(PackedVector2Array([Vector2(x-400,900),Vector2(x+270,-180),Vector2(x+1000,900)]),Color("91bbc6"))
		map.draw_colored_polygon(PackedVector2Array([Vector2(x+270,-180),Vector2(x+110,60),Vector2(x+300,10),Vector2(x+420,80)]),Color("e1f0ed"))
		map.draw_colored_polygon(PackedVector2Array([Vector2(x-200,950),Vector2(x+600,330),Vector2(x+1450,950)]),Color("a6cfa3"))
	if right > 4500 and left < 9200:
		map.draw_rect(Rect2(4500,990,4700,300),Color("6fbcc7"))
		for x in range(4500,9200,100):
			if x < left or x > right: continue
			map.draw_line(Vector2(x,1010+sin(x+map.elapsed_s*2)*8),Vector2(x+55,1010+sin(x+map.elapsed_s*2)*8),Color("d1f1e6"),3)
	for x in range(int(floor(left/700))*700,int(ceil(right/700))*700,700):
		if x < 0 or x > 42000 or x > 4400 and x < 9300 or x > 23000 and x < 28200: continue
		var y := WindmillMeadowLayout.ground_height(x)
		var fence_color := Color("ad9a71")
		map.draw_line(Vector2(x,y-70),Vector2(x+380,y-70),fence_color,9,true)
		map.draw_line(Vector2(x,y-35),Vector2(x+380,y-35),fence_color,7,true)
		for post in 4: map.draw_line(Vector2(x+post*125,y),Vector2(x+post*125,y-100),fence_color,12,true)
	if right > 10300 and left < 15500: _farm(map)
	if right > 22600 and left < 27000: _mill(map)
	for rect in map.collision_surfaces():
		if rect.end.x < left or rect.position.x > right: continue
		var ledge := rect.size.y <= 40
		map.draw_rect(rect, WOOD if ledge and rect.position.x > 23000 and rect.position.x < 26500 else Color("97785b"))
		map.draw_rect(Rect2(rect.position,Vector2(rect.size.x,12)), EDGE)
		map.draw_rect(Rect2(rect.position + Vector2(0,12),Vector2(rect.size.x,16)), GRASS)
		for x in range(int(maxf(left,rect.position.x)+20),int(minf(right,rect.end.x)-15),85):
			map.draw_line(Vector2(x,rect.position.y+38),Vector2(x+24,rect.position.y+53),Color("b89970"),3)
			if ledge: continue
			map.draw_circle(Vector2(x+40,rect.position.y+75),7,Color("a58a68"))
			map.draw_circle(Vector2(x+49,rect.position.y+79),4,Color("8e7257"))
			map.draw_line(Vector2(x,rect.position.y),Vector2(x-5,rect.position.y-18),Color("59965b"),3)
			map.draw_circle(Vector2(x-5,rect.position.y-20),5,Color("fff5cb") if x%2 == 0 else Color("e9f1fd"))
	# Trees, gates, carts and windflowers interrupt the long silhouettes.
	for x in range(1300,42000,1650):
		if x < left or x > right or x > 4450 and x < 9250 or x > 23000 and x < 27200: continue
		_tree(map,Vector2(x,WindmillMeadowLayout.ground_height(x)))
		var ground_y := WindmillMeadowLayout.ground_height(x+400)
		map.draw_line(Vector2(x+400,ground_y-20),Vector2(x+400,ground_y-100),WOOD,12)
		map.draw_rect(Rect2(x+370,ground_y-115,220,50),Color("c89c69"))
		map.draw_string(ThemeDB.fallback_font,Vector2(x+390,ground_y-80),"풍차 →" if x < 25000 else "출구 →",HORIZONTAL_ALIGNMENT_LEFT,-1,25,INK)
	for index in WindmillMeadowLayout.ZONE_STARTS.size():
		var x: float = WindmillMeadowLayout.ZONE_STARTS[index] + 280.0
		if x < left or x > right: continue
		var y := WindmillMeadowLayout.ground_height(x)-190.0
		map.draw_line(Vector2(x,WindmillMeadowLayout.ground_height(x)),Vector2(x,y),WOOD,14)
		map.draw_rect(Rect2(x-40,y-55,370,85),Color("f9edcb"))
		map.draw_string(ThemeDB.fallback_font,Vector2(x-18,y),"%d  %s" % [index+1,WindmillMeadowLayout.ZONE_NAMES[index]],HORIZONTAL_ALIGNMENT_LEFT,-1,29,INK)
	if right > 3600 and left < 9200:
		_label(map,Vector2(3800,340),"위쪽: 적과 보물 / 아래쪽: 개울 징검다리")
	if not map.powered and right > 26600 and left < 28300:
		map.draw_line(Vector2(26900,860),Vector2(28200,860),WOOD,14)
		_label(map,Vector2(26650,660),"풍차를 작동시키면 바람 다리 개방")
	if map.powered:
		for zone in WindmillMeadowLayout.WIND_ZONES:
			if zone.end.x < left or zone.position.x > right: continue
			map.draw_rect(zone,Color(0.85,0.98,1,0.16))
			for column in 4:
				var x: float = zone.position.x+70+column*140
				var y: float = zone.end.y-fmod(map.elapsed_s*170+column*100,zone.size.y)
				map.draw_line(Vector2(x,y+110),Vector2(x,y),Color("e7ffff"),5,true)
				map.draw_line(Vector2(x,y),Vector2(x-15,y+22),Color("e7ffff"),5,true)
			_label(map,zone.position+Vector2(0,-25),"상승 기류 · 점프하면 위로")
	for index in WindmillMeadowLayout.REWARDS.size():
		var point: Vector2 = WindmillMeadowLayout.REWARDS[index]
		if point.x < left or point.x > right: continue
		var color := Color("9b8b6b") if map.claimed.has(index) else GOLD
		map.draw_rect(Rect2(point+Vector2(-36,-42),Vector2(72,44)),WOOD)
		map.draw_rect(Rect2(point+Vector2(-40,-53),Vector2(80,22)),color)
		map.draw_rect(Rect2(point+Vector2(-5,-35),Vector2(10,20)),color)
		if not map.claimed.has(index):
			map.draw_arc(point+Vector2(0,-30),62,0,TAU,32,Color(1,0.9,0.5,0.5),2,true)
			_label(map,point+Vector2(-95,-85),["체력 회복","필살기 충전","회복약 보충"][index])
	for barrier in map.barriers:
		if barrier.collision_layer == 0: continue
		map.draw_rect(Rect2(barrier.position.x-20,-400,40,1240),Color(0.94,0.65,0.3,0.28))
		for y in range(-300,840,100): map.draw_line(Vector2(barrier.position.x-22,y),Vector2(barrier.position.x+22,y+50),GOLD,6)
	if right > 40800:
		map.draw_line(Vector2(41500,840),Vector2(41500,520),WOOD,22)
		map.draw_line(Vector2(41900,840),Vector2(41900,520),WOOD,22)
		map.draw_line(Vector2(41450,520),Vector2(41950,520),WOOD,28)
		_label(map,Vector2(41480,450),"풍차 들판 출구 →")

static func _label(canvas: Node2D, point: Vector2, text: String) -> void:
	canvas.draw_string(ThemeDB.fallback_font,point+Vector2(2,2),text,HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("f5f6db"))
	canvas.draw_string(ThemeDB.fallback_font,point,text,HORIZONTAL_ALIGNMENT_LEFT,-1,26,INK)

static func _tree(canvas: Node2D, point: Vector2) -> void:
	canvas.draw_line(point,point+Vector2(15,-280),WOOD,26)
	canvas.draw_circle(point+Vector2(-65,-285),100,Color("6b9e70"))
	canvas.draw_circle(point+Vector2(80,-300),110,Color("82b67a"))
	canvas.draw_circle(point+Vector2(10,-380),115,Color("91c181"))
	for index in 9:
		var leaf := point+Vector2(-120+index*28,-290-45*sin(index*1.8))
		canvas.draw_circle(leaf,25,Color("8fbe7c") if index%2 == 0 else Color("7baa70"))
	canvas.draw_line(point+Vector2(3,-40),point+Vector2(14,-230),Color("bd9568"),6,true)

static func _farm(canvas: Node2D) -> void:
	for x in [11000,13400]:
		var roof_y := 570.0 if x == 11000 else 680.0
		canvas.draw_rect(Rect2(x,roof_y,950,840-roof_y),Color("b3936a"))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x-70,roof_y),Vector2(x+475,roof_y-250),Vector2(x+1020,roof_y)]),Color("7d6962"))
		for column in 10: canvas.draw_line(Vector2(x+column*95,roof_y),Vector2(x+column*95,840),WOOD,5)
		canvas.draw_rect(Rect2(x+300,roof_y+40,320,800-roof_y),Color("5c5c51"))
		canvas.draw_rect(Rect2(x+80,roof_y+30,120,60),GOLD.darkened(0.2))
	for x in [10350,12400,15150]:
		canvas.draw_rect(Rect2(x,730,260,85),WOOD)
		canvas.draw_circle(Vector2(x+45,815),35,INK)
		canvas.draw_circle(Vector2(x+220,815),35,INK)
		canvas.draw_rect(Rect2(x+30,670,200,65),Color("d9c38b"))

static func _mill(map: WindmillMeadow) -> void:
	# Cutaway walls leave the real stair platforms and combat actors readable.
	map.draw_rect(Rect2(23250,-180,2900,1020),Color("d5c7a4"))
	map.draw_colored_polygon(PackedVector2Array([Vector2(23050,-180),Vector2(24700,-700),Vector2(26350,-180)]),Color("89786b"))
	map.draw_rect(Rect2(23360,80,2670,760),Color("a59476"))
	for x in range(23400,26100,360): map.draw_line(Vector2(x,80),Vector2(x,840),Color("8e7c63"),9)
	var hub := Vector2(24700,-290)
	var angle := map.elapsed_s * (0.65 if map.powered else 0.0)
	for index in 4:
		var direction := Vector2.UP.rotated(angle+index*TAU/4)
		var side := direction.orthogonal()
		map.draw_line(hub,hub+direction*640,WOOD,22)
		map.draw_colored_polygon(PackedVector2Array([hub+direction*170,hub+direction*610,hub+direction*610+side*145,hub+direction*170+side*85]),Color("f4e7bc"))
	map.draw_circle(hub,75,WOOD)
	map.draw_circle(hub,42,GOLD)
	var device := WindmillMeadowLayout.DEVICE+Vector2(0,-55)
	map.draw_circle(device,55,Color("afc6af") if not map.powered else GOLD)
	map.draw_arc(device,70,0,TAU,32,INK,6,true)
	map.draw_line(device,device+Vector2(35,-50 if not map.powered else 20),WOOD,12)
	_label(map,device+Vector2(-235,-110),"바람길 개방 · 풍차 작동 중" if map.powered else "적 처치 후 장치 옆에서 잠시 멈추기")
	if map.device_hold_s > 0 and not map.powered:
		map.draw_arc(device,90,-PI/2,-PI/2+TAU*map.device_hold_s/0.8,32,GOLD,8,true)
