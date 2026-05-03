extends RefCounted


func get_snapshot() -> Dictionary:
	var left_pressed: bool = Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A)
	var right_pressed: bool = Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D)
	var up_pressed: bool = Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W)
	var down_pressed: bool = Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S)
	var action_pressed: bool = (
		Input.is_action_pressed("ui_accept")
		or Input.is_key_pressed(KEY_SPACE)
		or Input.is_key_pressed(KEY_X)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
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
		"direction": direction,
		"power_smash_direction": _get_exclusive_horizontal_direction(left_pressed, right_pressed),
	}


func _get_exclusive_horizontal_direction(left_pressed: bool, right_pressed: bool) -> int:
	if left_pressed and not right_pressed:
		return -1
	if right_pressed and not left_pressed:
		return 1
	return 0
