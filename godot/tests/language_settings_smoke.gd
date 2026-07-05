extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const CharacterSelectData := preload("res://scripts/ui/character_select_data.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")

var _language_settings_snapshot: Dictionary = {}


func _init() -> void:
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_ENGLISH)

	_expect(LanguageSettings.translate_text("홍련 화염구") == "Hongryun Fireball", "stage boss skill names should localize")
	_expect(LanguageSettings.translate_text("게이지 120/500") == "Gauge 120/500", "composed gauge labels should localize")
	_expect(LanguageSettings.translate_text("보유 2 / 장착 1") == "Owned 2 / Equipped 1", "inventory count labels should localize")
	_expect(LanguageSettings.translate_text("비용 300  쿨타임 8초") == "Cost 300  Cooldown 8s", "skill cost/cooldown labels should localize")

	var active_catalog := ActiveItemCatalog.new()
	_expect(active_catalog.get_display_name("gauge_charge") == "Energy Drink", "active item catalog should return English names")

	var mythic_catalog := MythicItemCatalog.new()
	var speedboots: Dictionary = mythic_catalog.build_item_by_name("speedboots")
	_expect(str(speedboots.get("display_name", "")) == "Speed Boots", "mythic item names should localize")
	_expect(str(speedboots.get("description", "")).find("movement speed") >= 0, "mythic item descriptions should localize")

	var perk_catalog := RuntimePerkCatalog.new()
	var lightweight: Dictionary = perk_catalog.get_perk_data("dash_lightweight")
	_expect(str(lightweight.get("name", "")) == "Lightweight", "runtime perk names should localize")
	_expect(str(lightweight.get("description", "")).find("Dash cooldown") >= 0, "runtime perk descriptions should localize")
	var ghost_unlock: Dictionary = perk_catalog.get_perk_data("unlock_ghost_shot")
	_expect(str(ghost_unlock.get("name", "")) == str(LanguageSettings.PERK_NAME_EN["smasher_unlock_ghost_shot"]), "Ghost Smashing unlock perk name should localize to English")
	_expect(str(ghost_unlock.get("description", "")) == str(LanguageSettings.PERK_SUMMARY_EN["smasher_unlock_ghost_shot"]), "Ghost Smashing unlock perk summary should localize to English")
	var smasher_skill_config_en := SmasherSkillConfig.new()
	_expect(str(smasher_skill_config_en.get_skill_data("ghost_shot").get("korean", "")) == "Ghost Smashing", "Ghost Shot runtime id should display as Ghost Smashing in English")

	var characters: Array = LanguageSettings.localize_character_list(CharacterSelectData.get_characters())
	_expect(not characters.is_empty(), "character select data should be available")
	var first_character: Dictionary = characters[0]
	_expect(str(first_character.get("name", "")) == "Smasher", "character select names should localize")
	_expect(str(first_character.get("character_name", "")) == "Mika", "character names should localize")
	var stats: Dictionary = first_character.get("stats", {})
	_expect(stats.has("Speed"), "character select stat labels should localize")

	LanguageSettings.set_language(LanguageSettings.LANGUAGE_CHINESE)
	_expect(LanguageSettings.get_language_options().has(LanguageSettings.LANGUAGE_CHINESE), "language options should include Simplified Chinese")
	_expect(LanguageSettings.get_native_language_name(LanguageSettings.LANGUAGE_CHINESE) == "简体中文", "Chinese native language name should localize")
	_expect(LanguageSettings.translate("pause.continue") == "继续", "pause labels should localize to Chinese")
	_expect(LanguageSettings.translate_text("체력") == "生命", "exact gameplay text should localize to Chinese")
	_expect(LanguageSettings.translate_text("발동") == "发动", "skill control tokens should localize to Chinese")
	_expect(LanguageSettings.translate_text("게이지 120/500") == "能量 120/500", "composed gauge labels should localize to Chinese")
	_expect(LanguageSettings.format_stage_label(5) == "第5关", "stage labels should format in Chinese")
	_expect(LanguageSettings.format_item_box_summary(3) == "3个道具箱", "item box summaries should format in Chinese")
	var quality_prefixes_zh: Array = LanguageSettings.get_quality_prefixes("mid", ["fallback"])
	_expect(quality_prefixes_zh.has("精致"), "quality prefixes should localize to Chinese")

	var active_catalog_zh := ActiveItemCatalog.new()
	_expect(active_catalog_zh.get_display_name("gauge_charge") == "能量饮料", "active item catalog should return Chinese names")

	var mythic_catalog_zh := MythicItemCatalog.new()
	var speedboots_zh: Dictionary = mythic_catalog_zh.build_item_by_name("speedboots")
	_expect(str(speedboots_zh.get("display_name", "")) == "疾速靴", "mythic item names should localize to Chinese")
	_expect(str(speedboots_zh.get("description", "")).find("移动速度") >= 0, "mythic item descriptions should localize to Chinese")

	var perk_catalog_zh := RuntimePerkCatalog.new()
	var lightweight_zh: Dictionary = perk_catalog_zh.get_perk_data("dash_lightweight")
	_expect(str(lightweight_zh.get("name", "")) == "轻量化", "runtime perk names should localize to Chinese")
	_expect(str(lightweight_zh.get("description", "")).find("冲刺冷却") >= 0, "runtime perk descriptions should localize to Chinese")

	var characters_zh: Array = LanguageSettings.localize_character_list(CharacterSelectData.get_characters())
	_expect(not characters_zh.is_empty(), "Chinese character select data should be available")
	var first_character_zh: Dictionary = characters_zh[0]
	_expect(str(first_character_zh.get("name", "")) == "粉碎者", "character select names should localize to Chinese")
	_expect(str(first_character_zh.get("character_name", "")) == "米卡", "character names should localize to Chinese")
	var stats_zh: Dictionary = first_character_zh.get("stats", {})
	_expect(stats_zh.has("速度"), "character select stat labels should localize to Chinese")

	var smasher_skill_config := SmasherSkillConfig.new()
	_expect(str(smasher_skill_config.get_skill_data("ghost_shot").get("korean", "")) == str(LanguageSettings.SKILL_DATA_ZH["ghost_shot"]["korean"]), "Ghost Smashing skill data should localize to Chinese")
	_expect(str(smasher_skill_config.get_skill_data("plasma").get("korean", "")) == "等离子", "Smasher skill data should localize to Chinese")
	var commando_skill_config := CommandoSkillConfig.new()
	_expect(str(commando_skill_config.get_skill_data("commando_pistol").get("korean", "")) == "贝雷塔", "Commando skill data should localize to Chinese")
	var viper_skill_config := ViperSkillConfig.new()
	_expect(str(viper_skill_config.get_skill_data("ignition_aura").get("korean", "")) == "点火光环", "Viper skill data should localize to Chinese")

	LanguageSettings.set_language(LanguageSettings.LANGUAGE_JAPANESE)
	_expect(str(smasher_skill_config.get_skill_data("ghost_shot").get("korean", "")) == str(LanguageSettings.SKILL_DATA_JA["ghost_shot"]["korean"]), "Ghost Smashing skill data should localize to Japanese")
	_expect(LanguageSettings.get_language_options().has(LanguageSettings.LANGUAGE_JAPANESE), "language options should include Japanese")
	_expect(LanguageSettings.normalize_language("ja-JP") == LanguageSettings.LANGUAGE_JAPANESE, "Japanese locale aliases should normalize")
	_expect(LanguageSettings.get_native_language_name(LanguageSettings.LANGUAGE_JAPANESE) == "日本語", "Japanese native language name should localize")
	_expect(LanguageSettings.translate("pause.continue") == "続ける", "pause labels should localize to Japanese")
	_expect(LanguageSettings.translate_text("체력") == "体力", "exact gameplay text should localize to Japanese")
	_expect(LanguageSettings.format_stage_label(5) == "ステージ5", "stage labels should format in Japanese")
	_expect(LanguageSettings.format_item_box_summary(3) == "アイテム箱3個", "item box summaries should format in Japanese")
	var quality_prefixes_ja: Array = LanguageSettings.get_quality_prefixes("mid", ["fallback"])
	_expect(quality_prefixes_ja.has("標準の"), "quality prefixes should localize to Japanese")
	var active_catalog_ja := ActiveItemCatalog.new()
	_expect(active_catalog_ja.get_display_name("gauge_charge") == "エナジードリンク", "active item catalog should return Japanese names")
	var mythic_catalog_ja := MythicItemCatalog.new()
	var speedboots_ja: Dictionary = mythic_catalog_ja.build_item_by_name("speedboots")
	_expect(str(speedboots_ja.get("display_name", "")) == "スピードブーツ", "mythic item names should localize to Japanese")
	_expect(str(speedboots_ja.get("description", "")).find("移動速度") >= 0, "mythic item descriptions should localize to Japanese")
	var perk_catalog_ja := RuntimePerkCatalog.new()
	var lightweight_ja: Dictionary = perk_catalog_ja.get_perk_data("dash_lightweight")
	_expect(str(lightweight_ja.get("name", "")) == "軽量化", "runtime perk names should localize to Japanese")
	_expect(str(lightweight_ja.get("description", "")).find("ダッシュ") >= 0, "runtime perk descriptions should localize to Japanese")
	var characters_ja: Array = LanguageSettings.localize_character_list(CharacterSelectData.get_characters())
	_expect(not characters_ja.is_empty(), "Japanese character select data should be available")
	var first_character_ja: Dictionary = characters_ja[0]
	_expect(str(first_character_ja.get("name", "")) == "スマッシャー", "character select names should localize to Japanese")
	_expect(str(first_character_ja.get("character_name", "")) == "ミカ", "character names should localize to Japanese")
	var stats_ja: Dictionary = first_character_ja.get("stats", {})
	_expect(stats_ja.has("速度"), "character select stat labels should localize to Japanese")
	_expect(str(smasher_skill_config.get_skill_data("plasma").get("korean", "")) == "プラズマ", "Smasher skill data should localize to Japanese")
	_expect(str(commando_skill_config.get_skill_data("commando_pistol").get("korean", "")) == "ベレッタ", "Commando skill data should localize to Japanese")
	_expect(str(viper_skill_config.get_skill_data("ignition_aura").get("korean", "")) == "イグニッションオーラ", "Viper skill data should localize to Japanese")

	LanguageSettings.set_language(LanguageSettings.LANGUAGE_SPANISH)
	_expect(str(smasher_skill_config.get_skill_data("ghost_shot").get("korean", "")) == str(LanguageSettings.SKILL_DATA_ES["ghost_shot"]["korean"]), "Ghost Smashing skill data should localize to Spanish")
	_expect(LanguageSettings.get_language_options().has(LanguageSettings.LANGUAGE_SPANISH), "language options should include Spanish")
	_expect(LanguageSettings.normalize_language("es-ES") == LanguageSettings.LANGUAGE_SPANISH, "Spanish locale aliases should normalize")
	_expect(LanguageSettings.get_native_language_name(LanguageSettings.LANGUAGE_SPANISH) == "Español", "Spanish native language name should localize")
	_expect(LanguageSettings.translate("pause.continue") == "Continuar", "pause labels should localize to Spanish")
	_expect(LanguageSettings.translate_text("체력") == "PV", "exact gameplay text should localize to Spanish")
	_expect(LanguageSettings.format_stage_label(5) == "Fase 5", "stage labels should format in Spanish")
	_expect(LanguageSettings.format_item_box_summary(3) == "3 cajas de objeto", "item box summaries should format in Spanish")
	var quality_prefixes_es: Array = LanguageSettings.get_quality_prefixes("mid", ["fallback"])
	_expect(quality_prefixes_es.has("Estándar"), "quality prefixes should localize to Spanish")
	var active_catalog_es := ActiveItemCatalog.new()
	_expect(active_catalog_es.get_display_name("gauge_charge") == "Bebida energética", "active item catalog should return Spanish names")
	var mythic_catalog_es := MythicItemCatalog.new()
	var speedboots_es: Dictionary = mythic_catalog_es.build_item_by_name("speedboots")
	_expect(str(speedboots_es.get("display_name", "")) == "Botas de velocidad", "mythic item names should localize to Spanish")
	_expect(str(speedboots_es.get("description", "")).find("velocidad") >= 0, "mythic item descriptions should localize to Spanish")
	var perk_catalog_es := RuntimePerkCatalog.new()
	var lightweight_es: Dictionary = perk_catalog_es.get_perk_data("dash_lightweight")
	_expect(str(lightweight_es.get("name", "")) == "Ligereza", "runtime perk names should localize to Spanish")
	_expect(str(lightweight_es.get("description", "")).find("dash") >= 0, "runtime perk descriptions should localize to Spanish")
	var characters_es: Array = LanguageSettings.localize_character_list(CharacterSelectData.get_characters())
	_expect(not characters_es.is_empty(), "Spanish character select data should be available")
	var first_character_es: Dictionary = characters_es[0]
	_expect(str(first_character_es.get("name", "")) == "Smasher", "character select names should localize to Spanish")
	_expect(str(first_character_es.get("character_name", "")) == "Mika", "character names should localize to Spanish")
	var stats_es: Dictionary = first_character_es.get("stats", {})
	_expect(stats_es.has("Velocidad"), "character select stat labels should localize to Spanish")
	_expect(str(smasher_skill_config.get_skill_data("plasma").get("korean", "")) == "Plasma", "Smasher skill data should localize to Spanish")
	_expect(str(commando_skill_config.get_skill_data("commando_pistol").get("korean", "")) == "Beretta", "Commando skill data should localize to Spanish")
	_expect(str(viper_skill_config.get_skill_data("ignition_aura").get("korean", "")) == "Aura de ignición", "Viper skill data should localize to Spanish")

	LanguageSettings.set_language(LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL)
	_expect(str(smasher_skill_config.get_skill_data("ghost_shot").get("korean", "")) == str(LanguageSettings.SKILL_DATA_PT_BR["ghost_shot"]["korean"]), "Ghost Smashing skill data should localize to Brazilian Portuguese")
	_expect(LanguageSettings.get_language_options().has(LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL), "language options should include Brazilian Portuguese")
	_expect(LanguageSettings.normalize_language("pt-BR") == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL, "Brazilian Portuguese locale aliases should normalize")
	_expect(LanguageSettings.get_native_language_name(LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL) == "Português (Brasil)", "Brazilian Portuguese native language name should localize")
	_expect(LanguageSettings.translate("pause.continue") == "Continuar", "pause labels should localize to Brazilian Portuguese")
	_expect(LanguageSettings.translate_text("체력") == "PV", "exact gameplay text should localize to Brazilian Portuguese")
	_expect(LanguageSettings.format_stage_label(5) == "Fase 5", "stage labels should format in Brazilian Portuguese")
	_expect(LanguageSettings.format_item_box_summary(3) == "3 caixas de item", "item box summaries should format in Brazilian Portuguese")
	var quality_prefixes_pt_br: Array = LanguageSettings.get_quality_prefixes("mid", ["fallback"])
	_expect(quality_prefixes_pt_br.has("Padrão"), "quality prefixes should localize to Brazilian Portuguese")
	var active_catalog_pt_br := ActiveItemCatalog.new()
	_expect(active_catalog_pt_br.get_display_name("gauge_charge") == "Energético", "active item catalog should return Brazilian Portuguese names")
	var mythic_catalog_pt_br := MythicItemCatalog.new()
	var speedboots_pt_br: Dictionary = mythic_catalog_pt_br.build_item_by_name("speedboots")
	_expect(str(speedboots_pt_br.get("display_name", "")) == "Botas de Velocidade", "mythic item names should localize to Brazilian Portuguese")
	_expect(str(speedboots_pt_br.get("description", "")).find("velocidade") >= 0, "mythic item descriptions should localize to Brazilian Portuguese")
	var perk_catalog_pt_br := RuntimePerkCatalog.new()
	var lightweight_pt_br: Dictionary = perk_catalog_pt_br.get_perk_data("dash_lightweight")
	_expect(str(lightweight_pt_br.get("name", "")) == "Leveza", "runtime perk names should localize to Brazilian Portuguese")
	_expect(str(lightweight_pt_br.get("description", "")).find("dash") >= 0, "runtime perk descriptions should localize to Brazilian Portuguese")
	var characters_pt_br: Array = LanguageSettings.localize_character_list(CharacterSelectData.get_characters())
	_expect(not characters_pt_br.is_empty(), "Brazilian Portuguese character select data should be available")
	var first_character_pt_br: Dictionary = characters_pt_br[0]
	_expect(str(first_character_pt_br.get("name", "")) == "Smasher", "character select names should localize to Brazilian Portuguese")
	_expect(str(first_character_pt_br.get("character_name", "")) == "Mika", "character names should localize to Brazilian Portuguese")
	var stats_pt_br: Dictionary = first_character_pt_br.get("stats", {})
	_expect(stats_pt_br.has("Velocidade"), "character select stat labels should localize to Brazilian Portuguese")
	_expect(str(smasher_skill_config.get_skill_data("plasma").get("korean", "")) == "Plasma", "Smasher skill data should localize to Brazilian Portuguese")
	_expect(str(commando_skill_config.get_skill_data("commando_pistol").get("korean", "")) == "Beretta", "Commando skill data should localize to Brazilian Portuguese")
	_expect(str(viper_skill_config.get_skill_data("ignition_aura").get("korean", "")) == "Aura de Ignição", "Viper skill data should localize to Brazilian Portuguese")

	LanguageSettings.set_language(LanguageSettings.LANGUAGE_RUSSIAN)
	_expect(str(smasher_skill_config.get_skill_data("ghost_shot").get("korean", "")) == str(LanguageSettings.SKILL_DATA_RU["ghost_shot"]["korean"]), "Ghost Smashing skill data should localize to Russian")
	_expect(LanguageSettings.get_language_options().has(LanguageSettings.LANGUAGE_RUSSIAN), "language options should include Russian")
	_expect(LanguageSettings.normalize_language("ru-RU") == LanguageSettings.LANGUAGE_RUSSIAN, "Russian locale aliases should normalize")
	_expect(LanguageSettings.get_native_language_name(LanguageSettings.LANGUAGE_RUSSIAN) == str(LanguageSettings.LANGUAGE_NATIVE_NAMES[LanguageSettings.LANGUAGE_RUSSIAN]), "Russian native language name should localize")
	_expect(LanguageSettings.translate("pause.continue") == str(LanguageSettings.TEXT[LanguageSettings.LANGUAGE_RUSSIAN]["pause.continue"]), "pause labels should localize to Russian")
	_expect(LanguageSettings.translate_text("체력") == str(LanguageSettings.EXACT_TEXT_RU_OVERRIDES["체력"]), "exact gameplay text should localize to Russian")
	_expect(LanguageSettings.format_stage_label(5) == "Этап 5", "stage labels should format in Russian")
	_expect(LanguageSettings.format_item_box_summary(3) == "3 ящика с предметами", "item box summaries should format in Russian")
	var quality_prefixes_ru: Array = LanguageSettings.get_quality_prefixes("mid", ["fallback"])
	_expect(quality_prefixes_ru.has("Стандартный"), "quality prefixes should localize to Russian")
	var active_catalog_ru := ActiveItemCatalog.new()
	_expect(active_catalog_ru.get_display_name("gauge_charge") == str(LanguageSettings.ITEM_DISPLAY_RU["gauge_charge"]), "active item catalog should return Russian names")
	var mythic_catalog_ru := MythicItemCatalog.new()
	var speedboots_ru: Dictionary = mythic_catalog_ru.build_item_by_name("speedboots")
	_expect(str(speedboots_ru.get("display_name", "")) == str(LanguageSettings.ITEM_DISPLAY_RU["speedboots"]), "mythic item names should localize to Russian")
	_expect(str(speedboots_ru.get("description", "")) == str(LanguageSettings.MYTHIC_DESCRIPTION_RU["speedboots"]), "mythic item descriptions should localize to Russian")
	var perk_catalog_ru := RuntimePerkCatalog.new()
	var lightweight_ru: Dictionary = perk_catalog_ru.get_perk_data("dash_lightweight")
	_expect(str(lightweight_ru.get("name", "")) == str(LanguageSettings.PERK_NAME_RU["dash_lightweight"]), "runtime perk names should localize to Russian")
	_expect(str(lightweight_ru.get("description", "")) == str(LanguageSettings.PERK_SUMMARY_RU["dash_lightweight"]), "runtime perk descriptions should localize to Russian")
	var characters_ru: Array = LanguageSettings.localize_character_list(CharacterSelectData.get_characters())
	_expect(not characters_ru.is_empty(), "Russian character select data should be available")
	var first_character_ru: Dictionary = characters_ru[0]
	_expect(str(first_character_ru.get("role", "")) == str(LanguageSettings.CHARACTER_RU["smasher"]["role"]), "character select data should localize to Russian")
	var stats_ru: Dictionary = first_character_ru.get("stats", {})
	_expect(stats_ru.has("Скорость"), "character select stat labels should localize to Russian")
	_expect(str(smasher_skill_config.get_skill_data("plasma").get("korean", "")) == str(LanguageSettings.SKILL_DATA_RU["plasma"]["korean"]), "Smasher skill data should localize to Russian")
	_expect(str(commando_skill_config.get_skill_data("commando_pistol").get("korean", "")) == str(LanguageSettings.SKILL_DATA_RU["commando_pistol"]["korean"]), "Commando skill data should localize to Russian")
	_expect(str(viper_skill_config.get_skill_data("ignition_aura").get("korean", "")) == str(LanguageSettings.SKILL_DATA_RU["ignition_aura"]["korean"]), "Viper skill data should localize to Russian")

	# Non-mouse bond interact hint (TAB bond tooltip, 2026-07-04): the sentence
	# must localize in every EXACT_TEXT language, mirroring its sibling bond
	# tooltip sentence (ko is the source key; pt-BR/ru have no EXACT_TEXT dict).
	var bond_hint_key := "링펫을 클릭하거나 E 키(패드 RT)로 교감할 수 있습니다."
	var bond_hint_expected := {
		LanguageSettings.LANGUAGE_ENGLISH: "You can bond by clicking your lingpet or pressing E (RT on a gamepad).",
		LanguageSettings.LANGUAGE_CHINESE: "点击灵宠，或按 E 键（手柄 RT）即可进行羁绊互动。",
		LanguageSettings.LANGUAGE_JAPANESE: "リンペットをクリックするか、Eキー（パッドはRT）で絆を深められます。",
		LanguageSettings.LANGUAGE_SPANISH: "Puedes crear vínculo haciendo clic en tu lingpet o pulsando E (RT en el mando).",
	}
	for bond_hint_language in bond_hint_expected:
		LanguageSettings.set_language(bond_hint_language)
		_expect(
			LanguageSettings.translate_text(bond_hint_key) == str(bond_hint_expected[bond_hint_language]),
			"bond interact hint should localize to %s" % str(bond_hint_language)
		)

	_restore_language_settings_snapshot()
	print("language_settings_smoke: ok")
	quit(0)


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
	_restore_settings_file(
		LanguageSettings.SETTINGS_PATH,
		bool(_language_settings_snapshot.get("had", false)),
		_language_settings_snapshot.get("bytes", PackedByteArray())
	)
	LanguageSettings.reset_cache_for_tests()
	LanguageSettings.apply_saved_language()


func _restore_settings_file(path: String, had_file: bool, file_bytes: PackedByteArray) -> void:
	if had_file:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(file_bytes)
			file.close()
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_restore_language_settings_snapshot()
	push_error(message)
	quit(1)
