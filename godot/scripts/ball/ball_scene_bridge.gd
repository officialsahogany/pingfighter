extends RefCounted

const BallDriveSceneBridge := preload("res://scripts/ball/ball_drive_scene_bridge.gd")
const BallRuntimeSceneBridge := preload("res://scripts/ball/ball_runtime_scene_bridge.gd")

var drive_bridge: Object = BallDriveSceneBridge.new()
var runtime_bridge: Object = BallRuntimeSceneBridge.new()


func configure_physics_context(
	registry: Object,
	stage: int,
	league_mode: String = "champion",
	arena_enabled: bool = false,
	active_weather_type: String = ""
) -> Dictionary:
	return runtime_bridge.configure_physics_context(registry, stage, league_mode, arena_enabled, active_weather_type)


func apply_physics_context(
	owner: Object,
	registry: Object,
	stage: int,
	league_mode: String = "champion",
	arena_enabled: bool = false,
	active_weather_type: String = ""
) -> void:
	runtime_bridge.apply_physics_context(owner, registry, stage, league_mode, arena_enabled, active_weather_type)


func configure_visual_state(
	visual_type: String = "energy",
	boost_active: bool = false,
	poisoned: bool = false,
	viper_knockback: bool = false,
	bomb_loaded: bool = false
) -> Dictionary:
	return runtime_bridge.configure_visual_state(
		visual_type,
		boost_active,
		poisoned,
		viper_knockback,
		bomb_loaded
	)


func apply_visual_state(
	owner: Object,
	visual_type: String = "energy",
	boost_active: bool = false,
	poisoned: bool = false,
	viper_knockback: bool = false,
	bomb_loaded: bool = false
) -> void:
	runtime_bridge.apply_visual_state(
		owner,
		visual_type,
		boost_active,
		poisoned,
		viper_knockback,
		bomb_loaded
	)


func activate_drive_ball(
	owner: Object,
	registry: Object,
	direction: int,
	spin_strength: float,
	speed_multiplier: float = 1.015,
	speed_bypass_bonus: float = 0.0
) -> Dictionary:
	return drive_bridge.activate_drive_ball(
		owner,
		registry,
		direction,
		spin_strength,
		speed_multiplier,
		speed_bypass_bonus
	)


func apply_drive_ball(
	owner: Object,
	registry: Object,
	direction: int,
	spin_strength: float,
	speed_multiplier: float = 1.015,
	speed_bypass_bonus: float = 0.0
) -> void:
	runtime_bridge.apply_owner_snapshot(owner, activate_drive_ball(
		owner,
		registry,
		direction,
		spin_strength,
		speed_multiplier,
		speed_bypass_bonus
	))


func clear_drive_ball_state(registry: Object, clear_spin: bool = false) -> Dictionary:
	return drive_bridge.clear_drive_ball_state(registry, clear_spin)


func clear_power_smashing_state(registry: Object, clear_text: bool = true) -> void:
	drive_bridge.clear_power_smashing_state(registry, clear_text)


func reset_drive_input_frames(registry: Object) -> void:
	drive_bridge.reset_drive_input_frames(registry)
