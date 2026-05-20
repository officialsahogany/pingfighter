extends RefCounted

const LIFE_ELIXIR_PARTICLE_COUNT := 22
const LIFE_ELIXIR_PARTICLE_COLORS := [
	Color(1.0, 70.0 / 255.0, 90.0 / 255.0, 1.0),
	Color(1.0, 150.0 / 255.0, 40.0 / 255.0, 1.0),
	Color(1.0, 235.0 / 255.0, 70.0 / 255.0, 1.0),
	Color(70.0 / 255.0, 220.0 / 255.0, 90.0 / 255.0, 1.0),
	Color(70.0 / 255.0, 170.0 / 255.0, 1.0, 1.0),
	Color(80.0 / 255.0, 90.0 / 255.0, 1.0, 1.0),
	Color(180.0 / 255.0, 80.0 / 255.0, 1.0, 1.0),
]


func spawn_particles(particles: Array[Dictionary], center: Vector2) -> void:
	for i in range(LIFE_ELIXIR_PARTICLE_COUNT):
		var angle: float = TAU * float(i) / float(LIFE_ELIXIR_PARTICLE_COUNT) + randf_range(-0.18, 0.18)
		var speed: float = randf_range(120.0, 270.0)
		particles.append({
			"position": center + Vector2(randf_range(-18.0, 18.0), randf_range(-14.0, 14.0)),
			"velocity": Vector2(cos(angle), sin(angle)) * speed + Vector2(0.0, -55.0),
			"radius": randf_range(2.4, 5.6),
			"age": 0.0,
			"lifetime": randf_range(0.42, 0.82),
			"color": LIFE_ELIXIR_PARTICLE_COLORS[i % LIFE_ELIXIR_PARTICLE_COLORS.size()],
		})
