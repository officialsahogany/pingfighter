extends RefCounted


static func get_object(runtime_state: Object, key: String) -> Object:
	if runtime_state == null:
		return null
	var value: Variant = runtime_state.get(key)
	if value is Object:
		return value
	return null


static func get_dict(runtime_state: Object, key: String) -> Dictionary:
	if runtime_state == null:
		return {}
	var value: Variant = runtime_state.get(key)
	if value is Dictionary:
		return value
	return {}


static func get_array(runtime_state: Object, key: String) -> Array:
	if runtime_state == null:
		return []
	var value: Variant = runtime_state.get(key)
	if value is Array:
		return value
	return []


static func get_int(runtime_state: Object, key: String) -> int:
	if runtime_state == null:
		return 0
	return int(runtime_state.get(key))


static func get_float(runtime_state: Object, key: String, fallback: float = 0.0) -> float:
	if runtime_state == null:
		return fallback
	var value: Variant = runtime_state.get(key)
	if value == null:
		return fallback
	return float(value)


static func get_bool(runtime_state: Object, key: String) -> bool:
	if runtime_state == null:
		return false
	return bool(runtime_state.get(key))


static func get_string(runtime_state: Object, key: String) -> String:
	if runtime_state == null:
		return ""
	return str(runtime_state.get(key))


static func build_callable(runtime_state: Object, method: String, fallback: Callable = Callable()) -> Callable:
	if runtime_state != null and runtime_state.has_method(method):
		return Callable(runtime_state, method)
	return fallback


static func is_payload_active(runtime_state: Object, payload_key: String, helper_key: String = "") -> bool:
	if runtime_state == null:
		return false
	var payload: Dictionary = get_dict(runtime_state, payload_key)
	var helper: Object = get_object(runtime_state, helper_key) if helper_key != "" else null
	if helper != null and helper.has_method("is_active"):
		return bool(helper.is_active(payload))
	return bool(payload.get("active", false))


static func call_dict(source: Object, method: String, args: Array = [], duplicate_result: bool = true) -> Dictionary:
	if source == null or not source.has_method(method):
		return {}
	var value: Variant = source.callv(method, args)
	if value is Dictionary:
		var result: Dictionary = value
		return result.duplicate(true) if duplicate_result else result
	return {}


static func call_object(source: Object, method: String, args: Array = [], fallback: Object = null) -> Object:
	if source == null or not source.has_method(method):
		return fallback
	var value: Variant = source.callv(method, args)
	if value is Object:
		return value
	return fallback


static func call_string(source: Object, method: String, args: Array = [], fallback: String = "") -> String:
	if source == null or not source.has_method(method):
		return fallback
	return str(source.callv(method, args))


static func call_int(source: Object, method: String, args: Array = [], fallback: int = 0) -> int:
	if source == null or not source.has_method(method):
		return fallback
	return int(source.callv(method, args))


static func call_float(source: Object, method: String, args: Array = [], fallback: float = 0.0) -> float:
	if source == null or not source.has_method(method):
		return fallback
	return float(source.callv(method, args))


static func call_bool(source: Object, method: String, args: Array = [], fallback: bool = false) -> bool:
	if source == null or not source.has_method(method):
		return fallback
	return bool(source.callv(method, args))
