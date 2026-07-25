extends SceneTree

const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const LocalePolicy := preload("res://scripts/core/language_settings_locale_policy.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_supported_languages_and_native_names()
	_verify_locale_map_routing()
	_verify_fallback_policy()
	if _failures.is_empty():
		print("language_settings_locale_policy_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_supported_languages_and_native_names() -> void:
	var options := LocalePolicy.get_language_options()
	_expect(options == ["ko", "en", "zh", "ja", "es", "pt-BR", "ru"], "locale options should preserve the shipped UI order")
	options.clear()
	_expect(LocalePolicy.SUPPORTED_LANGUAGES.size() == 7, "returned options should not mutate the policy constant")
	for language in LocalePolicy.SUPPORTED_LANGUAGES:
		_expect(LocalePolicy.get_native_language_name(language) == str(LanguageSettingsData.LANGUAGE_NATIVE_NAMES.get(language, language)), "native name should route through language data for %s" % language)


func _verify_locale_map_routing() -> void:
	_expect(LocalePolicy.get_exact_text_map("ru") == LanguageSettingsData.EXACT_TEXT_RU, "Russian exact text should use the Russian map")
	_expect(LocalePolicy.get_exact_text_map("pt-BR") == LanguageSettingsData.EXACT_TEXT_PT_BR, "Brazilian Portuguese exact text should use its override-aware map")
	_expect(LocalePolicy.get_item_display_map("zh") == LanguageSettingsData.ITEM_DISPLAY_ZH, "Chinese item names should use the Chinese map")
	_expect(LocalePolicy.get_mythic_description_map("ja") == LanguageSettingsData.MYTHIC_DESCRIPTION_JA, "Japanese mythic descriptions should use the Japanese map")
	_expect(LocalePolicy.get_perk_name_map("es") == LanguageSettingsData.PERK_NAME_ES, "Spanish perk names should use the Spanish map")
	_expect(LocalePolicy.get_perk_summary_map("ru") == LanguageSettingsData.PERK_SUMMARY_RU, "Russian perk summaries should use the Russian map")
	_expect(LocalePolicy.get_character_map("pt-BR") == LanguageSettingsData.CHARACTER_PT_BR, "Brazilian Portuguese character copy should use its locale map")
	_expect(LocalePolicy.get_quality_prefix_map("zh") == LanguageSettingsData.QUALITY_PREFIXES_ZH, "Chinese quality prefixes should use the Chinese map")
	_expect(LocalePolicy.get_active_item_description_map("ko").is_empty(), "Korean active items should retain authored source descriptions")
	_expect(LocalePolicy.get_active_item_description_map("es") == LanguageSettingsData.ACTIVE_ITEM_DESCRIPTION_EN, "non-Korean active item descriptions should retain the English fallback policy")


func _verify_fallback_policy() -> void:
	_expect(LocalePolicy.get_exact_text_map("unknown") == LanguageSettingsData.EXACT_TEXT_EN, "unknown exact-text locale should fall back to English")
	_expect(LocalePolicy.get_item_display_map("unknown") == LanguageSettingsData.ITEM_DISPLAY_EN, "unknown item locale should fall back to English")
	_expect(LocalePolicy.get_perk_name_map("ko") == LanguageSettingsData.PERK_NAME_EN, "Korean source perk names should not require a translated map")
	_expect(LocalePolicy.get_character_map("unknown") == LanguageSettingsData.CHARACTER_EN, "unknown character locale should fall back to English")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
