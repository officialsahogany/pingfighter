extends RefCounted

const HydroPuddleTextureCache := preload("res://scripts/effects/hydro_puddle_texture_cache.gd")


func prewarm() -> void:
	HydroPuddleTextureCache.prewarm()


func draw_hydro_sphere(
	canvas: CanvasItem,
	shake_offset: Vector2,
	visual_time_seconds: float,
	projectile_active: bool,
	projectile_pos: Vector2,
	projectile_vel: Vector2,
	projectile_radius: float,
	trail: Array[Vector2],
	puddle_pos: Vector2,
	puddle_timer: float,
	puddle_duration: float,
	puddle_seed: int,
	puddle_half_width: float,
	puddle_half_height: float,
	puddle_drop_y: float,
	splash_timer: float,
	splash_duration: float,
	particles: Array
) -> void:
	if canvas == null:
		return
	if puddle_timer > 0.0:
		_draw_puddle(
			canvas,
			puddle_pos + shake_offset,
			visual_time_seconds,
			puddle_timer,
			puddle_duration,
			puddle_seed,
			puddle_half_width,
			puddle_half_height
		)
	if not particles.is_empty():
		_draw_particles(canvas, particles, shake_offset)
	if splash_timer > 0.0:
		_draw_splash(
			canvas,
			puddle_pos - Vector2(0.0, puddle_drop_y) + shake_offset,
			splash_timer,
			splash_duration
		)
	if projectile_active:
		_draw_projectile(
			canvas,
			projectile_pos + shake_offset,
			projectile_vel,
			projectile_radius,
			trail,
			shake_offset
		)


func get_puddle_projection_for_tests(
	visual_time_seconds: float,
	puddle_timer: float,
	puddle_duration: float,
	puddle_half_width: float,
	puddle_half_height: float
) -> Vector4:
	if puddle_duration <= 0.001 or puddle_half_width <= 0.5 or puddle_half_height <= 0.5:
		return Vector4.ZERO
	var life_ratio: float = clampf(puddle_timer / puddle_duration, 0.0, 1.0)
	var appear_lin: float = clampf((puddle_duration - puddle_timer) / 0.34, 0.0, 1.0)
	var appear: float = _ease_out_back(appear_lin)
	var fade: float = clampf(life_ratio / 0.18, 0.0, 1.0)
	var alpha: float = clampf(minf(appear_lin * 1.6, 1.0) * fade, 0.0, 1.0)
	if alpha <= 0.01:
		return Vector4.ZERO
	var grow: float = 0.72 + 0.28 * appear
	return Vector4(
		puddle_half_width * grow,
		puddle_half_height * grow,
		alpha,
		0.92 + 0.08 * sin(visual_time_seconds * 2.3)
	)


func _draw_projectile(
	canvas: CanvasItem,
	pos: Vector2,
	projectile_vel: Vector2,
	projectile_radius: float,
	trail: Array[Vector2],
	shake_offset: Vector2
) -> void:
	for index in range(trail.size()):
		var trail_pos: Vector2 = trail[index] + shake_offset
		var ratio: float = float(index + 1) / float(maxi(1, trail.size()))
		canvas.draw_circle(trail_pos, lerpf(2.0, 5.5, ratio), Color(0.26, 0.98, 1.0, 0.10 + 0.24 * ratio))
		if index > 0:
			var prev_pos: Vector2 = trail[index - 1] + shake_offset
			canvas.draw_line(prev_pos, trail_pos, Color(0.60, 1.0, 1.0, 0.30 * ratio), maxf(1.0, 3.0 * ratio), true)

	var direction: Vector2 = projectile_vel.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2(0.0, -1.0)
	var side: Vector2 = direction.orthogonal()
	var spear_points := PackedVector2Array([
		pos + direction * 24.0,
		pos + side * 8.0,
		pos - direction * 18.0,
		pos - side * 8.0,
	])
	canvas.draw_colored_polygon(spear_points, Color(0.44, 1.0, 1.0, 0.86))
	canvas.draw_polyline(PackedVector2Array([spear_points[0], spear_points[1], spear_points[2], spear_points[3], spear_points[0]]), Color(0.90, 1.0, 1.0, 0.92), 1.6, true)
	canvas.draw_circle(pos, projectile_radius + 7.0, Color(0.14, 0.88, 1.0, 0.18))


func _draw_puddle(
	canvas: CanvasItem,
	center: Vector2,
	visual_time_seconds: float,
	puddle_timer: float,
	puddle_duration: float,
	puddle_seed: int,
	puddle_half_width: float,
	puddle_half_height: float
) -> void:
	var projection: Vector4 = get_puddle_projection_for_tests(
		visual_time_seconds,
		puddle_timer,
		puddle_duration,
		puddle_half_width,
		puddle_half_height
	)
	if projection == Vector4.ZERO:
		return
	var rx: float = projection.x
	var ry: float = projection.y
	var alpha: float = projection.z
	var pulse: float = projection.w
	var surface: Texture2D = HydroPuddleTextureCache.get_surface_texture()
	_blit_hydro(canvas, surface, center, rx, ry, Color(0.16, 0.74, 0.95, alpha * 0.46))
	_blit_hydro_caustic(canvas, center, rx * 0.94, ry * 0.94, Color(0.55, 1.0, 1.0, alpha * 0.42), visual_time_seconds, puddle_seed)
	_blit_hydro_caustic(canvas, center, rx * 0.76, ry * 0.76, Color(0.85, 1.0, 1.0, alpha * 0.30), -visual_time_seconds * 0.8 + 2.0, puddle_seed)
	_blit_hydro(canvas, surface, center, rx * 0.5, ry * 0.5, Color(0.80, 1.0, 1.0, alpha * 0.30 * pulse))
	_blit_hydro(canvas, HydroPuddleTextureCache.get_foam_ring_texture(), center, rx * 1.02, ry * 1.04, Color(0.82, 1.0, 1.0, alpha * 0.85 * pulse))


func _draw_splash(
	canvas: CanvasItem,
	center: Vector2,
	splash_timer: float,
	splash_duration: float
) -> void:
	var ratio: float = clampf(splash_timer / maxf(0.001, splash_duration), 0.0, 1.0)
	var expansion: float = 1.0 - ratio
	var radius: float = lerpf(26.0, 104.0, expansion)
	_blit_hydro(canvas, HydroPuddleTextureCache.get_surface_texture(), center, radius, radius, Color(0.52, 1.0, 1.0, 0.34 * ratio))
	_blit_hydro(canvas, HydroPuddleTextureCache.get_foam_ring_texture(), center, radius * 0.92, radius * 0.92, Color(0.92, 1.0, 1.0, 0.70 * ratio))


func _draw_particles(canvas: CanvasItem, particles: Array, shake_offset: Vector2) -> void:
	var texture: Texture2D = HydroPuddleTextureCache.get_droplet_texture()
	if texture == null:
		return
	for particle in particles:
		var max_life: float = maxf(0.01, float(particle["max_life"]))
		var life_t: float = clampf(float(particle["life"]) / max_life, 0.0, 1.0)
		var is_splash: bool = int(particle["kind"]) == 0
		var alpha: float = clampf(life_t * 1.4, 0.0, 1.0) if is_splash else life_t
		if alpha <= 0.02:
			continue
		var size: float = float(particle["size"]) * (0.7 + 0.3 * life_t)
		var pos: Vector2 = (particle["pos"] as Vector2) + shake_offset
		var color: Color = Color(0.74, 1.0, 1.0, alpha * 0.92) if is_splash else Color(0.56, 0.96, 1.0, alpha * 0.58)
		canvas.draw_texture_rect(texture, Rect2(pos - Vector2(size, size), Vector2(size * 2.0, size * 2.0)), false, color)


func _blit_hydro(
	canvas: CanvasItem,
	texture: Texture2D,
	center: Vector2,
	rx: float,
	ry: float,
	color: Color
) -> void:
	if texture == null or rx <= 0.5 or ry <= 0.5 or color.a <= 0.0:
		return
	canvas.draw_texture_rect(texture, Rect2(center - Vector2(rx, ry), Vector2(rx * 2.0, ry * 2.0)), false, color)


func _blit_hydro_caustic(
	canvas: CanvasItem,
	center: Vector2,
	rx: float,
	ry: float,
	color: Color,
	visual_time_seconds: float,
	puddle_seed: int
) -> void:
	if rx <= 0.5 or ry <= 0.5 or color.a <= 0.0:
		return
	var texture: Texture2D = HydroPuddleTextureCache.get_caustic_texture()
	if texture == null:
		return
	var seed_phase: float = float(puddle_seed) * 0.013
	var breathe: float = 1.0 + 0.07 * sin(visual_time_seconds * 1.4 + seed_phase)
	var width: float = rx * breathe
	var height: float = ry * breathe
	canvas.draw_texture_rect(texture, Rect2(center - Vector2(width, height), Vector2(width * 2.0, height * 2.0)), false, color)


func _ease_out_back(x: float) -> float:
	var clamped: float = clampf(x, 0.0, 1.0)
	var overshoot := 1.70158
	var shifted: float = clamped - 1.0
	return 1.0 + (overshoot + 1.0) * pow(shifted, 3.0) + overshoot * pow(shifted, 2.0)
