extends RefCounted


static func update_drop(
	drop: Dictionary,
	fps_scale: float,
	play_left: float,
	play_right: float,
	play_height: float,
	default_size: float,
	max_fall_speed: float,
	acceleration: float,
	bounce_damping: float
) -> bool:
	drop["life"] = float(drop.get("life", 0.0)) - fps_scale
	if float(drop.get("life", 0.0)) <= 0.0:
		return false

	var pos: Vector2 = _get_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO)
	var vel: Vector2 = _get_vector2(drop.get("vel", Vector2.ZERO), Vector2.ZERO)
	var size: float = max(1.0, float(drop.get("size", default_size)))
	var float_timer: float = float(drop.get("float_timer", 0.0)) + 0.05 * fps_scale
	pos.x += (vel.x + sin(float_timer) * 0.1) * fps_scale
	pos.y += vel.y * fps_scale
	vel.y = min(max_fall_speed, vel.y + acceleration * fps_scale)

	if pos.x <= play_left + size:
		pos.x = play_left + size
		vel.x = abs(vel.x) * bounce_damping
	elif pos.x >= play_right - size:
		pos.x = play_right - size
		vel.x = -abs(vel.x) * bounce_damping
	vel.x *= pow(0.98, fps_scale)
	if pos.y > play_height - size:
		return false

	drop["pos"] = pos
	drop["vel"] = vel
	drop["float_timer"] = float_timer
	drop["rotation"] = float(drop.get("rotation", 0.0)) + float(drop.get("rotation_speed", 0.07)) * fps_scale
	var glow_timer: float = float(drop.get("glow_timer", 0.0)) + 0.1 * fps_scale
	drop["glow_timer"] = glow_timer
	drop["glow_intensity"] = 0.7 + 0.3 * abs(sin(glow_timer))
	return true


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
