extends RefCounted


func draw_flash(canvas: CanvasItem, center: Vector2, radius: float, flash_progress: float, scale_factor: float) -> void:
	for layer in range(3):
		var flash_radius: float = radius + 10.0 * scale_factor + float(layer) * 12.0 * scale_factor
		var flash_alpha: float = (0.38 - float(layer) * 0.10) * flash_progress
		canvas.draw_circle(center, flash_radius, Color(1.0, 0.82, 0.46, flash_alpha))
	canvas.draw_arc(center, radius + 26.0 * scale_factor * (1.0 - flash_progress), 0.0, TAU, 32, Color(1.0, 0.86, 0.54, 0.50 * flash_progress), 3.0)
	for burst_i in range(8):
		var burst_angle: float = float(burst_i) * TAU / 8.0
		var burst_dist: float = (radius + 14.0 * scale_factor) * (1.0 + (1.0 - flash_progress) * 0.6)
		var burst_pos: Vector2 = center + Vector2(cos(burst_angle), sin(burst_angle)) * burst_dist
		canvas.draw_circle(burst_pos, 3.0 * scale_factor * flash_progress, Color(1.0, 0.90, 0.60, 0.50 * flash_progress))
