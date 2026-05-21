extends RefCounted


func get_player_rect_from_context(context: Dictionary, default_size: Vector2) -> Rect2:
	return Rect2(
		_get_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO),
		_get_vector2(context.get("player_paddle_size", default_size), default_size)
	)


func get_player_interaction_rects_from_context(
	context: Dictionary,
	deps: Dictionary,
	default_size: Vector2
) -> Array[Rect2]:
	var base_rect := get_player_rect_from_context(context, default_size)
	if base_rect.size.x <= 0.0 or base_rect.size.y <= 0.0:
		return []
	return get_player_interaction_rects(base_rect, deps)


func get_player_interaction_rects(base_rect: Rect2, deps: Dictionary) -> Array[Rect2]:
	var rects: Array[Rect2] = [base_rect]
	var warp_gate_state: Object = deps.get("smasher_warp_gate_state", null)
	if warp_gate_state == null or not warp_gate_state.has_method("get_mirror_offset_x"):
		return rects
	var mirror_offset_x: float = float(warp_gate_state.get_mirror_offset_x(base_rect.position, base_rect.size.x))
	if abs(mirror_offset_x) > 0.01:
		rects.append(Rect2(base_rect.position + Vector2(mirror_offset_x, 0.0), base_rect.size))
	return rects


func get_first_overlapping_rect(pos: Vector2, radius: float, rects: Array[Rect2]) -> Rect2:
	for rect in rects:
		if circle_rect_overlap(pos, radius, rect):
			return rect
	return Rect2()


func circle_rect_overlap(pos: Vector2, radius: float, rect: Rect2) -> bool:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	var nearest := Vector2(
		clamp(pos.x, rect.position.x, rect.position.x + rect.size.x),
		clamp(pos.y, rect.position.y, rect.position.y + rect.size.y)
	)
	return pos.distance_to(nearest) <= radius


func segment_hits_circle(start: Vector2, finish: Vector2, center: Vector2, radius: float) -> bool:
	var segment: Vector2 = finish - start
	var length_sq: float = segment.length_squared()
	if length_sq <= 0.001:
		return start.distance_to(center) <= radius
	var t: float = clamp((center - start).dot(segment) / length_sq, 0.0, 1.0)
	var closest: Vector2 = start + segment * t
	return closest.distance_to(center) <= radius


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
