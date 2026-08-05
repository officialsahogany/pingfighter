extends SceneTree

const LingpetCompanionSkillPersistence := preload("res://scripts/lingpet/lingpet_companion_skill_persistence.gd")
const LingpetCompanionSkillState := preload("res://scripts/lingpet/lingpet_companion_skill_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_save_restore_and_shared_trigger_count()
	_verify_shared_cooldown_blocks_fresh_restore_and_stored_slots()
	_verify_stored_cooldowns_migrate_legacy_flat_snapshots()
	_verify_slot_state_accessor_clamps()
	_verify_runtime_delegates_persistence_owner()

	if _failures.is_empty():
		print("lingpet_companion_skill_persistence_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_save_restore_and_shared_trigger_count() -> void:
	var persistence := LingpetCompanionSkillPersistence.new()
	var states: Array = [LingpetCompanionSkillState.new(), LingpetCompanionSkillState.new()]
	states[0].complete_launch(Vector2(10.0, 20.0), 40.0, 0.45)
	persistence.record_launch(0, states)
	_expect_eq(persistence.get_trigger_count(), 1, "slot 0 launch should advance the shared trigger count")
	states[1].complete_launch(Vector2(30.0, 40.0), 25.0, 0.45)
	persistence.record_launch(1, states)
	_expect_eq(persistence.get_trigger_count(), 2, "slot 1 launch should share the same trigger sequence")
	persistence.save_current("Maribo", states, ["skill_a", "skill_b"])

	persistence.reset_states(states)
	_expect_eq(states[0].trigger_count, 0, "reset should clear slot 0 trigger count")
	_expect_eq(states[1].trigger_count, 0, "reset should clear slot 1 trigger count")
	_expect(persistence.restore_current("maribo", states, ["skill_a", "skill_b"]), "restore should find the normalized pet id")
	_expect_float(states[0].cooldown, 40.0, "restore should recover slot 0 cooldown")
	_expect_float(states[1].cooldown, 25.0, "restore should recover slot 1 cooldown")
	_expect_eq(states[0].trigger_count, 2, "restore should sync shared trigger count into slot 0")
	_expect_eq(states[1].trigger_count, 2, "restore should sync shared trigger count into slot 1")
	_expect(not persistence.restore_current("lunabi", states, ["skill_a", "skill_b"]), "missing pet restore should reset states and return false")
	_expect_eq(states[0].trigger_count, 0, "missing pet restore should reset slot 0")
	_expect_eq(persistence.get_trigger_count(), 0, "missing pet restore should clear shared trigger count")


func _verify_shared_cooldown_blocks_fresh_restore_and_stored_slots() -> void:
	var persistence := LingpetCompanionSkillPersistence.new()
	var states: Array = [LingpetCompanionSkillState.new(), LingpetCompanionSkillState.new()]
	states[0].complete_launch(Vector2(10.0, 20.0), 40.0, 0.45)
	persistence.record_launch(0, states)
	persistence.start_shared_cooldown(10.0, states)
	_expect_float(persistence.get_shared_cooldown(), 10.0, "launch should start a shared lingpet skill cooldown")
	_expect_float(states[0].cooldown, 40.0, "shared cooldown should not shorten the launched skill cooldown")
	_expect_float(states[1].cooldown, 10.0, "shared cooldown should lock the other active skill slot")

	persistence.save_current("maribo", states, ["skill_a", "skill_b"])
	persistence.advance_states(4.0, states)
	persistence.advance_stored_cooldowns(4.0, "lunabi", true, 2)
	var stored: Dictionary = persistence.state_by_pet_id.get("maribo", {}) as Dictionary
	_expect_float(float((stored.get("slot_0", {}) as Dictionary).get("cooldown", 0.0)), 36.0, "stored launched skill cooldown should keep ticking")
	_expect_float(float((stored.get("slot_1", {}) as Dictionary).get("cooldown", 0.0)), 6.0, "stored non-launched slot should preserve the shared cooldown floor")

	var fresh_states: Array = [LingpetCompanionSkillState.new(), LingpetCompanionSkillState.new()]
	_expect(not persistence.restore_current("lunabi", fresh_states, ["skill_a", "skill_b"]), "fresh pet restore should miss stored state")
	_expect_float(fresh_states[0].cooldown, 6.0, "fresh pet restore should inherit the remaining shared cooldown")
	_expect_float(fresh_states[1].cooldown, 6.0, "fresh pet second slot should inherit the remaining shared cooldown")
	persistence.advance_states(6.1, fresh_states)
	_expect_float(persistence.get_shared_cooldown(), 0.0, "shared cooldown should expire with normal state advancement")
	_expect_float(fresh_states[0].cooldown, 0.0, "fresh pet inherited cooldown should tick down normally")


func _verify_stored_cooldowns_migrate_legacy_flat_snapshots() -> void:
	var persistence := LingpetCompanionSkillPersistence.new()
	persistence.state_by_pet_id["red_dragon"] = {
		"cooldown": 20.0,
		"trigger_count": 3,
		"last_gain": 1.0,
		"origin": Vector2(12.0, 34.0),
	}
	persistence.advance_stored_cooldowns(3.0, "maribo", true, 2)
	var stored: Dictionary = persistence.state_by_pet_id.get("red_dragon", {}) as Dictionary
	var slot0: Dictionary = stored.get("slot_0", {}) as Dictionary
	var slot1: Dictionary = stored.get("slot_1", {}) as Dictionary
	_expect_float(float(slot0.get("cooldown", 0.0)), 17.0, "legacy flat snapshot should migrate into slot 0 and advance")
	_expect_float(float(slot1.get("cooldown", -1.0)), 0.0, "legacy flat snapshot should leave slot 1 cold")
	_expect_eq(int(stored.get("trigger_count", 0)), 3, "legacy flat snapshot should preserve shared trigger count")

	persistence.state_by_pet_id["maribo"] = {
		"slot_0": {"cooldown": 12.0},
		"slot_1": {"cooldown": 7.0},
		"trigger_count": 2,
	}
	persistence.advance_stored_cooldowns(5.0, "maribo", true, 2)
	var active_stored: Dictionary = persistence.state_by_pet_id.get("maribo", {}) as Dictionary
	_expect_float(float((active_stored.get("slot_0", {}) as Dictionary).get("cooldown", 0.0)), 12.0, "active companion stored cooldown should not tick")


func _verify_slot_state_accessor_clamps() -> void:
	var persistence := LingpetCompanionSkillPersistence.new()
	var slot0 := LingpetCompanionSkillState.new()
	var slot1 := LingpetCompanionSkillState.new()
	var states: Array = [slot0, slot1]
	_expect(persistence.get_state_for_slot(states, 0) == slot0, "slot accessor should return slot 0")
	_expect(persistence.get_state_for_slot(states, 1) == slot1, "slot accessor should return slot 1")
	_expect(persistence.get_state_for_slot(states, -4) == slot0, "slot accessor should clamp negative indexes to slot 0")
	_expect(persistence.get_state_for_slot(states, 99) == slot1, "slot accessor should clamp high indexes to the final slot")
	_expect(persistence.get_state_for_slot([], 0) == null, "slot accessor should tolerate an empty state array")


func _verify_runtime_delegates_persistence_owner() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_skill_persistence.gd")
	var surface_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_runtime_surface.gd")
	_expect(runtime_source.find("LingpetCompanionSkillPersistence") >= 0, "egg runtime should preload the companion skill persistence owner")
	_expect(runtime_source.find("_companion_skill_persistence.advance_stored_cooldowns") >= 0, "runtime stored cooldown wrapper should delegate to the persistence owner")
	_expect(runtime_source.find("var _companion_skill_trigger_count") < 0, "runtime should not keep the shared skill trigger count locally")
	_expect(runtime_source.find("func _build_companion_skill_persistent_snapshot") < 0, "runtime should not keep dead companion skill snapshot wrappers")
	_expect(runtime_source.find("func _normalize_companion_skill_persistent_snapshot") < 0, "runtime should not keep dead companion skill snapshot normalization wrappers")
	_expect(runtime_source.find("func _empty_companion_skill_state_snapshot") < 0, "runtime should not keep dead companion skill empty-snapshot wrappers")
	_expect(runtime_source.find("func _skill_state_slot_key") < 0, "runtime should not keep the old companion skill slot-key wrapper")
	_expect(runtime_source.find("func _get_companion_skill_state_for_slot") < 0, "runtime should not keep a private skill-state slot accessor wrapper")
	_expect(runtime_source.find("_skill_runtime_surface.get_active_surface_for_slot") >= 0, "runtime should ask the skill runtime surface for per-slot active-skill surfaces")
	_expect(surface_source.find("companion_skill_persistence.get_state_for_slot") >= 0, "skill runtime surface should delegate clamped skill-state slot lookup to the persistence owner")
	_expect(owner_source.find("normalize_persistent_snapshot") >= 0, "persistence owner should own snapshot normalization")
	_expect(owner_source.find("state_by_pet_id") >= 0, "persistence owner should own the per-pet stored snapshot dictionary")
	_expect(owner_source.find("func get_state_for_slot") >= 0, "persistence owner should expose the shared clamped skill-state slot lookup")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _expect_float(actual: float, expected: float, message: String, tolerance: float = 0.01) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])
