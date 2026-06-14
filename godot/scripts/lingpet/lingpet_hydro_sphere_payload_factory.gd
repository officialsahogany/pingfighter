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


static func build_splash_particle(origin: Vector2) -> Dictionary:
	var angle: float = -PI * 0.5 + (randf() - 0.5) * PI * 1.05
	var speed: float = randf_range(150.0, 360.0)
	var position := origin + Vector2(randf_range(-10.0, 10.0), randf_range(-4.0, 4.0))
	var velocity := Vector2(cos(angle), sin(angle)) * speed
	return build_particle(position, velocity, randf_range(0.34, 0.62), randf_range(3.0, 7.0), 0)


static func build_ambient_particle(puddle_pos: Vector2, puddle_half_width: float, puddle_half_height: float) -> Dictionary:
	var ux: float = randf_range(-0.92, 0.92)
	var uy: float = randf_range(-0.55, 0.55)
	var position := puddle_pos + Vector2(ux * puddle_half_width, uy * puddle_half_height)
	var velocity := Vector2(randf_range(-12.0, 12.0), randf_range(-28.0, -10.0))
	return build_particle(position, velocity, randf_range(0.5, 0.95), randf_range(2.0, 4.2), 1)


static func build_slow_status_data(multiplier: float) -> Dictionary:
	return {
		"multiplier": multiplier,
		"cleansable": true,
		"visual": "maribo_hydro_sphere",
	}
