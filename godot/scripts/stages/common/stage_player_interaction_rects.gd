extends RefCounted


static func get_player_rect_from_context(context: Dictionary, default_size: Vector2) -> Rect2:
	return Rect2(
		_get_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO),
		_get_vector2(context.get("player_paddle_size", default_size), default_size)
	)


static func get_player_interaction_rects_from_context(
	context: Dictionary,
	deps: Dictionary,
	default_size: Vector2
) -> Array[Rect2]:
	var base_rect := get_player_rect_from_context(context, default_size)
	if base_rect.size.x <= 0.0 or base_rect.size.y <= 0.0:
		return []
	return get_player_interaction_rects(base_rect, deps)


static func get_player_interaction_rects(base_rect: Rect2, deps: Dictionary) -> Array[Rect2]:
	var rects: Array[Rect2] = [base_rect]
	var warp_gate_state: Object = deps.get("smasher_warp_gate_state", null)
	if warp_gate_state == null or not warp_gate_state.has_method("get_mirror_offset_x"):
		return rects
	var mirror_offset_x: float = float(warp_gate_state.get_mirror_offset_x(base_rect.position, base_rect.size.x))
	if abs(mirror_offset_x) > 0.01:
		rects.append(Rect2(base_rect.position + Vector2(mirror_offset_x, 0.0), base_rect.size))
	return rects


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
