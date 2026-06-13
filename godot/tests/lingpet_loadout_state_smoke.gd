extends SceneTree

const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const LingpetLoadoutState := preload("res://scripts/lingpet/lingpet_loadout_state.gd")


class SchemaGatedOwner:
	extends RefCounted

	var scene_state: Object = BattleSceneState.new()
	var rejected_keys: Array[String] = []

	func _init() -> void:
		scene_state.reset()

	func _get(property: StringName) -> Variant:
		var key := str(property)
		if scene_state.has_key(key):
			return scene_state.get_value(key)
		return null

	func _set(property: StringName, value: Variant) -> bool:
		var key := str(property)
		if not scene_state.has_key(key):
			rejected_keys.append(key)
			return false
		scene_state.set_value(key, value)
		return true

	func value_of(key: String) -> Variant:
		return scene_state.get_value(key) if scene_state.has_key(key) else null

	func has_schema_key(key: String) -> bool:
		return scene_state.has_key(key)


var _failures: Array[String] = []


func _init() -> void:
	_verify_two_slot_roundtrip_survives_owner_sync()
	_verify_normalize_whitelist_preserves_arrays()
	_verify_legacy_one_slot_migrates_to_arrays()
	_verify_explicit_empty_loadout_preserves_no_skill_shell()
	_verify_empty_second_slot_preserves_one_slot_behavior()
	_verify_second_slot_owner_keys_are_schema_declared()

	if _failures.is_empty():
		print("lingpet_loadout_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_two_slot_roundtrip_survives_owner_sync() -> void:
	var owner := SchemaGatedOwner.new()
	var state := LingpetLoadoutState.new()
	var loadout: Dictionary = state.set_pet_loadout(
		owner,
		"maribo",
		"maribo_hydro_sphere",
		"lingpet_resonance_boost",
		3,
		2,
		"maribo_bubble_trap",
		"lingpet_afterglow_leak",
		4,
		5
	)
	_expect_two_slot_loadout(loadout, "direct set")
	_expect(owner.rejected_keys.is_empty(), "schema-gated owner should accept all loadout sync keys")
	_expect_str(str(owner.value_of("lingpet_second_active_skill_id")), "maribo_bubble_trap", "lingpet second active owner key should sync")
	_expect_eq(int(owner.value_of("lingpet_second_active_skill_level")), 4, "lingpet second active level owner key should sync")
	_expect_str(str(owner.value_of("ringpet_second_active_skill_id")), "maribo_bubble_trap", "ringpet second active owner key should sync")
	_expect_eq(int(owner.value_of("ringpet_second_active_skill_level")), 4, "ringpet second active level owner key should sync")
	_expect_str(str(owner.value_of("lingpet_second_passive_skill_id")), "lingpet_afterglow_leak", "lingpet second passive owner key should sync")
	_expect_eq(int(owner.value_of("lingpet_second_passive_skill_level")), 5, "lingpet second passive level owner key should sync")
	_expect_str(str(owner.value_of("ringpet_second_passive_skill_id")), "lingpet_afterglow_leak", "ringpet second passive owner key should sync")
	_expect_eq(int(owner.value_of("ringpet_second_passive_skill_level")), 5, "ringpet second passive level owner key should sync")

	var owner_loadouts: Dictionary = owner.value_of("lingpet_loadouts") as Dictionary
	_expect(owner_loadouts.has("maribo"), "owner loadout snapshot should contain Maribo")
	_expect_two_slot_loadout(owner_loadouts.get("maribo", {}) as Dictionary, "owner snapshot")
	var ringpet_loadouts: Dictionary = owner.value_of("ringpet_loadouts") as Dictionary
	_expect(ringpet_loadouts.has("maribo"), "ringpet owner loadout mirror should contain Maribo")

	var restored_state := LingpetLoadoutState.new()
	restored_state.sync_from_owner(owner)
	var restored := restored_state.get_loadout("maribo")
	_expect_two_slot_loadout(restored, "sync_from_owner roundtrip")


func _verify_normalize_whitelist_preserves_arrays() -> void:
	var state := LingpetLoadoutState.new()
	state.set_loadouts({
		"maribo": {
			"active_skill_ids": ["maribo_hydro_sphere", "maribo_bubble_trap"],
			"active_skill_levels": {
				"maribo_hydro_sphere": 2,
				"maribo_bubble_trap": 5,
			},
			"active_slot_count": 2,
			"passive_skill_ids": ["lingpet_resonance_boost", "lingpet_afterglow_leak"],
			"passive_skill_levels": {
				"lingpet_resonance_boost": 3,
				"lingpet_afterglow_leak": 4,
			},
			"passive_slot_count": 2,
		},
	})
	var snapshot: Dictionary = state.get_loadouts().get("maribo", {}) as Dictionary
	_expect(snapshot.has("active_skill_ids"), "_normalize_loadout whitelist should return active_skill_ids")
	_expect(snapshot.has("active_skill_levels"), "_normalize_loadout whitelist should return active_skill_levels")
	_expect(snapshot.has("active_slot_count"), "_normalize_loadout whitelist should return active_slot_count")
	_expect(snapshot.has("second_active_skill_id"), "_normalize_loadout whitelist should return second active alias")
	_expect(snapshot.has("second_passive_skill_id"), "_normalize_loadout whitelist should return second passive alias")
	_expect_eq(int(snapshot.get("active_slot_count", 0)), 2, "active slot count should survive set_loadouts")
	_expect_eq(int(snapshot.get("passive_slot_count", 0)), 2, "passive slot count should survive set_loadouts")
	_expect_str(_array_str_at(snapshot.get("active_skill_ids", []), 1), "maribo_bubble_trap", "active second slot should survive whitelist normalization")
	_expect_eq(_level_for(snapshot, "active_skill_levels", "maribo_bubble_trap"), 5, "active second slot level should survive whitelist normalization")
	_expect_str(_array_str_at(snapshot.get("passive_skill_ids", []), 1), "lingpet_afterglow_leak", "passive second slot should survive whitelist normalization")
	_expect_eq(_level_for(snapshot, "passive_skill_levels", "lingpet_afterglow_leak"), 4, "passive second slot level should survive whitelist normalization")

	var roundtrip := LingpetLoadoutState.new()
	roundtrip.set_loadouts(state.get_loadouts())
	_expect_str(_array_str_at(roundtrip.get_loadout("maribo").get("active_skill_ids", []), 1), "maribo_bubble_trap", "second active slot should survive a set_loadouts roundtrip")


func _verify_legacy_one_slot_migrates_to_arrays() -> void:
	var state := LingpetLoadoutState.new()
	state.set_loadouts({
		"maribo": {
			"active_skill_id": "maribo_bubble_trap",
			"active_skill_level": 2,
			"passive_skill_id": "maribo_resonance_boost",
			"passive_skill_level": 3,
		},
	})
	var loadout := state.get_loadout("maribo")
	_expect_str(str(loadout.get("active_skill_id", "")), "maribo_bubble_trap", "legacy active alias should become slot 0")
	_expect_eq(int(loadout.get("active_skill_level", 0)), 2, "legacy active level should become slot 0 level")
	_expect_eq((loadout.get("active_skill_ids", []) as Array).size(), 1, "legacy active loadout should expose exactly one active slot")
	_expect_eq(int(loadout.get("active_slot_count", 0)), 1, "legacy active loadout should default to one active slot")
	_expect_str(str(loadout.get("second_active_skill_id", "")), "", "legacy active loadout should leave second active empty")
	_expect_str(str(loadout.get("passive_skill_id", "")), "lingpet_resonance_boost", "legacy passive alias should normalize into slot 0")
	_expect_eq((loadout.get("passive_skill_ids", []) as Array).size(), 1, "legacy passive loadout should expose exactly one passive slot")
	_expect_eq(int(loadout.get("passive_slot_count", 0)), 1, "legacy passive loadout should default to one passive slot")
	_expect_str(str(loadout.get("second_passive_skill_id", "")), "", "legacy passive loadout should leave second passive empty")


func _verify_empty_second_slot_preserves_one_slot_behavior() -> void:
	var owner := SchemaGatedOwner.new()
	var state := LingpetLoadoutState.new()
	var loadout: Dictionary = state.set_pet_loadout(
		owner,
		"maribo",
		"maribo_hydro_sphere",
		"lingpet_resonance_boost",
		1,
		1
	)
	_expect_eq((loadout.get("active_skill_ids", []) as Array).size(), 1, "one-slot active loadout should still expose one active id")
	_expect_eq(int(loadout.get("active_slot_count", 0)), 1, "one-slot active loadout should keep active_slot_count at one")
	_expect_str(str(loadout.get("second_active_skill_id", "")), "", "one-slot active loadout should keep second active empty")
	_expect_eq((loadout.get("passive_skill_ids", []) as Array).size(), 1, "one-slot passive loadout should still expose one passive id")
	_expect_eq(int(loadout.get("passive_slot_count", 0)), 1, "one-slot passive loadout should keep passive_slot_count at one")
	_expect_str(str(loadout.get("second_passive_skill_id", "")), "", "one-slot passive loadout should keep second passive empty")
	_expect_str(str(owner.value_of("lingpet_second_active_skill_id")), "", "one-slot owner sync should clear second active id")
	_expect_eq(int(owner.value_of("lingpet_second_active_skill_level")), 0, "one-slot owner sync should clear second active level")
	_expect_str(str(owner.value_of("lingpet_second_passive_skill_id")), "", "one-slot owner sync should clear second passive id")
	_expect_eq(int(owner.value_of("lingpet_second_passive_skill_level")), 0, "one-slot owner sync should clear second passive level")


func _verify_explicit_empty_loadout_preserves_no_skill_shell() -> void:
	var owner := SchemaGatedOwner.new()
	var state := LingpetLoadoutState.new()
	var loadout: Dictionary = state.set_pet_loadout(
		owner,
		"lumion",
		"",
		"",
		0,
		0
	)
	_expect_str(str(loadout.get("active_skill_id", "")), "", "explicit empty loadout should not inject a default active id")
	_expect_eq(int(loadout.get("active_skill_level", 0)), 0, "explicit empty active level should stay zero")
	_expect_eq(int(loadout.get("active_slot_count", -1)), 0, "explicit empty loadout should keep active_slot_count at zero")
	_expect_eq((loadout.get("active_skill_ids", []) as Array).size(), 0, "explicit empty loadout should keep active ids empty")
	_expect_str(str(loadout.get("passive_skill_id", "")), "", "explicit empty loadout should not inject a default passive id")
	_expect_eq(int(loadout.get("passive_skill_level", 0)), 0, "explicit empty passive level should stay zero")
	_expect_eq(int(loadout.get("passive_slot_count", -1)), 0, "explicit empty loadout should keep passive_slot_count at zero")
	_expect_eq((loadout.get("passive_skill_ids", []) as Array).size(), 0, "explicit empty loadout should keep passive ids empty")
	_expect_str(str(owner.value_of("lingpet_active_skill_id")), "", "owner active key should stay empty for an explicit empty loadout")
	_expect_eq(int(owner.value_of("lingpet_active_skill_level")), 0, "owner active level should stay zero for an explicit empty loadout")
	_expect_str(str(owner.value_of("lingpet_passive_skill_id")), "", "owner passive key should stay empty for an explicit empty loadout")
	_expect_eq(int(owner.value_of("lingpet_passive_skill_level")), 0, "owner passive level should stay zero for an explicit empty loadout")


func _verify_second_slot_owner_keys_are_schema_declared() -> void:
	var owner := SchemaGatedOwner.new()
	for key in [
		"lingpet_second_active_skill_id",
		"ringpet_second_active_skill_id",
		"lingpet_second_active_skill_level",
		"ringpet_second_active_skill_level",
		"lingpet_second_passive_skill_id",
		"ringpet_second_passive_skill_id",
		"lingpet_second_passive_skill_level",
		"ringpet_second_passive_skill_level",
		"lingpet_second_skill_id",
		"ringpet_second_skill_id",
		"lingpet_second_skill_name",
		"ringpet_second_skill_name",
		"lingpet_second_skill_max_level",
		"ringpet_second_skill_max_level",
		"lingpet_second_skill_cooldown",
		"ringpet_second_skill_cooldown",
		"lingpet_second_skill_cooldown_duration",
		"ringpet_second_skill_cooldown_duration",
		"lingpet_second_skill_ready",
		"ringpet_second_skill_ready",
		"lingpet_second_skill_winding_up",
		"ringpet_second_skill_winding_up",
		"lingpet_second_skill_windup_ratio",
		"ringpet_second_skill_windup_ratio",
	]:
		_expect(owner.has_schema_key(str(key)), "%s should be declared in BattleSceneState.DEFAULT_VALUES" % str(key))


func _expect_two_slot_loadout(loadout: Dictionary, label: String) -> void:
	_expect_str(str(loadout.get("active_skill_id", "")), "maribo_hydro_sphere", "%s should keep first active alias" % label)
	_expect_eq(int(loadout.get("active_skill_level", 0)), 3, "%s should keep first active level alias" % label)
	_expect_eq(int(loadout.get("active_slot_count", 0)), 2, "%s should keep active_slot_count=2" % label)
	_expect_str(_array_str_at(loadout.get("active_skill_ids", []), 0), "maribo_hydro_sphere", "%s should keep active slot 0" % label)
	_expect_str(_array_str_at(loadout.get("active_skill_ids", []), 1), "maribo_bubble_trap", "%s should keep active slot 1" % label)
	_expect_eq(_level_for(loadout, "active_skill_levels", "maribo_hydro_sphere"), 3, "%s should keep active slot 0 level" % label)
	_expect_eq(_level_for(loadout, "active_skill_levels", "maribo_bubble_trap"), 4, "%s should keep active slot 1 level" % label)
	_expect_str(str(loadout.get("second_active_skill_id", "")), "maribo_bubble_trap", "%s should expose second active alias" % label)
	_expect_eq(int(loadout.get("second_active_skill_level", 0)), 4, "%s should expose second active level alias" % label)
	_expect_str(str(loadout.get("passive_skill_id", "")), "lingpet_resonance_boost", "%s should keep first passive alias" % label)
	_expect_eq(int(loadout.get("passive_skill_level", 0)), 2, "%s should keep first passive level alias" % label)
	_expect_eq(int(loadout.get("passive_slot_count", 0)), 2, "%s should keep passive_slot_count=2" % label)
	_expect_str(_array_str_at(loadout.get("passive_skill_ids", []), 0), "lingpet_resonance_boost", "%s should keep passive slot 0" % label)
	_expect_str(_array_str_at(loadout.get("passive_skill_ids", []), 1), "lingpet_afterglow_leak", "%s should keep passive slot 1" % label)
	_expect_eq(_level_for(loadout, "passive_skill_levels", "lingpet_resonance_boost"), 2, "%s should keep passive slot 0 level" % label)
	_expect_eq(_level_for(loadout, "passive_skill_levels", "lingpet_afterglow_leak"), 5, "%s should keep passive slot 1 level" % label)
	_expect_str(str(loadout.get("second_passive_skill_id", "")), "lingpet_afterglow_leak", "%s should expose second passive alias" % label)
	_expect_eq(int(loadout.get("second_passive_skill_level", 0)), 5, "%s should expose second passive level alias" % label)


func _array_str_at(value: Variant, index: int) -> String:
	if value is Array and index >= 0 and index < (value as Array).size():
		return str((value as Array)[index])
	return ""


func _level_for(loadout: Dictionary, levels_key: String, skill_id: String) -> int:
	var levels: Dictionary = loadout.get(levels_key, {}) as Dictionary
	return int(levels.get(skill_id, 0))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
