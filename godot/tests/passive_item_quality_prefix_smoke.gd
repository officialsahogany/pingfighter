extends SceneTree

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PassiveItemQuality := preload("res://scripts/items/passive_item_quality.gd")

var _failures: Array[String] = []
var _language_settings_snapshot: Dictionary = {}


func _init() -> void:
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	seed(20260506)

	var catalog: Object = MythicItemCatalog.new()
	_verify_quality_tiers(catalog)
	_verify_existing_prefix_is_preserved(catalog)
	_verify_field_spawn_items_are_decorated(catalog)
	_verify_runtime_acquisition_keeps_quality()
	_verify_runtime_roll_changes_recompute_quality()
	_verify_mythic_titles_use_rarity_gold(catalog)
	_verify_english_quality_text(catalog)
	_restore_language_settings_snapshot()

	if _failures.is_empty():
		print("passive_item_quality_prefix_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_quality_tiers(catalog: Object) -> void:
	var top_item: Dictionary = _sync_with_roll(catalog, "lucky_coin", {"double_spawn_pct": 15.0})
	_expect(str(top_item.get("quality_tier", "")) == "top", "max roll should produce top quality")
	_expect(str(top_item.get("name_prefix", "")) != "", "top quality should choose a visible prefix")
	_expect(_same_color(top_item.get("quality_color", Color.BLACK), PassiveItemQuality.OPTION_COLOR_TOP), "top quality should use red text color")
	_expect(str(top_item.get("qualified_display_name", "")).ends_with("럭키코인"), "qualified name should keep the Korean base name")
	_expect(str(top_item.get("qualified_display_name", "")) != "럭키코인", "qualified name should include the prefix")

	var mid_item: Dictionary = _sync_with_roll(catalog, "lucky_coin", {"double_spawn_pct": 10.0})
	_expect(str(mid_item.get("quality_tier", "")) == "mid", "middle roll should produce mid quality")
	_expect(_same_color(mid_item.get("quality_color", Color.BLACK), PassiveItemQuality.OPTION_COLOR_MID), "mid quality should use blue text color")

	var low_item: Dictionary = _sync_with_roll(catalog, "lucky_coin", {"double_spawn_pct": 5.0})
	_expect(str(low_item.get("quality_tier", "")) == "low", "minimum roll should produce low quality")
	_expect(_same_color(low_item.get("quality_color", Color.BLACK), PassiveItemQuality.OPTION_COLOR_LOW), "low quality should use white text color")

	var reverse_top: Dictionary = _sync_with_roll(catalog, "sage_ring", {
		"sage_speed_penalty_pct": 10.0,
		"sage_body_penalty_pct": 10.0,
	})
	_expect(str(reverse_top.get("quality_tier", "")) == "top", "reverse minimum rolls should count as top quality")


func _verify_existing_prefix_is_preserved(catalog: Object) -> void:
	var item_data: Dictionary = catalog.build_item_by_name("lucky_coin")
	item_data["rolls"] = {"double_spawn_pct": 15.0}
	item_data["name_prefix"] = "가챠고정"
	item_data["quality_tier"] = "mid"
	item_data = catalog.sync_roll_fields(item_data, false)
	_expect(str(item_data.get("name_prefix", "")) == "가챠고정", "sync should preserve an existing prefix")
	_expect(str(item_data.get("quality_tier", "")) == "mid", "sync should preserve an existing quality tier")
	_expect(_same_color(item_data.get("quality_color", Color.BLACK), PassiveItemQuality.OPTION_COLOR_MID), "preserved mid quality should restore its color")


func _verify_field_spawn_items_are_decorated(catalog: Object) -> void:
	var lucky_coin: Dictionary = _find_item(catalog.get_field_spawn_items(), "lucky_coin")
	_expect(not lucky_coin.is_empty(), "field spawn pool should include Lucky Coin")
	_expect(str(lucky_coin.get("quality_tier", "")) != "", "field spawn passive should receive a quality tier")
	_expect(lucky_coin.get("quality_color", null) is Color, "field spawn passive should receive a quality color")
	_expect(str(lucky_coin.get("qualified_display_name", "")) != "", "field spawn passive should expose a qualified display name")


func _verify_runtime_acquisition_keeps_quality() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var index: int = int(runtime.acquire_item("lucky_coin", null, null, {"double_spawn_pct": 15.0}, false, false))
	_expect(index >= 0, "runtime should acquire Lucky Coin")
	var item_data: Dictionary = runtime.get_inventory_item(index)
	_expect(str(item_data.get("quality_tier", "")) == "top", "runtime inventory should keep top quality")
	_expect(str(item_data.get("qualified_display_name", "")).ends_with("럭키코인"), "runtime inventory should keep the qualified name")


func _verify_runtime_roll_changes_recompute_quality() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var index: int = int(runtime.acquire_item("timer_belt", null, null, {"skill_cooldown_pct": 10.0}, false, false))
	_expect(index >= 0, "runtime should acquire Timer Belt")
	var item_data: Dictionary = runtime.get_inventory_item(index)
	_expect(str(item_data.get("quality_tier", "")) == "low", "minimum Timer Belt roll should start as low quality")
	_expect(bool(runtime.debug_adjust_inventory_roll(index, "skill_cooldown_pct", 10, null, null)), "debug roll editor should raise Timer Belt to max")
	item_data = runtime.get_inventory_item(index)
	_expect(str(item_data.get("quality_tier", "")) == "top", "debug roll edits should recompute top quality")
	_expect(_same_color(item_data.get("quality_color", Color.BLACK), PassiveItemQuality.OPTION_COLOR_TOP), "debug roll edits should refresh the title color")

	var override_runtime: Object = MythicItemRuntime.new()
	var override_index: int = int(override_runtime.acquire_item("timer_belt", null, null, {"skill_cooldown_pct": 10.0}, false, false))
	_expect(override_index >= 0, "runtime should acquire override Timer Belt")
	_expect(bool(override_runtime.equip_item("timer_belt", null, null, {"skill_cooldown_pct": 20.0}, false)), "roll overrides should equip existing Timer Belt")
	var override_item: Dictionary = override_runtime.get_inventory_item(override_index)
	_expect(str(override_item.get("quality_tier", "")) == "top", "roll overrides should recompute top quality")


func _verify_mythic_titles_use_rarity_gold(catalog: Object) -> void:
	var heavenly_cape: Dictionary = catalog.build_item_by_name("heavenly_cape")
	_expect(not heavenly_cape.is_empty(), "Heavenly Cape should build from the mythic catalog")
	_expect(_same_color(PassiveItemQuality.get_item_quality_color(heavenly_cape, Color.BLACK), PassiveItemQuality.RARITY_COLOR_MYTHIC), "mythic item title text should use gold")

	heavenly_cape["quality_color"] = PassiveItemQuality.OPTION_COLOR_TOP
	_expect(_same_color(PassiveItemQuality.get_item_quality_color(heavenly_cape, Color.BLACK), PassiveItemQuality.RARITY_COLOR_MYTHIC), "mythic rarity gold should override roll quality colors")


func _verify_english_quality_text(catalog: Object) -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_ENGLISH)
	var lucky_coin: Dictionary = _sync_with_roll(catalog, "lucky_coin", {"double_spawn_pct": 15.0})
	var qualified_name := str(lucky_coin.get("qualified_display_name", ""))
	_expect(qualified_name.ends_with("Lucky Coin"), "English passive quality name should keep the localized item base name")
	_expect(qualified_name != "Lucky Coin", "English passive quality name should include an English quality prefix")
	var option_text := PassiveItemQuality.format_roll_option_text({
		"label": "이동속도",
		"prefix": "+",
		"value": 12.0,
		"unit": "%",
	})
	_expect(option_text == "Move Speed +12%", "English roll option text should translate known labels")
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)


func _sync_with_roll(catalog: Object, item_name: String, rolls: Dictionary) -> Dictionary:
	var item_data: Dictionary = catalog.build_item_by_name(item_name)
	item_data["rolls"] = rolls
	return catalog.sync_roll_fields(item_data, false)


func _find_item(items: Array, item_name: String) -> Dictionary:
	for item_value in items:
		var item_data: Dictionary = item_value if item_value is Dictionary else {}
		if str(item_data.get("name", "")) == item_name:
			return item_data
	return {}


func _same_color(value: Variant, expected: Color) -> bool:
	if not (value is Color):
		return false
	var color: Color = value
	return (
		is_equal_approx(color.r, expected.r)
		and is_equal_approx(color.g, expected.g)
		and is_equal_approx(color.b, expected.b)
	)


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
