extends RefCounted

const OnlineMatchProtocol := preload("res://scripts/network/online_match_protocol.gd")

var _dash_was_pressed := false
var _serve_was_pressed := false
var _same_frame_snapshot: Dictionary = {}
var _same_frame_snapshot_key := -1


func reset() -> void:
	_dash_was_pressed = false
	_serve_was_pressed = false
	_same_frame_snapshot.clear()
	_same_frame_snapshot_key = -1


func collect(tick: int) -> Dictionary:
	var frame_key := int(Engine.get_physics_frames())
	if frame_key == _same_frame_snapshot_key:
		return _same_frame_snapshot.duplicate(true)
	var move_dir := int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
	var dash_pressed := Input.is_action_pressed("ui_down")
	var serve_pressed := (
		Input.is_action_pressed("ui_accept")
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	)
	var frame := OnlineMatchProtocol.sanitize_input_frame({
		"tick": tick,
		"move_dir": move_dir,
		"dash_edge": dash_pressed and not _dash_was_pressed,
		"serve_edge": serve_pressed and not _serve_was_pressed,
		# Reserved by protocol. The Han Miryang mirror MVP keeps every one off.
		"skill_edge": false,
		"item_edge": false,
		"guardian_edge": false,
	})
	_dash_was_pressed = dash_pressed
	_serve_was_pressed = serve_pressed
	_same_frame_snapshot = frame
	_same_frame_snapshot_key = frame_key
	return _same_frame_snapshot.duplicate(true)
