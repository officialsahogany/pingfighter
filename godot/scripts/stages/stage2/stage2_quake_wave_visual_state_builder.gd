extends RefCounted


func build_state(
	timer: float,
	duration: float,
	affects_ball: bool,
	wave_count: int,
	wave_segments: int,
	visual_only_wave_count: int,
	visual_only_wave_segments: int
) -> Dictionary:
	return {
		"timer": timer,
		"duration": duration,
		"visual_only": timer > 0.0 and not affects_ball,
		"wave_count": wave_count,
		"wave_segments": wave_segments,
		"visual_only_wave_count": visual_only_wave_count,
		"visual_only_wave_segments": visual_only_wave_segments,
	}
