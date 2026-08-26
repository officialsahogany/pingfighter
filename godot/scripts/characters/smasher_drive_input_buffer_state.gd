extends RefCounted

const DRIVE_INPUT_MAX_FRAME_GAP: int = 4
const DRIVE_INPUT_MAX_AGE_FRAMES: int = 16

var left_press_frame: int = -1
var right_press_frame: int = -1
var action_press_frame: int = -1
var last_left_pressed: bool = false
var last_right_pressed: bool = false
var last_action_pressed: bool = false
var _exclusive_discard_enabled := true


func reset() -> void:
	left_press_frame = -1
	right_press_frame = -1
	action_press_frame = -1
	last_left_pressed = false
	last_right_pressed = false
	last_action_pressed = false


func update_input_frames(
	left_pressed: bool,
	right_pressed: bool,
	action_pressed: bool,
	current_frame: int
) -> void:
	if left_pressed and not last_left_pressed:
		left_press_frame = current_frame
	if right_pressed and not last_right_pressed:
		right_press_frame = current_frame
	if action_pressed and not last_action_pressed:
		action_press_frame = current_frame

	last_left_pressed = left_pressed
	last_right_pressed = right_pressed
	last_action_pressed = action_pressed


func discard_current_inputs(
	left_pressed: bool,
	right_pressed: bool,
	action_pressed: bool
) -> void:
	if not _exclusive_discard_enabled:
		return
	left_press_frame = -1
	right_press_frame = -1
	action_press_frame = -1
	last_left_pressed = left_pressed
	last_right_pressed = right_pressed
	last_action_pressed = action_pressed


func set_exclusive_discard_enabled_for_test(enabled: bool) -> void:
	_exclusive_discard_enabled = enabled


func consume_direction(current_frame: int) -> int:
	_expire_old_frames(current_frame)
	if action_press_frame < 0:
		return 0

	var chosen_dir: int = 0
	var chosen_frame: int = -1
	var chosen_gap: int = DRIVE_INPUT_MAX_FRAME_GAP + 1
	if left_press_frame >= 0:
		var left_gap: int = abs(left_press_frame - action_press_frame)
		if left_gap <= DRIVE_INPUT_MAX_FRAME_GAP:
			chosen_dir = -1
			chosen_frame = max(left_press_frame, action_press_frame)
			chosen_gap = left_gap
	if right_press_frame >= 0:
		var right_gap: int = abs(right_press_frame - action_press_frame)
		var right_frame: int = max(right_press_frame, action_press_frame)
		if (
			right_gap <= DRIVE_INPUT_MAX_FRAME_GAP
			and (right_frame > chosen_frame or (right_frame == chosen_frame and right_gap < chosen_gap))
		):
			chosen_dir = 1
			chosen_frame = right_frame
			chosen_gap = right_gap

	if chosen_dir != 0:
		left_press_frame = -1
		right_press_frame = -1
		action_press_frame = -1
	return chosen_dir


func _expire_old_frames(current_frame: int) -> void:
	if left_press_frame >= 0 and current_frame - left_press_frame > DRIVE_INPUT_MAX_AGE_FRAMES:
		left_press_frame = -1
	if right_press_frame >= 0 and current_frame - right_press_frame > DRIVE_INPUT_MAX_AGE_FRAMES:
		right_press_frame = -1
	if action_press_frame >= 0 and current_frame - action_press_frame > DRIVE_INPUT_MAX_AGE_FRAMES:
		action_press_frame = -1


func get_left_press_frame() -> int:
	return left_press_frame


func get_right_press_frame() -> int:
	return right_press_frame


func get_action_press_frame() -> int:
	return action_press_frame


func get_last_left_pressed() -> bool:
	return last_left_pressed


func get_last_right_pressed() -> bool:
	return last_right_pressed


func get_last_action_pressed() -> bool:
	return last_action_pressed
