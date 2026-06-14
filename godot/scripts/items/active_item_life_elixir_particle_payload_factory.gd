extends RefCounted

const LIFE_ELIXIR_PARTICLE_COLORS := [
	Color(1.0, 70.0 / 255.0, 90.0 / 255.0, 1.0),
	Color(1.0, 150.0 / 255.0, 40.0 / 255.0, 1.0),
	Color(1.0, 235.0 / 255.0, 70.0 / 255.0, 1.0),
	Color(70.0 / 255.0, 220.0 / 255.0, 90.0 / 255.0, 1.0),
	Color(70.0 / 255.0, 170.0 / 255.0, 1.0, 1.0),
	Color(80.0 / 255.0, 90.0 / 255.0, 1.0, 1.0),
	Color(180.0 / 255.0, 80.0 / 255.0, 1.0, 1.0),
]


static func build_particle(center: Vector2, index: int, particle_count: int) -> Dictionary:
	var safe_count := maxi(1, particle_count)
	var angle: float = TAU * float(index) / float(safe_count) + randf_range(-0.18, 0.18)
	var speed: float = randf_range(120.0, 270.0)
	return {
		"position": center + Vector2(randf_range(-18.0, 18.0), randf_range(-14.0, 14.0)),
		"velocity": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, -55.0),
		"radius": randf_range(2.4, 5.6),
		"age": 0.0,
		"lifetime": randf_range(0.42, 0.82),
		"color": LIFE_ELIXIR_PARTICLE_COLORS[index % LIFE_ELIXIR_PARTICLE_COLORS.size()],
	}
