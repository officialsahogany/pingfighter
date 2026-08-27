extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemChukjibuRenderer := preload("res://scripts/items/active_item_chukjibu_renderer.gd")
const ActiveItemDashBoostRuntime := preload("res://scripts/items/active_item_dash_boost_runtime.gd")
const GameplayItemModuleCatalog := preload("res://scripts/resources/gameplay_item_module_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const EXPECTED_ICON_PATH := "res://assets/sprites/items/dash_boost_icon_hq_v1.png"
const EXPECTED_SEAL_PATH := "res://assets/sprites/effects/items/chukjibu_ground_seal_imagegen_v1.png"
const LOCALIZED_NAMES := [
	[LanguageSettings.LANGUAGE_ENGLISH, "Chukji Talisman"],
	[LanguageSettings.LANGUAGE_CHINESE, "缩地符"],
	[LanguageSettings.LANGUAGE_JAPANESE, "縮地符"],
	[LanguageSettings.LANGUAGE_SPANISH, "Talismán Chukji"],
	[LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL, "Talismã Chukji"],
	[LanguageSettings.LANGUAGE_RUSSIAN, "Талисман сжатия земли"],
]

var _failures: Array[String] = []
var _language_settings_snapshot: Dictionary = {}


func _init() -> void:
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	_verify_catalog_and_assets()
	_verify_localization()
	_verify_runtime_consumers()
	_verify_vfx_contract()
	_restore_language_settings_snapshot()

	if _failures.is_empty():
		print("active_item_chukjibu_rebrand_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_and_assets() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	var catalog := ActiveItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("dash_boost")
	_expect(str(item_data.get("display_name", "")) == "축지부", "dash_boost should be rebranded to Chukjibu")
	_expect(str(item_data.get("description", "")).begins_with("축지술로"), "Chukjibu tooltip should communicate the folded-ground fantasy")
	_expect(ActiveItemCatalog.DASH_BOOST_ICON_PATH == EXPECTED_ICON_PATH, "Chukjibu should use the generated silk talisman icon")

	var texture: Texture2D = load(EXPECTED_ICON_PATH) as Texture2D
	_expect(texture != null, "Chukjibu generated icon should load")
	if texture != null:
		_expect(texture.get_size() == Vector2(256.0, 256.0), "Chukjibu icon should use the 256px HQ contract")
		var image: Image = texture.get_image()
		var semi_count := 0
		for y_value in range(image.get_height()):
			for x_value in range(image.get_width()):
				var alpha: float = image.get_pixel(x_value, y_value).a
				if alpha > 8.0 / 255.0 and alpha <= 200.0 / 255.0:
					semi_count += 1
		_expect(semi_count < image.get_width() * image.get_height() / 4, "Chukjibu final icon should not carry a full-canvas chroma halo")
		_expect(image.get_pixel(0, 0).a <= 8.0 / 255.0, "Chukjibu icon corner should be transparent")

	var seal: Texture2D = load(EXPECTED_SEAL_PATH) as Texture2D
	_expect(seal != null, "Chukjibu folded-road seal should load")
	if seal != null:
		_expect(seal.get_size() == Vector2(64.0, 64.0), "Chukjibu folded-road seal should be prepared at 64px")


func _verify_localization() -> void:
	var catalog := ActiveItemCatalog.new()
	for locale_spec in LOCALIZED_NAMES:
		var language: String = str(locale_spec[0])
		var expected_name: String = str(locale_spec[1])
		LanguageSettings.set_language(language)
		_expect(str(catalog.build_item_by_name("dash_boost").get("display_name", "")) == expected_name, "%s catalog should localize Chukjibu" % language)
		_expect(LanguageSettings.translate_text("축지부") == expected_name, "%s exact-text lane should localize Chukjibu" % language)


func _verify_runtime_consumers() -> void:
	var pickup_source := FileAccess.get_file_as_string("res://scripts/items/active_item_pickup_feedback.gd")
	var pandora_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_pandora_legacy_runtime.gd")
	var debug_source := FileAccess.get_file_as_string("res://scripts/items/active_item_debug_spawn_menu.gd")
	var stats_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_support.gd")
	_expect(pickup_source.find("\"dash_boost\": \"축지부\"") >= 0, "pickup fallback should use Chukjibu")
	_expect(pandora_source.find("\"dash_boost\": \"축지부\"") >= 0, "Pandora fallback should use Chukjibu")
	_expect(debug_source.find("\"dash_boost\",") >= 0 and debug_source.find("축지 활주 무료 / 즉시 충전") >= 0, "F2 menu should retain the compatibility id with Chukjibu glide copy")
	_expect(stats_source.find("\"dash_boost\": \"%s\"" % EXPECTED_ICON_PATH) >= 0, "TAB stat breakdown should share the Chukjibu icon")

	var runtime := ActiveItemDashBoostRuntime.new()
	var state: Dictionary = runtime.start_state()
	_expect(is_equal_approx(float(state.get("timer_frames", 0.0)), 480.0), "Chukjibu should preserve the shipped eight-second duration")
	_expect(is_equal_approx(runtime.get_cost_multiplier(true), 0.0), "Chukjibu should preserve free dash cost")
	_expect(is_equal_approx(runtime.get_cooldown_multiplier(true), 0.01), "Chukjibu should preserve near-instant dash recharge")


func _verify_vfx_contract() -> void:
	var renderer := ActiveItemChukjibuRenderer.new()
	renderer.prewarm_assets()
	_expect(renderer.get_ground_seal_texture() != null, "Chukjibu seal should prewarm before battle draw")
	_expect(ActiveItemChukjibuRenderer.CHUKJIBU_GROUND_SEAL_PATH == EXPECTED_SEAL_PATH, "Chukjibu renderer should own the generated seal path")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/items/active_item_chukjibu_renderer.gd")
	var facade_source := FileAccess.get_file_as_string("res://scripts/items/active_item_effect_renderer.gd")
	_expect(renderer_source.find("_draw_folded_road_lines") >= 0, "Chukjibu should draw folded-road geometry")
	_expect(renderer_source.find("_draw_afterimage_particle") >= 0, "Chukjibu should draw cyan/gold afterimage streaks")
	_expect(renderer_source.find("draw_arc") < 0, "Chukjibu should not retain the generic circular Dash Boost aura")
	_expect(facade_source.find("_chukjibu_renderer.draw") >= 0, "active item renderer should delegate Chukjibu field VFX")
	_expect(GameplayItemModuleCatalog.MODULES.has("active_item_chukjibu_renderer"), "item module catalog should list Chukjibu renderer")


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
