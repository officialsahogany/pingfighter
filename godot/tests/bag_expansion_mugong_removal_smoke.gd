extends SceneTree

const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const MythicItemCapacityGaugeRuntime := preload("res://scripts/items/mythic_item_capacity_gauge_runtime.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const PerkFusionCatalog := preload("res://scripts/characters/perk_fusion_catalog.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkEffectiveLevels := preload("res://scripts/characters/runtime_perk_effective_levels.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const RETIRED_PERK_ID := "item_bag_expansion"
const RETIRED_LOCALIZATION_ID := "active_slot_expand"
const LEGACY_ITEM_ID := "slot_add"
const COLLECTION_MANIFEST_PATH := "res://assets/sprites/perks/common_mugong_collection_manifest.json"


class FakeLegacyCatalog:
	extends RefCounted

	func get_default_roll_value(item_id: String, roll_key: String) -> float:
		if item_id == "slot_add" and roll_key == "slot_add_count":
			return 1.0
		return 0.0


class FakeLegacyItemRuntime:
	extends RefCounted

	var equipped_items := {
		"slot_add": {
			"rolls": {"slot_add_count": 2.0},
		},
	}
	var catalog := FakeLegacyCatalog.new()

	func is_equipped(item_id: String) -> bool:
		return item_id == "slot_add"

	func _get_dict(value: Variant) -> Dictionary:
		return value as Dictionary if value is Dictionary else {}


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
		print("bag_expansion_mugong_removal_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_catalog_and_offer_removal() -> void:
	var catalog := RuntimePerkCatalog.new()
	_expect(not RuntimePerkCatalog.COMMON_PERKS.has(RETIRED_PERK_ID), "retired Geongonnang must be absent from the common Mugong catalog")
	_expect(catalog.get_perk_data(RETIRED_PERK_ID).is_empty(), "retired Geongonnang must not resolve as perk data")
	_expect(not catalog.get_all_perk_data().has(RETIRED_PERK_ID), "retired Geongonnang must be absent from bulk perk data")
	_expect(not _entries_have_id(catalog.get_choices("smasher", {}, true, 300), RETIRED_PERK_ID), "retired Geongonnang must not enter normal Mugong offers")
	_expect(not _entries_have_id(catalog.get_debug_perk_entries("smasher"), RETIRED_PERK_ID), "retired Geongonnang must not enter the debug picker")
	_expect(not PerkFusionCatalog.new().is_candidate(RETIRED_PERK_ID, 5, catalog), "retired Geongonnang must not remain a fusion source")
	_expect(bool(PerkConversionValues.RETIRED_CONVERTED_PERK_IDS.get(RETIRED_PERK_ID, false)), "retired Geongonnang must remain registered for stale-save sanitation")
	_expect(not PerkConversionValues.DELETED_ITEM_COMPENSATION.has(LEGACY_ITEM_ID), "legacy Backpack must no longer compensate into retired Geongonnang")


func _verify_runtime_and_save_neutrality() -> void:
	var effective_levels := RuntimePerkEffectiveLevels.new()
	var stale_levels := {RETIRED_PERK_ID: 2, "dash_lightweight": 2}
	_expect(
		effective_levels.get_runtime_skill_level(stale_levels, 99, true, RETIRED_PERK_ID) == 0,
		"stale Geongonnang levels must resolve to zero in generic runtime queries"
	)
	_expect(
		effective_levels.get_converted_perk_effect_level(stale_levels, 99, true, RETIRED_PERK_ID) == 0,
		"stale Geongonnang levels must resolve to zero effect"
	)
	var projected_levels: Dictionary = effective_levels.get_effective_runtime_skill_levels(stale_levels, 99, true)
	_expect(not projected_levels.has(RETIRED_PERK_ID), "stale Geongonnang levels must be absent from projected runtime levels")

	var runtime_state := RuntimePerkState.new()
	runtime_state.runtime_skill_levels = stale_levels.duplicate(true)
	_expect(runtime_state.get_active_item_slot_capacity(3) == 3, "stale Geongonnang must not expand active item capacity")
	var breakdown: Array = CharacterInfoOverlayStatsPresenter.active_item_slot_breakdown(runtime_state, null, 3)
	_expect(not _entries_have_icon_id(breakdown, RETIRED_PERK_ID), "character info must not expose stale Geongonnang as a slot source")

	var saved_levels: Dictionary = runtime_state.build_unlock_save_snapshot().get("runtime_skill_levels", {})
	_expect(not saved_levels.has(RETIRED_PERK_ID), "new run saves must omit retired Geongonnang")
	_expect(int(saved_levels.get("dash_lightweight", 0)) == 2, "save sanitation must preserve active Mugong levels")

	var restore_result: Dictionary = runtime_state.apply_unlock_save_snapshot({
		"version": 1,
		"runtime_skill_levels": {RETIRED_PERK_ID: 2, "dash_lightweight": 3},
	})
	var restored_levels: Dictionary = restore_result.get("runtime_skill_levels", {})
	_expect(bool(restore_result.get("restored", false)), "legacy run snapshot should still restore")
	_expect(int(restore_result.get("removed_retired_perks", 0)) == 1, "restore should report one retired Mugong removal")
	_expect(not restored_levels.has(RETIRED_PERK_ID), "legacy run restore must strip retired Geongonnang")
	_expect(int(restored_levels.get("dash_lightweight", 0)) == 3, "legacy run restore must preserve active Mugong levels")

	runtime_state.runtime_skill_levels["dash_lightweight"] = 5
	var fusion_restore: Dictionary = runtime_state.restore_perk_fusion_snapshot({
		"records": [{
			"fusion_id": "fusion_retired_geongonnang",
			"sources": ["dash_lightweight", RETIRED_PERK_ID],
			"outcome": "success",
		}],
		"next_fusion_index": 1,
		"fusion_revision": 1,
	}, RuntimePerkCatalog.new())
	_expect(int(fusion_restore.get("kept", -1)) == 0, "legacy fusion records must not keep retired Geongonnang")
	_expect(int(fusion_restore.get("dropped", 0)) == 1, "legacy fusion restore must drop the retired source record")
	var dropped_reasons: Dictionary = fusion_restore.get("dropped_by_reason", {}) as Dictionary
	_expect(int(dropped_reasons.get("missing_source", 0)) == 1, "retired fusion source should be reported as missing from the catalog")


func _verify_presentation_removal() -> void:
	_expect(not RuntimePerkIconRenderer.PERK_ICON_PATHS.has(RETIRED_PERK_ID), "retired Geongonnang must have no Mugong icon route")
	_expect(not LanguageSettingsData.PERK_LOCALIZATION_ALIASES.has(RETIRED_PERK_ID), "retired Geongonnang must have no localization alias")
	for perk_name_map_value: Variant in [
		LanguageSettingsData.PERK_NAME_EN,
		LanguageSettingsData.PERK_NAME_ZH,
		LanguageSettingsData.PERK_NAME_JA,
		LanguageSettingsData.PERK_NAME_ES,
		LanguageSettingsData.PERK_NAME_PT_BR,
		LanguageSettingsData.PERK_NAME_RU,
	]:
		var perk_name_map := perk_name_map_value as Dictionary
		_expect(not perk_name_map.has(RETIRED_LOCALIZATION_ID), "retired Geongonnang must be absent from localized Mugong names")
	for perk_summary_map_value: Variant in [
		LanguageSettingsData.PERK_SUMMARY_EN,
		LanguageSettingsData.PERK_SUMMARY_ZH,
		LanguageSettingsData.PERK_SUMMARY_JA,
		LanguageSettingsData.PERK_SUMMARY_ES,
		LanguageSettingsData.PERK_SUMMARY_PT_BR,
		LanguageSettingsData.PERK_SUMMARY_RU,
	]:
		var perk_summary_map := perk_summary_map_value as Dictionary
		_expect(not perk_summary_map.has(RETIRED_LOCALIZATION_ID), "retired Geongonnang must be absent from localized Mugong summaries")

	var manifest_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(COLLECTION_MANIFEST_PATH))
	_expect(manifest_value is Dictionary, "common Mugong collection manifest must parse")
	if manifest_value is Dictionary:
		var manifest := manifest_value as Dictionary
		_expect(not _nested_array_has_value(manifest.get("groups", {}), RETIRED_PERK_ID), "common Mugong groups must omit retired Geongonnang")
		_expect(not _entries_have_id(manifest.get("assets", []) as Array, RETIRED_PERK_ID), "common Mugong asset manifest must omit retired Geongonnang")


func _verify_legacy_item_compatibility() -> void:
	_expect(
		not MythicItemCatalog.new().build_item_by_name(LEGACY_ITEM_ID).is_empty(),
		"retiring Geongonnang must not delete legacy Backpack item metadata"
	)
	_expect(LanguageSettingsData.ITEM_DISPLAY_EN.has(LEGACY_ITEM_ID), "legacy Backpack item localization must remain intact")
	var item_runtime := FakeLegacyItemRuntime.new()
	_expect(MythicItemCapacityGaugeRuntime.new().get_active_item_slot_capacity(item_runtime, 3) == 5, "legacy Backpack must still add its rolled two active item slots")


func _entries_have_id(entries: Array, target_id: String) -> bool:
	for entry_value: Variant in entries:
		if entry_value is Dictionary and str((entry_value as Dictionary).get("id", (entry_value as Dictionary).get("perk_id", ""))) == target_id:
			return true
	return false


func _entries_have_icon_id(entries: Array, target_id: String) -> bool:
	for entry_value: Variant in entries:
		if entry_value is Dictionary and str((entry_value as Dictionary).get("icon_id", "")) == target_id:
			return true
	return false


func _nested_array_has_value(value: Variant, target: String) -> bool:
	if value is Dictionary:
		for nested_value: Variant in (value as Dictionary).values():
			if _nested_array_has_value(nested_value, target):
				return true
	if value is Array:
		for nested_value: Variant in value:
			if str(nested_value) == target or _nested_array_has_value(nested_value, target):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
