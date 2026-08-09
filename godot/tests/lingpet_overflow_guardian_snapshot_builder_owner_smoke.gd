extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetOverflowGuardianSnapshotBuilder := preload("res://scripts/lingpet/lingpet_overflow_guardian_snapshot_builder.gd")


class FakeLoadoutState:
	var loadouts: Dictionary = {}

	func _init(initial_loadouts: Dictionary) -> void:
		loadouts = initial_loadouts.duplicate(true)

	func get_stored_loadout(pet_id: String) -> Dictionary:
		return (loadouts.get(pet_id, {}) as Dictionary).duplicate(true)

	func get_loadout(pet_id: String) -> Dictionary:
		return (loadouts.get(pet_id, LingpetCatalog.build_default_loadout(pet_id)) as Dictionary).duplicate(true)


class FakeCollectionState:
	var battle_slots: Array[String] = ["maribo"]

	func get_battle_slots() -> Array[String]:
		return battle_slots.duplicate()


class FakeGuardianRunState:
	func get_cumulative_rewards(_pet_id: String) -> Dictionary:
		return {"signature": "none"}


class FakeHatchStatRollState:
	func get_hatch_stat_roll(_pet_id: String) -> Dictionary:
		return {"mobility": 0.0, "defense": 0.0}


var _failures: Array[String] = []


func _init() -> void:
	_verify_builder_behavior()
	_verify_facade_ownership()
	if _failures.is_empty():
		print("lingpet_overflow_guardian_snapshot_builder_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_builder_behavior() -> void:
	var loadout := LingpetCatalog.build_default_loadout("maribo")
	var loadout_state := FakeLoadoutState.new({"maribo": loadout})
	var builder := LingpetOverflowGuardianSnapshotBuilder.new()
	var replacement: Dictionary = builder.build_replacement("maribo", loadout_state)
	_expect(str(replacement.get("pet_id", "")) == "maribo", "replacement should preserve the pending guardian id")
	_expect(bool(replacement.get("pending_roll", false)), "replacement should be marked as a pending roll")
	_expect(not (replacement.get("active_skills", []) as Array).is_empty(), "replacement should expose its rolled active skills")
	_expect(not (replacement.get("stats", {}) as Dictionary).is_empty(), "replacement should expose catalog stats")

	var corrupted_replacement := replacement
	corrupted_replacement["display_name"] = "corrupt"
	(corrupted_replacement.get("stats", {}) as Dictionary)["defense_rate"] = -999.0
	var replacement_again: Dictionary = builder.build_replacement("maribo", loadout_state)
	_expect(str(replacement_again.get("display_name", "")) != "corrupt", "replacement cache should return a deep copy")
	_expect(float((replacement_again.get("stats", {}) as Dictionary).get("defense_rate", -999.0)) >= 0.0, "nested replacement cache data should not be mutable by callers")

	var current: Dictionary = builder.build_current(
		FakeCollectionState.new(),
		loadout_state,
		FakeGuardianRunState.new(),
		FakeHatchStatRollState.new()
	)
	_expect(str(current.get("pet_id", "")) == "maribo", "current snapshot should read the live battle slot")
	_expect(not bool(current.get("pending_roll", true)), "current guardian should not be marked as pending")
	_expect(not (current.get("active_skills", []) as Array).is_empty(), "current snapshot should expose effective active skills")

	var empty_passive_loadout := loadout.duplicate(true)
	empty_passive_loadout["passive_skill_id"] = ""
	empty_passive_loadout["passive_skill_level"] = 0
	empty_passive_loadout["passive_skill_ids"] = []
	empty_passive_loadout["passive_skill_levels"] = {}
	loadout_state.loadouts["maribo"] = empty_passive_loadout
	var empty_passive: Dictionary = builder.build_replacement("maribo", loadout_state)
	_expect((empty_passive.get("passive_skills", []) as Array).is_empty(), "an empty rolled passive slot should stay empty")
	_expect(str(empty_passive.get("passive_skill_name", "")).is_empty(), "empty passive slots should not borrow a catalog default")

	var collected := LingpetOverflowGuardianSnapshotBuilder.collect_loadout_skill_ids(
		{"active_skill_ids": ["first", "first", "second"], "active_skill_id": "fallback"},
		"active_skill_ids",
		"active_skill_id"
	)
	_expect(collected == ["first", "second"], "skill-id projection should preserve order and remove duplicates")


func _verify_facade_ownership() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var builder_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_overflow_guardian_snapshot_builder.gd")
	_expect(source.find("LingpetOverflowGuardianSnapshotBuilder") >= 0, "egg runtime should preload the overflow snapshot builder")
	_expect(source.find("_overflow_guardian_snapshot_builder.enrich_choice_snapshot") >= 0, "public overflow snapshot should delegate enrichment")
	_expect(source.find("_overflow_guardian_snapshot_builder.invalidate_replacement()") >= 0, "new preview loadouts should invalidate replacement projection")
	_expect(source.find("LingpetCatalog") == -1, "egg runtime should not regain direct catalog ownership")
	_expect(builder_source.find("LingpetCatalog") >= 0, "overflow snapshot builder should own comparison catalog projection")
	for retired_field in [
		"_overflow_current_guardian_profile",
		"_overflow_current_guardian_cache_key",
		"_overflow_current_guardian_cache",
		"_overflow_replacement_guardian_cache_key",
		"_overflow_replacement_guardian_cache",
	]:
		_expect(source.find("var %s" % retired_field) == -1, "egg runtime should not retain snapshot-builder state: %s" % retired_field)
	for retired_function in [
		"func _get_overflow_replacement_guardian_snapshot",
		"func _get_overflow_current_guardian_snapshot",
		"func _build_overflow_skill_entry",
		"func _collect_loadout_skill_ids",
	]:
		_expect(source.find(retired_function) == -1, "egg runtime should not retain snapshot-builder logic: %s" % retired_function)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
