extends Node2D

const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")

var scene_state = BattleSceneState.new()
var gameplay_modules = GameplayModuleRegistry.new()


func _ready() -> void:
	var lifecycle = _get_module("battle_scene_lifecycle")
	if lifecycle != null:
		lifecycle.initialize(self, gameplay_modules)


func _get_module(key: String):
	return gameplay_modules.get_instance(key)


func _get(property: StringName) -> Variant:
	var key: String = str(property)
	if scene_state.has_key(key):
		return scene_state.get_value(key)
	return null


func _set(property: StringName, value: Variant) -> bool:
	var key: String = str(property)
	if not scene_state.has_key(key):
		return false
	scene_state.set_value(key, value)
	return true


func configure_ball_physics_context(
	stage: int,
	league_mode: String = "champion",
	arena_enabled: bool = false,
	active_weather_type: String = ""
) -> void:
	var api = _get_module("battle_scene_api")
	if api != null:
		api.configure_ball_physics_context(self, gameplay_modules, stage, league_mode, arena_enabled, active_weather_type)


func configure_ball_visual_state(
	visual_type: String = "energy",
	boost_active: bool = false,
	poisoned: bool = false,
	viper_knockback: bool = false,
	bomb_loaded: bool = false
) -> void:
	var api = _get_module("battle_scene_api")
	if api != null:
		api.configure_ball_visual_state(self, gameplay_modules, visual_type, boost_active, poisoned, viper_knockback, bomb_loaded)


func activate_drive_ball(
	direction: int,
	spin_strength: float,
	speed_multiplier: float = 1.015,
	speed_bypass_bonus: float = 0.0
) -> void:
	var api = _get_module("battle_scene_api")
	if api != null:
		api.activate_drive_ball(self, gameplay_modules, direction, spin_strength, speed_multiplier, speed_bypass_bonus)


func _physics_process(delta: float) -> void:
	var update_driver = _get_module("battle_scene_update_driver")
	if update_driver != null:
		update_driver.update(self, gameplay_modules, delta)


func _draw() -> void:
	var drawer = _get_module("battle_scene_drawer")
	if drawer != null:
		drawer.draw(self, gameplay_modules)
