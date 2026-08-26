extends RefCounted

const COMMAND_TIMEOUT_SEC := 2.0
const KEY_LEFT := "left"
const KEY_RIGHT := "right"
const COMMAND_SEQUENCE := [KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT]

var command_buffer: Array[String] = []
var command_timer_sec := 0.0
var _prev_left_pressed := false
var _prev_right_pressed := false


func reset() -> void:
	command_buffer.clear()
	command_timer_sec = 0.0
	_prev_left_pressed = false
	_prev_right_pressed = false


func clear_sequence() -> void:
	command_buffer.clear()
	command_timer_sec = 0.0


func feed_input_snapshot(input_snapshot: Dictionary, delta: float, enabled: bool = true) -> bool:
	if bool(input_snapshot.get("vision_input_exclusive", false)):
		# Vision may pass A/D through as movement for non-Cheongringwi loadouts.
		# Keep those levels out of this command buffer while synchronizing the
		# physical hold state, so Shift release cannot replay a deferred edge.
		return feed_buttons(
			bool(input_snapshot.get("left_pressed", false)),
			bool(input_snapshot.get("right_pressed", false)),
			delta,
			false
		)
	return feed_buttons(
		bool(input_snapshot.get("left_pressed", false)),
		bool(input_snapshot.get("right_pressed", false)),
		delta,
		enabled
	)


func feed_buttons(left_pressed: bool, right_pressed: bool, delta: float, enabled: bool = true) -> bool:
	if not enabled:
		clear_sequence()
		_prev_left_pressed = left_pressed
		_prev_right_pressed = right_pressed
		return false

	if not command_buffer.is_empty():
		command_timer_sec += max(0.0, delta)
		if command_timer_sec > COMMAND_TIMEOUT_SEC:
			clear_sequence()

	var left_edge: bool = left_pressed and not _prev_left_pressed
	var right_edge: bool = right_pressed and not _prev_right_pressed
	var completed := false
	if left_edge and not right_edge:
		completed = _push_edge(KEY_LEFT)
	elif right_edge and not left_edge:
		completed = _push_edge(KEY_RIGHT)
	elif left_edge and right_edge:
		clear_sequence()

	_prev_left_pressed = left_pressed
	_prev_right_pressed = right_pressed
	return completed


func get_context() -> Dictionary:
	return {
		"buffer_size": command_buffer.size(),
		"timer_sec": command_timer_sec,
		"timeout_sec": COMMAND_TIMEOUT_SEC,
	}


func _push_edge(edge_key: String) -> bool:
	var expected_index: int = command_buffer.size()
	if expected_index >= COMMAND_SEQUENCE.size():
		clear_sequence()
		expected_index = 0

	var expected_key: String = str(COMMAND_SEQUENCE[expected_index])
	if edge_key != expected_key:
		clear_sequence()
		if edge_key != str(COMMAND_SEQUENCE[0]):
			return false

	command_buffer.append(edge_key)
	if command_buffer.size() == 1:
		command_timer_sec = 0.0
	if command_buffer.size() >= COMMAND_SEQUENCE.size():
		clear_sequence()
		return true
	return false
