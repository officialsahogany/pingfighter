extends RefCounted


static func build_wall_shake_accent(side: String, y_ratio: float, speed_scale: float, duration: float) -> Dictionary:
	return {
		"side": side,
		"y_ratio": y_ratio,
		"speed_scale": speed_scale,
		"timer": duration,
		"duration": duration,
	}
