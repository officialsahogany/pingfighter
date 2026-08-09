extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PauseMenuInputCommandRouter := preload("res://scripts/hud/pause_menu_input_command_router.gd")
const PauseMenuOptionsNavigationPolicy := preload("res://scripts/hud/pause_menu_options_navigation_policy.gd")
const PauseMenuOptionsRenderer := preload("res://scripts/hud/pause_menu_options_renderer.gd")
const PauseMenuOverlayLayout := preload("res://scripts/hud/pause_menu_overlay_layout.gd")
const PauseMenuPointerCommandRouter := preload("res://scripts/hud/pause_menu_pointer_command_router.gd")

const VIEW_SIZE := Vector2(1280.0, 720.0)
const MAIN_ENTRY_COUNT := 4

var _failures: Array[String] = []


func _init() -> void:
	var router := PauseMenuPointerCommandRouter.new()
	_verify_button_lifecycle(router)
	_verify_options_tabs_and_sound(router)
	_verify_display_clicks(router)
	_verify_controls_and_language_clicks(router)
	_verify_motion(router)
	_verify_overlay_ownership()
	if _failures.is_empty():
		print("pause_menu_pointer_command_router_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_button_lifecycle(router: Object) -> void:
	var release := _mouse(MOUSE_BUTTON_LEFT, Vector2.ZERO, false)
	_expect_command(router.route_button(release, false, PauseMenuOptionsNavigationPolicy.TAB_SOUND, PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE, VIEW_SIZE, MAIN_ENTRY_COUNT), PauseMenuPointerCommandRouter.COMMAND_CLEAR_DRAG, "mouse release")
	_expect_command(router.route_button(_mouse(MOUSE_BUTTON_RIGHT, Vector2.ZERO), false, PauseMenuOptionsNavigationPolicy.TAB_SOUND, PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE, VIEW_SIZE, MAIN_ENTRY_COUNT), PauseMenuInputCommandRouter.COMMAND_CLOSE_MAIN, "main right click")
	_expect_command(router.route_button(_mouse(MOUSE_BUTTON_RIGHT, Vector2.ZERO), true, PauseMenuOptionsNavigationPolicy.TAB_SOUND, PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE, VIEW_SIZE, MAIN_ENTRY_COUNT), PauseMenuInputCommandRouter.COMMAND_CLOSE_OPTIONS, "options right click")
	var main_panel := PauseMenuOverlayLayout.get_main_panel_rect(VIEW_SIZE)
	var third_row := PauseMenuOverlayLayout.get_button_rect(main_panel, 2, MAIN_ENTRY_COUNT, MAIN_ENTRY_COUNT)
	var main_command: Dictionary = router.route_button(_mouse(MOUSE_BUTTON_LEFT, third_row.get_center()), false, PauseMenuOptionsNavigationPolicy.TAB_SOUND, PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE, VIEW_SIZE, MAIN_ENTRY_COUNT)
	_expect_command(main_command, PauseMenuPointerCommandRouter.COMMAND_ACTIVATE_MAIN_INDEX, "main row click")
	_expect(int(main_command.get("index", -1)) == 2, "main row click should carry the hit index")


func _verify_options_tabs_and_sound(router: Object) -> void:
	var panel := PauseMenuOverlayLayout.get_options_panel_rect(VIEW_SIZE)
	_expect_command(router.route_options_click(PauseMenuOverlayLayout.get_reset_button_rect(panel).get_center(), PauseMenuOptionsNavigationPolicy.TAB_SOUND, PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE, VIEW_SIZE), PauseMenuPointerCommandRouter.COMMAND_RESET_TAB_DEFAULTS, "reset click")
	var tab_command: Dictionary = router.route_options_click(PauseMenuOverlayLayout.get_display_tab_rect(panel).get_center(), PauseMenuOptionsNavigationPolicy.TAB_SOUND, PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE, VIEW_SIZE)
	_expect_command(tab_command, PauseMenuPointerCommandRouter.COMMAND_SELECT_TAB, "display tab click")
	_expect(str(tab_command.get("tab", "")) == PauseMenuOptionsNavigationPolicy.TAB_DISPLAY, "display tab click should carry display tab")
	var slider_command: Dictionary = router.route_sound_click(PauseMenuOverlayLayout.get_slider_hit_rect("bgm", VIEW_SIZE).get_center(), VIEW_SIZE, panel)
	_expect_command(slider_command, PauseMenuPointerCommandRouter.COMMAND_BEGIN_SLIDER_DRAG, "BGM slider click")
	_expect(str(slider_command.get("slider", "")) == "bgm" and int(slider_command.get("focus", -1)) == 0, "BGM slider click should carry slider and focus")
	_expect_command(router.route_sound_click(PauseMenuOverlayLayout.get_back_button_rect(panel).get_center(), VIEW_SIZE, panel), PauseMenuInputCommandRouter.COMMAND_CLOSE_OPTIONS, "sound back click")


func _verify_display_clicks(router: Object) -> void:
	var panel := PauseMenuOverlayLayout.get_options_panel_rect(VIEW_SIZE)
	var mode_command: Dictionary = router.route_display_click(PauseMenuOverlayLayout.get_display_exclusive_fullscreen_rect(panel).get_center(), panel)
	_expect_command(mode_command, PauseMenuPointerCommandRouter.COMMAND_SET_DISPLAY_MODE, "exclusive display click")
	_expect(str(mode_command.get("mode", "")) == "exclusive_fullscreen" and int(mode_command.get("focus", -1)) == 0, "display mode command should carry canonical mode and focus")
	var fps_chevrons := PauseMenuOptionsRenderer.get_select_chevron_rects(PauseMenuOverlayLayout.get_display_fps_cap_value_rect(panel))
	var fps_left: Rect2 = fps_chevrons.get("left", Rect2())
	var fps_command: Dictionary = router.route_display_click(fps_left.get_center(), panel)
	_expect_direction(fps_command, PauseMenuInputCommandRouter.COMMAND_ADJUST_DISPLAY, -1, "FPS left chevron")
	_expect(int(fps_command.get("focus", -1)) == 1, "FPS chevron should focus the FPS row")
	var fps_row_command: Dictionary = router.route_display_click(PauseMenuOverlayLayout.get_display_fps_cap_row_rect(panel).get_center(), panel)
	_expect_command(fps_row_command, PauseMenuInputCommandRouter.COMMAND_ADJUST_DISPLAY, "FPS row label click")
	_expect(int(fps_row_command.get("direction", 99)) == 0, "FPS row label click should focus without cycling")
	_expect_command(router.route_display_click(PauseMenuOverlayLayout.get_display_default_row_rect(panel).get_center(), panel), PauseMenuPointerCommandRouter.COMMAND_TOGGLE_DISPLAY_DEFAULT, "remember display click")
	_expect_command(router.route_display_click(PauseMenuOverlayLayout.get_display_auto_refresh_row_rect(panel).get_center(), panel), PauseMenuPointerCommandRouter.COMMAND_TOGGLE_AUTO_REFRESH, "auto refresh click")
	_expect_command(router.route_display_click(PauseMenuOverlayLayout.get_display_recommended_button_rect(panel).get_center(), panel), PauseMenuPointerCommandRouter.COMMAND_APPLY_RECOMMENDED, "recommended click")
	_expect_command(router.route_display_click(PauseMenuOverlayLayout.get_display_apply_60hz_button_rect(panel).get_center(), panel), PauseMenuPointerCommandRouter.COMMAND_APPLY_60HZ, "60Hz click")
	_expect_command(router.route_display_click(PauseMenuOverlayLayout.get_display_save_button_rect(panel).get_center(), panel), PauseMenuPointerCommandRouter.COMMAND_SAVE_DISPLAY, "display save click")
	_expect_command(router.route_display_click(PauseMenuOverlayLayout.get_display_back_button_rect(panel).get_center(), panel), PauseMenuInputCommandRouter.COMMAND_CLOSE_OPTIONS, "display back click")


func _verify_controls_and_language_clicks(router: Object) -> void:
	var panel := PauseMenuOverlayLayout.get_options_panel_rect(VIEW_SIZE)
	var joypad_command: Dictionary = router.route_controls_click(PauseMenuOverlayLayout.get_controls_joypad_rect(panel).get_center(), panel, PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE)
	_expect_command(joypad_command, PauseMenuPointerCommandRouter.COMMAND_SELECT_CONTROL_DEVICE, "joypad tab click")
	_expect(str(joypad_command.get("device", "")) == PauseMenuOptionsNavigationPolicy.DEVICE_JOYPAD, "joypad click should carry joypad device")
	var vibration_chevrons := PauseMenuOptionsRenderer.get_select_chevron_rects(PauseMenuOverlayLayout.get_controls_vibration_value_rect(panel))
	var vibration_right: Rect2 = vibration_chevrons.get("right", Rect2())
	var vibration_command: Dictionary = router.route_controls_click(vibration_right.get_center(), panel, PauseMenuOptionsNavigationPolicy.DEVICE_JOYPAD)
	_expect_direction(vibration_command, PauseMenuInputCommandRouter.COMMAND_ADJUST_CONTROLS, 1, "vibration right chevron")
	_expect(int(vibration_command.get("focus", -1)) == 1, "vibration click should focus vibration row")
	var language_command: Dictionary = router.route_language_click(PauseMenuOverlayLayout.get_language_russian_rect(panel).get_center(), panel)
	_expect_command(language_command, PauseMenuPointerCommandRouter.COMMAND_SET_LANGUAGE, "Russian language click")
	_expect(str(language_command.get("language", "")) == LanguageSettings.LANGUAGE_RUSSIAN and int(language_command.get("focus", -1)) == 6, "Russian click should carry language and focus")
	_expect_command(router.route_language_click(PauseMenuOverlayLayout.get_language_back_button_rect(panel).get_center(), panel), PauseMenuInputCommandRouter.COMMAND_CLOSE_OPTIONS, "language back click")


func _verify_motion(router: Object) -> void:
	_expect_command(router.route_motion(true, "bgm", 420.0), PauseMenuPointerCommandRouter.COMMAND_DRAG_SLIDER, "active slider motion")
	_expect_command(router.route_motion(false, "bgm", 420.0), PauseMenuInputCommandRouter.COMMAND_NONE, "inactive overlay motion")
	_expect_command(router.route_motion(true, "", 420.0), PauseMenuInputCommandRouter.COMMAND_NONE, "non-drag motion")


func _verify_overlay_ownership() -> void:
	var overlay_source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_overlay.gd")
	var router_source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_pointer_command_router.gd")
	_expect(overlay_source.find("PauseMenuPointerCommandRouter") >= 0, "overlay should preload the pointer command router")
	_expect(overlay_source.find("_pointer_command_router.route_button(") >= 0, "mouse button input should delegate to the pointer router")
	_expect(overlay_source.find("_pointer_command_router.route_motion(") >= 0, "mouse motion should delegate drag interpretation")
	_expect(router_source.find("PauseMenuOverlayLayout") >= 0, "pointer router should consume the shared layout owner")
	_expect(router_source.find("PauseMenuOptionsRenderer.get_select_chevron_rects") >= 0, "pointer router should reuse the rendered chevron hit geometry")
	_expect(router_source.find("play_ui_") == -1, "pure pointer router must not play UI audio")
	_expect(router_source.find("set_language(") == -1, "pure pointer router must not mutate language settings")


func _mouse(button: MouseButton, position: Vector2, pressed: bool = true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.pressed = pressed
	event.button_index = button
	event.position = position
	return event


func _expect_command(command: Dictionary, expected: StringName, label: String) -> void:
	_expect(StringName(command.get("command", &"")) == expected, "%s should route to %s" % [label, expected])


func _expect_direction(command: Dictionary, expected: StringName, direction: int, label: String) -> void:
	_expect_command(command, expected, label)
	_expect(int(command.get("direction", 0)) == direction, "%s should carry direction %d" % [label, direction])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
