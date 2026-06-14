extends RefCounted


static func build_spiral_burst(
	existing_burst_count: int,
	time_sec: float,
	life_sec: float,
	inferno_active: bool
) -> Dictionary:
	return {
		"age": 0.0,
		"life": life_sec,
		"intensity": 1.6 if inferno_active else 1.0,
		"phase": float(existing_burst_count) * 0.73 + time_sec,
	}


static func build_fire_impact(position: Vector2, life_sec: float, scale: float = 1.0) -> Dictionary:
	return {
		"pos": position,
		"age": 0.0,
		"life": life_sec,
		"scale": scale,
	}
