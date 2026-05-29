extends SceneTree

const CharacterSelectData := preload("res://scripts/ui/character_select_data.gd")
const CharacterSelectScreen := preload("res://scripts/ui/character_select_screen.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []
var _language_settings_snapshot: Dictionary = {}


func _init() -> void:
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)

	var screen: Control = CharacterSelectScreen.new()
	screen.characters = LanguageSettings.localize_character_list(CharacterSelectData.get_characters())
	screen.visible_indices = []
	screen.selected_index = 2
	screen.call("_refresh_visible_indices")

	var selected_character_id := _selected_character_id(screen)
	_expect(selected_character_id != "", "test should start with a selected character id")

	screen.call("_cycle_language")
	_expect(LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH, "language button should cycle Korean to English")
	_expect(_selected_character_id(screen) == selected_character_id, "language refresh should preserve the selected character")
	_expect(screen.call("_language_code_label", LanguageSettings.get_language()) == "EN", "language button should expose the English code")

	screen.call("_apply_language", LanguageSettings.LANGUAGE_CHINESE)
	_expect(LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE, "language button path should apply requested language")
	_expect(_selected_character_id(screen) == selected_character_id, "direct language apply should preserve the selected character")
	_expect(screen.call("_language_code_label", LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL) == "PT-BR", "language code label should keep pt-BR readable")

	var rect_value: Variant = screen.call("_language_button_rect", Vector2(1920.0, 1080.0))
	var column_value: Variant = screen.call("_card_column_rect", Vector2(1920.0, 1080.0))
	var language_rect: Rect2 = rect_value if rect_value is Rect2 else Rect2()
	var column_rect: Rect2 = column_value if column_value is Rect2 else Rect2()
	_expect(language_rect.position.x >= column_rect.position.x, "language button should start inside the desktop card column")
	_expect(language_rect.end.x <= column_rect.end.x, "language button should end inside the desktop card column")
	_expect(language_rect.end.y <= column_rect.end.y, "language button should stay under the desktop card list")

	screen.free()
	_restore_language_settings_snapshot()

	if _failures.is_empty():
		print("character_select_language_button_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _selected_character_id(screen: Control) -> String:
	var characters_value: Variant = screen.get("characters")
	var selected_index_value: Variant = screen.get("selected_index")
	var characters: Array = characters_value if characters_value is Array else []
	var index := int(selected_index_value)
	if index < 0 or index >= characters.size():
		return ""
	var character_value: Variant = characters[index]
	if character_value is Dictionary:
		return str((character_value as Dictionary).get("id", ""))
	return ""


func _snapshot_settings_file(path: String) -> Dictionary:
	var had_original := FileAccess.file_exists(path)
	var original_bytes := PackedByteArray()
	if had_original:
		original_bytes = FileAccess.get_file_as_bytes(path)
	return {
		"had": had_original,
		"bytes": original_bytes,
	}


func _restore_language_settings_snapshot() -> void:
	if _language_settings_snapshot.is_empty():
		return
	if bool(_language_settings_snapshot.get("had", false)):
		var file := FileAccess.open(LanguageSettings.SETTINGS_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_language_settings_snapshot.get("bytes", PackedByteArray()))
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LanguageSettings.SETTINGS_PATH))
	LanguageSettings.reset_cache_for_tests()
	LanguageSettings.apply_saved_language()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
