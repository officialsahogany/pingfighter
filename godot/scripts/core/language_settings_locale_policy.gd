extends RefCounted

# Locale constants and language-map routing for LanguageSettings. Alias
# normalization, persistence, recursive localization, and pattern translation
# remain in the public facade to preserve non-ASCII alias handling in place.

const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")

const LANGUAGE_KOREAN := "ko"
const LANGUAGE_ENGLISH := "en"
const LANGUAGE_CHINESE := "zh"
const LANGUAGE_JAPANESE := "ja"
const LANGUAGE_SPANISH := "es"
const LANGUAGE_PORTUGUESE_BRAZIL := "pt-BR"
const LANGUAGE_RUSSIAN := "ru"
const DEFAULT_LANGUAGE := LANGUAGE_KOREAN
const SUPPORTED_LANGUAGES: Array[String] = [
	LANGUAGE_KOREAN,
	LANGUAGE_ENGLISH,
	LANGUAGE_CHINESE,
	LANGUAGE_JAPANESE,
	LANGUAGE_SPANISH,
	LANGUAGE_PORTUGUESE_BRAZIL,
	LANGUAGE_RUSSIAN,
]


static func get_language_options() -> Array[String]:
	return SUPPORTED_LANGUAGES.duplicate()


static func get_native_language_name(normalized_language: String) -> String:
	return str(LanguageSettingsData.LANGUAGE_NATIVE_NAMES.get(normalized_language, normalized_language))


static func get_exact_text_map(language: String) -> Dictionary:
	return _select(language, {
		LANGUAGE_RUSSIAN: LanguageSettingsData.EXACT_TEXT_RU,
		LANGUAGE_PORTUGUESE_BRAZIL: LanguageSettingsData.EXACT_TEXT_PT_BR,
		LANGUAGE_SPANISH: LanguageSettingsData.EXACT_TEXT_ES,
		LANGUAGE_CHINESE: LanguageSettingsData.EXACT_TEXT_ZH,
		LANGUAGE_JAPANESE: LanguageSettingsData.EXACT_TEXT_JA,
	}, LanguageSettingsData.EXACT_TEXT_EN)


static func get_item_display_map(language: String) -> Dictionary:
	return _select(language, {
		LANGUAGE_RUSSIAN: LanguageSettingsData.ITEM_DISPLAY_RU,
		LANGUAGE_PORTUGUESE_BRAZIL: LanguageSettingsData.ITEM_DISPLAY_PT_BR,
		LANGUAGE_SPANISH: LanguageSettingsData.ITEM_DISPLAY_ES,
		LANGUAGE_JAPANESE: LanguageSettingsData.ITEM_DISPLAY_JA,
		LANGUAGE_CHINESE: LanguageSettingsData.ITEM_DISPLAY_ZH,
	}, LanguageSettingsData.ITEM_DISPLAY_EN)


static func get_active_item_description_map(language: String) -> Dictionary:
	return {} if language == LANGUAGE_KOREAN else LanguageSettingsData.ACTIVE_ITEM_DESCRIPTION_EN


static func get_mythic_description_map(language: String) -> Dictionary:
	return _select(language, {
		LANGUAGE_RUSSIAN: LanguageSettingsData.MYTHIC_DESCRIPTION_RU,
		LANGUAGE_PORTUGUESE_BRAZIL: LanguageSettingsData.MYTHIC_DESCRIPTION_PT_BR,
		LANGUAGE_SPANISH: LanguageSettingsData.MYTHIC_DESCRIPTION_ES,
		LANGUAGE_JAPANESE: LanguageSettingsData.MYTHIC_DESCRIPTION_JA,
		LANGUAGE_CHINESE: LanguageSettingsData.MYTHIC_DESCRIPTION_ZH,
	}, LanguageSettingsData.MYTHIC_DESCRIPTION_EN)


static func get_perk_name_map(language: String) -> Dictionary:
	return _select(language, {
		LANGUAGE_RUSSIAN: LanguageSettingsData.PERK_NAME_RU,
		LANGUAGE_PORTUGUESE_BRAZIL: LanguageSettingsData.PERK_NAME_PT_BR,
		LANGUAGE_SPANISH: LanguageSettingsData.PERK_NAME_ES,
		LANGUAGE_CHINESE: LanguageSettingsData.PERK_NAME_ZH,
		LANGUAGE_JAPANESE: LanguageSettingsData.PERK_NAME_JA,
	}, LanguageSettingsData.PERK_NAME_EN)


static func get_perk_summary_map(language: String) -> Dictionary:
	return _select(language, {
		LANGUAGE_RUSSIAN: LanguageSettingsData.PERK_SUMMARY_RU,
		LANGUAGE_PORTUGUESE_BRAZIL: LanguageSettingsData.PERK_SUMMARY_PT_BR,
		LANGUAGE_SPANISH: LanguageSettingsData.PERK_SUMMARY_ES,
		LANGUAGE_CHINESE: LanguageSettingsData.PERK_SUMMARY_ZH,
		LANGUAGE_JAPANESE: LanguageSettingsData.PERK_SUMMARY_JA,
	}, LanguageSettingsData.PERK_SUMMARY_EN)


static func get_character_map(language: String) -> Dictionary:
	return _select(language, {
		LANGUAGE_RUSSIAN: LanguageSettingsData.CHARACTER_RU,
		LANGUAGE_PORTUGUESE_BRAZIL: LanguageSettingsData.CHARACTER_PT_BR,
		LANGUAGE_SPANISH: LanguageSettingsData.CHARACTER_ES,
		LANGUAGE_CHINESE: LanguageSettingsData.CHARACTER_ZH,
		LANGUAGE_JAPANESE: LanguageSettingsData.CHARACTER_JA,
	}, LanguageSettingsData.CHARACTER_EN)


static func get_quality_prefix_map(language: String) -> Dictionary:
	return _select(language, {
		LANGUAGE_RUSSIAN: LanguageSettingsData.QUALITY_PREFIXES_RU,
		LANGUAGE_PORTUGUESE_BRAZIL: LanguageSettingsData.QUALITY_PREFIXES_PT_BR,
		LANGUAGE_SPANISH: LanguageSettingsData.QUALITY_PREFIXES_ES,
		LANGUAGE_CHINESE: LanguageSettingsData.QUALITY_PREFIXES_ZH,
		LANGUAGE_JAPANESE: LanguageSettingsData.QUALITY_PREFIXES_JA,
	}, LanguageSettingsData.QUALITY_PREFIXES_EN)


static func _select(language: String, localized_maps: Dictionary, fallback: Dictionary) -> Dictionary:
	var selected: Variant = localized_maps.get(language, fallback)
	return selected if selected is Dictionary else fallback
