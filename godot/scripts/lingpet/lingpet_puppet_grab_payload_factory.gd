extends RefCounted


static func build_heart(center: Vector2, life_seconds: float) -> Dictionary:
	return {
		"pos": center + Vector2(randf_range(-22.0, 22.0), randf_range(-6.0, 14.0)),
		"drift": randf_range(-18.0, 18.0),
		"life": life_seconds,
		"size": randf_range(5.0, 9.0),
	}


static func build_sparkle(center: Vector2, life_seconds: float) -> Dictionary:
	return {
		"pos": center + Vector2(randf_range(-30.0, 30.0), randf_range(-20.0, 20.0)),
		"life": life_seconds,
		"size": randf_range(2.0, 5.0),
	}
