extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")


func get_snapshot() -> Dictionary:
	var left_pressed: bool = Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A) or GamepadInput.is_left_pressed()
	var right_pressed: bool = Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D) or GamepadInput.is_right_pressed()
	var up_pressed: bool = Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W) or GamepadInput.is_up_pressed()
	var down_pressed: bool = Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S) or GamepadInput.is_down_pressed()
	var jetpack_pressed: bool = Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or GamepadInput.is_primary_action_pressed()
	var action_pressed: bool = (
		Input.is_action_pressed("ui_accept")
		or Input.is_key_pressed(KEY_SPACE)
		or Input.is_key_pressed(KEY_X)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or GamepadInput.is_primary_action_pressed()
	)
	var direction := 0.0
	if left_pressed:
		direction -= 1.0
	if right_pressed:
		direction += 1.0

	return {
		"left_pressed": left_pressed,
		"right_pressed": right_pressed,
		"up_pressed": up_pressed,
		"down_pressed": down_pressed,
		"action_pressed": action_pressed,
		"jetpack_pressed": jetpack_pressed,
		"direction": direction,
		"power_smash_direction": _get_exclusive_horizontal_direction(left_pressed, right_pressed),
	}


func _get_exclusive_horizontal_direction(left_pressed: bool, right_pressed: bool) -> int:
	if left_pressed and not right_pressed:
		return -1
	if right_pressed and not left_pressed:
		return 1
	return 0
