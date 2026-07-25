extends RefCounted

var start := Vector2.ZERO
var end := Vector2.ZERO
var glow_color := Color.TRANSPARENT
var core_color := Color.TRANSPARENT
var head_color := Color.TRANSPARENT
var width := 0.0
var core_width := 0.0
var head_radius := 0.0
var alpha := 0.0


func draw(canvas: CanvasItem, beams: Array[Dictionary], center: Vector2) -> void:
	if canvas == null:
		return
	for beam: Dictionary in beams:
		if not project(beam, center):
			continue
		canvas.draw_line(start, end, glow_color, width)
		canvas.draw_line(start, end, core_color, core_width)
		canvas.draw_circle(end, head_radius, head_color)


func project(beam: Dictionary, center: Vector2) -> bool:
	alpha = 0.0
	var age := float(beam.get("age", 0.0))
	var life := float(beam.get("life", 0.5))
	if life <= 0.0:
		return false
	var extension := clampf(age / maxf(0.01, float(beam.get("extend_time", 0.12))), 0.0, 1.0)
	var extension_eased := 1.0 - pow(1.0 - extension, 3.0)
	var head := float(beam.get("max_len", 600.0)) * extension_eased
	var inner := 16.0
	if head <= inner:
		return false
	var angle := float(beam.get("angle", 0.0))
	var direction := Vector2(cos(angle), sin(angle))
	start = center + direction * inner
	end = center + direction * head
	var fade_in := clampf(age / 0.07, 0.0, 1.0)
	var fade_out := clampf((life - age) / maxf(0.01, life * 0.5), 0.0, 1.0)
	alpha = fade_in * fade_out
	if alpha <= 0.001:
		return false
	var base_color: Color = beam.get("color", Color(1.0, 0.85, 0.45))
	width = float(beam.get("width", 4.0))
	core_width = maxf(1.5, width * 0.32)
	head_radius = clampf(width * 0.6, 2.0, 14.0)
	glow_color = Color(base_color.r, base_color.g, base_color.b, alpha * 0.45)
	core_color = Color(1.0, 1.0, 0.96, alpha * 0.9)
	head_color = Color(1.0, 1.0, 0.95, alpha * 0.85)
	return true
