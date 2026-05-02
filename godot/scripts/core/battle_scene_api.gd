extends RefCounted


func configure_ball_physics_context(
	owner: Object,
	registry: Object,
	stage: int,
	league_mode: String = "champion",
	arena_enabled: bool = false,
	active_weather_type: String = ""
) -> void:
	var bridge: Object = _get_instance(registry, "ball_scene_bridge")
	if bridge != null:
		bridge.apply_physics_context(owner, registry, stage, league_mode, arena_enabled, active_weather_type)


func configure_ball_visual_state(
	owner: Object,
	registry: Object,
	visual_type: String = "energy",
	boost_active: bool = false,
	poisoned: bool = false,
	viper_knockback: bool = false,
	bomb_loaded: bool = false
) -> void:
	var bridge: Object = _get_instance(registry, "ball_scene_bridge")
	if bridge != null:
		bridge.apply_visual_state(owner, visual_type, boost_active, poisoned, viper_knockback, bomb_loaded)


func activate_drive_ball(
	owner: Object,
	registry: Object,
	direction: int,
	spin_strength: float,
	speed_multiplier: float = 1.015,
	speed_bypass_bonus: float = 0.0
) -> void:
	var bridge: Object = _get_instance(registry, "ball_scene_bridge")
	if bridge != null:
		bridge.apply_drive_ball(owner, registry, direction, spin_strength, speed_multiplier, speed_bypass_bonus)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
