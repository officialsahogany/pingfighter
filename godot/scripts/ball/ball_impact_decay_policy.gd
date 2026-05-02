extends RefCounted


func apply(
	velocity: Vector2,
	impact_boost: float,
	min_boost: float,
	decay_rate: float,
	fps_scale: float
) -> float:
	if impact_boost <= min_boost:
		return impact_boost

	var configured_decay_rate: float = clamp(decay_rate, 0.01, 0.9999)
	var next_boost: float = impact_boost * pow(configured_decay_rate, fps_scale)
	return max(next_boost, min_boost)
