extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")

const RAINBOW_COLORS := [
	Color(1.0, 0.0, 0.0),
	Color(1.0, 127.0 / 255.0, 0.0),
	Color(1.0, 1.0, 0.0),
	Color(0.0, 1.0, 0.0),
	Color(0.0, 0.0, 1.0),
	Color(75.0 / 255.0, 0.0, 130.0 / 255.0),
	Color(148.0 / 255.0, 0.0, 211.0 / 255.0),
]


func _init() -> void:
	ImpactFlareTextureCache.prewarm()
	ImpactShockwaveTextureCache.prewarm()


func draw(
	canvas: CanvasItem,
	draw_center: Vector2,
	combo: int,
	progress: float,
	effect_timer_frames: float,
	base_color: Color,
	alpha: float
) -> void:
	_draw_rays(canvas, draw_center, combo, progress, effect_timer_frames, base_color, alpha)
	_draw_slashes(canvas, draw_center, combo, progress, alpha)
	_draw_rings(canvas, draw_center, combo, progress, base_color, alpha)
	_draw_rainbow_orbits(canvas, draw_center, combo, progress, alpha)


func _draw_rays(
	canvas: CanvasItem,
	draw_center: Vector2,
	combo: int,
	progress: float,
	effect_timer_frames: float,
	base_color: Color,
	alpha: float
) -> void:
	if combo < 3 or effect_timer_frames <= 40.0:
		return
	var ray_count: int = min(combo * 2, 8)
	for ray_idx in range(ray_count):
		var angle: float = (float(ray_idx) / float(ray_count)) * TAU + progress * 2.0
		var ray_length: float = 30.0 + float(combo) * 10.0 + sin(progress * 10.0 + float(ray_idx)) * 10.0
		var ray_end: Vector2 = draw_center + Vector2(cos(angle), sin(angle)) * ray_length
		var ray_lift: float = (0.18 + 0.15 * sin(progress * 16.0 + float(ray_idx) * 1.7)) * (50.0 / 255.0)
		var ray_color: Color = Color(
			min(1.0, base_color.r + ray_lift),
			min(1.0, base_color.g + ray_lift),
			min(1.0, base_color.b + ray_lift),
			0.65 * alpha
		)
		canvas.draw_line(draw_center, ray_end, ray_color, 2.0 + floor(float(combo) / 2.0))


func _draw_slashes(canvas: CanvasItem, draw_center: Vector2, combo: int, progress: float, alpha: float) -> void:
	if combo < 5:
		return
	var slash_count: int = min(3, combo - 2)
	for slash_idx in range(slash_count):
		var slash_angle: float = -0.55 + float(slash_idx) * 0.25
		var slash_len: float = 42.0 + float(combo) * 4.0
		var slash_center: Vector2 = draw_center + Vector2(
			-34.0 + float(slash_idx) * 17.0,
			-28.0 + sin(progress * 8.0 + float(slash_idx)) * 5.0
		)
		var slash_dir: Vector2 = Vector2(cos(slash_angle), sin(slash_angle))
		canvas.draw_line(
			slash_center - slash_dir * slash_len * 0.5,
			slash_center + slash_dir * slash_len * 0.5,
			Color(1.0, 1.0, 1.0, 0.30 * alpha),
			2.0
		)


func _draw_rings(
	canvas: CanvasItem,
	draw_center: Vector2,
	combo: int,
	progress: float,
	base_color: Color,
	alpha: float
) -> void:
	if combo < 4:
		return
	var ring_count: int = min(combo - 2, 3)
	for ring_idx in range(ring_count):
		var ring_progress: float = fmod(progress + float(ring_idx) * 0.10, 1.0)
		var ring_radius: float = 20.0 + ring_progress * 80.0
		var ring_alpha: float = max(0.0, 0.78 - ring_progress * 0.78) * alpha
		ImpactShockwaveTextureCache.draw_full_ring(canvas, draw_center, ring_radius, base_color, ring_alpha)


func _draw_rainbow_orbits(canvas: CanvasItem, draw_center: Vector2, combo: int, progress: float, alpha: float) -> void:
	if combo < 6:
		return
	var color_count: int = RAINBOW_COLORS.size()
	for rainbow_idx in range(color_count):
		var orbit_angle: float = progress * 5.0 + float(rainbow_idx) * TAU / float(color_count)
		var orbit_pos: Vector2 = draw_center + Vector2(
			cos(orbit_angle) * (50.0 + float(combo) * 5.0),
			sin(orbit_angle) * (30.0 + float(combo) * 3.0)
		)
		var rainbow_color: Color = RAINBOW_COLORS[rainbow_idx]
		ImpactFlareTextureCache.draw_sparkle(canvas, orbit_pos, 5.0 + floor(float(combo) / 2.0), rainbow_color, 0.78 * alpha)
