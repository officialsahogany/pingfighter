extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemDebugSpawnMenu := preload("res://scripts/items/active_item_debug_spawn_menu.gd")
const ActiveItemHeupinjinRenderer := preload("res://scripts/items/active_item_heupinjin_renderer.gd")
const ActiveItemPickupFeedback := preload("res://scripts/items/active_item_pickup_feedback.gd")
const GameplayItemModuleCatalog := preload("res://scripts/resources/gameplay_item_module_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const MythicItemPandoraLegacyRuntime := preload("res://scripts/items/mythic_item_pandora_legacy_runtime.gd")

const ICON_PATH := "res://assets/sprites/items/magnet_field_icon_hq_v1.png"
const EXPECTED_LOCALIZED_NAMES := {
	"ko": "흡인진",
	"en": "Attraction Formation",
	"zh": "吸引阵",
	"ja": "吸引陣",
	"es": "Formación de Atracción",
	"pt-BR": "Formação de Atração",
	"ru": "Формация притяжения",
}

var _failures: Array[String] = []


func _init() -> void:
	_verify_catalog_and_compatibility_id()
	_verify_localization()
	_verify_fallback_consumers()
	_verify_icon_asset()
	_verify_vfx_contract()
	_verify_old_player_name_is_retired()
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("active_item_heupinjin_rebrand_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_catalog_and_compatibility_id() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var catalog := ActiveItemCatalog.new()
	var item: Dictionary = catalog.build_item_by_name("magnet_field")
	_expect(not item.is_empty(), "magnet_field compatibility ID should still build")
	_expect(str(item.get("name", "")) == "magnet_field", "catalog name should preserve magnet_field")
	_expect(str(item.get("effect", "")) == "magnet_field", "effect routing should preserve magnet_field")
	_expect(str(item.get("display_name", "")) == "흡인진", "Korean player name should be Heupinjin")
	_expect(str(item.get("description", "")).contains("흡인진을 펼쳐"), "tooltip should describe unfolding the formation")
	_expect(str(item.get("description", "")).contains("공을 플레이어 쪽으로 끌어당깁니다"), "tooltip should preserve the pull behavior")
	_expect(str(item.get("icon_path", "")) == ICON_PATH, "catalog should route Heupinjin to its versioned icon")
	_expect(catalog.build_item_by_name("heupinjin").is_empty(), "the player-facing rebrand must not create a second runtime ID")


func _verify_localization() -> void:
	var catalog := ActiveItemCatalog.new()
	for locale: String in EXPECTED_LOCALIZED_NAMES.keys():
		LanguageSettings.set_test_locale_override(locale)
		var item: Dictionary = catalog.build_item_by_name("magnet_field")
		var expected_name: String = str(EXPECTED_LOCALIZED_NAMES[locale])
		_expect(str(item.get("display_name", "")) == expected_name, "%s display name should localize Heupinjin" % locale)
		_expect(LanguageSettings.translate_text("흡인진") == expected_name, "%s exact-text lane should localize Heupinjin" % locale)
		if locale != LanguageSettings.LANGUAGE_KOREAN:
			_expect(not _contains_hangul(str(item.get("description", ""))), "%s description should not leak Korean copy" % locale)


func _verify_fallback_consumers() -> void:
	_expect(str(ActiveItemPickupFeedback.ITEM_NAME_KO.get("magnet_field", "")) == "흡인진", "pickup fallback should use Heupinjin")
	_expect(str(MythicItemPandoraLegacyRuntime.ACTIVE_ITEM_KOREAN_NAMES.get("magnet_field", "")) == "흡인진", "Pandora fallback should use Heupinjin")
	_expect(ActiveItemDebugSpawnMenu.DEBUG_ENTRY_ORDER.has("magnet_field"), "debug spawn menu should preserve magnet_field")
	var debug_source := FileAccess.get_file_as_string("res://scripts/items/active_item_debug_spawn_menu.gd")
	_expect(debug_source.contains("흡인진 전개 / 공 유도"), "debug subtitle should use Heupinjin formation language")


func _verify_icon_asset() -> void:
	_expect(FileAccess.file_exists(ICON_PATH), "Heupinjin icon should exist")
	var image := Image.load_from_file(ProjectSettings.globalize_path(ICON_PATH))
	_expect(image != null and not image.is_empty(), "Heupinjin icon should load")
	if image == null or image.is_empty():
		return
	_expect(image.get_size() == Vector2i(256, 256), "Heupinjin icon should use the 256px HQ contract")
	var semi_count := 0
	for y_value in range(image.get_height()):
		for x_value in range(image.get_width()):
			var alpha: float = image.get_pixel(x_value, y_value).a
			if alpha > 8.0 / 255.0 and alpha <= 200.0 / 255.0:
				semi_count += 1
	_expect(semi_count < image.get_width() * image.get_height() / 4, "Heupinjin final icon should not carry a full-canvas chroma halo")
	for point: Vector2i in [Vector2i.ZERO, Vector2i(255, 0), Vector2i(0, 255), Vector2i(255, 255)]:
		_expect(image.get_pixelv(point).a <= 8.0 / 255.0, "Heupinjin icon corners should be transparent")
	var used_rect: Rect2i = image.get_used_rect()
	_expect(used_rect.size.x >= 180 and used_rect.size.x <= 256, "Heupinjin HQ icon should keep a readable subject width")
	_expect(used_rect.size.y >= 180 and used_rect.size.y <= 256, "Heupinjin HQ icon should keep a readable subject height")


func _verify_vfx_contract() -> void:
	var renderer := ActiveItemHeupinjinRenderer.new()
	renderer.prewarm_assets()
	var status: Dictionary = renderer.get_asset_status()
	_expect(str(status.get("icon_path", "")) == ICON_PATH, "Heupinjin renderer should share the catalog icon")
	_expect(bool(status.get("icon_ready", false)), "Heupinjin renderer should prewarm its icon")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/items/active_item_heupinjin_renderer.gd")
	var facade_source := FileAccess.get_file_as_string("res://scripts/items/active_item_effect_renderer.gd")
	var timer_source := FileAccess.get_file_as_string("res://scripts/items/active_item_timer_gauge_renderer.gd")
	var particles_source := FileAccess.get_file_as_string("res://scripts/items/active_item_magnet_field_particles.gd")
	_expect(renderer_source.contains("_draw_elliptical_octagon"), "Heupinjin should draw an eight-sided formation")
	_expect(renderer_source.contains("_draw_inward_channels"), "Heupinjin should draw visibly inward-moving channels")
	_expect(renderer_source.contains("AGED_GOLD") and renderer_source.contains("JADE_COLOR"), "Heupinjin should use its gold and jade ritual palette")
	_expect(facade_source.contains("_heupinjin_renderer.draw"), "active item renderer should delegate the field VFX to Heupinjin")
	_expect(timer_source.contains("_draw_heupinjin_octagon"), "duration gauge should use the Heupinjin plaque language")
	_expect(particles_source.contains("RandomNumberGenerator"), "Heupinjin presentation particles should own an independent RNG")
	_expect(GameplayItemModuleCatalog.MODULES.has("active_item_heupinjin_renderer"), "item module catalog should list the Heupinjin renderer")


func _verify_old_player_name_is_retired() -> void:
	for path: String in [
		"res://scripts/items/active_item_catalog.gd",
		"res://scripts/items/active_item_pickup_feedback.gd",
		"res://scripts/items/mythic_item_pandora_legacy_runtime.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		_expect(not source.contains("자기장"), "%s should retire the old Korean player name" % path)


func _contains_hangul(value: String) -> bool:
	for index: int in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		if codepoint >= 0xAC00 and codepoint <= 0xD7A3:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
