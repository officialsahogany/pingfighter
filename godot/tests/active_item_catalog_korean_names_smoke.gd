extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemPickupFeedback := preload("res://scripts/items/active_item_pickup_feedback.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const EXPECTED_DISPLAY_NAMES := {
	"gauge_charge": "에너지드링크",
	"life_elixir": "생명수",
	"ammo_box": "탄약상자",
	"doping_potion": "도핑주사기",
	"vitamin_pill": "비타민드링크",
	"strange_vial": "기묘한 약병",
	"aipill": "AI 알약",
	"pandora_box": "판도라의 상자",
	"grenade": "수류탄",
	"flare": "조명탄",
	"tear_gas": "최루탄",
	"dynamite": "다이너마이트",
	"molotov": "화염병",
	"stopwatch": "스탑워치",
	"magnet_field": "자기장",
	"long_boost": "거대화포션",
	"regeneration_potion": "재생물약",
	"holy_barrier": "홀리베리어",
	"wall": "벽돌",
	"boomerang": "부메랑",
	"banana": "바나나",
	"soap": "비누",
	"spider_mine": "스파이더지뢰",
	"milk_bottle": "우유병",
}

var _failures: Array[String] = []
var _language_settings_snapshot: Dictionary = {}


func _init() -> void:
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_verify_catalog_display_names()
	_verify_catalog_descriptions()
	_verify_pickup_fallback_names()
	_verify_english_catalog_display_names()
	_verify_chinese_catalog_display_names()
	_verify_japanese_catalog_display_names()
	_verify_spanish_catalog_display_names()
	_verify_portuguese_brazil_catalog_display_names()
	_verify_russian_catalog_display_names()
	_verify_duplicate_active_item_descriptions()
	_restore_language_settings_snapshot()

	if _failures.is_empty():
		print("active_item_catalog_korean_names_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_display_names() -> void:
	var catalog := ActiveItemCatalog.new()
	for item_name in EXPECTED_DISPLAY_NAMES.keys():
		var expected_name: String = str(EXPECTED_DISPLAY_NAMES[item_name])
		var item_data: Dictionary = catalog.build_item_by_name(str(item_name))
		_expect(not item_data.is_empty(), "%s should build from the active item catalog" % item_name)
		_expect(str(item_data.get("display_name", "")) == expected_name, "%s should use Korean display text" % item_name)
		_expect(catalog.get_display_name(str(item_name)) == expected_name, "%s get_display_name should use Korean display text" % item_name)


func _verify_catalog_descriptions() -> void:
	var catalog := ActiveItemCatalog.new()
	var description_items: Array = EXPECTED_DISPLAY_NAMES.keys()
	description_items.append("dash_boost")
	description_items.append("elixir_of_mastery")
	for item_name in description_items:
		var item_data: Dictionary = catalog.build_item_by_name(str(item_name))
		_expect(str(item_data.get("description", "")).strip_edges() != "", "%s should expose a tooltip description" % item_name)
	_expect(
		str(catalog.build_item_by_name("regeneration_potion").get("description", "")).find("스킬 쿨타임") >= 0,
		"regeneration potion description should explain cooldown recovery"
	)


func _verify_duplicate_active_item_descriptions() -> void:
	var catalog := ActiveItemCatalog.new()
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_ENGLISH)
	_expect(
		str(catalog.build_item_by_name("elixir_of_mastery").get("description", "")) == str(LanguageSettings.ACTIVE_ITEM_DESCRIPTION_EN["elixir_of_mastery"]),
		"English active catalog should use the active elixir description"
	)
	_expect(
		str(catalog.build_item_by_name("milk_bottle").get("description", "")) == str(LanguageSettings.ACTIVE_ITEM_DESCRIPTION_EN["milk_bottle"]),
		"English active catalog should use the active milk-bottle description"
	)

	LanguageSettings.set_language(LanguageSettings.LANGUAGE_CHINESE)
	_expect(str(catalog.build_item_by_name("milk_bottle").get("description", "")) == str(LanguageSettings.MYTHIC_DESCRIPTION_ZH["milk_bottle"]), "Chinese active catalog should keep the localized milk-bottle description")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_JAPANESE)
	_expect(str(catalog.build_item_by_name("milk_bottle").get("description", "")) == str(LanguageSettings.MYTHIC_DESCRIPTION_JA["milk_bottle"]), "Japanese active catalog should keep the localized milk-bottle description")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_SPANISH)
	_expect(str(catalog.build_item_by_name("milk_bottle").get("description", "")) == str(LanguageSettings.MYTHIC_DESCRIPTION_ES["milk_bottle"]), "Spanish active catalog should keep the localized milk-bottle description")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL)
	_expect(str(catalog.build_item_by_name("milk_bottle").get("description", "")) == str(LanguageSettings.MYTHIC_DESCRIPTION_PT_BR["milk_bottle"]), "Brazilian Portuguese active catalog should keep the localized milk-bottle description")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_RUSSIAN)
	_expect(str(catalog.build_item_by_name("milk_bottle").get("description", "")) == str(LanguageSettings.MYTHIC_DESCRIPTION_RU["milk_bottle"]), "Russian active catalog should keep the localized milk-bottle description")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_pickup_fallback_names() -> void:
	var feedback := ActiveItemPickupFeedback.new()
	for item_name in EXPECTED_DISPLAY_NAMES.keys():
		if item_name == "ammo_box" or item_name == "doping_potion":
			continue
		var expected_name: String = str(EXPECTED_DISPLAY_NAMES[item_name])
		_expect(str(feedback._get_item_display_name(str(item_name))) == expected_name, "%s pickup fallback should use Korean display text" % item_name)


func _verify_english_catalog_display_names() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_ENGLISH)
	var catalog := ActiveItemCatalog.new()
	_expect(str(catalog.build_item_by_name("gauge_charge").get("display_name", "")) == "Energy Drink", "English active item catalog should localize Energy Drink")
	_expect(str(catalog.build_item_by_name("grenade").get("display_name", "")) == "Grenade", "English active item catalog should localize Grenade")
	_expect(str(catalog.build_item_by_name("elixir_of_mastery").get("display_name", "")) == "Elixir of Mastery", "English active item catalog should localize Elixir of Mastery")
	_expect(str(catalog.build_item_by_name("milk_bottle").get("display_name", "")) == "Milk Bottle", "English active item catalog should localize Milk Bottle")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_chinese_catalog_display_names() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_CHINESE)
	var catalog := ActiveItemCatalog.new()
	_expect(str(catalog.build_item_by_name("gauge_charge").get("display_name", "")) == "能量饮料", "Chinese active item catalog should localize Energy Drink")
	_expect(str(catalog.build_item_by_name("grenade").get("display_name", "")) == "手榴弹", "Chinese active item catalog should localize Grenade")
	_expect(str(catalog.build_item_by_name("elixir_of_mastery").get("display_name", "")) == "精通灵药", "Chinese active item catalog should localize Elixir of Mastery")
	_expect(str(catalog.build_item_by_name("milk_bottle").get("display_name", "")) == "牛奶瓶", "Chinese active item catalog should localize Milk Bottle")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_japanese_catalog_display_names() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_JAPANESE)
	var catalog := ActiveItemCatalog.new()
	_expect(str(catalog.build_item_by_name("gauge_charge").get("display_name", "")) == "エナジードリンク", "Japanese active item catalog should localize Energy Drink")
	_expect(str(catalog.build_item_by_name("grenade").get("display_name", "")) == "手榴弾", "Japanese active item catalog should localize Grenade")
	_expect(str(catalog.build_item_by_name("elixir_of_mastery").get("display_name", "")) == "熟練のエリクサー", "Japanese active item catalog should localize Elixir of Mastery")
	_expect(str(catalog.build_item_by_name("milk_bottle").get("display_name", "")) == "ミルクボトル", "Japanese active item catalog should localize Milk Bottle")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_spanish_catalog_display_names() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_SPANISH)
	var catalog := ActiveItemCatalog.new()
	_expect(str(catalog.build_item_by_name("gauge_charge").get("display_name", "")) == "Bebida energética", "Spanish active item catalog should localize Energy Drink")
	_expect(str(catalog.build_item_by_name("grenade").get("display_name", "")) == "Granada", "Spanish active item catalog should localize Grenade")
	_expect(str(catalog.build_item_by_name("elixir_of_mastery").get("display_name", "")) == "Elixir de maestría", "Spanish active item catalog should localize Elixir of Mastery")
	_expect(str(catalog.build_item_by_name("milk_bottle").get("display_name", "")) == "Botella de leche", "Spanish active item catalog should localize Milk Bottle")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_portuguese_brazil_catalog_display_names() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL)
	var catalog := ActiveItemCatalog.new()
	_expect(str(catalog.build_item_by_name("gauge_charge").get("display_name", "")) == "Energético", "Brazilian Portuguese active item catalog should localize Energy Drink")
	_expect(str(catalog.build_item_by_name("grenade").get("display_name", "")) == "Granada", "Brazilian Portuguese active item catalog should localize Grenade")
	_expect(str(catalog.build_item_by_name("elixir_of_mastery").get("display_name", "")) == "Elixir de Maestria", "Brazilian Portuguese active item catalog should localize Elixir of Mastery")
	_expect(str(catalog.build_item_by_name("milk_bottle").get("display_name", "")) == "Garrafa de leite", "Brazilian Portuguese active item catalog should localize Milk Bottle")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _verify_russian_catalog_display_names() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_RUSSIAN)
	var catalog := ActiveItemCatalog.new()
	_expect(str(catalog.build_item_by_name("gauge_charge").get("display_name", "")) == "Энергетик", "Russian active item catalog should localize Energy Drink")
	_expect(str(catalog.build_item_by_name("grenade").get("display_name", "")) == "Граната", "Russian active item catalog should localize Grenade")
	_expect(str(catalog.build_item_by_name("elixir_of_mastery").get("display_name", "")) == "Эликсир мастерства", "Russian active item catalog should localize Elixir of Mastery")
	_expect(str(catalog.build_item_by_name("milk_bottle").get("display_name", "")) == "Бутылка молока", "Russian active item catalog should localize Milk Bottle")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


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
