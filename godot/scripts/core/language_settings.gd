extends RefCounted

const SETTINGS_PATH := "user://language_settings.cfg"
const SETTINGS_SCHEMA_VERSION := 1
const SETTINGS_SECTION := "language"
const SETTINGS_SCHEMA_KEY := "schema_version"
const SETTINGS_LANGUAGE_KEY := "locale"

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

const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const LANGUAGE_NATIVE_NAMES := LanguageSettingsData.LANGUAGE_NATIVE_NAMES
const ITEM_DISPLAY_EN := LanguageSettingsData.ITEM_DISPLAY_EN
const ITEM_DISPLAY_ZH := LanguageSettingsData.ITEM_DISPLAY_ZH
const ITEM_DISPLAY_JA := LanguageSettingsData.ITEM_DISPLAY_JA
const ITEM_DISPLAY_ES := LanguageSettingsData.ITEM_DISPLAY_ES
const ITEM_DISPLAY_PT_BR := LanguageSettingsData.ITEM_DISPLAY_PT_BR
const ITEM_DISPLAY_RU := LanguageSettingsData.ITEM_DISPLAY_RU
const ACTIVE_ITEM_DESCRIPTION_EN := LanguageSettingsData.ACTIVE_ITEM_DESCRIPTION_EN
const MYTHIC_DESCRIPTION_EN := LanguageSettingsData.MYTHIC_DESCRIPTION_EN
const MYTHIC_DESCRIPTION_ZH := LanguageSettingsData.MYTHIC_DESCRIPTION_ZH
const MYTHIC_DESCRIPTION_JA := LanguageSettingsData.MYTHIC_DESCRIPTION_JA
const MYTHIC_DESCRIPTION_ES := LanguageSettingsData.MYTHIC_DESCRIPTION_ES
const MYTHIC_DESCRIPTION_PT_BR := LanguageSettingsData.MYTHIC_DESCRIPTION_PT_BR
const MYTHIC_DESCRIPTION_RU := LanguageSettingsData.MYTHIC_DESCRIPTION_RU
const PERK_NAME_EN := LanguageSettingsData.PERK_NAME_EN
const PERK_NAME_ZH := LanguageSettingsData.PERK_NAME_ZH
const PERK_NAME_JA := LanguageSettingsData.PERK_NAME_JA
const PERK_NAME_ES := LanguageSettingsData.PERK_NAME_ES
const PERK_NAME_PT_BR := LanguageSettingsData.PERK_NAME_PT_BR
const PERK_NAME_RU := LanguageSettingsData.PERK_NAME_RU
const PERK_SUMMARY_EN := LanguageSettingsData.PERK_SUMMARY_EN
const PERK_SUMMARY_ZH := LanguageSettingsData.PERK_SUMMARY_ZH
const PERK_SUMMARY_JA := LanguageSettingsData.PERK_SUMMARY_JA
const PERK_SUMMARY_ES := LanguageSettingsData.PERK_SUMMARY_ES
const PERK_SUMMARY_PT_BR := LanguageSettingsData.PERK_SUMMARY_PT_BR
const PERK_SUMMARY_RU := LanguageSettingsData.PERK_SUMMARY_RU
const PERK_LOCALIZATION_ALIASES := LanguageSettingsData.PERK_LOCALIZATION_ALIASES
const CHARACTER_EN := LanguageSettingsData.CHARACTER_EN
const CHARACTER_ZH := LanguageSettingsData.CHARACTER_ZH
const CHARACTER_JA := LanguageSettingsData.CHARACTER_JA
const CHARACTER_ES := LanguageSettingsData.CHARACTER_ES
const CHARACTER_PT_BR := LanguageSettingsData.CHARACTER_PT_BR
const CHARACTER_RU := LanguageSettingsData.CHARACTER_RU
const SKILL_DATA_ZH := LanguageSettingsData.SKILL_DATA_ZH
const SKILL_DATA_JA := LanguageSettingsData.SKILL_DATA_JA
const SKILL_DATA_ES := LanguageSettingsData.SKILL_DATA_ES
const SKILL_DATA_PT_BR := LanguageSettingsData.SKILL_DATA_PT_BR
const SKILL_DATA_RU := LanguageSettingsData.SKILL_DATA_RU
const EXACT_TEXT_EN := LanguageSettingsData.EXACT_TEXT_EN
const EXACT_TEXT_ZH := LanguageSettingsData.EXACT_TEXT_ZH
const EXACT_TEXT_JA := LanguageSettingsData.EXACT_TEXT_JA
const EXACT_TEXT_ES := LanguageSettingsData.EXACT_TEXT_ES
const EXACT_TEXT_PT_BR := LanguageSettingsData.EXACT_TEXT_PT_BR
const EXACT_TEXT_PT_BR_OVERRIDES := LanguageSettingsData.EXACT_TEXT_PT_BR_OVERRIDES
const EXACT_TEXT_RU := LanguageSettingsData.EXACT_TEXT_RU
const EXACT_TEXT_RU_OVERRIDES := LanguageSettingsData.EXACT_TEXT_RU_OVERRIDES
const QUALITY_PREFIXES_EN := LanguageSettingsData.QUALITY_PREFIXES_EN
const QUALITY_PREFIXES_ZH := LanguageSettingsData.QUALITY_PREFIXES_ZH
const QUALITY_PREFIXES_JA := LanguageSettingsData.QUALITY_PREFIXES_JA
const QUALITY_PREFIXES_ES := LanguageSettingsData.QUALITY_PREFIXES_ES
const QUALITY_PREFIXES_PT_BR := LanguageSettingsData.QUALITY_PREFIXES_PT_BR
const QUALITY_PREFIXES_RU := LanguageSettingsData.QUALITY_PREFIXES_RU
const TEXT := LanguageSettingsData.TEXT

static var _cached_language := ""
static var _item_description_override_maps: Dictionary = {}

static func apply_saved_language() -> String:
	var language := get_language()
	_apply_engine_locale(language)
	return language


static func get_language() -> String:
	if not _cached_language.is_empty():
		return _cached_language
	var config := _load_settings()
	_cached_language = normalize_language(str(config.get_value(SETTINGS_SECTION, SETTINGS_LANGUAGE_KEY, DEFAULT_LANGUAGE)))
	_apply_engine_locale(_cached_language)
	return _cached_language


static func set_language(language: String) -> String:
	var normalized := normalize_language(language)
	_cached_language = normalized
	_apply_engine_locale(normalized)
	var config := _load_settings()
	config.set_value(SETTINGS_SECTION, SETTINGS_SCHEMA_KEY, SETTINGS_SCHEMA_VERSION)
	config.set_value(SETTINGS_SECTION, SETTINGS_LANGUAGE_KEY, normalized)
	if config.save(SETTINGS_PATH) != OK:
		print_verbose("Failed to save language settings: %s" % SETTINGS_PATH)
	return normalized


static func reset_cache_for_tests() -> void:
	_cached_language = ""
	_item_description_override_maps.clear()


static func normalize_language(language: String) -> String:
	var normalized := language.strip_edges().to_lower()
	if normalized == "en_us" or normalized == "en-us":
		normalized = LANGUAGE_ENGLISH
	if normalized == "ko_kr" or normalized == "ko-kr":
		normalized = LANGUAGE_KOREAN
	if normalized == "zh_cn" or normalized == "zh-cn" or normalized == "zh_hans" or normalized == "zh-hans" or normalized == "chinese" or normalized == "中文" or normalized == "简体中文":
		normalized = LANGUAGE_CHINESE
	if normalized == "ja_jp" or normalized == "ja-jp" or normalized == "japanese" or normalized == "日本語" or normalized == "にほんご":
		normalized = LANGUAGE_JAPANESE
	if normalized == "es_es" or normalized == "es-es" or normalized == "es_mx" or normalized == "es-mx" or normalized == "spanish" or normalized == "espanol" or normalized == "español":
		normalized = LANGUAGE_SPANISH
	if normalized == "pt_br" or normalized == "pt-br" or normalized == "pt" or normalized == "portuguese" or normalized == "portugues" or normalized == "português" or normalized == "brazilian portuguese" or normalized == "português brasileiro" or normalized == "portugues brasileiro":
		normalized = LANGUAGE_PORTUGUESE_BRAZIL
	if normalized == "ru_ru" or normalized == "ru-ru" or normalized == "russian" or normalized == "русский" or normalized == "russkiy":
		normalized = LANGUAGE_RUSSIAN
	if SUPPORTED_LANGUAGES.has(normalized):
		return normalized
	return DEFAULT_LANGUAGE


static func get_language_options() -> Array[String]:
	return SUPPORTED_LANGUAGES.duplicate()


static func get_native_language_name(language: String) -> String:
	var normalized := normalize_language(language)
	return str(LANGUAGE_NATIVE_NAMES.get(normalized, normalized))


static func _get_exact_text_map(language: String) -> Dictionary:
	if language == LANGUAGE_RUSSIAN:
		return EXACT_TEXT_RU
	if language == LANGUAGE_PORTUGUESE_BRAZIL:
		return EXACT_TEXT_PT_BR
	if language == LANGUAGE_SPANISH:
		return EXACT_TEXT_ES
	if language == LANGUAGE_CHINESE:
		return EXACT_TEXT_ZH
	if language == LANGUAGE_JAPANESE:
		return EXACT_TEXT_JA
	return EXACT_TEXT_EN


static func _get_item_display_map(language: String) -> Dictionary:
	if language == LANGUAGE_RUSSIAN:
		return ITEM_DISPLAY_RU
	if language == LANGUAGE_PORTUGUESE_BRAZIL:
		return ITEM_DISPLAY_PT_BR
	if language == LANGUAGE_SPANISH:
		return ITEM_DISPLAY_ES
	if language == LANGUAGE_JAPANESE:
		return ITEM_DISPLAY_JA
	if language == LANGUAGE_CHINESE:
		return ITEM_DISPLAY_ZH
	return ITEM_DISPLAY_EN


static func _get_active_item_description_map(language: String) -> Dictionary:
	if language == LANGUAGE_KOREAN:
		return {}
	# Active item tooltip bodies are currently authored in English only.
	# Use English as the non-Korean fallback so unsupported locales do not leak Korean copy.
	return ACTIVE_ITEM_DESCRIPTION_EN


static func _get_mythic_description_map(language: String) -> Dictionary:
	if language == LANGUAGE_RUSSIAN:
		return MYTHIC_DESCRIPTION_RU
	if language == LANGUAGE_PORTUGUESE_BRAZIL:
		return MYTHIC_DESCRIPTION_PT_BR
	if language == LANGUAGE_SPANISH:
		return MYTHIC_DESCRIPTION_ES
	if language == LANGUAGE_JAPANESE:
		return MYTHIC_DESCRIPTION_JA
	if language == LANGUAGE_CHINESE:
		return MYTHIC_DESCRIPTION_ZH
	return MYTHIC_DESCRIPTION_EN


static func _get_item_description_override_map(language: String) -> Dictionary:
	if language == LANGUAGE_KOREAN:
		return {}
	if _item_description_override_maps.has(language):
		return _item_description_override_maps[language]
	var active_item_description_map := _get_active_item_description_map(language)
	var mythic_description_map := _get_mythic_description_map(language)
	var result := {}
	if language == LANGUAGE_ENGLISH:
		result.merge(mythic_description_map, true)
		result.merge(active_item_description_map, true)
	else:
		result.merge(active_item_description_map, true)
		result.merge(mythic_description_map, true)
	_item_description_override_maps[language] = result
	return result


static func _get_perk_name_map(language: String) -> Dictionary:
	if language == LANGUAGE_RUSSIAN:
		return PERK_NAME_RU
	if language == LANGUAGE_PORTUGUESE_BRAZIL:
		return PERK_NAME_PT_BR
	if language == LANGUAGE_SPANISH:
		return PERK_NAME_ES
	if language == LANGUAGE_CHINESE:
		return PERK_NAME_ZH
	if language == LANGUAGE_JAPANESE:
		return PERK_NAME_JA
	return PERK_NAME_EN


static func _get_perk_summary_map(language: String) -> Dictionary:
	if language == LANGUAGE_RUSSIAN:
		return PERK_SUMMARY_RU
	if language == LANGUAGE_PORTUGUESE_BRAZIL:
		return PERK_SUMMARY_PT_BR
	if language == LANGUAGE_SPANISH:
		return PERK_SUMMARY_ES
	if language == LANGUAGE_CHINESE:
		return PERK_SUMMARY_ZH
	if language == LANGUAGE_JAPANESE:
		return PERK_SUMMARY_JA
	return PERK_SUMMARY_EN


static func _get_perk_localization_key(perk_id: String) -> String:
	return str(PERK_LOCALIZATION_ALIASES.get(perk_id, perk_id))


static func _get_character_map(language: String) -> Dictionary:
	if language == LANGUAGE_RUSSIAN:
		return CHARACTER_RU
	if language == LANGUAGE_PORTUGUESE_BRAZIL:
		return CHARACTER_PT_BR
	if language == LANGUAGE_SPANISH:
		return CHARACTER_ES
	if language == LANGUAGE_CHINESE:
		return CHARACTER_ZH
	if language == LANGUAGE_JAPANESE:
		return CHARACTER_JA
	return CHARACTER_EN


static func _get_quality_prefix_map(language: String) -> Dictionary:
	if language == LANGUAGE_RUSSIAN:
		return QUALITY_PREFIXES_RU
	if language == LANGUAGE_PORTUGUESE_BRAZIL:
		return QUALITY_PREFIXES_PT_BR
	if language == LANGUAGE_SPANISH:
		return QUALITY_PREFIXES_ES
	if language == LANGUAGE_CHINESE:
		return QUALITY_PREFIXES_ZH
	if language == LANGUAGE_JAPANESE:
		return QUALITY_PREFIXES_JA
	return QUALITY_PREFIXES_EN


static func translate(key: String, fallback: String = "") -> String:
	var language := get_language()
	var table: Dictionary = TEXT.get(language, {})
	if table.has(key):
		return str(table[key])
	var fallback_table: Dictionary = TEXT.get(DEFAULT_LANGUAGE, {})
	if fallback_table.has(key):
		return str(fallback_table[key])
	if not fallback.is_empty():
		return fallback
	return key


static func translate_text(text: String, fallback: String = "") -> String:
	var language := get_language()
	if language == LANGUAGE_KOREAN:
		return text
	if text.is_empty():
		return text
	if language == LANGUAGE_RUSSIAN and EXACT_TEXT_RU_OVERRIDES.has(text):
		return str(EXACT_TEXT_RU_OVERRIDES[text])
	if language == LANGUAGE_PORTUGUESE_BRAZIL and EXACT_TEXT_PT_BR_OVERRIDES.has(text):
		return str(EXACT_TEXT_PT_BR_OVERRIDES[text])
	var exact_text_map := _get_exact_text_map(language)
	if exact_text_map.has(text):
		return str(exact_text_map[text])
	if not fallback.is_empty():
		return fallback
	var translated := _translate_known_patterns(text)
	if translated != "":
		return translated
	return text


static func get_quality_prefixes(tier: String, fallback: Array) -> Array:
	var language := get_language()
	if language == LANGUAGE_KOREAN:
		return fallback
	var prefix_map := _get_quality_prefix_map(language)
	return _get_array(prefix_map.get(tier, fallback)).duplicate()


static func localize_character_list(characters: Array) -> Array:
	if get_language() == LANGUAGE_KOREAN:
		return characters
	var result: Array = []
	for character_value in characters:
		if character_value is Dictionary:
			result.append(localize_character_data(character_value))
		else:
			result.append(character_value)
	return result


static func localize_character_data(character_data: Dictionary) -> Dictionary:
	var language := get_language()
	if language == LANGUAGE_KOREAN:
		return character_data
	var result := character_data.duplicate(true)
	var key := str(result.get("runtime_id", result.get("key", result.get("id", "")))).strip_edges().to_lower()
	if key == "soldier":
		key = "commando"
	elif key == "blacksmith":
		key = "baltor"
	var localized: Dictionary = _get_character_map(language).get(key, {})
	for field in localized.keys():
		result[str(field)] = localized[field]
	if result.has("unlock_hint"):
		result["unlock_hint"] = translate_text(str(result["unlock_hint"]))
	var stats_value: Variant = result.get("stats", {})
	if stats_value is Dictionary:
		var stats: Dictionary = stats_value
		var localized_stats: Dictionary = {}
		for stat_key_value in stats.keys():
			var stat_key := str(stat_key_value)
			localized_stats[translate_text(stat_key)] = stats[stat_key_value]
		result["stats"] = localized_stats
	return result


static func localize_item_data(item_data: Dictionary) -> Dictionary:
	var language := get_language()
	if language == LANGUAGE_KOREAN:
		return item_data
	var result := _localize_visible_dictionary(item_data.duplicate(true), "")
	var item_name := str(result.get("name", result.get("effect", "")))
	var item_display_map := _get_item_display_map(language)
	var item_description_map := _get_item_description_override_map(language)
	if item_display_map.has(item_name):
		result["display_name"] = str(item_display_map[item_name])
		result["korean_name"] = str(item_display_map[item_name])
	if item_description_map.has(item_name):
		result["description"] = str(item_description_map[item_name])
	if result.has("qualified_display_name"):
		result["qualified_display_name"] = format_item_display_name(result)
	return result


static func localize_perk_data(perk_data: Dictionary) -> Dictionary:
	var language := get_language()
	if language == LANGUAGE_KOREAN:
		return perk_data
	var result := _localize_visible_dictionary(perk_data.duplicate(true), "")
	var perk_id := _get_perk_localization_key(str(result.get("id", "")))
	var perk_name_map := _get_perk_name_map(language)
	var perk_summary_map := _get_perk_summary_map(language)
	if perk_name_map.has(perk_id):
		result["name"] = str(perk_name_map[perk_id])
	if perk_summary_map.has(perk_id):
		result["description"] = str(perk_summary_map[perk_id])
		result["detail"] = str(perk_summary_map[perk_id])
	var descriptions_value: Variant = result.get("descriptions", {})
	if descriptions_value is Dictionary:
		var descriptions: Dictionary = descriptions_value
		var localized_descriptions: Dictionary = {}
		for level_value in descriptions.keys():
			localized_descriptions[level_value] = str(perk_summary_map.get(perk_id, translate_text(str(descriptions[level_value]))))
		result["descriptions"] = localized_descriptions
	return result


static func localize_reward_data(reward_data: Dictionary) -> Dictionary:
	if get_language() == LANGUAGE_KOREAN:
		return reward_data
	return _localize_visible_dictionary(reward_data.duplicate(true), "")


static func localize_skill_config_data(skill_data: Dictionary, skill_name: String) -> void:
	var language := get_language()
	var localized: Dictionary = {}
	if language == LANGUAGE_CHINESE:
		localized = SKILL_DATA_ZH.get(skill_name, {})
	elif language == LANGUAGE_JAPANESE:
		localized = SKILL_DATA_JA.get(skill_name, {})
	elif language == LANGUAGE_SPANISH:
		localized = SKILL_DATA_ES.get(skill_name, {})
	elif language == LANGUAGE_PORTUGUESE_BRAZIL:
		localized = SKILL_DATA_PT_BR.get(skill_name, {})
	elif language == LANGUAGE_RUSSIAN:
		localized = SKILL_DATA_RU.get(skill_name, {})
	else:
		return
	for field in localized.keys():
		skill_data[str(field)] = localized[field]


static func format_stage_label(stage: int) -> String:
	var language := get_language()
	if language == LANGUAGE_ENGLISH:
		return "Stage %d" % stage
	if language == LANGUAGE_CHINESE:
		return "第%d关" % stage
	if language == LANGUAGE_JAPANESE:
		return "ステージ%d" % stage
	if language == LANGUAGE_SPANISH:
		return "Fase %d" % stage
	if language == LANGUAGE_PORTUGUESE_BRAZIL:
		return "Fase %d" % stage
	if language == LANGUAGE_RUSSIAN:
		return "Этап %d" % stage
	return "스테이지 %d" % stage


static func format_stage_character_label(stage: int, character_name: String) -> String:
	var localized_name := translate_text(character_name)
	var language := get_language()
	if language == LANGUAGE_ENGLISH:
		return "Stage %d / %s" % [stage, localized_name]
	if language == LANGUAGE_CHINESE:
		return "第%d关 / %s" % [stage, localized_name]
	if language == LANGUAGE_JAPANESE:
		return "ステージ%d / %s" % [stage, localized_name]
	if language == LANGUAGE_SPANISH:
		return "Fase %d / %s" % [stage, localized_name]
	if language == LANGUAGE_PORTUGUESE_BRAZIL:
		return "Fase %d / %s" % [stage, localized_name]
	if language == LANGUAGE_RUSSIAN:
		return "Этап %d / %s" % [stage, localized_name]
	return "스테이지 %d  /  %s" % [stage, localized_name]


static func format_stage_result_label(stage: int) -> String:
	var language := get_language()
	if language == LANGUAGE_ENGLISH:
		return "Stage %d Results" % stage
	if language == LANGUAGE_CHINESE:
		return "第%d关结果" % stage
	if language == LANGUAGE_JAPANESE:
		return "ステージ%d結果" % stage
	if language == LANGUAGE_SPANISH:
		return "Resultados de fase %d" % stage
	if language == LANGUAGE_PORTUGUESE_BRAZIL:
		return "Resultados da fase %d" % stage
	if language == LANGUAGE_RUSSIAN:
		return "Итоги этапа %d" % stage
	return "스테이지 %d 결과" % stage


static func format_stage_transition_subtitle(stage: int) -> String:
	var language := get_language()
	if language == LANGUAGE_ENGLISH:
		return "Stage %d / Next Boss Preview" % stage
	if language == LANGUAGE_CHINESE:
		return "第%d关 / 下一个首领预告" % stage
	if language == LANGUAGE_JAPANESE:
		return "ステージ%d / 次のボス予告" % stage
	if language == LANGUAGE_SPANISH:
		return "Fase %d / Vista previa del próximo jefe" % stage
	if language == LANGUAGE_PORTUGUESE_BRAZIL:
		return "Fase %d / Prévia do próximo chefe" % stage
	if language == LANGUAGE_RUSSIAN:
		return "Этап %d / Предпросмотр следующего босса" % stage
	return "스테이지 %d  /  다음 보스 예고" % stage


static func format_stage_transition_status(stage: int) -> String:
	var language := get_language()
	if language == LANGUAGE_ENGLISH:
		return "Preparing Stage %d boss data" % stage
	if language == LANGUAGE_CHINESE:
		return "正在准备第%d关首领数据" % stage
	if language == LANGUAGE_JAPANESE:
		return "ステージ%dのボスデータを準備中" % stage
	if language == LANGUAGE_SPANISH:
		return "Preparando datos del jefe de fase %d" % stage
	if language == LANGUAGE_PORTUGUESE_BRAZIL:
		return "Preparando dados do chefe da fase %d" % stage
	if language == LANGUAGE_RUSSIAN:
		return "Подготовка данных босса этапа %d" % stage
	return "스테이지 %d 보스 데이터를 준비 중" % stage


static func format_item_box_summary(count: int) -> String:
	var language := get_language()
	if language == LANGUAGE_ENGLISH:
		return "%d Item Box%s" % [count, "" if count == 1 else "es"]
	if language == LANGUAGE_CHINESE:
		return "%d个道具箱" % count
	if language == LANGUAGE_JAPANESE:
		return "アイテム箱%d個" % count
	if language == LANGUAGE_SPANISH:
		return "%d caja%s de objeto" % [count, "" if count == 1 else "s"]
	if language == LANGUAGE_PORTUGUESE_BRAZIL:
		return "%d caixa%s de item" % [count, "" if count == 1 else "s"]
	if language == LANGUAGE_RUSSIAN:
		var mod10 := count % 10
		var mod100 := count % 100
		if mod10 == 1 and mod100 != 11:
			return "%d ящик с предметом" % count
		if mod10 >= 2 and mod10 <= 4 and (mod100 < 12 or mod100 > 14):
			return "%d ящика с предметами" % count
		return "%d ящиков с предметами" % count
	return "아이템 상자 %d개" % count


static func format_item_display_name(item_data: Dictionary) -> String:
	var base_name := str(item_data.get("display_name", item_data.get("korean_name", item_data.get("name", "장비"))))
	base_name = translate_text(base_name, base_name)
	var prefix := translate_text(str(item_data.get("name_prefix", "")).strip_edges())
	if prefix == "":
		return base_name
	return "%s %s" % [prefix, base_name]


static func format_select_label(name: String) -> String:
	var localized_name := translate_text(name)
	var language := get_language()
	if language == LANGUAGE_ENGLISH:
		return "Select %s" % localized_name
	if language == LANGUAGE_CHINESE:
		return "选择%s" % localized_name
	if language == LANGUAGE_JAPANESE:
		return "%sを選択" % localized_name
	if language == LANGUAGE_SPANISH:
		return "Seleccionar %s" % localized_name
	if language == LANGUAGE_PORTUGUESE_BRAZIL:
		return "Selecionar %s" % localized_name
	if language == LANGUAGE_RUSSIAN:
		return "Выбрать %s" % localized_name
	return "%s 선택" % localized_name


static func _localize_visible_dictionary(source: Dictionary, parent_key: String) -> Dictionary:
	var result: Dictionary = {}
	for key_value in source.keys():
		var key := str(key_value)
		var value: Variant = source[key_value]
		if value is Dictionary:
			result[key_value] = _localize_visible_dictionary(value, key)
		elif value is Array:
			result[key_value] = _localize_visible_array(value, key)
		elif value is String:
			result[key_value] = _localize_visible_string(key, str(value), parent_key)
		else:
			result[key_value] = value
	return result


static func _localize_visible_array(source: Array, parent_key: String) -> Array:
	var result: Array = []
	for value in source:
		if value is Dictionary:
			result.append(_localize_visible_dictionary(value, parent_key))
		elif value is Array:
			result.append(_localize_visible_array(value, parent_key))
		elif value is String:
			result.append(_localize_visible_string(parent_key, str(value), parent_key))
		else:
			result.append(value)
	return result


static func _localize_visible_string(key: String, value: String, parent_key: String) -> String:
	var visible_keys := {
		"display_name": true,
		"korean_name": true,
		"qualified_display_name": true,
		"description": true,
		"detail": true,
		"label": true,
		"title": true,
		"subtitle": true,
		"eyebrow": true,
		"summary": true,
		"text": true,
		"status": true,
		"hint": true,
		"name_prefix": true,
		"unit": true,
		"value": true,
	}
	if visible_keys.has(key) or parent_key == "descriptions":
		return translate_text(value)
	return value


static func _translate_known_patterns(text: String) -> String:
	var language := get_language()
	if text.begins_with("게이지 "):
		if language == LANGUAGE_CHINESE:
			return "能量 %s" % text.substr("게이지 ".length())
		if language == LANGUAGE_JAPANESE:
			return "ゲージ %s" % text.substr("게이지 ".length())
		if language == LANGUAGE_SPANISH:
			return "Energía %s" % text.substr("게이지 ".length())
		if language == LANGUAGE_PORTUGUESE_BRAZIL:
			return "Energia %s" % text.substr("게이지 ".length())
		if language == LANGUAGE_RUSSIAN:
			return "Энергия %s" % text.substr("게이지 ".length())
		return "Gauge %s" % text.substr("게이지 ".length())
	if text.begins_with("대시 토큰 "):
		if language == LANGUAGE_CHINESE:
			return "冲刺令牌 %s" % text.substr("대시 토큰 ".length())
		if language == LANGUAGE_JAPANESE:
			return "ダッシュトークン %s" % text.substr("대시 토큰 ".length())
		if language == LANGUAGE_SPANISH:
			return "Fichas de dash %s" % text.substr("대시 토큰 ".length())
		if language == LANGUAGE_PORTUGUESE_BRAZIL:
			return "Fichas de dash %s" % text.substr("대시 토큰 ".length())
		if language == LANGUAGE_RUSSIAN:
			return "Жетоны рывка %s" % text.substr("대시 토큰 ".length())
		return "Dash Tokens %s" % text.substr("대시 토큰 ".length())
	if text.begins_with("부활 확률 "):
		var revival_value := text.substr("부활 확률 ".length())
		if language == LANGUAGE_CHINESE:
			return "复活概率 %s" % revival_value
		if language == LANGUAGE_JAPANESE:
			return "復活確率 %s" % revival_value
		if language == LANGUAGE_SPANISH:
			return "Probabilidad de revivir %s" % revival_value
		if language == LANGUAGE_PORTUGUESE_BRAZIL:
			return "Chance de reviver %s" % revival_value
		if language == LANGUAGE_RUSSIAN:
			return "Шанс воскрешения %s" % revival_value
		return "Revival Chance %s" % revival_value
	if text.begins_with("선택 대기: "):
		if language == LANGUAGE_CHINESE:
			return "待选择：%s" % text.substr("선택 대기: ".length())
		if language == LANGUAGE_JAPANESE:
			return "選択待ち：%s" % text.substr("선택 대기: ".length())
		if language == LANGUAGE_SPANISH:
			return "Elecciones pendientes: %s" % text.substr("선택 대기: ".length())
		if language == LANGUAGE_PORTUGUESE_BRAZIL:
			return "Escolhas pendentes: %s" % text.substr("선택 대기: ".length())
		if language == LANGUAGE_RUSSIAN:
			return "Ожидает выбор: %s" % text.substr("선택 대기: ".length())
		return "Choices Waiting: %s" % text.substr("선택 대기: ".length())
	if text.begins_with("선택 대기 "):
		if language == LANGUAGE_CHINESE:
			return "待选择 %s" % text.substr("선택 대기 ".length())
		if language == LANGUAGE_JAPANESE:
			return "選択待ち %s" % text.substr("선택 대기 ".length())
		if language == LANGUAGE_SPANISH:
			return "Elecciones pendientes %s" % text.substr("선택 대기 ".length())
		if language == LANGUAGE_PORTUGUESE_BRAZIL:
			return "Escolhas pendentes %s" % text.substr("선택 대기 ".length())
		if language == LANGUAGE_RUSSIAN:
			return "Ожидает выбор %s" % text.substr("선택 대기 ".length())
		return "Choices Waiting %s" % text.substr("선택 대기 ".length())
	if text.begins_with("퍽 골드: "):
		if language == LANGUAGE_CHINESE:
			return "升级金币：%s" % text.substr("퍽 골드: ".length())
		if language == LANGUAGE_JAPANESE:
			return "パークゴールド：%s" % text.substr("퍽 골드: ".length())
		if language == LANGUAGE_SPANISH:
			return "Oro de perk: %s" % text.substr("퍽 골드: ".length())
		if language == LANGUAGE_PORTUGUESE_BRAZIL:
			return "Ouro de perk: %s" % text.substr("퍽 골드: ".length())
		if language == LANGUAGE_RUSSIAN:
			return "Золото перков: %s" % text.substr("퍽 골드: ".length())
		return "Perk Gold: %s" % text.substr("퍽 골드: ".length())
	if text.begins_with("퍽 골드 "):
		if language == LANGUAGE_CHINESE:
			return "升级金币 %s" % text.substr("퍽 골드 ".length())
		if language == LANGUAGE_JAPANESE:
			return "パークゴールド %s" % text.substr("퍽 골드 ".length())
		if language == LANGUAGE_SPANISH:
			return "Oro de perk %s" % text.substr("퍽 골드 ".length())
		if language == LANGUAGE_PORTUGUESE_BRAZIL:
			return "Ouro de perk %s" % text.substr("퍽 골드 ".length())
		if language == LANGUAGE_RUSSIAN:
			return "Золото перков %s" % text.substr("퍽 골드 ".length())
		return "Perk Gold %s" % text.substr("퍽 골드 ".length())
	if text.begins_with("추가 ") and text.ends_with("개"):
		if language == LANGUAGE_CHINESE:
			return "额外%s个" % text.substr("추가 ".length(), text.length() - "추가 ".length() - 1)
		if language == LANGUAGE_JAPANESE:
			return "追加%s個" % text.substr("추가 ".length(), text.length() - "추가 ".length() - 1)
		if language == LANGUAGE_SPANISH:
			return "%s extra" % text.substr("추가 ".length(), text.length() - "추가 ".length() - 1)
		if language == LANGUAGE_PORTUGUESE_BRAZIL:
			return "%s extra" % text.substr("추가 ".length(), text.length() - "추가 ".length() - 1)
		if language == LANGUAGE_RUSSIAN:
			return "Дополнительно %s" % text.substr("추가 ".length(), text.length() - "추가 ".length() - 1)
		return "Extra %s" % text.substr("추가 ".length(), text.length() - "추가 ".length() - 1)
	if text.begins_with("보유 ") and text.find(" / 장착 ") >= 0:
		var parts := text.replace("보유 ", "").split(" / 장착 ", false)
		if parts.size() == 2:
			if language == LANGUAGE_CHINESE:
				return "持有 %s / 装备 %s" % [parts[0], parts[1]]
			if language == LANGUAGE_JAPANESE:
				return "所持 %s / 装備 %s" % [parts[0], parts[1]]
			if language == LANGUAGE_SPANISH:
				return "Poseído %s / Equipado %s" % [parts[0], parts[1]]
			if language == LANGUAGE_PORTUGUESE_BRAZIL:
				return "Possuído %s / Equipado %s" % [parts[0], parts[1]]
			if language == LANGUAGE_RUSSIAN:
				return "Получено %s / Надето %s" % [parts[0], parts[1]]
			return "Owned %s / Equipped %s" % [parts[0], parts[1]]
	if text.begins_with("장착: "):
		if language == LANGUAGE_CHINESE:
			return "装备：%s" % translate_text(text.substr("장착: ".length()))
		if language == LANGUAGE_JAPANESE:
			return "装備：%s" % translate_text(text.substr("장착: ".length()))
		if language == LANGUAGE_SPANISH:
			return "Equipado: %s" % translate_text(text.substr("장착: ".length()))
		if language == LANGUAGE_PORTUGUESE_BRAZIL:
			return "Equipado: %s" % translate_text(text.substr("장착: ".length()))
		if language == LANGUAGE_RUSSIAN:
			return "Надето: %s" % translate_text(text.substr("장착: ".length()))
		return "Equipped: %s" % translate_text(text.substr("장착: ".length()))
	if text.begins_with("부위 : "):
		if language == LANGUAGE_CHINESE:
			return "部位：%s" % translate_text(text.substr("부위 : ".length()))
		if language == LANGUAGE_JAPANESE:
			return "部位：%s" % translate_text(text.substr("부위 : ".length()))
		if language == LANGUAGE_SPANISH:
			return "Parte: %s" % translate_text(text.substr("부위 : ".length()))
		if language == LANGUAGE_PORTUGUESE_BRAZIL:
			return "Parte: %s" % translate_text(text.substr("부위 : ".length()))
		if language == LANGUAGE_RUSSIAN:
			return "Часть: %s" % translate_text(text.substr("부위 : ".length()))
		return "Part: %s" % translate_text(text.substr("부위 : ".length()))
	if text.begins_with("슬롯 "):
		if language == LANGUAGE_CHINESE:
			return "栏位 %s" % text.substr("슬롯 ".length())
		if language == LANGUAGE_JAPANESE:
			return "スロット %s" % text.substr("슬롯 ".length())
		if language == LANGUAGE_SPANISH:
			return "Espacio %s" % text.substr("슬롯 ".length())
		if language == LANGUAGE_PORTUGUESE_BRAZIL:
			return "Espaço %s" % text.substr("슬롯 ".length())
		if language == LANGUAGE_RUSSIAN:
			return "Ячейка %s" % text.substr("슬롯 ".length())
		return "Slot %s" % text.substr("슬롯 ".length())
	if text.begins_with("비용 ") and text.find("  쿨타임 ") >= 0:
		var skill_parts := text.replace("비용 ", "").split("  쿨타임 ", false)
		if skill_parts.size() == 2:
			if language == LANGUAGE_CHINESE:
				return "费用 %s  冷却 %s" % [skill_parts[0], translate_text(skill_parts[1])]
			if language == LANGUAGE_JAPANESE:
				return "費用 %s  クールタイム %s" % [skill_parts[0], translate_text(skill_parts[1])]
			if language == LANGUAGE_SPANISH:
				return "Coste %s  Recarga %s" % [skill_parts[0], translate_text(skill_parts[1])]
			if language == LANGUAGE_PORTUGUESE_BRAZIL:
				return "Custo %s  Recarga %s" % [skill_parts[0], translate_text(skill_parts[1])]
			if language == LANGUAGE_RUSSIAN:
				return "Стоимость %s  Перезарядка %s" % [skill_parts[0], translate_text(skill_parts[1])]
			return "Cost %s  Cooldown %s" % [skill_parts[0], translate_text(skill_parts[1])]
	if text.begins_with("스테이지 ") and text.ends_with(" 결과 화면"):
		var stage_result := text.replace("스테이지 ", "").replace(" 결과 화면", "")
		if language == LANGUAGE_CHINESE:
			return "第%s关结果画面" % stage_result
		if language == LANGUAGE_JAPANESE:
			return "ステージ%s結果画面" % stage_result
		if language == LANGUAGE_SPANISH:
			return "Pantalla de resultados de fase %s" % stage_result
		if language == LANGUAGE_PORTUGUESE_BRAZIL:
			return "Tela de resultados da fase %s" % stage_result
		if language == LANGUAGE_RUSSIAN:
			return "Экран итогов этапа %s" % stage_result
		return "Stage %s Result Screen" % stage_result
	if text.begins_with("스테이지 ") and text.ends_with(" 결과"):
		var stage_number := text.replace("스테이지 ", "").replace(" 결과", "")
		if language == LANGUAGE_CHINESE:
			return "第%s关结果" % stage_number
		if language == LANGUAGE_JAPANESE:
			return "ステージ%s結果" % stage_number
		if language == LANGUAGE_SPANISH:
			return "Resultados de fase %s" % stage_number
		if language == LANGUAGE_PORTUGUESE_BRAZIL:
			return "Resultados da fase %s" % stage_number
		if language == LANGUAGE_RUSSIAN:
			return "Итоги этапа %s" % stage_number
		return "Stage %s Results" % stage_number
	if text.begins_with("스테이지 "):
		var stage_label := text.replace("스테이지 ", "")
		if stage_label.is_valid_int():
			if language == LANGUAGE_CHINESE:
				return "第%s关" % stage_label
			if language == LANGUAGE_JAPANESE:
				return "ステージ%s" % stage_label
			if language == LANGUAGE_SPANISH:
				return "Fase %s" % stage_label
			if language == LANGUAGE_PORTUGUESE_BRAZIL:
				return "Fase %s" % stage_label
			if language == LANGUAGE_RUSSIAN:
				return "Этап %s" % stage_label
			return "Stage %s" % stage_label
	if text.ends_with(" 선택"):
		if language == LANGUAGE_CHINESE:
			return "选择%s" % translate_text(text.substr(0, text.length() - 3))
		if language == LANGUAGE_JAPANESE:
			return "%sを選択" % translate_text(text.substr(0, text.length() - 3))
		if language == LANGUAGE_SPANISH:
			return "Seleccionar %s" % translate_text(text.substr(0, text.length() - 3))
		if language == LANGUAGE_PORTUGUESE_BRAZIL:
			return "Selecionar %s" % translate_text(text.substr(0, text.length() - 3))
		if language == LANGUAGE_RUSSIAN:
			return "Выбрать %s" % translate_text(text.substr(0, text.length() - 3))
		return "Select %s" % translate_text(text.substr(0, text.length() - 3))
	if text.begins_with("쿨타임 ") and text.ends_with("초"):
		var seconds := text.replace("쿨타임 ", "").replace("초", "")
		if language == LANGUAGE_CHINESE:
			return "冷却%s秒" % seconds
		if language == LANGUAGE_JAPANESE:
			return "クールタイム%s秒" % seconds
		if language == LANGUAGE_SPANISH:
			return "Recarga %ss" % seconds
		if language == LANGUAGE_PORTUGUESE_BRAZIL:
			return "Recarga %ss" % seconds
		if language == LANGUAGE_RUSSIAN:
			return "Перезарядка %sс" % seconds
		return "Cooldown %ss" % seconds
	if text.ends_with("초"):
		var plain_seconds := text.substr(0, text.length() - 1)
		if plain_seconds.is_valid_float():
			if language == LANGUAGE_CHINESE:
				return "%s秒" % plain_seconds
			if language == LANGUAGE_JAPANESE:
				return "%s秒" % plain_seconds
			if language == LANGUAGE_SPANISH:
				return "%ss" % plain_seconds
			if language == LANGUAGE_PORTUGUESE_BRAZIL:
				return "%ss" % plain_seconds
			if language == LANGUAGE_RUSSIAN:
				return "%sс" % plain_seconds
			return "%ss" % plain_seconds
	if text.ends_with(" 발견"):
		if language == LANGUAGE_CHINESE:
			return "发现%s" % translate_text(text.substr(0, text.length() - 3))
		if language == LANGUAGE_JAPANESE:
			return "%s発見" % translate_text(text.substr(0, text.length() - 3))
		if language == LANGUAGE_SPANISH:
			return "%s encontrado" % translate_text(text.substr(0, text.length() - 3))
		if language == LANGUAGE_PORTUGUESE_BRAZIL:
			return "%s encontrado" % translate_text(text.substr(0, text.length() - 3))
		if language == LANGUAGE_RUSSIAN:
			return "%s найдено" % translate_text(text.substr(0, text.length() - 3))
		return "%s Found" % translate_text(text.substr(0, text.length() - 3))
	return ""


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func _load_settings() -> ConfigFile:
	var config := ConfigFile.new()
	if FileAccess.file_exists(SETTINGS_PATH):
		var result := config.load(SETTINGS_PATH)
		if result != OK:
			return ConfigFile.new()
	return config


static func _apply_engine_locale(language: String) -> void:
	TranslationServer.set_locale(normalize_language(language))
