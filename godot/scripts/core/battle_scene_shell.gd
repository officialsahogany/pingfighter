extends Node2D

const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")

const ITEM_SPAWN_DEBUG_KEY := KEY_F2

var scene_state = BattleSceneState.new()
var gameplay_modules = GameplayModuleRegistry.new()


func _ready() -> void:
	_apply_selection_state()
	var lifecycle = _get_module("battle_scene_lifecycle")
	if lifecycle != null:
		lifecycle.initialize(self, gameplay_modules)


func _get_module(key: String):
	return gameplay_modules.get_instance(key)


func _apply_selection_state() -> void:
	var selection_state := get_node_or_null("/root/GameSelectionState")
	if selection_state == null or not selection_state.has_method("get_selection"):
		return
	var selection: Dictionary = selection_state.get_selection()
	var runtime_character_id: String = str(selection.get("runtime_character_id", "smasher"))
	scene_state.set_value("selected_character_id", str(selection.get("character_id", "ufo_player")))
	scene_state.set_value("selected_runtime_character_id", runtime_character_id)
	scene_state.set_value("selected_character_type", runtime_character_id)
	scene_state.set_value("selected_character_name", str(selection.get("character_name", "스매셔")))


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


func _unhandled_input(event: InputEvent) -> void:
	var active_item_runtime = _get_module("active_item_runtime")
	if active_item_runtime == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == ITEM_SPAWN_DEBUG_KEY:
		if active_item_runtime.has_method("toggle_debug_spawn_menu"):
			active_item_runtime.toggle_debug_spawn_menu()
			queue_redraw()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if active_item_runtime.has_method("handle_debug_spawn_menu_click"):
			var handled: bool = bool(active_item_runtime.handle_debug_spawn_menu_click(event.position, get_viewport_rect().size))
			if handled:
				queue_redraw()
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var update_driver = _get_module("battle_scene_update_driver")
	if update_driver != null:
		update_driver.update_scoreboard_visuals(self, gameplay_modules, delta)
	var scoreboard_state = _get_module("scoreboard_state")
	if scoreboard_state == null or not scoreboard_state.is_active():
		return
	if update_driver != null:
		update_driver.update_scoreboard_overlay(self, gameplay_modules, delta)


func _physics_process(delta: float) -> void:
	var update_driver = _get_module("battle_scene_update_driver")
	if update_driver != null:
		update_driver.update(self, gameplay_modules, delta)


func _draw() -> void:
	var drawer = _get_module("battle_scene_drawer")
	if drawer != null:
		drawer.draw(self, gameplay_modules)
	var active_item_runtime = _get_module("active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("draw_debug_spawn_menu"):
		active_item_runtime.draw_debug_spawn_menu(self, get_viewport_rect().size)
