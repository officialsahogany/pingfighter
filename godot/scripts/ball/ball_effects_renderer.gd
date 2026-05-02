extends RefCounted

const BallIntensityEffectRenderer := preload("res://scripts/ball/ball_intensity_effect_renderer.gd")

const BALL_OUTER_COLOR := Color(30.0 / 255.0, 100.0 / 255.0, 200.0 / 255.0)
const BALL_INNER_COLOR := Color(100.0 / 255.0, 180.0 / 255.0, 255.0 / 255.0)
const BALL_CORE_COLOR := Color(1.0, 1.0, 1.0)

var intensity_renderer: Object = BallIntensityEffectRenderer.new()


func draw_active_effects(canvas: Node2D, shake_offset: Vector2, context: Dictionary) -> void:
	if canvas == null:
		return

	_draw_ball_ghost_trail(canvas, shake_offset, context.get("ball_ghost_trail", []))
	intensity_renderer.draw(canvas, shake_offset, context)
	_draw_energy_explosion_particles(canvas, shake_offset, context.get("energy_explosion_particles", []))


func _draw_ball_ghost_trail(canvas: Node2D, shake_offset: Vector2, ghost_trail: Array) -> void:
	if ghost_trail.is_empty():
		return

	var total_points: int = ghost_trail.size()
	var current_time_ms: float = float(Time.get_ticks_msec())
	for i in range(total_points):
		var point: Dictionary = ghost_trail[i]
		var point_alpha: float = float(point["alpha"])
		if point_alpha < 3.0 / 255.0:
			continue

		var position_ratio: float = float(i) / max(1.0, float(total_points - 1))
		var base_alpha: float = point_alpha * pow(position_ratio, 0.7) * 0.6
		if base_alpha < 3.0 / 255.0:
			continue

		var wave_time: float = current_time_ms * 0.008 + float(i) * 0.5
		var wave_scale: float = 1.0 + sin(wave_time) * 0.05
		var ghost_size: float = float(point["size"]) * (0.7 + position_ratio * 0.3) * wave_scale
		if ghost_size < 2.0:
			continue

		var draw_pos: Vector2 = point["pos"] + shake_offset
		var wave_ring_offset: float = sin(wave_time * 1.2) * 2.0
		var ring_radius: float = ghost_size + 4.0 + wave_ring_offset
		canvas.draw_circle(draw_pos, ring_radius, Color(BALL_OUTER_COLOR.r, BALL_OUTER_COLOR.g, BALL_OUTER_COLOR.b, base_alpha * 0.15))
		canvas.draw_circle(draw_pos, ghost_size + 2.0, Color(BALL_OUTER_COLOR.r, BALL_OUTER_COLOR.g, BALL_OUTER_COLOR.b, base_alpha * 0.2))
		canvas.draw_circle(draw_pos, ghost_size * 0.85, Color(BALL_INNER_COLOR.r, BALL_INNER_COLOR.g, BALL_INNER_COLOR.b, base_alpha * 0.35))
		canvas.draw_circle(draw_pos, ghost_size * 0.5, Color(BALL_CORE_COLOR.r, BALL_CORE_COLOR.g, BALL_CORE_COLOR.b, base_alpha * 0.5))
		if position_ratio > 0.3:
			var ripple_phase: float = fmod(current_time_ms * 0.015 + float(i) * 0.8, TAU)
			var ripple_alpha: float = base_alpha * 0.1 * sin(ripple_phase)
			if ripple_alpha > 1.0 / 255.0:
				var ripple_radius: float = ghost_size + 6.0 + sin(ripple_phase) * 3.0
				canvas.draw_arc(draw_pos, ripple_radius, 0.0, TAU, 28, Color(BALL_INNER_COLOR.r, BALL_INNER_COLOR.g, BALL_INNER_COLOR.b, ripple_alpha), 1.0)


func _draw_energy_explosion_particles(canvas: Node2D, shake_offset: Vector2, particles: Array) -> void:
	for particle in particles:
		var size: float = float(particle["size"])
		if size < 1.0:
			continue

		var lifetime: float = float(particle["lifetime"])
		var max_lifetime: float = float(particle["max_lifetime"])
		var alpha: float = 1.0 - clamp(lifetime / max_lifetime, 0.0, 1.0)
		if alpha < 10.0 / 255.0:
			continue

		var color: Color = particle["color"]
		var draw_pos: Vector2 = particle["pos"] + shake_offset
		canvas.draw_circle(draw_pos, size * 2.0, Color(color.r, color.g, color.b, alpha * 0.5))
		canvas.draw_circle(draw_pos, size, Color(color.r, color.g, color.b, min(alpha, 230.0 / 255.0)))
		if str(particle["type"]) == "spark" and size > 1.0:
			canvas.draw_circle(draw_pos, max(1.0, size * 0.5), Color(220.0 / 255.0, 240.0 / 255.0, 1.0, min(alpha * 0.8, 200.0 / 255.0)))
