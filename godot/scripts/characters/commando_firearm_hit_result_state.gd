extends RefCounted


static func build_base_result(source: String, damage_units: int) -> Dictionary:
	return {
		"source": source,
		"damage_units": damage_units,
	}


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
