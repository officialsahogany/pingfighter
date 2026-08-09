extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const FOCUS_LANGUAGES: Array[String] = [
	LanguageSettings.LANGUAGE_KOREAN,
	LanguageSettings.LANGUAGE_ENGLISH,
	LanguageSettings.LANGUAGE_CHINESE,
	LanguageSettings.LANGUAGE_JAPANESE,
	LanguageSettings.LANGUAGE_SPANISH,
	LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL,
	LanguageSettings.LANGUAGE_RUSSIAN,
]

var language_code := LanguageSettings.DEFAULT_LANGUAGE


static func get_language_for_focus(focus: int) -> String:
	if focus < 0 or focus >= FOCUS_LANGUAGES.size():
		return ""
	return FOCUS_LANGUAGES[focus]


func sync() -> String:
	language_code = LanguageSettings.get_language()
	return language_code


func cycle(direction: int, owner: Object = null) -> String:
	if direction == 0:
		return language_code
	var options := LanguageSettings.get_language_options()
	var index := options.find(language_code)
	if index < 0:
		index = 0
	var step := 1 if direction >= 0 else -1
	return set_language(options[(index + step + options.size()) % options.size()], owner)


func set_language(language: String, owner: Object = null) -> String:
	language_code = LanguageSettings.set_language(language)
	notify_language_changed(owner)
	return language_code


func select_focus(focus: int, owner: Object = null) -> bool:
	var language := get_language_for_focus(focus)
	if language.is_empty():
		return false
	set_language(language, owner)
	return true


func get_native_language_name() -> String:
	return LanguageSettings.get_native_language_name(language_code)


func notify_language_changed(owner: Object) -> void:
	if owner != null and owner.has_method("refresh_language_texts"):
		owner.refresh_language_texts()
