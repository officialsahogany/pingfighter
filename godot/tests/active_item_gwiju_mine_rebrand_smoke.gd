extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemDebugSpawnMenu := preload("res://scripts/items/active_item_debug_spawn_menu.gd")
const ActiveItemPickupFeedback := preload("res://scripts/items/active_item_pickup_feedback.gd")
const ActiveItemThrowSpiderMineRenderer := preload("res://scripts/items/active_item_throw_spider_mine_renderer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const MythicItemPandoraLegacyRuntime := preload("res://scripts/items/mythic_item_pandora_legacy_runtime.gd")

const EXPECTED_LOCALIZED_NAMES := {
	"ko": "귀주뢰",
	"en": "Gwiju Mine",
	"zh": "鬼蛛雷",
	"ja": "鬼蛛雷",
	"es": "Mina Gwiju",
	"pt-BR": "Mina Gwiju",
	"ru": "Мина «Квиджу»",
}
const ICON_PATH := "res://assets/sprites/items/spider_mine_icon_hq_v1.png"
const SHEET_PATHS := [
	"res://assets/sprites/items/gwiju_mine_crawl_sheet_imagegen_v1.png",
	"res://assets/sprites/items/gwiju_mine_deploy_sheet_imagegen_v1.png",
	"res://assets/sprites/items/gwiju_mine_installed_idle_sheet_imagegen_v1.png",
]

var _failures: Array[String] = []


func _init() -> void:
	_verify_catalog_and_compatibility_id()
	_verify_all_localized_names()
	_verify_fallback_consumers()
	_verify_versioned_visual_assets()
	_verify_old_player_name_is_retired()
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("active_item_gwiju_mine_rebrand_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_catalog_and_compatibility_id() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var catalog := ActiveItemCatalog.new()
	var item: Dictionary = catalog.build_item_by_name("spider_mine")
	_expect(not item.is_empty(), "spider_mine compatibility ID should still build")
	_expect(str(item.get("name", "")) == "spider_mine", "catalog name should preserve spider_mine")
	_expect(str(item.get("effect", "")) == "spider_mine", "effect routing should preserve spider_mine")
	_expect(str(item.get("display_name", "")) == "귀주뢰", "Korean player name should be Gwiju Mine")
	_expect(str(item.get("description", "")).contains("벽을 타고"), "description should preserve the wall-crawl behavior")
	_expect(str(item.get("description", "")).contains("폭발해 이동을 늦춥니다"), "description should preserve detonation and slow behavior")
	_expect(str(item.get("icon_path", "")) == ICON_PATH, "catalog should use the versioned Gwiju icon")
	_expect(catalog.build_item_by_name("gwiju_mine").is_empty(), "the player-facing rebrand must not create a second runtime ID")


func _verify_all_localized_names() -> void:
	var catalog := ActiveItemCatalog.new()
	for locale: String in EXPECTED_LOCALIZED_NAMES.keys():
		LanguageSettings.set_test_locale_override(locale)
		var item: Dictionary = catalog.build_item_by_name("spider_mine")
		_expect(
			str(item.get("display_name", "")) == str(EXPECTED_LOCALIZED_NAMES[locale]),
			"%s display name should localize the Gwiju rebrand" % locale
		)
		_expect(LanguageSettings.translate_text("귀주뢰") == str(EXPECTED_LOCALIZED_NAMES[locale]), "%s exact-text lane should localize Gwiju Mine" % locale)
		if locale != LanguageSettings.LANGUAGE_KOREAN:
			_expect(not _contains_hangul(str(item.get("description", ""))), "%s description should not leak Korean copy" % locale)


func _verify_fallback_consumers() -> void:
	_expect(str(ActiveItemPickupFeedback.ITEM_NAME_KO.get("spider_mine", "")) == "귀주뢰", "pickup fallback should use Gwiju Mine")
	_expect(str(MythicItemPandoraLegacyRuntime.ACTIVE_ITEM_KOREAN_NAMES.get("spider_mine", "")) == "귀주뢰", "Pandora selection fallback should use Gwiju Mine")
	_expect(ActiveItemDebugSpawnMenu.DEBUG_ENTRY_ORDER.has("spider_mine"), "debug spawn menu should preserve the spider_mine entry")
	var debug_source := FileAccess.get_file_as_string("res://scripts/items/active_item_debug_spawn_menu.gd")
	_expect(debug_source.contains("벽타는 봉인뢰"), "debug subtitle should use the rebranded field-object language")


func _verify_versioned_visual_assets() -> void:
	_verify_alpha_asset(ICON_PATH, Vector2i(256, 256), false)
	for path: String in SHEET_PATHS:
		_verify_alpha_asset(path, Vector2i(2048, 2048), true)
	var renderer := ActiveItemThrowSpiderMineRenderer.new()
	renderer.prewarm_assets()
	var status: Dictionary = renderer.get_asset_status()
	_expect(str(status.get("crawl_sheet_path", "")) == SHEET_PATHS[0], "renderer should route crawl frames to Gwiju art")
	_expect(str(status.get("deploy_sheet_path", "")) == SHEET_PATHS[1], "renderer should route deploy frames to Gwiju art")
	_expect(str(status.get("installed_idle_sheet_path", "")) == SHEET_PATHS[2], "renderer should route armed frames to Gwiju art")


func _verify_alpha_asset(path: String, expected_size: Vector2i, verify_cell_edges: bool) -> void:
	_expect(FileAccess.file_exists(path), "%s should exist" % path)
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	_expect(image != null and not image.is_empty(), "%s should load" % path)
	if image == null or image.is_empty():
		return
	_expect(image.get_size() == expected_size, "%s should keep size %s" % [path, str(expected_size)])
	var size: Vector2i = image.get_size()
	for point: Vector2i in [Vector2i.ZERO, Vector2i(size.x - 1, 0), Vector2i(0, size.y - 1), size - Vector2i.ONE]:
		_expect(image.get_pixelv(point).a <= 0.01, "%s should have transparent corners" % path)
	if not verify_cell_edges:
		return
	for row: int in range(4):
		for column: int in range(4):
			var left := column * 512
			var top := row * 512
			for offset: int in range(512):
				_expect(image.get_pixel(left, top + offset).a <= 0.01, "%s cell %d,%d should have a transparent left edge" % [path, column, row])
				_expect(image.get_pixel(left + 511, top + offset).a <= 0.01, "%s cell %d,%d should have a transparent right edge" % [path, column, row])
				_expect(image.get_pixel(left + offset, top).a <= 0.01, "%s cell %d,%d should have a transparent top edge" % [path, column, row])
				_expect(image.get_pixel(left + offset, top + 511).a <= 0.01, "%s cell %d,%d should have a transparent bottom edge" % [path, column, row])


func _verify_old_player_name_is_retired() -> void:
	for path: String in [
		"res://scripts/items/active_item_catalog.gd",
		"res://scripts/items/active_item_pickup_feedback.gd",
		"res://scripts/items/mythic_item_pandora_legacy_runtime.gd",
		"res://scripts/items/active_item_debug_spawn_menu.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		_expect(not source.contains("스파이더지뢰"), "%s should retire the old Korean player name" % path)


func _contains_hangul(value: String) -> bool:
	for index: int in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		if codepoint >= 0xAC00 and codepoint <= 0xD7A3:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
