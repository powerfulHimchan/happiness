class_name WindmillMeadowLayout
extends RefCounted

## The illustration is compressed; these coordinates are the playable, camera-scrolled map.
const WIDTH := 42000.0
const TARGET_SECONDS := 300.0
const ZONE_STARTS := [0.0, 4200.0, 9800.0, 16400.0, 23400.0, 26400.0, 35200.0]
const ZONE_NAMES := ["들판 입구", "개울 갈림길", "버려진 농장", "풍차 진입로", "풍차 장치실", "바람꽃 둔덕", "출구 초원"]
const DEVICE := Vector2(25100, 180)
const WIND_BRIDGE := Rect2(26900, 840, 1300, 100)
const WIND_ZONES := [Rect2(28500, 200, 650, 640), Rect2(31800, 140, 650, 700)]
const REWARDS := [Vector2(7350, 430), Vector2(20500, 290), Vector2(32850, 210)]
const REQUIRED_ENCOUNTERS := ["farm_a", "farm_b", "mill_a", "mill_b", "hill_a", "hill_b", "elite"]

static func zone_at(x: float) -> int:
	for index in range(ZONE_STARTS.size() - 1, -1, -1):
		if x >= ZONE_STARTS[index]: return index
	return 0

static func surfaces() -> Array[Rect2]:
	var result: Array[Rect2] = [
		Rect2(0, 840, 2200, 420), Rect2(2200, 740, 1000, 520),
		Rect2(3200, 820, 1000, 440), Rect2(4200, 840, 300, 420),
		# Creek: broad low stepping stones; the high ridge is optional.
		Rect2(4500, 900, 500, 200), Rect2(5180, 900, 500, 200),
		Rect2(5860, 900, 500, 200), Rect2(6540, 900, 500, 200),
		Rect2(7220, 900, 500, 200), Rect2(7900, 900, 500, 200),
		Rect2(8580, 900, 500, 200), Rect2(9200, 840, 7200, 420),
		# A rolling approach, followed by the windmill courtyard.
		Rect2(16400, 760, 1000, 500), Rect2(17400, 650, 900, 610),
		Rect2(18300, 760, 1100, 500), Rect2(19400, 840, 1000, 420),
		Rect2(20400, 720, 1000, 540), Rect2(21400, 840, 5500, 420),
		# Wind bridge is absent until the windmill is powered.
		Rect2(28200, 840, 3000, 420), Rect2(31200, 720, 1000, 540),
		Rect2(32200, 600, 1000, 660), Rect2(33200, 720, 300, 540),
		Rect2(33500, 840, 2100, 420), Rect2(35600, 720, 700, 540),
		Rect2(36300, 600, 700, 660), Rect2(37000, 720, 400, 540),
		Rect2(37400, 840, 4600, 420),
	]
	return result

static func ledges() -> Array[Rect2]:
	var result: Array[Rect2] = []
	# Ascent to the creek ridge, <=150px rises and <=180px gaps.
	for index in 3:
		result.append(Rect2(3660 + index * 360, 720 - index * 150, 320, 28))
	result.append(Rect2(4740, 420, 3520, 40))
	for index in 3:
		result.append(Rect2(8380 + index * 320, 540 + index * 120, 280, 28))
	# Farm cart and roofs; these do not obstruct the ground route.
	result.append_array([Rect2(10400, 710, 580, 28), Rect2(11080, 570, 980, 32), Rect2(12300, 700, 540, 28), Rect2(13400, 680, 900, 32), Rect2(14700, 710, 460, 28)])
	# Exterior hill route rejoins the mill entrance.
	for index in 4:
		result.append(Rect2(16900 + index * 380, 720 - index * 120, 340, 28))
	result.append(Rect2(18420, 360, 2700, 40))
	for index in 3:
		result.append(Rect2(21200 + index * 380, 480 + index * 120, 340, 28))
	# Interior stair route to the device. The exterior route meets it at the top.
	for index in 5:
		result.append(Rect2(23400 + index * 340, 720 - index * 135, 320, 28))
	result.append(Rect2(25100, 180, 980, 40))
	# Exterior stairs, deliberately a little longer than the indoor route.
	for index in 5:
		result.append(Rect2(25800 + index * 230, 300 + index * 105, 300, 28))
	# Windflower shelves: all are reachable with the original single jump.
	for origin in [28400, 31600, 34300]:
		for index in 4:
			result.append(Rect2(origin + index * 280, 710 - index * 140, 250, 28))
		result.append(Rect2(origin + 1120, 290, 650, 32))
	return result

static func encounters() -> Array[Dictionary]:
	return [
		{"id":"entry", "trigger":Rect2(2600, -100, 900, 1100), "points":[Vector2(3300,780), Vector2(3650,780)], "lock":false},
		{"id":"ridge", "trigger":Rect2(5900, 200, 900, 300), "points":[Vector2(6700,360), Vector2(7200,360)], "lock":false},
		{"id":"farm_a", "trigger":Rect2(11800,-800,900,1900), "points":[Vector2(12400,780),Vector2(12900,780),Vector2(13250,570)], "lock":true, "left":11500.0, "right":14500.0},
		{"id":"farm_b", "trigger":Rect2(14600,-800,900,1900), "points":[Vector2(15150,780),Vector2(15700,780)], "lock":true, "left":14400.0, "right":16200.0},
		{"id":"approach", "trigger":Rect2(18300,150,900,350), "points":[Vector2(19200,300),Vector2(19900,300)], "lock":false},
		{"id":"mill_a", "trigger":Rect2(22400,-800,700,1900), "points":[Vector2(23000,780),Vector2(23300,780)], "lock":true, "left":22100.0, "right":23700.0},
		{"id":"mill_b", "trigger":Rect2(24700,-250,750,470), "points":[Vector2(25350,120),Vector2(25750,120)], "lock":true, "left":24400.0, "right":26200.0},
		{"id":"hill_a", "trigger":Rect2(29100,-800,600,1900), "points":[Vector2(29700,780),Vector2(30100,780),Vector2(30400,510)], "lock":true, "left":28900.0, "right":31200.0},
		{"id":"hill_b", "trigger":Rect2(33800,-800,600,1900), "points":[Vector2(34400,780),Vector2(34800,780),Vector2(35000,500)], "lock":true, "left":33500.0, "right":35600.0},
	]


static func ground_height(x: float) -> float:
	for rect in surfaces():
		if x >= rect.position.x and x < rect.end.x: return rect.position.y
	return 900.0
