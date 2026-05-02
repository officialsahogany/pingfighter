extends RefCounted


func build(context: Dictionary, deps: Dictionary) -> Dictionary:
	var dash_context: Dictionary = _get_dict(context.get("dash_snapshot", {}))
	var power_state = deps.get("power_state", null)
	return {
		"dash_active": dash_context.get("active", false),
		"dash_is_half": dash_context.get("is_half", false),
		"drive_text_timer_frames": float(context.get("drive_text_timer_frames", 0.0)),
		"drive_text_duration_frames": float(context.get("drive_text_duration_frames", 0.0)),
		"power_smashing_text_timer_frames": power_state.get_text_timer_frames() if power_state != null else 0.0,
		"power_smash_text_duration_frames": float(context.get("power_smash_text_duration_frames", 0.0)),
	}


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
