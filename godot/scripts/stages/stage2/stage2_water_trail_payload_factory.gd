extends RefCounted

const DEFAULT_TRAIL_LIFE_SEC := 0.38


func build_trail(
	pos: Vector2,
	progress: float,
	random_source: RandomNumberGenerator,
	life_sec: float = DEFAULT_TRAIL_LIFE_SEC
) -> Dictionary:
	return {
		"pos": pos + Vector2(
			random_source.randf_range(-4.0, 4.0),
			random_source.randf_range(-4.0, 4.0)
		),
		"life": life_sec,
		"max_life": life_sec,
		"radius": random_source.randf_range(5.0, 13.0) * (0.70 + progress * 0.60),
		"color": Color(0.42, 0.88, 1.0, 1.0),
	}
