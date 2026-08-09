extends RefCounted

const PauseMenuDisplaySettingsState := preload("res://scripts/hud/pause_menu_display_settings_state.gd")
const PauseMenuInputCommandRouter := preload("res://scripts/hud/pause_menu_input_command_router.gd")
const PauseMenuLanguageSettingsController := preload("res://scripts/hud/pause_menu_language_settings_controller.gd")
const PauseMenuOptionsNavigationPolicy := preload("res://scripts/hud/pause_menu_options_navigation_policy.gd")
const PauseMenuOptionsRenderer := preload("res://scripts/hud/pause_menu_options_renderer.gd")
const PauseMenuOverlayLayout := preload("res://scripts/hud/pause_menu_overlay_layout.gd")

const SOUND_SLIDER_BGM := "bgm"
const SOUND_SLIDER_SFX := "sfx"

const COMMAND_CLEAR_DRAG := &"clear_drag"
const COMMAND_ACTIVATE_MAIN_INDEX := &"activate_main_index"
const COMMAND_RESET_TAB_DEFAULTS := &"reset_tab_defaults"
const COMMAND_SELECT_TAB := &"select_tab"
const COMMAND_BEGIN_SLIDER_DRAG := &"begin_slider_drag"
const COMMAND_DRAG_SLIDER := &"drag_slider"
const COMMAND_SET_DISPLAY_MODE := &"set_display_mode"
const COMMAND_TOGGLE_DISPLAY_DEFAULT := &"toggle_display_default"
const COMMAND_TOGGLE_AUTO_REFRESH := &"toggle_auto_refresh"
const COMMAND_APPLY_RECOMMENDED := &"apply_recommended"
const COMMAND_APPLY_60HZ := &"apply_60hz"
const COMMAND_SAVE_DISPLAY := &"save_display"
const COMMAND_SELECT_CONTROL_DEVICE := &"select_control_device"
const COMMAND_SET_LANGUAGE := &"set_language"


func route_button(
	mouse_event: InputEventMouseButton,
	options_open: bool,
	options_tab: String,
	controls_device: String,
	view_size: Vector2,
	main_entry_count: int
) -> Dictionary:
	if not mouse_event.pressed:
		return _command(COMMAND_CLEAR_DRAG)
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		return _command(PauseMenuInputCommandRouter.COMMAND_CLOSE_OPTIONS if options_open else PauseMenuInputCommandRouter.COMMAND_CLOSE_MAIN)
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return _command(PauseMenuInputCommandRouter.COMMAND_NONE)
	if options_open:
		return route_options_click(mouse_event.position, options_tab, controls_device, view_size)
	var panel_rect := PauseMenuOverlayLayout.get_main_panel_rect(view_size)
	for index in range(main_entry_count):
		var rect := PauseMenuOverlayLayout.get_button_rect(panel_rect, index, main_entry_count, main_entry_count)
		if rect.has_point(mouse_event.position):
			return _command(COMMAND_ACTIVATE_MAIN_INDEX, {"index": index})
	return _command(PauseMenuInputCommandRouter.COMMAND_NONE)


func route_options_click(position: Vector2, options_tab: String, controls_device: String, view_size: Vector2) -> Dictionary:
	var panel_rect := PauseMenuOverlayLayout.get_options_panel_rect(view_size)
	if PauseMenuOverlayLayout.get_reset_button_rect(panel_rect).has_point(position):
		return _command(COMMAND_RESET_TAB_DEFAULTS)
	var tab := _get_clicked_tab(position, panel_rect)
	if not tab.is_empty():
		return _command(COMMAND_SELECT_TAB, {"tab": tab})
	match options_tab:
		PauseMenuOptionsNavigationPolicy.TAB_DISPLAY:
			return route_display_click(position, panel_rect)
		PauseMenuOptionsNavigationPolicy.TAB_CONTROLS:
			return route_controls_click(position, panel_rect, controls_device)
		PauseMenuOptionsNavigationPolicy.TAB_LANGUAGE:
			return route_language_click(position, panel_rect)
	return route_sound_click(position, view_size, panel_rect)


func route_sound_click(position: Vector2, view_size: Vector2, panel_rect: Rect2) -> Dictionary:
	if PauseMenuOverlayLayout.get_back_button_rect(panel_rect).has_point(position):
		return _command(PauseMenuInputCommandRouter.COMMAND_CLOSE_OPTIONS)
	if PauseMenuOverlayLayout.get_slider_hit_rect(SOUND_SLIDER_BGM, view_size).has_point(position):
		return _command(COMMAND_BEGIN_SLIDER_DRAG, {
			"slider": SOUND_SLIDER_BGM,
			"focus": 0,
			"mouse_x": position.x,
			"view_size": view_size,
		})
	if PauseMenuOverlayLayout.get_slider_hit_rect(SOUND_SLIDER_SFX, view_size).has_point(position):
		return _command(COMMAND_BEGIN_SLIDER_DRAG, {
			"slider": SOUND_SLIDER_SFX,
			"focus": 1,
			"mouse_x": position.x,
			"view_size": view_size,
		})
	return _command(PauseMenuInputCommandRouter.COMMAND_NONE)


func route_display_click(position: Vector2, panel_rect: Rect2) -> Dictionary:
	if PauseMenuOverlayLayout.get_display_fullscreen_rect(panel_rect).has_point(position):
		return _display_mode_command(PauseMenuDisplaySettingsState.DISPLAY_MODE_FULLSCREEN)
	if PauseMenuOverlayLayout.get_display_exclusive_fullscreen_rect(panel_rect).has_point(position):
		return _display_mode_command(PauseMenuDisplaySettingsState.DISPLAY_MODE_EXCLUSIVE_FULLSCREEN)
	if PauseMenuOverlayLayout.get_display_windowed_rect(panel_rect).has_point(position):
		return _display_mode_command(PauseMenuDisplaySettingsState.DISPLAY_MODE_WINDOWED)
	if PauseMenuOverlayLayout.get_display_fps_cap_row_rect(panel_rect).has_point(position):
		var fps_direction := _get_chevron_direction(position, PauseMenuOverlayLayout.get_display_fps_cap_value_rect(panel_rect))
		return _command(PauseMenuInputCommandRouter.COMMAND_ADJUST_DISPLAY, {
			"focus": 1,
			"direction": fps_direction,
			"feedback": "confirm" if fps_direction != 0 else "",
		})
	if PauseMenuOverlayLayout.get_display_vsync_row_rect(panel_rect).has_point(position):
		var vsync_direction := _get_chevron_direction(position, PauseMenuOverlayLayout.get_display_vsync_value_rect(panel_rect))
		return _command(PauseMenuInputCommandRouter.COMMAND_ADJUST_DISPLAY, {
			"focus": 2,
			"direction": vsync_direction,
			"feedback": "confirm" if vsync_direction != 0 else "",
		})
	if PauseMenuOverlayLayout.get_display_default_row_rect(panel_rect).has_point(position):
		return _command(COMMAND_TOGGLE_DISPLAY_DEFAULT, {"focus": 3})
	if PauseMenuOverlayLayout.get_display_auto_refresh_row_rect(panel_rect).has_point(position):
		return _command(COMMAND_TOGGLE_AUTO_REFRESH, {"focus": 4})
	if PauseMenuOverlayLayout.get_display_recommended_button_rect(panel_rect).has_point(position):
		return _command(COMMAND_APPLY_RECOMMENDED, {"focus": 5})
	if PauseMenuOverlayLayout.get_display_apply_60hz_button_rect(panel_rect).has_point(position):
		return _command(COMMAND_APPLY_60HZ, {"focus": 6})
	if PauseMenuOverlayLayout.get_display_save_button_rect(panel_rect).has_point(position):
		return _command(COMMAND_SAVE_DISPLAY, {"focus": 7})
	if PauseMenuOverlayLayout.get_display_back_button_rect(panel_rect).has_point(position):
		return _command(PauseMenuInputCommandRouter.COMMAND_CLOSE_OPTIONS)
	return _command(PauseMenuInputCommandRouter.COMMAND_NONE)


func route_controls_click(position: Vector2, panel_rect: Rect2, controls_device: String) -> Dictionary:
	if PauseMenuOverlayLayout.get_controls_keyboard_mouse_rect(panel_rect).has_point(position):
		return _command(COMMAND_SELECT_CONTROL_DEVICE, {
			"device": PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE,
			"focus": 0,
		})
	if PauseMenuOverlayLayout.get_controls_joypad_rect(panel_rect).has_point(position):
		return _command(COMMAND_SELECT_CONTROL_DEVICE, {
			"device": PauseMenuOptionsNavigationPolicy.DEVICE_JOYPAD,
			"focus": 0,
		})
	if controls_device == PauseMenuOptionsNavigationPolicy.DEVICE_JOYPAD and PauseMenuOverlayLayout.get_controls_vibration_row_rect(panel_rect).has_point(position):
		var vibration_direction := _get_chevron_direction(position, PauseMenuOverlayLayout.get_controls_vibration_value_rect(panel_rect))
		return _command(PauseMenuInputCommandRouter.COMMAND_ADJUST_CONTROLS, {
			"focus": 1,
			"direction": vibration_direction,
			"feedback": "confirm" if vibration_direction != 0 else "",
		})
	if PauseMenuOverlayLayout.get_controls_back_button_rect(panel_rect).has_point(position):
		return _command(PauseMenuInputCommandRouter.COMMAND_CLOSE_OPTIONS)
	return _command(PauseMenuInputCommandRouter.COMMAND_NONE)


func route_language_click(position: Vector2, panel_rect: Rect2) -> Dictionary:
	var language_rects: Array[Rect2] = [
		PauseMenuOverlayLayout.get_language_korean_rect(panel_rect),
		PauseMenuOverlayLayout.get_language_english_rect(panel_rect),
		PauseMenuOverlayLayout.get_language_chinese_rect(panel_rect),
		PauseMenuOverlayLayout.get_language_japanese_rect(panel_rect),
		PauseMenuOverlayLayout.get_language_spanish_rect(panel_rect),
		PauseMenuOverlayLayout.get_language_portuguese_brazil_rect(panel_rect),
		PauseMenuOverlayLayout.get_language_russian_rect(panel_rect),
	]
	for index in range(language_rects.size()):
		if language_rects[index].has_point(position):
			return _command(COMMAND_SET_LANGUAGE, {
				"language": PauseMenuLanguageSettingsController.get_language_for_focus(index),
				"focus": index,
			})
	if PauseMenuOverlayLayout.get_language_back_button_rect(panel_rect).has_point(position):
		return _command(PauseMenuInputCommandRouter.COMMAND_CLOSE_OPTIONS)
	return _command(PauseMenuInputCommandRouter.COMMAND_NONE)


func route_motion(options_open: bool, dragging_slider: String, mouse_x: float, view_size: Vector2 = Vector2.ZERO) -> Dictionary:
	if options_open and not dragging_slider.is_empty():
		return _command(COMMAND_DRAG_SLIDER, {
			"slider": dragging_slider,
			"mouse_x": mouse_x,
			"view_size": view_size,
		})
	return _command(PauseMenuInputCommandRouter.COMMAND_NONE)


func _get_clicked_tab(position: Vector2, panel_rect: Rect2) -> String:
	if PauseMenuOverlayLayout.get_sound_tab_rect(panel_rect).has_point(position):
		return PauseMenuOptionsNavigationPolicy.TAB_SOUND
	if PauseMenuOverlayLayout.get_display_tab_rect(panel_rect).has_point(position):
		return PauseMenuOptionsNavigationPolicy.TAB_DISPLAY
	if PauseMenuOverlayLayout.get_controls_tab_rect(panel_rect).has_point(position):
		return PauseMenuOptionsNavigationPolicy.TAB_CONTROLS
	if PauseMenuOverlayLayout.get_language_tab_rect(panel_rect).has_point(position):
		return PauseMenuOptionsNavigationPolicy.TAB_LANGUAGE
	return ""


func _display_mode_command(mode: String) -> Dictionary:
	return _command(COMMAND_SET_DISPLAY_MODE, {
		"mode": mode,
		"focus": 0,
	})


func _get_chevron_direction(position: Vector2, value_rect: Rect2) -> int:
	var chevrons := PauseMenuOptionsRenderer.get_select_chevron_rects(value_rect)
	var left_rect: Rect2 = chevrons.get("left", Rect2())
	var right_rect: Rect2 = chevrons.get("right", Rect2())
	if left_rect.has_point(position):
		return -1
	if right_rect.has_point(position):
		return 1
	return 0


func _command(command: StringName, fields: Dictionary = {}) -> Dictionary:
	var result := {"command": command}
	for key in fields:
		result[key] = fields[key]
	return result
