extends RefCounted

const MuhonVisualGeometry := preload("res://scripts/effects/muhon_visual_geometry.gd")


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


static func soul_flame_polygon_points(
	center: Vector2,
	radius: float,
	sway: float = 0.0
) -> PackedVector2Array:
	return MuhonVisualGeometry.flame_polygon_points(center, radius, sway)


static func soul_wisp_polyline_points(
	center: Vector2,
	radius: float,
	side: float,
	phase: float = 0.0
) -> PackedVector2Array:
	return MuhonVisualGeometry.smooth_open_polyline_points(
		MuhonVisualGeometry.wisp_polyline_points(center, radius, side, phase),
		4
	)


static func soul_flame_smooth_polygon_points(
	center: Vector2,
	radius: float,
	sway: float = 0.0
) -> PackedVector2Array:
	return MuhonVisualGeometry.smooth_flame_polygon_points(center, radius, sway, 3)


static func draw_soul_flame(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	sway: float,
	fill: Color,
	outline: Color,
	outline_width: float,
	inner_fill: Color,
	core_color: Color
) -> void:
	if canvas == null or radius <= 0.0 or fill.a <= 0.001:
		return
	var outer_points: PackedVector2Array = soul_flame_smooth_polygon_points(center, radius, sway)
	canvas.draw_colored_polygon(outer_points, fill)
	if outline.a > 0.001 and outline_width > 0.0:
		canvas.draw_polyline(closed_polyline_points(outer_points), outline, outline_width, true)
	var fold_color: Color = fill.darkened(0.58)
	fold_color.a = fill.a * 0.52
	for side in [-1.0, 1.0]:
		canvas.draw_polyline(
			MuhonVisualGeometry.smooth_open_polyline_points(
				MuhonVisualGeometry.flame_fold_polyline_points(center, radius, float(side), sway),
				3
			),
			fold_color,
			maxf(1.0, radius * 0.055),
			true
		)
	var middle_center: Vector2 = center + Vector2(radius * 0.015, radius * 0.10)
	var middle_points: PackedVector2Array = soul_flame_smooth_polygon_points(middle_center, radius * 0.72, sway * 0.46)
	canvas.draw_colored_polygon(middle_points, inner_fill)
	var inner_center: Vector2 = center + Vector2(-radius * 0.04, radius * 0.22)
	var inner_points: PackedVector2Array = soul_flame_smooth_polygon_points(inner_center, radius * 0.43, -sway * 0.72)
	canvas.draw_colored_polygon(inner_points, core_color)
	var glint_color := Color(1.0, 0.99, 0.90, core_color.a)
	canvas.draw_circle(center + Vector2(-radius * 0.03, radius * 0.30), maxf(1.25, radius * 0.085), glint_color)


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


static func draw_fitted_texture(canvas: CanvasItem, texture: Texture2D, rect: Rect2, alpha: float) -> void:
	if canvas == null or texture == null or alpha <= 0.001:
		return
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var scale_ratio: float = min(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
	var draw_size: Vector2 = texture_size * scale_ratio
	var icon_draw_rect := Rect2(rect.get_center() - draw_size * 0.5, draw_size)
	canvas.draw_texture_rect(texture, icon_draw_rect, false, Color(1.0, 1.0, 1.0, alpha))


static func draw_fallback_reward_icon(canvas: CanvasItem, visual_state: Dictionary) -> void:
	if canvas == null or visual_state.is_empty():
		return
	var center: Vector2 = visual_state.get("center", Vector2.ZERO)
	var radius: float = float(visual_state.get("radius", 0.0))
	if radius <= 0.0:
		return
	var fill: Color = visual_state.get("fill", Color.TRANSPARENT)
	if fill.a > 0.001:
		canvas.draw_circle(center, radius, fill)
	var ring_color: Color = visual_state.get("ring_color", Color.TRANSPARENT)
	var ring_width: float = float(visual_state.get("ring_width", 0.0))
	if ring_color.a > 0.001 and ring_width > 0.0:
		canvas.draw_arc(center, radius, 0.0, TAU, 28, ring_color, ring_width)


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


static func draw_box_hover_glow(
	canvas: CanvasItem,
	draw_center: Vector2,
	radius_x: float,
	radius_y: float,
	draw_scale: float,
	is_mythic: bool,
	global_alpha: float,
	pulse: float
) -> void:
	if canvas == null:
		return
	var base_color: Color = Color(1.0, 0.92, 0.50, 1.0) if is_mythic else Color(0.62, 0.92, 1.0, 1.0)
	for layer_value in box_hover_glow_layers(radius_x, radius_y, global_alpha, pulse):
		var layer: Dictionary = layer_value if layer_value is Dictionary else {}
		var layer_color: Color = base_color
		layer_color.a = float(layer.get("alpha", 0.0))
		draw_filled_ellipse(
			canvas,
			draw_center,
			float(layer.get("radius_x", 0.0)),
			float(layer.get("radius_y", 0.0)),
			layer_color
		)
	var ring: Dictionary = box_hover_glow_ring(radius_x, radius_y, draw_scale, global_alpha, pulse)
	var ring_color: Color = base_color
	ring_color.a = float(ring.get("alpha", 0.0))
	draw_ellipse_polyline(
		canvas,
		draw_center,
		float(ring.get("radius_x", 0.0)),
		float(ring.get("radius_y", 0.0)),
		ring_color,
		float(ring.get("width", max(1.5, 2.2 * draw_scale)))
	)


static func draw_box_hover_sparkles(
	canvas: CanvasItem,
	draw_center: Vector2,
	radius_x: float,
	radius_y: float,
	draw_scale: float,
	is_mythic: bool,
	global_alpha: float,
	phase: float,
	timer: float
) -> void:
	if canvas == null:
		return
	var base_color: Color = Color(1.0, 0.92, 0.50, 1.0) if is_mythic else Color(0.62, 0.92, 1.0, 1.0)
	for sparkle_value in box_hover_sparkles(draw_center, radius_x, radius_y, draw_scale, global_alpha, phase, timer):
		var sparkle: Dictionary = sparkle_value if sparkle_value is Dictionary else {}
		var sparkle_alpha: float = float(sparkle.get("alpha", 0.0))
		var sparkle_size: float = float(sparkle.get("size", 2.0))
		var sparkle_pos: Vector2 = sparkle.get("position", draw_center)
		var dot_color: Color = base_color
		dot_color.a = sparkle_alpha
		canvas.draw_circle(sparkle_pos, sparkle_size, dot_color)
		canvas.draw_circle(sparkle_pos, sparkle_size * 0.42, Color(1.0, 1.0, 1.0, sparkle_alpha * 0.85))
