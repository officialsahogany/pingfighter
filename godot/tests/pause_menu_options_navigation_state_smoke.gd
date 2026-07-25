extends SceneTree

const PauseMenuOptionsNavigationPolicy := preload("res://scripts/hud/pause_menu_options_navigation_policy.gd")
const PauseMenuOptionsNavigationState := preload("res://scripts/hud/pause_menu_options_navigation_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_overlay_navigation_owner_contract()
	var state := PauseMenuOptionsNavigationState.new()
	_expect(state.options_tab == PauseMenuOptionsNavigationPolicy.TAB_SOUND, "navigation should start on the sound tab")
	_expect(state.options_focus == 0, "navigation should start at the first row")
	state.options_focus = 2
	_expect(state.cycle_tab(1), "tab cycle should report a changed tab")
	_expect(state.options_tab == PauseMenuOptionsNavigationPolicy.TAB_DISPLAY, "forward tab cycle should select display")
	_expect(state.options_focus == 0, "tab change should reset focus atomically")
	_expect(state.move_focus(-1, PauseMenuOptionsNavigationPolicy.DISPLAY_FOCUS_COUNT), "focus move should report a changed row")
	_expect(state.options_focus == PauseMenuOptionsNavigationPolicy.DISPLAY_FOCUS_COUNT - 1, "focus should wrap backward")
	state.options_tab = PauseMenuOptionsNavigationPolicy.TAB_CONTROLS
	state.options_focus = 2
	_expect(state.cycle_controls_device(1), "device cycle should report a changed view")
	_expect(state.controls_device_view == PauseMenuOptionsNavigationPolicy.DEVICE_JOYPAD, "device cycle should select joypad")
	_expect(state.options_focus == 2, "joypad view should preserve its valid back-row focus")
	_expect(state.get_feedback_scope() == "options:controls:joypad", "controls feedback scope should include the device")
	_expect(state.cycle_controls_device(1), "second device cycle should return to keyboard")
	_expect(state.options_focus == 1, "keyboard view should clamp the removed joypad row")
	state.reset()
	_expect(state.options_tab == PauseMenuOptionsNavigationPolicy.TAB_SOUND, "reset should restore sound tab")
	_expect(state.controls_device_view == PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE, "reset should restore keyboard view")

	if _failures.is_empty():
		print("pause_menu_options_navigation_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_overlay_navigation_owner_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_overlay.gd")
	for delegation in [
		"_options_navigation_state.reset()",
		"_options_navigation_state.select_tab(tab)",
		"_options_navigation_state.move_focus(delta, focus_count)",
		"_options_navigation_state.cycle_controls_device(direction)",
		"_options_navigation_state.get_feedback_scope()",
		"PauseMenuOptionsNavigationPolicy.get_feedback_count(scope",
	]:
		_expect(source.find(delegation) >= 0, "overlay should delegate options navigation: %s" % delegation)
	_expect(source.find("var tabs: Array[String] = [OPTIONS_TAB_SOUND") == -1, "overlay should not retain its own settings-tab cycle")
	_expect(source.find("var views: Array[String] = [CONTROL_DEVICE_KEYBOARD_MOUSE") == -1, "overlay should not retain its own control-device cycle")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
