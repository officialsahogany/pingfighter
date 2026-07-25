extends SceneTree

const RuntimePerkCallbackMap := preload("res://scripts/characters/runtime_perk_callback_map.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_callback_map_semantics()
	_verify_source_contract()

	if _failures.is_empty():
		print("runtime_perk_callback_map_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_callback_map_semantics() -> void:
	var receiver := FakeCallbackReceiver.new()
	var callbacks := {
		"plain": Callable(receiver, "plain"),
		"dict_without_accepted": Callable(receiver, "dict_without_accepted"),
		"dict_with_accepted": Callable(receiver, "dict_with_accepted"),
		"invalid_dict": Callable(receiver, "plain"),
		"truthy": Callable(receiver, "truthy"),
		"intish": Callable(receiver, "intish"),
		"void": Callable(receiver, "void_call"),
		"stringish": Callable(receiver, "stringish"),
		"array_value": Callable(receiver, "array_value"),
		"object_value": Callable(receiver, "object_value"),
		"non_callable": 7,
	}

	_expect(RuntimePerkCallbackMap.get_callable(callbacks, "plain").is_valid(), "callback lookup should return valid callables")
	_expect(not RuntimePerkCallbackMap.get_callable(callbacks, "missing").is_valid(), "callback lookup should reject missing callbacks")
	_expect(not RuntimePerkCallbackMap.get_callable(callbacks, "non_callable").is_valid(), "callback lookup should reject non-callable values")
	var optional_result: Dictionary = RuntimePerkCallbackMap.call_optional(callbacks, "dict_without_accepted", ["kept"])
	_expect(bool(optional_result.get("accepted", false)), "optional callback should mark dictionaries accepted when missing the key")
	_expect(str(optional_result.get("value", "")) == "kept", "optional callback should preserve returned dictionary payload")
	var rejected_result: Dictionary = RuntimePerkCallbackMap.call_optional(callbacks, "dict_with_accepted")
	_expect(not bool(rejected_result.get("accepted", true)), "optional callback should preserve explicit accepted=false")
	_expect(bool(RuntimePerkCallbackMap.call_optional(callbacks, "plain").get("accepted", false)), "optional callback should accept non-dictionary returns")
	var missing_result: Dictionary = RuntimePerkCallbackMap.call_optional(callbacks, "missing")
	_expect(not bool(missing_result.get("accepted", true)), "optional callback should reject missing callbacks")
	_expect(str(missing_result.get("blocked_reason", "")) == "missing_missing", "optional callback should explain missing callback keys")
	var accepted_result: Dictionary = RuntimePerkCallbackMap.call_acceptance(callbacks, "dict_without_accepted", ["accepted"])
	_expect(bool(accepted_result.get("accepted", false)), "acceptance callback should mark dictionaries accepted when missing the key")
	_expect(str(accepted_result.get("value", "")) == "accepted", "acceptance callback should preserve returned dictionary payload")
	var explicit_reject: Dictionary = RuntimePerkCallbackMap.call_acceptance(callbacks, "dict_with_accepted")
	_expect(not bool(explicit_reject.get("accepted", true)), "acceptance callback should preserve explicit accepted=false")
	_expect(bool(RuntimePerkCallbackMap.call_acceptance(callbacks, "truthy").get("accepted", false)), "acceptance callback should cast non-dictionary returns")
	var missing_acceptance: Dictionary = RuntimePerkCallbackMap.call_acceptance(callbacks, "missing_acceptance")
	_expect(not bool(missing_acceptance.get("accepted", true)), "acceptance callback should reject missing callbacks")
	_expect(str(missing_acceptance.get("blocked_reason", "")) == "missing_missing_acceptance", "acceptance callback should explain missing callback keys")
	var strict_without_accepted: Dictionary = RuntimePerkCallbackMap.call_strict_acceptance(callbacks, "dict_without_accepted", ["strict"])
	_expect(not strict_without_accepted.has("accepted"), "strict acceptance should preserve dictionaries without defaulting accepted")
	_expect(str(strict_without_accepted.get("value", "")) == "strict", "strict acceptance should preserve returned dictionary payload")
	var strict_truthy: Dictionary = RuntimePerkCallbackMap.call_strict_acceptance(callbacks, "truthy")
	_expect(bool(strict_truthy.get("accepted", false)), "strict acceptance should cast non-dictionary results")
	var missing_strict: Dictionary = RuntimePerkCallbackMap.call_strict_acceptance(callbacks, "missing_strict")
	_expect(not bool(missing_strict.get("accepted", true)), "strict acceptance should reject missing callbacks")
	_expect(str(missing_strict.get("blocked_reason", "")) == "missing_missing_strict", "strict acceptance should explain missing callback keys")
	var dict_result: Dictionary = RuntimePerkCallbackMap.call_dict(callbacks, "dict_without_accepted", ["dict"])
	_expect(str(dict_result.get("value", "")) == "dict", "dict callback should return dictionary payloads unchanged")
	var invalid_dict_result: Dictionary = RuntimePerkCallbackMap.call_dict(callbacks, "invalid_dict")
	_expect(not bool(invalid_dict_result.get("accepted", true)), "dict callback should reject non-dictionary results")
	_expect(str(invalid_dict_result.get("blocked_reason", "")) == "invalid_invalid_dict", "dict callback should explain invalid callback results")
	var missing_dict_result: Dictionary = RuntimePerkCallbackMap.call_dict(callbacks, "missing_dict")
	_expect(str(missing_dict_result.get("blocked_reason", "")) == "missing_missing_dict", "dict callback should explain missing callback keys")
	_expect(RuntimePerkCallbackMap.call_bool(callbacks, "truthy", [], false), "bool callback should cast callback results")
	_expect(RuntimePerkCallbackMap.call_bool(callbacks, "missing", [], true), "bool callback should use fallback for missing callbacks")
	_expect(RuntimePerkCallbackMap.call_int(callbacks, "intish", [], -1) == 3, "int callback should cast callback results")
	_expect(RuntimePerkCallbackMap.call_int(callbacks, "missing", [], -1) == -1, "int callback should use fallback for missing callbacks")
	RuntimePerkCallbackMap.call_void(callbacks, "void")
	RuntimePerkCallbackMap.call_void(callbacks, "missing_void")
	_expect(receiver.void_calls == 1, "void callback should call valid callbacks and ignore missing callbacks")
	_expect(RuntimePerkCallbackMap.call_string(callbacks, "stringish") == "12", "string callback should preserve str() casting behavior")
	_expect(RuntimePerkCallbackMap.call_string(callbacks, "missing", [], "fallback") == "fallback", "string callback should use fallback for missing callbacks")
	_expect(RuntimePerkCallbackMap.call_array(callbacks, "array_value") == ["a", "b"], "array callback should return array results")
	_expect(RuntimePerkCallbackMap.call_array(callbacks, "plain").is_empty(), "array callback should reject non-array results")
	_expect(RuntimePerkCallbackMap.call_object(callbacks, "object_value") == receiver.payload_object, "object callback should return object results")
	_expect(RuntimePerkCallbackMap.call_object(callbacks, "plain") == null, "object callback should reject non-object results")


func _verify_source_contract() -> void:
	var apply_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_apply_flow.gd")
	var finish_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_finish_flow.gd")
	var confirm_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_confirm_flow.gd")
	var open_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_open_flow.gd")
	var update_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_update_flow.gd")
	var starpoint_collection_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_starpoint_collection_flow.gd")
	var dynamic_effects_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_dynamic_effects.gd")
	var showcase_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_showcase_flow.gd")
	var modal_input_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_modal_input.gd")
	var unlock_swap_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_swap_flow.gd")
	var unlock_apply_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_choice_apply.gd")
	var debug_grants_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_debug_grants.gd")
	var action_runner_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_action_runner.gd")
	for source_value in [apply_source, finish_source, confirm_source, open_source, update_source, starpoint_collection_source, dynamic_effects_source, showcase_flow_source, modal_input_source, unlock_swap_source, unlock_apply_source, debug_grants_source, action_runner_source]:
		var source := str(source_value)
		_expect(source.find("RuntimePerkCallbackMap") >= 0, "migrated flow helpers should preload callback-map helper")
		_expect(source.find("func _call_") < 0, "migrated flow helpers should not keep local callback caller wrappers")
		_expect(source.find("func _call_optional(") < 0, "migrated flow helpers should not keep local optional-callback callers")
		_expect(source.find("func _call_bool(") < 0, "migrated flow helpers should not keep local bool-callback callers")
		_expect(source.find("func _call_dict(") < 0, "migrated flow helpers should not keep local dict-callback callers")
		_expect(source.find("func _call_string(") < 0, "migrated flow helpers should not keep local string-callback callers")
		_expect(source.find("func _call_array(") < 0, "migrated flow helpers should not keep local array-callback callers")
		_expect(source.find("func _call_object(") < 0, "migrated flow helpers should not keep local object-callback callers")
		_expect(source.find("func _call_int(") < 0, "migrated flow helpers should not keep local int-callback callers")
		_expect(source.find("func _call_void(") < 0, "migrated flow helpers should not keep local void-callback callers")
		_expect(source.find("func _get_callback(") < 0, "migrated flow helpers should not keep local callback lookup")
	_expect(apply_source.find("RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_APPLY_CHOICE_FEEDBACK_RESULT)") >= 0, "apply flow should use shared callback lookup for feedback callbacks")
	_expect(apply_source.find("RuntimePerkCallbackMap.call_bool(") >= 0 and apply_source.find("CALLBACK_APPLY_UNLOCK_CHOICE") >= 0, "apply flow should use shared bool callback helper")
	_expect(finish_source.find("RuntimePerkCallbackMap.call_string(callbacks, CALLBACK_GET_CHARACTER_TYPE") >= 0, "finish flow should use shared string callback helper")
	_expect(finish_source.find("RuntimePerkCallbackMap.call_object(callbacks, CALLBACK_GET_CATALOG") >= 0, "finish flow should use shared object callback helper")
	_expect(confirm_source.find("RuntimePerkCallbackMap.call_array(callbacks, CALLBACK_GET_CARD_RECTS") >= 0, "confirm flow should use shared array callback helper")
	_expect(confirm_source.find("RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_PLAY_PERK_SELECT_AUDIO") >= 0, "confirm flow should use shared optional callback helper")
	_expect(open_source.find("RuntimePerkCallbackMap.call_dict(") >= 0 and open_source.find("CALLBACK_APPLY_CHOICE_OPENING_UPDATE") >= 0, "choice open flow should use shared dict callback helper")
	_expect(open_source.find("RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_GET_INSTANCE)") >= 0, "choice open flow should use shared callback lookup for get-instance callbacks")
	_expect(update_source.find("RuntimePerkCallbackMap.call_bool(callbacks, CALLBACK_IS_CHOICE_FLIGHT_ACTIVE") >= 0, "update flow should use shared bool callback helper")
	_expect(update_source.find("RuntimePerkCallbackMap.call_dict(") >= 0 and update_source.find("CALLBACK_APPLY_CHOICE_OPENING_UPDATE") >= 0, "update flow should use shared dict callback helper")
	_expect(starpoint_collection_source.find("RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_GET_INSTANCE)") >= 0, "starpoint collection flow should use shared callback lookup for get-instance callbacks")
	_expect(starpoint_collection_source.find("RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_OPEN_NEXT_CHOICE") >= 0, "starpoint collection flow should use shared optional callback helper")
	_expect(dynamic_effects_source.find("RuntimePerkCallbackMap.call_optional(callbacks, CALLBACK_SYNC_RUNTIME_PERK_OWNER_EFFECTS") >= 0, "dynamic effects should use shared optional callback helper")
	_expect(showcase_flow_source.find("RuntimePerkCallbackMap.call_optional(") >= 0 and showcase_flow_source.find("CALLBACK_FINISH_SUCCESSFUL_CHOICE") >= 0, "unlock showcase flow should use shared optional callback helper")
	_expect(showcase_flow_source.find("RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_IS_UNLOCK_SHOWCASE_ACTIVE)") >= 0, "unlock showcase flow should use shared callback lookup for active query")
	_expect(modal_input_source.find("RuntimePerkCallbackMap.call_bool(callbacks, CALLBACK_IS_CHOICE_ACTIVE") >= 0, "modal input should use shared bool callback helper")
	_expect(modal_input_source.find("RuntimePerkCallbackMap.call_int(") >= 0 and modal_input_source.find("CALLBACK_GET_CARD_INDEX_AT") >= 0, "modal input should use shared int callback helper")
	_expect(modal_input_source.find("RuntimePerkCallbackMap.call_void(") >= 0 and modal_input_source.find("CALLBACK_CHOOSE_SELECTED") >= 0, "modal input should use shared void callback helper")
	_expect(unlock_swap_source.find("RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_GET_INSTANCE)") >= 0, "unlock swap flow should use shared callback lookup for get-instance callbacks")
	_expect(unlock_swap_source.find("RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_FINISH_OR_OPEN_UNLOCK_SHOWCASE)") >= 0, "unlock swap flow should use shared callback lookup for showcase finish callbacks")
	_expect(unlock_apply_source.find("RuntimePerkCallbackMap.call_object(") >= 0 and unlock_apply_source.find("CALLBACK_GET_INSTANCE") >= 0, "unlock choice apply should use shared object callback helper")
	_expect(unlock_apply_source.find("RuntimePerkCallbackMap.call_optional(") >= 0 and unlock_apply_source.find("CALLBACK_SYNC_RUNTIME_PERK_OWNER_EFFECTS") >= 0, "unlock choice apply should use shared optional callback helper")
	_expect(unlock_apply_source.find("RuntimePerkCallbackMap.call_acceptance(") >= 0 and unlock_apply_source.find("CALLBACK_APPLY_CHOICE_FEEDBACK_RESULT") >= 0, "unlock choice apply should use shared acceptance callback helper")
	_expect(debug_grants_source.find("RuntimePerkCallbackMap.call_strict_acceptance(") >= 0 and debug_grants_source.find("CALLBACK_APPLY_CHOICE_FEEDBACK_RESULT") >= 0, "debug grants should use shared strict acceptance callback helper")
	_expect(debug_grants_source.find("RuntimePerkCallbackMap.call_optional(") >= 0 and debug_grants_source.find("CALLBACK_APPLY_LEVEL_SIDE_EFFECT") >= 0, "debug grants should use shared optional callback helper")
	_expect(debug_grants_source.find("RuntimePerkCallbackMap.get_callable(callbacks, CALLBACK_SYNC_OWNER)") >= 0, "debug grants should use shared callback lookup for owner sync")
	_expect(action_runner_source.find("RuntimePerkCallbackMap.call_strict_acceptance(") >= 0 and action_runner_source.find("CALLBACK_CONVERT_TO_GOLD") >= 0, "choice action runner should use shared strict acceptance callback helper")
	_expect(action_runner_source.find("RuntimePerkCallbackMap.call_dict(") >= 0 and action_runner_source.find("CALLBACK_FULL_GAUGE") >= 0, "choice action runner should use shared dict callback helper for feedback actions")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeCallbackReceiver:
	extends RefCounted

	var payload_object := RefCounted.new()
	var void_calls := 0

	func plain() -> String:
		return "done"

	func dict_without_accepted(value: String) -> Dictionary:
		return {"value": value}

	func dict_with_accepted() -> Dictionary:
		return {"accepted": false, "value": "blocked"}

	func truthy() -> int:
		return 1

	func intish() -> int:
		return 3

	func void_call() -> void:
		void_calls += 1

	func stringish() -> int:
		return 12

	func array_value() -> Array:
		return ["a", "b"]

	func object_value() -> Object:
		return payload_object
