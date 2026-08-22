extends SceneTree

const VictoryHighlightFrameCaptureState := preload("res://scripts/core/victory_highlight_frame_capture_state.gd")

const EXPECTED_FAILURE_THRESHOLD := 3
const FAILURE_METHODS := {
	"async_capture_error": "force_async_capture_error_for_tests",
	"byte_size_mismatch": "force_byte_size_mismatch_for_tests",
	"crop_sync_failure": "force_crop_sync_failure_for_tests",
}

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for reason in FAILURE_METHODS:
		_test_single_failure_recovers(str(reason))
		_test_consecutive_failures_discard(str(reason))
	if _failures.is_empty():
		print("victory_highlight_frame_failure_recovery_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		printerr("victory_highlight_frame_failure_recovery_smoke: %s" % failure)
	quit(1)


func _test_single_failure_recovers(reason: String) -> void:
	var capture := VictoryHighlightFrameCaptureState.new()
	var frame := _make_frame()
	_seed_healthy_capture(capture, frame, 100)
	if not _force_failure(capture, reason):
		capture.reset()
		return
	var failed_once: Dictionary = capture.get_debug_snapshot()
	_expect(
		capture.is_available()
		and not bool(failed_once.get("failed", true))
		and int(failed_once.get("consecutive_capture_failure_count", -1)) == 1,
		"%s: one failure must keep the frame lane available with consecutive=1" % reason
	)
	_expect(
		int(failed_once.get("ring_count", -1)) == 1
		and int(failed_once.get("frame_clip_count", -1)) == 1
		and int(failed_once.get("owned_rid_count", -1)) == 1,
		"%s: one failure must preserve the healthy ring, promoted clips, and owned viewport" % reason
	)
	_expect(
		str(failed_once.get("last_capture_failure_reason", "")) == reason
		and str(failed_once.get("fallback_reason", "")).is_empty()
		and str(failed_once.get("last_failure_log", "")).contains("reason=%s" % reason),
		"%s: recovery diagnostics must expose the exact reason without claiming fallback" % reason
	)
	if not capture.has_method("force_capture_success_for_tests"):
		_expect(false, "%s: capture state must expose a successful-frame recovery seam" % reason)
		capture.reset()
		return
	capture.call("force_capture_success_for_tests", frame, 1.0)
	var recovered: Dictionary = capture.get_debug_snapshot()
	_expect(
		capture.is_available()
		and int(recovered.get("consecutive_capture_failure_count", -1)) == 0,
		"%s: the next valid frame must reset the consecutive failure counter" % reason
	)
	_force_failure(capture, reason)
	var failed_after_success: Dictionary = capture.get_debug_snapshot()
	_expect(
		capture.is_available()
		and int(failed_after_success.get("consecutive_capture_failure_count", -1)) == 1,
		"%s: a post-recovery failure must restart at one instead of accumulating across success" % reason
	)
	capture.reset()


func _test_consecutive_failures_discard(reason: String) -> void:
	var capture := VictoryHighlightFrameCaptureState.new()
	var frame := _make_frame()
	_seed_healthy_capture(capture, frame, 200)
	for attempt in range(1, EXPECTED_FAILURE_THRESHOLD + 1):
		if not _force_failure(capture, reason):
			capture.reset()
			return
		var snapshot: Dictionary = capture.get_debug_snapshot()
		if attempt < EXPECTED_FAILURE_THRESHOLD:
			_expect(
				capture.is_available()
				and int(snapshot.get("consecutive_capture_failure_count", -1)) == attempt,
				"%s: attempt %d must recover below the threshold" % [reason, attempt]
			)
		else:
			_expect(
				bool(snapshot.get("failed", false))
				and not capture.is_available()
				and int(snapshot.get("failure_threshold", -1)) == EXPECTED_FAILURE_THRESHOLD,
				"%s: the third consecutive failure must close the frame lane" % reason
			)
			_expect(
				int(snapshot.get("ring_count", -1)) == 0
				and int(snapshot.get("frame_clip_count", -1)) == 0
				and int(snapshot.get("owned_rid_count", -1)) == 0,
				"%s: threshold fallback must discard all frame resources and clips" % reason
			)
			_expect(
				str(snapshot.get("fallback_reason", "")) == reason
				and str(snapshot.get("last_failure_log", "")).contains("action=fallback")
				and str(snapshot.get("last_failure_log", "")).contains("reason=%s" % reason),
				"%s: threshold fallback log must retain its exact actionable reason" % reason
			)
	capture.reset()


func _seed_healthy_capture(capture: Object, frame: PackedByteArray, clip_id: int) -> void:
	capture.install_owned_viewport_for_tests(root)
	capture.store_frame_for_tests(frame, 0.0)
	var clip_frames: Array[PackedByteArray] = []
	clip_frames.append(frame)
	capture.install_frame_clip_for_tests(clip_id, clip_frames)


func _force_failure(capture: Object, reason: String) -> bool:
	var method_name := str(FAILURE_METHODS.get(reason, ""))
	if method_name.is_empty() or not capture.has_method(method_name):
		_expect(false, "%s: missing force-injection seam %s" % [reason, method_name])
		return false
	capture.call(method_name)
	return true


func _make_frame() -> PackedByteArray:
	var frame := PackedByteArray()
	frame.resize(VictoryHighlightFrameCaptureState.CAPTURE_BYTE_COUNT)
	return frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
