extends RefCounted

const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")

var _method_accepts_argument_count_cache: Dictionary = {}


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


func draw_weather(canvas: CanvasItem, registry: Object, shake_offset: Vector2 = Vector2.ZERO, draw_context: Dictionary = {}) -> void:
	var weather: Object = _get_weather(registry)
	if not _should_draw_weather_instance(weather, draw_context):
		return
	var renderer: Object = _get_instance(registry, "weather_event_renderer")
	var effect_lod_scale: float = BattleRenderQuality.effect_scale(draw_context)
	if renderer != null and renderer.has_method("draw"):
		if _method_accepts_argument_count(renderer, "draw", 4):
			renderer.draw(weather, canvas, shake_offset, effect_lod_scale)
		else:
			renderer.draw(weather, canvas, shake_offset)
	elif weather != null and weather.has_method("draw"):
		if _method_accepts_argument_count(weather, "draw", 3):
			weather.draw(canvas, shake_offset, effect_lod_scale)
		else:
			weather.draw(canvas, shake_offset)


func should_draw_weather(registry: Object, draw_context: Dictionary = {}) -> bool:
	return _should_draw_weather_instance(_get_weather(registry), draw_context)


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


func _should_draw_weather_instance(weather: Object, draw_context: Dictionary) -> bool:
	if _should_skip_blank_context_weather(weather, draw_context):
		return false
	if not _has_visible_weather_effects(weather):
		return false
	return true


func _has_visible_weather_effects(weather: Object) -> bool:
	if weather == null:
		return false
	if weather.has_method("has_visible_effects"):
		return bool(weather.has_visible_effects())
	var checked_visibility := false
	if weather.has_method("get_weather_context"):
		var context_value: Variant = weather.get_weather_context()
		if context_value is Dictionary:
			checked_visibility = true
			var context: Dictionary = context_value
			if bool(context.get("active", false)):
				return true
			if float(context.get("warning_timer_frames", 0.0)) > 0.0 or float(context.get("end_timer_frames", 0.0)) > 0.0:
				return true
			if bool(context.get("sand_dissolving", false)) or float(context.get("sand_total_depth", 0.0)) > 0.5:
				return true
	if weather.has_method("is_weather_active"):
		checked_visibility = true
		if bool(weather.is_weather_active()):
			return true
	if weather.has_method("get_render_particles"):
		checked_visibility = true
		var particles_value: Variant = weather.get_render_particles()
		if particles_value is Array and not particles_value.is_empty():
			return true
	if weather.has_method("get_sand_total_depth"):
		checked_visibility = true
		if float(weather.get_sand_total_depth()) > 0.5:
			return true
	return not checked_visibility


func _should_skip_blank_context_weather(_weather: Object, draw_context: Dictionary) -> bool:
	if not _has_explicit_weather_draw_context(draw_context):
		return false
	if bool(draw_context.get("weather_event_active", false)) or bool(draw_context.get("weather_active", false)):
		return false
	if str(draw_context.get("weather_type", "")).strip_edges() != "":
		return false
	var context_value: Variant = draw_context.get("weather_event_context", {})
	if context_value is Dictionary:
		var weather_context: Dictionary = context_value
		if bool(weather_context.get("active", false)):
			return false
		if str(weather_context.get("type", "")).strip_edges() != "":
			return false
	return true


func _has_explicit_weather_draw_context(draw_context: Dictionary) -> bool:
	return (
		draw_context.has("weather_event_active")
		or draw_context.has("weather_active")
		or draw_context.has("weather_type")
		or draw_context.has("weather_event_context")
	)


func _method_accepts_argument_count(target: Object, method_name: String, arg_count: int) -> bool:
	if target == null:
		return false
	var cache_key := _get_method_acceptance_cache_key(target, method_name, arg_count)
	if _method_accepts_argument_count_cache.has(cache_key):
		return bool(_method_accepts_argument_count_cache[cache_key])
	for method_info in target.get_method_list():
		if not (method_info is Dictionary):
			continue
		if str(method_info.get("name", "")) != method_name:
			continue
		var args_count: int = 0
		var args_value: Variant = method_info.get("args", [])
		if args_value is Array:
			args_count = args_value.size()
		var default_count: int = 0
		var default_value: Variant = method_info.get("default_args", [])
		if default_value is Array:
			default_count = default_value.size()
		var required_count: int = maxi(0, args_count - default_count)
		var accepts := arg_count >= required_count and arg_count <= args_count
		_method_accepts_argument_count_cache[cache_key] = accepts
		return accepts
	_method_accepts_argument_count_cache[cache_key] = false
	return false


func _get_method_acceptance_cache_key(target: Object, method_name: String, arg_count: int) -> String:
	return "%d:%s:%d" % [target.get_instance_id(), method_name, arg_count]
