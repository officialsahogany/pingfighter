extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")

const BALL_VISUAL_SCALE := 1.575
const BALL_RENDER_RADIUS := 16.9 * BALL_VISUAL_SCALE
const BALL_PARTICLE_BRIGHTNESS := 0.68
const ENERGY_BALL_MAX_PARTICLES := 12
const ENERGY_BALL_PARTICLE_COLORS: Array[Color] = [
	Color(235.0 / 255.0, 248.0 / 255.0, 1.0),
	Color(215.0 / 255.0, 238.0 / 255.0, 1.0),
	Color(185.0 / 255.0, 225.0 / 255.0, 1.0),
	Color(1.0, 1.0, 1.0),
]

var particles: Array[Dictionary] = []


func _init() -> void:
	ImpactFlareTextureCache.prewarm()


func clear() -> void:
	particles.clear()


func draw(
	canvas: CanvasItem,
	pos: Vector2,
	fx_lod_scale: float = 1.0,
	visual_alpha: float = 1.0
) -> void:
	var lod_scale: float = clamp(fx_lod_scale, 0.35, 1.0)
	_spawn_particles(lod_scale)
	_draw_particles(canvas, pos, lod_scale, clampf(visual_alpha, 0.0, 1.0))


func _spawn_particles(lod_scale: float) -> void:
	if randf() >= 0.24 * lod_scale:
		return
	var spawn_angle: float = randf_range(0.0, TAU)
	var spawn_dist: float = BALL_RENDER_RADIUS * randf_range(0.867, 1.445)
	particles.append({
		"x": cos(spawn_angle) * spawn_dist,
		"y": sin(spawn_angle) * spawn_dist,
		"vx": randf_range(-0.5, 0.5),
		"vy": randf_range(-1.5, -0.5),
		"life": float(randi_range(20, 40)),
		"max_life": 40.0,
		"size": randf_range(0.42, 1.02),
		"color": ENERGY_BALL_PARTICLE_COLORS[randi_range(0, ENERGY_BALL_PARTICLE_COLORS.size() - 1)]
	})

	var particle_limit: int = max(5, int(ceil(float(ENERGY_BALL_MAX_PARTICLES) * lod_scale)))
	while particles.size() > particle_limit:
		particles.pop_front()


func _draw_particles(
	canvas: CanvasItem, pos: Vector2, lod_scale: float, alpha_scale: float
) -> void:
	var write_idx: int = 0
	for particle_index in range(particles.size()):
		var p: Dictionary = particles[particle_index]
		var px: float = float(p["x"]) + float(p["vx"])
		var py: float = float(p["y"]) + float(p["vy"])
		var life: float = float(p["life"]) - 1.0
		var max_life: float = float(p["max_life"])
		var base_size: float = float(p["size"])
		var color: Color = p["color"]

		p["x"] = px
		p["y"] = py
		p["life"] = life

		if life > 0.0:
			var alpha: float = (200.0 * (life / max_life)) / 255.0
			var size: float = max(1.0, floor(base_size * (life / max_life)))
			var particle_pos: Vector2 = pos + Vector2(px, py)
			ImpactFlareTextureCache.draw_glow(canvas, particle_pos, size + 2.0, color, alpha * 0.22 * BALL_PARTICLE_BRIGHTNESS * lod_scale * alpha_scale)
			ImpactFlareTextureCache.draw_sparkle(canvas, particle_pos, size, color, alpha * 0.72 * BALL_PARTICLE_BRIGHTNESS * alpha_scale)
			particles[write_idx] = p
			write_idx += 1

	particles.resize(write_idx)
