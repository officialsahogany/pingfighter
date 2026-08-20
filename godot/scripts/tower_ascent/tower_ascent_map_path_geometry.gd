extends RefCounted


static func build(
	edges_value: Variant,
	map_seed: int,
	art_size: float,
	curve_min_ratio: float,
	curve_max_ratio: float,
	curve_skew_ratio: float,
	endpoint_clearance_ratio: float,
	minimum_samples: int,
	maximum_samples: int
) -> Array[Dictionary]:
	var edges: Array = edges_value if edges_value is Array else []
	var result: Array[Dictionary] = []
	for edge_variant in edges:
		if not (edge_variant is Dictionary):
			continue
		var edge := edge_variant as Dictionary
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		var from_position: Vector2 = edge.get("from_position", Vector2.ZERO)
		var to_position: Vector2 = edge.get("to_position", Vector2.ZERO)
		var delta := to_position - from_position
		var distance := delta.length()
		if from_id.is_empty() or to_id.is_empty() or distance <= 0.001:
			continue
		var direction := delta / distance
		var normal := Vector2(-direction.y, direction.x)
		var seed_key := "%d:%s:%s" % [map_seed, from_id, to_id]
		var curvature_unit := _stable_unit(seed_key + ":curve")
		var direction_sign := -1.0 if _stable_unit(seed_key + ":side") < 0.5 else 1.0
		var skew_unit := _stable_unit(seed_key + ":skew") * 2.0 - 1.0
		var curvature_ratio := lerpf(curve_min_ratio, curve_max_ratio, curvature_unit)
		var clearance := minf(art_size * endpoint_clearance_ratio, distance * 0.22)
		var path_start := from_position + direction * clearance
		var path_end := to_position - direction * clearance
		var control := (path_start + path_end) * 0.5
		control += normal * distance * curvature_ratio * direction_sign
		control += direction * distance * curve_skew_ratio * skew_unit
		var sample_count := clampi(
			int(ceil(distance / maxf(8.0, art_size * 0.16))),
			minimum_samples,
			maximum_samples
		)
		var points := PackedVector2Array()
		for sample_index in range(sample_count + 1):
			var progress := float(sample_index) / float(sample_count)
			points.append(_quadratic_bezier(path_start, control, path_end, progress))
		var projected := edge.duplicate(true)
		projected["path_start"] = path_start
		projected["path_end"] = path_end
		projected["control_position"] = control
		projected["path_points"] = points
		projected["curve_signature"] = _signature(points)
		var travel_points := PackedVector2Array([from_position])
		travel_points.append_array(points)
		travel_points.append(to_position)
		var travel_segment_lengths := PackedFloat32Array()
		var travel_distance := 0.0
		for travel_index in range(1, travel_points.size()):
			var segment_length := travel_points[travel_index - 1].distance_to(
				travel_points[travel_index]
			)
			travel_segment_lengths.append(segment_length)
			travel_distance += segment_length
		projected["travel_points"] = travel_points
		projected["travel_segment_lengths"] = travel_segment_lengths
		projected["travel_distance"] = travel_distance
		result.append(projected)
	return result


static func connection_signature(edges_value: Variant) -> PackedStringArray:
	var edges: Array = edges_value if edges_value is Array else []
	var result := PackedStringArray()
	for edge_variant in edges:
		if edge_variant is Dictionary:
			var edge := edge_variant as Dictionary
			result.append("%s>%s" % [str(edge.get("from", "")), str(edge.get("to", ""))])
	return result


static func attach_dots(
	edges_value: Variant,
	dot_gap: float,
	outer_radius: float,
	inner_radius: float,
	circle_segments: int
) -> Array[Dictionary]:
	var edges: Array = edges_value if edges_value is Array else []
	var result: Array[Dictionary] = []
	for edge_variant in edges:
		if not (edge_variant is Dictionary):
			continue
		var edge := (edge_variant as Dictionary).duplicate(true)
		var path_points: PackedVector2Array = edge.get("path_points", PackedVector2Array())
		var centers := _sample_equidistant_centers(path_points, maxf(1.0, dot_gap))
		var dots: Array[Dictionary] = []
		for center in centers:
			dots.append({
				"center": center,
				"outer_polygon": _circle_polygon(center, outer_radius, circle_segments),
				"inner_polygon": _circle_polygon(center, inner_radius, circle_segments),
			})
		edge["dots"] = dots
		edge["dot_count"] = dots.size()
		result.append(edge)
	return result


static func dot_count(edges_value: Variant) -> int:
	var edges: Array = edges_value if edges_value is Array else []
	var result := 0
	for edge_variant in edges:
		if edge_variant is Dictionary:
			result += int((edge_variant as Dictionary).get("dot_count", 0))
	return result


static func sample_travel_position(edge: Dictionary, progress: float) -> Vector2:
	var points: PackedVector2Array = edge.get("travel_points", PackedVector2Array())
	var segment_lengths: PackedFloat32Array = edge.get(
		"travel_segment_lengths",
		PackedFloat32Array()
	)
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1 or segment_lengths.is_empty():
		return points[0]
	var total_distance := float(edge.get("travel_distance", 0.0))
	var target_distance := clampf(progress, 0.0, 1.0) * total_distance
	var consumed := 0.0
	for segment_index in range(segment_lengths.size()):
		var segment_length := float(segment_lengths[segment_index])
		if target_distance <= consumed + segment_length or segment_index == segment_lengths.size() - 1:
			var local_progress := (
				0.0
				if segment_length <= 0.001
				else clampf((target_distance - consumed) / segment_length, 0.0, 1.0)
			)
			return points[segment_index].lerp(points[segment_index + 1], local_progress)
		consumed += segment_length
	return points[points.size() - 1]


static func curve_signature(edges_value: Variant) -> String:
	var edges: Array = edges_value if edges_value is Array else []
	var parts := PackedStringArray()
	for edge_variant in edges:
		if edge_variant is Dictionary:
			parts.append(str((edge_variant as Dictionary).get("curve_signature", "")))
	return "|".join(parts)


static func _sample_equidistant_centers(
	points: PackedVector2Array,
	gap: float
) -> PackedVector2Array:
	var result := PackedVector2Array()
	if points.size() < 2:
		return result
	var distance_until_dot := gap * 0.5
	for point_index in range(1, points.size()):
		var segment_start := points[point_index - 1]
		var segment_end := points[point_index]
		var segment_delta := segment_end - segment_start
		var segment_length := segment_delta.length()
		if segment_length <= 0.001:
			continue
		var direction := segment_delta / segment_length
		var consumed := 0.0
		while consumed + distance_until_dot <= segment_length + 0.001:
			consumed += distance_until_dot
			result.append(segment_start + direction * consumed)
			distance_until_dot = gap
		distance_until_dot -= segment_length - consumed
	return result


static func _circle_polygon(
	center: Vector2,
	radius: float,
	segment_count: int
) -> PackedVector2Array:
	var result := PackedVector2Array()
	var safe_segment_count := maxi(6, segment_count)
	for segment_index in range(safe_segment_count):
		var angle := TAU * float(segment_index) / float(safe_segment_count)
		result.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return result


static func _quadratic_bezier(
	start: Vector2,
	control: Vector2,
	finish: Vector2,
	progress: float
) -> Vector2:
	var inverse := 1.0 - progress
	return inverse * inverse * start + 2.0 * inverse * progress * control + progress * progress * finish


static func _signature(points: PackedVector2Array) -> String:
	var parts := PackedStringArray()
	for point in points:
		parts.append("%0.2f,%0.2f" % [point.x, point.y])
	return ";".join(parts)


static func _stable_unit(value: String) -> float:
	# A local presentation hash keeps curve layout deterministic without touching
	# either the map generator RNG or the authoritative gameplay RNG stream.
	var hash_value := 2166136261
	for byte_value in value.to_utf8_buffer():
		hash_value = int((hash_value ^ int(byte_value)) * 16777619) & 0x7fffffff
	return float(hash_value) / float(0x7fffffff)
