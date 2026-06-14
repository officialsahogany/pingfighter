extends RefCounted

const DEFAULT_STARPOINT_DROP_SIZE := 12.0
const DEFAULT_STARPOINT_DROP_LIFETIME := 600.0
const DEFAULT_STARPOINT_PARTICLE_LIFE := 60.0


static func build_drop(
	pos: Vector2,
	random: Variant = null,
	star_detector_bonus: bool = false,
	drop_size: float = DEFAULT_STARPOINT_DROP_SIZE,
	drop_lifetime: float = DEFAULT_STARPOINT_DROP_LIFETIME,
	rotation_speed_min: float = 0.05,
	rotation_speed_max: float = 0.1,
	source_type: String = ""
) -> Dictionary:
	var direction: float = -1.0 if _randf(random) < 0.5 else 1.0
	var drop := {
		"pos": pos,
		"vel": Vector2(_randf_range(random, 1.5, 3.0) * direction, _randf_range(random, -4.0, -2.5)),
		"size": drop_size * (0.94 if star_detector_bonus else 1.0),
		"rotation": _randf_range(random, 0.0, TAU),
		"rotation_speed": _randf_range(random, rotation_speed_min, rotation_speed_max),
		"glow_intensity": 1.0,
		"glow_timer": 0.0,
		"life": drop_lifetime,
		"float_timer": _randf_range(random, 0.0, TAU),
		"star_detector_bonus": star_detector_bonus,
	}
	if source_type != "":
		drop["source_type"] = source_type
	return drop


static func build_particles(
	pos: Vector2,
	count: int,
	intensity: float,
	random: Variant = null,
	particle_life: float = DEFAULT_STARPOINT_PARTICLE_LIFE
) -> Array:
	var particles: Array = []
	for _i in range(max(0, count)):
		particles.append({
			"pos": pos + Vector2(_randf_range(random, -10.0, 10.0), _randf_range(random, -10.0, 10.0)),
			"vel": Vector2(_randf_range(random, -2.0, 2.0) * intensity, _randf_range(random, -4.0, -1.0) * intensity),
			"size": _randf_range(random, 1.4, 3.3) * min(1.6, intensity),
			"alpha": 1.0,
			"fade_speed": _randf_range(random, 0.035, 0.070),
			"life": particle_life,
			"color_shift": _randf_range(random, 0.3, 1.0),
		})
	return particles


static func _randf(random: Variant) -> float:
	if random is RandomNumberGenerator:
		return random.randf()
	return randf()


static func _randf_range(random: Variant, from_value: float, to_value: float) -> float:
	if random is RandomNumberGenerator:
		return random.randf_range(from_value, to_value)
	return randf_range(from_value, to_value)
