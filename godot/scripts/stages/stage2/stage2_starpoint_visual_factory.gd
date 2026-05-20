extends RefCounted

const DEFAULT_STARPOINT_DROP_SIZE := 12.0
const DEFAULT_STARPOINT_DROP_LIFETIME := 600.0
const DEFAULT_STARPOINT_PARTICLE_LIFE := 60.0


func build_drop(
	pos: Vector2,
	random: RandomNumberGenerator,
	star_detector_bonus: bool = false,
	drop_size: float = DEFAULT_STARPOINT_DROP_SIZE,
	drop_lifetime: float = DEFAULT_STARPOINT_DROP_LIFETIME
) -> Dictionary:
	var direction: float = -1.0 if random.randf() < 0.5 else 1.0
	return {
		"pos": pos,
		"vel": Vector2(random.randf_range(1.5, 3.0) * direction, random.randf_range(-4.0, -2.5)),
		"size": drop_size * (0.94 if star_detector_bonus else 1.0),
		"rotation": random.randf_range(0.0, TAU),
		"rotation_speed": random.randf_range(0.05, 0.1),
		"glow_intensity": 1.0,
		"glow_timer": 0.0,
		"life": drop_lifetime,
		"float_timer": random.randf_range(0.0, TAU),
		"star_detector_bonus": star_detector_bonus,
	}


func build_particles(
	pos: Vector2,
	count: int,
	intensity: float,
	random: RandomNumberGenerator,
	particle_life: float = DEFAULT_STARPOINT_PARTICLE_LIFE
) -> Array:
	var particles: Array = []
	for _i in range(max(0, count)):
		particles.append({
			"pos": pos + Vector2(random.randf_range(-10.0, 10.0), random.randf_range(-10.0, 10.0)),
			"vel": Vector2(random.randf_range(-2.0, 2.0) * intensity, random.randf_range(-4.0, -1.0) * intensity),
			"size": random.randf_range(1.4, 3.3) * min(1.6, intensity),
			"alpha": 1.0,
			"fade_speed": random.randf_range(0.035, 0.070),
			"life": particle_life,
			"color_shift": random.randf_range(0.3, 1.0),
		})
	return particles
