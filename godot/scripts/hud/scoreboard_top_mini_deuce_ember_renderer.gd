extends RefCounted


func draw(canvas: CanvasItem, rect: Rect2, scale_factor: float, t: float) -> void:
	for j in range(10):
		var particle_phase: float = fmod(t * (4.0 + float(j) * 0.8) + float(j) * 0.7, 1.0)
		var particle_x: float = rect.position.x + 5.0 * scale_factor + float(j) * (rect.size.x - 10.0 * scale_factor) / 9.0
		particle_x += sin(t * 10.0 + float(j) * 1.2) * 5.0 * scale_factor
		var particle_y: float = rect.position.y - 5.0 * scale_factor - particle_phase * 35.0 * scale_factor
		var size_factor: float = 1.0 - particle_phase * 0.7
		var particle_size: float = max(0.0, float(2 + (j % 3)) * size_factor * scale_factor)
		var particle_alpha: float = pow(1.0 - particle_phase, 1.2)
		if particle_size <= 0.8 or particle_alpha <= 0.08:
			continue

		var particle_color: Color = _get_ember_color(1.0 - particle_phase, particle_alpha)
		var particle_center: Vector2 = Vector2(particle_x, particle_y)
		canvas.draw_circle(particle_center, particle_size * 2.0, Color(particle_color.r, particle_color.g, 0.0, particle_alpha * 0.25))
		canvas.draw_circle(particle_center, particle_size + 1.0, Color(particle_color.r, particle_color.g, particle_color.b, particle_alpha * 0.50))
		canvas.draw_circle(particle_center, particle_size, Color(1.0, 1.0, 200.0 / 255.0, particle_alpha))


func _get_ember_color(life_ratio: float, particle_alpha: float) -> Color:
	if life_ratio > 0.6:
		return Color(1.0, 1.0, (150.0 * (life_ratio - 0.6) / 0.4) / 255.0, particle_alpha)
	if life_ratio > 0.3:
		return Color(1.0, (150.0 + 105.0 * (life_ratio - 0.3) / 0.3) / 255.0, 0.0, particle_alpha)
	return Color(life_ratio / 0.3, (80.0 * life_ratio / 0.3) / 255.0, 0.0, particle_alpha)
