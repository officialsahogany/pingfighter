extends RefCounted

const GamepadInput := preload("res://scripts/core/gamepad_input.gd")

var _last_action_pressed := false
var _last_middle_pressed := false
var _last_up_pressed := false
var _same_frame_snapshot: Dictionary = {}
var _same_frame_snapshot_key := -1


func get_snapshot() -> Dictionary:
	# Same-frame idempotence guard, mirrored from smasher_input_reader.gd: a
	# second consumer sampling this reader inside one physics frame must not
	# consume the just-pressed/just-released edges before the player controller.
	var frame_key: int = _get_snapshot_frame_key()
	if frame_key == _same_frame_snapshot_key:
		return _same_frame_snapshot.duplicate(true)
	var left_pressed: bool = Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A) or GamepadInput.is_left_pressed()
	var right_pressed: bool = Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D) or GamepadInput.is_right_pressed()
	var down_pressed: bool = Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S) or GamepadInput.is_down_pressed()
	var up_pressed: bool = Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W) or GamepadInput.is_up_pressed()
	var up_just_pressed: bool = up_pressed and not _last_up_pressed
	_last_up_pressed = up_pressed
	var action_pressed: bool = (
		Input.is_action_pressed("ui_accept")
		or Input.is_key_pressed(KEY_SPACE)
		or Input.is_key_pressed(KEY_X)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or GamepadInput.is_primary_action_pressed()
	)
	var action_just_pressed: bool = action_pressed and not _last_action_pressed
	var action_just_released: bool = not action_pressed and _last_action_pressed
	_last_action_pressed = action_pressed
	var middle_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or GamepadInput.is_firearm_reset_pressed()
	var middle_just_pressed: bool = middle_pressed and not _last_middle_pressed
	_last_middle_pressed = middle_pressed
	var direction := 0.0
	if left_pressed:
		direction -= 1.0
	if right_pressed:
		direction += 1.0

	_same_frame_snapshot = {
		"left_pressed": left_pressed,
		"right_pressed": right_pressed,
		"down_pressed": down_pressed,
		"up_pressed": up_pressed,
		"up_just_pressed": up_just_pressed,
		"action_pressed": action_pressed,
		"action_just_pressed": action_just_pressed,
		"action_just_released": action_just_released,
		"mouse_middle_pressed": middle_pressed,
		"mouse_middle_just_pressed": middle_just_pressed,
		"firearm_reset_just_pressed": middle_just_pressed,
		"direction": direction,
		"power_smash_direction": _get_exclusive_horizontal_direction(left_pressed, right_pressed),
		"blacksmith_swing_direction": _get_exclusive_horizontal_direction(left_pressed, right_pressed),
	}
	_same_frame_snapshot_key = frame_key
	return _same_frame_snapshot.duplicate(true)


func _get_snapshot_frame_key() -> int:
	return int(Engine.get_physics_frames())


func _get_exclusive_horizontal_direction(left_pressed: bool, right_pressed: bool) -> int:
	if left_pressed and not right_pressed:
		return -1
	if right_pressed and not left_pressed:
		return 1
	return 0
