extends RefCounted


func draw(
	canvas: CanvasItem,
	pillar_drawer: Object,
	center: Vector2,
	radius: float,
	t: float,
	scale_factor: float,
	full_ratio: float,
	context: Dictionary = {}
) -> void:
	if canvas == null or pillar_drawer == null:
		return

	var palette: Dictionary = _get_fill_palette(full_ratio)
	var fill_top_color: Color = palette["top"]
	var fill_bottom_color: Color = palette["bottom"]
	var wave_glow: Color = palette["glow"]
	var inner_radius: float = radius - 5.0 * scale_factor
	if bool(context.get("pillar_hud_static_lod", false)):
		_draw_static_fill(canvas, center, inner_radius, full_ratio, fill_top_color, fill_bottom_color, wave_glow)
		_draw_static_fill_glow(canvas, center, radius, full_ratio, wave_glow)
		return

	pillar_drawer.draw_pillar_liquid_fill(
		canvas,
		center,
		inner_radius,
		full_ratio,
		t,
		fill_top_color,
		fill_bottom_color,
		wave_glow,
		float(context.get("hud_lod_scale", 1.0))
	)
	_draw_fill_glow(canvas, center, radius, full_ratio, wave_glow)


func _get_fill_palette(full_ratio: float) -> Dictionary:
	var fill_top_color: Color = Color(0.36, 0.70, 1.0, 1.0)
	var fill_bottom_color: Color = Color(0.10, 0.26, 0.72, 1.0)
	var wave_glow: Color = Color(0.82, 0.94, 1.0, 1.0)
	if full_ratio >= 0.999:
		fill_top_color = Color(1.0, 0.92, 0.62, 1.0)
		fill_bottom_color = Color(0.70, 0.52, 0.16, 1.0)
		wave_glow = Color(1.0, 0.95, 0.82, 1.0)
	elif full_ratio >= 0.75:
		fill_top_color = Color(0.58, 0.86, 1.0, 1.0)
		fill_bottom_color = Color(0.18, 0.46, 0.88, 1.0)
	elif full_ratio < 0.35:
		fill_top_color = Color(0.22, 0.46, 0.92, 1.0)
		fill_bottom_color = Color(0.07, 0.17, 0.48, 1.0)
	return {
		"top": fill_top_color,
		"bottom": fill_bottom_color,
		"glow": wave_glow,
	}


func _draw_fill_glow(canvas: CanvasItem, center: Vector2, radius: float, full_ratio: float, wave_glow: Color) -> void:
	if full_ratio <= 0.0:
		return
	canvas.draw_circle(center, radius * (0.20 + full_ratio * 0.24), Color(wave_glow.r, wave_glow.g, wave_glow.b, 0.12 + full_ratio * 0.16))
	canvas.draw_circle(center + Vector2(0.0, radius * 0.10), radius * (0.10 + full_ratio * 0.12), Color(1.0, 1.0, 1.0, 0.06 + full_ratio * 0.07))


func _draw_static_fill_glow(canvas: CanvasItem, center: Vector2, radius: float, full_ratio: float, wave_glow: Color) -> void:
	if full_ratio <= 0.0:
		return
	canvas.draw_circle(center, radius * (0.18 + full_ratio * 0.20), Color(wave_glow.r, wave_glow.g, wave_glow.b, 0.10 + full_ratio * 0.10))


func _draw_static_fill(
	canvas: CanvasItem,
	center: Vector2,
	inner_radius: float,
	full_ratio: float,
	fill_top_color: Color,
	fill_bottom_color: Color,
	wave_glow: Color
) -> void:
	var clamped_ratio: float = clamp(full_ratio, 0.0, 1.0)
	if clamped_ratio <= 0.0:
		return
	var radius: float = max(4.0, inner_radius)
	var fill_height: float = radius * 2.0 * clamped_ratio
	var fill_top: float = center.y + radius - fill_height
	var sample_count := 12
	var top_points := PackedVector2Array()
	var top_colors := PackedColorArray()
	var bottom_points := PackedVector2Array()
	var bottom_colors := PackedColorArray()
	for sample_idx in range(sample_count):
		var sample_t: float = float(sample_idx) / max(1.0, float(sample_count - 1))
		var local_x: float = lerpf(-radius, radius, sample_t)
		var y_limit: float = sqrt(max(0.0, radius * radius - local_x * local_x))
		var line_top: float = clamp(fill_top, center.y - y_limit, center.y + y_limit)
		var line_bottom: float = center.y + y_limit
		if line_top >= line_bottom:
			continue
		var gradient_t: float = clamp((line_top - (center.y - radius)) / max(1.0, radius * 2.0), 0.0, 1.0)
		top_points.append(Vector2(center.x + local_x, line_top))
		top_colors.append(fill_top_color.lerp(fill_bottom_color, gradient_t))
		bottom_points.append(Vector2(center.x + local_x, line_bottom))
		bottom_colors.append(fill_bottom_color)
	if top_points.size() < 2:
		return

	var fill_points := PackedVector2Array()
	var fill_colors := PackedColorArray()
	for idx in range(top_points.size()):
		fill_points.append(top_points[idx])
		fill_colors.append(top_colors[idx])
	for idx in range(bottom_points.size() - 1, -1, -1):
		fill_points.append(bottom_points[idx])
		fill_colors.append(bottom_colors[idx])
	canvas.draw_polygon(fill_points, fill_colors)
	canvas.draw_polyline(top_points, Color(wave_glow.r, wave_glow.g, wave_glow.b, 0.38), 1.4, true)
