extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")

const TRAIL_LINK_SPARK_STRIDE := 2
const MAX_RENDERED_TRAILS := 16
const MAX_RENDERED_PARTICLES := 72
const MAX_RENDERED_GHOSTS := 6
const MAX_RENDERED_GHOST_TRAJECTORY := 24
const GHOST_TRAJECTORY_DARK := Color(0.035, 0.0, 0.08)
const GHOST_TRAJECTORY_PURPLE := Color(130.0 / 255.0, 44.0 / 255.0, 230.0 / 255.0)
const GHOST_TRAJECTORY_HOT := Color(218.0 / 255.0, 120.0 / 255.0, 1.0)


func _init() -> void:
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()


func draw(canvas: Node2D, power_state, shake_offset: Vector2) -> void:
	if canvas == null or power_state == null:
		return
	if power_state.has_method("has_visible_effects") and not bool(power_state.has_visible_effects()):
		return

	if power_state.has_method("get_ghost_shot_blackhole_effects"):
		var blackhole_effects: Array = power_state.get_ghost_shot_blackhole_effects()
		if not blackhole_effects.is_empty():
			_draw_ghost_shot_blackholes(canvas, blackhole_effects, shake_offset)
	if power_state.has_method("get_ghost_shot_trajectory_points"):
		var trajectory_points: Array = power_state.get_ghost_shot_trajectory_points()
		if not trajectory_points.is_empty():
			_draw_ghost_shot_trajectory(canvas, trajectory_points, shake_offset)
	var trails: Array = power_state.get_trails()
	if not trails.is_empty():
		_draw_trails(canvas, trails, shake_offset)
	var particles: Array = power_state.get_particles()
	if not particles.is_empty():
		_draw_particles(canvas, particles, shake_offset)
	if power_state.has_method("has_ghost_shot_visible_aura") and bool(power_state.has_ghost_shot_visible_aura()):
		_draw_ghost_shot_aura(canvas, power_state.get_ghost_shot_last_visible_ball_pos(), shake_offset)
	if power_state.has_method("get_ghost_shot_ghosts"):
		var ghosts: Array = power_state.get_ghost_shot_ghosts()
		if not ghosts.is_empty():
			_draw_ghost_shot_ghosts(canvas, ghosts, shake_offset)


func _draw_ghost_shot_trajectory(canvas: Node2D, points: Array, shake_offset: Vector2) -> void:
	if points.is_empty():
		return
	var start_index: int = max(0, points.size() - MAX_RENDERED_GHOST_TRAJECTORY)
	for i in range(start_index + 1, points.size()):
		var previous_value: Variant = points[i - 1]
		var current_value: Variant = points[i]
		if not (previous_value is Dictionary) or not (current_value is Dictionary):
			continue
		var previous: Dictionary = previous_value
		var current: Dictionary = current_value
		var from_pos: Vector2 = _as_vector2(previous.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var to_pos: Vector2 = _as_vector2(current.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var segment: Vector2 = to_pos - from_pos
		var length: float = segment.length()
		if length < 1.0:
			continue
		var ratio: float = float(i - start_index) / max(1.0, float(points.size() - start_index - 1))
		var alpha: float = clamp(
			min(float(previous.get("alpha", 0.0)), float(current.get("alpha", 0.0))) * pow(ratio, 0.42),
			0.0,
			1.0
		)
		if alpha <= 0.02:
			continue
		var size: float = max(6.0, min(float(previous.get("size", 14.0)), float(current.get("size", 14.0))))
		var width: float = max(1.4, size * (0.12 + ratio * 0.05))
		var direction: Vector2 = segment / length
		var perpendicular := Vector2(-direction.y, direction.x)
		var phase: float = float(current.get("phase", 0.0)) + float(i) * 0.61
		var wave_offset: Vector2 = perpendicular * sin(Time.get_ticks_msec() * 0.006 + phase) * (2.2 + ratio * 3.2)
		var warped_from: Vector2 = from_pos + wave_offset
		var warped_to: Vector2 = to_pos - wave_offset * 0.45

		canvas.draw_line(warped_from, warped_to, Color(GHOST_TRAJECTORY_DARK.r, GHOST_TRAJECTORY_DARK.g, GHOST_TRAJECTORY_DARK.b, 0.50 * alpha), width * 3.6, true)
		canvas.draw_line(warped_from, warped_to, Color(GHOST_TRAJECTORY_PURPLE.r, GHOST_TRAJECTORY_PURPLE.g, GHOST_TRAJECTORY_PURPLE.b, 0.46 * alpha), width * 1.45, true)
		canvas.draw_line(from_pos - wave_offset * 0.35, to_pos + wave_offset * 0.25, Color(GHOST_TRAJECTORY_HOT.r, GHOST_TRAJECTORY_HOT.g, GHOST_TRAJECTORY_HOT.b, 0.18 * alpha), max(0.8, width * 0.52), true)
		if i % 3 == 0:
			var spark_pos: Vector2 = from_pos.lerp(to_pos, 0.58) + perpendicular * sin(phase * 2.3) * 5.5
			ImpactFlareTextureCache.draw_sparkle(canvas, spark_pos, max(3.0, size * 0.18), GHOST_TRAJECTORY_HOT, 0.42 * alpha)

	for i in range(start_index, points.size()):
		var point_value: Variant = points[i]
		if not (point_value is Dictionary):
			continue
		var point: Dictionary = point_value
		var alpha: float = clamp(float(point.get("alpha", 0.0)), 0.0, 1.0)
		if alpha <= 0.03:
			continue
		var ratio: float = float(i - start_index) / max(1.0, float(points.size() - start_index - 1))
		var pos: Vector2 = _as_vector2(point.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = max(5.0, float(point.get("size", 14.0)) * (0.34 + ratio * 0.12))
		ImpactFlareTextureCache.draw_glow(canvas, pos, size * 1.25, GHOST_TRAJECTORY_DARK, 0.20 * alpha)
		if ratio > 0.78:
			ImpactFlareTextureCache.draw_sparkle(canvas, pos, max(3.2, size * 0.34), GHOST_TRAJECTORY_PURPLE, 0.34 * alpha)


func _draw_trails(canvas: Node2D, trails: Array, shake_offset: Vector2) -> void:
	_draw_trail_links(canvas, trails, shake_offset)
	var trail_start: int = max(0, trails.size() - MAX_RENDERED_TRAILS)
	for index in range(trail_start, trails.size()):
		var trail: Dictionary = trails[index]
		var life: float = clamp(float(trail["life"]), 0.0, 1.0)
		if life <= 0.0:
			continue

		var trail_pos: Vector2 = trail["pos"]
		trail_pos += shake_offset
		var size: float = max(1.0, float(trail.get("size", trail.get("radius", 28.6))))
		var core_size: float = size * 0.6 * life
		if core_size <= 0.0:
			continue
		ImpactFlareTextureCache.draw_glow(canvas, trail_pos, size * 0.9, Color(100.0 / 255.0, 150.0 / 255.0, 1.0), 0.18 * life)
		ImpactFlareTextureCache.draw_sparkle(canvas, trail_pos, max(3.0, core_size), Color(220.0 / 255.0, 240.0 / 255.0, 1.0), 0.48 * life)


func _draw_trail_links(canvas: Node2D, trails: Array, shake_offset: Vector2) -> void:
	if trails.size() < 2:
		return
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
		if i % TRAIL_LINK_SPARK_STRIDE == 0:
			var spark_seed: float = float(i) * 1.73 + life * 4.1
			var spark_end: Vector2 = from_pos + Vector2(sin(spark_seed), cos(spark_seed * 1.37)) * 8.0
			canvas.draw_line(from_pos, spark_end, Color(200.0 / 255.0, 220.0 / 255.0, 1.0, 0.34 * life), 1.0)


func _draw_particles(canvas: Node2D, particles: Array, shake_offset: Vector2) -> void:
	var particle_start: int = max(0, particles.size() - MAX_RENDERED_PARTICLES)
	for index in range(particle_start, particles.size()):
		var particle: Dictionary = particles[index]
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
			ImpactFlareTextureCache.draw_sparkle(canvas, particle_pos, size * 2.15, color, alpha * 0.54)


func _draw_ghost_shot_blackholes(canvas: Node2D, effects: Array, shake_offset: Vector2) -> void:
	var now_msec: int = Time.get_ticks_msec()
	for effect in effects:
		if not (effect is Dictionary):
			continue
		var start_msec: int = int(effect.get("start_msec", now_msec))
		var duration_msec: int = max(1, int(effect.get("duration_msec", 1)))
		var progress: float = float(now_msec - start_msec) / float(duration_msec)
		if progress < 0.0 or progress > 1.0:
			continue
		var pos: Vector2 = _as_vector2(effect.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var kind: String = str(effect.get("kind", "in"))
		var pulse: float = sin(progress * PI)
		var radius: float = (18.0 + progress * 54.0) if kind == "out" else (70.0 - progress * 50.0)
		var core_radius: float = max(5.0, radius * (0.34 + 0.12 * pulse))
		var alpha: float = clamp(pulse, 0.0, 1.0)
		ImpactFlareTextureCache.draw_glow(canvas, pos, radius * 0.92, Color(0.02, 0.0, 0.05), 0.34 * alpha)
		ImpactFlareTextureCache.draw_glow(canvas, pos, core_radius, Color(0.0, 0.0, 0.0), 0.52 * alpha)
		for ring_index in range(2):
			var ring_radius: float = max(3.0, radius - float(ring_index) * 11.0)
			var ring_alpha: float = (0.55 - float(ring_index) * 0.12) * alpha
			ImpactShockwaveTextureCache.draw_full_ring(
				canvas,
				pos,
				ring_radius,
				Color(150.0 / 255.0, 70.0 / 255.0, 1.0),
				ring_alpha * 0.46
			)


func _draw_ghost_shot_aura(canvas: Node2D, ball_pos: Vector2, shake_offset: Vector2) -> void:
	if ball_pos.x < -100.0 or ball_pos.y < -100.0:
		return
	var pos: Vector2 = ball_pos + shake_offset
	var phase: float = Time.get_ticks_msec() / 1000.0
	var radius: float = 38.0 + sin(phase * 7.0) * 4.0
	ImpactFlareTextureCache.draw_glow(canvas, pos, radius, Color(95.0 / 255.0, 20.0 / 255.0, 150.0 / 255.0), 0.10)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, pos, 31.0 + sin(phase * 5.0) * 3.0, Color(130.0 / 255.0, 60.0 / 255.0, 1.0), 0.22)


func _draw_ghost_shot_ghosts(canvas: Node2D, ghosts: Array, shake_offset: Vector2) -> void:
	var ghost_start: int = max(0, ghosts.size() - MAX_RENDERED_GHOSTS)
	for index in range(ghost_start, ghosts.size()):
		var ghost: Variant = ghosts[index]
		if not (ghost is Dictionary):
			continue
		var alpha: float = clamp(float(ghost.get("alpha", 0.0)), 0.0, 1.0)
		if alpha <= 0.02:
			continue
		var pos: Vector2 = _as_vector2(ghost.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = max(3.0, float(ghost.get("size", 8.0)))
		var purple := Color(120.0 / 255.0, 55.0 / 255.0, 200.0 / 255.0)
		ImpactFlareTextureCache.draw_glow(canvas, pos, size * 1.75, purple, alpha * 0.20)
		ImpactFlareTextureCache.draw_glow(canvas, pos, size, Color(0.04, 0.0, 0.10), alpha * 0.48)
		ImpactFlareTextureCache.draw_sparkle(canvas, pos + Vector2(-size * 0.32, -size * 0.10), max(1.8, size * 0.32), Color(1.0, 0.18, 0.30), alpha * 0.52)
		ImpactFlareTextureCache.draw_sparkle(canvas, pos + Vector2(size * 0.32, -size * 0.10), max(1.8, size * 0.32), Color(1.0, 0.18, 0.30), alpha * 0.52)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
