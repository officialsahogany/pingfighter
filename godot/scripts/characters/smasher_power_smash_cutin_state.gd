extends RefCounted

const SKILL_POWER_SMASHING := "power_smashing"

var _active: bool = false
var _elapsed: float = 0.0
var _duration: float = 0.0
var _skill_name: String = SKILL_POWER_SMASHING


func begin(freeze_duration: float, skill_name: String = SKILL_POWER_SMASHING) -> void:
	_active = true
	_elapsed = 0.0
	_duration = max(0.1, freeze_duration)
	_skill_name = skill_name if skill_name != "" else SKILL_POWER_SMASHING


func update(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if _elapsed >= _duration:
		_active = false


func reset() -> void:
	_active = false
	_elapsed = 0.0
	_duration = 0.0
	_skill_name = SKILL_POWER_SMASHING


func is_active() -> bool:
	return _active


func get_progress() -> float:
	if _duration <= 0.0:
		return 0.0
	return clampf(_elapsed / _duration, 0.0, 1.0)


func get_phase() -> String:
	var p: float = get_progress()
	if p < 0.11:
		return "wipe"
	if p < 0.73:
		return "main"
	if p < 0.82:
		return "text"
	if p < 1.0:
		return "flash"
	return "done"


func get_elapsed() -> float:
	return _elapsed


func get_duration() -> float:
	return _duration


func get_skill_name() -> String:
	return _skill_name
