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
	is_half: bool,
	recovery_frames: float = DASH_RECOVERY_FRAMES
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
		"recovery_timer": _get_recovery_timer(ended, is_half, recovery_frames),
	}


func _get_recovery_timer(ended: bool, is_half: bool, recovery_frames: float) -> float:
	if not ended:
		return 0.0
	var frames: float = max(1.0, recovery_frames)
	if is_half:
		return frames * HALF_DASH_RECOVERY_MULT
	return frames


func _get_current_speed(timer: float) -> float:
	if timer > DASH_DECEL_FRAMES:
		return DASH_BASE_SPEED
	var dash_strength: float = clamp(timer / DASH_DECEL_FRAMES, 0.0, 1.0)
	return DASH_BASE_SPEED * dash_strength


# 실전 대시 이동거리: update()가 프레임마다 수행하는 감속 커브 이동
# (round(direction * speed), fps_scale=1 기준)을 그대로 적분한다. 능력치 패널
# 대시 거리 표시가 이 함수를 쓰므로 커브 상수가 바뀌면 표시도 따라온다.
# _get_current_speed와 동일 커브를 인라인한다 — 그 인스턴스 메서드에 의존하지
# 않아야 정적 컨텍스트에서 호출 가능하고 다른 세션의 시그니처 변경과도 무관하다.
static func compute_total_dash_distance(duration_frames: float, distance_multiplier: float = 1.0) -> float:
	var timer: float = max(1.0, duration_frames)
	var mult: float = maxf(0.0, distance_multiplier)
	var distance: float = 0.0
	var frame_guard: int = 0
	while timer > 0.0 and frame_guard < 600:
		timer -= 1.0
		var speed: float = DASH_BASE_SPEED * mult
		if timer <= DASH_DECEL_FRAMES:
			speed *= clampf(timer / DASH_DECEL_FRAMES, 0.0, 1.0)
		distance += absf(round(speed))
		frame_guard += 1
	return distance
