extends RefCounted


func draw(canvas: Node2D, effect_state, shake_offset: Vector2) -> void:
	if canvas == null or effect_state == null:
		return

	_draw_hit_particles(canvas, shake_offset, effect_state.get_hit_particles())
	_draw_wall_impact_effects(
		canvas,
		shake_offset,
		effect_state.get_wall_impact_flash_timer(),
		effect_state.get_wall_impact_position(),
		effect_state.get_wall_impact_particles()
	)


func _draw_hit_particles(canvas: Node2D, shake_offset: Vector2, particles: Array) -> void:
	for particle in particles:
		var life: float = float(particle["life"])
		var max_life: float = max(0.001, float(particle["max_life"]))
		var alpha: float = life / max_life
		var size: float = float(particle["size"]) * alpha
		if alpha <= 0.0 or size <= 0.0:
			continue
		var particle_pos: Vector2 = particle["pos"]
		var color: Color = particle["color"]
		canvas.draw_circle(particle_pos + shake_offset, size, Color(color.r, color.g, color.b, alpha))


func _draw_wall_impact_effects(
	canvas: Node2D,
	shake_offset: Vector2,
	flash_timer: float,
	flash_position: Vector2,
	particles: Array
) -> void:
	if flash_timer > 0.0:
		var progress: float = flash_timer / (8.0 / 60.0)
		var flash_radius: float = 25.0 + (1.0 - progress) * 24.0
		var flash_pos: Vector2 = flash_position + shake_offset
		canvas.draw_circle(flash_pos, flash_radius, Color(180.0 / 255.0, 220.0 / 255.0, 1.0, 0.10 * progress))
		canvas.draw_circle(flash_pos, flash_radius * 0.45, Color(220.0 / 255.0, 240.0 / 255.0, 1.0, 0.16 * progress))

	for particle in particles:
		var life: float = float(particle["life"])
		var max_life: float = max(0.001, float(particle["max_life"]))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		var color: Color = particle["color"]
		var particle_pos: Vector2 = particle["pos"]
		var size: float = float(particle["size"])
		if alpha <= 0.0 or size <= 0.5:
			continue
		canvas.draw_circle(particle_pos + shake_offset, size * 1.8, Color(color.r, color.g, color.b, 0.16 * alpha))
		canvas.draw_circle(particle_pos + shake_offset, size, Color(color.r, color.g, color.b, 0.70 * alpha))
		canvas.draw_circle(particle_pos + shake_offset, max(1.0, size * 0.45), Color(0.88, 0.95, 1.0, 0.85 * alpha))
