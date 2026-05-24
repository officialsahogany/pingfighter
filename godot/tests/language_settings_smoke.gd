extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const CharacterSelectData := preload("res://scripts/ui/character_select_data.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")

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
