extends SceneTree

const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_choice_navigation_latch()
	_verify_unlock_swap_navigation_latch()

	if _failures.is_empty():
		print("runtime_perk_gamepad_navigation_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_choice_navigation_latch() -> void:
	var state: Object = RuntimePerkState.new()
	state.choice_active = true
	state.current_choices = [
		{"id": "perk_a"},
		{"id": "perk_b"},
		{"id": "perk_c"},
	]
	state.selected_index = 0

	state.handle_input(_axis(JOY_AXIS_LEFT_X, 0.65), null, null, Vector2(1920.0, 1080.0))
	_expect(int(state.selected_index) == 0, "small left-stick tilt should not move runtime perk selection")

	state.handle_input(_axis(JOY_AXIS_LEFT_X, 0.86), null, null, Vector2(1920.0, 1080.0))
	_expect(int(state.selected_index) == 1, "firm left-stick tilt should move runtime perk selection once")

	state.handle_input(_axis(JOY_AXIS_LEFT_X, 0.88), null, null, Vector2(1920.0, 1080.0))
	_expect(int(state.selected_index) == 1, "held left-stick tilt should not repeat runtime perk selection")

	state.handle_input(_axis(JOY_AXIS_LEFT_X, 0.0), null, null, Vector2(1920.0, 1080.0))
	state.handle_input(_axis(JOY_AXIS_LEFT_X, 0.86), null, null, Vector2(1920.0, 1080.0))
	_expect(int(state.selected_index) == 2, "runtime perk selection should move again after left stick returns to neutral")


func _verify_unlock_swap_navigation_latch() -> void:
	var state: Object = RuntimePerkState.new()
	state.pending_unlock_swap = {
		"candidates": [
			{"skill_id": "slot_a"},
			{"skill_id": "slot_b"},
			{"skill_id": "slot_c"},
		],
	}
	state.unlock_swap_selected_index = 0

	state.handle_input(_axis(JOY_AXIS_LEFT_X, -0.65), null, null, Vector2(1920.0, 1080.0))
	_expect(int(state.unlock_swap_selected_index) == 0, "small left-stick tilt should not move unlock-swap selection")

	state.handle_input(_axis(JOY_AXIS_LEFT_X, -0.86), null, null, Vector2(1920.0, 1080.0))
	_expect(int(state.unlock_swap_selected_index) == 2, "firm left-stick tilt should move unlock-swap selection once")

	state.handle_input(_axis(JOY_AXIS_LEFT_X, -0.88), null, null, Vector2(1920.0, 1080.0))
	_expect(int(state.unlock_swap_selected_index) == 2, "held left-stick tilt should not repeat unlock-swap selection")


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
