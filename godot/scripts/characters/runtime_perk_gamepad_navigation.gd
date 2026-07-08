extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")


func consume_horizontal_latch(event: InputEvent, direction: int, current_latch: int) -> Dictionary:
	if not (event is InputEventJoypadMotion):
		return _result(direction, current_latch)
	var motion_event: InputEventJoypadMotion = event
	if motion_event.axis != JOY_AXIS_LEFT_X:
		return _result(direction, current_latch)
	if absf(motion_event.axis_value) <= GamepadInput.MENU_AXIS_RELEASE_THRESHOLD:
		return _result(0, 0)
	if direction == 0:
		return _result(0, current_latch)
	if current_latch == direction:
		return _result(0, current_latch)
	return _result(direction, direction)


func apply_choice_latch_update(runtime_state: Object, result: Dictionary, current_latch: int) -> Dictionary:
	return _apply_latch_update(
		runtime_state,
		"gamepad_choice_horizontal_latch",
		result,
		current_latch
	)


func apply_unlock_swap_latch_update(runtime_state: Object, result: Dictionary, current_latch: int) -> Dictionary:
	return _apply_latch_update(
		runtime_state,
		"gamepad_unlock_swap_horizontal_latch",
		result,
		current_latch
	)


func consume_choice_navigation_from_runtime_state(
	runtime_state: Object,
	event: InputEvent,
	direction: int
) -> Dictionary:
	return _consume_navigation_from_runtime_state(
		runtime_state,
		"gamepad_choice_horizontal_latch",
		event,
		direction
	)


func consume_unlock_swap_navigation_from_runtime_state(
	runtime_state: Object,
	event: InputEvent,
	direction: int
) -> Dictionary:
	return _consume_navigation_from_runtime_state(
		runtime_state,
		"gamepad_unlock_swap_horizontal_latch",
		event,
		direction
	)


func _result(direction: int, latch: int) -> Dictionary:
	return {
		"direction": direction,
		"latch": latch,
	}


func _consume_navigation_from_runtime_state(
	runtime_state: Object,
	latch_property: String,
	event: InputEvent,
	direction: int
) -> Dictionary:
	var current_latch: int = _get_runtime_state_int(runtime_state, latch_property)
	var result: Dictionary = consume_horizontal_latch(event, direction, current_latch)
	return _apply_latch_update(runtime_state, latch_property, result, current_latch)


func _get_runtime_state_int(runtime_state: Object, key: String) -> int:
	if runtime_state == null:
		return 0
	return int(runtime_state.get(key))


func _apply_latch_update(
	runtime_state: Object,
	latch_property: String,
	result: Dictionary,
	current_latch: int
) -> Dictionary:
	if runtime_state == null:
		return {
			"accepted": false,
			"direction": int(result.get("direction", 0)),
			"latch": current_latch,
		}
	var next_latch: int = int(result.get("latch", current_latch))
	runtime_state.set(latch_property, next_latch)
	return {
		"accepted": true,
		"direction": int(result.get("direction", 0)),
		"latch": next_latch,
	}
