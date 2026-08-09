extends SceneTree

const GamepadVibrationSettings := preload("res://scripts/core/gamepad_vibration_settings.gd")
const PauseMenuControlsSettingsController := preload("res://scripts/hud/pause_menu_controls_settings_controller.gd")
const PauseMenuOptionsNavigationPolicy := preload("res://scripts/hud/pause_menu_options_navigation_policy.gd")

var _failures: Array[String] = []


func _init() -> void:
	var saved_level := GamepadVibrationSettings.get_vibration_level()
	_verify_controller_behavior()
	_verify_facade_ownership()
	GamepadVibrationSettings.set_vibration_level(saved_level)
	if _failures.is_empty():
		print("pause_menu_controls_settings_controller_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_controller_behavior() -> void:
	GamepadVibrationSettings.set_vibration_level(3)
	var controller := PauseMenuControlsSettingsController.new()
	_expect(controller.sync() == 3, "sync should read the saved vibration level")
	_expect(controller.vibration_level == 3, "sync should retain the saved vibration level")
	_expect(controller.adjust(1) == 4, "positive adjustment should raise vibration")
	_expect(GamepadVibrationSettings.get_vibration_level() == 4, "adjustment should persist vibration")
	_expect(controller.adjust(-2) == 2, "adjustment should preserve the requested delta")
	_expect(controller.adjust(0) == 2, "zero adjustment should be a no-op")
	controller.vibration_level = GamepadVibrationSettings.VIBRATION_LEVEL_MAX
	_expect(controller.adjust(1) == GamepadVibrationSettings.VIBRATION_LEVEL_MAX, "adjustment should clamp at the maximum")
	_expect(controller.reset() == GamepadVibrationSettings.VIBRATION_LEVEL_DEFAULT, "reset should restore the default")
	_expect(GamepadVibrationSettings.get_vibration_level() == GamepadVibrationSettings.VIBRATION_LEVEL_DEFAULT, "reset should persist the default")
	_expect(controller.get_vibration_level_label(3).begins_with("3 / 5 "), "label should include the normalized level range")

	var keyboard_rows: Array = controller.get_control_mapping_rows(PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE)
	var joypad_rows: Array = controller.get_control_mapping_rows(PauseMenuOptionsNavigationPolicy.DEVICE_JOYPAD)
	_expect(keyboard_rows.size() == 6, "keyboard mapping should expose six rows")
	_expect(joypad_rows.size() == 6, "joypad mapping should expose six rows")
	_expect(not str(keyboard_rows[0].get("label", "")).is_empty(), "mapping rows should expose localized labels")
	_expect(str(keyboard_rows[0].get("value", "")) != str(joypad_rows[0].get("value", "")), "device mappings should project different values")


func _verify_facade_ownership() -> void:
	var overlay_source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_overlay.gd")
	_expect(overlay_source.find("PauseMenuControlsSettingsController") >= 0, "overlay should preload the controls settings controller")
	for delegation in [
		"_controls_settings_controller.sync()",
		"_controls_settings_controller.adjust(direction)",
		"_controls_settings_controller.reset()",
		"_controls_settings_controller.get_vibration_level_label(level)",
		"_controls_settings_controller.get_control_mapping_rows(controls_device_view)",
	]:
		_expect(overlay_source.find(delegation) >= 0, "overlay should delegate controls operation: %s" % delegation)
	_expect(overlay_source.find("GamepadVibrationSettings.") == -1, "overlay should not call the vibration settings singleton directly")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
