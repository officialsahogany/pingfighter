extends RefCounted

const CommandoSupplyDropAircraftLifecycleState := preload("res://scripts/characters/commando_supply_drop_aircraft_lifecycle_state.gd")
const CommandoSupplyDropCollectibleState := preload("res://scripts/characters/commando_supply_drop_collectible_state.gd")

const PAYLOAD_MIN_Y := 15.0
const PAYLOAD_MAX_Y := 735.0


static func build_collision_context(deps: Dictionary) -> Dictionary:
	var context_value: Variant = deps.get("commando_supply_drop_collision_context", {})
	var context: Dictionary = context_value.duplicate(true) if context_value is Dictionary else {}
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime == null or not active_item_runtime.has_method("get_ball_collision_context"):
		return context
	var active_item_context_value: Variant = active_item_runtime.get_ball_collision_context()
	if active_item_context_value is Dictionary and not (active_item_context_value as Dictionary).is_empty():
		context.merge(active_item_context_value as Dictionary, true)
	return context


static func get_payload_spawn_position(aircraft_pos: Vector2, deps: Dictionary = {}) -> Vector2:
	var bounds: Vector2 = get_payload_center_bounds(deps)
	var offset: Vector2 = CommandoSupplyDropAircraftLifecycleState.PAYLOAD_SPAWN_OFFSET
	return Vector2(
		clamp(aircraft_pos.x + offset.x, bounds.x, bounds.y),
		clamp(aircraft_pos.y + offset.y, PAYLOAD_MIN_Y, PAYLOAD_MAX_Y)
	)


static func get_payload_center_bounds(deps: Dictionary = {}) -> Vector2:
	var default_play_width: float = CommandoSupplyDropAircraftLifecycleState.DEFAULT_PLAY_WIDTH
	var play_width: float = max(1.0, float(deps.get("play_width", deps.get("width", default_play_width))))
	var safe_margin: float = CommandoSupplyDropCollectibleState.COLLECTIBLE_DROP_SAFE_MARGIN
	var min_x: float = clamp(
		float(deps.get("commando_supply_drop_center_min_x", safe_margin)),
		0.0,
		play_width
	)
	var max_x: float = clamp(
		float(deps.get("commando_supply_drop_center_max_x", play_width - safe_margin)),
		0.0,
		play_width
	)
	if max_x < min_x:
		var center_x: float = play_width * 0.5
		return Vector2(center_x, center_x)
	return Vector2(min_x, max_x)
