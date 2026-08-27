extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemDebugSpawnMenu := preload("res://scripts/items/active_item_debug_spawn_menu.gd")
const ActiveItemPickupFeedback := preload("res://scripts/items/active_item_pickup_feedback.gd")
const ActiveItemStopwatchRuntime := preload("res://scripts/items/active_item_stopwatch_runtime.gd")
const ActiveItemYosulPocketWatchRenderer := preload("res://scripts/items/active_item_yosul_pocket_watch_renderer.gd")
const GameplayItemModuleCatalog := preload("res://scripts/resources/gameplay_item_module_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const MythicItemPandoraLegacyRuntime := preload("res://scripts/items/mythic_item_pandora_legacy_runtime.gd")

const ICON_PATH := "res://assets/sprites/items/stopwatch_icon_hq_v1.png"
const EXPECTED_LOCALIZED_NAMES := {
	LanguageSettings.LANGUAGE_KOREAN: "요술 회중시계",
	LanguageSettings.LANGUAGE_ENGLISH: "Magical Pocket Watch",
	LanguageSettings.LANGUAGE_CHINESE: "魔法怀表",
	LanguageSettings.LANGUAGE_JAPANESE: "魔法の懐中時計",
	LanguageSettings.LANGUAGE_SPANISH: "Reloj de bolsillo mágico",
	LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: "Relógio de bolso mágico",
	LanguageSettings.LANGUAGE_RUSSIAN: "Волшебные карманные часы",
}

var _failures: Array[String] = []


func _init() -> void:
	_verify_catalog_and_compatibility_id()
	_verify_localization()
	_verify_fallback_consumers()
	_verify_icon_asset()
	_verify_vfx_contract()
	_verify_gameplay_contract_is_unchanged()
	_verify_old_player_name_is_retired()
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("active_item_yosul_pocket_watch_rebrand_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_catalog_and_compatibility_id() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var catalog := ActiveItemCatalog.new()
	var item: Dictionary = catalog.build_item_by_name("stopwatch")
	_expect(not item.is_empty(), "stopwatch compatibility ID should still build")
	_expect(str(item.get("name", "")) == "stopwatch", "catalog name should preserve stopwatch")
	_expect(str(item.get("effect", "")) == "stopwatch", "effect routing should preserve stopwatch")
	_expect(str(item.get("display_name", "")) == "요술 회중시계", "Korean player name should be Yosul Pocket Watch")
	_expect(str(item.get("description", "")).contains("태엽을 멈춰"), "tooltip should explain the magical winding-stop fantasy")
	_expect(str(item.get("description", "")).contains("공과 전투의 흐름을 정지"), "tooltip should preserve the time-stop behavior")
	_expect(str(item.get("icon_path", "")) == ICON_PATH, "catalog should route the compatibility ID to the generated pocket-watch icon")
	_expect(catalog.build_item_by_name("yosul_pocket_watch").is_empty(), "the player-facing rebrand must not create a second runtime ID")


func _verify_localization() -> void:
	var catalog := ActiveItemCatalog.new()
	for locale: String in EXPECTED_LOCALIZED_NAMES.keys():
		LanguageSettings.set_test_locale_override(locale)
		var expected_name: String = str(EXPECTED_LOCALIZED_NAMES[locale])
		var item: Dictionary = catalog.build_item_by_name("stopwatch")
		_expect(str(item.get("display_name", "")) == expected_name, "%s display name should localize Yosul Pocket Watch" % locale)
		_expect(LanguageSettings.translate_text("요술 회중시계") == expected_name, "%s exact-text lane should localize Yosul Pocket Watch" % locale)
		if locale != LanguageSettings.LANGUAGE_KOREAN:
			_expect(not _contains_hangul(str(item.get("description", ""))), "%s description should not leak Korean copy" % locale)


func _verify_fallback_consumers() -> void:
	_expect(str(ActiveItemPickupFeedback.ITEM_NAME_KO.get("stopwatch", "")) == "요술 회중시계", "pickup fallback should use Yosul Pocket Watch")
	_expect(str(MythicItemPandoraLegacyRuntime.ACTIVE_ITEM_KOREAN_NAMES.get("stopwatch", "")) == "요술 회중시계", "Pandora fallback should use Yosul Pocket Watch")
	_expect(ActiveItemDebugSpawnMenu.DEBUG_ENTRY_ORDER.has("stopwatch"), "debug spawn menu should preserve stopwatch")
	var debug_source := FileAccess.get_file_as_string("res://scripts/items/active_item_debug_spawn_menu.gd")
	_expect(debug_source.contains("요술 태엽 / 시간 정지"), "debug subtitle should use the pocket-watch fantasy")


func _verify_icon_asset() -> void:
	_expect(FileAccess.file_exists(ICON_PATH), "Yosul Pocket Watch icon should exist")
	var image := Image.load_from_file(ProjectSettings.globalize_path(ICON_PATH))
	_expect(image != null and not image.is_empty(), "Yosul Pocket Watch icon should load")
	if image == null or image.is_empty():
		return
	_expect(image.get_size() == Vector2i(256, 256), "Yosul Pocket Watch icon should use the 256px HQ contract")
	var semi_count := 0
	for y_value in range(image.get_height()):
		for x_value in range(image.get_width()):
			var alpha: float = image.get_pixel(x_value, y_value).a
			if alpha > 8.0 / 255.0 and alpha <= 200.0 / 255.0:
				semi_count += 1
	_expect(semi_count < image.get_width() * image.get_height() / 4, "Yosul Pocket Watch final icon should not carry a full-canvas chroma halo")
	for point: Vector2i in [Vector2i.ZERO, Vector2i(255, 0), Vector2i(0, 255), Vector2i(255, 255)]:
		_expect(image.get_pixelv(point).a <= 8.0 / 255.0, "Yosul Pocket Watch icon corners should be transparent")
	var used_rect: Rect2i = image.get_used_rect()
	_expect(used_rect.size.x >= 180 and used_rect.size.x <= 256, "Yosul Pocket Watch HQ icon should keep a readable subject width")
	_expect(used_rect.size.y >= 180 and used_rect.size.y <= 256, "Yosul Pocket Watch HQ icon should keep a readable subject height")


func _verify_vfx_contract() -> void:
	var renderer := ActiveItemYosulPocketWatchRenderer.new()
	renderer.prewarm_assets()
	var status: Dictionary = renderer.get_asset_status()
	_expect(str(status.get("icon_path", "")) == ICON_PATH, "Yosul Pocket Watch renderer should share the catalog icon")
	_expect(bool(status.get("icon_ready", false)), "Yosul Pocket Watch renderer should prewarm its icon")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/items/active_item_yosul_pocket_watch_renderer.gd")
	var facade_source := FileAccess.get_file_as_string("res://scripts/items/active_item_effect_renderer.gd")
	_expect(renderer_source.contains("_draw_time_binding_ring"), "Yosul Pocket Watch should draw a magical time-binding ring")
	_expect(renderer_source.contains("_draw_binding_diamond"), "Yosul Pocket Watch should draw a four-direction binding seal")
	_expect(renderer_source.contains("recovery_active"), "Yosul Pocket Watch should visibly unwind during recovery")
	_expect(renderer_source.contains("draw_texture_rect"), "generated pocket-watch art should supply the field-effect identity")
	_expect(not renderer_source.contains("STOPWATCH_FACE_NUMBERS"), "Yosul Pocket Watch should not retain the numbered stopwatch face")
	_expect(facade_source.contains("_yosul_pocket_watch_renderer.draw"), "active item renderer should delegate the field VFX to Yosul Pocket Watch")
	_expect(GameplayItemModuleCatalog.MODULES.has("active_item_yosul_pocket_watch_renderer"), "item module catalog should list the Yosul Pocket Watch renderer")


func _verify_gameplay_contract_is_unchanged() -> void:
	_expect(is_equal_approx(ActiveItemStopwatchRuntime.STOPWATCH_DURATION_FRAMES, 120.0), "rebrand should preserve the two-second time freeze")
	_expect(is_equal_approx(ActiveItemStopwatchRuntime.STOPWATCH_RECOVERY_FRAMES, 60.0), "rebrand should preserve the one-second recovery")
	_expect(ActiveItemCatalog.FIELD_SPAWN_ORDER.has("stopwatch"), "field acquisition should retain the stopwatch compatibility ID")


func _verify_old_player_name_is_retired() -> void:
	for path: String in [
		"res://scripts/items/active_item_catalog.gd",
		"res://scripts/items/active_item_pickup_feedback.gd",
		"res://scripts/items/mythic_item_pandora_legacy_runtime.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		_expect(not source.contains("스탑워치"), "%s should retire the old Korean player name" % path)


func _contains_hangul(value: String) -> bool:
	for index: int in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		if codepoint >= 0xAC00 and codepoint <= 0xD7A3:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
