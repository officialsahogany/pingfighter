extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemThrowGrenadeRenderer := preload("res://scripts/items/active_item_throw_grenade_renderer.gd")
const GrenadeExplosionDrawer := preload("res://scripts/effects/grenade_explosion_drawer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const EXPECTED_ICON_PATH := "res://assets/sprites/items/pokhwatan_icon_imagegen_v1.png"
const EXPECTED_IMPACT_PATH := "res://assets/sprites/effects/items/jinroe_tan/jinroe_tan_impact_stamp_imagegen_v1.png"
const LOCALIZED_NAMES := [
	[LanguageSettings.LANGUAGE_ENGLISH, "Gunpowder Bomb"],
	[LanguageSettings.LANGUAGE_CHINESE, "爆火弹"],
	[LanguageSettings.LANGUAGE_JAPANESE, "爆火弾"],
	[LanguageSettings.LANGUAGE_SPANISH, "Bomba de pólvora"],
	[LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL, "Bomba de pólvora"],
	[LanguageSettings.LANGUAGE_RUSSIAN, "Пороховая бомба"],
]

var _failures: Array[String] = []
var _language_settings_snapshot: Dictionary = {}


func _init() -> void:
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	_verify_catalog_and_assets()
	_verify_localization()
	_verify_runtime_consumers()
	_restore_language_settings_snapshot()

	if _failures.is_empty():
		print("active_item_pokhwatan_rebrand_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_and_assets() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	var catalog := ActiveItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("grenade")
	_expect(str(item_data.get("name", "")) == "grenade", "Pokhwatan should preserve the grenade compatibility id")
	_expect(str(item_data.get("effect", "")) == "grenade", "Pokhwatan should preserve the grenade effect route")
	_expect(str(item_data.get("display_name", "")) == "폭화탄", "grenade should be rebranded to the three-syllable Pokhwatan name")
	var description := str(item_data.get("description", ""))
	_expect(description.find("화약") >= 0 and description.find("무쇠 폭화탄") >= 0, "Pokhwatan tooltip should describe the cast-iron gunpowder design")
	_expect(description.find("진뢰탄") < 0 and description.find("뇌문") < 0, "Pokhwatan tooltip should remove the old lightning-talisman theme")
	_expect(catalog.build_item_by_name("pokhwatan").is_empty(), "the player-facing rebrand must not create a second runtime id")
	_expect(ActiveItemCatalog.GRENADE_ICON_PATH == EXPECTED_ICON_PATH, "Pokhwatan should use its generated cast-iron icon")
	_expect(ActiveItemThrowGrenadeRenderer.POKHWATAN_PROJECTILE_PATH == EXPECTED_ICON_PATH, "the thrown projectile should share the Pokhwatan catalog icon")
	_expect(GrenadeExplosionDrawer.POKHWATAN_IMPACT_STAMP_PATH == EXPECTED_IMPACT_PATH, "Pokhwatan should retain the previously accepted impact stamp")
	_expect(GrenadeExplosionDrawer.POKHWATAN_EXPLOSION_STYLE == "jinroe_tan", "Pokhwatan should preserve the saved explosion-style value")
	_expect(GrenadeExplosionDrawer.JINROE_TAN_EXPLOSION_STYLE == GrenadeExplosionDrawer.POKHWATAN_EXPLOSION_STYLE, "the former explosion-style symbol should remain a compatibility alias")
	_verify_texture_alpha_contract(EXPECTED_ICON_PATH, "Pokhwatan icon")
	_verify_texture_alpha_contract(EXPECTED_IMPACT_PATH, "retained impact stamp")


func _verify_localization() -> void:
	var catalog := ActiveItemCatalog.new()
	for locale_spec in LOCALIZED_NAMES:
		var language: String = str(locale_spec[0])
		var expected_name: String = str(locale_spec[1])
		LanguageSettings.set_language(language)
		_expect(str(catalog.build_item_by_name("grenade").get("display_name", "")) == expected_name, "%s catalog should localize Pokhwatan" % language)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_ENGLISH)
	_expect(str(catalog.build_item_by_name("grenade").get("description", "")) == str(LanguageSettings.ACTIVE_ITEM_DESCRIPTION_EN["grenade"]), "English Pokhwatan tooltip should use the localized active-item description")
	_expect(str(LanguageSettings.ACTIVE_ITEM_DESCRIPTION_EN["grenade"]).find("talisman") < 0, "English Pokhwatan tooltip should remove the old talisman theme")


func _verify_runtime_consumers() -> void:
	var renderer := ActiveItemThrowGrenadeRenderer.new()
	renderer.prewarm_assets()
	_expect(renderer.get_grenade_projectile_texture() != null, "Pokhwatan projectile icon should prewarm")
	_expect(GrenadeExplosionDrawer.are_texture_assets_ready(), "the retained impact stamp should prewarm with the shared explosion textures")
	var pickup_source := FileAccess.get_file_as_string("res://scripts/items/active_item_pickup_feedback.gd")
	var pandora_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_pandora_legacy_runtime.gd")
	var commando_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_catalog_build_router.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/items/active_item_throw_grenade_renderer.gd")
	_expect(pickup_source.find("\"grenade\": \"폭화탄\"") >= 0, "pickup fallback should use Pokhwatan")
	_expect(pandora_source.find("\"grenade\": \"폭화탄\"") >= 0, "Pandora fallback should use Pokhwatan")
	_expect(commando_source.find("폭화탄, 환광탄, 열화병") >= 0, "Commando Arm tooltip should use Pokhwatan")
	_expect(renderer_source.find("_draw_pokhwatan_trail(") >= 0, "Pokhwatan projectile should use the smoke-and-ember trail")
	_expect(renderer_source.find("_draw_jinroe_tan_trail(canvas, grenade.get") < 0, "the live projectile path should not call the former themed trail")


func _verify_texture_alpha_contract(path: String, label: String) -> void:
	var texture: Texture2D = load(path) as Texture2D
	_expect(texture != null, "%s should load" % label)
	if texture == null:
		return
	_expect(texture.get_size() == Vector2(256.0, 256.0), "%s should use the 256px HQ contract" % label)
	var image: Image = texture.get_image()
	_expect(image.get_pixel(0, 0).a <= 8.0 / 255.0, "%s corner should be transparent" % label)
	_expect(image.get_pixel(image.get_width() - 1, image.get_height() - 1).a <= 8.0 / 255.0, "%s opposite corner should be transparent" % label)


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
