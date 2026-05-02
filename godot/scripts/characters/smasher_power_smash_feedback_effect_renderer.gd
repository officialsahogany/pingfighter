extends RefCounted


func draw(canvas: Node2D, power_state, shake_offset: Vector2) -> void:
	if canvas == null or power_state == null:
		return

	_draw_trails(canvas, power_state.get_trails(), shake_offset)
	_draw_particles(canvas, power_state.get_particles(), shake_offset)


func _draw_trails(canvas: Node2D, trails: Array, shake_offset: Vector2) -> void:
	_draw_trail_links(canvas, trails, shake_offset)
	for trail in trails:
		var life: float = clamp(float(trail["life"]), 0.0, 1.0)
		if life <= 0.0:
			continue

		var trail_pos: Vector2 = trail["pos"]
		trail_pos += shake_offset
		var size: float = max(1.0, float(trail.get("size", trail.get("radius", 28.6))))
		var core_size: float = size * 0.6 * life
		if core_size <= 0.0:
			continue
		canvas.draw_circle(trail_pos, size * 0.9, Color(100.0 / 255.0, 150.0 / 255.0, 1.0, 0.20 * life))
		canvas.draw_circle(trail_pos, size * 0.6, Color(150.0 / 255.0, 200.0 / 255.0, 1.0, 0.40 * life))
		canvas.draw_circle(trail_pos, core_size, Color(220.0 / 255.0, 240.0 / 255.0, 1.0, 0.60 * life))


func _draw_trail_links(canvas: Node2D, trails: Array, shake_offset: Vector2) -> void:
	for i in range(max(0, trails.size() - 1)):
		var current: Dictionary = trails[i]
		var next: Dictionary = trails[i + 1]
		var life: float = clamp(min(float(current.get("life", 0.0)), float(next.get("life", 0.0))), 0.0, 1.0)
		if life <= 0.0:
			continue
		var from_pos: Vector2 = current["pos"]
		var to_pos: Vector2 = next["pos"]
		from_pos += shake_offset
		to_pos += shake_offset
		canvas.draw_line(from_pos, to_pos, Color(100.0 / 255.0, 200.0 / 255.0, 1.0, 0.80 * life), max(1.0, 3.0 * life))
		for _spark_index in range(2):
			var spark_end: Vector2 = from_pos + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
			canvas.draw_line(from_pos, spark_end, Color(200.0 / 255.0, 220.0 / 255.0, 1.0, 0.40 * life), 1.0)


func _draw_particles(canvas: Node2D, particles: Array, shake_offset: Vector2) -> void:
	for particle in particles:
		var size: float = float(particle["size"])
		if size < 0.8:
			continue

		var lifetime: float = float(particle["lifetime"])
		var max_lifetime: float = max(1.0, float(particle["max_lifetime"]))
		var alpha: float = 1.0 - clamp(lifetime / max_lifetime, 0.0, 1.0)
		if alpha <= 8.0 / 255.0:
			continue

		var color: Color = particle["color"]
		var particle_pos: Vector2 = particle["pos"]
		particle_pos += shake_offset
		var particle_type: String = str(particle["type"])
		if particle_type == "spark":
			var particle_vel_value: Variant = particle.get("vel", Vector2.ZERO)
			var particle_vel: Vector2 = particle_vel_value if particle_vel_value is Vector2 else Vector2.ZERO
			canvas.draw_line(
				particle_pos,
				particle_pos + particle_vel * 2.0,
				Color(color.r, color.g, color.b, alpha),
				1.0
			)
		else:
			canvas.draw_circle(particle_pos, size * 2.0, Color(color.r, color.g, color.b, alpha * 0.30))
			canvas.draw_circle(particle_pos, size, Color(1.0, 1.0, 1.0, alpha * 0.80))
