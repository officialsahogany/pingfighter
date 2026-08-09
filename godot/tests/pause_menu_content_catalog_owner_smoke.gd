extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PauseMenuContentCatalog := preload("res://scripts/hud/pause_menu_content_catalog.gd")
const PauseMenuOptionsNavigationPolicy := preload("res://scripts/hud/pause_menu_options_navigation_policy.gd")

var _failures: Array[String] = []


func _init() -> void:
	var saved_language := LanguageSettings._cached_language
	LanguageSettings._cached_language = LanguageSettings.LANGUAGE_ENGLISH
	_verify_main_content()
	_verify_focus_descriptions()
	_verify_facade_ownership()
	LanguageSettings._cached_language = saved_language
	if _failures.is_empty():
		print("pause_menu_content_catalog_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_main_content() -> void:
	var entries: Array = PauseMenuContentCatalog.get_main_entries()
	_expect(entries.size() == 4, "catalog should expose four pause actions")
	_expect(str(entries[0].get("en", "")) == "RESUME", "first editorial label should remain RESUME")
	_expect(str(entries[0].get("label", "")) == LanguageSettings.translate("pause.continue"), "resume label should be localized")
	_expect(str(entries[0].get("action", "")) == PauseMenuContentCatalog.MENU_CONTINUE, "resume action should remain stable")
	_expect(str(entries[3].get("action", "")) == PauseMenuContentCatalog.MENU_EXIT_TO_MAIN, "exit action should remain stable")
	_expect(PauseMenuContentCatalog.get_options_back_label(false) == LanguageSettings.translate("settings.back"), "nested options should use the back label")
	_expect(PauseMenuContentCatalog.get_options_back_label(true) == LanguageSettings.translate("settings.close"), "options-only mode should use the close label")


func _verify_focus_descriptions() -> void:
	for focus in range(PauseMenuOptionsNavigationPolicy.SOUND_FOCUS_COUNT):
		_expect(not PauseMenuContentCatalog.get_focused_option_description(PauseMenuOptionsNavigationPolicy.TAB_SOUND, focus, PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE).is_empty(), "every sound focus should have a description")
	for focus in range(PauseMenuOptionsNavigationPolicy.DISPLAY_FOCUS_COUNT):
		_expect(not PauseMenuContentCatalog.get_focused_option_description(PauseMenuOptionsNavigationPolicy.TAB_DISPLAY, focus, PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE).is_empty(), "every display focus should have a description")
	_expect(
		PauseMenuContentCatalog.get_focused_option_description(PauseMenuOptionsNavigationPolicy.TAB_DISPLAY, 7, PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE)
		== LanguageSettings.translate("settings.desc.save"),
		"display focus 7 should retain the save description"
	)
	_expect(
		PauseMenuContentCatalog.get_focused_option_description(PauseMenuOptionsNavigationPolicy.TAB_DISPLAY, 8, PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE)
		== LanguageSettings.translate("settings.desc.display_back"),
		"display focus 8 should retain the back description"
	)
	_expect(
		PauseMenuContentCatalog.get_focused_option_description(PauseMenuOptionsNavigationPolicy.TAB_CONTROLS, 1, PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE)
		== LanguageSettings.translate("settings.desc.controls_back"),
		"keyboard focus 1 should be the controls back row"
	)
	_expect(
		PauseMenuContentCatalog.get_focused_option_description(PauseMenuOptionsNavigationPolicy.TAB_CONTROLS, 1, PauseMenuOptionsNavigationPolicy.DEVICE_JOYPAD)
		== LanguageSettings.translate("settings.desc.controls_vibration"),
		"joypad focus 1 should be the vibration row"
	)
	_expect(
		PauseMenuContentCatalog.get_focused_option_description(PauseMenuOptionsNavigationPolicy.TAB_LANGUAGE, PauseMenuOptionsNavigationPolicy.LANGUAGE_FOCUS_COUNT - 2, PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE)
		== LanguageSettings.translate("settings.desc.language"),
		"last language choice should retain the selection description"
	)
	_expect(
		PauseMenuContentCatalog.get_focused_option_description(PauseMenuOptionsNavigationPolicy.TAB_LANGUAGE, PauseMenuOptionsNavigationPolicy.LANGUAGE_FOCUS_COUNT - 1, PauseMenuOptionsNavigationPolicy.DEVICE_KEYBOARD_MOUSE)
		== LanguageSettings.translate("settings.desc.language_back"),
		"language back focus should retain the back description"
	)
	_expect(PauseMenuContentCatalog.get_focused_option_description("unknown", 0, "unknown").is_empty(), "unknown scopes should remain empty")


func _verify_facade_ownership() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/pause_menu_overlay.gd")
	_expect(source.find("PauseMenuContentCatalog") >= 0, "overlay should preload the content catalog")
	for delegation in [
		"PauseMenuContentCatalog.translate(key, fallback)",
		"PauseMenuContentCatalog.get_main_entries()",
		"PauseMenuContentCatalog.get_options_back_label(options_only)",
		"PauseMenuContentCatalog.get_focused_option_description(tab, focus, controls_device_view)",
	]:
		_expect(source.find(delegation) >= 0, "overlay should delegate content operation: %s" % delegation)
	_expect(source.find("settings.desc.bgm") == -1, "overlay should not retain the focused-description table")
	_expect(source.find("{\"en\": \"RESUME\"") == -1, "overlay should not retain the main-entry catalog")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
