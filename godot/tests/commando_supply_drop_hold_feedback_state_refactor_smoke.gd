extends SceneTree

const HOLD_STATE_PATH := "res://scripts/characters/commando_supply_drop_hold_feedback_state.gd"
const HOST_PATH := "res://scripts/characters/commando_supply_drop_state.gd"

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_threshold_progress_and_anchor()
	_verify_audio_gate_and_radio_tail()
	_verify_pending_hold_buffer()
	_verify_snapshot_restore_and_cleanup()

	if _failures.is_empty():
		print("commando_supply_drop_hold_feedback_state_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(HOLD_STATE_PATH), "Commando Supply Drop hold feedback should have a focused state owner")
	if not FileAccess.file_exists(HOLD_STATE_PATH):
		return
	var host_source := FileAccess.get_file_as_string(HOST_PATH)
	var owner_source := FileAccess.get_file_as_string(HOLD_STATE_PATH)
	_expect(
		host_source.find("const CommandoSupplyDropHoldFeedbackState := preload(\"%s\")" % HOLD_STATE_PATH) >= 0,
		"Supply Drop host should preload the focused hold feedback owner"
	)
	_expect(
		host_source.find("var _hold_feedback_state: Object = CommandoSupplyDropHoldFeedbackState.new()") >= 0,
		"Supply Drop host should retain one hold feedback owner instance"
	)
	for marker in [
		"func reset(",
		"func cancel_transient(",
		"func advance(",
		"func accumulate_pending_hold(",
		"func advance_hold(",
		"func cache_gauge_anchor(",
		"func sync_hold_feedback(",
		"func begin_activation(",
		"func build_gauge_status(",
		"func get_snapshot(",
		"func restore(",
	]:
		_expect(owner_source.find(marker) >= 0, "hold feedback owner should implement %s" % marker)
	for moved_marker in [
		"var hold_time",
		"var pending_hold_time",
		"var radio_motion",
		"var radio_timer",
		"var radio_duration",
		"var hold_radio_audio_active",
		"var hold_gauge_player_pos",
		"var hold_gauge_player_size",
		"func _accumulate_pending_hold(",
		"func _cache_hold_gauge_anchor(",
		"func _sync_hold_feedback(",
		"func _is_hold_gauge_visible(",
		"func _get_hold_gauge_progress(",
		"func _get_hold_gauge_rect(",
	]:
		_expect(host_source.find(moved_marker) < 0, "Supply Drop host should not retain hold feedback marker %s" % moved_marker)
	_expect(
		host_source.find("_hold_feedback_state.advance(safe_delta, active)") >= 0,
		"frame update should delegate radio-tail timing to the focused owner"
	)
	_expect(
		host_source.find("_hold_feedback_state.advance_hold(delta)") >= 0,
		"input update should delegate buffered hold accumulation to the focused owner"
	)


func _verify_threshold_progress_and_anchor() -> void:
	var state: Object = _new_state()
	if state == null:
		return
	_expect(not state.advance_hold(0.29), "hold should remain below activation at 0.29 seconds")
	_expect(not bool(state.build_gauge_status(false).get("visible", true)), "gauge should stay hidden before 0.3 seconds")
	_expect(not state.sync_hold_feedback(false), "hidden gauge should not request radio playback")
	state.cache_gauge_anchor({
		"commando_supply_drop_collision_context": {
			"player_pos": Vector2(130.0, 650.0),
			"player_paddle_size": Vector2(155.0, 50.0),
		},
	})
	_expect(not state.advance_hold(0.02), "0.31-second hold should show feedback without activating")
	_expect(state.sync_hold_feedback(false), "first visible hold frame should request one radio playback")
	_expect(not state.sync_hold_feedback(false), "continued visible hold should deduplicate radio playback")
	var status: Dictionary = state.build_gauge_status(false)
	var rect: Rect2 = status.get("rect", Rect2())
	_expect(bool(status.get("visible", false)), "gauge should become visible at the Python threshold")
	_expect(float(status.get("progress", 0.0)) > 0.0, "visible gauge should expose threshold-adjusted progress")
	_expect(is_equal_approx(rect.get_center().x, 207.5), "gauge should remain centered over the cached paddle")
	_expect(is_equal_approx(rect.position.y, 610.0), "gauge should remain 40 pixels above the paddle")


func _verify_audio_gate_and_radio_tail() -> void:
	var state: Object = _new_state()
	if state == null:
		return
	state.advance_hold(0.4)
	_expect(state.sync_hold_feedback(false), "hold feedback should arm the radio playback gate")
	_expect(state.is_radio_audio_active(), "started hold feedback should expose the active radio gate")
	_expect(not state.begin_activation(), "activation should not request a duplicate cue while the hold radio is active")
	_expect(state.is_radio_motion(), "activation should retain the radio-call pose tail")
	state.advance(0.34, true)
	_expect(state.is_radio_motion(), "radio-call pose should remain active before its 0.35-second tail expires")
	state.advance(0.02, true)
	_expect(not state.is_radio_motion(), "radio-call pose should expire after its configured tail")
	_expect(not state.is_radio_audio_active(), "radio-tail expiry should re-arm the one-playback gate")
	state.reset()
	state.advance_hold(1.0)
	_expect(state.begin_activation(), "single-step activation without feedback should request one radio cue")


func _verify_pending_hold_buffer() -> void:
	var state: Object = _new_state()
	if state == null:
		return
	state.accumulate_pending_hold(0.7)
	var blocked_snapshot: Dictionary = state.get_snapshot(false)
	_expect(is_equal_approx(float(blocked_snapshot.get("pending_hold_time", 0.0)), 0.7), "blocked hold should retain its buffered duration")
	_expect(not bool(state.build_gauge_status(false).get("visible", true)), "buffered hold should not expose the gauge before readiness")
	_expect(state.advance_hold(0.3), "buffered 0.7 seconds plus 0.3 seconds should reach activation")
	var ready_snapshot: Dictionary = state.get_snapshot(false)
	_expect(is_zero_approx(float(ready_snapshot.get("pending_hold_time", -1.0))), "consuming buffered hold should clear the pending duration")
	_expect(is_equal_approx(float(ready_snapshot.get("hold_time", 0.0)), 1.0), "consumed buffer should join the live hold duration")


func _verify_snapshot_restore_and_cleanup() -> void:
	var state: Object = _new_state()
	if state == null:
		return
	state.restore({
		"hold_time": 0.45,
		"pending_hold_time": 0.2,
		"radio_motion": true,
		"radio_timer": 0.12,
		"radio_duration": 0.4,
	})
	var restored: Dictionary = state.get_snapshot(false)
	_expect(is_equal_approx(float(restored.get("hold_time", 0.0)), 0.45), "restore should retain normalized live hold time")
	_expect(is_equal_approx(float(restored.get("pending_hold_time", 0.0)), 0.2), "restore should retain normalized buffered hold time")
	_expect(is_equal_approx(float(restored.get("radio_duration", 0.0)), 0.4), "restore should retain the saved radio tail duration")
	_expect(not state.is_radio_audio_active(), "restore should never claim an unverified live audio playback")
	state.cancel_transient()
	var cancelled: Dictionary = state.get_snapshot(false)
	_expect(is_zero_approx(float(cancelled.get("hold_time", -1.0))), "transient cancel should clear live hold time")
	_expect(not bool(cancelled.get("radio_motion", true)), "transient cancel should clear radio motion")
	state.advance_hold(0.4)
	state.sync_hold_feedback(false)
	state.force_stop_audio()
	_expect(not state.is_radio_audio_active(), "forced audio cleanup should clear the playback gate")


func _new_state() -> Object:
	if not FileAccess.file_exists(HOLD_STATE_PATH):
		return null
	var state_script: Script = load(HOLD_STATE_PATH)
	return state_script.new()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
