extends RefCounted


static func build_particle(pos: Vector2, vel: Vector2, life: float, radius: float, color: Color) -> Dictionary:
	var safe_life := maxf(0.05, life)
	return {
		"pos": pos,
		"vel": vel,
		"life": safe_life,
		"max_life": safe_life,
		"radius": maxf(0.5, radius),
		"color": color,
	}
