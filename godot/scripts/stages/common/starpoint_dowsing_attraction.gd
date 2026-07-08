extends RefCounted

const LingpetStarlightTrackingState := preload("res://scripts/lingpet/lingpet_starlight_tracking_state.gd")


static func resolve_context(context: Dictionary, deps: Dictionary) -> Dictionary:
	var runtime := _resolve_mythic_item_runtime(context, deps)
	if runtime == null or not runtime.has_method("get_dowsing_pendulum_context"):
		return {}
	var pendulum_context: Variant = runtime.get_dowsing_pendulum_context()
	if pendulum_context is Dictionary and bool((pendulum_context as Dictionary).get("active", false)):
		return pendulum_context
	return {}


static func resolve_player_center(context: Dictionary) -> Vector2:
	var player_pos: Vector2 = _get_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var paddle_size: Vector2 = _get_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	return player_pos + paddle_size * 0.5


static func apply_to_drop(
	drop: Dictionary,
	dowsing_context: Dictionary,
	player_center: Vector2,
	fps_scale: float
) -> void:
	if drop.is_empty() or dowsing_context.is_empty():
		return
	if bool(drop.get(LingpetStarlightTrackingState.DROP_ACTIVE_KEY, false)):
		return
	var attraction_range: float = maxf(0.0, float(dowsing_context.get("range", 0.0)))
	if attraction_range <= 0.0:
		return
	var pos: Vector2 = _get_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO)
	var vel: Vector2 = _get_vector2(drop.get("vel", Vector2.ZERO), Vector2.ZERO)
	var offset: Vector2 = player_center - pos
	var distance: float = offset.length()
	var min_distance: float = maxf(0.0, float(dowsing_context.get("min_distance", 30.0)))
	if distance <= min_distance or distance > attraction_range:
		return
	var force_multiplier: float = 1.0 - distance / attraction_range
	var force: float = maxf(0.0, float(dowsing_context.get("force", 3.5))) * force_multiplier
	var next_vel: Vector2 = vel + offset / distance * force * maxf(0.0, fps_scale)
	var max_speed: float = maxf(0.0, float(dowsing_context.get("max_speed", 8.0)))
	if max_speed > 0.0 and next_vel.length() > max_speed:
		next_vel = next_vel.normalized() * max_speed
	drop["vel"] = next_vel


static func _resolve_mythic_item_runtime(context: Dictionary, deps: Dictionary) -> Object:
	var runtime_value: Variant = deps.get("mythic_item_runtime", null)
	if runtime_value is Object:
		return runtime_value as Object
	var registry_value: Variant = context.get("registry", deps.get("registry", null))
	if registry_value is Object and (registry_value as Object).has_method("get_instance"):
		var runtime_from_registry: Variant = (registry_value as Object).get_instance("mythic_item_runtime")
		if runtime_from_registry is Object:
			return runtime_from_registry as Object
	return null


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
