extends RefCounted

const SCORE_PIP_COUNT := 3
const SCORE_PIP_COUNT_LOD := 2
const SPARKLE_SWEEP_WIDTH_SCALE := 12.0
const SPARKLE_SWEEP_WIDTH_SCALE_LOD := 6.0


func draw_score_pips(canvas: Node2D, rect: Rect2, scale_factor: float, sparkle_intensity: float, quality_scale: float = 1.0) -> void:
	var pip_radius: float = max(1.6, 2.0 * scale_factor)
	var pip_color: Color = Color(1.0, 215.0 / 255.0, 96.0 / 255.0, (150.0 + 65.0 * sparkle_intensity) / 255.0)
	var inset_x: float = max(5.0, 6.0 * scale_factor)
	var inset_y: float = max(4.0, 5.0 * scale_factor)
	var centers := [
		rect.position + Vector2(inset_x, inset_y),
		Vector2(rect.end.x - inset_x, rect.position.y + inset_y),
		Vector2(rect.position.x + inset_x, rect.end.y - inset_y),
		rect.end - Vector2(inset_x, inset_y),
	]
	var pip_count: int = SCORE_PIP_COUNT_LOD if quality_scale < 0.85 else SCORE_PIP_COUNT
	for pip_index in range(pip_count):
		var center: Vector2 = centers[pip_index]
		canvas.draw_circle(center, pip_radius * 1.8, Color(pip_color.r, pip_color.g, pip_color.b, pip_color.a * 0.18))
		canvas.draw_circle(center, pip_radius, pip_color)


func draw_sparkles(
	canvas: Node2D,
	rect: Rect2,
	scale_factor: float,
	sparkle_progress: float,
	sparkle_intensity: float,
	quality_scale: float = 1.0
) -> void:
	if sparkle_intensity <= 0.1:
		return

	var lod_active: bool = quality_scale < 0.85
	var sweep_width_scale: float = SPARKLE_SWEEP_WIDTH_SCALE_LOD if lod_active else SPARKLE_SWEEP_WIDTH_SCALE
	var sweep_width: int = max(8, int(sweep_width_scale * scale_factor))
	var sweep_alpha: float = (120.0 / 255.0) * sparkle_intensity
	var sweep_x: float = rect.position.x + rect.size.x * 1.5 * sparkle_progress - rect.size.x * 0.25
	for i in range(sweep_width):
		var center_delta: float = abs(float(i) - float(sweep_width) * 0.5) / max(1.0, float(sweep_width) * 0.5)
		var line_alpha: float = sweep_alpha * (1.0 - center_delta)
		var line_x: float = sweep_x + float(i)
		if line_x >= rect.position.x and line_x <= rect.end.x:
			canvas.draw_line(
				Vector2(line_x, rect.position.y),
				Vector2(line_x - 15.0 * scale_factor, rect.end.y),
				Color(1.0, 1.0, 220.0 / 255.0, line_alpha),
				1.0
			)

	if sparkle_intensity <= 0.5 or lod_active:
		return

	var star_size: float = (3.0 + 2.0 * sparkle_intensity) * scale_factor
	var star_color: Color = Color(1.0, 1.0, 200.0 / 255.0, sparkle_intensity)
	for star_pos in [
		rect.position + Vector2(6.0, 6.0) * scale_factor,
		Vector2(rect.end.x - 6.0 * scale_factor, rect.position.y + 6.0 * scale_factor),
		Vector2(rect.position.x + 6.0 * scale_factor, rect.end.y - 6.0 * scale_factor),
		rect.end - Vector2(6.0, 6.0) * scale_factor,
	]:
		_draw_star(canvas, star_pos, star_size, star_color)


func _draw_star(canvas: Node2D, center: Vector2, size: float, color: Color) -> void:
	canvas.draw_line(center + Vector2(-size, 0.0), center + Vector2(size, 0.0), color, 1.0)
	canvas.draw_line(center + Vector2(0.0, -size), center + Vector2(0.0, size), color, 1.0)
	var diag: float = size * 0.7
	canvas.draw_line(
		center + Vector2(-diag, -diag),
		center + Vector2(diag, diag),
		Color(color.r, color.g, color.b, color.a * 0.5),
		1.0
	)
	canvas.draw_line(
		center + Vector2(diag, -diag),
		center + Vector2(-diag, diag),
		Color(color.r, color.g, color.b, color.a * 0.5),
		1.0
	)
