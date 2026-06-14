extends RefCounted


static func overlaps_any_rect_player(drop: Dictionary, player_rects: Array[Rect2], default_size: float) -> bool:
	var pos: Vector2 = _get_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO)
	var size: float = max(1.0, float(drop.get("size", default_size)))
	var star_rect := Rect2(pos - Vector2(size, size), Vector2(size * 2.0, size * 2.0))
	for rect in player_rects:
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if rect.intersects(star_rect, true):
			return true
	return false


static func overlaps_any_circle_player(drop: Dictionary, player_rects: Array[Rect2], default_size: float) -> bool:
	var pos: Vector2 = _get_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO)
	var radius: float = get_collect_radius(drop, default_size)
	for rect in player_rects:
		if circle_rect_overlap(pos, radius, rect):
			return true
	return false


static func get_collect_radius(drop: Dictionary, default_size: float) -> float:
	var size: float = max(1.0, float(drop.get("size", default_size)))
	return size * 1.18


static func circle_rect_overlap(pos: Vector2, radius: float, rect: Rect2) -> bool:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	var nearest := Vector2(
		clamp(pos.x, rect.position.x, rect.position.x + rect.size.x),
		clamp(pos.y, rect.position.y, rect.position.y + rect.size.y)
	)
	return pos.distance_to(nearest) <= radius


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
