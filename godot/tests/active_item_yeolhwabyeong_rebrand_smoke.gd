extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemThrowMolotovRenderer := preload("res://scripts/items/active_item_throw_molotov_renderer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const EXPECTED_ICON_PATH := "res://assets/sprites/items/molotov_icon_hq_v1.png"
const LOCALIZED_NAMES := [
	[LanguageSettings.LANGUAGE_ENGLISH, "Blazing Flask"],
	[LanguageSettings.LANGUAGE_CHINESE, "烈火瓶"],
	[LanguageSettings.LANGUAGE_JAPANESE, "烈火瓶"],
	[LanguageSettings.LANGUAGE_SPANISH, "Frasco Ígneo"],
	[LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL, "Frasco Ardente"],
	[LanguageSettings.LANGUAGE_RUSSIAN, "Пылающая бутыль"],
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
		print("active_item_yeolhwabyeong_rebrand_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_and_icon() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	var catalog := ActiveItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("molotov")
	_expect(str(item_data.get("display_name", "")) == "열화병", "molotov should be rebranded to Yeolhwabyeong")
	_expect(str(item_data.get("description", "")).begins_with("열화병을 던져"), "Yeolhwabyeong tooltip should use the rebranded name")
	_expect(ActiveItemCatalog.MOLOTOV_ICON_PATH == EXPECTED_ICON_PATH, "Yeolhwabyeong should use the generated earthenware icon")
	_expect(ActiveItemThrowMolotovRenderer.MOLOTOV_ICON_PATH == EXPECTED_ICON_PATH, "the thrown projectile should share the Yeolhwabyeong catalog icon")

	var texture: Texture2D = load(EXPECTED_ICON_PATH) as Texture2D
	_expect(texture != null, "Yeolhwabyeong generated icon should load")
	if texture == null:
		return
	_expect(texture.get_size() == Vector2(256.0, 256.0), "Yeolhwabyeong icon should use the 256px HQ contract")
	var image: Image = texture.get_image()
	var semi_count := 0
	for y_value in range(image.get_height()):
		for x_value in range(image.get_width()):
			var alpha: float = image.get_pixel(x_value, y_value).a
			if alpha > 8.0 / 255.0 and alpha <= 200.0 / 255.0:
				semi_count += 1
	_expect(semi_count < image.get_width() * image.get_height() / 4, "Yeolhwabyeong HQ icon should not carry a full-canvas background halo")
	_expect(image.get_pixel(0, 0).a <= 8.0 / 255.0, "Yeolhwabyeong icon corner should be transparent")


func _verify_localization() -> void:
	var catalog := ActiveItemCatalog.new()
	for locale_spec in LOCALIZED_NAMES:
		var language: String = str(locale_spec[0])
		var expected_name: String = str(locale_spec[1])
		LanguageSettings.set_language(language)
		_expect(str(catalog.build_item_by_name("molotov").get("display_name", "")) == expected_name, "%s catalog should localize Yeolhwabyeong" % language)
		_expect(LanguageSettings.translate_text("열화병") == expected_name, "%s exact-text lane should localize Yeolhwabyeong" % language)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_ENGLISH)
	_expect(str(catalog.build_item_by_name("molotov").get("description", "")) == str(LanguageSettings.ACTIVE_ITEM_DESCRIPTION_EN["molotov"]), "English Yeolhwabyeong tooltip should use the localized active-item description")


func _verify_runtime_consumers() -> void:
	var renderer := ActiveItemThrowMolotovRenderer.new()
	renderer.prewarm_assets()
	_expect(renderer.get_molotov_icon_texture() != null, "Yeolhwabyeong projectile icon should prewarm")
	var pickup_source := FileAccess.get_file_as_string("res://scripts/items/active_item_pickup_feedback.gd")
	var pandora_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_pandora_legacy_runtime.gd")
	var commando_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_catalog_build_router.gd")
	var debug_source := FileAccess.get_file_as_string("res://scripts/items/active_item_debug_spawn_menu.gd")
	_expect(pickup_source.find("\"molotov\": \"열화병\"") >= 0, "pickup fallback should use Yeolhwabyeong")
	_expect(pandora_source.find("\"molotov\": \"열화병\"") >= 0, "Pandora fallback should use Yeolhwabyeong")
	_expect(commando_source.find("폭화탄, 환광탄, 열화병") >= 0, "Commando Arm tooltip should use Pokhwatan and Yeolhwabyeong")
	_expect(debug_source.find("\"molotov\",") >= 0, "F2 active-item menu should retain the molotov compatibility id")


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
