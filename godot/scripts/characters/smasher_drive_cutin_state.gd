extends RefCounted

# Lightweight, NON-FREEZING partial-screen still cut-in for the Smasher's Drive
# skill. Unlike the power-smashing cut-in (smasher_power_smash_cutin_state +
# skill_cutin_overlay_host.draw), this one does NOT pause the game or dim the
# whole screen -- the rally keeps playing while a Mika portrait slides in from
# the left edge for a brief beat. Owned by smasher_power_smash_state so it shares
# that module's per-frame update (update_effects), draw, and reset lifecycle.
# Triggered on drive activation by smasher_drive_activation_feedback_controller.

const DEFAULT_DURATION := 1.35

var _active: bool = false
var _elapsed: float = 0.0
var _duration: float = DEFAULT_DURATION
# Combo-charged drive flag. When true, the cut-in uses the punchier
# "drive_cutin_enraged" writhe-ember preset + brighter particle tint. Driven by
# drive_result.consume_combo at activation (see
# smasher_drive_activation_feedback_controller). Duration stays first-positional
# because tests call begin(<duration>).
var _enraged: bool = false


func begin(duration: float = DEFAULT_DURATION, enraged: bool = false) -> void:
	_active = true
	_elapsed = 0.0
	_duration = max(0.1, duration)
	_enraged = enraged


func update(delta: float) -> void:
	if not _active:
		return
	_elapsed += max(0.0, delta)
	if _elapsed >= _duration:
		_active = false


func reset() -> void:
	_active = false
	_elapsed = 0.0
	_duration = DEFAULT_DURATION
	_enraged = false


func is_active() -> bool:
	return _active


func is_enraged() -> bool:
	return _enraged


func get_progress() -> float:
	if _duration <= 0.0:
		return 0.0
	return clampf(_elapsed / _duration, 0.0, 1.0)


func get_phase() -> String:
	var p: float = get_progress()
	if p < 0.18:
		return "in"
	if p < 0.62:
		return "hold"
	if p < 1.0:
		return "out"
	return "done"


func get_elapsed() -> float:
	return _elapsed


func get_duration() -> float:
	return _duration
