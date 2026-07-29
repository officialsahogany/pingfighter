extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const CharacterSelectData := preload("res://scripts/ui/character_select_data.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")

const ACTIVE_ITEM_EXTRAS := [
	"ammo_box",
	"doping_potion",
	"elixir_of_mastery",
	"milk_bottle",
	"cheddar_cheese",
	"camembert_cheese",
	"emmental_cheese",
]
const LEGACY_DISABLED_ACTIVE_ITEM_IDS := [
]
var _failures: Array[String] = []
var _language_settings_snapshot: Dictionary = {}


func _init() -> void:
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	_verify_translation_map_coverage()

	for language in _get_non_korean_languages():
		LanguageSettings.set_language(language)
		_verify_translation_maps_have_no_hangul(language)
		_verify_runtime_surfaces_have_no_hangul(language)

	_verify_skill_label_not_english_fallback()

	_restore_language_settings_snapshot()

	if _failures.is_empty():
		print("localization_coverage_smoke: ok")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _get_non_korean_languages() -> Array[String]:
	return [
		LanguageSettings.LANGUAGE_ENGLISH,
		LanguageSettings.LANGUAGE_CHINESE,
		LanguageSettings.LANGUAGE_JAPANESE,
		LanguageSettings.LANGUAGE_SPANISH,
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL,
		LanguageSettings.LANGUAGE_RUSSIAN,
	]


# Regression seal for the localization-copy-sync trap. The no-Hangul scan cannot
# catch an English fallthrough (English has no Hangul), and EXACT_TEXT_PT_BR /
# EXACT_TEXT_RU are aliases of EXACT_TEXT_EN whose *_OVERRIDES dicts are
# intentionally partial, so _verify_same_keys never notices a dropped skill label.
# These locales DO localize skill/item terms (정화/회복/플라즈마/...), so a skill
# label that exists in the full locales must not silently revert to English here.
func _verify_skill_label_not_english_fallback() -> void:
	var labels := ["해골장막"]
	for korean in labels:
		LanguageSettings.set_language(LanguageSettings.LANGUAGE_ENGLISH)
		var english: String = LanguageSettings.translate_text(korean)
		_expect(english != korean and not english.is_empty(), "EN should translate skill label %s" % korean)
		for language in _get_non_korean_languages():
			if language == LanguageSettings.LANGUAGE_ENGLISH:
				continue
			LanguageSettings.set_language(language)
			var localized: String = LanguageSettings.translate_text(korean)
			_expect(localized != korean, "%s should not leave %s untranslated (raw Korean)" % [language, korean])
			_expect(localized != english, "%s should localize %s, not fall back to English '%s'" % [language, korean, english])


func _verify_pistol_enhance_summary_copy() -> void:
	var entries := [
		{
			"label": "EN",
			"text": str(LanguageSettings.PERK_SUMMARY_EN.get("pistol_enhance", "")),
			"accuracy": ["accuracy"],
			"speed": ["bullet speed"],
			"knockback": ["knockback"],
			"magazine": ["magazine"],
		},
		{
			"label": "ZH",
			"text": str(LanguageSettings.PERK_SUMMARY_ZH.get("pistol_enhance", "")),
			"accuracy": ["精度"],
			"speed": ["弹速"],
			"knockback": ["击退"],
			"magazine": ["弹匣"],
		},
		{
			"label": "JA",
			"text": str(LanguageSettings.PERK_SUMMARY_JA.get("pistol_enhance", "")),
			"accuracy": ["精度"],
			"speed": ["弾速"],
			"knockback": ["ノックバック"],
			"magazine": ["マガジン"],
		},
		{
			"label": "ES",
			"text": str(LanguageSettings.PERK_SUMMARY_ES.get("pistol_enhance", "")),
			"accuracy": ["precisión"],
			"speed": ["velocidad de bala"],
			"knockback": ["retroceso"],
			"magazine": ["cargador"],
		},
		{
			"label": "PT_BR",
			"text": str(LanguageSettings.PERK_SUMMARY_PT_BR.get("pistol_enhance", "")),
			"accuracy": ["precisão"],
			"speed": ["velocidade dos projéteis"],
			"knockback": ["recuo"],
			"magazine": ["carregador"],
		},
		{
			"label": "RU",
			"text": str(LanguageSettings.PERK_SUMMARY_RU.get("pistol_enhance", "")),
			"accuracy": ["точность"],
			"speed": ["скорость пули"],
			"knockback": ["отбрасывание"],
			"magazine": ["магазина"],
		},
	]
	for entry in entries:
		var label: String = str(entry.get("label", "unknown"))
		var summary: String = str(entry.get("text", "")).to_lower()
		_expect(_contains_any_token(summary, entry.get("accuracy", [])), "PERK_SUMMARY_%s pistol_enhance should mention accuracy/spread" % label)
		_expect(_contains_any_token(summary, entry.get("speed", [])), "PERK_SUMMARY_%s pistol_enhance should mention bullet speed" % label)
		_expect(_contains_any_token(summary, entry.get("knockback", [])), "PERK_SUMMARY_%s pistol_enhance should mention normal-hit knockback" % label)
		_expect(_contains_any_token(summary, entry.get("magazine", [])), "PERK_SUMMARY_%s pistol_enhance should mention magazine/ammo" % label)


func _contains_any_token(text: String, tokens: Variant) -> bool:
	if not (tokens is Array):
		return false
	for token in tokens:
		if text.find(str(token).to_lower()) >= 0:
			return true
	return false


func _verify_translation_map_coverage() -> void:
	var korean_text: Dictionary = LanguageSettings.TEXT.get(LanguageSettings.LANGUAGE_KOREAN, {})
	for language in LanguageSettings.get_language_options():
		var localized_text: Dictionary = LanguageSettings.TEXT.get(language, {})
		_verify_same_keys(korean_text, localized_text, "TEXT[%s]" % language)

	_verify_same_keys(LanguageSettings.ITEM_DISPLAY_EN, LanguageSettings.ITEM_DISPLAY_ZH, "ITEM_DISPLAY_ZH")
	_verify_same_keys(LanguageSettings.ITEM_DISPLAY_EN, LanguageSettings.ITEM_DISPLAY_JA, "ITEM_DISPLAY_JA")
	_verify_same_keys(LanguageSettings.ITEM_DISPLAY_EN, LanguageSettings.ITEM_DISPLAY_ES, "ITEM_DISPLAY_ES")
	_verify_same_keys(LanguageSettings.ITEM_DISPLAY_EN, LanguageSettings.ITEM_DISPLAY_PT_BR, "ITEM_DISPLAY_PT_BR")
	_verify_same_keys(LanguageSettings.ITEM_DISPLAY_EN, LanguageSettings.ITEM_DISPLAY_RU, "ITEM_DISPLAY_RU")
	_verify_same_keys(LanguageSettings.MYTHIC_DESCRIPTION_EN, LanguageSettings.MYTHIC_DESCRIPTION_ZH, "MYTHIC_DESCRIPTION_ZH")
	_verify_same_keys(LanguageSettings.MYTHIC_DESCRIPTION_EN, LanguageSettings.MYTHIC_DESCRIPTION_JA, "MYTHIC_DESCRIPTION_JA")
	_verify_same_keys(LanguageSettings.MYTHIC_DESCRIPTION_EN, LanguageSettings.MYTHIC_DESCRIPTION_ES, "MYTHIC_DESCRIPTION_ES")
	_verify_same_keys(LanguageSettings.MYTHIC_DESCRIPTION_EN, LanguageSettings.MYTHIC_DESCRIPTION_PT_BR, "MYTHIC_DESCRIPTION_PT_BR")
	_verify_same_keys(LanguageSettings.MYTHIC_DESCRIPTION_EN, LanguageSettings.MYTHIC_DESCRIPTION_RU, "MYTHIC_DESCRIPTION_RU")
	_verify_same_keys(LanguageSettings.PERK_NAME_EN, LanguageSettings.PERK_NAME_ZH, "PERK_NAME_ZH")
	_verify_same_keys(LanguageSettings.PERK_NAME_EN, LanguageSettings.PERK_NAME_JA, "PERK_NAME_JA")
	_verify_same_keys(LanguageSettings.PERK_NAME_EN, LanguageSettings.PERK_NAME_ES, "PERK_NAME_ES")
	_verify_same_keys(LanguageSettings.PERK_NAME_EN, LanguageSettings.PERK_NAME_PT_BR, "PERK_NAME_PT_BR")
	_verify_same_keys(LanguageSettings.PERK_NAME_EN, LanguageSettings.PERK_NAME_RU, "PERK_NAME_RU")
	_verify_same_keys(LanguageSettings.PERK_SUMMARY_EN, LanguageSettings.PERK_SUMMARY_ZH, "PERK_SUMMARY_ZH")
	_verify_same_keys(LanguageSettings.PERK_SUMMARY_EN, LanguageSettings.PERK_SUMMARY_JA, "PERK_SUMMARY_JA")
	_verify_same_keys(LanguageSettings.PERK_SUMMARY_EN, LanguageSettings.PERK_SUMMARY_ES, "PERK_SUMMARY_ES")
	_verify_same_keys(LanguageSettings.PERK_SUMMARY_EN, LanguageSettings.PERK_SUMMARY_PT_BR, "PERK_SUMMARY_PT_BR")
	_verify_same_keys(LanguageSettings.PERK_SUMMARY_EN, LanguageSettings.PERK_SUMMARY_RU, "PERK_SUMMARY_RU")
	_verify_pistol_enhance_summary_copy()
	_verify_same_nested_keys(LanguageSettings.CHARACTER_EN, LanguageSettings.CHARACTER_ZH, "CHARACTER_ZH")
	_verify_same_nested_keys(LanguageSettings.CHARACTER_EN, LanguageSettings.CHARACTER_JA, "CHARACTER_JA")
	_verify_same_nested_keys(LanguageSettings.CHARACTER_EN, LanguageSettings.CHARACTER_ES, "CHARACTER_ES")
	_verify_same_nested_keys(LanguageSettings.CHARACTER_EN, LanguageSettings.CHARACTER_PT_BR, "CHARACTER_PT_BR")
	_verify_same_nested_keys(LanguageSettings.CHARACTER_EN, LanguageSettings.CHARACTER_RU, "CHARACTER_RU")
	_verify_same_nested_keys(LanguageSettings.SKILL_DATA_ZH, LanguageSettings.SKILL_DATA_JA, "SKILL_DATA_JA")
	_verify_same_nested_keys(LanguageSettings.SKILL_DATA_ZH, LanguageSettings.SKILL_DATA_ES, "SKILL_DATA_ES")
	_verify_same_nested_keys(LanguageSettings.SKILL_DATA_ZH, LanguageSettings.SKILL_DATA_PT_BR, "SKILL_DATA_PT_BR")
	_verify_same_nested_keys(LanguageSettings.SKILL_DATA_ZH, LanguageSettings.SKILL_DATA_RU, "SKILL_DATA_RU")
	_verify_viper_dark_blade_window_text()
	_verify_same_keys(LanguageSettings.EXACT_TEXT_EN, LanguageSettings.EXACT_TEXT_ZH, "EXACT_TEXT_ZH")
	_verify_same_keys(LanguageSettings.EXACT_TEXT_EN, LanguageSettings.EXACT_TEXT_JA, "EXACT_TEXT_JA")
	_verify_same_keys(LanguageSettings.EXACT_TEXT_EN, LanguageSettings.EXACT_TEXT_ES, "EXACT_TEXT_ES")
	_verify_same_keys(LanguageSettings.EXACT_TEXT_EN, LanguageSettings.EXACT_TEXT_PT_BR, "EXACT_TEXT_PT_BR")
	_verify_same_keys(LanguageSettings.EXACT_TEXT_EN, LanguageSettings.EXACT_TEXT_RU, "EXACT_TEXT_RU")
	_verify_same_keys(LanguageSettings.QUALITY_PREFIXES_EN, LanguageSettings.QUALITY_PREFIXES_ZH, "QUALITY_PREFIXES_ZH")
	_verify_same_keys(LanguageSettings.QUALITY_PREFIXES_EN, LanguageSettings.QUALITY_PREFIXES_JA, "QUALITY_PREFIXES_JA")
	_verify_same_keys(LanguageSettings.QUALITY_PREFIXES_EN, LanguageSettings.QUALITY_PREFIXES_ES, "QUALITY_PREFIXES_ES")
	_verify_same_keys(LanguageSettings.QUALITY_PREFIXES_EN, LanguageSettings.QUALITY_PREFIXES_PT_BR, "QUALITY_PREFIXES_PT_BR")
	_verify_same_keys(LanguageSettings.QUALITY_PREFIXES_EN, LanguageSettings.QUALITY_PREFIXES_RU, "QUALITY_PREFIXES_RU")


func _verify_translation_maps_have_no_hangul(language: String) -> void:
	_scan_values(LanguageSettings.TEXT.get(language, {}), "TEXT[%s]" % language)
	_scan_values(LanguageSettings._get_exact_text_map(language), "EXACT_TEXT[%s]" % language)
	_scan_values(LanguageSettings._get_item_display_map(language), "ITEM_DISPLAY[%s]" % language)
	_scan_values(LanguageSettings._get_mythic_description_map(language), "MYTHIC_DESCRIPTION[%s]" % language)
	_scan_values(LanguageSettings._get_perk_name_map(language), "PERK_NAME[%s]" % language)
	_scan_values(LanguageSettings._get_perk_summary_map(language), "PERK_SUMMARY[%s]" % language)
	_scan_values(LanguageSettings._get_character_map(language), "CHARACTER[%s]" % language)
	_scan_values(LanguageSettings._get_quality_prefix_map(language), "QUALITY_PREFIXES[%s]" % language)
	if language == LanguageSettings.LANGUAGE_CHINESE:
		_scan_values(LanguageSettings.SKILL_DATA_ZH, "SKILL_DATA_ZH")
	elif language == LanguageSettings.LANGUAGE_JAPANESE:
		_scan_values(LanguageSettings.SKILL_DATA_JA, "SKILL_DATA_JA")
	elif language == LanguageSettings.LANGUAGE_SPANISH:
		_scan_values(LanguageSettings.SKILL_DATA_ES, "SKILL_DATA_ES")
	elif language == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		_scan_values(LanguageSettings.SKILL_DATA_PT_BR, "SKILL_DATA_PT_BR")
		_scan_values(LanguageSettings.EXACT_TEXT_PT_BR_OVERRIDES, "EXACT_TEXT_PT_BR_OVERRIDES")
	elif language == LanguageSettings.LANGUAGE_RUSSIAN:
		_scan_values(LanguageSettings.SKILL_DATA_RU, "SKILL_DATA_RU")
		_scan_values(LanguageSettings.EXACT_TEXT_RU_OVERRIDES, "EXACT_TEXT_RU_OVERRIDES")


func _verify_runtime_surfaces_have_no_hangul(language: String) -> void:
	_verify_active_item_catalog(language)
	_verify_mythic_item_catalog(language)
	_verify_perk_catalog(language)
	_verify_character_select(language)
	_verify_skill_configs(language)
	_verify_formatter_outputs(language)
	_verify_lingpet_panel_surface(language)


func _verify_lingpet_panel_surface(language: String) -> void:
	# Lingpet TAB panel + 교감 (affinity) overlay surface. Reward labels and
	# bond titles are pulled from the runtime constants so a new reward type
	# or bond title cannot ship Korean-only, and the composed labels exercise
	# the translate-then-format / known-patterns paths the presenters use.
	var surface_texts: Array[String] = [
		"링펫", "링펫 알", "링펫 없음", "링펫 알 없음", "미해금", "미획득",
		"동행 중", "하트 공명", "포만도", "탈진", "액티브 스킬", "패시브 스킬", "다음 보상 준비 중",
		"최대 강화 완료", "링코어 강화 시 해금", "2번째 액티브 스킬 +1", "2번째 패시브 스킬 +1",
		"방어", "방어율", "출현율", "액티브 쿨타임", "받아치기", "이동", "추적", "전이",
		"링코어", "강화칩 %d / %d", "미장착",
		"공에 맞을 때마다 금이 가고, 가득 차면 링펫이 깨어납니다.",
		"테스트 난이도에서 미카로 플레이하면 첫 링펫 알이 나타납니다.",
		"링펫이 전투 중 자동으로 사용하는 액티브 스킬입니다.",
		"링펫에게 배정된 패시브 스킬입니다.",
		"이번 판 동안 링펫과 쌓은 교감 수치입니다. 요구치를 채우면 교감 레벨이 오르고 다음 보상이 해금됩니다.",
		"링펫의 포만도입니다. 시간이 지나면 서서히 줄고, 낮아지면 순찰이 느려지며 0이 되면 탈진합니다. 먹이를 주면 회복됩니다.",
	]
	for reward_label in LingpetAffinityState.LABEL_BY_REWARD_TYPE.values():
		surface_texts.append(str(reward_label))
	for korean_text in surface_texts:
		_expect_no_hangul(LanguageSettings.translate_text(korean_text), "LINGPET_SURFACE[%s] %s" % [language, korean_text])
	_expect_no_hangul(LanguageSettings.translate_text("교감 Lv.15!"), "LINGPET_SURFACE[%s] affinity flash label" % language)
	_expect_no_hangul(LanguageSettings.translate_text("교감 Lv.%d") % 3, "LINGPET_SURFACE[%s] affinity row label" % language)
	_expect_no_hangul(LanguageSettings.translate_text("공 충돌 %s") % "1 / 3", "LINGPET_SURFACE[%s] egg subtitle" % language)
	_expect_no_hangul(LanguageSettings.translate_text("다음: %s") % LanguageSettings.translate_text("기동 강화"), "LINGPET_SURFACE[%s] next reward line" % language)
	_expect_no_hangul(LanguageSettings.translate_text("강화칩 %d / %d") % [3, 5], "LINGPET_SURFACE[%s] ring core chip count line" % language)
	_expect_no_hangul(LanguageSettings.translate_text("액티브 · %s쿨타임 %s") % ["Lv.2 · ", LanguageSettings.translate_text("18초")], "LINGPET_SURFACE[%s] active skill subtitle" % language)
	_expect_no_hangul(LanguageSettings.translate_text("%s을(를) 다시 사용할 수 있게 되는 시간입니다.") % "X", "LINGPET_SURFACE[%s] cooldown tooltip" % language)
	for picker_text in ["액티브 선택", "패시브 선택", "2nd 액티브 선택", "2nd 패시브 선택", "스킬 선택", "액티브 후보", "패시브 후보", "2nd 액티브 후보", "2nd 패시브 후보", "후보", "+%d 대기", "선택하면 이 스킬이 링펫 슬롯에 고정됩니다."]:
		_expect_no_hangul(LanguageSettings.translate_text(picker_text), "LINGPET_PICKER_SURFACE[%s] %s" % [language, picker_text])
	for skill_name in _lingpet_picker_candidate_names():
		_expect_no_hangul(LanguageSettings.translate_text(skill_name), "LINGPET_PICKER_SKILL_NAME[%s] %s" % [language, skill_name])


func _verify_active_item_catalog(language: String) -> void:
	var catalog := ActiveItemCatalog.new()
	for item_id in LEGACY_DISABLED_ACTIVE_ITEM_IDS:
		_expect(ActiveItemCatalog.is_acquisition_disabled(item_id), "legacy active item %s should remain explicitly acquisition-disabled for %s" % [item_id, language])
		_expect(catalog.build_item_by_name(item_id).is_empty(), "legacy active item %s should stay blocked for %s" % [item_id, language])
	var item_ids: Array = ActiveItemCatalog.FIELD_SPAWN_ORDER.duplicate()
	for item_id in ACTIVE_ITEM_EXTRAS:
		if not item_ids.has(item_id):
			item_ids.append(item_id)
	for item_id in item_ids:
		var item_data: Dictionary = catalog.build_item_by_name(str(item_id))
		_expect(not item_data.is_empty(), "active item %s should build for %s" % [item_id, language])
		_scan_values(item_data, "active item %s[%s]" % [item_id, language])


func _verify_mythic_item_catalog(language: String) -> void:
	var catalog := MythicItemCatalog.new()
	for item_id in MythicItemCatalog.FIELD_SPAWN_ORDER:
		var item_data: Dictionary = catalog.build_item_by_name(str(item_id))
		_expect(not item_data.is_empty(), "mythic item %s should build for %s" % [item_id, language])
		_scan_values(item_data, "mythic item %s[%s]" % [item_id, language])


func _verify_perk_catalog(language: String) -> void:
	var catalog := RuntimePerkCatalog.new()
	_scan_values(catalog.get_all_perk_data(), "runtime perks[%s]" % language)
	_scan_values(catalog.get_debug_perk_entries(), "debug perk entries[%s]" % language)


func _verify_character_select(language: String) -> void:
	# League / difficulty button labels on the character-select action bar.
	for league_label in ["테스트", "실전", "오버클럭"]:
		_expect_no_hangul(LanguageSettings.translate_text(league_label), "LEAGUE_LABEL[%s] %s" % [language, league_label])
	var characters: Array = LanguageSettings.localize_character_list(CharacterSelectData.get_characters())
	_expect(not characters.is_empty(), "character select data should be available for %s" % language)
	_scan_values(characters, "character select[%s]" % language)
	for index in range(characters.size()):
		var character_value: Variant = characters[index]
		if not character_value is Dictionary:
			continue
		var character: Dictionary = character_value
		var stats_value: Variant = character.get("stats", {})
		if stats_value is Dictionary:
			_scan_dictionary_keys(stats_value, "character select[%s].%d.stats" % [language, index])


func _verify_skill_configs(language: String) -> void:
	var smasher := SmasherSkillConfig.new()
	for skill_id in SmasherSkillConfig.SKILL_DATA.keys():
		_scan_values(smasher.get_skill_data(str(skill_id)), "smasher skill %s[%s]" % [skill_id, language])

	var commando := CommandoSkillConfig.new()
	for skill_id in CommandoSkillConfig.SKILL_DATA.keys():
		_scan_values(commando.get_skill_data(str(skill_id)), "commando skill %s[%s]" % [skill_id, language])

	var viper := ViperSkillConfig.new()
	for skill_id in ViperSkillConfig.SKILL_DATA.keys():
		_scan_values(viper.get_skill_data(str(skill_id)), "viper skill %s[%s]" % [skill_id, language])


func _lingpet_picker_candidate_names() -> Array[String]:
	var names: Array[String] = []
	for pet_id in LingpetCatalog.get_pet_ids(true):
		for skill in LingpetCatalog.get_active_skill_pool(str(pet_id)):
			var skill_name := str(skill.get("name", "")).strip_edges()
			if skill_name != "" and not names.has(skill_name):
				names.append(skill_name)
	for passive in LingpetCatalog.get_passive_skill_pool("maribo"):
		var passive_name := str(passive.get("name", "")).strip_edges()
		if passive_name != "" and not names.has(passive_name):
			names.append(passive_name)
	return names


func _verify_formatter_outputs(language: String) -> void:
	var raw_characters: Array = CharacterSelectData.get_characters()
	var raw_character_name := ""
	if not raw_characters.is_empty() and raw_characters[0] is Dictionary:
		raw_character_name = str(raw_characters[0].get("name", ""))

	_scan_values(LanguageSettings.format_stage_label(5), "format_stage_label[%s]" % language)
	_scan_values(LanguageSettings.format_stage_result_label(5), "format_stage_result_label[%s]" % language)
	_scan_values(LanguageSettings.format_stage_transition_subtitle(5), "format_stage_transition_subtitle[%s]" % language)
	_scan_values(LanguageSettings.format_stage_transition_status(5), "format_stage_transition_status[%s]" % language)
	_scan_values(LanguageSettings.format_item_box_summary(3), "format_item_box_summary[%s]" % language)
	if raw_character_name != "":
		_scan_values(LanguageSettings.format_stage_character_label(5, raw_character_name), "format_stage_character_label[%s]" % language)
		_scan_values(LanguageSettings.format_select_label(raw_character_name), "format_select_label[%s]" % language)

	for source_text in LanguageSettings.EXACT_TEXT_EN.keys():
		_scan_values(LanguageSettings.translate_text(str(source_text)), "translate_text exact[%s]" % language)


func _verify_same_nested_keys(expected: Dictionary, actual: Dictionary, actual_name: String) -> void:
	_verify_same_keys(expected, actual, actual_name)
	for key_value in expected.keys():
		if not actual.has(key_value):
			continue
		var expected_value: Variant = expected[key_value]
		var actual_value: Variant = actual[key_value]
		if expected_value is Dictionary and actual_value is Dictionary:
			_verify_same_keys(expected_value, actual_value, "%s.%s" % [actual_name, key_value])


func _verify_viper_dark_blade_window_text() -> void:
	var localized_skill_maps := {
		"SKILL_DATA_ZH": {"data": LanguageSettings.SKILL_DATA_ZH, "one": "1秒", "glow": "红"},
		"SKILL_DATA_JA": {"data": LanguageSettings.SKILL_DATA_JA, "one": "1秒", "glow": "赤"},
		"SKILL_DATA_ES": {"data": LanguageSettings.SKILL_DATA_ES, "one": "1 s", "glow": "rojo"},
		"SKILL_DATA_PT_BR": {"data": LanguageSettings.SKILL_DATA_PT_BR, "one": "1 s", "glow": "vermelho"},
		"SKILL_DATA_RU": {"data": LanguageSettings.SKILL_DATA_RU, "one": "1 с", "glow": "крас"},
	}
	for label in localized_skill_maps.keys():
		var spec: Dictionary = localized_skill_maps[label]
		var skill_data: Dictionary = (spec.get("data", {}) as Dictionary).get("dark_blade", {})
		var description := str(skill_data.get("description", ""))
		_expect(description.find(str(spec.get("one", ""))) >= 0, "%s.dark_blade should describe the 1-second chain window" % label)
		_expect(description.find(str(spec.get("glow", ""))) >= 0, "%s.dark_blade should mention the red chain glow" % label)
		_expect(description.find("3秒") < 0 and description.find("3 s") < 0 and description.find("3 с") < 0, "%s.dark_blade should not keep stale 3-second copy" % label)


func _verify_same_keys(expected: Dictionary, actual: Dictionary, actual_name: String) -> void:
	for key_value in expected.keys():
		if not actual.has(key_value):
			_failures.append("%s is missing key %s" % [actual_name, key_value])
	for key_value in actual.keys():
		if not expected.has(key_value):
			_failures.append("%s has extra key %s" % [actual_name, key_value])


func _scan_values(value: Variant, context: String) -> void:
	if value is String:
		_expect_no_hangul(str(value), context)
	elif value is Dictionary:
		var dictionary: Dictionary = value
		for key_value in dictionary.keys():
			_scan_values(dictionary[key_value], "%s.%s" % [context, key_value])
	elif value is Array:
		var array: Array = value
		for index in range(array.size()):
			_scan_values(array[index], "%s[%d]" % [context, index])


func _scan_dictionary_keys(value: Variant, context: String) -> void:
	if not value is Dictionary:
		return
	var dictionary: Dictionary = value
	for key_value in dictionary.keys():
		_expect_no_hangul(str(key_value), "%s key" % context)


func _expect_no_hangul(text: String, context: String) -> void:
	if _has_hangul(text):
		_failures.append("%s leaked Korean text: %s" % [context, text])


func _has_hangul(text: String) -> bool:
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if code >= 0x1100 and code <= 0x11FF:
			return true
		if code >= 0x3130 and code <= 0x318F:
			return true
		if code >= 0xAC00 and code <= 0xD7AF:
			return true
	return false


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
			file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LanguageSettings.SETTINGS_PATH))
	LanguageSettings.reset_cache_for_tests()
	LanguageSettings.apply_saved_language()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
