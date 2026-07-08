extends SceneTree

const RuntimePerkGamepadNavigation := preload("res://scripts/characters/runtime_perk_gamepad_navigation.gd")

var _failures: Array[String] = []


class FakeRuntimeState:
	var gamepad_choice_horizontal_latch := 0
	var gamepad_unlock_swap_horizontal_latch := 0


func _init() -> void:
	_verify_left_axis_latch_contract()
	_verify_non_left_axis_passthrough()
	_verify_latch_state_application()
	_verify_runtime_state_navigation_facades()
	_verify_state_delegates_latch_application()

	if _failures.is_empty():
		print("runtime_perk_gamepad_navigation_helper_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_left_axis_latch_contract() -> void:
	var helper := RuntimePerkGamepadNavigation.new()
	var result: Dictionary = helper.consume_horizontal_latch(_axis(JOY_AXIS_LEFT_X, 0.86), 1, 0)
	_expect(int(result.get("direction", 0)) == 1, "first firm left-axis input should emit its direction")
	_expect(int(result.get("latch", 0)) == 1, "first firm left-axis input should latch its direction")

	result = helper.consume_horizontal_latch(_axis(JOY_AXIS_LEFT_X, 0.88), 1, 1)
	_expect(int(result.get("direction", 0)) == 0, "held left-axis input should not repeat")
	_expect(int(result.get("latch", 0)) == 1, "held left-axis input should keep its latch")

	result = helper.consume_horizontal_latch(_axis(JOY_AXIS_LEFT_X, 0.65), 0, 1)
	_expect(int(result.get("direction", -1)) == 0, "sub-threshold non-neutral left-axis input should not emit")
	_expect(int(result.get("latch", 0)) == 1, "sub-threshold non-neutral left-axis input should keep its latch")

	result = helper.consume_horizontal_latch(_axis(JOY_AXIS_LEFT_X, 0.0), 0, 1)
	_expect(int(result.get("direction", -1)) == 0, "neutral left-axis input should not emit")
	_expect(int(result.get("latch", -1)) == 0, "neutral left-axis input should release the latch")


func _verify_non_left_axis_passthrough() -> void:
	var helper := RuntimePerkGamepadNavigation.new()
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_DPAD_RIGHT
	button.pressed = true
	var result: Dictionary = helper.consume_horizontal_latch(button, 1, -1)
	_expect(int(result.get("direction", 0)) == 1, "non-motion gamepad input should pass through direction")
	_expect(int(result.get("latch", 0)) == -1, "non-motion gamepad input should not mutate latch")

	result = helper.consume_horizontal_latch(_axis(JOY_AXIS_RIGHT_X, 0.95), 1, -1)
	_expect(int(result.get("direction", 0)) == 1, "non-left-axis motion should pass through direction")
	_expect(int(result.get("latch", 0)) == -1, "non-left-axis motion should not mutate latch")


func _verify_latch_state_application() -> void:
	var helper := RuntimePerkGamepadNavigation.new()
	var state := FakeRuntimeState.new()
	var result: Dictionary = helper.consume_horizontal_latch(_axis(JOY_AXIS_LEFT_X, 0.86), 1, 0)
	var apply_result: Dictionary = helper.apply_choice_latch_update(state, result, state.gamepad_choice_horizontal_latch)
	_expect(bool(apply_result.get("accepted", false)), "choice latch state update should be accepted")
	_expect(int(apply_result.get("direction", 0)) == 1, "choice latch state update should preserve direction")
	_expect(state.gamepad_choice_horizontal_latch == 1, "choice latch state update should write the choice latch")

	result = helper.consume_horizontal_latch(_axis(JOY_AXIS_LEFT_X, 0.0), 0, state.gamepad_choice_horizontal_latch)
	apply_result = helper.apply_choice_latch_update(state, result, state.gamepad_choice_horizontal_latch)
	_expect(int(apply_result.get("latch", -1)) == 0, "choice latch state update should report release")
	_expect(state.gamepad_choice_horizontal_latch == 0, "choice latch state update should release the choice latch")

	result = helper.consume_horizontal_latch(_axis(JOY_AXIS_LEFT_X, -0.86), -1, 0)
	apply_result = helper.apply_unlock_swap_latch_update(state, result, state.gamepad_unlock_swap_horizontal_latch)
	_expect(bool(apply_result.get("accepted", false)), "unlock-swap latch state update should be accepted")
	_expect(int(apply_result.get("direction", 0)) == -1, "unlock-swap latch state update should preserve direction")
	_expect(state.gamepad_unlock_swap_horizontal_latch == -1, "unlock-swap latch state update should write the swap latch")

	apply_result = helper.apply_choice_latch_update(null, result, 7)
	_expect(not bool(apply_result.get("accepted", true)), "latch state update should reject null runtime state")
	_expect(int(apply_result.get("latch", 0)) == 7, "null latch state update should preserve fallback latch")


func _verify_runtime_state_navigation_facades() -> void:
	var helper := RuntimePerkGamepadNavigation.new()
	var state := FakeRuntimeState.new()

	var choice_result: Dictionary = helper.consume_choice_navigation_from_runtime_state(
		state,
		_axis(JOY_AXIS_LEFT_X, 0.86),
		1
	)
	_expect(bool(choice_result.get("accepted", false)), "choice runtime-state navigation facade should accept live state")
	_expect(int(choice_result.get("direction", 0)) == 1, "choice runtime-state navigation facade should preserve emitted direction")
	_expect(state.gamepad_choice_horizontal_latch == 1, "choice runtime-state navigation facade should write choice latch")

	choice_result = helper.consume_choice_navigation_from_runtime_state(
		state,
		_axis(JOY_AXIS_LEFT_X, 0.88),
		1
	)
	_expect(int(choice_result.get("direction", -1)) == 0, "choice runtime-state navigation facade should suppress held direction")
	_expect(state.gamepad_choice_horizontal_latch == 1, "choice runtime-state navigation facade should keep held latch")

	choice_result = helper.consume_choice_navigation_from_runtime_state(
		state,
		_axis(JOY_AXIS_LEFT_X, 0.0),
		0
	)
	_expect(int(choice_result.get("latch", -1)) == 0, "choice runtime-state navigation facade should release neutral latch")
	_expect(state.gamepad_choice_horizontal_latch == 0, "choice runtime-state navigation facade should clear choice latch")

	var swap_result: Dictionary = helper.consume_unlock_swap_navigation_from_runtime_state(
		state,
		_axis(JOY_AXIS_LEFT_X, -0.86),
		-1
	)
	_expect(bool(swap_result.get("accepted", false)), "unlock-swap runtime-state navigation facade should accept live state")
	_expect(int(swap_result.get("direction", 0)) == -1, "unlock-swap runtime-state navigation facade should preserve emitted direction")
	_expect(state.gamepad_unlock_swap_horizontal_latch == -1, "unlock-swap runtime-state navigation facade should write swap latch")

	var null_result: Dictionary = helper.consume_choice_navigation_from_runtime_state(null, _axis(JOY_AXIS_LEFT_X, 0.86), 1)
	_expect(not bool(null_result.get("accepted", true)), "runtime-state navigation facade should reject null state")


func _verify_state_delegates_latch_application() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var choice_body := _function_body(state_source, "func _consume_gamepad_choice_navigation(")
	var swap_body := _function_body(state_source, "func _consume_gamepad_unlock_swap_navigation(")
	_expect(choice_body.find("_gamepad_navigation.consume_choice_navigation_from_runtime_state") >= 0, "state should delegate choice navigation to runtime-state facade")
	_expect(swap_body.find("_gamepad_navigation.consume_unlock_swap_navigation_from_runtime_state") >= 0, "state should delegate unlock-swap navigation to runtime-state facade")
	_expect(choice_body.find("consume_horizontal_latch") < 0, "state choice wrapper should not consume horizontal latch directly")
	_expect(swap_body.find("consume_horizontal_latch") < 0, "state unlock-swap wrapper should not consume horizontal latch directly")
	_expect(choice_body.find("apply_choice_latch_update") < 0, "state choice wrapper should not apply latch updates directly")
	_expect(swap_body.find("apply_unlock_swap_latch_update") < 0, "state unlock-swap wrapper should not apply latch updates directly")
	_expect(choice_body.find("gamepad_choice_horizontal_latch") < 0, "state choice wrapper should not pass choice latch directly")
	_expect(swap_body.find("gamepad_unlock_swap_horizontal_latch") < 0, "state unlock-swap wrapper should not pass swap latch directly")
	_expect(state_source.find("gamepad_choice_horizontal_latch = int(result.get") < 0, "state should not assign choice latch inline")
	_expect(state_source.find("gamepad_unlock_swap_horizontal_latch = int(result.get") < 0, "state should not assign unlock-swap latch inline")


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)
