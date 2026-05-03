extends Node2D

const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")

const ITEM_SPAWN_DEBUG_KEY := KEY_F2
const RUNTIME_PERK_DEBUG_KEY := KEY_F8
const FULLSCREEN_TOGGLE_KEY := KEY_F11
const CHARACTER_INFO_KEY := KEY_TAB

var scene_state = BattleSceneState.new()
var gameplay_modules = GameplayModuleRegistry.new()
var _battle_initialized := false
var _stage_landing_intro_started := false


func _ready() -> void:
	_apply_selection_state()
	_configure_battle_window()
	var logo_intro = _get_module("penguin_logo_intro")
	if logo_intro != null and logo_intro.has_method("begin") and bool(logo_intro.begin(self)):
		queue_redraw()
		return
	_initialize_battle()
	_begin_stage_landing_intro()


func _initialize_battle() -> void:
	if _battle_initialized:
		return
	var lifecycle = _get_module("battle_scene_lifecycle")
	if lifecycle != null:
		lifecycle.initialize(self, gameplay_modules)
	_battle_initialized = true


func _begin_stage_landing_intro() -> void:
	if _stage_landing_intro_started or not _battle_initialized:
		return
	_stage_landing_intro_started = true
	var landing_intro = _get_module("stage_landing_intro")
	if landing_intro != null and landing_intro.has_method("begin"):
		if bool(landing_intro.begin(self, gameplay_modules)):
			queue_redraw()


func _get_module(key: String):
	return gameplay_modules.get_instance(key)


func _configure_battle_window() -> void:
	var view_layout = _get_module("battle_view_layout")
	if view_layout != null and view_layout.has_method("configure_window"):
		view_layout.configure_window(get_window())


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


func configure_player_character(character_type: String = "smasher") -> void:
	var api = _get_module("battle_scene_api")
	if api != null:
		api.configure_player_character(self, gameplay_modules, character_type)


func activate_drive_ball(
	direction: int,
	spin_strength: float,
	speed_multiplier: float = 1.015,
	speed_bypass_bonus: float = 0.0
) -> void:
	var api = _get_module("battle_scene_api")
	if api != null:
		api.activate_drive_ball(self, gameplay_modules, direction, spin_strength, speed_multiplier, speed_bypass_bonus)


func collect_star_point(amount: int = 1) -> void:
	var api = _get_module("battle_scene_api")
	if api != null and api.has_method("collect_star_point"):
		api.collect_star_point(self, gameplay_modules, amount)


func _unhandled_input(event: InputEvent) -> void:
	if _handle_window_shortcut(event):
		return
	if _is_logo_intro_active() or not _battle_initialized:
		return
	if _is_stage_landing_intro_active():
		var landing_intro = _get_module("stage_landing_intro")
		if landing_intro != null and landing_intro.has_method("handle_input"):
			var handled: bool = bool(landing_intro.handle_input(event, gameplay_modules))
			if handled:
				queue_redraw()
				get_viewport().set_input_as_handled()
		return
	var runtime_perk_state = _get_module("runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("is_choice_active") and bool(runtime_perk_state.is_choice_active()):
		if runtime_perk_state.has_method("handle_input"):
			var handled: bool = bool(runtime_perk_state.handle_input(event, self, gameplay_modules, get_viewport_rect().size))
			if handled:
				queue_redraw()
				get_viewport().set_input_as_handled()
		return

	var character_info = _get_module("character_info_overlay")
	if character_info != null and character_info.has_method("is_active") and bool(character_info.is_active()):
		if character_info.has_method("handle_input"):
			var handled_info: bool = bool(character_info.handle_input(event, self, gameplay_modules, get_viewport_rect().size))
			if handled_info:
				queue_redraw()
				get_viewport().set_input_as_handled()
		return

	if _is_character_info_toggle(event):
		if character_info != null and character_info.has_method("open"):
			character_info.open()
			queue_redraw()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == RUNTIME_PERK_DEBUG_KEY:
		collect_star_point(1)
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

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


func _handle_window_shortcut(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	if not event.pressed or event.echo:
		return false
	if event.keycode != FULLSCREEN_TOGGLE_KEY and event.physical_keycode != FULLSCREEN_TOGGLE_KEY:
		return false
	var view_layout = _get_module("battle_view_layout")
	if view_layout == null or not view_layout.has_method("toggle_fullscreen"):
		return false
	view_layout.toggle_fullscreen(get_window())
	queue_redraw()
	get_viewport().set_input_as_handled()
	return true

func _process(delta: float) -> void:
	var logo_intro = _get_module("penguin_logo_intro")
	if logo_intro != null and logo_intro.has_method("is_active") and bool(logo_intro.is_active()):
		if logo_intro.has_method("update"):
			logo_intro.update(delta)
		if logo_intro.has_method("is_active") and not bool(logo_intro.is_active()):
			_initialize_battle()
			_begin_stage_landing_intro()
		queue_redraw()
		return
	if not _battle_initialized:
		_initialize_battle()
		_begin_stage_landing_intro()

	var landing_intro = _get_module("stage_landing_intro")
	if landing_intro != null and landing_intro.has_method("is_active") and bool(landing_intro.is_active()):
		if landing_intro.has_method("update"):
			landing_intro.update(delta, gameplay_modules)
		queue_redraw()
		return

	var runtime_perk_state = _get_module("runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("is_choice_active") and bool(runtime_perk_state.is_choice_active()):
		if runtime_perk_state.has_method("update"):
			runtime_perk_state.update(delta, get_viewport_rect().size)
		queue_redraw()
		return

	var character_info = _get_module("character_info_overlay")
	if character_info != null and character_info.has_method("is_active") and bool(character_info.is_active()):
		if character_info.has_method("update"):
			character_info.update(delta)
		queue_redraw()
		return

	var update_driver = _get_module("battle_scene_update_driver")
	if update_driver != null:
		update_driver.update_scoreboard_visuals(self, gameplay_modules, delta)
	var scoreboard_state = _get_module("scoreboard_state")
	if scoreboard_state == null or not scoreboard_state.is_active():
		return
	if update_driver != null:
		update_driver.update_scoreboard_overlay(self, gameplay_modules, delta)


func _physics_process(delta: float) -> void:
	if _is_logo_intro_active() or not _battle_initialized or _is_stage_landing_intro_active():
		return
	var runtime_perk_state = _get_module("runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("is_choice_active") and bool(runtime_perk_state.is_choice_active()):
		return
	var character_info = _get_module("character_info_overlay")
	if character_info != null and character_info.has_method("is_active") and bool(character_info.is_active()):
		return
	var update_driver = _get_module("battle_scene_update_driver")
	if update_driver != null:
		update_driver.update(self, gameplay_modules, delta)


func _draw() -> void:
	var logo_intro = _get_module("penguin_logo_intro")
	if logo_intro != null and logo_intro.has_method("is_active") and bool(logo_intro.is_active()):
		if logo_intro.has_method("draw"):
			logo_intro.draw(self, get_viewport_rect().size)
		return
	if not _battle_initialized:
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color.BLACK)
		return
	var landing_intro = _get_module("stage_landing_intro")
	if landing_intro != null and landing_intro.has_method("is_active") and bool(landing_intro.is_active()):
		if landing_intro.has_method("draw"):
			landing_intro.draw(self, self, gameplay_modules, get_viewport_rect().size)
		return
	var drawer = _get_module("battle_scene_drawer")
	if drawer != null:
		drawer.draw(self, gameplay_modules)
	var character_info = _get_module("character_info_overlay")
	if character_info != null and character_info.has_method("is_active") and bool(character_info.is_active()):
		if character_info.has_method("draw"):
			character_info.draw(self, self, gameplay_modules, get_viewport_rect().size)
		return
	var active_item_runtime = _get_module("active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("draw_debug_spawn_menu"):
		active_item_runtime.draw_debug_spawn_menu(self, get_viewport_rect().size)


func _is_logo_intro_active() -> bool:
	var logo_intro = _get_module("penguin_logo_intro")
	return logo_intro != null and logo_intro.has_method("is_active") and bool(logo_intro.is_active())


func _is_stage_landing_intro_active() -> bool:
	var landing_intro = _get_module("stage_landing_intro")
	return landing_intro != null and landing_intro.has_method("is_active") and bool(landing_intro.is_active())


func _is_character_info_toggle(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return false
	return key_event.keycode == CHARACTER_INFO_KEY or key_event.physical_keycode == CHARACTER_INFO_KEY
