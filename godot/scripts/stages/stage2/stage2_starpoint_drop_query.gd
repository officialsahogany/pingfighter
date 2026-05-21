extends RefCounted


static func overlaps_any_player(
	drop: Dictionary,
	player_rects: Array[Rect2],
	collision_geometry: Object,
	default_size: float
) -> bool:
	if collision_geometry == null or not collision_geometry.has_method("circle_rect_overlap"):
		return false
	var pos: Vector2 = _get_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO)
	var radius: float = get_collect_radius(drop, default_size)
	for rect in player_rects:
		if collision_geometry.circle_rect_overlap(pos, radius, rect):
			return true
	return false


static func get_collect_radius(drop: Dictionary, default_size: float) -> float:
	var size: float = max(1.0, float(drop.get("size", default_size)))
	return size * 1.18


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
