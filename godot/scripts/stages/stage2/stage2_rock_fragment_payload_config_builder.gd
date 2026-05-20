extends RefCounted


func build_config(fragment_life_sec: float) -> Dictionary:
	return {
		"fragment_life_sec": fragment_life_sec,
	}
