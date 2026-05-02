extends RefCounted


static func as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


static func as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback
