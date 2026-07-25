extends RefCounted

const PauseMenuOptionsNavigationPolicy := preload("res://scripts/hud/pause_menu_options_navigation_policy.gd")

var options_tab := PauseMenuOptionsNavigationPolicy.TAB_SOUND
var options_focus := 0
var controls_device_view := PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE


func reset() -> void:
	options_tab = PauseMenuOptionsNavigationPolicy.TAB_SOUND
	options_focus = 0
	controls_device_view = PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE


func select_tab(tab: String) -> bool:
	var previous_tab := options_tab
	options_tab = tab
	options_focus = 0
	return options_tab != previous_tab


func cycle_tab(direction: int) -> bool:
	return select_tab(PauseMenuOptionsNavigationPolicy.cycle_tab(options_tab, direction))


func move_focus(direction: int, focus_count: int) -> bool:
	var previous_focus := options_focus
	options_focus = PauseMenuOptionsNavigationPolicy.move_focus(options_focus, direction, focus_count)
	return options_focus != previous_focus


func cycle_controls_device(direction: int) -> bool:
	var previous_view := controls_device_view
	controls_device_view = PauseMenuOptionsNavigationPolicy.cycle_controls_device(controls_device_view, direction)
	options_focus = PauseMenuOptionsNavigationPolicy.clamp_controls_focus(options_focus, controls_device_view)
	return controls_device_view != previous_view


func clamp_controls_focus() -> bool:
	var previous_focus := options_focus
	options_focus = PauseMenuOptionsNavigationPolicy.clamp_controls_focus(options_focus, controls_device_view)
	return options_focus != previous_focus


func get_feedback_scope() -> String:
	return PauseMenuOptionsNavigationPolicy.get_feedback_scope(options_tab, controls_device_view)


func get_controls_focus_count() -> int:
	return PauseMenuOptionsNavigationPolicy.get_controls_focus_count(controls_device_view)


func get_controls_back_focus_index() -> int:
	return PauseMenuOptionsNavigationPolicy.get_controls_back_focus_index(controls_device_view)


func is_controls_vibration_focus() -> bool:
	return PauseMenuOptionsNavigationPolicy.is_controls_vibration_focus(controls_device_view, options_focus)
