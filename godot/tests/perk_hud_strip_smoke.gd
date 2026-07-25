extends SceneTree

# Seals the Vampire-Survivors-style acquired-perk strip (2026-07-09 request): a top-left
# row of small perk icons showing the current build during battle. Guards:
#  - build_strip_entries() excludes active-skill unlock perks (5-orb HUD, not perks) and
#    keeps owned passive perks with their icon color,
#  - the entries are cached and only rebuilt when the levels dict changes.

const RuntimePerkHudStripRenderer := preload("res://scripts/hud/runtime_perk_hud_strip_renderer.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const PerkFusionIconKey := preload("res://scripts/characters/perk_fusion_icon_key.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_test_excludes_unlocks_keeps_passives()
	_test_cache_reuse()
	_test_fusion_projection_folds_sources_and_invalidates_cache()
	_test_left_letterbox_fit_guard()
	print("perk_hud_strip_smoke: ok")
	ProjectResourceLoader.clear_caches()
	quit(0)


func _test_excludes_unlocks_keeps_passives() -> void:
	var renderer: Object = RuntimePerkHudStripRenderer.new()
	var catalog: Object = RuntimePerkCatalog.new()
	var levels: Dictionary = {
		"common_bulk_up": 3,
		"unlock_warp_gate": 1,
		"adversity_armor": 2,
		"unlock_smasher_wheel": 1,
	}
	var entries: Array = renderer.build_strip_entries(levels, catalog)
	var ids: Array = []
	for entry in entries:
		ids.append(str((entry as Dictionary).get("id", "")))
	_expect(ids.has("common_bulk_up"), "passive perk (common_bulk_up) must appear in the strip")
	_expect(ids.has("adversity_armor"), "converted passive perk (adversity_armor) must appear")
	_expect(not ids.has("unlock_warp_gate"), "active-skill unlock (unlock_warp_gate) must be excluded")
	_expect(not ids.has("unlock_smasher_wheel"), "active-skill unlock (unlock_smasher_wheel) must be excluded")
	_expect(entries.size() == 2, "expected exactly the 2 passive perks, got %d" % entries.size())
	# Each entry carries a Color for the fallback frame and a positive level.
	var first: Dictionary = entries[0]
	_expect(first.get("color") is Color, "entry must carry an icon Color")
	_expect(int(first.get("level", 0)) > 0, "entry must carry a positive level")


func _test_cache_reuse() -> void:
	var renderer: Object = RuntimePerkHudStripRenderer.new()
	var catalog: Object = RuntimePerkCatalog.new()
	var levels: Dictionary = {"common_bulk_up": 1}
	var first: Array = renderer.get_strip_entries_cached(levels, catalog)
	var second: Array = renderer.get_strip_entries_cached(levels, catalog)
	_expect(is_same(first, second), "identical levels must reuse the cached entries array (no rebuild)")
	# A changed levels dict must rebuild.
	var changed: Dictionary = {"common_bulk_up": 1, "common_swiftness": 2}
	var third: Array = renderer.get_strip_entries_cached(changed, catalog)
	_expect(not is_same(first, third), "changed levels must rebuild the entries")
	_expect(third.size() == 2, "changed levels must include both passive perks, got %d" % third.size())


func _test_fusion_projection_folds_sources_and_invalidates_cache() -> void:
	var renderer: Object = RuntimePerkHudStripRenderer.new()
	var catalog: Object = RuntimePerkCatalog.new()
	var levels := {"common_bulk_up": 5, "common_swiftness": 5, "adversity_armor": 1}
	var before: Dictionary = {
		"fusion_revision": 0,
		"cache_signature": 10,
		"entries": [
			{"type": "perk", "id": "common_bulk_up", "perk_id": "common_bulk_up", "base_level": 5, "effective_level": 5},
			{"type": "perk", "id": "common_swiftness", "perk_id": "common_swiftness", "base_level": 5, "effective_level": 5},
			{"type": "perk", "id": "adversity_armor", "perk_id": "adversity_armor", "base_level": 1, "effective_level": 1},
		],
	}
	var before_entries: Array = renderer.get_strip_entries_cached(levels, catalog, before)
	var after: Dictionary = {
		"fusion_revision": 1,
		"cache_signature": 11,
		"entries": [
			{"type": "fusion", "id": "fusion_0", "fusion_id": "fusion_0", "fusion_revision": 1, "sources": ["common_bulk_up", "common_swiftness"]},
			{"type": "perk", "id": "adversity_armor", "perk_id": "adversity_armor", "base_level": 1, "effective_level": 1},
		],
	}
	var after_entries: Array = renderer.get_strip_entries_cached(levels, catalog, after)
	_expect(not is_same(before_entries, after_entries), "fusion revision/signature should invalidate the HUD strip cache even when levels are unchanged")
	_expect(after_entries.size() == 2, "two fused sources should occupy one strip entry beside the unrelated perk")
	var ids: Array = []
	for entry_value: Variant in after_entries:
		ids.append(str((entry_value as Dictionary).get("id", "")))
	_expect(ids.has("fusion_0") and ids.has("adversity_armor"), "strip projection should expose the fusion identity and retain unrelated perks")
	_expect(not ids.has("common_bulk_up") and not ids.has("common_swiftness"), "strip projection must not render folded source perks twice")
	for entry_value: Variant in after_entries:
		var entry: Dictionary = entry_value as Dictionary
		if str(entry.get("id", "")) == "fusion_0":
			var parsed_icon := PerkFusionIconKey.parse(str(entry.get("draw_id", "")))
			_expect(str(parsed_icon.get("fusion_id", "")) == "fusion_0" and int(parsed_icon.get("fusion_revision", 0)) == 1, "HUD fusion cell should include fusion identity and revision in its cache key")
			_expect(parsed_icon.get("sources", []) == ["common_bulk_up", "common_swiftness"], "HUD fusion cell should route both material ids into the composite icon")


func _test_left_letterbox_fit_guard() -> void:
	var renderer: Object = RuntimePerkHudStripRenderer.new()
	var vertical_letterbox_only: Dictionary = renderer.get_strip_layout(
		3,
		Vector2(0.0, 120.0),
		Vector2(760.0, 750.0)
	)
	_expect(not bool(vertical_letterbox_only.get("visible", true)), "game_offset.x=0 must hide the strip instead of drawing over the full playfield")
	var partial_side_letterbox: Dictionary = renderer.get_strip_layout(
		3,
		Vector2(30.0, 24.0),
		Vector2(760.0, 750.0)
	)
	_expect(not bool(partial_side_letterbox.get("visible", true)), "a side letterbox narrower than one complete icon column must hide the strip")
	var exact_fit: Dictionary = renderer.get_strip_layout(
		3,
		Vector2(38.0, 24.0),
		Vector2(760.0, 750.0)
	)
	_expect(bool(exact_fit.get("visible", false)), "the strip may appear once margins plus one complete icon column fit")
	var strip_left := float(exact_fit.get("strip_left", -1.0))
	var icon_size := float(exact_fit.get("icon_size", 0.0))
	var strip_right := float(exact_fit.get("strip_right", 999.0))
	_expect(strip_left >= 0.0 and strip_left + icon_size <= strip_right + 0.001, "visible strip geometry must fit inside its guarded letterbox span")
	_expect(strip_right < 38.0, "visible strip geometry must end before the 760x750 playfield begins")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("perk_hud_strip_smoke FAIL: " + message)
	ProjectResourceLoader.clear_caches()
	quit(1)
