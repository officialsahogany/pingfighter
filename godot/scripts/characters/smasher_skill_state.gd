extends RefCounted

var cooldowns: Dictionary = {}
var was_active: Dictionary = {}
var activation_msec: Dictionary = {}
var cooldown_pause_started_msec := -1


func reset() -> void:
	cooldowns.clear()
	was_active.clear()
	activation_msec.clear()
	cooldown_pause_started_msec = -1


func reset_cooldowns() -> void:
	cooldowns.clear()
	cooldown_pause_started_msec = -1


func trigger_cooldown(skill_name: String, time_now: int, cooldown_seconds: float) -> void:
	cooldowns[skill_name] = {
		"start_msec": time_now,
		"cooldown_msec": int(max(0.0, cooldown_seconds) * 1000.0),
	}


func trigger_configured_cooldown(skill_name: String, time_now: int, skill_config: Object) -> void:
	trigger_cooldown(skill_name, time_now, _get_config_cooldown(skill_name, skill_config))


func pause_cooldowns(time_now: int) -> void:
	if cooldown_pause_started_msec >= 0:
		return
	cooldown_pause_started_msec = max(0, time_now)


func resume_cooldowns(time_now: int) -> void:
	if cooldown_pause_started_msec < 0:
		return
	var pause_duration_msec: int = max(0, time_now - cooldown_pause_started_msec)
	if pause_duration_msec > 0:
		for skill_name in cooldowns.keys():
			var data: Variant = cooldowns[skill_name]
			if data is Dictionary:
				var next_data: Dictionary = (data as Dictionary).duplicate(true)
				next_data["start_msec"] = int(next_data.get("start_msec", next_data.get("start", -1))) + pause_duration_msec
				cooldowns[skill_name] = next_data
			else:
				cooldowns[skill_name] = int(data) + pause_duration_msec
	cooldown_pause_started_msec = -1


func get_cooldown_remaining(skill_name: String, time_now: int, fallback_cooldown_seconds: float) -> float:
	if not cooldowns.has(skill_name):
		return 0.0

	var data = cooldowns[skill_name]
	var start_msec: int = -1
	var cooldown_msec: int = 0
	var allow_negative_start := false
	if data is Dictionary:
		start_msec = int(data.get("start_msec", data.get("start", -1)))
		cooldown_msec = int(data.get("cooldown_msec", data.get("cooldown_ms", 0)))
		allow_negative_start = bool(data.get("allow_negative_start_msec", false))
	else:
		start_msec = int(data)

	if cooldown_msec <= 0:
		cooldown_msec = int(max(0.0, fallback_cooldown_seconds) * 1000.0)
	if (start_msec < 0 and not allow_negative_start) or cooldown_msec <= 0:
		return 0.0

	var effective_time_now: int = cooldown_pause_started_msec if cooldown_pause_started_msec >= 0 else time_now
	var elapsed: int = max(0, effective_time_now - start_msec)
	if elapsed >= cooldown_msec:
		return 0.0
	return 1.0 - float(elapsed) / float(cooldown_msec)


func get_configured_cooldown_remaining(skill_name: String, time_now: int, skill_config: Object) -> float:
	return get_cooldown_remaining(skill_name, time_now, _get_config_cooldown(skill_name, skill_config))


# 현재 걸려 있는 쿨타임의 전체 길이(초). 가변 쿨타임 스킬(플라즈마)의 HUD가 남은 초를
# ratio * 실제 총쿨타임으로 정확히 표시할 수 있게 한다. 쿨타임이 없으면 0.
func get_cooldown_total_seconds(skill_name: String) -> float:
	var data: Variant = cooldowns.get(skill_name, null)
	if data is Dictionary:
		var cooldown_msec: int = int((data as Dictionary).get("cooldown_msec", (data as Dictionary).get("cooldown_ms", 0)))
		return float(max(0, cooldown_msec)) / 1000.0
	return 0.0


func reduce_all_cooldowns_by_fraction(reduction_fraction: float, time_now: int = -1) -> int:
	var fraction: float = clamp(float(reduction_fraction), 0.0, 0.95)
	if fraction <= 0.0 or cooldowns.is_empty():
		return 0
	var effective_time_now: int = cooldown_pause_started_msec if cooldown_pause_started_msec >= 0 else time_now
	if effective_time_now < 0:
		effective_time_now = Time.get_ticks_msec()
	var changed := 0
	for skill_name in cooldowns.keys():
		var data: Variant = cooldowns.get(skill_name)
		if not (data is Dictionary):
			continue
		var cooldown_data: Dictionary = (data as Dictionary).duplicate(true)
		var start_msec: int = int(cooldown_data.get("start_msec", cooldown_data.get("start", -1)))
		var cooldown_msec: int = int(cooldown_data.get("cooldown_msec", cooldown_data.get("cooldown_ms", 0)))
		if start_msec < 0 or cooldown_msec <= 0:
			continue
		var reduce_msec: int = int(round(float(cooldown_msec) * fraction))
		if reduce_msec <= 0:
			continue
		var next_start_msec: int = start_msec - reduce_msec
		if effective_time_now - next_start_msec >= cooldown_msec:
			cooldowns.erase(skill_name)
		else:
			cooldown_data["start_msec"] = next_start_msec
			if next_start_msec < 0:
				cooldown_data["allow_negative_start_msec"] = true
			else:
				cooldown_data.erase("allow_negative_start_msec")
			cooldowns[skill_name] = cooldown_data
		changed += 1
	return changed


# Dynamic recovery-speed bonuses (for example the Campfire aura) advance the
# cooldown clock itself. This differs from an item cooldown multiplier: skills
# already cooling recover faster only while the player remains inside the aura.
func advance_cooldowns_by_msec(bonus_msec: int, time_now: int = -1) -> int:
	var safe_bonus: int = max(0, bonus_msec)
	if safe_bonus <= 0 or cooldowns.is_empty() or cooldown_pause_started_msec >= 0:
		return 0
	var effective_time_now: int = time_now
	if effective_time_now < 0:
		effective_time_now = Time.get_ticks_msec()
	var changed := 0
	for skill_name in cooldowns.keys():
		var data: Variant = cooldowns.get(skill_name)
		if not (data is Dictionary):
			continue
		var cooldown_data: Dictionary = (data as Dictionary).duplicate(true)
		var start_msec: int = int(cooldown_data.get("start_msec", cooldown_data.get("start", -1)))
		var cooldown_msec: int = int(cooldown_data.get("cooldown_msec", cooldown_data.get("cooldown_ms", 0)))
		var allow_negative_start: bool = bool(cooldown_data.get("allow_negative_start_msec", false))
		if (start_msec < 0 and not allow_negative_start) or cooldown_msec <= 0:
			continue
		var next_start_msec: int = start_msec - safe_bonus
		if effective_time_now - next_start_msec >= cooldown_msec:
			cooldowns.erase(skill_name)
		else:
			cooldown_data["start_msec"] = next_start_msec
			if next_start_msec < 0:
				cooldown_data["allow_negative_start_msec"] = true
			else:
				cooldown_data.erase("allow_negative_start_msec")
			cooldowns[skill_name] = cooldown_data
		changed += 1
	return changed


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
