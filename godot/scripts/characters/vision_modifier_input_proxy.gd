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
const MOVEMENT_LATCH_EXEMPT_CHANNELS := {
	"left_pressed": true,
	"right_pressed": true,
}

var _input_reader: Object = null
var _snapshot: Dictionary = {}
var _physical_snapshot: Dictionary = {}
var _filtered_snapshot: Dictionary = {}
var _exclusive_active := false
var _blocked_hold_channels: Dictionary = {}
var _suppressed_until_release := {}
var _current_snapshot_filtered := false
var _discard_latch_enabled := true
var _movement_latch_exempt_channels: Dictionary = MOVEMENT_LATCH_EXEMPT_CHANNELS.duplicate()
var _same_frame_rebuild_idempotence_enabled := true
var _suppression_frame_key := -1
var _suppression_frame_owner_id := 0
var _frame_start_suppression: Dictionary = {}
var _frame_post_suppression: Dictionary = {}
var _frame_snapshot_configured := false


func configure(input_reader: Object) -> Object:
	_input_reader = input_reader
	var snapshot: Dictionary = {}
	if _input_reader != null and _input_reader.has_method("get_snapshot"):
		var value: Variant = _input_reader.get_snapshot()
		if value is Dictionary:
			snapshot = (value as Dictionary).duplicate(true)
	return configure_snapshot(input_reader, snapshot, true)


func begin_snapshot_frame(frame_key: int, owner_id: int) -> void:
	if not _same_frame_rebuild_idempotence_enabled:
		return
	if frame_key == _suppression_frame_key and owner_id == _suppression_frame_owner_id:
		return
	_suppression_frame_key = frame_key
	_suppression_frame_owner_id = owner_id
	_frame_start_suppression = _suppressed_until_release.duplicate()
	_frame_post_suppression = _frame_start_suppression.duplicate()
	_frame_snapshot_configured = false


func configure_snapshot(
	input_reader: Object,
	snapshot: Dictionary,
	exclusive_active: bool,
	blocked_hold_channels: Dictionary = {},
	physical_snapshot: Dictionary = {}
) -> Object:
	var replaying_same_frame := (
		_same_frame_rebuild_idempotence_enabled
		and _suppression_frame_key >= 0
		and _frame_snapshot_configured
	)
	if replaying_same_frame:
		# A mythic raw-reader request may build before player control enriches the
		# cached snapshot with Stage 3 status movement. Rebuild from the same
		# frame-start latch set so both views drain identical command channels.
		_suppressed_until_release = _frame_start_suppression.duplicate()
	_input_reader = input_reader
	_snapshot = snapshot.duplicate(true)
	_physical_snapshot = (
		physical_snapshot.duplicate(true)
		if not physical_snapshot.is_empty()
		else _snapshot.duplicate(true)
	)
	_exclusive_active = exclusive_active
	_blocked_hold_channels = blocked_hold_channels.duplicate()
	# Legacy direct callers predate per-skill policy. Preserve their explicit
	# exclusive=true contract by defaulting to the complete channel set.
	if _exclusive_active and _blocked_hold_channels.is_empty():
		for channel: String in HOLD_CHANNELS:
			_blocked_hold_channels[channel] = true
	_filtered_snapshot = _build_filtered_snapshot()
	if _same_frame_rebuild_idempotence_enabled and _suppression_frame_key >= 0:
		if not _frame_snapshot_configured:
			_frame_post_suppression = _suppressed_until_release.duplicate()
			_frame_snapshot_configured = true
		elif replaying_same_frame:
			# Only the first configure mutates cross-frame latch state. Later
			# same-frame status rebuilds replay its drain set for their output, then
			# restore the first configure's authoritative next-frame state.
			_suppressed_until_release = _frame_post_suppression.duplicate()
	return self


func get_snapshot() -> Dictionary:
	return _filtered_snapshot.duplicate(true)


func _build_filtered_snapshot() -> Dictionary:
	var filtered := _snapshot.duplicate(true)
	var drained_channels := {}
	_current_snapshot_filtered = false
	var movement_left_pressed := bool(_snapshot.get("left_pressed", false))
	var movement_right_pressed := bool(_snapshot.get("right_pressed", false))
	var movement_direction := float(
		_snapshot.get("direction", _horizontal_direction(_snapshot))
	)
	var horizontal_movement_blocked := (
		_exclusive_active
		and (
			bool(_blocked_hold_channels.get("left_pressed", false))
			or bool(_blocked_hold_channels.get("right_pressed", false))
		)
	)
	if horizontal_movement_blocked:
		movement_left_pressed = false
		movement_right_pressed = false
		movement_direction = 0.0
	# GRT-050: the real reader is still sampled while Vision owns combat input.
	# Held channels are discarded, never deferred; after Shift release they stay
	# suppressed until their physical release, including synthesized release
	# edges such as Commando's hold/action channels.
	for channel: String in HOLD_CHANNELS:
		var raw_pressed := bool(_physical_snapshot.get(channel, false))
		var blocked_while_exclusive := (
			_exclusive_active
			and bool(_blocked_hold_channels.get(channel, false))
		)
		if (
			_discard_latch_enabled
			and blocked_while_exclusive
			and raw_pressed
			and not bool(_movement_latch_exempt_channels.get(channel, false))
		):
			_suppressed_until_release[channel] = true
		var must_suppress := (
			blocked_while_exclusive
			or (
				_discard_latch_enabled
				and bool(_suppressed_until_release.get(channel, false))
			)
		)
		if not must_suppress:
			continue
		_current_snapshot_filtered = true
		drained_channels[channel] = true
		filtered[channel] = false
		# configure_snapshot() is owned by the actor driver's one canonical
		# frame sample. Only that raw sample may prove a physical release and
		# clear the cross-frame discard latch.
		if not raw_pressed:
			_suppressed_until_release.erase(channel)
	for edge_channel: String in EDGE_CHANNEL_OWNERS:
		var owner_channel := str(EDGE_CHANNEL_OWNERS[edge_channel])
		if bool(drained_channels.get(owner_channel, false)):
			filtered[edge_channel] = false
	# F4(b): ordinary horizontal fields are command lanes. Vision-exclusive
	# frames expose player translation only through the dedicated movement lane,
	# making every existing/future non-movement consumer blocked by default.
	if _exclusive_active:
		filtered["left_pressed"] = false
		filtered["right_pressed"] = false
		filtered["direction"] = 0.0
		_current_snapshot_filtered = true
	else:
		filtered["direction"] = (
			0.0
			if _is_horizontal_suppressed(drained_channels)
			else float(_snapshot.get("direction", _horizontal_direction(filtered)))
		)
	filtered["movement_left_pressed"] = movement_left_pressed
	filtered["movement_right_pressed"] = movement_right_pressed
	filtered["movement_direction"] = movement_direction
	filtered["power_smash_direction"] = 0 if _exclusive_active else _exclusive_horizontal_direction(filtered)
	filtered["blacksmith_swing_direction"] = 0 if _exclusive_active else _exclusive_horizontal_direction(filtered)
	filtered["vision_input_exclusive"] = _exclusive_active
	return filtered


func has_pending_release_suppression() -> bool:
	return not _suppressed_until_release.is_empty()


func should_filter_current_snapshot() -> bool:
	return _current_snapshot_filtered


func suppress_primary_pointer_until_release() -> void:
	# The configured frame snapshot is intentionally immutable. Forwarding the
	# request updates the raw Viper reader for the next frame; it does not rebuild
	# this proxy mid-frame. No live production consumer performs a second read
	# that depends on same-frame recomputation.
	if _input_reader != null and _input_reader.has_method("suppress_primary_pointer_until_release"):
		_input_reader.suppress_primary_pointer_until_release()


func set_discard_latch_enabled_for_test(enabled: bool) -> void:
	_discard_latch_enabled = enabled
	if not enabled:
		_suppressed_until_release.clear()


func set_movement_latch_exempt_channels_for_test(channels: Array) -> void:
	_movement_latch_exempt_channels.clear()
	for channel_value: Variant in channels:
		_movement_latch_exempt_channels[str(channel_value)] = true


func set_same_frame_rebuild_idempotence_enabled_for_test(enabled: bool) -> void:
	_same_frame_rebuild_idempotence_enabled = enabled
	invalidate_snapshot_frame_for_test()


func invalidate_snapshot_frame_for_test() -> void:
	_suppression_frame_key = -1
	_suppression_frame_owner_id = 0
	_frame_start_suppression.clear()
	_frame_post_suppression.clear()
	_frame_snapshot_configured = false


func reset() -> void:
	_snapshot.clear()
	_physical_snapshot.clear()
	_filtered_snapshot.clear()
	_blocked_hold_channels.clear()
	_suppressed_until_release.clear()
	_exclusive_active = false
	_current_snapshot_filtered = false
	invalidate_snapshot_frame_for_test()


func _is_horizontal_suppressed(drained_channels: Dictionary) -> bool:
	return (
		bool(drained_channels.get("left_pressed", false))
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
