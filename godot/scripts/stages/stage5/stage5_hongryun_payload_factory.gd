extends RefCounted


static func build_fireball_projectile(position: Vector2, velocity: Vector2, radius: float) -> Dictionary:
	return {
		"pos": position,
		"vel": velocity,
		"radius": radius,
		"age": 0.0,
	}


static func build_fireball_impact_event(position: Vector2, reason: String, scale: float) -> Dictionary:
	return {
		"pos": position,
		"reason": reason,
		"scale": scale,
	}
