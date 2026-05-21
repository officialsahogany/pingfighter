extends RefCounted


static func get_offset(quake_timer: float, quake_duration: float, rng: RandomNumberGenerator) -> Vector2:
	if quake_timer <= 0.0:
		return Vector2.ZERO
	var duration_frames: float = max(1.0, quake_duration * 60.0)
	var elapsed_frames: float = clampf((quake_duration - quake_timer) * 60.0, 0.0, duration_frames)
	var progress: float = elapsed_frames / duration_frames
	var base_intensity: float = _get_base_intensity(progress)
	var pulse: float = 1.0 + sin(elapsed_frames * 1.7) * 0.22
	var wave_x: float = sin(elapsed_frames * 2.2) * base_intensity * 0.52
	var wave_y: float = cos(elapsed_frames * 2.8) * base_intensity * 0.66
	var noise_x: float = rng.randf_range(-base_intensity * 0.45, base_intensity * 0.45)
	var noise_y: float = rng.randf_range(-base_intensity * 0.38, base_intensity * 0.38)
	return Vector2(round((wave_x + noise_x) * pulse), round((wave_y + noise_y) * pulse))


static func _get_base_intensity(progress: float) -> float:
	if progress < 0.14:
		return 13.2 + sin(progress / 0.14 * PI) * 1.5
	if progress < 0.65:
		var middle_progress: float = (progress - 0.14) / 0.51
		return 12.0 - middle_progress * 4.1
	var fade_progress: float = (progress - 0.65) / 0.35
	return 7.9 * (1.0 - clampf(fade_progress, 0.0, 1.0))
