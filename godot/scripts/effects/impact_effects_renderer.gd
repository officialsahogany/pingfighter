extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")

const PARTICLE_GLOW_SIZE_THRESHOLD := 2.8
const PARTICLE_TRAIL_ALPHA_THRESHOLD := 0.24
const MAX_RENDERED_HIT_FLASHES := 4
const MAX_RENDERED_HIT_RINGS := 6
const MAX_RENDERED_HIT_STREAKS := 8
const MAX_RENDERED_HIT_PARTICLES := 18
const MAX_RENDERED_WALL_RINGS := 5
const MAX_RENDERED_WALL_PARTICLES := 10


func _init() -> void:
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()


func draw(canvas: Node2D, effect_state, shake_offset: Vector2) -> void:
	if canvas == null or effect_state == null:
		return
	if effect_state.has_method("has_visible_effects") and not bool(effect_state.has_visible_effects()):
		return

	_draw_hit_flashes(canvas, shake_offset, effect_state.get_hit_flashes())
	_draw_hit_rings(canvas, shake_offset, effect_state.get_hit_rings())
	_draw_hit_streaks(canvas, shake_offset, effect_state.get_hit_streaks())
	_draw_hit_particles(canvas, shake_offset, effect_state.get_hit_particles())
	_draw_wall_impact_effects(
		canvas,
		shake_offset,
		effect_state.get_wall_impact_flash_timer(),
		effect_state.get_wall_impact_position(),
		effect_state.get_wall_impact_particles(),
		effect_state.get_wall_impact_rings()
	)


func _draw_hit_flashes(canvas: Node2D, shake_offset: Vector2, flashes: Array) -> void:
	var flash_start: int = max(0, flashes.size() - MAX_RENDERED_HIT_FLASHES)
	for flash_index in range(flash_start, flashes.size()):
		var flash: Dictionary = flashes[flash_index]
		var life: float = float(flash.get("life", 0.0))
		var max_life: float = max(0.001, float(flash.get("max_life", 0.001)))
		var progress: float = 1.0 - clamp(life / max_life, 0.0, 1.0)
		var alpha: float = pow(1.0 - progress, 2.0)
		if alpha <= 0.01:
			continue
		var color: Color = flash.get("color", Color.WHITE)
		var pos: Vector2 = flash.get("pos", Vector2.ZERO) + shake_offset
		var radius: float = float(flash.get("radius", 20.0)) * (0.55 + progress * 0.65)
		ImpactFlareTextureCache.draw_burst(canvas, pos, radius * 1.55, color, 0.22 * alpha)
		ImpactFlareTextureCache.draw_glow(canvas, pos, radius * 1.10, color, 0.26 * alpha)
		ImpactFlareTextureCache.draw_sparkle(canvas, pos, radius * 0.52, Color.WHITE, 0.44 * alpha)


func _draw_hit_rings(canvas: Node2D, shake_offset: Vector2, rings: Array) -> void:
	var ring_start: int = max(0, rings.size() - MAX_RENDERED_HIT_RINGS)
	for ring_index in range(ring_start, rings.size()):
		var ring: Dictionary = rings[ring_index]
		var life: float = float(ring.get("life", 0.0))
		var max_life: float = max(0.001, float(ring.get("max_life", 0.001)))
		var progress: float = 1.0 - clamp(life / max_life, 0.0, 1.0)
		var alpha: float = pow(1.0 - progress, 1.35)
		if alpha <= 0.01:
			continue
		var color: Color = ring.get("color", Color.WHITE)
		var pos: Vector2 = ring.get("pos", Vector2.ZERO) + shake_offset
		var radius: float = lerp(float(ring.get("start_radius", 6.0)), float(ring.get("end_radius", 32.0)), progress)
		ImpactShockwaveTextureCache.draw_full_ring(
			canvas,
			pos,
			radius,
			color,
			0.62 * alpha
		)
		if progress < 0.65:
			ImpactShockwaveTextureCache.draw_full_ring(
				canvas,
				pos,
				radius * 0.64,
				Color.WHITE,
				0.24 * alpha
			)


func _draw_hit_streaks(canvas: Node2D, shake_offset: Vector2, streaks: Array) -> void:
	var streak_start: int = max(0, streaks.size() - MAX_RENDERED_HIT_STREAKS)
	for streak_index in range(streak_start, streaks.size()):
		var streak: Dictionary = streaks[streak_index]
		var life: float = float(streak.get("life", 0.0))
		var max_life: float = max(0.001, float(streak.get("max_life", 0.001)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		if alpha <= 0.01:
			continue
		var dir: Vector2 = streak.get("dir", Vector2.RIGHT)
		if dir.length_squared() <= 0.001:
			dir = Vector2.RIGHT
		dir = dir.normalized()
		var pos: Vector2 = streak.get("pos", Vector2.ZERO) + shake_offset
		var length: float = float(streak.get("length", 18.0)) * (0.45 + alpha * 0.55)
		var width: float = max(0.5, float(streak.get("width", 1.5)) * alpha)
		var color: Color = streak.get("color", Color.WHITE)
		var start_pos: Vector2 = pos - dir * length * 0.18
		var end_pos: Vector2 = pos + dir * length * 0.82
		canvas.draw_line(start_pos, end_pos, Color(color.r, color.g, color.b, 0.58 * alpha), max(1.0, width + 0.8), true)


func _draw_hit_particles(canvas: Node2D, shake_offset: Vector2, particles: Array) -> void:
	var particle_start: int = max(0, particles.size() - MAX_RENDERED_HIT_PARTICLES)
	for particle_index in range(particle_start, particles.size()):
		var particle: Dictionary = particles[particle_index]
		var life: float = float(particle["life"])
		var max_life: float = max(0.001, float(particle["max_life"]))
		var alpha: float = life / max_life
		var size: float = float(particle["size"]) * alpha
		if alpha <= 0.0 or size <= 0.0:
			continue
		var particle_pos: Vector2 = particle["pos"]
		var color: Color = particle["color"]
		if particle.has("vel"):
			var vel: Vector2 = particle["vel"]
			var speed: float = vel.length()
			if speed > 0.15 and alpha > PARTICLE_TRAIL_ALPHA_THRESHOLD:
				var trail_length: float = float(particle.get("trail", 7.0)) * alpha
				var trail_dir: Vector2 = vel / speed
				canvas.draw_line(
					particle_pos + shake_offset - trail_dir * trail_length,
					particle_pos + shake_offset,
					Color(color.r, color.g, color.b, 0.30 * alpha),
					max(0.8, size * 0.7),
					true
				)
		var draw_pos: Vector2 = particle_pos + shake_offset
		if size > PARTICLE_GLOW_SIZE_THRESHOLD:
			ImpactFlareTextureCache.draw_glow(canvas, draw_pos, size * 1.65, color, 0.11 * alpha)
		ImpactFlareTextureCache.draw_sparkle(canvas, draw_pos, size, color, min(0.62, alpha))


func _draw_wall_impact_effects(
	canvas: Node2D,
	shake_offset: Vector2,
	flash_timer: float,
	flash_position: Vector2,
	particles: Array,
	rings: Array
) -> void:
	if flash_timer <= 0.0 and particles.is_empty() and rings.is_empty():
		return
	if flash_timer > 0.0:
		var progress: float = flash_timer / (8.0 / 60.0)
		var flash_radius: float = 25.0 + (1.0 - progress) * 24.0
		var flash_pos: Vector2 = flash_position + shake_offset
		var flash_color := Color(180.0 / 255.0, 220.0 / 255.0, 1.0)
		ImpactFlareTextureCache.draw_burst(canvas, flash_pos, flash_radius * 1.45, flash_color, 0.15 * progress)
		ImpactFlareTextureCache.draw_glow(canvas, flash_pos, flash_radius, flash_color, 0.18 * progress)
		ImpactFlareTextureCache.draw_sparkle(canvas, flash_pos, flash_radius * 0.38, Color.WHITE, 0.25 * progress)

	var wall_ring_start: int = max(0, rings.size() - MAX_RENDERED_WALL_RINGS)
	for ring_index in range(wall_ring_start, rings.size()):
		var ring: Dictionary = rings[ring_index]
		var ring_life: float = float(ring.get("life", 0.0))
		var ring_max_life: float = max(0.001, float(ring.get("max_life", 0.001)))
		var ring_progress: float = 1.0 - clamp(ring_life / ring_max_life, 0.0, 1.0)
		var ring_alpha: float = pow(1.0 - ring_progress, 1.25)
		if ring_alpha <= 0.01:
			continue
		var side: String = str(ring.get("side", "left"))
		var ring_color: Color = ring.get("color", Color(0.75, 0.90, 1.0))
		var ring_pos: Vector2 = ring.get("pos", Vector2.ZERO) + shake_offset
		var ring_radius: float = lerp(float(ring.get("start_radius", 8.0)), float(ring.get("end_radius", 36.0)), ring_progress)
		ImpactShockwaveTextureCache.draw_wall_ring(
			canvas,
			side,
			ring_pos,
			ring_radius,
			ring_color,
			0.68 * ring_alpha
		)
		if ring_progress < 0.75:
			ImpactShockwaveTextureCache.draw_wall_ring(
				canvas,
				side,
				ring_pos,
				ring_radius * 0.72,
				Color.WHITE,
				0.18 * ring_alpha
			)

	var wall_particle_start: int = max(0, particles.size() - MAX_RENDERED_WALL_PARTICLES)
	for particle_index in range(wall_particle_start, particles.size()):
		var particle: Dictionary = particles[particle_index]
		var life: float = float(particle["life"])
		var max_life: float = max(0.001, float(particle["max_life"]))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		var color: Color = particle["color"]
		var particle_pos: Vector2 = particle["pos"]
		var size: float = float(particle["size"])
		if alpha <= 0.0 or size <= 0.5:
			continue
		if particle.has("vel"):
			var vel: Vector2 = particle["vel"]
			var speed: float = vel.length()
			if speed > 0.15 and alpha > PARTICLE_TRAIL_ALPHA_THRESHOLD:
				var trail_len: float = float(particle.get("trail", 7.0)) * alpha
				var trail_dir: Vector2 = vel / speed
				canvas.draw_line(
					particle_pos + shake_offset - trail_dir * trail_len,
					particle_pos + shake_offset,
					Color(color.r, color.g, color.b, 0.28 * alpha),
					max(0.8, size * 0.60),
					true
				)
		var draw_pos: Vector2 = particle_pos + shake_offset
		if size > PARTICLE_GLOW_SIZE_THRESHOLD:
			ImpactFlareTextureCache.draw_glow(canvas, draw_pos, size * 1.65, color, 0.10 * alpha)
		ImpactFlareTextureCache.draw_sparkle(canvas, draw_pos, size, color, 0.54 * alpha)
