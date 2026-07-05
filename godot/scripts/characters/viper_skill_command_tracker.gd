extends RefCounted


func update_before_movement(runtime: Object, input_snapshot: Dictionary, command_skill_config: Object, deps: Dictionary, now_msec: int, constants: Dictionary) -> Dictionary:
	runtime.input_sequence_frame += 1
	var down_pressed: bool = bool(input_snapshot.get("down_pressed", false))
	var pressed_edge: bool = down_pressed and not runtime.previous_down_pressed
	var up_pressed: bool = bool(input_snapshot.get("up_pressed", false))
	var up_edge: bool = up_pressed and not runtime.previous_up_pressed
	var left_pressed: bool = bool(input_snapshot.get("left_pressed", false))
	var right_pressed: bool = bool(input_snapshot.get("right_pressed", false))
	var left_edge: bool = left_pressed and not runtime.previous_left_pressed
	var right_edge: bool = right_pressed and not runtime.previous_right_pressed
	runtime.previous_down_pressed = down_pressed
	_update_dual_glitch_command(runtime, command_skill_config, deps, now_msec, left_edge, right_edge, up_edge, constants)
	_update_core_flip_input_edges(runtime, left_edge, right_edge)
	_update_chaos_command(runtime, command_skill_config, now_msec, left_edge, right_edge, up_edge, constants)
	runtime.previous_left_pressed = left_pressed
	runtime.previous_up_pressed = up_pressed
	runtime.previous_right_pressed = right_pressed
	return {
		"down_pressed": down_pressed,
		"pressed_edge": pressed_edge,
		"up_pressed": up_pressed,
		"up_edge": up_edge,
		"left_pressed": left_pressed,
		"right_pressed": right_pressed,
		"left_edge": left_edge,
		"right_edge": right_edge,
	}


func _update_dual_glitch_command(runtime: Object, command_skill_config: Object, deps: Dictionary, now_msec: int, left_edge: bool, right_edge: bool, up_edge: bool, constants: Dictionary) -> void:
	var dual_glitch_name: String = str(constants.get("dual_glitch", "dual_glitch"))
	var dual_window_msec: int = int(constants.get("dual_glitch_window_msec", 1200))
	var dual_max_key_gap_msec: int = int(constants.get("dual_glitch_max_key_gap_msec", 260))
	if up_edge:
		runtime.dual_glitch_cmd_buffer.clear()
	if not (runtime.dual_glitch_state == "idle" and runtime.visibility_query.is_skill_equipped(command_skill_config, dual_glitch_name) and runtime.visibility_query.is_configured_skill_ready(dual_glitch_name, deps, -1) and not runtime._is_core_flip_ready_window_active(now_msec)):
		runtime.dual_glitch_cmd_buffer.clear()
		return
	_expire_dual_glitch_buffer(runtime, now_msec, dual_window_msec)
	var dual_glitch_key_sequence: Array[String] = []
	if left_edge and not right_edge:
		dual_glitch_key_sequence.append("a")
	elif right_edge and not left_edge:
		dual_glitch_key_sequence.append("d")
	for dual_glitch_key_char: String in dual_glitch_key_sequence:
		_expire_dual_glitch_buffer(runtime, now_msec, dual_window_msec)
		var dual_glitch_progress: int = runtime.dual_glitch_cmd_buffer.size()
		var dual_glitch_entry: Dictionary = {"key": dual_glitch_key_char, "time": now_msec}
		if dual_glitch_progress > 0:
			var dual_glitch_last_command: Dictionary = runtime.dual_glitch_cmd_buffer[dual_glitch_progress - 1]
			if now_msec - int(dual_glitch_last_command.get("time", 0)) > dual_max_key_gap_msec:
				runtime.dual_glitch_cmd_buffer = [dual_glitch_entry] if dual_glitch_key_char == "a" else []
				continue
		if dual_glitch_key_char == ("a" if dual_glitch_progress == 0 or dual_glitch_progress == 2 or dual_glitch_progress >= 4 else "d"):
			if dual_glitch_progress == 0:
				runtime.dual_glitch_cmd_buffer = [dual_glitch_entry]
			else:
				runtime.dual_glitch_cmd_buffer.append(dual_glitch_entry)
		elif dual_glitch_key_char == "a":
			runtime.dual_glitch_cmd_buffer = [dual_glitch_entry]
		else:
			runtime.dual_glitch_cmd_buffer = []


func _expire_dual_glitch_buffer(runtime: Object, now_msec: int, dual_window_msec: int) -> void:
	if runtime.dual_glitch_cmd_buffer.is_empty():
		return
	var dual_glitch_first_command: Dictionary = runtime.dual_glitch_cmd_buffer[0]
	if now_msec - int(dual_glitch_first_command.get("time", 0)) > dual_window_msec:
		runtime.dual_glitch_cmd_buffer.clear()


func consume_dual_glitch_command_ready(runtime: Object, now_msec: int, dual_window_msec: int) -> bool:
	_expire_dual_glitch_buffer(runtime, now_msec, dual_window_msec)
	var command_ready := false
	if runtime.dual_glitch_cmd_buffer.size() >= 4:
		var first_entry: Dictionary = runtime.dual_glitch_cmd_buffer[0]; var second_entry: Dictionary = runtime.dual_glitch_cmd_buffer[1]; var third_entry: Dictionary = runtime.dual_glitch_cmd_buffer[2]; var fourth_entry: Dictionary = runtime.dual_glitch_cmd_buffer[3]
		command_ready = str(first_entry.get("key", "")) == "a" and str(second_entry.get("key", "")) == "d" and str(third_entry.get("key", "")) == "a" and str(fourth_entry.get("key", "")) == "d"
		if command_ready:
			runtime.dual_glitch_cmd_buffer.clear()
	return command_ready


func _update_core_flip_input_edges(runtime: Object, left_edge: bool, right_edge: bool) -> void:
	if left_edge:
		runtime.core_flip_left_press_frame = runtime.input_sequence_frame
	if right_edge:
		runtime.core_flip_right_press_frame = runtime.input_sequence_frame


func _update_chaos_command(runtime: Object, command_skill_config: Object, now_msec: int, left_edge: bool, right_edge: bool, up_edge: bool, constants: Dictionary) -> void:
	var chaos_spear_name: String = str(constants.get("chaos_spear", "chaos_spear"))
	if not (runtime.chaos_state == "idle" and runtime.visibility_query.is_skill_equipped(command_skill_config, chaos_spear_name)):
		return
	var chaos_cmd_buffer_max: int = int(constants.get("chaos_cmd_buffer_max", 6))
	if left_edge:
		runtime.chaos_cmd_buffer.append({"key": "a", "time": now_msec})
	if up_edge:
		runtime.chaos_cmd_buffer.append({"key": "w", "time": now_msec})
	if right_edge:
		runtime.chaos_cmd_buffer.append({"key": "d", "time": now_msec})
	while runtime.chaos_cmd_buffer.size() > chaos_cmd_buffer_max:
		runtime.chaos_cmd_buffer.pop_front()


func consume_chaos_command_ready(runtime: Object, now_msec: int, chaos_window_msec: int) -> bool:
	if runtime.chaos_cmd_buffer.size() < 3:
		return false
	var first_command: Dictionary = runtime.chaos_cmd_buffer[runtime.chaos_cmd_buffer.size() - 3]; var second_command: Dictionary = runtime.chaos_cmd_buffer[runtime.chaos_cmd_buffer.size() - 2]; var third_command: Dictionary = runtime.chaos_cmd_buffer[runtime.chaos_cmd_buffer.size() - 1]
	if str(first_command.get("key", "")) != "a" or str(second_command.get("key", "")) != "w" or str(third_command.get("key", "")) != "d":
		return false
	var command_ready: bool = int(second_command.get("time", 0)) - int(first_command.get("time", 0)) <= chaos_window_msec and int(third_command.get("time", 0)) - int(second_command.get("time", 0)) <= chaos_window_msec and now_msec - int(third_command.get("time", 0)) <= chaos_window_msec
	if command_ready:
		runtime.chaos_cmd_buffer.clear()
	return command_ready
