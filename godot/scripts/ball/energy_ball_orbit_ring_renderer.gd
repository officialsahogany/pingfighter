extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")

const ORBIT_POINT_COUNT := 14
const ORBIT_MARKER_STRIDE := 4
const BRIGHT_POINT_COUNT := 2
const ORBIT_BRIGHTNESS := 0.70


func _init() -> void:
	ImpactFlareTextureCache.prewarm()


func draw_ring(
	canvas: CanvasItem,
	pos: Vector2,
	time_seconds: float,
	ball_ring_color: Color,
	ball_inner_color: Color,
	ring_rotation: float,
	ring_tilt: float,
	ring_radius: float,
	ring_idx: int,
	fx_lod_scale: float = 1.0,
	visual_alpha: float = 1.0
) -> void:
	var lod_scale: float = clamp(fx_lod_scale, 0.35, 1.0)
	var alpha_scale: float = clampf(visual_alpha, 0.0, 1.0)
	var point_count: int = ORBIT_POINT_COUNT if lod_scale >= 0.82 else max(8, int(round(float(ORBIT_POINT_COUNT) * lod_scale)))
	var marker_stride: int = ORBIT_MARKER_STRIDE if lod_scale >= 0.82 else ORBIT_MARKER_STRIDE + 1
	var orbit_points: PackedVector2Array = PackedVector2Array()
	for point_idx in range(point_count):
		var angle_deg: float = ring_rotation + float(point_idx) * (360.0 / float(point_count))
		var angle: float = deg_to_rad(angle_deg)
		var tilt_rad: float = deg_to_rad(ring_tilt)
		var x_offset: float = cos(angle) * ring_radius
		var y_offset: float = sin(angle) * ring_radius * cos(tilt_rad)
		var z_depth: float = sin(angle) * sin(tilt_rad)
		var depth_factor: float = (z_depth + 1.0) * 0.5
		var orbit_pos: Vector2 = pos + Vector2(x_offset, y_offset)
		var point_radius: float = max(1.0, floor(1.7 + depth_factor * 1.3))
		var ring_color: Color = _get_ring_point_color(ball_ring_color, depth_factor, ring_idx, alpha_scale)
		orbit_points.append(orbit_pos)
		if point_idx % marker_stride == ring_idx % marker_stride:
			ImpactFlareTextureCache.draw_sparkle(canvas, orbit_pos, point_radius, ring_color, ring_color.a * ORBIT_BRIGHTNESS)
	if orbit_points.size() > 0:
		orbit_points.append(orbit_points[0])

	_draw_ring_lines(canvas, orbit_points, ball_ring_color, alpha_scale)
	_draw_bright_points(canvas, pos, time_seconds, ball_inner_color, ring_rotation, ring_tilt, ring_radius, lod_scale, alpha_scale)


func _get_ring_point_color(
	ball_ring_color: Color, depth_factor: float, ring_idx: int, alpha_scale: float
) -> Color:
	return Color(
		clamp(ball_ring_color.r * 0.3 + depth_factor * ball_ring_color.r * 0.7 + float(ring_idx) * 0.02, 0.0, 1.0),
		clamp(ball_ring_color.g * 0.3 + depth_factor * ball_ring_color.g * 0.7 + float(ring_idx) * 0.04, 0.0, 1.0),
		clamp(ball_ring_color.b * 0.3 + depth_factor * ball_ring_color.b * 0.7, 0.0, 1.0),
		(15.0 + depth_factor * 35.0) / 255.0 * alpha_scale
	)


func _draw_ring_lines(
	canvas: CanvasItem,
	orbit_points: PackedVector2Array,
	ball_ring_color: Color,
	alpha_scale: float
) -> void:
	if orbit_points.size() <= 2:
		return
	canvas.draw_polyline(orbit_points, Color(ball_ring_color.r, ball_ring_color.g, ball_ring_color.b, (12.0 / 255.0) * ORBIT_BRIGHTNESS * alpha_scale), 1.0)


func _draw_bright_points(
	canvas: CanvasItem,
	pos: Vector2,
	time_seconds: float,
	ball_inner_color: Color,
	ring_rotation: float,
	ring_tilt: float,
	ring_radius: float,
	lod_scale: float,
	alpha_scale: float
) -> void:
	var bright_count: int = BRIGHT_POINT_COUNT if lod_scale >= 0.82 else 1
	for bright_idx in range(bright_count):
		var bright_angle_deg: float = ring_rotation + float(bright_idx) * 180.0
		var bright_angle: float = deg_to_rad(bright_angle_deg)
		var tilt_rad: float = deg_to_rad(ring_tilt)
		var x_offset: float = cos(bright_angle) * ring_radius
		var y_offset: float = sin(bright_angle) * ring_radius * cos(tilt_rad)
		var z_depth: float = sin(bright_angle) * sin(tilt_rad)
		if z_depth > -0.3:
			var bright_pos: Vector2 = pos + Vector2(x_offset, y_offset)
			var bright_pulse: float = (sin(time_seconds * 10.0 + float(bright_idx)) + 1.0) * 0.5
			var bright_size: float = 0.72 + bright_pulse * 0.85
			var bright_alpha: float = (40.0 + bright_pulse * 35.0) / 255.0
			ImpactFlareTextureCache.draw_glow(canvas, bright_pos, bright_size + 1.0, ball_inner_color, bright_alpha * 0.32 * ORBIT_BRIGHTNESS * lod_scale * alpha_scale)
			ImpactFlareTextureCache.draw_sparkle(canvas, bright_pos, bright_size, Color(220.0 / 255.0, 245.0 / 255.0, 1.0), bright_alpha * ORBIT_BRIGHTNESS * alpha_scale)
