extends RefCounted

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")


func configure_physics_context(
	registry: Object,
	stage: int,
	league_mode: String = "champion",
	arena_enabled: bool = false,
	active_weather_type: String = ""
) -> Dictionary:
	var physics: Object = _get_module(registry, "ball_physics")
	var normalized_stage: int = max(1, stage)
	var normalized_mode: String = _normalize_league_mode(physics, league_mode)
	if physics != null and physics.has_method("configure_context"):
		physics.configure_context(normalized_stage, normalized_mode, arena_enabled, active_weather_type)
	return {
		"current_stage": normalized_stage,
		"ai_mode": normalized_mode,
		"arena_mode_enabled": arena_enabled,
		"weather_type": active_weather_type,
	}


func apply_physics_context(
	owner: Object,
	registry: Object,
	stage: int,
	league_mode: String = "champion",
	arena_enabled: bool = false,
	active_weather_type: String = ""
) -> void:
	apply_owner_snapshot(owner, configure_physics_context(
		registry,
		stage,
		league_mode,
		arena_enabled,
		active_weather_type
	))


func configure_visual_state(
	visual_type: String = "energy",
	boost_active: bool = false,
	poisoned: bool = false,
	viper_knockback: bool = false,
	bomb_loaded: bool = false
) -> Dictionary:
	var normalized_visual_type := "energy"
	if visual_type == "pingpong" or visual_type == "prism":
		normalized_visual_type = visual_type
	return {
		"ball_visual_type": normalized_visual_type,
		"boost_charging_active": boost_active,
		"poisoned_ball_overlay_active": poisoned,
		"viper_knockback_overlay_active": viper_knockback,
		"bomb_ball_loaded": bomb_loaded,
	}


func apply_visual_state(
	owner: Object,
	visual_type: String = "energy",
	boost_active: bool = false,
	poisoned: bool = false,
	viper_knockback: bool = false,
	bomb_loaded: bool = false
) -> void:
	apply_owner_snapshot(owner, configure_visual_state(
		visual_type,
		boost_active,
		poisoned,
		viper_knockback,
		bomb_loaded
	))


func apply_owner_snapshot(owner: Object, snapshot: Dictionary) -> void:
	if owner == null:
		return
	for key in snapshot.keys():
		owner.set(str(key), snapshot[key])


func _get_module(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _normalize_league_mode(physics: Object, league_mode: String) -> String:
	if physics != null and physics.has_method("normalize_league_mode"):
		return str(physics.normalize_league_mode(league_mode))
	return BattleSceneConfig.normalize_league_mode(league_mode)
