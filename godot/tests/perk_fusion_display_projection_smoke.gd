extends SceneTree

const PerkFusionDisplayProjection := preload(
	"res://scripts/characters/perk_fusion_display_projection.gd"
)
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []
var _projector := PerkFusionDisplayProjection.new()
var _catalog := FakeCatalog.new()


func _init() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	_verify_two_sources_fold_into_one_entry()
	_verify_invalid_records_fail_closed()
	_verify_projection_is_deterministic()
	_verify_revision_cache_and_fusion_diff()
	_verify_canonical_snapshot_keys_only()
	_verify_outputs_are_deep_copies()

	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("perk_fusion_display_projection_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_two_sources_fold_into_one_entry() -> void:
	var levels := {"alpha": 5, "beta": 5, "gamma": 3}
	var effective_levels := {"alpha": 7, "beta": 6, "gamma": 4}
	var snapshot := {
		"fusion_revision": 1,
		"records": [
			{
				"fusion_id": "fusion_0",
				"sources": ["beta", "alpha"],
				"outcome": "side_effect",
				"option_penalties": {"alpha": {"power": {"multiplier": 0.8}}},
				"deleted_options": {},
				"byproducts": ["reverb"],
				"byproduct_payloads": {"reverb": {"ratio": 0.25}},
			},
		],
	}
	var projection: Dictionary = _projector.build(levels, snapshot, _catalog, effective_levels)
	var entries: Array = projection.get("entries", []) as Array
	_expect(entries.size() == 2, "two fused sources plus one unrelated perk should project to two entries")
	_expect(_find_entry(entries, "alpha").is_empty(), "first fusion source must not remain an ordinary entry")
	_expect(_find_entry(entries, "beta").is_empty(), "second fusion source must not remain an ordinary entry")
	_expect(not _find_entry(entries, "gamma").is_empty(), "unrelated owned perk must remain visible")

	var fusion: Dictionary = _find_entry(entries, "fusion_0")
	_expect(str(fusion.get("type", "")) == "fusion", "folded entry should publish fusion type")
	_expect(fusion.get("sources", []) == ["alpha", "beta"], "fusion sources should be sorted")
	_expect(int(fusion.get("slot_cost", 0)) == 1, "fusion entry should consume one display slot")
	_expect(
		fusion.get("base_levels", {}) == {"alpha": 5, "beta": 5},
		"fusion entry should preserve both source base levels"
	)
	_expect(
		fusion.get("effective_levels", {}) == {"alpha": 7, "beta": 6},
		"fusion entry should preserve both source effective levels"
	)
	var fusion_summary := str(fusion.get("summary", ""))
	_expect(fusion_summary.contains("합일"), "fusion summary should use the canonical Korean Mugong unity copy")
	_expect(not fusion_summary.contains("융합"), "fusion summary should not regress to the retired Korean fusion term")
	_expect(_sources_are_unique(entries), "a source id must not appear in more than one projected entry")


func _verify_invalid_records_fail_closed() -> void:
	var levels := {"alpha": 5, "beta": 5, "gamma": 5}
	var missing_source_snapshot := {
		"fusion_revision": 2,
		"records": [
			{"fusion_id": "fusion_bad", "sources": ["alpha", "missing"], "outcome": "success"},
		],
	}
	var missing_projection: Dictionary = _projector.build(levels, missing_source_snapshot, _catalog)
	var missing_entries: Array = missing_projection.get("entries", []) as Array
	_expect(_count_type(missing_entries, "fusion") == 0, "record with a missing source should not project")
	_expect(_count_type(missing_entries, "perk") == 3, "invalid record must leave all ordinary sources visible")

	var conflicting_snapshot := {
		"fusion_revision": 3,
		"records": [
			{"fusion_id": "fusion_1", "sources": ["alpha", "beta"], "outcome": "success"},
			{"fusion_id": "fusion_2", "sources": ["alpha", "gamma"], "outcome": "success"},
		],
	}
	var conflict_projection: Dictionary = _projector.build(levels, conflicting_snapshot, _catalog)
	var conflict_entries: Array = conflict_projection.get("entries", []) as Array
	_expect(_count_type(conflict_entries, "fusion") == 0, "source-conflicting records should all fail closed")
	_expect(_count_type(conflict_entries, "perk") == 3, "conflict rejection must not hide an ambiguous source")


func _verify_projection_is_deterministic() -> void:
	var levels_a := {"epsilon": 2, "delta": 5, "gamma": 5, "beta": 5, "alpha": 5}
	var levels_b := {"alpha": 5, "beta": 5, "gamma": 5, "delta": 5, "epsilon": 2}
	var record_1 := {"fusion_id": "fusion_1", "sources": ["beta", "alpha"], "outcome": "success"}
	var record_2 := {"fusion_id": "fusion_2", "sources": ["gamma", "delta"], "outcome": "stable"}
	var projection_a: Dictionary = _projector.build(
		levels_a,
		{"fusion_revision": 4, "records": [record_2, record_1]},
		_catalog
	)
	var projection_b: Dictionary = _projector.build(
		levels_b,
		{"fusion_revision": 4, "records": [record_1, record_2]},
		_catalog
	)
	_expect(
		projection_a.get("entries", []) == projection_b.get("entries", []),
		"level and record insertion order must not affect canonical entries"
	)
	_expect(
		projection_a.get("cache_signature") == projection_b.get("cache_signature"),
		"equivalent canonical projections should share a cache signature"
	)
	_expect(
		_sources_are_unique(projection_a.get("entries", []) as Array),
		"multiple fusion records must not duplicate any source"
	)


func _verify_revision_cache_and_fusion_diff() -> void:
	var levels := {"alpha": 5, "beta": 5, "epsilon": 2}
	var before: Dictionary = _projector.build(levels, {"fusion_revision": 0, "records": []}, _catalog)
	var record := {
		"fusion_id": "fusion_0",
		"sources": ["alpha", "beta"],
		"outcome": "success",
		"option_penalties": {},
	}
	var after: Dictionary = _projector.build(
		levels,
		{"fusion_revision": 1, "records": [record]},
		_catalog
	)
	_expect(
		before.get("cache_signature") != after.get("cache_signature"),
		"same levels with a new fusion revision and record must invalidate display cache"
	)
	var added: Array = _projector.diff(before, after)
	_expect(added.size() == 1, "fusion addition should produce a diff even when levels are unchanged")
	if added.size() == 1:
		_expect(str((added[0] as Dictionary).get("type", "")) == "fusion", "fusion diff should publish fusion type")
		_expect(str((added[0] as Dictionary).get("fusion_id", "")) == "fusion_0", "fusion diff should preserve identity")
		_expect(str((added[0] as Dictionary).get("change", "")) == "added", "first fusion diff should be added")

	var revision_only: Dictionary = _projector.build(
		levels,
		{"fusion_revision": 2, "records": [record]},
		_catalog
	)
	_expect(
		after.get("cache_signature") != revision_only.get("cache_signature"),
		"fusion revision alone must remain part of the cache signature"
	)
	_expect(
		_projector.diff(after, revision_only).is_empty(),
		"revision-only invalidation should not invent a fusion reward diff"
	)

	var live_level_only: Dictionary = _projector.build(
		levels,
		{"fusion_revision": 1, "records": [record]},
		_catalog,
		{"alpha": 8, "beta": 7, "epsilon": 4}
	)
	_expect(
		_projector.diff(after, live_level_only).is_empty(),
		"live effective-level growth must not re-emit an unchanged fusion record as a reward"
	)
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_ENGLISH)
	var locale_only: Dictionary = _projector.build(
		levels,
		{"fusion_revision": 1, "records": [record]},
		_catalog
	)
	_expect(
		_projector.diff(after, locale_only).is_empty(),
		"locale-only source names/summary changes must not re-emit an unchanged fusion record"
	)
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)

	var changed_record: Dictionary = record.duplicate(true)
	changed_record["outcome"] = "stable"
	var changed_projection: Dictionary = _projector.build(
		levels,
		{"fusion_revision": 3, "records": [changed_record]},
		_catalog
	)
	var changed: Array = _projector.diff(revision_only, changed_projection)
	_expect(changed.size() == 1, "changed record payload should produce one fusion diff")
	if changed.size() == 1:
		_expect(str((changed[0] as Dictionary).get("change", "")) == "changed", "record mutation should be marked changed")


func _verify_outputs_are_deep_copies() -> void:
	var levels := {"alpha": 5, "beta": 5}
	var snapshot := {
		"fusion_revision": 1,
		"records": [
			{
				"fusion_id": "fusion_0",
				"sources": ["alpha", "beta"],
				"outcome": "side_effect",
				"option_penalties": {"alpha": {"power": {"multiplier": 0.8}}},
			},
		],
	}
	var projected: Dictionary = _projector.build(levels, snapshot, _catalog)
	var projected_fusion: Dictionary = _find_entry(projected.get("entries", []) as Array, "fusion_0")
	(projected_fusion.get("source_names", []) as Array)[0] = "변조"
	var record_payload: Dictionary = projected_fusion.get("record_payload", {}) as Dictionary
	(record_payload.get("option_penalties", {}) as Dictionary).clear()

	var rebuilt: Dictionary = _projector.build(levels, snapshot, _catalog)
	var rebuilt_fusion: Dictionary = _find_entry(rebuilt.get("entries", []) as Array, "fusion_0")
	_expect(
		str((rebuilt_fusion.get("source_names", []) as Array)[0]) == "알파",
		"mutating returned source names must not affect later projections"
	)
	_expect(
		not ((snapshot["records"] as Array)[0].get("option_penalties", {}) as Dictionary).is_empty(),
		"projection output must not alias nested input record payloads"
	)


func _verify_canonical_snapshot_keys_only() -> void:
	var levels := {"alpha": 5, "beta": 5}
	var legacy_projection := _projector.build(
		levels,
		{
			"revision": 9,
			"fusion_records": [{
				"fusion_id": "fusion_0",
				"sources": ["alpha", "beta"],
			}],
		},
		_catalog
	)
	_expect(_count_type(legacy_projection.get("entries", []) as Array, "fusion") == 0, "display projection should ignore legacy fusion_records")
	_expect(int(legacy_projection.get("fusion_revision", -1)) == 0, "display projection should ignore generic revision")
	var source := FileAccess.get_file_as_string("res://scripts/characters/perk_fusion_display_projection.gd")
	_expect(source.find("snapshot.get(\"fusion_records\"") < 0, "display projection should consume only records")
	_expect(source.find("snapshot.get(\"revision\"") < 0, "display projection should consume only fusion_revision")


func _find_entry(entries: Array, entry_id: String) -> Dictionary:
	for entry_value: Variant in entries:
		if entry_value is Dictionary and str((entry_value as Dictionary).get("id", "")) == entry_id:
			return entry_value as Dictionary
	return {}


func _count_type(entries: Array, entry_type: String) -> int:
	var count := 0
	for entry_value: Variant in entries:
		if entry_value is Dictionary and str((entry_value as Dictionary).get("type", "")) == entry_type:
			count += 1
	return count


func _sources_are_unique(entries: Array) -> bool:
	var seen: Dictionary = {}
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value as Dictionary
		if str(entry.get("type", "")) == "fusion":
			for source_value: Variant in entry.get("sources", []):
				var source_id: String = str(source_value)
				if seen.has(source_id):
					return false
				seen[source_id] = true
		else:
			var perk_id: String = str(entry.get("perk_id", ""))
			if seen.has(perk_id):
				return false
			seen[perk_id] = true
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeCatalog:
	extends RefCounted

	var _data := {
		"alpha": {"name": "알파", "max_level": 5},
		"beta": {"name": "베타", "max_level": 5},
		"gamma": {"name": "감마", "max_level": 5},
		"delta": {"name": "델타", "max_level": 5},
		"epsilon": {"name": "엡실론", "max_level": 5},
	}

	func get_perk_data(perk_id: String) -> Dictionary:
		return (_data.get(perk_id, {}) as Dictionary).duplicate(true)

	func get_slot_cost_for_level(_perk_data: Dictionary, level: int) -> int:
		return 1 if level > 0 else 0
