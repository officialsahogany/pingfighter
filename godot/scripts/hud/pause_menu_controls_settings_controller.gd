extends RefCounted

const GamepadVibrationSettings := preload("res://scripts/core/gamepad_vibration_settings.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PauseMenuOptionsNavigationPolicy := preload("res://scripts/hud/pause_menu_options_navigation_policy.gd")

var vibration_level := GamepadVibrationSettings.VIBRATION_LEVEL_DEFAULT


func sync() -> int:
	vibration_level = GamepadVibrationSettings.get_vibration_level()
	return vibration_level


func adjust(delta: int) -> int:
	if delta == 0:
		return vibration_level
	vibration_level = GamepadVibrationSettings.set_vibration_level(vibration_level + delta)
	return vibration_level


func reset() -> int:
	vibration_level = GamepadVibrationSettings.set_vibration_level(
		GamepadVibrationSettings.VIBRATION_LEVEL_DEFAULT
	)
	return vibration_level


func get_vibration_level_label(level: int = 0) -> String:
	var normalized: int = (
		GamepadVibrationSettings.get_vibration_level()
		if level < GamepadVibrationSettings.VIBRATION_LEVEL_MIN
		else GamepadVibrationSettings.normalize_vibration_level(level)
	)
	var name := LanguageSettings.translate("vibration.%d" % normalized)
	return "%d / %d %s" % [normalized, GamepadVibrationSettings.VIBRATION_LEVEL_MAX, name]


func get_control_mapping_rows(device: String) -> Array:
	if device == PauseMenuOptionsNavigationPolicy.DEVICE_JOYPAD:
		return [
			{"label": _text("controls.map.move"), "value": _text("controls.value.joypad.move")},
			{"label": _text("controls.map.dash_skill"), "value": _text("controls.value.joypad.dash_skill")},
			{"label": _text("controls.map.active_item"), "value": _text("controls.value.joypad.active_item")},
			{"label": _text("controls.map.supply_hold"), "value": _text("controls.value.joypad.supply_hold")},
			{"label": _text("controls.map.weapon_switch"), "value": _text("controls.value.joypad.weapon_switch")},
			{"label": _text("controls.map.confirm_cancel_pause"), "value": _text("controls.value.joypad.confirm_cancel_pause")},
		]
	return [
		{"label": _text("controls.map.move"), "value": _text("controls.value.keyboard.move")},
		{"label": _text("controls.map.dash_skill"), "value": _text("controls.value.keyboard.dash_skill")},
		{"label": _text("controls.map.active_item"), "value": _text("controls.value.keyboard.active_item")},
		{"label": _text("controls.map.supply_hold"), "value": _text("controls.value.keyboard.supply_hold")},
		{"label": _text("controls.map.weapon_switch"), "value": _text("controls.value.keyboard.weapon_switch")},
		{"label": _text("controls.map.confirm_cancel_pause"), "value": _text("controls.value.keyboard.confirm_cancel_pause")},
	]


func _text(key: String) -> String:
	return LanguageSettings.translate(key)
