class_name StartScreenBackdrop
extends Node2D

## One reusable background draw. A manual clock freezes while away/inactive.
const BACKGROUND: Texture2D = preload("res://assets/title/dawn-road.png")
const MOTION: Shader = preload("res://assets/title/dawn-motion.gdshader")
var elapsed_s := 0.0
var canvas_size := Vector2.ZERO


func _init() -> void:
	show_behind_parent = true
	var effect := ShaderMaterial.new()
	effect.shader = MOTION
	material = effect
	visible = false


func set_screen(dimensions: Vector2, on_title: bool) -> void:
	visible = on_title
	if dimensions != canvas_size:
		canvas_size = dimensions
		queue_redraw()


func tick(delta: float, on_title: bool, application_active: bool) -> void:
	if not on_title or not application_active:
		return
	elapsed_s = fposmod(elapsed_s + clampf(delta, 0.0, 0.1), 120.0)
	(material as ShaderMaterial).set_shader_parameter("elapsed_s", elapsed_s)


func _draw() -> void:
	if canvas_size.x <= 0.0 or canvas_size.y <= 0.0:
		return
	var image_size := BACKGROUND.get_size()
	var cover := maxf(canvas_size.x / image_size.x, canvas_size.y / image_size.y)
	var source_size := canvas_size / cover
	draw_texture_rect_region(BACKGROUND, Rect2(Vector2.ZERO, canvas_size), Rect2((image_size - source_size) * 0.5, source_size))


## Fixed particles use arithmetic phases, never the gameplay RNG.
func draw_motes(canvas: Control) -> void:
	var unit := canvas.size.y / 1000.0
	for index in 18:
		var phase := TAU * elapsed_s / 120.0
		var x := 0.43 + fposmod(float(index) * 0.137, 0.55)
		var y := 0.16 + fposmod(float(index) * 0.213, 0.78)
		var point := canvas.size * Vector2(x + sin(phase * 3.0 + index) * 0.015, y + sin(phase * 4.0 + index * 2.1) * 0.025)
		var alpha := (0.24 + 0.18 * sin(phase * 7.0 + index))
		canvas.draw_circle(point, (5.0 if index % 3 == 0 else 3.0) * unit, Color(1.0, 0.83, 0.44, alpha * 0.14))
		canvas.draw_circle(point, 1.35 * unit, Color(1.0, 0.94, 0.68, alpha))
