extends RefCounted


static func as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


static func copy_dict(value: Variant) -> Dictionary:
	return as_dict(value).duplicate(true)


static func as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func copy_array(value: Variant) -> Array:
	return as_array(value).duplicate(true)


static func as_vector2(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2:
		return value
	return fallback


static func as_finite_vector2(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2 and is_finite(value.x) and is_finite(value.y):
		return value
	return fallback


static func as_color(value: Variant, fallback: Color = Color.WHITE) -> Color:
	if value is Color:
		return value
	return fallback


static func as_rect2(value: Variant, fallback: Rect2 = Rect2()) -> Rect2:
	if value is Rect2:
		return value
	return fallback


static func get_value(source: Object, key: String, fallback: Variant = null) -> Variant:
	if source == null:
		return fallback
	var value: Variant = source.get(key)
	if value == null:
		return fallback
	return value


static func get_float(source: Object, key: String, fallback: float = 0.0) -> float:
	return float(get_value(source, key, fallback))


static func get_string(source: Object, key: String, fallback: String = "") -> String:
	var value: Variant = get_value(source, key, null)
	if value == null:
		return fallback
	return str(value)
