extends RefCounted

var cooldowns: Dictionary = {}
var was_active: Dictionary = {}
var activation_msec: Dictionary = {}


func reset() -> void:
	cooldowns.clear()
	was_active.clear()
	activation_msec.clear()


func reset_cooldowns() -> void:
	cooldowns.clear()


func trigger_cooldown(skill_name: String, time_now: int, cooldown_seconds: float) -> void:
	cooldowns[skill_name] = {
		"start_msec": time_now,
		"cooldown_msec": int(max(0.0, cooldown_seconds) * 1000.0),
	}


func trigger_configured_cooldown(skill_name: String, time_now: int, skill_config: Object) -> void:
	trigger_cooldown(skill_name, time_now, _get_config_cooldown(skill_name, skill_config))


func get_cooldown_remaining(skill_name: String, time_now: int, fallback_cooldown_seconds: float) -> float:
	if not cooldowns.has(skill_name):
		return 0.0

	var data = cooldowns[skill_name]
	var start_msec: int = -1
	var cooldown_msec: int = 0
	if data is Dictionary:
		start_msec = int(data.get("start_msec", data.get("start", -1)))
		cooldown_msec = int(data.get("cooldown_msec", data.get("cooldown_ms", 0)))
	else:
		start_msec = int(data)

	if cooldown_msec <= 0:
		cooldown_msec = int(max(0.0, fallback_cooldown_seconds) * 1000.0)
	if start_msec < 0 or cooldown_msec <= 0:
		return 0.0

	var elapsed: int = max(0, time_now - start_msec)
	if elapsed >= cooldown_msec:
		return 0.0
	return 1.0 - float(elapsed) / float(cooldown_msec)


func get_configured_cooldown_remaining(skill_name: String, time_now: int, skill_config: Object) -> float:
	return get_cooldown_remaining(skill_name, time_now, _get_config_cooldown(skill_name, skill_config))


func update_activation_state(skill_name: String, is_active: bool, time_now: int) -> int:
	var previously_active: bool = bool(was_active.get(skill_name, false))
	if is_active and not previously_active:
		activation_msec[skill_name] = time_now
	was_active[skill_name] = is_active
	return time_now - int(activation_msec.get(skill_name, -100000))


func get_cooldowns() -> Dictionary:
	return cooldowns


func get_was_active() -> Dictionary:
	return was_active


func get_activation_msec() -> Dictionary:
	return activation_msec


func _get_config_cooldown(skill_name: String, skill_config: Object) -> float:
	if skill_config != null and skill_config.has_method("get_cooldown_seconds"):
		return float(skill_config.get_cooldown_seconds(skill_name))
	return 0.0
