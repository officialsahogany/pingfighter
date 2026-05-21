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
