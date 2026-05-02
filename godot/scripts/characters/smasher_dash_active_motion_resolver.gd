extends RefCounted

const DASH_BASE_SPEED: float = 40.0
const DASH_DECEL_FRAMES: float = 20.0
const DASH_RECOVERY_FRAMES: float = 42.0
const HALF_DASH_RECOVERY_MULT: float = 1.5


func update(
	fps_scale: float,
	player_pos: Vector2,
	play_left: float,
	play_right: float,
	paddle_width: float,
	direction: float,
	timer: float,
	is_half: bool
) -> Dictionary:
	timer -= fps_scale
	var current_speed: float = _get_current_speed(timer)
	player_pos.x += round(direction * current_speed * fps_scale)
	player_pos.x = clamp(player_pos.x, play_left, play_right - paddle_width)

	var ended: bool = timer <= 0.0
	return {
		"player_pos": player_pos,
		"timer": timer,
		"elapsed_delta": fps_scale,
		"ended": ended,
		"recovery_timer": _get_recovery_timer(ended, is_half),
	}


func _get_recovery_timer(ended: bool, is_half: bool) -> float:
	if not ended:
		return 0.0
	if is_half:
		return DASH_RECOVERY_FRAMES * HALF_DASH_RECOVERY_MULT
	return DASH_RECOVERY_FRAMES


func _get_current_speed(timer: float) -> float:
	if timer > DASH_DECEL_FRAMES:
		return DASH_BASE_SPEED
	var dash_strength: float = clamp(timer / DASH_DECEL_FRAMES, 0.0, 1.0)
	return DASH_BASE_SPEED * dash_strength
