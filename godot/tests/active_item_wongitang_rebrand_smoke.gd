extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const EXPECTED_ICON_PATH := "res://assets/sprites/items/regeneration_potion_icon_hq_v1.png"
const LOCALIZED_NAMES := [
	[LanguageSettings.LANGUAGE_ENGLISH, "Wongitang"],
	[LanguageSettings.LANGUAGE_CHINESE, "元气汤"],
	[LanguageSettings.LANGUAGE_JAPANESE, "元気湯"],
	[LanguageSettings.LANGUAGE_SPANISH, "Tónico Wongitang"],
	[LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL, "Tônico Wongitang"],
	[LanguageSettings.LANGUAGE_RUSSIAN, "Отвар «Вонгитан»"],
]

var _failures: Array[String] = []
var _language_settings_snapshot: Dictionary = {}


func _init() -> void:
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	_verify_catalog_and_icon()
	_verify_localization()
	_verify_runtime_consumers()
	_restore_language_settings_snapshot()

	if _failures.is_empty():
		print("active_item_wongitang_rebrand_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_and_icon() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	var catalog := ActiveItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("regeneration_potion")
	_expect(str(item_data.get("display_name", "")) == "원기탕", "regeneration_potion should be rebranded to Wongitang")
	_expect(str(item_data.get("effect", "")) == "regeneration_potion", "Wongitang should preserve the runtime effect id")
	_expect(str(item_data.get("description", "")).begins_with("원기를 북돋아"), "Wongitang tooltip should explain its restorative fantasy")
	_expect(str(item_data.get("description", "")).find("초식 쿨타임") >= 0, "Wongitang tooltip should preserve the cooldown-reset behavior")
	_expect(ActiveItemCatalog.REGENERATION_POTION_ICON_PATH == EXPECTED_ICON_PATH, "Wongitang should use the generated decoction-pot icon")

	var texture: Texture2D = load(EXPECTED_ICON_PATH) as Texture2D
	_expect(texture != null, "Wongitang generated icon should load")
	if texture == null:
		return
	_expect(texture.get_size() == Vector2(256.0, 256.0), "Wongitang icon should use the 256px HQ contract")
	var image: Image = texture.get_image()
	var semi_count := 0
	for y_value in range(image.get_height()):
		for x_value in range(image.get_width()):
			var alpha: float = image.get_pixel(x_value, y_value).a
			if alpha > 8.0 / 255.0 and alpha <= 200.0 / 255.0:
				semi_count += 1
	_expect(semi_count < image.get_width() * image.get_height() / 4, "Wongitang final icon should not carry a full-canvas chroma halo")
	_expect(image.get_pixel(0, 0).a <= 8.0 / 255.0, "Wongitang icon corner should be transparent")


func _verify_localization() -> void:
	var catalog := ActiveItemCatalog.new()
	for locale_spec in LOCALIZED_NAMES:
		var language: String = str(locale_spec[0])
		var expected_name: String = str(locale_spec[1])
		LanguageSettings.set_language(language)
		_expect(str(catalog.build_item_by_name("regeneration_potion").get("display_name", "")) == expected_name, "%s catalog should localize Wongitang" % language)
		_expect(LanguageSettings.translate_text("원기탕") == expected_name, "%s exact-text lane should localize Wongitang" % language)


func _verify_runtime_consumers() -> void:
	var pickup_source := FileAccess.get_file_as_string("res://scripts/items/active_item_pickup_feedback.gd")
	var pandora_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_pandora_legacy_runtime.gd")
	var debug_source := FileAccess.get_file_as_string("res://scripts/items/active_item_debug_spawn_menu.gd")
	_expect(pickup_source.find("\"regeneration_potion\": \"원기탕\"") >= 0, "pickup fallback should use Wongitang")
	_expect(pandora_source.find("\"regeneration_potion\": \"원기탕\"") >= 0, "Pandora fallback should use Wongitang")
	_expect(debug_source.find("\"regeneration_potion\",") >= 0, "F2 active-item menu should retain the regeneration_potion compatibility id")
	_expect(debug_source.find("쿨타임 초기화 / 활주 횟수 회복") >= 0, "F2 Wongitang subtitle should use the glide-charge terminology")


func _snapshot_settings_file(path: String) -> Dictionary:
	var had_original := FileAccess.file_exists(path)
	var original_bytes := PackedByteArray()
	if had_original:
		original_bytes = FileAccess.get_file_as_bytes(path)
	return {"had": had_original, "bytes": original_bytes}


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
