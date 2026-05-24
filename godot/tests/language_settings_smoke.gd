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
	_expect(str(smasher_skill_config.get_skill_data("plasma").get("korean", "")) == "等离子", "Smasher skill data should localize to Chinese")
	var commando_skill_config := CommandoSkillConfig.new()
	_expect(str(commando_skill_config.get_skill_data("commando_pistol").get("korean", "")) == "贝雷塔", "Commando skill data should localize to Chinese")
	var viper_skill_config := ViperSkillConfig.new()
	_expect(str(viper_skill_config.get_skill_data("ignition_aura").get("korean", "")) == "点火光环", "Viper skill data should localize to Chinese")

	LanguageSettings.set_language(LanguageSettings.LANGUAGE_JAPANESE)
	_expect(LanguageSettings.get_language_options().has(LanguageSettings.LANGUAGE_JAPANESE), "language options should include Japanese")
	_expect(LanguageSettings.normalize_language("ja-JP") == LanguageSettings.LANGUAGE_JAPANESE, "Japanese locale aliases should normalize")
	_expect(LanguageSettings.get_native_language_name(LanguageSettings.LANGUAGE_JAPANESE) == "日本語", "Japanese native language name should localize")
	var active_catalog_ja := ActiveItemCatalog.new()
	_expect(active_catalog_ja.get_display_name("gauge_charge") == "エナジードリンク", "active item catalog should return Japanese names")
	var mythic_catalog_ja := MythicItemCatalog.new()
	var speedboots_ja: Dictionary = mythic_catalog_ja.build_item_by_name("speedboots")
	_expect(str(speedboots_ja.get("display_name", "")) == "スピードブーツ", "mythic item names should localize to Japanese")
	_expect(str(speedboots_ja.get("description", "")).find("移動速度") >= 0, "mythic item descriptions should localize to Japanese")

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
