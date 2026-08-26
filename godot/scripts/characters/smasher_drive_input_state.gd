extends RefCounted

const SmasherDriveFrameCooldownState := preload("res://scripts/characters/smasher_drive_frame_cooldown_state.gd")
const SmasherDriveInputBufferState := preload("res://scripts/characters/smasher_drive_input_buffer_state.gd")

var buffer_state: Object = SmasherDriveInputBufferState.new()
var cooldown_state: Object = SmasherDriveFrameCooldownState.new()


func reset() -> void:
	buffer_state.reset()


func reset_cooldowns() -> void:
	cooldown_state.reset()


func update_input_frames(
	left_pressed: bool,
	right_pressed: bool,
	action_pressed: bool,
	current_frame: int
) -> void:
	buffer_state.update_input_frames(left_pressed, right_pressed, action_pressed, current_frame)


func discard_current_inputs(left_pressed: bool, right_pressed: bool, action_pressed: bool) -> void:
	buffer_state.discard_current_inputs(left_pressed, right_pressed, action_pressed)


func update_cooldowns(fps_scale: float) -> void:
	cooldown_state.update(fps_scale)


func update_input_and_cooldowns(
	left_pressed: bool,
	right_pressed: bool,
	action_pressed: bool,
	current_frame: int,
	fps_scale: float
) -> void:
	update_input_frames(left_pressed, right_pressed, action_pressed, current_frame)
	update_cooldowns(fps_scale)


func trigger_frame_cooldowns(perfect_frames: float, global_frames: float) -> void:
	cooldown_state.trigger(perfect_frames, global_frames)


func is_frame_cooldown_blocked() -> bool:
	return cooldown_state.is_blocked()


func consume_direction(current_frame: int) -> int:
	return buffer_state.consume_direction(current_frame)


func get_left_press_frame() -> int:
	return buffer_state.get_left_press_frame()


func get_right_press_frame() -> int:
	return buffer_state.get_right_press_frame()


func get_action_press_frame() -> int:
	return buffer_state.get_action_press_frame()


func get_last_left_pressed() -> bool:
	return buffer_state.get_last_left_pressed()


func get_last_right_pressed() -> bool:
	return buffer_state.get_last_right_pressed()


func get_last_action_pressed() -> bool:
	return buffer_state.get_last_action_pressed()


func get_perfect_cooldown_frames() -> float:
	return cooldown_state.get_perfect_cooldown_frames()


func get_global_cooldown_frames() -> float:
	return cooldown_state.get_global_cooldown_frames()
