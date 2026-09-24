extends Node2D

## 원화가 준비되기 전 이동 방향과 속도 변화를 읽기 위한 임시 캐릭터다.


func _draw() -> void:
	# 그림자
	draw_ellipse(Vector2(0.0, 58.0), Vector2(42.0, 11.0), Color(0.02, 0.05, 0.08, 0.42))
	# 망토와 몸
	var cape := PackedVector2Array([
		Vector2(-30.0, -22.0),
		Vector2(-53.0, 42.0),
		Vector2(5.0, 48.0),
		Vector2(24.0, -18.0),
	])
	draw_colored_polygon(cape, Color("4f6bb8"))
	draw_rect(Rect2(-24.0, -26.0, 49.0, 69.0), Color("f5d76e"), true)
	# 머리와 머리카락
	draw_circle(Vector2(0.0, -52.0), 27.0, Color("ffe0b2"))
	draw_arc(Vector2(0.0, -57.0), 25.0, PI, TAU, 20, Color("4b3a53"), 13.0, true)
	# 진행 방향을 보여주는 검과 화살표
	draw_line(Vector2(18.0, -5.0), Vector2(55.0, 3.0), Color("e9f2f2"), 7.0)
	draw_line(Vector2(55.0, 3.0), Vector2(67.0, -4.0), Color("80d8d0"), 6.0)
	var arrow := PackedVector2Array([
		Vector2(73.0, -52.0),
		Vector2(48.0, -66.0),
		Vector2(48.0, -38.0),
	])
	draw_colored_polygon(arrow, Color("ffd166"))


func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 32:
		var angle := TAU * float(index) / 32.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
