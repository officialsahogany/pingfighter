extends RefCounted

# Advanced from the ungated idle pump while battle physics is paused by the
# modal gate. The reveal holds after completion until input starts the exit
# action, then auto-closes once the exit action finishes.
const REVEAL_SECONDS := 1.4
const DISMISS_SECONDS := 1.6

var active := false
var elapsed := 0.0
var dismissing := false
var dismiss_elapsed := 0.0


func start() -> void:
	active = true
	elapsed = 0.0
	dismissing = false
	dismiss_elapsed = 0.0


func reset() -> void:
	active = false
	elapsed = 0.0
	dismissing = false
	dismiss_elapsed = 0.0


func advance(delta: float) -> void:
	if not active:
		return
	var safe_delta: float = maxf(0.0, delta)
	if dismissing:
		dismiss_elapsed += safe_delta
		if dismiss_elapsed >= DISMISS_SECONDS:
			reset()
		return
	elapsed += safe_delta


func get_progress() -> float:
	if REVEAL_SECONDS <= 0.0:
		return 1.0
	return clampf(elapsed / REVEAL_SECONDS, 0.0, 1.0)


func is_awaiting_dismiss() -> bool:
	return active and not dismissing and elapsed >= REVEAL_SECONDS


func begin_dismiss() -> bool:
	if not is_awaiting_dismiss():
		return false
	dismissing = true
	dismiss_elapsed = 0.0
	return true


func is_dismissing() -> bool:
	return active and dismissing


func get_dismiss_progress() -> float:
	if DISMISS_SECONDS <= 0.0:
		return 1.0
	return clampf(dismiss_elapsed / DISMISS_SECONDS, 0.0, 1.0)


func dismiss_immediate() -> bool:
	if not active:
		return false
	reset()
	return true
