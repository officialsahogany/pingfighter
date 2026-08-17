extends RefCounted

const SmasherDashMotionUpdateResolver := preload("res://scripts/characters/smasher_dash_motion_update_resolver.gd")

const DASH_DURATION: float = 15.0
const HALF_DASH_DURATION: float = 11.0
const PLAYER_BASE_PADDLE_WIDTH: float = 155.0
const PLAYER_BASE_PADDLE_HEIGHT: float = 50.0
# 대붕전익의 세로 보너스(+70%/Lv)는 유지하되, 같은 비율을 가로에
# 적용하면 Lv.5에 화면 대부분을 덮는다. 가로는 시각 오라와 맞는 +10%/Lv로 제한한다.
const DASH_ACCELERATION_WIDTH_BONUS_SCALE: float = 1.0 / 7.0

var update_resolver: Object = SmasherDashMotionUpdateResolver.new()
var dash_active: bool = false
var dash_timer: float = 0.0
var dash_direction: float = 0.0
var dash_is_half: bool = false
var dash_acceleration_bonus: float = 0.0
var dash_acceleration_width_bonus: float = 0.0
var dash_acceleration_height_bonus: float = 0.0
var dash_acceleration_skill_level: int = 0
var dash_skip_recovery: bool = false
# 신비의 주사위 dash_distance 속도 배율(시작 시 1회 스냅샷 — 대쉬 중
# 커밋이 진행 중 대쉬를 소급 변경하지 않는다).
var dash_distance_multiplier: float = 1.0
var dash_stun_timer: float = 0.0
var dash_recovery_total_frames: float = 0.0
var dash_available_timer: float = 0.0
var dash_elapsed_frames: float = 0.0


func reset_round() -> void:
	dash_active = false
	dash_timer = 0.0
	dash_direction = 0.0
	dash_is_half = false
	dash_acceleration_bonus = 0.0
	dash_acceleration_width_bonus = 0.0
	dash_acceleration_height_bonus = 0.0
	dash_acceleration_skill_level = 0
	dash_skip_recovery = false
	dash_stun_timer = 0.0
	dash_recovery_total_frames = 0.0
	dash_available_timer = 0.0
	dash_elapsed_frames = 0.0


func is_active() -> bool:
	return dash_active


func is_recovering() -> bool:
	return dash_stun_timer > 0.0


func clear_recovery() -> void:
	dash_skip_recovery = false
	dash_stun_timer = 0.0
	dash_recovery_total_frames = 0.0
	dash_available_timer = 0.0


func cancel_active_without_recovery() -> bool:
	if not dash_active:
		return false
	dash_active = false
	dash_timer = 0.0
	dash_elapsed_frames = 0.0
	dash_acceleration_bonus = 0.0
	dash_acceleration_width_bonus = 0.0
	dash_acceleration_height_bonus = 0.0
	dash_acceleration_skill_level = 0
	dash_skip_recovery = false
	dash_stun_timer = 0.0
	dash_recovery_total_frames = 0.0
	dash_available_timer = 0.0
	return true


func can_chain(direction: float, has_full_token: bool, start_delay_frames: float) -> bool:
	return (
		dash_active
		and not dash_is_half
		and has_full_token
		and dash_elapsed_frames >= start_delay_frames
		and direction != 0.0
	)


func can_chain_from_recovery(direction: float, has_chain_token: bool) -> bool:
	return dash_stun_timer > 0.0 and has_chain_token and direction != 0.0


func can_start(direction: float, key_released_since_last: bool) -> bool:
	return direction != 0.0 and dash_available_timer <= 0.0 and key_released_since_last


func start(
	direction: float,
	is_half: bool,
	duration_frames: float = DASH_DURATION,
	acceleration_bonus: float = 0.0,
	acceleration_level: int = 0,
	base_paddle_height: float = PLAYER_BASE_PADDLE_HEIGHT,
	skip_recovery: bool = false,
	distance_multiplier: float = 1.0,
	base_paddle_width: float = PLAYER_BASE_PADDLE_WIDTH
) -> bool:
	if direction == 0.0:
		return false
	dash_active = true
	dash_direction = direction
	dash_is_half = is_half
	dash_distance_multiplier = maxf(0.0, distance_multiplier)
	dash_acceleration_bonus = max(0.0, acceleration_bonus)
	dash_acceleration_skill_level = max(0, acceleration_level)
	dash_acceleration_width_bonus = (
		max(0.0, float(base_paddle_width))
		* dash_acceleration_bonus
		* DASH_ACCELERATION_WIDTH_BONUS_SCALE
	)
	dash_acceleration_height_bonus = max(0.0, float(base_paddle_height)) * dash_acceleration_bonus
	dash_skip_recovery = bool(skip_recovery)
	dash_elapsed_frames = 0.0
	dash_stun_timer = 0.0
	dash_recovery_total_frames = 0.0
	dash_available_timer = 0.0
	if is_half:
		dash_timer = max(1.0, duration_frames * (HALF_DASH_DURATION / DASH_DURATION))
	else:
		dash_timer = max(1.0, duration_frames)
	return true


func update(
	fps_scale: float,
	player_pos: Vector2,
	play_left: float,
	play_right: float,
	paddle_width: float,
	recovery_frames: float = 42.0
) -> Dictionary:
	return update_resolver.update(self, fps_scale, player_pos, play_left, play_right, paddle_width, recovery_frames)


func get_snapshot() -> Dictionary:
	var acceleration_active: bool = dash_active and (
		dash_acceleration_width_bonus > 0.0
		or dash_acceleration_height_bonus > 0.0
	)
	return {
		"active": dash_active,
		"timer": dash_timer,
		"direction": dash_direction,
		"is_half": dash_is_half,
		"dash_acceleration_active": acceleration_active,
		"dash_acceleration_bonus": dash_acceleration_bonus if acceleration_active else 0.0,
		"dash_acceleration_width_bonus": dash_acceleration_width_bonus if acceleration_active else 0.0,
		"dash_acceleration_height_bonus": dash_acceleration_height_bonus if acceleration_active else 0.0,
		"dash_acceleration_skill_level": dash_acceleration_skill_level if acceleration_active else 0,
		"skip_recovery": dash_skip_recovery,
		"dash_distance_multiplier": dash_distance_multiplier,
		"recovering": dash_stun_timer > 0.0,
		"stun_timer": dash_stun_timer,
		"recovery_total_frames": dash_recovery_total_frames,
		"recovery_progress": _get_recovery_progress(),
		"available_timer": dash_available_timer,
		"elapsed_frames": dash_elapsed_frames,
	}


func _get_recovery_progress() -> float:
	if dash_stun_timer <= 0.0:
		return 1.0
	var total_frames: float = max(1.0, dash_recovery_total_frames)
	return clamp(1.0 - dash_stun_timer / total_frames, 0.0, 1.0)
