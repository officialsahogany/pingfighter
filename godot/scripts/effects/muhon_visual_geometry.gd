extends RefCounted

# Player-facing geometry for the compatibility-owned `starpoint` reward.
# The runtime ID stays stable, while every renderer uses this upright split-tip
# soul-flame silhouette for the 무혼 presentation.


static func flame_polygon_points(
	center: Vector2,
	radius: float,
	sway: float = 0.0
) -> PackedVector2Array:
	if radius <= 0.0:
		return PackedVector2Array()
	var clamped_sway: float = clampf(sway, -0.22, 0.22)
	var profile: Array[Vector2] = [
		Vector2(clamped_sway, -1.15),
		Vector2(0.13 + clamped_sway * 0.58, -0.52),
		Vector2(0.48 - clamped_sway * 0.18, -0.84),
		Vector2(0.43, -0.28),
		Vector2(0.70, 0.10),
		Vector2(0.61, 0.49),
		Vector2(0.34, 0.78),
		Vector2(0.0, 0.92),
		Vector2(-0.34, 0.78),
		Vector2(-0.61, 0.49),
		Vector2(-0.70, 0.10),
		Vector2(-0.48, -0.29),
		Vector2(-0.34 + clamped_sway * 0.20, -0.63),
		Vector2(-0.12 + clamped_sway * 0.62, -0.42),
	]
	var points := PackedVector2Array()
	for point in profile:
		points.append(center + point * radius)
	return points


static func closed_polyline_points(points: PackedVector2Array) -> PackedVector2Array:
	if points.is_empty():
		return PackedVector2Array()
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	return closed


# Short asymmetric creases give the outer flame depth without adding another
# silhouette implementation. Both the CPU fallback and the result reward use
# these same points, so the pickup/absorption/result identity stays locked.
static func flame_fold_polyline_points(
	center: Vector2,
	radius: float,
	side: float,
	sway: float = 0.0
) -> PackedVector2Array:
	if radius <= 0.0:
		return PackedVector2Array()
	var safe_side: float = -1.0 if side < 0.0 else 1.0
	var clamped_sway: float = clampf(sway, -0.22, 0.22)
	return PackedVector2Array([
		center + Vector2(safe_side * 0.55, 0.38) * radius,
		center + Vector2(safe_side * 0.44, 0.12) * radius,
		center + Vector2(safe_side * (0.31 - clamped_sway * safe_side * 0.12), -0.16) * radius,
		center + Vector2(safe_side * (0.38 - clamped_sway * safe_side * 0.20), -0.43) * radius,
	])


# A bowed four-segment ribbon reads as dissipating soul energy rather than the
# straight rays used by the retired star presentation.
static func wisp_polyline_points(
	center: Vector2,
	radius: float,
	side: float,
	phase: float = 0.0
) -> PackedVector2Array:
	if radius <= 0.0:
		return PackedVector2Array()
	var safe_side: float = -1.0 if side < 0.0 else 1.0
	var bob: float = sin(phase + safe_side * 1.4) * 0.10
	return PackedVector2Array([
		center + Vector2(safe_side * 0.62, 0.42 + bob) * radius,
		center + Vector2(safe_side * 0.96, 0.16 - bob * 0.45) * radius,
		center + Vector2(safe_side * 0.78, -0.24 + bob * 0.35) * radius,
		center + Vector2(safe_side * 1.08, -0.66 - bob * 0.20) * radius,
	])


static func smooth_flame_polygon_points(
	center: Vector2,
	radius: float,
	sway: float = 0.0,
	subdivisions: int = 3
) -> PackedVector2Array:
	return smooth_closed_polygon_points(
		flame_polygon_points(center, radius, sway),
		subdivisions
	)


static func smooth_closed_polygon_points(
	anchors: PackedVector2Array,
	subdivisions: int = 3
) -> PackedVector2Array:
	if anchors.size() < 3:
		return anchors.duplicate()
	var steps: int = max(1, subdivisions)
	var result := PackedVector2Array()
	var count: int = anchors.size()
	for index in range(count):
		var p0: Vector2 = anchors[(index - 1 + count) % count]
		var p1: Vector2 = anchors[index]
		var p2: Vector2 = anchors[(index + 1) % count]
		var p3: Vector2 = anchors[(index + 2) % count]
		for step in range(steps):
			result.append(_hermite_point(p0, p1, p2, p3, float(step) / float(steps)))
	return result


static func smooth_open_polyline_points(
	anchors: PackedVector2Array,
	subdivisions: int = 4
) -> PackedVector2Array:
	if anchors.size() < 2:
		return anchors.duplicate()
	var steps: int = max(1, subdivisions)
	var result := PackedVector2Array()
	for index in range(anchors.size() - 1):
		var p0: Vector2 = anchors[max(0, index - 1)]
		var p1: Vector2 = anchors[index]
		var p2: Vector2 = anchors[index + 1]
		var p3: Vector2 = anchors[min(anchors.size() - 1, index + 2)]
		for step in range(steps):
			result.append(_hermite_point(p0, p1, p2, p3, float(step) / float(steps)))
	result.append(anchors[anchors.size() - 1])
	return result


static func _hermite_point(
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	p3: Vector2,
	t: float
) -> Vector2:
	var t2: float = t * t
	var t3: float = t2 * t
	var tangent_in: Vector2 = (p2 - p0) * 0.36
	var tangent_out: Vector2 = (p3 - p1) * 0.36
	return (
		p1 * (2.0 * t3 - 3.0 * t2 + 1.0)
		+ tangent_in * (t3 - 2.0 * t2 + t)
		+ p2 * (-2.0 * t3 + 3.0 * t2)
		+ tangent_out * (t3 - t2)
	)
