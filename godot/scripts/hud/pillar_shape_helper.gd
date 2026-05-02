extends RefCounted


func build_ellipse_points(rect: Rect2, segments: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	var center := rect.get_center()
	var radius_x: float = rect.size.x * 0.5
	var radius_y: float = rect.size.y * 0.5
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


func build_sector_points(
	center: Vector2,
	outer_radius: float,
	start_rad: float,
	end_rad: float,
	segments: int = 32,
	inner_radius: float = 0.0
) -> PackedVector2Array:
	var points := PackedVector2Array()
	if inner_radius <= 0.0:
		points.append(center)
	for i in range(segments + 1):
		var ratio: float = float(i) / float(max(1, segments))
		var angle: float = start_rad + (end_rad - start_rad) * ratio
		points.append(center + Vector2(cos(angle), sin(angle)) * outer_radius)
	if inner_radius > 0.0:
		for i in range(segments, -1, -1):
			var ratio: float = float(i) / float(max(1, segments))
			var angle: float = start_rad + (end_rad - start_rad) * ratio
			points.append(center + Vector2(cos(angle), sin(angle)) * inner_radius)
	return points


func draw_soft_shadow_ellipse(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	if canvas == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	var outer_rect := rect.grow_individual(10.0, 4.0, 10.0, 4.0)
	var mid_rect := rect.grow_individual(5.0, 2.0, 5.0, 2.0)
	canvas.draw_colored_polygon(
		build_ellipse_points(outer_rect, 28),
		Color(color.r, color.g, color.b, color.a * 0.22)
	)
	canvas.draw_colored_polygon(
		build_ellipse_points(mid_rect, 28),
		Color(color.r, color.g, color.b, color.a * 0.45)
	)
	canvas.draw_colored_polygon(build_ellipse_points(rect, 28), color)


func ease_out_cubic(t: float) -> float:
	var clamped_t: float = clamp(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped_t, 3.0)


func ease_in_out_sine(t: float) -> float:
	var clamped_t: float = clamp(t, 0.0, 1.0)
	return -(cos(PI * clamped_t) - 1.0) * 0.5
