extends SceneTree

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []


func _init() -> void:
	var state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	state.runtime_skill_levels = {"dash_amplification": 2}

	# No fusion modal/commit has run yet. The state-owned default display
	# catalog must still preserve the authored multi-slot cost.
	var initial_snapshot: Dictionary = state.get_snapshot()
	var initial_projection: Dictionary = initial_snapshot.get("perk_fusion_display_projection", {}) as Dictionary
	var initial_entry := _entry_for(initial_projection, "dash_amplification")
	_expect(int(initial_entry.get("slot_cost", 0)) == 2, "pre-fusion snapshot must preserve dash_amplification Lv.2 slot cost")

	var builds_after_snapshot := int(state.get_perk_fusion_display_cache_stats().get("projection_builds", 0))
	for _index in range(8):
		state.get_perk_fusion_display_projection(catalog)
	var repeated_builds := int(state.get_perk_fusion_display_cache_stats().get("projection_builds", 0))
	_expect(repeated_builds == builds_after_snapshot + 1, "first explicit catalog identity may rebuild once, then repeated per-frame reads must hit cache")

	state.runtime_skill_levels["dash_amplification"] = 3
	var changed_projection: Dictionary = state.get_perk_fusion_display_projection(catalog)
	var changed_entry := _entry_for(changed_projection, "dash_amplification")
	_expect(int(changed_entry.get("slot_cost", 0)) == 3, "level hash change must invalidate the projection cache")
	_expect(
		int(state.get_perk_fusion_display_cache_stats().get("projection_builds", 0)) == repeated_builds + 1,
		"level mutation should rebuild the cached projection exactly once"
	)

	_verify_fusion_revision_locale_and_reset_invalidation(catalog)

	if _failures.is_empty():
		print("perk_fusion_projection_cache_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_fusion_revision_locale_and_reset_invalidation(catalog: Object) -> void:
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = {
		"item_luck": 5,
		"common_bulk_up": 5,
	}
	state.get_perk_fusion_display_projection(catalog)
	var builds := _projection_builds(state)

	var record: Dictionary = state.commit_perk_fusion(
		["item_luck", "common_bulk_up"],
		{"outcome": "success"},
		catalog
	)
	_expect(not record.is_empty(), "cache invalidation fixture must commit a valid fusion")
	state.get_perk_fusion_display_projection(catalog)
	_expect(_projection_builds(state) == builds + 1, "fusion commit revision must invalidate the projection cache exactly once")
	builds = _projection_builds(state)
	state.get_perk_fusion_display_projection(catalog)
	_expect(_projection_builds(state) == builds, "post-commit repeated reads must hit the rebuilt projection cache")

	var fusion_snapshot: Dictionary = state.get_perk_fusion_snapshot()
	var restore_result: Dictionary = state.restore_perk_fusion_snapshot(fusion_snapshot, catalog)
	_expect(int(restore_result.get("kept", 0)) == 1, "cache invalidation fixture must restore the committed fusion")
	state.get_perk_fusion_display_projection(catalog)
	_expect(_projection_builds(state) == builds + 1, "fusion restore revision must invalidate the projection cache exactly once")
	builds = _projection_builds(state)

	# Change only the in-memory language cache so this smoke never rewrites the
	# player's persistent language setting. The runtime cache key must still see
	# the same language transition used by live UI projection readers.
	var original_language := LanguageSettings.get_language()
	var alternate_language := (
		LanguageSettings.LANGUAGE_ENGLISH
		if original_language != LanguageSettings.LANGUAGE_ENGLISH
		else LanguageSettings.LANGUAGE_KOREAN
	)
	LanguageSettings._cached_language = alternate_language
	TranslationServer.set_locale(alternate_language)
	state.get_perk_fusion_display_projection(catalog)
	_expect(_projection_builds(state) == builds + 1, "locale transition must invalidate the projection cache exactly once")
	builds = _projection_builds(state)
	LanguageSettings._cached_language = original_language
	TranslationServer.set_locale(original_language)
	state.get_perk_fusion_display_projection(catalog)
	_expect(_projection_builds(state) == builds + 1, "restoring the locale must rebuild rather than reuse foreign-language projection data")
	builds = _projection_builds(state)

	state.reset()
	state.get_perk_fusion_display_projection(catalog)
	_expect(_projection_builds(state) == builds + 1, "new-run reset must clear the projection cache so the next read rebuilds once")
	builds = _projection_builds(state)
	state.get_perk_fusion_display_projection(catalog)
	_expect(_projection_builds(state) == builds, "post-reset repeated reads must hit the rebuilt projection cache")


func _projection_builds(state: Object) -> int:
	return int(state.get_perk_fusion_display_cache_stats().get("projection_builds", 0))


func _entry_for(projection: Dictionary, perk_id: String) -> Dictionary:
	for entry_value: Variant in projection.get("entries", []):
		if entry_value is Dictionary and str((entry_value as Dictionary).get("id", "")) == perk_id:
			return entry_value as Dictionary
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
