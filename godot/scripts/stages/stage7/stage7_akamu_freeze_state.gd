extends RefCounted

# Stage 7's gameplay-wide freeze clock.
#
# Awakening and Superspeed decide when to begin/cancel a freeze. This owner
# keeps the timer/reason pair atomic and emits the completed reason exactly once
# so the facade can run reason-specific completion side effects.

var remaining_sec := 0.0
var reason := ""


func reset_full() -> void:
	clear_round_transients()


func clear_round_transients() -> void:
	remaining_sec = 0.0
	reason = ""


func begin(new_reason: String, duration_sec: float) -> void:
	remaining_sec = maxf(0.0, duration_sec)
	reason = new_reason if remaining_sec > 0.0 else ""


func advance(delta: float) -> String:
	if not is_active():
		return ""
	var completed_reason := reason
	remaining_sec = maxf(0.0, remaining_sec - delta)
	if is_active():
		return ""
	reason = ""
	return completed_reason


func cancel_if_reason(expected_reason: String) -> bool:
	if not is_active() or reason != expected_reason:
		return false
	clear_round_transients()
	return true


func is_active() -> bool:
	return remaining_sec > 0.0


func has_runtime_state() -> bool:
	return is_active() or reason != ""


func get_snapshot() -> Dictionary:
	return {
		"active": is_active(),
		"remaining_sec": remaining_sec,
		"reason": reason,
	}
