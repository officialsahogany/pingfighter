extends RefCounted


static func get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


static func get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
