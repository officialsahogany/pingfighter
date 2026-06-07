extends RefCounted

# Advanced from the ungated idle pump while battle physics is paused by the
# modal gate. The reveal holds after completion until input starts the exit
# action, then auto-closes once the exit action finishes.
const REVEAL_SECONDS := 1.4
const DISMISS_SECONDS := 1.6

# Asset-readiness gate. The reveal locks onto the heavy Live2D acquisition sheet, but
# that sheet streams in across several frames; on the F7 grant and 1-hit egg paths the
# reveal can open before it finishes. Without a gate the reveal would lock SOLID on the
# static 원화 fallback for a few seconds (the visible regression) before popping to the
# animation. Instead we hold the reveal in its data-reconstruction phase until the sheet
# is cached. REVEAL_ASSET_GATE_FRACTION is the max reveal progress allowed while the
# sheet is missing; it MUST stay below the host's lock-solid mapping
# (lingpet_acquire_cutin_overlay_host: RESTORE_SOLID_START maps to progress ~0.59), so
# the gate can never reach the locked-art frame. MAX_HOLD is a failsafe so a sheet that
# never caches cannot hang the reveal forever (it then completes on the static art, the
# old pre-fix behavior, rather than soft-locking the modal).
const REVEAL_ASSET_GATE_FRACTION := 0.55
const REVEAL_ASSET_GATE_MAX_HOLD_SECONDS := 4.0

var active := false
var elapsed := 0.0
var dismissing := false
var dismiss_elapsed := 0.0
var dismiss_seconds := DISMISS_SECONDS
var _asset_gate_hold_elapsed := 0.0


func start() -> void:
	active = true
	elapsed = 0.0
	dismissing = false
	dismiss_elapsed = 0.0
	dismiss_seconds = DISMISS_SECONDS
	_asset_gate_hold_elapsed = 0.0


func reset() -> void:
	active = false
	elapsed = 0.0
	dismissing = false
	dismiss_elapsed = 0.0
	dismiss_seconds = DISMISS_SECONDS
	_asset_gate_hold_elapsed = 0.0


func advance(delta: float, assets_ready: bool = true) -> void:
	if not active:
		return
	var safe_delta: float = maxf(0.0, delta)
	if dismissing:
		dismiss_elapsed += safe_delta
		if dismiss_elapsed >= dismiss_seconds:
			reset()
		return
	elapsed += safe_delta
	# Hold the reveal in reconstruction until the Live2D sheet caches (or the failsafe
	# expires), so the static 원화 never locks solid on screen.
	if not assets_ready and _asset_gate_hold_elapsed < REVEAL_ASSET_GATE_MAX_HOLD_SECONDS:
		var gate_cap: float = REVEAL_SECONDS * REVEAL_ASSET_GATE_FRACTION
		if elapsed > gate_cap:
			_asset_gate_hold_elapsed += safe_delta
			elapsed = gate_cap


func get_progress() -> float:
	if REVEAL_SECONDS <= 0.0:
		return 1.0
	return clampf(elapsed / REVEAL_SECONDS, 0.0, 1.0)


func is_awaiting_dismiss() -> bool:
	return active and not dismissing and elapsed >= REVEAL_SECONDS


func begin_dismiss(duration_seconds: float = DISMISS_SECONDS) -> bool:
	if not is_awaiting_dismiss():
		return false
	dismissing = true
	dismiss_elapsed = 0.0
	dismiss_seconds = maxf(0.1, duration_seconds)
	return true


func is_dismissing() -> bool:
	return active and dismissing


func get_dismiss_progress() -> float:
	if dismiss_seconds <= 0.0:
		return 1.0
	return clampf(dismiss_elapsed / dismiss_seconds, 0.0, 1.0)


func dismiss_immediate() -> bool:
	if not active:
		return false
	reset()
	return true
