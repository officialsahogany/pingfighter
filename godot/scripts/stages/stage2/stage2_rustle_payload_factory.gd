extends RefCounted


func build_layout(height: float) -> Dictionary:
	return {
		"bushes": build_bushes(height),
		"vines": build_vines(),
	}


func build_bushes(height: float) -> Array:
	var bush_specs := [
		{"area": "boss", "pos": Vector2(54.0, 42.0), "radius": 34.0, "seed": 11.0},
		{"area": "boss", "pos": Vector2(154.0, 78.0), "radius": 26.0, "seed": 19.0},
		{"area": "boss", "pos": Vector2(274.0, 50.0), "radius": 31.0, "seed": 23.0},
		{"area": "boss", "pos": Vector2(505.0, 46.0), "radius": 37.0, "seed": 31.0},
		{"area": "boss", "pos": Vector2(615.0, 80.0), "radius": 28.0, "seed": 37.0},
		{"area": "player", "pos": Vector2(50.0, height - 36.0), "radius": 31.0, "seed": 43.0},
		{"area": "player", "pos": Vector2(150.0, height - 70.0), "radius": 25.0, "seed": 47.0},
		{"area": "player", "pos": Vector2(285.0, height - 42.0), "radius": 29.0, "seed": 53.0},
		{"area": "player", "pos": Vector2(506.0, height - 39.0), "radius": 35.0, "seed": 59.0},
		{"area": "player", "pos": Vector2(616.0, height - 67.0), "radius": 27.0, "seed": 61.0},
	]
	var bushes: Array = []
	for spec in bush_specs:
		bushes.append({
			"area": spec["area"],
			"pos": spec["pos"],
			"radius": spec["radius"],
			"seed": spec["seed"],
			"amount": 0.0,
			"angle": 0.0,
			"phase": 0.0,
		})
	return bushes


func build_vines() -> Array:
	var vines: Array = []
	for idx in range(6):
		vines.append({
			"x": 70.0 + float(idx) * 122.0,
			"length": 90.0 + float(idx % 3) * 22.0,
			"amount": 0.0,
			"angle": 0.0,
			"phase": float(idx) * 0.7,
		})
	return vines
