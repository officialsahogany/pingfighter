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


static func corner_brace_segments(
	top_left: Vector2,
	top_right: Vector2,
	bottom_right: Vector2,
	bottom_left: Vector2,
	draw_scale: float
) -> Array:
	var brace_len: float = max(8.0, 14.0 * draw_scale)
	var corners: Array = [
		{"corner": top_left, "neighbors": [top_right, bottom_left]},
		{"corner": top_right, "neighbors": [top_left, bottom_right]},
		{"corner": bottom_right, "neighbors": [top_right, bottom_left]},
		{"corner": bottom_left, "neighbors": [top_left, bottom_right]},
	]
	var segments: Array = []
	for entry_value in corners:
		var entry: Dictionary = entry_value
		var corner: Vector2 = entry["corner"]
		var neighbors_value: Variant = entry["neighbors"]
		if not (neighbors_value is Array):
			continue
		var neighbors: Array = neighbors_value
		for neighbor_value in neighbors:
			if not (neighbor_value is Vector2):
				continue
			var neighbor: Vector2 = neighbor_value
			var direction: Vector2 = neighbor - corner
			if direction.length_squared() <= 0.001:
				continue
			segments.append({
				"start": corner,
				"end": corner + direction.normalized() * brace_len,
			})
	return segments


static func get_box_lock_size(draw_scale: float, box_hy: float) -> float:
	if box_hy > 0.0:
		return max(6.0 * draw_scale, box_hy * 0.30)
	return 22.0 * draw_scale


static func get_box_lock_center(draw_center: Vector2, lock_offset_y: float, box_rotation: float) -> Vector2:
	return rotated_local_point(draw_center, Vector2(0.0, lock_offset_y), box_rotation)


static func get_box_lock_face_points(
	draw_center: Vector2,
	lock_offset_y: float,
	lock_size: float,
	box_rotation: float
) -> PackedVector2Array:
	return PackedVector2Array([
		rotated_local_point(draw_center, Vector2(0.0, lock_offset_y - lock_size), box_rotation),
		rotated_local_point(draw_center, Vector2(lock_size * 0.72, lock_offset_y), box_rotation),
		rotated_local_point(draw_center, Vector2(0.0, lock_offset_y + lock_size), box_rotation),
		rotated_local_point(draw_center, Vector2(-lock_size * 0.72, lock_offset_y), box_rotation),
	])


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


static func rotated_local_point(origin: Vector2, local_point: Vector2, angle: float) -> Vector2:
	var c: float = cos(angle)
	var s: float = sin(angle)
	return origin + Vector2(
		local_point.x * c - local_point.y * s,
		local_point.x * s + local_point.y * c
	)
