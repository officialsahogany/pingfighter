extends SceneTree

const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkChoiceDispatch := preload("res://scripts/characters/runtime_perk_choice_dispatch.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const RETIRED_PERK_ID := "instant_treasure_hunt"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_catalog_and_offer_removal()
	_verify_stale_choice_rejection()
	_verify_presentation_removal()
	_verify_treasure_map_copy_cleanup()

	if _failures.is_empty():
		print("treasure_hunt_perk_removal_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_catalog_and_offer_removal() -> void:
	var catalog := RuntimePerkCatalog.new()
	_expect(not RuntimePerkCatalog.INSTANT_PERKS.has(RETIRED_PERK_ID), "retired Treasure Hunt must be absent from the instant catalog")
	_expect(catalog.get_perk_data(RETIRED_PERK_ID).is_empty(), "retired Treasure Hunt must not resolve as perk data")
	_expect(not _entries_have_id(catalog.get_choices("smasher", {}, false, 300), RETIRED_PERK_ID), "retired Treasure Hunt must not enter Mugong offers")
	_expect(not _entries_have_id(catalog.get_debug_perk_entries("smasher"), RETIRED_PERK_ID), "retired Treasure Hunt must not enter the debug picker")


func _verify_stale_choice_rejection() -> void:
	var dispatch := RuntimePerkChoiceDispatch.new().build_dispatch(
		{"id": RETIRED_PERK_ID, "name": "보물탐색"},
		false,
		false
	)
	_expect(not bool(dispatch.get("accepted", true)), "stale Treasure Hunt dispatch must be rejected")
	_expect(str(dispatch.get("action", "")) == RuntimePerkChoiceDispatch.ACTION_INVALID, "stale Treasure Hunt dispatch must resolve to invalid")
	_expect(str(dispatch.get("blocked_reason", "")) == "retired_choice", "stale Treasure Hunt dispatch must report the retired-choice reason")

	var state := RuntimePerkState.new()
	_expect(not state.apply_choice({"id": RETIRED_PERK_ID, "name": "보물탐색"}, null, null), "stale Treasure Hunt cards must not execute through runtime state")
	_expect(not state.runtime_skill_levels.has(RETIRED_PERK_ID), "retired instant choice must never become a collected perk")


func _verify_presentation_removal() -> void:
	_expect(not RuntimePerkIconRenderer.PERK_ICON_PATHS.has(RETIRED_PERK_ID), "retired Treasure Hunt must have no static icon route")
	_expect(not RuntimePerkIconRenderer.PERK_SHEET_PATHS.has(RETIRED_PERK_ID), "retired Treasure Hunt must have no animated icon route")
	for perk_name_map_value: Variant in [
		LanguageSettingsData.PERK_NAME_EN,
		LanguageSettingsData.PERK_NAME_ZH,
		LanguageSettingsData.PERK_NAME_JA,
		LanguageSettingsData.PERK_NAME_ES,
		LanguageSettingsData.PERK_NAME_PT_BR,
		LanguageSettingsData.PERK_NAME_RU,
	]:
		var perk_name_map := perk_name_map_value as Dictionary
		_expect(not perk_name_map.has(RETIRED_PERK_ID), "retired Treasure Hunt must be absent from localized perk names")
	for perk_summary_map_value: Variant in [
		LanguageSettingsData.PERK_SUMMARY_EN,
		LanguageSettingsData.PERK_SUMMARY_ZH,
		LanguageSettingsData.PERK_SUMMARY_JA,
		LanguageSettingsData.PERK_SUMMARY_ES,
		LanguageSettingsData.PERK_SUMMARY_PT_BR,
		LanguageSettingsData.PERK_SUMMARY_RU,
	]:
		var perk_summary_map := perk_summary_map_value as Dictionary
		_expect(not perk_summary_map.has(RETIRED_PERK_ID), "retired Treasure Hunt must be absent from localized perk summaries")


func _verify_treasure_map_copy_cleanup() -> void:
	var treasure_map: Dictionary = RuntimePerkCatalog.new().get_perk_data("downtown_treasure_map")
	_expect(not treasure_map.is_empty(), "Heavenly-Secret Treasure Map must remain available")
	_expect(str(treasure_map.get("detail", "")).find("보물탐색") < 0, "Treasure Map detail must not advertise the retired perk")
	var descriptions: Dictionary = treasure_map.get("descriptions", {})
	for description_value: Variant in descriptions.values():
		_expect(str(description_value).find("보물탐색") < 0, "Treasure Map level copy must not advertise the retired perk")


func _entries_have_id(entries: Array, target_id: String) -> bool:
	for entry_value: Variant in entries:
		if entry_value is Dictionary and str((entry_value as Dictionary).get("id", "")) == target_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
