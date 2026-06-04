extends RefCounted


static func union_rects(rects: Array) -> Rect2:
	if rects.is_empty():
		return Rect2()
	var first: Rect2 = as_rect2(rects[0], Rect2())
	var min_x: float = first.position.x
	var min_y: float = first.position.y
	var max_x: float = first.end.x
	var max_y: float = first.end.y
	for i in range(1, rects.size()):
		var rect: Rect2 = as_rect2(rects[i], Rect2())
		min_x = min(min_x, rect.position.x)
		min_y = min(min_y, rect.position.y)
		max_x = max(max_x, rect.end.x)
		max_y = max(max_y, rect.end.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


static func get_array(value: Variant) -> Array:
	if value is Array:
		return value as Array
	return []


static func as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value as Color
	return fallback


static func as_rect2(value: Variant, fallback: Rect2) -> Rect2:
	if value is Rect2:
		return value as Rect2
	return fallback


static func as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value as Vector2
	return fallback
