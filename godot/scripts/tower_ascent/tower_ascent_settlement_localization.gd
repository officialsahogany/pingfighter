extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const KEY_CLEAR_TITLE := "tower_ascent.settlement.clear.title"
const KEY_CLEAR_BODY := "tower_ascent.settlement.clear.body"
const KEY_DEFEAT_TITLE := "tower_ascent.settlement.defeat.title"
const KEY_DEFEAT_BODY := "tower_ascent.settlement.defeat.body"
const KEY_TRUE_ENDING_TITLE := "tower_ascent.settlement.true_ending.title"
const KEY_TRUE_ENDING_BODY := "tower_ascent.settlement.true_ending.body"
const KEY_LOST_BUILD_TITLE := "tower_ascent.settlement.lost_build.title"
const KEY_PERSISTENT_INCOME_TITLE := "tower_ascent.settlement.persistent_income.title"
const KEY_EMPTY_BUILD := "tower_ascent.settlement.lost_build.empty"
const KEY_LOST_BUILD_CURRENCY_ROW := "tower_ascent.settlement.lost_build.currency_row"
const KEY_NO_NEW_DISCOVERY := "tower_ascent.settlement.persistent_income.no_discovery"
const KEY_PROMPT := "tower_ascent.settlement.prompt"

const TEXT_BY_LOCALE := {
	LanguageSettings.LANGUAGE_KOREAN: {
		KEY_CLEAR_TITLE: "등정 완료",
		KEY_CLEAR_BODY: "왕의 시련에서 얻은 기록을 정리합니다.",
		KEY_DEFEAT_TITLE: "등정 종료",
		KEY_DEFEAT_BODY: "런의 힘은 놓고 가지만, 등정의 흔적은 남습니다.",
		KEY_TRUE_ENDING_TITLE: "왕의 시련 완수",
		KEY_TRUE_ENDING_BODY: "승천탑의 마지막 시련을 넘어 진엔딩 기록을 남겼습니다.",
		KEY_LOST_BUILD_TITLE: "이번 런에서 놓고 가는 것",
		KEY_PERSISTENT_INCOME_TITLE: "이번 런이 남긴 것",
		KEY_EMPTY_BUILD: "기록된 런 빌드 없음",
		KEY_LOST_BUILD_CURRENCY_ROW: "무혼 {muhon} · 금화 {gold}",
		KEY_NO_NEW_DISCOVERY: "새 도감 발견 없음",
		KEY_PROMPT: "확인하여 등정을 마칩니다.",
	},
	LanguageSettings.LANGUAGE_ENGLISH: {
		KEY_LOST_BUILD_CURRENCY_ROW: "Muhon {muhon} · Gold {gold}",
	},
	LanguageSettings.LANGUAGE_CHINESE: {
		KEY_LOST_BUILD_CURRENCY_ROW: "武魂 {muhon} · 金币 {gold}",
	},
	LanguageSettings.LANGUAGE_JAPANESE: {
		KEY_LOST_BUILD_CURRENCY_ROW: "武魂 {muhon} · 金貨 {gold}",
	},
	LanguageSettings.LANGUAGE_SPANISH: {
		KEY_LOST_BUILD_CURRENCY_ROW: "Muhon {muhon} · Oro {gold}",
	},
	LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: {
		KEY_LOST_BUILD_CURRENCY_ROW: "Muhon {muhon} · Ouro {gold}",
	},
	LanguageSettings.LANGUAGE_RUSSIAN: {
		KEY_LOST_BUILD_CURRENCY_ROW: "Мухон {muhon} · Золото {gold}",
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
	var registered_keys := get_registered_keys()
	for locale in LanguageSettings.SUPPORTED_LANGUAGES:
		if locale == LanguageSettings.LANGUAGE_KOREAN:
			continue
		var locale_text: Dictionary = TEXT_BY_LOCALE.get(locale, {})
		for key in registered_keys:
			if not locale_text.has(key):
				result.append(locale)
				break
	return result
