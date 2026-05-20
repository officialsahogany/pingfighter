extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")

const SKY_BLUE := Color(100.0 / 255.0, 200.0 / 255.0, 1.0)
const MAIN_BLUE := Color(200.0 / 255.0, 230.0 / 255.0, 1.0)
const CORE_WHITE := Color(1.0, 1.0, 1.0)
const LASER_WIDTH := 8.0
const MAX_RENDERED_EVAPORATION_PARTICLES := 28


func _init() -> void:
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()


func draw(canvas: CanvasItem, lasers: Array, particles: Array, shake_offset: Vector2) -> void:
	if canvas == null:
		return
	if lasers.is_empty() and particles.is_empty():
		return
	for laser in lasers:
		_draw_laser(canvas, laser, shake_offset)
	var particle_start: int = max(0, particles.size() - MAX_RENDERED_EVAPORATION_PARTICLES)
	for index in range(particle_start, particles.size()):
		_draw_evaporation_particle(canvas, particles[index], shake_offset)


func _draw_laser(canvas: CanvasItem, laser: Dictionary, shake_offset: Vector2) -> void:
	var alpha: float = clamp(float(laser.get("alpha", 255.0)) / 255.0, 0.0, 1.0)
	if alpha < 0.04:
		return
	var start: Vector2 = _as_vector2(laser.get("start", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var end: Vector2 = _as_vector2(laser.get("end", Vector2.ZERO), Vector2.ZERO) + shake_offset
	if start.distance_squared_to(end) <= 0.01:
		return

	for layer in range(2, 0, -1):
		var glow_alpha: float = min(1.0, alpha * 0.20 / float(layer))
		var glow_width: float = LASER_WIDTH + float(layer) * 4.0
		canvas.draw_line(start, end, Color(SKY_BLUE.r, SKY_BLUE.g, SKY_BLUE.b, glow_alpha), glow_width, true)
	canvas.draw_line(start, end, Color(MAIN_BLUE.r, MAIN_BLUE.g, MAIN_BLUE.b, alpha), LASER_WIDTH + 2.0, true)
	canvas.draw_line(start, end, Color(CORE_WHITE.r, CORE_WHITE.g, CORE_WHITE.b, alpha * 0.82), max(2.0, LASER_WIDTH / 3.0), true)
	ImpactFlareTextureCache.draw_glow(canvas, start, LASER_WIDTH * 1.25, MAIN_BLUE, alpha * 0.34)
	ImpactFlareTextureCache.draw_sparkle(canvas, end, LASER_WIDTH * 0.95, CORE_WHITE, alpha * 0.48)

	if float(laser.get("remaining_time", 0.0)) > float(laser.get("duration", 360.0)) - 10.0:
		var impact_frame: float = 10.0 - (float(laser.get("duration", 360.0)) - float(laser.get("remaining_time", 0.0)))
		var impact_radius: float = max(2.0, impact_frame * 3.0)
		ImpactShockwaveTextureCache.draw_full_ring(canvas, start, impact_radius, Color(150.0 / 255.0, 220.0 / 255.0, 1.0), alpha * 0.28)

	var segments: Array = _as_array(laser.get("electric_segments", []))
	for i in range(max(0, segments.size() - 1)):
		var from_point: Vector2 = _segment_draw_point(segments[i]) + shake_offset
		var to_point: Vector2 = _segment_draw_point(segments[i + 1]) + shake_offset
		canvas.draw_line(from_point, to_point, Color(CORE_WHITE.r, CORE_WHITE.g, CORE_WHITE.b, alpha * 0.90), 2.0, true)

	var now: float = float(Time.get_ticks_msec()) * 0.001
	for i in range(1):
		var t: float = fmod(now * 0.72 + float(i) * 0.43, 1.0)
		var spark_pos: Vector2 = start.lerp(end, t) + Vector2(
			sin(now * 23.0 + float(i) * 2.0) * 3.0,
			cos(now * 19.0 + float(i) * 1.7) * 6.0
		)
		var spark_alpha: float = alpha * (0.56 + 0.28 * (0.5 + 0.5 * sin(now * 17.0 + float(i))))
		ImpactFlareTextureCache.draw_sparkle(canvas, spark_pos, 2.6, MAIN_BLUE, spark_alpha * 0.62)


func _draw_evaporation_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	var alpha: float = clamp(float(particle.get("alpha", 0.0)) / 255.0, 0.0, 1.0)
	var size: float = float(particle.get("size", 0.0))
	if alpha <= 0.0 or size <= 0.0:
		return
	var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var life_ratio: float = clamp(
		float(particle.get("lifetime", 1.0)) / max(1.0, float(particle.get("max_lifetime", 1.0))),
		0.0,
		1.0
	)
	var base_color: Color = _as_color(particle.get("color", MAIN_BLUE), MAIN_BLUE)
	var draw_color: Color = base_color.lerp(CORE_WHITE, 1.0 - life_ratio)
	ImpactFlareTextureCache.draw_sparkle(canvas, pos, max(2.4, size * 1.35), draw_color, alpha * 0.72)


func _segment_draw_point(segment: Variant) -> Vector2:
	if segment is Dictionary:
		var base: Vector2 = _as_vector2(segment.get("base", Vector2.ZERO), Vector2.ZERO)
		var offset: Vector2 = _as_vector2(segment.get("offset", Vector2.ZERO), Vector2.ZERO)
		return base + offset
	return Vector2.ZERO


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
