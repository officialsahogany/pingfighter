extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PauseMenuLanguageSettingsController := preload("res://scripts/hud/pause_menu_language_settings_controller.gd")

const TEST_SETTINGS_PATH := "user://pause_menu_language_settings_controller_owner_smoke.cfg"


class FakeOwner:
	var refresh_count := 0

	func refresh_language_texts() -> void:
		refresh_count += 1


var _failures: Array[String] = []


func _init() -> void:
	_prepare_test_settings()
	_verify_controller_behavior()
	_verify_focus_mapping()
	_verify_facade_ownership()
	_restore_real_settings()
	if _failures.is_empty():
		print("pause_menu_language_settings_controller_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _prepare_test_settings() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	LanguageSettings.set_test_settings_path_override(TEST_SETTINGS_PATH)
	LanguageSettings.reset_cache_for_tests()


func _restore_real_settings() -> void:
	LanguageSettings.set_test_settings_path_override("")
	LanguageSettings.reset_cache_for_tests()
	LanguageSettings.apply_saved_language()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))


func _verify_controller_behavior() -> void:
	var controller := PauseMenuLanguageSettingsController.new()
	var owner := FakeOwner.new()
	_expect(controller.sync() == LanguageSettings.DEFAULT_LANGUAGE, "sync should read the saved default language")
	_expect(controller.language_code == LanguageSettings.DEFAULT_LANGUAGE, "sync should retain the saved language")
	_expect(controller.set_language(LanguageSettings.LANGUAGE_ENGLISH, owner) == LanguageSettings.LANGUAGE_ENGLISH, "set should persist English")
	_expect(LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH, "set should update the shared language setting")
	_expect(owner.refresh_count == 1, "set should refresh owner language text")
	_expect(controller.cycle(1, owner) == LanguageSettings.LANGUAGE_CHINESE, "forward cycle should follow canonical language order")
	_expect(controller.cycle(-1, owner) == LanguageSettings.LANGUAGE_ENGLISH, "reverse cycle should follow canonical language order")
	controller.language_code = LanguageSettings.LANGUAGE_RUSSIAN
	_expect(controller.cycle(1, owner) == LanguageSettings.LANGUAGE_KOREAN, "forward cycle should wrap after Russian")
	var before_zero := controller.language_code
	_expect(controller.cycle(0, owner) == before_zero, "zero-direction cycle should be a no-op")
	_expect(owner.refresh_count == 4, "only persisted language changes should refresh owner text")
	_expect(not controller.get_native_language_name().is_empty(), "controller should expose the current native language name")


func _verify_focus_mapping() -> void:
	var expected: Array[String] = [
		LanguageSettings.LANGUAGE_KOREAN,
		LanguageSettings.LANGUAGE_ENGLISH,
		LanguageSettings.LANGUAGE_CHINESE,
		LanguageSettings.LANGUAGE_JAPANESE,
		LanguageSettings.LANGUAGE_SPANISH,
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL,
		LanguageSettings.LANGUAGE_RUSSIAN,
	]
	for index in range(expected.size()):
		_expect(PauseMenuLanguageSettingsController.get_language_for_focus(index) == expected[index], "focus %d should map to %s" % [index, expected[index]])
	_expect(PauseMenuLanguageSettingsController.get_language_for_focus(7).is_empty(), "back focus should not map to a language")
	var controller := PauseMenuLanguageSettingsController.new()
	var owner := FakeOwner.new()
	_expect(controller.select_focus(5, owner), "Portuguese focus should be selectable")
	_expect(controller.language_code == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL, "focus selection should persist Portuguese")
	var before_invalid := controller.language_code
	_expect(not controller.select_focus(7, owner), "back focus should not be treated as a language selection")
	_expect(controller.language_code == before_invalid, "invalid focus should preserve the current language")


func _verify_facade_ownership() -> void:
	var overlay_source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_overlay.gd")
	var pointer_source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_pointer_command_router.gd")
	var controller_source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_language_settings_controller.gd")
	_expect(overlay_source.find("PauseMenuLanguageSettingsController") >= 0, "overlay should preload the language controller")
	for delegation in [
		"_language_settings_controller.sync()",
		"_language_settings_controller.cycle(direction, owner)",
		"_language_settings_controller.set_language(language, owner)",
		"_language_settings_controller.select_focus(options_focus, owner)",
		"_language_settings_controller.notify_language_changed(owner)",
	]:
		_expect(overlay_source.find(delegation) >= 0, "overlay should delegate language operation: %s" % delegation)
	_expect(pointer_source.find("PauseMenuLanguageSettingsController.get_language_for_focus") >= 0, "pointer router should reuse the canonical focus-language mapping")
	_expect(controller_source.find("LanguageSettings.set_language") >= 0, "language controller should own persistence")
	_expect(controller_source.find("refresh_language_texts") >= 0, "language controller should own owner refresh notification")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
