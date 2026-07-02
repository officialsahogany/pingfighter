extends RefCounted

var defense_rate_override := -1.0
var appearance_rate_override := -1.0
var move_speed_override := -1.0


func set_defense_rate_override(value: float) -> void:
	defense_rate_override = -1.0 if value < 0.0 else clampf(value, 0.0, 1.0)


func set_appearance_rate_override(value: float) -> void:
	appearance_rate_override = -1.0 if value < 0.0 else clampf(value, 0.0, 1.0)


func set_move_speed_override(value: float) -> void:
	move_speed_override = -1.0 if value < 0.0 else clampf(value, 0.1, 5.0)


func apply_move_speed_override(base_value: float) -> float:
	if move_speed_override >= 0.0:
		return base_value * move_speed_override
	return base_value


func get_patrol_speed(profile: Object, stat_name: String, fallback: float) -> float:
	var base_value := fallback
	if profile != null and profile.has_method("get_stat"):
		base_value = float(profile.get_stat(stat_name, fallback))
	return apply_move_speed_override(base_value)


func resolve_defense_rate(motion_style: String, base_value: float) -> float:
	if motion_style != "patrol":
		return 0.0
	if defense_rate_override >= 0.0:
		return defense_rate_override
	return base_value


func get_defense_rate(profile: Object, fallback: float) -> float:
	var motion_style := _get_profile_motion_style(profile)
	var base_value := 0.0
	if motion_style == "patrol" and profile != null and profile.has_method("get_defense_rate"):
		base_value = float(profile.get_defense_rate(fallback))
	return resolve_defense_rate(motion_style, base_value)


func resolve_appearance_rate(motion_style: String, base_value: float) -> float:
	if motion_style == "patrol":
		return 0.0
	if appearance_rate_override >= 0.0:
		return appearance_rate_override
	return base_value


func get_appearance_rate(profile: Object, fallback: float = 0.0) -> float:
	var motion_style := _get_profile_motion_style(profile)
	var base_value := 0.0
	if motion_style != "patrol" and profile != null and profile.has_method("get_appearance_rate"):
		base_value = float(profile.get_appearance_rate(fallback))
	return resolve_appearance_rate(motion_style, base_value)


func _get_profile_motion_style(profile: Object) -> String:
	if profile != null and profile.has_method("get_motion_style"):
		return str(profile.get_motion_style())
	return "patrol"
