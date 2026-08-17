extends SceneTree

const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkEffectiveLevels := preload("res://scripts/characters/runtime_perk_effective_levels.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const RETIRED_PERK_ID := "revival"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_catalog_and_offer_removal()
	_verify_runtime_and_save_neutrality()
	_verify_presentation_removal()
	_verify_legacy_item_compatibility()
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("revival_mugong_removal_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_catalog_and_offer_removal() -> void:
	var catalog := RuntimePerkCatalog.new()
	_expect(not RuntimePerkCatalog.CONVERTED_PERKS.has(RETIRED_PERK_ID), "retired Revival must be absent from the converted perk catalog")
	_expect(catalog.get_perk_data(RETIRED_PERK_ID).is_empty(), "retired Revival must not resolve as perk data")
	_expect(not catalog.get_all_perk_data().has(RETIRED_PERK_ID), "retired Revival must be absent from bulk perk data")
	_expect(not _entries_have_id(catalog.get_choices("smasher", {}, true, 300), RETIRED_PERK_ID), "retired Revival must not enter normal Mugong offers")
	_expect(not _entries_have_id(catalog.get_debug_perk_entries("smasher"), RETIRED_PERK_ID), "retired Revival must not enter the debug picker")
	_expect(not PerkConversionValues.CONVERSION_SOURCE_TO_PERK.has(RETIRED_PERK_ID), "retired Revival must have no conversion mapping")
	_expect(not PerkConversionValues.CONVERTED_PERK_VALUES.has(RETIRED_PERK_ID), "retired Revival must have no converted value lanes")


func _verify_runtime_and_save_neutrality() -> void:
	var effective_levels := RuntimePerkEffectiveLevels.new()
	var stale_levels := {RETIRED_PERK_ID: 1, "dash_lightweight": 2}
	_expect(
		effective_levels.get_runtime_skill_level(stale_levels, 99, true, RETIRED_PERK_ID) == 0,
		"stale Revival levels must resolve to zero in generic runtime queries"
	)
	_expect(
		effective_levels.get_converted_perk_effect_level(stale_levels, 99, true, RETIRED_PERK_ID) == 0,
		"stale Revival levels must resolve to zero effect"
	)
	var projected_levels: Dictionary = effective_levels.get_effective_runtime_skill_levels(stale_levels, 99, true)
	_expect(not projected_levels.has(RETIRED_PERK_ID), "stale Revival levels must be absent from projected runtime levels")
	_expect(int(projected_levels.get("dash_lightweight", 0)) > 2, "runtime projection must preserve active Mugong bonus levels")

	var runtime_state := RuntimePerkState.new()
	runtime_state.runtime_skill_levels = {RETIRED_PERK_ID: 1, "dash_lightweight": 2}
	var saved_levels: Dictionary = runtime_state.build_unlock_save_snapshot().get("runtime_skill_levels", {})
	_expect(not saved_levels.has(RETIRED_PERK_ID), "new run saves must omit retired Revival")
	_expect(int(saved_levels.get("dash_lightweight", 0)) == 2, "save sanitation must preserve active Mugong levels")

	var restore_result: Dictionary = runtime_state.apply_unlock_save_snapshot({
		"version": 1,
		"runtime_skill_levels": {RETIRED_PERK_ID: 1, "dash_lightweight": 3},
	})
	var restored_levels: Dictionary = restore_result.get("runtime_skill_levels", {})
	_expect(bool(restore_result.get("restored", false)), "legacy run snapshot should still restore")
	_expect(int(restore_result.get("removed_retired_perks", 0)) == 1, "restore should report one retired Mugong removal")
	_expect(not restored_levels.has(RETIRED_PERK_ID), "legacy run restore must strip retired Revival")
	_expect(int(restored_levels.get("dash_lightweight", 0)) == 3, "legacy run restore must preserve active Mugong levels")


func _verify_presentation_removal() -> void:
	_expect(not RuntimePerkIconRenderer.PERK_ICON_PATHS.has(RETIRED_PERK_ID), "retired Revival must have no Mugong icon route")
	for perk_name_map_value: Variant in [
		LanguageSettingsData.PERK_NAME_EN,
		LanguageSettingsData.PERK_NAME_ZH,
		LanguageSettingsData.PERK_NAME_JA,
		LanguageSettingsData.PERK_NAME_ES,
		LanguageSettingsData.PERK_NAME_PT_BR,
		LanguageSettingsData.PERK_NAME_RU,
	]:
		var perk_name_map := perk_name_map_value as Dictionary
		_expect(not perk_name_map.has(RETIRED_PERK_ID), "retired Revival must be absent from localized Mugong names")
	for perk_summary_map_value: Variant in [
		LanguageSettingsData.PERK_SUMMARY_EN,
		LanguageSettingsData.PERK_SUMMARY_ZH,
		LanguageSettingsData.PERK_SUMMARY_JA,
		LanguageSettingsData.PERK_SUMMARY_ES,
		LanguageSettingsData.PERK_SUMMARY_PT_BR,
		LanguageSettingsData.PERK_SUMMARY_RU,
	]:
		var perk_summary_map := perk_summary_map_value as Dictionary
		_expect(not perk_summary_map.has(RETIRED_PERK_ID), "retired Revival must be absent from localized Mugong summaries")


func _verify_legacy_item_compatibility() -> void:
	_expect(
		not MythicItemCatalog.new().build_item_by_name(RETIRED_PERK_ID).is_empty(),
		"retiring the Mugong must not delete legacy Revival item metadata"
	)
	_expect(LanguageSettingsData.ITEM_DISPLAY_EN.has(RETIRED_PERK_ID), "legacy Revival item localization must remain intact")


func _entries_have_id(entries: Array, target_id: String) -> bool:
	for entry_value: Variant in entries:
		if entry_value is Dictionary and str((entry_value as Dictionary).get("id", "")) == target_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
