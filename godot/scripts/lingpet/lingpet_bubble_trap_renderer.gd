extends RefCounted

const INNER_BUBBLE_OFFSETS := [
	Vector2(-0.44, -0.18),
	Vector2(-0.28, 0.30),
	Vector2(0.30, -0.34),
	Vector2(0.42, 0.10),
	Vector2(0.02, 0.34),
	Vector2(-0.04, -0.04),
]
const INNER_BUBBLE_RADII := [0.17, 0.11, 0.13, 0.10, 0.08, 0.06]


func prewarm() -> void:
	pass


func draw_bubble_trap(
	canvas: CanvasItem,
	shake_offset: Vector2,
	runtime_elapsed: float,
	capture_timer: float,
	capture_duration_seconds: float,
	bubble_center: Vector2,
	capture_bubble_radius: float,
	capture_visual_seed: float,
	projectiles: Array,
	projectile_radius: float,
	burst_timer: float,
	burst_pos: Vector2,
	burst_flash_seconds: float,
	particles: Array,
	inner_bubble_size_variance: float
) -> void:
	if canvas == null:
		return
	if capture_timer > 0.0:
		_draw_capture_bubble(
			canvas,
			bubble_center + shake_offset,
			runtime_elapsed,
			capture_timer,
			capture_duration_seconds,
			capture_bubble_radius,
			capture_visual_seed,
			inner_bubble_size_variance
		)
	for projectile_value in projectiles:
		var projectile := projectile_value as Dictionary
		_draw_projectile(
			canvas,
			projectile,
			shake_offset,
			runtime_elapsed,
			projectile_radius,
			inner_bubble_size_variance
		)
	if burst_timer > 0.0:
		_draw_burst(canvas, burst_pos + shake_offset, burst_timer, burst_flash_seconds)
	if not particles.is_empty():
		_draw_particles(canvas, particles, shake_offset)


func get_animated_projection_for_tests(runtime_elapsed: float, center: Vector2) -> Dictionary:
	return {
		"rainbow_hue": _get_rainbow_hue(runtime_elapsed, center),
		"capture_pulse": _get_capture_pulse(runtime_elapsed),
	}


func _draw_projectile(
	canvas: CanvasItem,
	projectile: Dictionary,
	shake_offset: Vector2,
	runtime_elapsed: float,
	projectile_radius: float,
	inner_bubble_size_variance: float
) -> void:
	var pos: Vector2 = projectile.get("pos", Vector2.ZERO)
	var trail: Array = projectile.get("trail", [])
	var radius := _get_projectile_radius(projectile, projectile_radius)
	var visual_seed: float = float(projectile.get("visual_seed", 0.0))
	for i in range(trail.size()):
		var trail_pos: Vector2 = (trail[i] as Vector2) + shake_offset
		var ratio: float = float(i + 1) / float(maxi(1, trail.size()))
		canvas.draw_circle(trail_pos, lerpf(radius * 0.20, radius * 0.52, ratio), Color(0.50, 0.95, 1.0, 0.05 + 0.17 * ratio))
		if i > 0:
			var prev_pos: Vector2 = (trail[i - 1] as Vector2) + shake_offset
			canvas.draw_line(prev_pos, trail_pos, Color(0.68, 1.0, 1.0, 0.28 * ratio), maxf(1.0, 2.8 * ratio), true)
	_draw_bubble_core(canvas, pos, radius, 0.92, 0.22, visual_seed, inner_bubble_size_variance)
	if bool(projectile.get("is_rainbow", false)):
		_draw_rainbow_projectile_shimmer(canvas, pos, radius, 0.92, runtime_elapsed)


func _draw_rainbow_projectile_shimmer(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	alpha: float,
	runtime_elapsed: float
) -> void:
	var hue := _get_rainbow_hue(runtime_elapsed, center)
	canvas.draw_circle(center, radius * 0.96, Color.from_hsv(hue, 0.35, 1.0, alpha * 0.18))
	canvas.draw_arc(center, radius * 0.92, -PI * 0.32, PI * 0.88, 32, Color.from_hsv(fmod(hue + 0.12, 1.0), 0.38, 1.0, alpha * 0.42), 2.4, true)


func _draw_capture_bubble(
	canvas: CanvasItem,
	center: Vector2,
	runtime_elapsed: float,
	capture_timer: float,
	capture_duration_seconds: float,
	capture_bubble_radius: float,
	capture_visual_seed: float,
	inner_bubble_size_variance: float
) -> void:
	var ratio: float = clampf(capture_timer / maxf(0.01, capture_duration_seconds), 0.0, 1.0)
	var pulse := _get_capture_pulse(runtime_elapsed)
	var fade: float = clampf(ratio / 0.18, 0.0, 1.0)
	var radius := capture_bubble_radius * pulse
	_draw_bubble_core(canvas, center, radius, 0.72 * fade, 0.30 * fade, capture_visual_seed, inner_bubble_size_variance)
	canvas.draw_arc(center, radius * 0.74, -PI * 0.22, PI * 0.78, 24, Color(0.90, 1.0, 1.0, 0.44 * fade), 2.0, true)
	canvas.draw_circle(center + Vector2(-radius * 0.24, -radius * 0.20), radius * 0.12, Color(1.0, 1.0, 1.0, 0.28 * fade))


func _draw_burst(canvas: CanvasItem, center: Vector2, burst_timer: float, burst_flash_seconds: float) -> void:
	var ratio: float = clampf(burst_timer / maxf(0.001, burst_flash_seconds), 0.0, 1.0)
	var expansion: float = 1.0 - ratio
	var radius: float = lerpf(20.0, 76.0, expansion)
	canvas.draw_circle(center, radius * 0.55, Color(0.46, 0.96, 1.0, 0.18 * ratio))
	canvas.draw_arc(center, radius, 0.0, TAU, 40, Color(0.84, 1.0, 1.0, 0.58 * ratio), 2.2, true)
	for i in range(10):
		var angle: float = TAU * float(i) / 10.0 + expansion * 0.9
		var start: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.42
		var end: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		canvas.draw_line(start, end, Color(0.92, 1.0, 1.0, 0.36 * ratio), 1.4, true)


func _draw_bubble_core(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	fill_alpha: float,
	rim_alpha: float,
	detail_seed: float,
	inner_bubble_size_variance: float
) -> void:
	if radius <= 0.5:
		return
	canvas.draw_circle(center, radius * 1.08, Color(0.42, 0.92, 1.0, fill_alpha * 0.10))
	canvas.draw_circle(center, radius, Color(0.40, 0.90, 1.0, fill_alpha * 0.24))
	canvas.draw_circle(center + Vector2(-radius * 0.18, -radius * 0.22), radius * 0.56, Color(0.86, 1.0, 1.0, fill_alpha * 0.15))
	canvas.draw_circle(center + Vector2(radius * 0.20, radius * 0.26), radius * 0.46, Color(0.17, 0.62, 0.84, fill_alpha * 0.07))
	_draw_inner_bubbles(canvas, center, radius, fill_alpha, detail_seed, inner_bubble_size_variance)
	canvas.draw_arc(center, radius, -PI * 0.08, PI * 1.44, 52, Color(0.86, 1.0, 1.0, rim_alpha + 0.34), 2.0, true)
	canvas.draw_arc(center, radius * 0.90, PI * 1.08, PI * 1.70, 24, Color(1.0, 1.0, 1.0, 0.46), 2.0, true)
	canvas.draw_arc(center, radius * 0.82, -PI * 0.14, PI * 0.20, 18, Color(0.20, 0.66, 0.84, 0.30), 1.6, true)
	canvas.draw_circle(center + Vector2(-radius * 0.34, -radius * 0.34), radius * 0.17, Color(1.0, 1.0, 1.0, 0.24))
	canvas.draw_circle(center + Vector2(radius * 0.16, radius * 0.42), radius * 0.09, Color(1.0, 1.0, 1.0, 0.18))


func _draw_inner_bubbles(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	fill_alpha: float,
	detail_seed: float,
	inner_bubble_size_variance: float
) -> void:
	for index in range(INNER_BUBBLE_OFFSETS.size()):
		var offset: Vector2 = INNER_BUBBLE_OFFSETS[index]
		var jitter_angle: float = _seeded_unit(detail_seed, float(index) + 17.0) * TAU
		var jitter_amount: float = radius * 0.045 * _seeded_unit(detail_seed, float(index) + 31.0)
		var bubble_pos := center + offset * radius + Vector2(cos(jitter_angle), sin(jitter_angle)) * jitter_amount
		var base_radius: float = float(INNER_BUBBLE_RADII[index]) * radius
		var inner_radius := maxf(1.2, base_radius * _get_inner_bubble_size_scale(detail_seed, index, inner_bubble_size_variance))
		canvas.draw_circle(bubble_pos, inner_radius, Color(0.80, 0.98, 1.0, fill_alpha * 0.16))
		canvas.draw_arc(bubble_pos, inner_radius, 0.0, TAU, 18, Color(0.94, 1.0, 1.0, 0.32), 1.1, true)
		canvas.draw_circle(bubble_pos + Vector2(-inner_radius * 0.26, -inner_radius * 0.24), maxf(0.8, inner_radius * 0.22), Color(1.0, 1.0, 1.0, 0.26))


func _draw_particles(canvas: CanvasItem, particles: Array, shake_offset: Vector2) -> void:
	for particle_value in particles:
		var particle := particle_value as Dictionary
		var max_life: float = maxf(0.01, float(particle["max_life"]))
		var life_t: float = clampf(float(particle["life"]) / max_life, 0.0, 1.0)
		var alpha: float = clampf(life_t * 1.35, 0.0, 1.0)
		if alpha <= 0.02:
			continue
		var pos: Vector2 = (particle["pos"] as Vector2) + shake_offset
		var size: float = float(particle["size"]) * (0.72 + 0.28 * life_t)
		canvas.draw_circle(pos, size, Color(0.70, 1.0, 1.0, alpha * 0.62))


func _get_projectile_radius(projectile: Dictionary, projectile_radius: float) -> float:
	if bool(projectile.get("is_rainbow", false)):
		return projectile_radius * maxf(1.0, float(projectile.get("rainbow_size_mult", 2.0)))
	return projectile_radius * clampf(float(projectile.get("radius_scale", 1.0)), 0.70, 1.30)


func _get_rainbow_hue(runtime_elapsed: float, center: Vector2) -> float:
	return fmod(maxf(0.0, runtime_elapsed) * 0.15 + center.x * 0.002, 1.0)


func _get_capture_pulse(runtime_elapsed: float) -> float:
	return 0.94 + 0.06 * sin(maxf(0.0, runtime_elapsed) * 7.2)


func _get_inner_bubble_size_scale(detail_seed: float, index: int, size_variance: float) -> float:
	return lerpf(1.0 - size_variance, 1.0 + size_variance, _seeded_unit(detail_seed, float(index) + 53.0))


func _seeded_unit(seed_value: float, salt: float) -> float:
	var hashed: float = sin(seed_value * 9283.33 + salt * 47.77) * 43758.5453
	return hashed - floor(hashed)
