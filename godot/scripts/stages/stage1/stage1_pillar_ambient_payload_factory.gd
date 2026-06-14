extends RefCounted


static func build_idle_butterflies() -> Array[Dictionary]:
	var butterflies: Array[Dictionary] = []
	var color_indices: Array[int] = [0, 1, 2, 3]
	var sides: Array[String] = ["left", "left", "right", "right"]
	var y_ratios: Array[float] = [1.0 / 3.0, 2.0 / 3.0, 1.0 / 3.0, 2.0 / 3.0]
	for i in range(4):
		butterflies.append({
			"side": sides[i],
			"y_ratio": y_ratios[i],
			"phase": randf_range(0.0, TAU),
			"wing_speed": 10.0,
			"color_index": color_indices[i],
			"size": 1.0,
		})
	return butterflies


static func build_flying_trail_entry(position: Vector2, alpha: float) -> Dictionary:
	return {
		"position": position,
		"alpha": alpha,
	}


static func build_absorption_particle(center: Vector2) -> Dictionary:
	var angle: float = randf_range(0.0, TAU)
	var speed: float = randf_range(35.0, 130.0)
	return {
		"position": center,
		"velocity": Vector2(cos(angle), sin(angle)) * speed,
		"life": randf_range(0.45, 1.0),
		"size": randf_range(2.0, 5.5),
	}
