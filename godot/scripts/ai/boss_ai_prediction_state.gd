extends RefCounted

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")

const BOSS_ACCURACY: float = 1.0
const BOSS_ACCURACY_ERROR: float = 60.0
const BOSS_MISTAKE_CHANCE: float = 0.10
const BOSS_MISTAKE_ERROR_MIN: float = 78.0
const BOSS_MISTAKE_ERROR_MAX: float = 140.0
const BOSS_MISTAKE_SPEED_SCALE: float = 4.5
const JUNIOR_POWER_SMASH_MISTAKE_CHANCE: float = 0.80
const JUNIOR_POWER_SMASH_MISTAKE_ERROR_MIN: float = 170.0
const JUNIOR_POWER_SMASH_MISTAKE_ERROR_MAX: float = 260.0
const JUNIOR_POWER_SMASH_MISTAKE_SPEED_SCALE: float = 7.0
const BOSS_FAST_BALL_SPEED: float = 15.0
const BOSS_MEDIUM_BALL_SPEED: float = 10.0
const BOSS_FAST_PREDICT_FRAMES: float = 8.0
const BOSS_MEDIUM_PREDICT_FRAMES: float = 12.0
const BOSS_SLOW_PREDICT_FRAMES: float = 20.0
const WALL_REFLECTION_LIMIT: int = 4
const PREDICTION_SIMULATION_MAX_FRAMES: int = 120

var approach_decision_active := false
var approach_mistake_active := false
var boss_fail_error_offset: float = 0.0


func reset() -> void:
	_reset_approach_decision()


func predict_future_x(
	ball_pos: Vector2,
	ball_vel: Vector2,
	fps_scale: float,
	play_left: float,
	play_right: float,
	boss_paddle_width: float,
	context: Dictionary = {}
) -> float:
	var effective_ball_vel: Vector2 = ball_vel * float(context.get("ball_impact_boost", 1.0))
	var predict_frame: float = _get_predict_frames(effective_ball_vel)
	# 인자 play_left/right는 '공 반사 경계'(홀로그램 기만 프레임은 분신의
	# 시각 여백으로 좁혀 들어온다). 보스 '목표 중심' 클램프는 컨텍스트의
	# 전역 play 경계 기준 — 반사 경계로 클램프하면 보스 목표 범위까지
	# 좁아진다. 일반 경로는 둘이 같아 동작 불변.
	var clamp_play_left: float = float(context.get("play_left", play_left))
	var clamp_play_right: float = float(context.get("play_right", play_right))
	var min_center: float = clamp_play_left + boss_paddle_width * 0.5
	var max_center: float = clamp_play_right - boss_paddle_width * 0.5
	var future_x: float = _predict_arrival_x(ball_pos, ball_vel, predict_frame, play_left, play_right, context, fps_scale)
	if ball_vel.y >= -0.001:
		_reset_approach_decision()
		return clamp(future_x, min_center, max_center)
	if not approach_decision_active:
		_roll_approach_decision(effective_ball_vel, context)
	future_x = _apply_approach_prediction_error(future_x)
	return clamp(future_x, min_center, max_center)


func predict_exact_arrival_x(
	ball_pos: Vector2,
	ball_vel: Vector2,
	play_left: float,
	play_right: float,
	boss_paddle_width: float,
	context: Dictionary = {},
	fps_scale: float = 1.0
) -> float:
	var effective_ball_vel: Vector2 = ball_vel * float(context.get("ball_impact_boost", 1.0))
	var predict_frame: float = _get_predict_frames(effective_ball_vel)
	# 반사 경계(인자)와 보스 목표 클램프(전역) 분리 — predict_future_x와
	# 동일한 계약.
	var clamp_play_left: float = float(context.get("play_left", play_left))
	var clamp_play_right: float = float(context.get("play_right", play_right))
	var min_center: float = clamp_play_left + boss_paddle_width * 0.5
	var max_center: float = clamp_play_right - boss_paddle_width * 0.5
	var future_x: float = _predict_arrival_x(ball_pos, ball_vel, predict_frame, play_left, play_right, context, fps_scale)
	return clamp(future_x, min_center, max_center)


func _apply_approach_prediction_error(future_x: float) -> float:
	if approach_mistake_active:
		return future_x + boss_fail_error_offset
	if randf() > BOSS_ACCURACY:
		return future_x + randf_range(-BOSS_ACCURACY_ERROR, BOSS_ACCURACY_ERROR)
	return future_x


func _roll_approach_decision(ball_vel: Vector2, context: Dictionary) -> void:
	approach_decision_active = true
	approach_mistake_active = false
	boss_fail_error_offset = 0.0
	var mistake_chance: float = clamp(float(context.get("boss_mistake_chance", BOSS_MISTAKE_CHANCE)), 0.0, 1.0)
	var junior_power_smash_active: bool = _is_junior_power_smash_active(context)
	if junior_power_smash_active:
		mistake_chance = max(mistake_chance, JUNIOR_POWER_SMASH_MISTAKE_CHANCE)
	elif bool(context.get("power_smashing_parabola_active", false)) and int(context.get("power_smashing_combo_consumed", 0)) >= 3:
		mistake_chance *= 0.5
	if randf() < mistake_chance:
		var current_speed: float = ball_vel.length()
		var mistake_error_min: float = JUNIOR_POWER_SMASH_MISTAKE_ERROR_MIN if junior_power_smash_active else BOSS_MISTAKE_ERROR_MIN
		var mistake_error_max: float = JUNIOR_POWER_SMASH_MISTAKE_ERROR_MAX if junior_power_smash_active else BOSS_MISTAKE_ERROR_MAX
		var mistake_speed_scale: float = JUNIOR_POWER_SMASH_MISTAKE_SPEED_SCALE if junior_power_smash_active else BOSS_MISTAKE_SPEED_SCALE
		if not junior_power_smash_active:
			mistake_error_min = max(0.0, float(context.get("boss_mistake_error_min", BOSS_MISTAKE_ERROR_MIN)))
			mistake_error_max = max(0.0, float(context.get("boss_mistake_error_max", BOSS_MISTAKE_ERROR_MAX)))
			mistake_speed_scale = max(0.0, float(context.get("boss_mistake_speed_scale", BOSS_MISTAKE_SPEED_SCALE)))
			mistake_error_max = max(mistake_error_min, mistake_error_max)
		var mistake_magnitude: float = min(
			mistake_error_max,
			max(mistake_error_min, current_speed * mistake_speed_scale)
		)
		var mistake_direction := -1.0 if randf() < 0.5 else 1.0
		approach_mistake_active = true
		boss_fail_error_offset = mistake_direction * mistake_magnitude


func _reset_approach_decision() -> void:
	approach_decision_active = false
	approach_mistake_active = false
	boss_fail_error_offset = 0.0


func _get_predict_frames(ball_vel: Vector2) -> float:
	var ball_speed: float = abs(ball_vel.x) + abs(ball_vel.y)
	if ball_speed > BOSS_FAST_BALL_SPEED:
		return BOSS_FAST_PREDICT_FRAMES
	if ball_speed > BOSS_MEDIUM_BALL_SPEED:
		return BOSS_MEDIUM_PREDICT_FRAMES
	return BOSS_SLOW_PREDICT_FRAMES


func _is_junior_power_smash_active(context: Dictionary) -> bool:
	return (
		bool(context.get("power_smashing_parabola_active", false))
		and _normalize_league_mode(str(context.get("ai_mode", "champion"))) == "junior"
	)


func _normalize_league_mode(ai_mode: String) -> String:
	return BattleSceneConfig.normalize_league_mode(ai_mode)


func _predict_arrival_x(
	ball_pos: Vector2,
	ball_vel: Vector2,
	fallback_frames: float,
	play_left: float,
	play_right: float,
	context: Dictionary,
	fps_scale: float = 1.0
) -> float:
	if ball_vel.y >= -0.001:
		var effective_vx: float = ball_vel.x * float(context.get("ball_impact_boost", 1.0))
		return _predict_x_with_walls(ball_pos.x, effective_vx, fallback_frames, play_left, play_right)
	return _predict_x_until_boss_line(ball_pos, ball_vel, play_left, play_right, context, fps_scale)


func _predict_x_until_boss_line(
	ball_pos: Vector2,
	ball_vel: Vector2,
	play_left: float,
	play_right: float,
	context: Dictionary,
	fps_scale: float = 1.0
) -> float:
	var target_y: float = _get_boss_intercept_y(context)
	if ball_pos.y <= target_y or abs(ball_vel.y) < 0.001:
		return clamp(ball_pos.x, play_left, play_right)

	var predicted_pos: Vector2 = ball_pos
	var impact_boost: float = float(context.get("ball_impact_boost", 1.0))
	var min_boost: float = float(context.get("ball_min_boost", 0.70))
	var decay_rate: float = clamp(float(context.get("ball_boost_decay_rate", 0.975)), 0.01, 0.9999)
	# 홀로그램 기만 프레임 옵트인: 분신은 벽 반사 후 반전된 vel.x를 유지한
	# 채 raw velocity(부스트 계약 무력화 = boost/decay 상수)로 직진하므로,
	# 도착 프레임 수를 닫힌형으로 구하고 최초 signed vx × 총 프레임을
	# 삼각파 modulo로 접으면 O(1) exact arrival이다 — 프레임 컷도 반사
	# 횟수 제한도 없고, 물리 hot path에서 프레임당 Dictionary 할당(얕은
	# 궤적 기준 틱당 최대 1200회)도 발생하지 않는다. 실 공 경로(플래그
	# 부재)는 기존 근사(매 프레임 원래 vx)를 그대로 유지해 회귀가 없다.
	if bool(context.get("prediction_reflect_velocity", false)):
		# 실 분신은 vel × fps_scale로 이동한다(72Hz 기본 = 5/6) — 명목
		# 프레임으로 계산하면 live scale에서 parity가 깨진다. 정수-tick
		# 판정까지 미러: ticks = ceil(거리 / (하강분×fps_scale)),
		# dx = vx × fps_scale × ticks.
		var descent_per_tick: float = -ball_vel.y * impact_boost * max(0.0001, fps_scale)
		if descent_per_tick <= 0.0005:
			return clamp(ball_pos.x, play_left, play_right)
		var ticks_to_intercept: float = ceilf((ball_pos.y - target_y) / descent_per_tick)
		return _predict_x_reflected_modulo(
			ball_pos.x,
			ball_vel.x * impact_boost * max(0.0001, fps_scale) * ticks_to_intercept,
			play_left,
			play_right
		)
	for _frame_index in range(PREDICTION_SIMULATION_MAX_FRAMES):
		var move: Vector2 = ball_vel * impact_boost
		predicted_pos.x = _advance_x_with_walls(predicted_pos.x, move.x, play_left, play_right)
		predicted_pos.y += move.y
		if predicted_pos.y <= target_y:
			return clamp(predicted_pos.x, play_left, play_right)
		if impact_boost > min_boost:
			impact_boost = max(impact_boost * decay_rate, min_boost)
	return _predict_x_with_walls(
		ball_pos.x,
		ball_vel.x * float(context.get("ball_impact_boost", 1.0)),
		float(PREDICTION_SIMULATION_MAX_FRAMES),
		play_left,
		play_right
	)


func _get_boss_intercept_y(context: Dictionary) -> float:
	return (
		float(context.get("boss_y", 25.0))
		+ float(context.get("boss_hitbox_height", 40.0))
		+ float(context.get("hitbox_padding", 5.0))
		+ float(context.get("ball_size", 28.6)) * 0.5
	)


# 총 이동량을 삼각파 modulo로 접어 반사 횟수 제한 없이 정확한 최종 x를
# 돌려준다 — 홀로그램 기만 예측의 극단(초장거리 이동) 안전망.
func _predict_x_reflected_modulo(x: float, total_dx: float, play_left: float, play_right: float) -> float:
	var span: float = play_right - play_left
	if span <= 0.001:
		return clamp(x, play_left, play_right)
	var period: float = span * 2.0
	var phase: float = fposmod(clamp(x, play_left, play_right) - play_left + total_dx, period)
	if phase <= span:
		return play_left + phase
	return play_left + (period - phase)


func _advance_x_with_walls(x: float, dx: float, play_left: float, play_right: float) -> float:
	if abs(dx) < 0.001:
		return clamp(x, play_left, play_right)

	var remaining: float = dx
	var predicted_x: float = clamp(x, play_left, play_right)
	for _bounce_index in range(WALL_REFLECTION_LIMIT):
		var next_x: float = predicted_x + remaining
		if next_x >= play_left and next_x <= play_right:
			return next_x
		if next_x > play_right:
			remaining = -(next_x - play_right)
			predicted_x = play_right
		else:
			remaining = play_left - next_x
			predicted_x = play_left
	return clamp(predicted_x + remaining, play_left, play_right)


func _predict_x_with_walls(x: float, vx: float, frames: float, play_left: float, play_right: float) -> float:
	if abs(vx) < 0.001 or frames <= 0.0:
		return clamp(x, play_left, play_right)

	var remaining: float = frames
	var predicted_x: float = clamp(x, play_left, play_right)
	var predicted_vx: float = vx
	for _bounce_index in range(WALL_REFLECTION_LIMIT):
		if remaining <= 0.0:
			break

		var time_to_wall: float = INF
		if predicted_vx > 0.0:
			time_to_wall = (play_right - predicted_x) / predicted_vx
		elif predicted_vx < 0.0:
			time_to_wall = (play_left - predicted_x) / predicted_vx

		if time_to_wall <= 0.0 or time_to_wall >= remaining:
			predicted_x += predicted_vx * remaining
			remaining = 0.0
			break

		predicted_x += predicted_vx * time_to_wall
		remaining -= time_to_wall
		predicted_vx = -predicted_vx

	return clamp(predicted_x, play_left, play_right)
