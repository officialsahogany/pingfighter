extends RefCounted


func draw_score_diamonds(canvas: Node2D, rect: Rect2, scale_factor: float, sparkle_intensity: float) -> void:
	var diamond_size: float = max(4.0, 6.0 * scale_factor)
	var diamond_color: Color = Color(1.0, 220.0 / 255.0, 100.0 / 255.0, (200.0 + 55.0 * sparkle_intensity) / 255.0)
	var left_center: Vector2 = Vector2(rect.position.x + 10.0 * scale_factor + diamond_size, rect.position.y + rect.size.y * 0.5)
	var right_center: Vector2 = Vector2(rect.end.x - 10.0 * scale_factor - diamond_size, rect.position.y + rect.size.y * 0.5)
	for center in [left_center, right_center]:
		canvas.draw_colored_polygon(
			PackedVector2Array([
				Vector2(center.x - diamond_size, center.y),
				Vector2(center.x, center.y - diamond_size),
				Vector2(center.x + diamond_size, center.y),
				Vector2(center.x, center.y + diamond_size),
			]),
			diamond_color
		)


func draw_sparkles(
	canvas: Node2D,
	rect: Rect2,
	scale_factor: float,
	sparkle_progress: float,
	sparkle_intensity: float
) -> void:
	if sparkle_intensity <= 0.1:
		return

	var sweep_width: int = max(12, int(25.0 * scale_factor))
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

	if sparkle_intensity <= 0.5:
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
