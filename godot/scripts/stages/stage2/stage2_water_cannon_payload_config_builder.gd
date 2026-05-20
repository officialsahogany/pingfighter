extends RefCounted


func build_config(
	rock_fragment_min_count: int,
	rock_fragment_max_count: int,
	water_splash_min_count: int,
	water_splash_max_count: int,
	rock_fragment_life_sec: float,
	water_splash_life_sec: float,
	rock_fragment_gravity: float,
	water_splash_gravity: float
) -> Dictionary:
	return {
		"rock_fragment_min_count": rock_fragment_min_count,
		"rock_fragment_max_count": rock_fragment_max_count,
		"water_splash_min_count": water_splash_min_count,
		"water_splash_max_count": water_splash_max_count,
		"rock_fragment_life_sec": rock_fragment_life_sec,
		"water_splash_life_sec": water_splash_life_sec,
		"rock_fragment_gravity": rock_fragment_gravity,
		"water_splash_gravity": water_splash_gravity,
	}
