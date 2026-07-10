extends RefCounted


static func get_callable(callbacks: Dictionary, key: String) -> Callable:
	var value: Variant = callbacks.get(key, Callable())
	if value is Callable:
		return value
	return Callable()


static func call_optional(callbacks: Dictionary, key: String, args: Array = []) -> Dictionary:
	var callback := get_callable(callbacks, key)
	if not callback.is_valid():
		return {"accepted": false, "blocked_reason": "missing_%s" % key}
	var result: Variant = callback.callv(args)
	if result is Dictionary:
		var result_dict: Dictionary = result
		if result_dict.has("accepted"):
			return result_dict
		result_dict["accepted"] = true
		return result_dict
	return {"accepted": true}


static func call_acceptance(callbacks: Dictionary, key: String, args: Array = []) -> Dictionary:
	var callback := get_callable(callbacks, key)
	if not callback.is_valid():
		return {"accepted": false, "blocked_reason": "missing_%s" % key}
	var result: Variant = callback.callv(args)
	if result is Dictionary:
		var result_dict: Dictionary = result
		if result_dict.has("accepted"):
			return result_dict
		result_dict["accepted"] = true
		return result_dict
	return {"accepted": bool(result)}


static func call_strict_acceptance(callbacks: Dictionary, key: String, args: Array = []) -> Dictionary:
	var callback := get_callable(callbacks, key)
	if not callback.is_valid():
		return {"accepted": false, "blocked_reason": "missing_%s" % key}
	var result: Variant = callback.callv(args)
	if result is Dictionary:
		return result
	return {"accepted": bool(result)}


static func call_bool(callbacks: Dictionary, key: String, args: Array = [], fallback: bool = false) -> bool:
	var callback := get_callable(callbacks, key)
	if not callback.is_valid():
		return fallback
	return bool(callback.callv(args))


static func call_int(callbacks: Dictionary, key: String, args: Array = [], fallback: int = 0) -> int:
	var callback := get_callable(callbacks, key)
	if not callback.is_valid():
		return fallback
	return int(callback.callv(args))


static func call_void(callbacks: Dictionary, key: String, args: Array = []) -> void:
	var callback := get_callable(callbacks, key)
	if callback.is_valid():
		callback.callv(args)


static func call_dict(callbacks: Dictionary, key: String, args: Array = []) -> Dictionary:
	var callback := get_callable(callbacks, key)
	if not callback.is_valid():
		return {"accepted": false, "blocked_reason": "missing_%s" % key}
	var result: Variant = callback.callv(args)
	if result is Dictionary:
		return result
	return {"accepted": false, "blocked_reason": "invalid_%s" % key}


static func call_string(callbacks: Dictionary, key: String, args: Array = [], fallback: String = "") -> String:
	var callback := get_callable(callbacks, key)
	if not callback.is_valid():
		return fallback
	return str(callback.callv(args))


static func call_array(callbacks: Dictionary, key: String, args: Array = []) -> Array:
	var callback := get_callable(callbacks, key)
	if not callback.is_valid():
		return []
	var result: Variant = callback.callv(args)
	if result is Array:
		return result
	return []


static func call_object(callbacks: Dictionary, key: String, args: Array = []) -> Object:
	var callback := get_callable(callbacks, key)
	if not callback.is_valid():
		return null
	var result: Variant = callback.callv(args)
	if result is Object:
		return result
	return null
