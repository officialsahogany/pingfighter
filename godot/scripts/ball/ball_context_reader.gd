extends RefCounted


static func get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return as_vector2(source.get(key, fallback), fallback)


static func as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
