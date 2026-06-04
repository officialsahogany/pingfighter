extends RefCounted

const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")


static func update_clone_slashes(runtime: Object, fps_scale: float, context: Dictionary, deps: Dictionary, constants: Dictionary) -> void:
	if runtime.nerve_strike_clone_slashes.is_empty():
		return
	var updated_slashes: Array = []
	var travel_frames := float(constants.get("travel_frames", 13.2))
	var hit_radius := float(constants.get("hit_radius", 120.0))
	var slash_frames := float(constants.get("slash_frames", 12.0))
	for entry_value in runtime.nerve_strike_clone_slashes:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		match str(entry.get("state", "pending")):
			"pending":
				_update_pending_entry(runtime, entry, fps_scale, context)
			"travel":
				_update_travel_entry(runtime, entry, fps_scale, context, deps, travel_frames, hit_radius, slash_frames)
			"slash":
				entry["timer"] = max(0.0, float(entry.get("timer", 0.0)) - fps_scale)
			_:
				entry["timer"] = 0.0
		if str(entry.get("state", "")) != "slash" or float(entry.get("timer", 0.0)) > 0.0:
			updated_slashes.append(entry)
	runtime.nerve_strike_clone_slashes = updated_slashes


static func _update_pending_entry(runtime: Object, entry: Dictionary, fps_scale: float, context: Dictionary) -> void:
	var delay_frames: float = max(0.0, float(entry.get("delay_frames", 0.0)) - fps_scale)
	entry["delay_frames"] = delay_frames
	if delay_frames <= 0.0:
		entry["state"] = "travel"; entry["timer"] = 0.0; entry["target"] = runtime._get_nerve_strike_boss_center(context)


static func _update_travel_entry(runtime: Object, entry: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary, travel_frames: float, hit_radius: float, slash_frames: float) -> void:
	var origin: Vector2 = _get_vector2(entry.get("origin", Vector2.ZERO), Vector2.ZERO)
	var live_target: Vector2 = runtime._get_nerve_strike_boss_center(context)
	var current_target: Vector2 = _get_vector2(entry.get("target", origin), origin)
	var motion: Dictionary = ViperSkillGeometry.nerve_strike_clone_slash_motion(origin, current_target, live_target, float(entry.get("timer", 0.0)), fps_scale, travel_frames, 0.70, 0.16)
	var progress: float = float(motion.get("progress", 0.0))
	var target: Vector2 = _get_vector2(motion.get("target", current_target), current_target)
	entry["timer"] = float(motion.get("timer", 0.0)); entry["target"] = target; entry["pos"] = _get_vector2(motion.get("pos", origin), origin)
	if progress >= 1.0:
		var pos: Vector2 = _get_vector2(entry.get("pos", target), target)
		if ViperSkillGeometry.nerve_strike_hits_target(pos, live_target, hit_radius) and not bool(entry.get("hit_applied", false)):
			entry["hit_applied"] = true; runtime._apply_nerve_strike_confusion(deps); runtime._spawn_nerve_strike_slash_feedback(pos, deps)
		entry["state"] = "slash"; entry["timer"] = slash_frames


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
