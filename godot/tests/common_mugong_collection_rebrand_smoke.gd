extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")

const COLLECTION_MANIFEST_PATH := "res://assets/sprites/perks/common_mugong_collection_manifest.json"
const ICON_SIZE := Vector2i(256, 256)
const EXPECTED := {
	"common_bulk_up": ["철산공", "res://assets/sprites/perks/common_bulk_up_perk_icon.png"],
	"common_swiftness": ["유운보", "res://assets/sprites/perks/common_swiftness_perk_icon.png"],
	"common_expansion": ["광맥결", "res://assets/sprites/perks/common_expansion_perk_icon.png"],
	"training_mastery": ["연공심법", "res://assets/sprites/perks/training_mastery_perk_icon.png"],
	"perk_boost_charge": ["축기결", "res://assets/sprites/perks/perk_boost_charge_perk_icon_v2.png"],
	"perk_laurel_shield": ["오엽호신", "res://assets/sprites/perks/perk_laurel_shield_perk_icon.png"],
	"dash_lightweight": ["회기보", "res://assets/sprites/perks/dash_lightweight_perk_icon.png"],
	"dash_module_control": ["수세결", "res://assets/sprites/perks/dash_module_control_perk_icon.png"],
	"dash_jump": ["비천보", "res://assets/sprites/perks/dash_jump_perk_icon.png"],
	"dash_acceleration": ["대붕전익", "res://assets/sprites/perks/dash_acceleration_perk_icon.png"],
	"dash_amplification": ["활주구슬", "res://assets/sprites/perks/dash_amplification_perk_icon.png"],
	"item_luck": ["인보결", "res://assets/sprites/perks/item_luck_perk_icon.png"],
	"item_cooldown_mastery": ["순환결", "res://assets/sprites/perks/item_cooldown_mastery_perk_icon.png"],
	"item_gauge_mastery": ["기령심법", "res://assets/sprites/perks/item_gauge_mastery_perk_icon.png"],
	"item_caffeine": ["연효결", "res://assets/sprites/perks/item_caffeine_perk_icon.png"],
	"item_polish": ["개광결", "res://assets/sprites/perks/item_polish_perk_icon.png"],
	"item_recycle": ["환보결", "res://assets/sprites/perks/item_recycle_perk_icon.png"],
	"downtown_treasure_map": ["천기보도", "res://assets/sprites/perks/downtown_treasure_map_perk_icon.png"],
}

var _failed := false


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_test_catalog_and_runtime_paths()
	_test_seven_language_coverage()
	_test_collection_manifest()
	LanguageSettings.set_test_locale_override("")
	PerkConversionFlags.debug_set_enabled(false)
	if _failed:
		quit(1)
		return
	print("common_mugong_collection_rebrand_smoke: ok")
	quit(0)


func _test_catalog_and_runtime_paths() -> void:
	_expect(RuntimePerkCatalog.COMMON_PERKS.size() == EXPECTED.size() + 1, "the catalog should retain eighteen current Mugong plus the legacy common_training definition")
	_expect(RuntimePerkCatalog.TRAINING_MIGRATED_PERK_IDS.has("common_training"), "common_training should be marked as training-migrated")
	var catalog := RuntimePerkCatalog.new()
	var renderer := RuntimePerkIconRenderer.new()
	LanguageSettings.set_test_locale_override("ko")
	_expect(not "common_training" in _ids(catalog.get_choices("smasher", {}, true, 500)), "common_training should not appear in current Mugong offers")
	for perk_id: String in EXPECTED.keys():
		var spec: Array = EXPECTED[perk_id]
		var expected_name := str(spec[0])
		var icon_path := str(spec[1])
		_expect(RuntimePerkCatalog.COMMON_PERKS.has(perk_id), "%s should remain in the common Mugong catalog" % perk_id)
		_expect(str(catalog.get_perk_data(perk_id).get("name", "")) == expected_name, "%s should expose the adopted Korean name" % perk_id)
		_expect(str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get(perk_id, "")) == icon_path, "%s should keep its runtime icon path" % perk_id)
		_expect(str(renderer._get_static_path(perk_id)) == icon_path and renderer.has_icon(perk_id), "%s should resolve through the production icon renderer" % perk_id)
		_expect(not renderer.has_animated_icon(perk_id), "%s should remain static so animation distinguishes Peerless Mugong" % perk_id)
		var image := Image.new()
		_expect(image.load(ProjectSettings.globalize_path(icon_path)) == OK, "%s PNG should load" % perk_id)
		if image.is_empty():
			continue
		_expect(Vector2i(image.get_width(), image.get_height()) == ICON_SIZE, "%s should remain 256x256" % perk_id)
		var used_rect := image.get_used_rect()
		_expect(used_rect.position.x >= 8 and used_rect.position.y >= 8, "%s should keep top-left alpha padding" % perk_id)
		_expect(used_rect.end.x <= 248 and used_rect.end.y <= 248, "%s should keep bottom-right alpha padding" % perk_id)
		for corner in [Vector2i(0, 0), Vector2i(255, 0), Vector2i(0, 255), Vector2i(255, 255)]:
			_expect(is_zero_approx(image.get_pixelv(corner).a), "%s corners should remain transparent" % perk_id)


func _test_seven_language_coverage() -> void:
	var catalog := RuntimePerkCatalog.new()
	for locale: String in LanguageSettings.SUPPORTED_LANGUAGES:
		LanguageSettings.set_test_locale_override(locale)
		for perk_id: String in EXPECTED.keys():
			var data: Dictionary = catalog.get_perk_data(perk_id)
			_expect(str(data.get("name", "")).strip_edges() != "", "%s name should exist for %s" % [perk_id, locale])
			_expect(str(data.get("detail", "")).strip_edges() != "", "%s detail should exist for %s" % [perk_id, locale])


func _test_collection_manifest() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COLLECTION_MANIFEST_PATH))
	_expect(parsed is Dictionary, "the common Mugong collection manifest should parse")
	if not parsed is Dictionary:
		return
	var manifest: Dictionary = parsed
	_expect(str(manifest.get("collection_id", "")) == "common_mugong_hanji_seals_v1", "the collection id should stay stable")
	var assets: Array = manifest.get("assets", []) as Array
	_expect(assets.size() == EXPECTED.size(), "the collection manifest should list all 18 current common Mugong")
	var seen: Dictionary = {}
	for asset_value: Variant in assets:
		if not asset_value is Dictionary:
			continue
		var asset: Dictionary = asset_value
		var perk_id := str(asset.get("perk_id", ""))
		seen[perk_id] = true
		if not EXPECTED.has(perk_id):
			continue
		var spec: Array = EXPECTED[perk_id]
		var icon_path := str(spec[1])
		var manifest_path := str(asset.get("manifest_path", ""))
		_expect(str(asset.get("display_name_ko", "")) == str(spec[0]), "%s collection name should match the catalog" % perk_id)
		_expect(str(asset.get("static_path", "")) == icon_path, "%s collection path should match runtime" % perk_id)
		var individual_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		_expect(individual_value is Dictionary, "%s individual manifest should parse" % perk_id)
		if individual_value is Dictionary:
			var individual: Dictionary = individual_value
			_expect(str(individual.get("perk_id", "")) == perk_id, "%s individual manifest should preserve its id" % perk_id)
			_expect(str(individual.get("runtime_path", "")) == icon_path, "%s individual manifest should preserve its path" % perk_id)
			var qa: Dictionary = individual.get("qa", {}) as Dictionary
			_expect(str(qa.get("sha256", "")) == FileAccess.get_sha256(icon_path), "%s individual manifest hash should match the accepted PNG" % perk_id)
	for perk_id: String in EXPECTED.keys():
		_expect(seen.has(perk_id), "%s should appear in the collection manifest" % perk_id)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _ids(entries: Array) -> Array[String]:
	var result: Array[String] = []
	for entry_value: Variant in entries:
		if entry_value is Dictionary:
			result.append(str((entry_value as Dictionary).get("id", "")))
	return result
