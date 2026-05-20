extends RefCounted


func get_ball_state(
	elapsed_sec: float,
	start_pos: Vector2,
	target_pos: Vector2,
	phase_1_duration: float,
	phase_2_duration: float,
	phase_3_duration: float,
	outro_duration: float = 0.0
) -> Dictionary:
	if elapsed_sec < phase_1_duration:
		return {
			"phase": 1,
			"phase_progress": clamp(elapsed_sec / phase_1_duration, 0.0, 1.0),
			"visible": false,
			"pos": start_pos,
			"scale": 0.1,
			"alpha": 0.0,
		}
	if elapsed_sec < phase_1_duration + phase_2_duration:
		var phase_time: float = elapsed_sec - phase_1_duration
		var progress: float = clamp(phase_time / phase_2_duration, 0.0, 1.0)
		var eased: float = _ease_out_back(progress)
		return {
			"phase": 2,
			"phase_progress": progress,
			"visible": true,
			"pos": start_pos + Vector2(0.0, sin(phase_time * 12.0) * 7.5 * (1.0 - progress * 0.45)),
			"scale": lerp(0.18, 1.0, eased),
			"alpha": clamp(progress * 1.45, 0.0, 1.0),
		}
	var phase_3_start: float = phase_1_duration + phase_2_duration
	var phase_3_end: float = phase_3_start + phase_3_duration
	if elapsed_sec >= phase_3_end:
		var outro_t: float = 1.0
		if outro_duration > 0.0001:
			outro_t = clamp((elapsed_sec - phase_3_end) / outro_duration, 0.0, 1.0)
		var fade: float = clamp(1.0 - outro_t * outro_t, 0.0, 1.0)
		return {
			"phase": 4,
			"phase_progress": outro_t,
			"visible": true,
			"body_visible": false,
			"pos": target_pos,
			"scale": 1.0,
			"alpha": fade,
		}

	var move_time: float = elapsed_sec - phase_3_start
	var move_progress: float = clamp(move_time / phase_3_duration, 0.0, 1.0)
	var move_eased: float = 1.0 - pow(1.0 - move_progress, 3.0)
	var arc_height: float = -34.0 * sin(move_progress * PI)
	var levitate: float = sin(move_time * 6.0) * 8.0 * (1.0 - move_eased)
	return {
		"phase": 3,
		"phase_progress": move_progress,
		"visible": true,
		"pos": start_pos.lerp(target_pos, move_eased) + Vector2(0.0, arc_height + levitate),
		"scale": 1.0,
		"alpha": 1.0,
	}


func current_phase(
	elapsed_sec: float,
	phase_1_duration: float,
	phase_2_duration: float,
	phase_3_duration: float = -1.0
) -> int:
	if elapsed_sec < phase_1_duration:
		return 1
	if elapsed_sec < phase_1_duration + phase_2_duration:
		return 2
	if phase_3_duration >= 0.0 and elapsed_sec >= phase_1_duration + phase_2_duration + phase_3_duration:
		return 4
	return 3


func _ease_out_back(value: float) -> float:
	var t: float = clamp(value, 0.0, 1.0)
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)
