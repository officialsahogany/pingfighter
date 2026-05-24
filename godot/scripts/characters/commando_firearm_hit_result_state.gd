extends RefCounted


static func build_base_result(source: String, damage_units: int) -> Dictionary:
	return {
		"source": source,
		"damage_units": damage_units,
	}


static func get_result_frames(profile: Dictionary, result: Dictionary, frame_key: String) -> float:
	var frames: float = float(profile.get(frame_key, 0.0))
	if result.has(frame_key):
		frames = float(result.get(frame_key, frames))
	return frames


static func get_stun_frames(profile: Dictionary, result: Dictionary) -> float:
	return get_result_frames(profile, result, "stun_frames")


static func get_slow_frames(profile: Dictionary, result: Dictionary) -> float:
	return get_result_frames(profile, result, "slow_frames")


static func get_stun_source(result: Dictionary, default_source: String) -> String:
	return str(result.get("stun_source", default_source))


static func get_slow_source(result: Dictionary, default_source: String) -> String:
	return str(result.get("slow_source", "%s_slow" % default_source))


static func get_slow_multiplier(profile: Dictionary, result: Dictionary) -> float:
	return clamp(float(result.get("slow_multiplier", profile.get("slow_multiplier", 1.0))), 0.0, 1.0)


static func apply_stun_result_fields(
	result: Dictionary,
	stun_frames: float,
	knockback_vel: float,
	knockback_profile: Dictionary
) -> void:
	result["stun_frames"] = stun_frames
	result["knockback_vel"] = knockback_vel
	if knockback_profile.has("knockback_frames"):
		result["knockback_frames"] = float(knockback_profile.get("knockback_frames", 0.0))
	if knockback_profile.has("knockback_decay_per_frame"):
		result["knockback_decay_per_frame"] = float(knockback_profile.get("knockback_decay_per_frame", 1.0))


static func apply_slow_result_fields(result: Dictionary, slow_frames: float, slow_multiplier: float) -> void:
	result["slow_frames"] = slow_frames
	result["slow_multiplier"] = slow_multiplier


static func build_stun_status_data(knockback_vel: float, source: String, result: Dictionary) -> Dictionary:
	var status_data := {
		"knockback_vel": knockback_vel,
		"knockback_active": abs(knockback_vel) > 0.001,
		"source": source,
	}
	if result.has("knockback_frames"):
		status_data["knockback_frames"] = float(result.get("knockback_frames", 0.0))
	if result.has("knockback_decay_per_frame"):
		status_data["knockback_decay_per_frame"] = float(result.get("knockback_decay_per_frame", 1.0))
	return status_data


static func build_slow_status_data(slow_multiplier: float, source: String) -> Dictionary:
	return {
		"multiplier": slow_multiplier,
		"source": source,
	}
