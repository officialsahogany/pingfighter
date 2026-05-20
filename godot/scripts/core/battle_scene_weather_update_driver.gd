extends RefCounted


func update_weather(owner: Object, registry: Object, delta: float) -> void:
	var weather: Object = _get_weather(registry)
	if weather != null and weather.has_method("update"):
		weather.update(owner, registry, delta)


func on_round_start(owner: Object, registry: Object) -> Dictionary:
	var weather: Object = _get_weather(registry)
	if weather == null or not weather.has_method("advance_round_start"):
		return {}
	var result: Dictionary = weather.advance_round_start(owner, registry)
	_arm_baal_boots_if_needed(owner, registry, weather)
	return result


func draw_weather(canvas: CanvasItem, registry: Object, shake_offset: Vector2 = Vector2.ZERO) -> void:
	var weather: Object = _get_weather(registry)
	var renderer: Object = _get_instance(registry, "weather_event_renderer")
	if renderer != null and renderer.has_method("draw"):
		renderer.draw(weather, canvas, shake_offset)
	elif weather != null and weather.has_method("draw"):
		weather.draw(canvas, shake_offset)


func debug_cycle_weather_event(owner: Object, registry: Object) -> Dictionary:
	var weather: Object = _get_weather(registry)
	if weather == null or not weather.has_method("debug_cycle_weather_event"):
		return {"handled": false}
	return weather.debug_cycle_weather_event(owner, registry)


func debug_force_weather_event(weather_type: String, owner: Object, registry: Object) -> Dictionary:
	var weather: Object = _get_weather(registry)
	if weather == null or not weather.has_method("debug_force_weather_event"):
		return {"handled": false}
	var result: Variant = weather.debug_force_weather_event(weather_type, owner, registry)
	var result_dict: Dictionary = result if result is Dictionary else {"handled": true}
	if bool(result_dict.get("started", false)):
		_arm_baal_boots_if_needed(owner, registry, weather)
	return result_dict


func _arm_baal_boots_if_needed(owner: Object, registry: Object, weather: Object) -> void:
	if weather == null or not weather.has_method("is_weather_active") or not bool(weather.is_weather_active()):
		return
	if not weather.has_method("get_weather_type"):
		return
	var mythic_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_runtime != null and mythic_runtime.has_method("on_weather_round_start"):
		mythic_runtime.on_weather_round_start(owner, registry, str(weather.get_weather_type()))


func _get_weather(registry: Object) -> Object:
	return _get_instance(registry, "weather_event_state")


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
