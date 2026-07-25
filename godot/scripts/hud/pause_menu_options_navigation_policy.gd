extends RefCounted

const TAB_SOUND := "sound"
const TAB_DISPLAY := "display"
const TAB_CONTROLS := "controls"
const TAB_LANGUAGE := "language"
const DEVICE_KEYBOARD_MOUSE := "keyboard_mouse"
const DEVICE_JOYPAD := "joypad"
const SCOPE_MAIN := "main"

const SOUND_FOCUS_COUNT := 3
const DISPLAY_FOCUS_COUNT := 9
const CONTROLS_BASE_FOCUS_COUNT := 2
const CONTROLS_JOYPAD_FOCUS_COUNT := 3
const LANGUAGE_FOCUS_COUNT := 8


static func get_tabs() -> Array[String]:
	return [TAB_SOUND, TAB_DISPLAY, TAB_CONTROLS, TAB_LANGUAGE]


static func cycle_tab(current_tab: String, direction: int) -> String:
	var tabs := get_tabs()
	var index := tabs.find(current_tab)
	if index < 0:
		index = 0
	var step := 1 if direction >= 0 else -1
	return tabs[(index + step + tabs.size()) % tabs.size()]


static func cycle_controls_device(current_device: String, direction: int) -> String:
	if direction == 0:
		return current_device
	var devices: Array[String] = [DEVICE_KEYBOARD_MOUSE, DEVICE_JOYPAD]
	var index := devices.find(current_device)
	if index < 0:
		index = 0
	var step := 1 if direction >= 0 else -1
	return devices[(index + step + devices.size()) % devices.size()]


static func get_controls_focus_count(device: String) -> int:
	return CONTROLS_JOYPAD_FOCUS_COUNT if device == DEVICE_JOYPAD else CONTROLS_BASE_FOCUS_COUNT


static func get_controls_back_focus_index(device: String) -> int:
	return 2 if device == DEVICE_JOYPAD else 1


static func clamp_controls_focus(focus: int, device: String) -> int:
	return clampi(focus, 0, get_controls_focus_count(device) - 1)


static func is_controls_vibration_focus(device: String, focus: int) -> bool:
	return device == DEVICE_JOYPAD and focus == 1


static func move_focus(current_focus: int, direction: int, focus_count: int) -> int:
	if focus_count <= 0:
		return current_focus
	return (current_focus + direction + focus_count) % focus_count


static func get_feedback_scope(tab: String, controls_device: String) -> String:
	if tab == TAB_CONTROLS:
		return "options:%s:%s" % [tab, controls_device]
	return "options:%s" % tab


static func get_feedback_count(scope: String, main_count: int) -> int:
	if scope == SCOPE_MAIN:
		return max(0, main_count)
	if not scope.begins_with("options:"):
		return 0
	var parts := scope.split(":")
	if parts.size() < 2:
		return 0
	match str(parts[1]):
		TAB_SOUND:
			return SOUND_FOCUS_COUNT
		TAB_DISPLAY:
			return DISPLAY_FOCUS_COUNT
		TAB_CONTROLS:
			return CONTROLS_JOYPAD_FOCUS_COUNT if parts.size() >= 3 and str(parts[2]) == DEVICE_JOYPAD else CONTROLS_BASE_FOCUS_COUNT
		TAB_LANGUAGE:
			return LANGUAGE_FOCUS_COUNT
	return 0
