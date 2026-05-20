extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")

const MAX_RENDERED_COMBO_PARTICLES := 42


func _init() -> void:
	ImpactFlareTextureCache.prewarm()


func draw(canvas: CanvasItem, combo_particles: Array[Dictionary], effect_count: int, shake_offset: Vector2) -> void:
	if canvas == null:
		return
	var particle_start: int = max(0, combo_particles.size() - MAX_RENDERED_COMBO_PARTICLES)
	for index in range(particle_start, combo_particles.size()):
		var particle: Dictionary = combo_particles[index]
		var particle_life: float = max(0.0, float(particle["life"]))
		if particle_life <= 0.0:
			continue
		var particle_max_life: float = max(1.0, float(particle.get("max_life", 60.0)))
		var particle_alpha: float = clamp(particle_life / particle_max_life, 0.0, 1.0)
		var particle_color: Color = particle["color"]
		var particle_pos: Vector2 = particle["pos"] + shake_offset
		var particle_size: float = max(1.0, float(particle["size"]) * particle_alpha)
		ImpactFlareTextureCache.draw_glow(
			canvas,
			particle_pos,
			particle_size * 2.0,
			particle_color,
			0.16 * particle_alpha
		)
		if int(particle.get("shape", 0)) == 1:
			_draw_star_particle(canvas, particle_pos, particle_size, particle_color, particle_alpha, effect_count)
		else:
			ImpactFlareTextureCache.draw_sparkle(
				canvas,
				particle_pos,
				particle_size,
				particle_color,
				0.68 * particle_alpha
			)


func _draw_star_particle(
	canvas: CanvasItem,
	particle_pos: Vector2,
	particle_size: float,
	particle_color: Color,
	particle_alpha: float,
	effect_count: int
) -> void:
	var star_len: float = particle_size * 2.3
	var star_width: float = max(1.0, particle_size * 0.42)
	var star_color: Color = Color(particle_color.r, particle_color.g, particle_color.b, 0.90 * particle_alpha)
	canvas.draw_line(particle_pos + Vector2(-star_len, 0.0), particle_pos + Vector2(star_len, 0.0), star_color, star_width)
	canvas.draw_line(particle_pos + Vector2(0.0, -star_len), particle_pos + Vector2(0.0, star_len), star_color, star_width)
	if effect_count >= 6:
		canvas.draw_line(
			particle_pos + Vector2(-star_len * 0.65, -star_len * 0.65),
			particle_pos + Vector2(star_len * 0.65, star_len * 0.65),
			Color(1.0, 1.0, 1.0, 0.58 * particle_alpha),
			max(1.0, star_width * 0.7)
		)
		canvas.draw_line(
			particle_pos + Vector2(-star_len * 0.65, star_len * 0.65),
			particle_pos + Vector2(star_len * 0.65, -star_len * 0.65),
			Color(1.0, 1.0, 1.0, 0.58 * particle_alpha),
			max(1.0, star_width * 0.7)
		)
	ImpactFlareTextureCache.draw_sparkle(canvas, particle_pos, particle_size * 0.86, Color(1.0, 1.0, 0.82), 0.80 * particle_alpha)
