extends RefCounted


static func build_particle(position: Vector2, velocity: Vector2, life: float, size: float, kind: int) -> Dictionary:
	return {
		"pos": position,
		"vel": velocity,
		"life": life,
		"max_life": maxf(0.01, life),
		"size": size,
		"kind": kind,
	}


static func build_burst_particle(origin: Vector2) -> Dictionary:
	var angle: float = -PI * 0.5 + (randf() - 0.5) * PI * 1.35
	var speed: float = randf_range(120.0, 310.0)
	var position := origin + Vector2(randf_range(-9.0, 9.0), randf_range(-4.0, 5.0))
	var velocity := Vector2(cos(angle), sin(angle)) * speed
	return build_particle(position, velocity, randf_range(0.28, 0.58), randf_range(2.2, 5.2), 0)


static func build_ambient_particle(orbit_pos: Vector2, orbit_half_width: float, orbit_half_height: float) -> Dictionary:
	var ux: float = randf_range(-0.92, 0.92)
	var uy: float = randf_range(-0.42, 0.42)
	var position := orbit_pos + Vector2(ux * orbit_half_width, uy * orbit_half_height)
	var velocity := Vector2(randf_range(-22.0, 22.0), randf_range(-12.0, 8.0))
	return build_particle(position, velocity, randf_range(0.42, 0.82), randf_range(1.8, 3.8), 1)


static func build_slow_status_data(multiplier: float) -> Dictionary:
	return {
		"multiplier": multiplier,
		"cleansable": true,
		"visual": "draft_bat_moon_orbit",
		"suppress_legacy_boss_ai_slow": true,
	}
