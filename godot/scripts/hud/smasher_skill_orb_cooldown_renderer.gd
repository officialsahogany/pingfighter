extends RefCounted


func draw(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	cooldown_ratio: float,
	pillar_drawer
) -> void:
	var clamped_ratio: float = clamp(cooldown_ratio, 0.0, 1.0)
	canvas.draw_circle(center, radius, Color(0.0, 0.0, 0.0, 0.45))
	if clamped_ratio > 0.0:
		var points: PackedVector2Array
		if pillar_drawer != null and pillar_drawer.has_method("build_sector_points"):
			points = pillar_drawer.build_sector_points(center, radius, -PI * 0.5, -PI * 0.5 + TAU * clamped_ratio, 32)
		else:
			points = _build_sector_points(center, radius, -PI * 0.5, -PI * 0.5 + TAU * clamped_ratio, 32)
		canvas.draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.42))
	canvas.draw_arc(
		center,
		radius + 1.0,
		-PI * 0.5,
		-PI * 0.5 + TAU * (1.0 - clamped_ratio),
		28,
		Color(0.65, 0.88, 1.0, 0.78),
		2.0
	)


func _build_sector_points(
	center: Vector2,
	outer_radius: float,
	start_rad: float,
	end_rad: float,
	segments: int = 32
) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(center)
	for i in range(segments + 1):
		var ratio: float = float(i) / float(max(1, segments))
		var angle: float = start_rad + (end_rad - start_rad) * ratio
		points.append(center + Vector2(cos(angle), sin(angle)) * outer_radius)
	return points
