extends RefCounted

# Lightweight, non-freezing partial-screen cut-in state for Smasher skills that
# use the Drive-style left-wall triangle panel while gameplay keeps running.

const DEFAULT_DURATION := 1.35

var _active: bool = false
var _elapsed: float = 0.0
var _duration: float = DEFAULT_DURATION
var _skill_name: String = ""


func begin(skill_name: String, duration: float = DEFAULT_DURATION) -> void:
	_active = true
	_elapsed = 0.0
	_duration = max(0.1, duration)
	_skill_name = skill_name.strip_edges()


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
	_skill_name = ""


func is_active() -> bool:
	return _active


func get_skill_name() -> String:
	return _skill_name


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
