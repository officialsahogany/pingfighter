extends RefCounted


static func build_absorbed_splash_payload(position: Vector2) -> Dictionary:
	return {
		"position": position,
		"strength": 0.75,
		"color": Color(0.42, 0.88, 1.0, 1.0),
	}


static func build_absorbed_rock_payload(position: Vector2, rock_radius: float) -> Dictionary:
	return {
		"position": position,
		"strength": clamp(rock_radius / 28.0, 0.85, 1.65),
		"color": Color(0.48, 0.92, 0.78, 1.0),
	}
