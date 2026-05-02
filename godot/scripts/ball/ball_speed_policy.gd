extends RefCounted

const BALL_BASE_SPEED := 7.65
const SERVE_SIDE_SPEED := 2.55
const SERVE_SPEED_SCALE := 1.2
const SERVE_STAGE_SPEED_RATE := 0.03
const SERVE_STAGE_SPEED_CAP := 0.5
const SERVE_MAX_BASE_MULT := 1.6
const JUNIOR_BALL_SPEED_MULT := 0.65
const SPEED_DAMPEN_K := 0.6
const JUNIOR_SPEED_INCREASE_MULT := 0.6
const DEFAULT_RALLY_SPEED_MULT := 0.168
const ARENA_RALLY_SPEED_MULT := 2.24
const WEATHER_RALLY_SPEED_MULT := 1.6
const MIN_BOUNCE_ANGLE_DEG := 25.0
const SPEED_SCALE_THRESHOLD := 51.0


func build_serve_velocity(player_serves: bool, context: Dictionary) -> Vector2:
	var direction: float = -1.0 if player_serves else 1.0
	var stage_multiplier: float = 1.0
	var current_stage: int = int(context.get("current_stage", 1))
	if current_stage != 50:
		stage_multiplier += min(float(max(0, current_stage - 1)) * SERVE_STAGE_SPEED_RATE, SERVE_STAGE_SPEED_CAP)

	var velocity := Vector2(
		-SERVE_SIDE_SPEED if randf() < 0.5 else SERVE_SIDE_SPEED,
		direction * BALL_BASE_SPEED
	) * stage_multiplier * SERVE_SPEED_SCALE

	var max_serve_speed: float = BALL_BASE_SPEED * SERVE_MAX_BASE_MULT * SERVE_SPEED_SCALE
	var serve_speed: float = velocity.length()
	if serve_speed > max_serve_speed:
		velocity = velocity.normalized() * max_serve_speed

	var junior_ball_mult: float = get_junior_ball_speed_multiplier(context)
	if junior_ball_mult != 1.0:
		velocity *= junior_ball_mult
	return velocity


func get_junior_ball_speed_multiplier(context: Dictionary) -> float:
	return JUNIOR_BALL_SPEED_MULT if str(context.get("ai_mode", "champion")) == "junior" else 1.0


func get_junior_speed_increase_multiplier(context: Dictionary) -> float:
	return JUNIOR_SPEED_INCREASE_MULT if str(context.get("ai_mode", "champion")) == "junior" else 1.0


func get_rally_speed_increase_multiplier(context: Dictionary) -> float:
	if bool(context.get("arena_mode_enabled", false)):
		return ARENA_RALLY_SPEED_MULT
	var weather_type: String = str(context.get("weather_type", ""))
	if bool(context.get("weather_active", false)) and (weather_type == "breeze" or weather_type == "gust"):
		return DEFAULT_RALLY_SPEED_MULT * WEATHER_RALLY_SPEED_MULT
	return DEFAULT_RALLY_SPEED_MULT


func get_speed_dampen_factor(current_speed: float) -> float:
	var base_speed: float = BALL_BASE_SPEED if BALL_BASE_SPEED > 0.0 else 9.0
	var ratio: float = current_speed / base_speed
	if ratio <= 1.0:
		return 1.0
	return 1.0 / (1.0 + (ratio - 1.0) * SPEED_DAMPEN_K)


func apply_dampened_multiplier(current_speed: float, raw_multiplier: float) -> float:
	if raw_multiplier <= 1.0:
		return raw_multiplier
	var excess: float = raw_multiplier - 1.0
	return 1.0 + excess * get_speed_dampen_factor(current_speed)


func get_scaled_random_multiplier(raw_min: float, raw_max: float, scale: float) -> float:
	var min_excess: float = (raw_min - 1.0) * scale
	var max_excess: float = (raw_max - 1.0) * scale
	return 1.0 + randf_range(min_excess, max_excess)


func ensure_min_vertical_component(vector: Vector2, direction_sign: float) -> Vector2:
	if vector.length() == 0.0:
		return Vector2(0.0, direction_sign)

	var result: Vector2 = vector.normalized()
	var min_vertical_ratio: float = sin(deg_to_rad(MIN_BOUNCE_ANGLE_DEG))
	if abs(result.y) >= min_vertical_ratio:
		return result

	result.y = sign(direction_sign) * min_vertical_ratio
	var remaining_x_sq: float = max(0.0, 1.0 - result.y * result.y)
	var x_sign: float = sign(result.x)
	if x_sign == 0.0:
		x_sign = -1.0 if randf() < 0.5 else 1.0
	result.x = x_sign * sqrt(remaining_x_sq)
	return result.normalized()


func cap_base_speed(velocity: Vector2) -> Vector2:
	var base_speed: float = velocity.length()
	if base_speed > SPEED_SCALE_THRESHOLD:
		return velocity.normalized() * SPEED_SCALE_THRESHOLD
	return velocity
