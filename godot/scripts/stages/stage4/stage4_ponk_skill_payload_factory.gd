extends RefCounted


static func build_meditation_trail(position: Vector2) -> Dictionary:
	return {
		"pos": position,
		"life": 34.0,
		"radius": 11.0,
	}


static func build_meditation_particle(position: Vector2, random: RandomNumberGenerator) -> Dictionary:
	var angle := random.randf_range(0.0, TAU)
	var direction := Vector2(cos(angle), sin(angle))
	return {
		"pos": position + direction * random.randf_range(10.0, 34.0),
		"vel": direction * random.randf_range(0.25, 1.15),
		"life": random.randf_range(20.0, 42.0),
		"size": random.randf_range(1.8, 4.2),
	}


static func build_meditation_circle(center: Vector2, index: int) -> Dictionary:
	var circle_index: int = maxi(0, index)
	return {
		"pos": center,
		"radius": 34.0 + float(circle_index) * 20.0,
		"grow": 1.6 + float(circle_index) * 0.35,
		"life": 54.0 + float(circle_index) * 18.0,
	}
