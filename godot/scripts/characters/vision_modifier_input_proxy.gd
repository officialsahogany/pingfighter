extends RefCounted

const HOLD_CHANNELS := [
	"left_pressed",
	"right_pressed",
	"up_pressed",
	"down_pressed",
	"action_pressed",
	"mouse_left_pressed",
	"mouse_middle_pressed",
	"secondary_action_pressed",
	"supply_drop_hold_pressed",
	"commando_supply_drop_hold_pressed",
	"mouse_right_pressed",
	"gamepad_supply_hold_pressed",
	"jetpack_pressed",
]
const EDGE_CHANNEL_OWNERS := {
	"up_just_pressed": "up_pressed",
	"action_just_pressed": "action_pressed",
	"action_just_released": "action_pressed",
	"mouse_left_just_pressed": "mouse_left_pressed",
	"mouse_middle_just_pressed": "mouse_middle_pressed",
	"firearm_reset_just_pressed": "mouse_middle_pressed",
	"secondary_action_just_pressed": "secondary_action_pressed",
}

var _input_reader: Object = null
var _snapshot: Dictionary = {}
var _filtered_snapshot: Dictionary = {}
var _exclusive_active := false
var _suppressed_until_release := {}
var _current_snapshot_filtered := false


func configure(input_reader: Object) -> Object:
	_input_reader = input_reader
	var snapshot: Dictionary = {}
	if _input_reader != null and _input_reader.has_method("get_snapshot"):
		var value: Variant = _input_reader.get_snapshot()
		if value is Dictionary:
			snapshot = (value as Dictionary).duplicate(true)
	return configure_snapshot(input_reader, snapshot, true)


func configure_snapshot(input_reader: Object, snapshot: Dictionary, exclusive_active: bool) -> Object:
	_input_reader = input_reader
	_snapshot = snapshot.duplicate(true)
	_exclusive_active = exclusive_active
	_filtered_snapshot = _build_filtered_snapshot()
	return self


func get_snapshot() -> Dictionary:
	return _filtered_snapshot.duplicate(true)


func _build_filtered_snapshot() -> Dictionary:
	var filtered := _snapshot.duplicate(true)
	var drained_channels := {}
	_current_snapshot_filtered = _exclusive_active
	# GRT-050: the real reader is still sampled while Vision owns combat input.
	# Held channels are discarded, never deferred; after Shift release they stay
	# suppressed until their physical release, including synthesized release
	# edges such as Commando's hold/action channels.
	for channel: String in HOLD_CHANNELS:
		var raw_pressed := bool(_snapshot.get(channel, false))
		if _exclusive_active and raw_pressed:
			_suppressed_until_release[channel] = true
		var must_suppress := _exclusive_active or bool(_suppressed_until_release.get(channel, false))
		if not must_suppress:
			continue
		_current_snapshot_filtered = true
		drained_channels[channel] = true
		filtered[channel] = false
		if not raw_pressed:
			_suppressed_until_release.erase(channel)
	for edge_channel: String in EDGE_CHANNEL_OWNERS:
		var owner_channel := str(EDGE_CHANNEL_OWNERS[edge_channel])
		if _exclusive_active or bool(drained_channels.get(owner_channel, false)):
			filtered[edge_channel] = false
	filtered["direction"] = 0.0 if _is_horizontal_suppressed(drained_channels) else _horizontal_direction(filtered)
	filtered["power_smash_direction"] = _exclusive_horizontal_direction(filtered)
	filtered["blacksmith_swing_direction"] = _exclusive_horizontal_direction(filtered)
	return filtered


func has_pending_release_suppression() -> bool:
	return not _suppressed_until_release.is_empty()


func should_filter_current_snapshot() -> bool:
	return _current_snapshot_filtered


func suppress_primary_pointer_until_release() -> void:
	if _input_reader != null and _input_reader.has_method("suppress_primary_pointer_until_release"):
		_input_reader.suppress_primary_pointer_until_release()


func _is_horizontal_suppressed(drained_channels: Dictionary) -> bool:
	return (
		_exclusive_active
		or bool(drained_channels.get("left_pressed", false))
		or bool(drained_channels.get("right_pressed", false))
	)


func _horizontal_direction(snapshot: Dictionary) -> float:
	var direction := 0.0
	if bool(snapshot.get("left_pressed", false)):
		direction -= 1.0
	if bool(snapshot.get("right_pressed", false)):
		direction += 1.0
	return direction


func _exclusive_horizontal_direction(snapshot: Dictionary) -> int:
	var left_pressed := bool(snapshot.get("left_pressed", false))
	var right_pressed := bool(snapshot.get("right_pressed", false))
	if left_pressed and not right_pressed:
		return -1
	if right_pressed and not left_pressed:
		return 1
	return 0
