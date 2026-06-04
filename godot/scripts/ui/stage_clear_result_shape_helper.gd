extends RefCounted


static func ellipse_polygon_points(center: Vector2, radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
	if radius_x <= 0.0 or radius_y <= 0.0:
		return PackedVector2Array()
	var safe_segments: int = max(3, segments)
	var points := PackedVector2Array()
	for i in range(safe_segments):
		var angle: float = (float(i) / float(safe_segments)) * TAU
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


static func ellipse_polyline_points(center: Vector2, radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
	if radius_x <= 0.0 or radius_y <= 0.0:
		return PackedVector2Array()
	var safe_segments: int = max(3, segments)
	var points := PackedVector2Array()
	for i in range(safe_segments + 1):
		var angle: float = (float(i) / float(safe_segments)) * TAU
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


static func radial_polygon_points(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	if radius <= 0.0:
		return PackedVector2Array()
	var safe_segments: int = max(3, segments)
	var points := PackedVector2Array()
	for i in range(safe_segments):
		var angle: float = (float(i) / float(safe_segments)) * TAU
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func star_polygon_points(
	center: Vector2,
	outer_radius: float,
	inner_radius: float,
	x_scale: float,
	num_points: int = 5
) -> PackedVector2Array:
	var safe_points: int = max(2, num_points)
	var safe_x_scale: float = max(0.04, x_scale)
	var points := PackedVector2Array()
	for i in range(safe_points * 2):
		var angle: float = -PI * 0.5 + float(i) * PI / float(safe_points)
		var radius: float = outer_radius if i % 2 == 0 else inner_radius
		points.append(center + Vector2(cos(angle) * radius * safe_x_scale, sin(angle) * radius))
	return points


static func closed_polyline_points(points: PackedVector2Array) -> PackedVector2Array:
	if points.is_empty():
		return PackedVector2Array()
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	return closed


static func draw_filled_ellipse(
	canvas: CanvasItem,
	center: Vector2,
	radius_x: float,
	radius_y: float,
	color: Color,
	segments: int = 40
) -> void:
	if canvas == null or radius_x <= 0.0 or radius_y <= 0.0 or color.a <= 0.001:
		return
	var pts: PackedVector2Array = ellipse_polygon_points(center, radius_x, radius_y, segments)
	if pts.is_empty():
		return
	canvas.draw_colored_polygon(pts, color)


static func draw_ellipse_polyline(
	canvas: CanvasItem,
	center: Vector2,
	radius_x: float,
	radius_y: float,
	color: Color,
	width: float,
	segments: int = 56
) -> void:
	if canvas == null or radius_x <= 0.0 or radius_y <= 0.0 or color.a <= 0.001 or width <= 0.0:
		return
	var pts: PackedVector2Array = ellipse_polyline_points(center, radius_x, radius_y, segments)
	if pts.is_empty():
		return
	canvas.draw_polyline(pts, color, width, true)


static func draw_star_polygon(
	canvas: CanvasItem,
	center: Vector2,
	outer_radius: float,
	inner_radius: float,
	x_scale: float,
	fill: Color,
	outline: Color,
	outline_width: float
) -> void:
	if canvas == null or fill.a <= 0.001:
		return
	var pts: PackedVector2Array = star_polygon_points(center, outer_radius, inner_radius, x_scale)
	if pts.is_empty():
		return
	canvas.draw_colored_polygon(pts, fill)
	if outline.a > 0.001 and outline_width > 0.0:
		canvas.draw_polyline(closed_polyline_points(pts), outline, outline_width, true)


static func draw_radial_burst(canvas: CanvasItem, center: Vector2, radius: float, color: Color, segments: int = 28) -> void:
	if canvas == null or radius <= 0.0 or color.a <= 0.001:
		return
	var outer_color: Color = color
	outer_color.a = color.a * 0.55
	var outer_pts: PackedVector2Array = radial_polygon_points(center, radius, segments)
	if not outer_pts.is_empty():
		canvas.draw_colored_polygon(outer_pts, outer_color)
	var inner_color: Color = color
	inner_color.a = color.a * 0.92
	var inner_pts: PackedVector2Array = radial_polygon_points(center, radius * 0.55, segments)
	if not inner_pts.is_empty():
		canvas.draw_colored_polygon(inner_pts, inner_color)


static func draw_panel(
	canvas: CanvasItem,
	rect: Rect2,
	fill_color: Color,
	border_color: Color,
	border_width: float,
	corner_radius: float
) -> void:
	if canvas == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	var width: int = max(0, int(round(border_width)))
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.border_color = border_color
	var radius: int = max(0, int(round(corner_radius)))
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	canvas.draw_style_box(style, rect)


static func box_hover_glow_layers(radius_x: float, radius_y: float, global_alpha: float, pulse: float, layer_count: int = 4) -> Array:
	var layers: Array = []
	var safe_layer_count: int = max(1, layer_count)
	for i in range(safe_layer_count):
		var t: float = 0.0 if safe_layer_count <= 1 else float(i) / float(safe_layer_count - 1)
		var layer_alpha: float = lerpf(0.055, 0.18, t) * global_alpha
		layer_alpha *= 0.85 + pulse * 0.30
		layers.append({
			"radius_x": radius_x * lerpf(1.95, 1.18, t),
			"radius_y": radius_y * lerpf(1.80, 1.08, t),
			"alpha": clampf(layer_alpha, 0.0, 0.22),
		})
	return layers


static func box_hover_glow_ring(radius_x: float, radius_y: float, draw_scale: float, global_alpha: float, pulse: float) -> Dictionary:
	return {
		"radius_x": radius_x * 1.28,
		"radius_y": radius_y * 1.14,
		"alpha": clampf((0.24 + pulse * 0.12) * global_alpha, 0.0, 0.42),
		"width": max(1.5, 2.2 * draw_scale),
	}


static func box_hover_sparkles(
	draw_center: Vector2,
	radius_x: float,
	radius_y: float,
	draw_scale: float,
	global_alpha: float,
	phase: float,
	timer: float,
	sparkle_count: int = 6
) -> Array:
	var sparkles: Array = []
	var safe_count: int = max(0, sparkle_count)
	var orbit_x: float = radius_x * 1.18
	var orbit_y: float = radius_y * 0.86
	for i in range(safe_count):
		var t: float = float(i) / float(safe_count)
		var orbit_angle: float = t * TAU + timer * 0.85 + phase
		var local_phase: float = timer * 3.0 + t * TAU
		var sparkle_alpha: float = (sin(local_phase) * 0.5 + 0.5) * global_alpha * 0.85
		if sparkle_alpha <= 0.04:
			continue
		sparkles.append({
			"position": draw_center + Vector2(cos(orbit_angle) * orbit_x, sin(orbit_angle) * orbit_y),
			"size": max(2.0, (3.6 + sin(local_phase * 1.3) * 1.2) * draw_scale),
			"alpha": sparkle_alpha,
		})
	return sparkles
