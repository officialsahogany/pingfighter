extends SceneTree

const RuntimePerkPayloadAccess := preload("res://scripts/characters/runtime_perk_payload_access.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_payload_access()
	_verify_source_contract()

	if _failures.is_empty():
		print("runtime_perk_payload_access_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_payload_access() -> void:
	var nested_dict := {"nested": {"value": 1}}
	var copied_dict: Dictionary = RuntimePerkPayloadAccess.copy_dict(nested_dict)
	_get_dict(copied_dict.get("nested", {}))["value"] = 9
	_expect(int(_get_dict(nested_dict.get("nested", {})).get("value", 0)) == 1, "copy_dict should deep-copy nested dictionary payloads")
	_expect(RuntimePerkPayloadAccess.as_dict({"value": 2}).get("value", 0) == 2, "as_dict should return dictionary payloads")
	_expect(RuntimePerkPayloadAccess.as_dict([]).is_empty(), "as_dict should reject non-dictionary payloads")

	var nested_array := [{"value": 1}]
	var copied_array: Array = RuntimePerkPayloadAccess.copy_array(nested_array)
	_get_dict(copied_array[0])["value"] = 9
	_expect(int(_get_dict(nested_array[0]).get("value", 0)) == 1, "copy_array should deep-copy nested array payloads")
	_expect(RuntimePerkPayloadAccess.as_array(["a"]).size() == 1, "as_array should return array payloads")
	_expect(RuntimePerkPayloadAccess.as_array({}).is_empty(), "as_array should reject non-array payloads")

	_expect(RuntimePerkPayloadAccess.as_vector2(Vector2(3.0, 4.0)) == Vector2(3.0, 4.0), "as_vector2 should return Vector2 payloads")
	_expect(RuntimePerkPayloadAccess.as_vector2("bad", Vector2.ONE) == Vector2.ONE, "as_vector2 should return fallback for non-Vector2 payloads")
	_expect(RuntimePerkPayloadAccess.as_finite_vector2(Vector2(5.0, 6.0)) == Vector2(5.0, 6.0), "as_finite_vector2 should return finite Vector2 payloads")
	_expect(RuntimePerkPayloadAccess.as_finite_vector2(Vector2(INF, 1.0), Vector2.ONE) == Vector2.ONE, "as_finite_vector2 should reject infinite Vector2 payloads")
	_expect(RuntimePerkPayloadAccess.as_finite_vector2("bad", Vector2.ONE) == Vector2.ONE, "as_finite_vector2 should return fallback for non-Vector2 payloads")
	_expect(RuntimePerkPayloadAccess.as_color(Color.RED) == Color.RED, "as_color should return Color payloads")
	_expect(RuntimePerkPayloadAccess.as_color("bad", Color.BLUE) == Color.BLUE, "as_color should return fallback for non-Color payloads")
	_expect(RuntimePerkPayloadAccess.as_rect2(Rect2(Vector2.ONE, Vector2(2.0, 3.0))) == Rect2(Vector2.ONE, Vector2(2.0, 3.0)), "as_rect2 should return Rect2 payloads")
	_expect(RuntimePerkPayloadAccess.as_rect2("bad", Rect2(Vector2.ONE, Vector2.ONE)) == Rect2(Vector2.ONE, Vector2.ONE), "as_rect2 should return fallback for non-Rect2 payloads")

	var source := FakeSource.new()
	_expect(RuntimePerkPayloadAccess.get_value(source, "present", "fallback") == "value", "get_value should read object properties")
	_expect(RuntimePerkPayloadAccess.get_value(source, "missing", "fallback") == "fallback", "get_value should return fallback for missing properties")
	_expect(RuntimePerkPayloadAccess.get_value(null, "present", "fallback") == "fallback", "get_value should return fallback for null sources")
	_expect(absf(RuntimePerkPayloadAccess.get_float(source, "float_value") - 1.25) < 0.001, "get_float should cast object properties")
	_expect(absf(RuntimePerkPayloadAccess.get_float(source, "missing_float", 2.5) - 2.5) < 0.001, "get_float should return fallback for missing properties")
	_expect(absf(RuntimePerkPayloadAccess.get_float(null, "float_value", 3.5) - 3.5) < 0.001, "get_float should return fallback for null sources")
	_expect(RuntimePerkPayloadAccess.get_string(source, "number") == "12", "get_string should preserve str() casting behavior")
	_expect(RuntimePerkPayloadAccess.get_string(source, "missing", "fallback") == "fallback", "get_string should return fallback for missing properties")


func _verify_source_contract() -> void:
	var flight_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_active_unlock_flight.gd")
	var choice_action_runner_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_action_runner.gd")
	var choice_apply_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_apply_flow.gd")
	var choice_completion_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_completion.gd")
	var choice_confirm_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_confirm_flow.gd")
	var choice_finish_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_finish_flow.gd")
	var choice_layout_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_layout.gd")
	var choice_offer_modifiers_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_offer_modifiers.gd")
	var choice_opening_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_opening.gd")
	var choice_selection_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_selection.gd")
	var choice_standard_path_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_standard_path.gd")
	var debug_grants_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_debug_grants.gd")
	var owner_effect_sync_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_owner_effect_sync.gd")
	var owner_projection_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_owner_projection.gd")
	var resume_safety_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_resume_safety.gd")
	var snapshot_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_snapshot_builder.gd")
	var starpoint_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_starpoint_absorption.gd")
	var unlock_showcase_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_showcase.gd")
	var unlock_showcase_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_showcase_flow.gd")
	var unlock_swap_layout_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_swap_layout.gd")
	var unlock_swap_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_swap_flow.gd")
	for source_value in [
		flight_source,
		choice_action_runner_source,
		choice_apply_flow_source,
		choice_completion_source,
		choice_confirm_flow_source,
		choice_finish_flow_source,
		choice_layout_source,
		choice_offer_modifiers_source,
		choice_opening_source,
		choice_selection_source,
		choice_standard_path_source,
		debug_grants_source,
		owner_effect_sync_source,
		owner_projection_source,
		resume_safety_source,
		snapshot_source,
		starpoint_source,
		unlock_showcase_source,
		unlock_showcase_flow_source,
		unlock_swap_layout_source,
		unlock_swap_flow_source,
	]:
		var source := str(source_value)
		_expect(source.find("RuntimePerkPayloadAccess") >= 0, "migrated payload helpers should preload payload access")
		_expect(source.find("func _get_dict(") < 0, "migrated payload helpers should not keep local dict normalizers")
		_expect(source.find("func _get_array(") < 0, "migrated payload helpers should not keep local array normalizers")
		_expect(source.find("func _get_vector2(") < 0, "migrated payload helpers should not keep local Vector2 normalizers")
		_expect(source.find("func _get_valid_velocity(") < 0, "migrated payload helpers should not keep local finite Vector2 normalizers")
		_expect(source.find("func _get_color(") < 0, "migrated payload helpers should not keep local Color normalizers")
		_expect(source.find("func _get_rect2(") < 0, "migrated payload helpers should not keep local Rect2 normalizers")
		_expect(source.find("func _safe_owner_get(") < 0, "migrated payload helpers should not keep local owner property fallback accessors")
		_expect(source.find("func _duplicate_dict_property(") < 0, "migrated payload helpers should not keep local dict property duplicate wrappers")
		_expect(source.find("func _duplicate_array_property(") < 0, "migrated payload helpers should not keep local array property duplicate wrappers")
	_expect(flight_source.find("RuntimePerkPayloadAccess.as_dict(") >= 0, "active unlock flight should use shared dict payload access")
	_expect(flight_source.find("RuntimePerkPayloadAccess.as_array(") >= 0, "active unlock flight should use shared array payload access")
	_expect(flight_source.find("RuntimePerkPayloadAccess.as_vector2(") >= 0, "active unlock flight should use shared Vector2 payload access")
	_expect(flight_source.find("RuntimePerkPayloadAccess.as_color(") >= 0, "active unlock flight should use shared Color payload access")
	_expect(flight_source.find("RuntimePerkPayloadAccess.as_rect2(") >= 0, "active unlock flight should use shared Rect2 payload access")
	_expect(choice_action_runner_source.find("RuntimePerkPayloadAccess.as_dict(") >= 0, "choice action runner should use shared dict payload access")
	_expect(choice_apply_flow_source.find("RuntimePerkPayloadAccess.as_vector2(") >= 0, "choice apply flow should use shared Vector2 payload access")
	_expect(choice_completion_source.find("RuntimePerkPayloadAccess.as_dict(") >= 0, "choice completion should use shared dict payload access")
	_expect(choice_confirm_flow_source.find("RuntimePerkPayloadAccess.as_dict(") >= 0, "choice confirm flow should use shared dict payload access")
	_expect(choice_finish_flow_source.find("RuntimePerkPayloadAccess.as_dict(") >= 0, "choice finish flow should use shared dict payload access")
	_expect(choice_layout_source.find("RuntimePerkPayloadAccess.as_vector2(") >= 0, "choice layout should use shared Vector2 payload access")
	_expect(choice_offer_modifiers_source.find("RuntimePerkPayloadAccess.as_dict(") >= 0, "choice offer modifiers should use shared dict payload access")
	_expect(choice_opening_source.find("RuntimePerkPayloadAccess.as_array(") >= 0, "choice opening should use shared array payload access")
	_expect(choice_opening_source.find("RuntimePerkPayloadAccess.as_dict(") >= 0, "choice opening should use shared dict payload access")
	_expect(choice_selection_source.find("RuntimePerkPayloadAccess.as_dict(") >= 0, "choice selection should use shared dict payload access")
	_expect(choice_standard_path_source.find("RuntimePerkPayloadAccess.as_dict(") >= 0, "choice standard path should use shared dict payload access")
	_expect(debug_grants_source.find("RuntimePerkPayloadAccess.as_dict(") >= 0, "debug grants should use shared dict payload access")
	_expect(owner_effect_sync_source.find("RuntimePerkPayloadAccess.get_value(owner, \"player_pos\"") >= 0, "owner effect sync should use shared owner property fallback access")
	_expect(owner_effect_sync_source.find("RuntimePerkPayloadAccess.get_float(owner, \"runtime_paddle_base_width\"") >= 0, "owner effect sync should use shared float access for base paddle width")
	_expect(owner_effect_sync_source.find("RuntimePerkPayloadAccess.get_float(owner, \"runtime_paddle_base_height\"") >= 0, "owner effect sync should use shared float access for base paddle height")
	_expect(owner_effect_sync_source.find("func _get_runtime_paddle_base_width(") < 0, "owner effect sync should not keep local base-width accessor")
	_expect(owner_effect_sync_source.find("func _get_runtime_paddle_base_height(") < 0, "owner effect sync should not keep local base-height accessor")
	_expect(owner_projection_source.find("RuntimePerkPayloadAccess.as_dict(") >= 0, "owner projection should use shared dict payload access")
	_expect(resume_safety_source.find("RuntimePerkPayloadAccess.get_value(owner, \"ball_vel\"") >= 0, "resume safety should use shared owner velocity fallback access")
	_expect(resume_safety_source.find("RuntimePerkPayloadAccess.as_finite_vector2(") >= 0, "resume safety should use shared finite Vector2 payload access")
	_expect(snapshot_source.find("RuntimePerkPayloadAccess.copy_dict(") >= 0, "snapshot builder should use shared deep-copy dict payload access")
	_expect(snapshot_source.find("RuntimePerkPayloadAccess.copy_array(") >= 0, "snapshot builder should use shared deep-copy array payload access")
	_expect(snapshot_source.find("RuntimePerkPayloadAccess.get_string(") >= 0, "snapshot builder should use shared string property access")
	_expect(starpoint_source.find("RuntimePerkPayloadAccess.get_value(owner, \"player_pos\"") >= 0, "starpoint absorption should use shared owner property fallback access")
	_expect(starpoint_source.find("RuntimePerkPayloadAccess.as_vector2(") >= 0, "starpoint absorption should use shared Vector2 payload access")
	_expect(unlock_showcase_source.find("RuntimePerkPayloadAccess.get_value(owner, \"ai_mode\"") >= 0, "unlock showcase should use shared owner property fallback access")
	_expect(unlock_showcase_source.find("RuntimePerkPayloadAccess.as_color(") >= 0, "unlock showcase should use shared Color payload access")
	_expect(unlock_showcase_flow_source.find("RuntimePerkPayloadAccess.as_dict(") >= 0, "unlock showcase flow should use shared dict payload access")
	_expect(unlock_swap_layout_source.find("RuntimePerkPayloadAccess.as_array(") >= 0, "unlock swap layout should use shared array payload access")
	_expect(unlock_swap_layout_source.find("RuntimePerkPayloadAccess.as_vector2(") >= 0, "unlock swap layout should use shared Vector2 payload access")
	_expect(unlock_swap_flow_source.find("RuntimePerkPayloadAccess.as_dict(") >= 0, "unlock swap flow should use shared dict payload access")
	_expect(unlock_swap_flow_source.find("RuntimePerkPayloadAccess.as_array(") >= 0, "unlock swap flow should use shared array payload access")


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeSource:
	extends RefCounted

	var present := "value"
	var number := 12
	var float_value := 1.25
