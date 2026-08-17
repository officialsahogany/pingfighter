extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const KEY_TEASER_TITLE := "tower_ascent.ending.fake_teaser.title"
const KEY_TEASER_BODY := "tower_ascent.ending.fake_teaser.body"
const KEY_TEASER_PROMPT := "tower_ascent.ending.fake_teaser.prompt"
const KEY_CHOICE_TITLE := "tower_ascent.ending.choice.title"
const KEY_CHOICE_BODY := "tower_ascent.ending.choice.body"
const KEY_CHOICE_DESCEND := "tower_ascent.ending.choice.descend"
const KEY_CHOICE_CONTINUE := "tower_ascent.ending.choice.continue"
const KEY_CHOICE_PROMPT := "tower_ascent.ending.choice.prompt"

const TEXT_BY_LOCALE := {
	LanguageSettings.LANGUAGE_KOREAN: {
		KEY_TEASER_TITLE: "가짜 끝",
		KEY_TEASER_BODY: "왕의 시련은 아직 끝나지 않았다",
		KEY_TEASER_PROMPT: "확인하여 이번 등정을 마칩니다.",
		KEY_CHOICE_TITLE: "왕의 시련",
		KEY_CHOICE_BODY: "이번 등정을 마칠지, 더 높은 곳으로 나아갈지 선택하세요.",
		KEY_CHOICE_DESCEND: "하산한다",
		KEY_CHOICE_CONTINUE: "더 오른다",
		KEY_CHOICE_PROMPT: "더 오르기는 되돌릴 수 없습니다.",
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
