extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const KEY_TITLE := "tower_ascent.gauntlet.transition.title"
const KEY_BODY := "tower_ascent.gauntlet.transition.body"
const KEY_PRESERVE := "tower_ascent.gauntlet.transition.preserve"
const KEY_PROMPT := "tower_ascent.gauntlet.transition.prompt"

const TEXT_BY_LOCALE := {
	LanguageSettings.LANGUAGE_KOREAN: {
		KEY_TITLE: "4천왕 연전",
		KEY_BODY: "{completed}번째 대전을 마쳤습니다. 다음 대전은 {next}번째입니다.",
		KEY_PRESERVE: "회복과 중간 상자 없이, 현재 빌드와 전장 상태를 이어갑니다.",
		KEY_PROMPT: "확인하여 다음 대전을 준비합니다.",
	},
}


static func text(key: String, values: Dictionary = {}) -> String:
	var locale := LanguageSettings.get_language()
	var locale_text: Dictionary = TEXT_BY_LOCALE.get(locale, {})
	var fallback_text: Dictionary = TEXT_BY_LOCALE.get(LanguageSettings.LANGUAGE_KOREAN, {})
	return str(locale_text.get(key, fallback_text.get(key, key))).format(values)


static func get_registered_keys() -> Array[String]:
	var result: Array[String] = []
	var korean_text: Dictionary = TEXT_BY_LOCALE.get(LanguageSettings.LANGUAGE_KOREAN, {})
	for key_value in korean_text.keys():
		result.append(str(key_value))
	result.sort()
	return result


static func get_missing_translation_locales() -> Array[String]:
	var result: Array[String] = []
	for locale in LanguageSettings.SUPPORTED_LANGUAGES:
		if locale != LanguageSettings.LANGUAGE_KOREAN and not TEXT_BY_LOCALE.has(locale):
			result.append(locale)
	return result
