extends SceneTree

const RuntimePerkSnapshotBuilder := preload("res://scripts/characters/runtime_perk_snapshot_builder.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_snapshot_contract()
	_verify_runtime_state_snapshot_facade()
	_verify_selected_choice_snapshot_contract()
	_verify_state_snapshot_wrapper()

	if _failures.is_empty():
		print("runtime_perk_snapshot_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_snapshot_contract() -> void:
	var state := FakeState.new()
	var builder := RuntimePerkSnapshotBuilder.new()
	var snapshot: Dictionary = builder.build(state, FakeStarpointAbsorption.new(), FakeDeferredInstants.new())
	_expect(int(_get_dict(snapshot.get("runtime_skill_levels", {})).get("dash_lightweight", 0)) == 2, "snapshot should include runtime levels")
	_expect(int(_get_dict(snapshot.get("effective_runtime_skill_levels", {})).get("dash_lightweight", 0)) == 4, "snapshot should include effective levels from state method")
	_expect(bool(snapshot.get("choice_active", false)), "snapshot should include choice-active state")
	_expect(str(snapshot.get("feedback_text", "")) == "feedback", "snapshot should include feedback text")
	_expect(int(_get_dict(snapshot.get("perk_slot_status", {})).get("count", 0)) == 11, "snapshot should expose current perk slot status")
	_expect(bool(snapshot.get("pending_dimension_gate_after_spawn_intro", false)), "snapshot should expose pending deferred Dimension Gate")
	_expect(int(snapshot.get("pending_dimension_gate_origin_stage", 0)) == 5, "snapshot should expose deferred Dimension Gate origin stage")
	_expect(bool(snapshot.get("pending_full_gauge_after_spawn_intro", false)), "snapshot should expose pending deferred full gauge")
	_expect(int(snapshot.get("pending_full_gauge_origin_stage", 0)) == 6, "snapshot should expose deferred full-gauge origin stage")
	_expect(str(_get_dict(snapshot.get("starpoint_absorption_effect", {})).get("state", "")) == "active", "snapshot should include starpoint absorption snapshot")

	var runtime_levels: Dictionary = _get_dict(snapshot.get("runtime_skill_levels", {}))
	runtime_levels["dash_lightweight"] = 99
	_expect(int(state.runtime_skill_levels.get("dash_lightweight", 0)) == 2, "snapshot runtime levels should be deep-copied")
	var current_choices: Array = _get_array(snapshot.get("current_choices", []))
	if not current_choices.is_empty():
		_get_dict(current_choices[0])["id"] = "mutated"
	_expect(str(_get_dict(state.current_choices[0]).get("id", "")) == "choice_a", "snapshot choices should be deep-copied")


func _verify_runtime_state_snapshot_facade() -> void:
	var state := FakeState.new()
	state._starpoint_absorption = FakeStarpointAbsorption.new()
	state._deferred_instants = FakeDeferredInstants.new()
	var builder := RuntimePerkSnapshotBuilder.new()
	var snapshot: Dictionary = builder.build_from_runtime_state(state)
	_expect(str(_get_dict(snapshot.get("starpoint_absorption_effect", {})).get("state", "")) == "active", "runtime-state snapshot facade should read starpoint absorption helper")
	_expect(bool(snapshot.get("pending_dimension_gate_after_spawn_intro", false)), "runtime-state snapshot facade should read deferred Dimension Gate helper")
	_expect(int(snapshot.get("pending_full_gauge_origin_stage", 0)) == 6, "runtime-state snapshot facade should read deferred full-gauge origin stage")
	_expect(builder.build_from_runtime_state(null).is_empty(), "runtime-state snapshot facade should reject missing state")


func _verify_selected_choice_snapshot_contract() -> void:
	var builder := RuntimePerkSnapshotBuilder.new()
	var choice := {
		"name": "",
		"max_level": 5,
		"nested": {"value": 1},
	}
	var snapshot: Dictionary = builder.build_selected_choice("dash_lightweight", choice, {"dash_lightweight": 2})
	_expect(str(snapshot.get("id", "")) == "dash_lightweight", "selected choice snapshot should stamp the selected id")
	_expect(str(snapshot.get("name", "")) == "dash_lightweight", "selected choice snapshot should use the id as name fallback")
	_expect(int(snapshot.get("current_level", -1)) == 1, "selected choice snapshot should expose the applied previous level")
	_expect(int(snapshot.get("next_level", 0)) == 2, "selected choice snapshot should expose the applied next level")
	_expect(int(snapshot.get("level_delta", 0)) == 1, "selected choice snapshot should expose the level delta")

	_get_dict(snapshot.get("nested", {}))["value"] = 9
	_expect(int(_get_dict(choice.get("nested", {})).get("value", 0)) == 1, "selected choice snapshot should be deep-copied")

	var pending_snapshot: Dictionary = builder.build_selected_choice("instant_gauge_full", {"name": "Instant"}, {})
	_expect(not pending_snapshot.has("level_delta"), "unleveled selected choice snapshot should not invent a level delta")


func _verify_state_snapshot_wrapper() -> void:
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = {"dash_lightweight": 1}
	state.current_choices = [{"id": "choice_a"}]
	state.current_perk_slot_status = {"count": 1, "limit": 12}
	state.feedback_text = "state feedback"
	state.feedback_timer = 0.5
	var snapshot: Dictionary = state.get_snapshot()
	_expect(int(_get_dict(snapshot.get("runtime_skill_levels", {})).get("dash_lightweight", 0)) == 1, "state wrapper should use snapshot helper for levels")
	_expect(str(snapshot.get("feedback_text", "")) == "state feedback", "state wrapper should preserve feedback text")
	_expect(int(_get_dict(snapshot.get("perk_slot_status", {})).get("limit", 0)) == 12, "state wrapper should preserve perk slot status")
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var builder_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_snapshot_builder.gd")
	var wrapper_body: String = _function_body(state_source, "func get_snapshot(")
	_expect(builder_source.find("func build_from_runtime_state(") >= 0, "snapshot builder should expose runtime-state snapshot facade")
	_expect(wrapper_body.find("_snapshot_builder.build_from_runtime_state") >= 0, "state snapshot wrapper should delegate through runtime-state facade")
	_expect(wrapper_body.find("_snapshot_builder.build(self, _starpoint_absorption, _deferred_instants)") < 0, "state snapshot wrapper should not pass helper objects inline")


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeState:
	var runtime_skill_levels := {"dash_lightweight": 2}
	var starpoint_for_skills := 1
	var pending_skill_choices := 2
	var choice_active := true
	var current_choices := [{"id": "choice_a", "nested": {"value": 1}}]
	var selected_index := 0
	var animation_time := 0.4
	var particles := [{"age": 0.1}]
	var gold_from_perks := 8
	var item_gold_gain_multiplier := 1.2
	var item_perk_level_bonus := 1
	var viper_ignition_aura_active := true
	var pending_unlock_swap := {"choice_id": "unlock_a"}
	var unlock_swap_selected_index := 1
	var choice_flight_effect := {"active": true}
	var unlock_showcase := {"active": true}
	var feedback_text := "feedback"
	var feedback_timer := 0.8
	var last_selected_id := "choice_a"
	var last_selected_choice := {"id": "choice_a"}
	var selected_choice_sequence := 3
	var current_choice_context := {"stage": 5}
	var current_perk_slot_status := {"count": 11, "limit": 12}
	var _starpoint_absorption: Object = null
	var _deferred_instants: Object = null

	func get_effective_runtime_skill_levels() -> Dictionary:
		return {"dash_lightweight": 4}

	func get_viper_ignition_aura_level_bonus() -> int:
		return 2

	func get_viper_ignition_aura_gold_bonus() -> int:
		return 50


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


class FakeStarpointAbsorption:
	func get_snapshot() -> Dictionary:
		return {"state": "active"}


class FakeDeferredInstants:
	func has_pending_dimension_gate() -> bool:
		return true

	func get_dimension_gate_origin_stage() -> int:
		return 5

	func has_pending_full_gauge() -> bool:
		return true

	func get_full_gauge_origin_stage() -> int:
		return 6
