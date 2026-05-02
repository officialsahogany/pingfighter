extends RefCounted


static func get_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return value


static func get_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = get_value(owner, key, fallback)
	if value is Vector2:
		return value
	return fallback


static func get_dictionary(owner: Object, key: String) -> Dictionary:
	var value: Variant = get_value(owner, key, {})
	if value is Dictionary:
		return value
	return {}


static func get_array(owner: Object, key: String) -> Array:
	var value: Variant = get_value(owner, key, [])
	if value is Array:
		return value
	return []
