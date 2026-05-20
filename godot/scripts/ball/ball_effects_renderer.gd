extends RefCounted

const BallIntensityEffectRenderer := preload("res://scripts/ball/ball_intensity_effect_renderer.gd")
const BallRenderToggles := preload("res://scripts/core/ball_render_toggles.gd")
const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")

const BALL_OUTER_COLOR := Color(30.0 / 255.0, 100.0 / 255.0, 200.0 / 255.0)
const BALL_INNER_COLOR := Color(100.0 / 255.0, 180.0 / 255.0, 255.0 / 255.0)
const BALL_CORE_COLOR := Color(1.0, 1.0, 1.0)
const GHOST_TRAIL_OUTER_COLOR := Color(58.0 / 255.0, 8.0 / 255.0, 110.0 / 255.0)
const GHOST_TRAIL_INNER_COLOR := Color(142.0 / 255.0, 54.0 / 255.0, 235.0 / 255.0)
const GHOST_TRAIL_CORE_COLOR := Color(226.0 / 255.0, 142.0 / 255.0, 1.0)
const ENERGY_PARTICLE_GLOW_SIZE_THRESHOLD := 3.0
const ENERGY_PARTICLE_TRAIL_ALPHA_THRESHOLD := 0.16
const MAX_RENDERED_GHOST_TRAIL := 4
const MAX_RENDERED_ENERGY_PARTICLES := 22
const SEVERE_LOD_SCALE_THRESHOLD := 0.50
const SEVERE_LOD_ENERGY_PARTICLE_LIMIT := 7

var intensity_renderer: Object = BallIntensityEffectRenderer.new()


func _init() -> void:
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()


func draw_active_effects(
	canvas: Node2D,
	shake_offset: Vector2,
	context: Dictionary,
	perf_logger: Object = null
) -> void:
	if canvas == null:
		return

	var lod_scale: float = clamp(float(context.get("effect_lod_scale", 1.0)), 0.25, 1.0)
	var severe_lod: bool = lod_scale <= SEVERE_LOD_SCALE_THRESHOLD
	var ghost_trail: Array = context.get("ball_ghost_trail", [])
	if not ghost_trail.is_empty():
		var ghost_start: int = _perf_begin(perf_logger)
		var ghost_shot_trail: bool = (
			bool(context.get("ghost_shot_motion_active", false))
			or bool(context.get("ghost_shot_active", false))
		)
		var ghost_limit: int = _scaled_limit(MAX_RENDERED_GHOST_TRAIL, lod_scale, 2)
		_draw_ball_ghost_trail(canvas, shake_offset, ghost_trail, ghost_shot_trail, ghost_limit)
		_perf_end(perf_logger, "draw.ball_effects.ghost_trail", ghost_start)
	if not BallRenderToggles.is_intensity_effects_disabled():
		var intensity_start: int = _perf_begin(perf_logger)
		intensity_renderer.draw(canvas, shake_offset, context)
		_perf_end(perf_logger, "draw.ball_effects.intensity", intensity_start)
	var energy_particles: Array = context.get("energy_explosion_particles", [])
	if not energy_particles.is_empty() and not BallRenderToggles.is_energy_particles_disabled():
		var energy_start: int = _perf_begin(perf_logger)
		var energy_limit: int = _scaled_limit(MAX_RENDERED_ENERGY_PARTICLES, lod_scale, 9)
		if severe_lod:
			energy_limit = min(energy_limit, SEVERE_LOD_ENERGY_PARTICLE_LIMIT)
		_draw_energy_explosion_particles(canvas, shake_offset, energy_particles, energy_limit, severe_lod)
		_perf_end(perf_logger, "draw.ball_effects.energy_particles", energy_start)


func _draw_ball_ghost_trail(
	canvas: Node2D,
	shake_offset: Vector2,
	ghost_trail: Array,
	ghost_shot_trail: bool = false,
	render_limit: int = MAX_RENDERED_GHOST_TRAIL
) -> void:
	if ghost_trail.is_empty():
		return

	var total_points: int = ghost_trail.size()
	var trail_start: int = max(0, total_points - render_limit)
	var outer_color: Color = GHOST_TRAIL_OUTER_COLOR if ghost_shot_trail else BALL_OUTER_COLOR
	var inner_color: Color = GHOST_TRAIL_INNER_COLOR if ghost_shot_trail else BALL_INNER_COLOR
	var core_color: Color = GHOST_TRAIL_CORE_COLOR if ghost_shot_trail else BALL_CORE_COLOR
	for i in range(trail_start, total_points):
		var point: Dictionary = ghost_trail[i]
		var point_alpha: float = float(point["alpha"])
		if point_alpha < 3.0 / 255.0:
			continue

		var position_ratio: float = float(i) / max(1.0, float(total_points - 1))
		var base_alpha: float = point_alpha * pow(position_ratio, 0.7) * 0.6
		if base_alpha < 3.0 / 255.0:
			continue

		var ghost_size: float = float(point["size"]) * (0.72 + position_ratio * 0.24)
		if ghost_size < 2.0:
			continue

		var draw_pos: Vector2 = point["pos"] + shake_offset
		if ghost_shot_trail and i > trail_start:
			var prev_value: Variant = ghost_trail[i - 1]
			if prev_value is Dictionary:
				var previous: Dictionary = prev_value
				var prev_pos: Vector2 = previous.get("pos", Vector2.ZERO) + shake_offset
				canvas.draw_line(prev_pos, draw_pos, Color(outer_color.r, outer_color.g, outer_color.b, base_alpha * 0.38), max(1.0, ghost_size * 0.16), true)
		ImpactFlareTextureCache.draw_glow(canvas, draw_pos, ghost_size * 0.95, inner_color, base_alpha * (0.70 if ghost_shot_trail else 0.58))
		if position_ratio > 0.65:
			ImpactFlareTextureCache.draw_sparkle(canvas, draw_pos, max(5.0, ghost_size * 0.36), core_color, base_alpha * (0.48 if ghost_shot_trail else 0.36))


func _draw_energy_explosion_particles(
	canvas: Node2D,
	shake_offset: Vector2,
	particles: Array,
	render_limit: int,
	severe_lod: bool
) -> void:
	var particle_start: int = max(0, particles.size() - render_limit)
	for particle_index in range(particle_start, particles.size()):
		var particle: Dictionary = particles[particle_index]
		if str(particle.get("type", "explosion")) == "burst":
			if severe_lod:
				_draw_energy_burst_compact(canvas, shake_offset, particle)
			else:
				_draw_energy_burst(canvas, shake_offset, particle)
			continue
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
		if size > ENERGY_PARTICLE_GLOW_SIZE_THRESHOLD and not severe_lod:
			ImpactFlareTextureCache.draw_glow(canvas, draw_pos, size * 1.55, color, alpha * 0.20)
		if str(particle["type"]) == "spark" and particle.has("vel") and not severe_lod:
			var vel: Vector2 = particle["vel"]
			var speed: float = vel.length()
			if speed > 0.15 and alpha > ENERGY_PARTICLE_TRAIL_ALPHA_THRESHOLD:
				var trail_dir: Vector2 = vel / speed
				var trail_len: float = min(28.0, speed * 1.8) * alpha
				canvas.draw_line(
					draw_pos - trail_dir * trail_len,
					draw_pos,
					Color(color.r, color.g, color.b, alpha * 0.36),
					max(0.8, size * 0.62),
					true
				)
		ImpactFlareTextureCache.draw_sparkle(canvas, draw_pos, size, color, min(alpha, 0.64))
		if str(particle["type"]) == "spark" and size > 1.4 and not severe_lod:
			ImpactFlareTextureCache.draw_sparkle(canvas, draw_pos, max(1.0, size * 0.5), Color(220.0 / 255.0, 240.0 / 255.0, 1.0), min(alpha * 0.52, 0.52))


func _draw_energy_burst(canvas: Node2D, shake_offset: Vector2, burst: Dictionary) -> void:
	var lifetime: float = float(burst.get("lifetime", 0.0))
	var max_lifetime: float = max(1.0, float(burst.get("max_lifetime", 1.0)))
	var progress: float = clamp(lifetime / max_lifetime, 0.0, 1.0)
	var alpha: float = pow(1.0 - progress, 1.45)
	if alpha < 6.0 / 255.0:
		return
	var center: Vector2 = burst.get("pos", Vector2.ZERO) + shake_offset
	var color: Color = burst.get("color", BALL_INNER_COLOR)
	var intensity: float = clamp(float(burst.get("intensity", 0.0)), 0.0, 1.5)
	var radius: float = float(burst.get("size", 40.0)) * (0.58 + progress * (0.52 + intensity * 0.10))
	var hot_color := color.lerp(Color.WHITE, 0.26)

	ImpactFlareTextureCache.draw_burst(canvas, center, radius * 1.12, hot_color, (0.20 + intensity * 0.035) * alpha)
	ImpactFlareTextureCache.draw_glow(canvas, center, radius * 0.92, color, (0.24 + intensity * 0.045) * alpha)
	ImpactFlareTextureCache.draw_sparkle(canvas, center, max(18.0, radius * 0.34), Color.WHITE, (0.30 + intensity * 0.05) * alpha)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, center, radius * 0.64, color, (0.20 + intensity * 0.04) * alpha)


func _draw_energy_burst_compact(canvas: Node2D, shake_offset: Vector2, burst: Dictionary) -> void:
	var lifetime: float = float(burst.get("lifetime", 0.0))
	var max_lifetime: float = max(1.0, float(burst.get("max_lifetime", 1.0)))
	var progress: float = clamp(lifetime / max_lifetime, 0.0, 1.0)
	var alpha: float = pow(1.0 - progress, 1.45)
	if alpha < 6.0 / 255.0:
		return
	var center: Vector2 = burst.get("pos", Vector2.ZERO) + shake_offset
	var color: Color = burst.get("color", BALL_INNER_COLOR)
	var intensity: float = clamp(float(burst.get("intensity", 0.0)), 0.0, 1.5)
	var radius: float = float(burst.get("size", 40.0)) * (0.52 + progress * (0.46 + intensity * 0.08))
	ImpactFlareTextureCache.draw_glow(canvas, center, radius * 0.86, color, (0.20 + intensity * 0.035) * alpha)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, center, radius * 0.56, color, (0.16 + intensity * 0.03) * alpha)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _scaled_limit(base_limit: int, scale: float, minimum: int) -> int:
	if scale >= 0.999:
		return base_limit
	return max(minimum, int(ceil(float(base_limit) * scale)))
