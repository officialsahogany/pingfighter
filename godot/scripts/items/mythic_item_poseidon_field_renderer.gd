extends RefCounted


func draw_poseidon_effects(
	canvas: CanvasItem,
	shake_offset: Vector2,
	water_trail: Array,
	particles: Array,
	explosion_active: bool,
	player_center: Vector2,
	explosion_timer: float,
	explosion_particles: Array,
	explosion_flash_duration: float,
	water_trail_render_limit: int,
	particle_render_limit: int,
	explosion_particle_render_limit: int,
	trail_arc_render_limit: int,
	trail_arc_segments: int
) -> void:
	# Preserve the Python draw order: trail under vortex particles, charge flash on top.
	draw_poseidon_water_trail(
		canvas,
		shake_offset,
		water_trail,
		water_trail_render_limit,
		trail_arc_render_limit,
		trail_arc_segments
	)
	draw_poseidon_particles(canvas, shake_offset, particles, particle_render_limit)
	draw_poseidon_water_explosion(
		canvas,
		shake_offset,
		explosion_active,
		player_center,
		explosion_timer,
		explosion_particles,
		explosion_flash_duration,
		explosion_particle_render_limit
	)


func draw_poseidon_water_trail(
	canvas: CanvasItem,
	shake_offset: Vector2,
	water_trail: Array,
	water_trail_render_limit: int,
	trail_arc_render_limit: int,
	trail_arc_segments: int
) -> void:
	if canvas == null or water_trail.is_empty():
		return
	var render_start: int = _recent_start(water_trail, water_trail_render_limit)
	var arc_start: int = max(render_start, water_trail.size() - trail_arc_render_limit)
	for droplet_index in range(render_start, water_trail.size()):
		var droplet_value = water_trail[droplet_index]
		var droplet: Dictionary = _as_dict(droplet_value)
		var life: float = float(droplet.get("life", 0.0))
		var alpha: float = clamp(life * 8.5 / 255.0, 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var size: float = max(0.5, float(droplet.get("size", 4.0)))
		var pos: Vector2 = Vector2(float(droplet.get("x", 0.0)), float(droplet.get("y", 0.0))) + shake_offset
		canvas.draw_circle(pos, size, Color(80.0 / 255.0, 160.0 / 255.0, 1.0, alpha))
		if size > 2.0:
			var highlight_offset: float = size / 3.0
			var highlight_alpha: float = min(1.0, alpha + 50.0 / 255.0) * 0.5
			canvas.draw_circle(
				pos - Vector2(highlight_offset, highlight_offset),
				size / 2.5,
				Color(220.0 / 255.0, 240.0 / 255.0, 1.0, highlight_alpha)
			)
		if size > 3.0 and droplet_index >= arc_start:
			canvas.draw_arc(
				pos,
				size,
				0.0,
				TAU,
				trail_arc_segments,
				Color(50.0 / 255.0, 120.0 / 255.0, 200.0 / 255.0, alpha / 3.0),
				1.0
			)


func draw_poseidon_particles(
	canvas: CanvasItem,
	shake_offset: Vector2,
	particles: Array,
	particle_render_limit: int
) -> void:
	if canvas == null:
		return
	# Poseidon vortex particles are stored oldest-first; older particles have risen
	# higher on screen, newest particles spawn near the paddle anchor. Slicing the
	# last N (the natural _recent_start path) would cut the top of the water column
	# off. Stride sample evenly across the lifecycle so the full pillar silhouette
	# stays readable while honoring particle_render_limit as the draw budget.
	var total: int = particles.size()
	if total <= 0:
		return
	var budget: int = particle_render_limit
	var render_count: int = total if total <= budget else budget
	for sample_index in range(render_count):
		var particle_index: int = sample_index if total <= budget else int(floor(float(sample_index) * float(total) / float(budget)))
		var particle: Dictionary = _as_dict(particles[particle_index])
		var size: float = max(0.5, float(particle.get("size", 4.0)))
		var life: float = float(particle.get("life", 0.0))
		var alpha: float = clamp(life * 5.0 / 255.0, 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var pos: Vector2 = Vector2(float(particle.get("x", 0.0)), float(particle.get("y", 0.0))) + shake_offset
		var color: Color = _as_color(particle.get("color", Color(50.0 / 255.0, 200.0 / 255.0, 1.0)), Color(50.0 / 255.0, 200.0 / 255.0, 1.0))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, alpha))
		var highlight_size: float = size / 3.0
		if highlight_size >= 0.5:
			canvas.draw_circle(
				pos - Vector2(highlight_size, highlight_size),
				highlight_size,
				Color(200.0 / 255.0, 230.0 / 255.0, 1.0, alpha * 0.5)
			)


func draw_poseidon_water_explosion(
	canvas: CanvasItem,
	shake_offset: Vector2,
	explosion_active: bool,
	player_center: Vector2,
	explosion_timer: float,
	explosion_particles: Array,
	explosion_flash_duration: float,
	explosion_particle_render_limit: int
) -> void:
	if canvas == null or not explosion_active:
		return
	var center: Vector2 = player_center + shake_offset
	if explosion_timer < explosion_flash_duration:
		var flash_progress: float = explosion_timer / explosion_flash_duration
		var flash_alpha: float = (180.0 / 255.0) * (1.0 - flash_progress)
		var flash_size: float = 30.0 + flash_progress * 90.0
		canvas.draw_circle(center, flash_size, Color(120.0 / 255.0, 200.0 / 255.0, 1.0, flash_alpha * 0.5))
		canvas.draw_circle(center, flash_size * 0.5, Color(180.0 / 255.0, 230.0 / 255.0, 1.0, flash_alpha))
	for p_index in range(_recent_start(explosion_particles, explosion_particle_render_limit), explosion_particles.size()):
		var p_value = explosion_particles[p_index]
		var p: Dictionary = _as_dict(p_value)
		var life: float = float(p.get("life", 0.0))
		var max_life: float = max(0.01, float(p.get("max_life", 1.0)))
		var ratio: float = clamp(life / max_life, 0.0, 1.0)
		var size: float = max(2.0, float(p.get("size", 8.0)) * ratio)
		var pos: Vector2 = center + Vector2(float(p.get("offset_x", 0.0)), float(p.get("offset_y", 0.0)))
		var alpha: float = (220.0 / 255.0) * ratio
		var color: Color = _as_color(p.get("color", Color(120.0 / 255.0, 220.0 / 255.0, 1.0)), Color(120.0 / 255.0, 220.0 / 255.0, 1.0))
		canvas.draw_circle(pos, size + 4.0, Color(100.0 / 255.0, 200.0 / 255.0, 1.0, alpha / 3.0))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, alpha))


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback


func _recent_start(source: Array, render_limit: int) -> int:
	if render_limit < 0:
		return 0
	return max(0, source.size() - max(0, render_limit))
