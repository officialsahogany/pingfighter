extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")

const DEFAULT_DISPLAY_COLORS: Array[Color] = [
	Color(100.0 / 255.0, 180.0 / 255.0, 1.0),
	Color(80.0 / 255.0, 160.0 / 255.0, 1.0),
	Color(60.0 / 255.0, 140.0 / 255.0, 1.0),
]
const MAX_RENDERED_INTENSITY_TRAIL := 6
const MAX_RENDERED_INTENSITY_PARTICLES := 28
const SEVERE_LOD_SCALE_THRESHOLD := 0.50
const SEVERE_LOD_INTENSITY_TRAIL_LIMIT := 3
const SEVERE_LOD_INTENSITY_PARTICLE_LIMIT := 8


func _init() -> void:
	ImpactFlareTextureCache.prewarm()


func draw(canvas: Node2D, shake_offset: Vector2, context: Dictionary) -> void:
	var intensity: float = float(context.get("intensity", 0.0))
	if intensity < 0.05:
		return

	var intensity_trail: Array = context.get("ball_intensity_trail", [])
	var intensity_particles: Array = context.get("ball_intensity_particles", [])
	var display_colors: Array = context.get("ball_current_display_colors", DEFAULT_DISPLAY_COLORS)
	if display_colors.size() < 3:
		display_colors = DEFAULT_DISPLAY_COLORS

	var lod_scale: float = clamp(float(context.get("effect_lod_scale", 1.0)), 0.25, 1.0)
	var severe_lod: bool = lod_scale <= SEVERE_LOD_SCALE_THRESHOLD
	var trail_limit: int = _scaled_limit(MAX_RENDERED_INTENSITY_TRAIL, lod_scale, 3)
	var particle_limit: int = _scaled_limit(MAX_RENDERED_INTENSITY_PARTICLES, lod_scale, 10)
	if severe_lod:
		trail_limit = min(trail_limit, SEVERE_LOD_INTENSITY_TRAIL_LIMIT)
		particle_limit = min(particle_limit, SEVERE_LOD_INTENSITY_PARTICLE_LIMIT)
	_draw_trail(canvas, shake_offset, intensity, intensity_trail, display_colors, trail_limit)
	_draw_particles(canvas, shake_offset, intensity, intensity_particles, particle_limit, severe_lod)
	if not severe_lod:
		_draw_current_ball_glow(canvas, shake_offset, intensity, context)


func _draw_trail(
	canvas: Node2D,
	shake_offset: Vector2,
	intensity: float,
	intensity_trail: Array,
	display_colors: Array,
	render_limit: int
) -> void:
	if intensity_trail.is_empty():
		return
	var total_points: int = intensity_trail.size()
	var trail_start: int = max(0, total_points - render_limit)
	for i in range(trail_start, total_points):
		var point: Dictionary = intensity_trail[i]
		var alpha: float = float(point["alpha"])
		if alpha < 5.0 / 255.0:
			continue

		var position_ratio: float = float(i) / max(1.0, float(total_points - 1))
		var size: float = float(point["size"]) * (0.3 + position_ratio * 0.7)
		if size < 1.0:
			continue

		var color_index: int = min(2, int((1.0 - position_ratio) * 3.0))
		var base_color: Color = display_colors[color_index]
		var draw_alpha: float = alpha * (0.5 + intensity * 0.5)
		var draw_pos: Vector2 = point["pos"] + shake_offset
		var inner_color: Color = _brighten_color(base_color, 50.0 / 255.0)
		ImpactFlareTextureCache.draw_glow(canvas, draw_pos, max(1.0, size * 0.72), inner_color, draw_alpha * 0.62)


func _draw_particles(
	canvas: Node2D,
	shake_offset: Vector2,
	intensity: float,
	intensity_particles: Array,
	render_limit: int,
	severe_lod: bool
) -> void:
	var particle_start: int = max(0, intensity_particles.size() - render_limit)
	for particle_index in range(particle_start, intensity_particles.size()):
		var particle: Dictionary = intensity_particles[particle_index]
		var life: float = float(particle["life"])
		var max_life: float = float(particle["max_life"])
		var base_size: float = float(particle["size"])
		if life <= 0.0 or base_size < 0.5:
			continue

		var alpha: float = (life / max_life) * (0.5 + intensity * 0.5)
		if alpha < 5.0 / 255.0:
			continue

		var size: float = max(1.0, base_size)
		var draw_pos: Vector2 = particle["pos"] + shake_offset
		if str(particle["type"]) == "flame":
			var base_color: Color = particle["color"]
			var inner_color: Color = _brighten_color(base_color, 80.0 / 255.0)
			ImpactFlareTextureCache.draw_glow(canvas, draw_pos, size * 0.70, base_color, alpha * 0.40)
			if not severe_lod and size > 3.2:
				ImpactFlareTextureCache.draw_sparkle(canvas, draw_pos, max(2.0, size * 0.28), inner_color, alpha * 0.48)
		else:
			var lod_alpha: float = alpha * (0.46 if severe_lod else 0.72)
			ImpactFlareTextureCache.draw_sparkle(canvas, draw_pos, max(2.0, size * 0.42), Color(1.0, 1.0, 200.0 / 255.0), lod_alpha)


func _draw_current_ball_glow(canvas: Node2D, shake_offset: Vector2, intensity: float, context: Dictionary) -> void:
	if intensity <= 0.2:
		return
	var ball_size: float = float(context.get("ball_size", 28.6))
	var ball_render_radius: float = max(ball_size * 0.5, float(context.get("ball_render_radius", ball_size * 0.5)))
	var ball_pos: Vector2 = context.get("ball_pos", Vector2.ZERO)
	var glow_color: Color = context.get("ball_current_glow_color", Color(60.0 / 255.0, 100.0 / 255.0, 180.0 / 255.0, 30.0 / 255.0))
	var glow_size: float = ball_render_radius * (1.0 + intensity * 0.3)
	var glow_alpha: float = glow_color.a * 0.5 * intensity
	if glow_alpha > 5.0 / 255.0:
		ImpactFlareTextureCache.draw_glow(canvas, ball_pos + shake_offset, glow_size, glow_color, glow_alpha)


func _brighten_color(color: Color, amount: float) -> Color:
	return Color(
		clamp(color.r + amount, 0.0, 1.0),
		clamp(color.g + amount, 0.0, 1.0),
		clamp(color.b + amount, 0.0, 1.0),
		color.a
	)


func _scaled_limit(base_limit: int, scale: float, minimum: int) -> int:
	if scale >= 0.999:
		return base_limit
	return max(minimum, int(ceil(float(base_limit) * scale)))
