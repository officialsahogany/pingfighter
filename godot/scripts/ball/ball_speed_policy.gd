extends RefCounted

const BALL_BASE_SPEED := 7.65
const SERVE_SIDE_SPEED := 2.55
const SERVE_SPEED_SCALE := 1.2
const SERVE_STAGE_SPEED_RATE := 0.03
const SERVE_STAGE_SPEED_CAP := 0.5
const SERVE_MAX_BASE_MULT := 1.6
const JUNIOR_BALL_SPEED_MULT := 0.85
const SPEED_DAMPEN_K := 0.6
const JUNIOR_SPEED_INCREASE_MULT := 0.85
const DEFAULT_RALLY_SPEED_MULT := 0.1008
const ARENA_RALLY_SPEED_MULT := 2.24
const WEATHER_RALLY_SPEED_MULT := 1.6
const FIRE_RALLY_SPEED_MULT := 2.0
const FIRE_BASE_SPEED_MULT := 1.07
const DEFAULT_MAX_BALL_SPEED := 26.0
const MYTHIC_MAX_BALL_SPEED := 32.0
const FIRE_WEATHER_MAX_BALL_SPEED := 35.0
const MIN_BOUNCE_ANGLE_DEG := 25.0
const SPEED_SCALE_THRESHOLD := 20.0


func build_serve_velocity(player_serves: bool, context: Dictionary) -> Vector2:
	var direction: float = -1.0 if player_serves else 1.0
	var stage_multiplier: float = _get_serve_stage_multiplier(context)

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
	if bool(context.get("weather_active", false)) and str(context.get("weather_type", "")) == "fire":
		velocity *= FIRE_BASE_SPEED_MULT
	return velocity


func get_minimum_rally_speed(context: Dictionary) -> float:
	var stage_multiplier: float = _get_serve_stage_multiplier(context)
	var serve_speed: float = Vector2(SERVE_SIDE_SPEED, BALL_BASE_SPEED).length()
	serve_speed *= stage_multiplier * SERVE_SPEED_SCALE
	if bool(context.get("weather_active", false)) and str(context.get("weather_type", "")) == "fire":
		serve_speed *= FIRE_BASE_SPEED_MULT
	var max_serve_speed: float = BALL_BASE_SPEED * SERVE_MAX_BASE_MULT * SERVE_SPEED_SCALE
	serve_speed = min(serve_speed, max_serve_speed)
	return serve_speed * get_junior_ball_speed_multiplier(context)


func enforce_minimum_rally_speed(velocity: Vector2, context: Dictionary) -> Vector2:
	var current_speed: float = velocity.length()
	if current_speed <= 0.0:
		return velocity
	var minimum_speed: float = get_minimum_rally_speed(context)
	if current_speed >= minimum_speed:
		return velocity
	return velocity.normalized() * minimum_speed


func get_minimum_effective_boost(velocity: Vector2, context: Dictionary) -> float:
	var current_speed: float = velocity.length()
	if current_speed <= 0.0:
		return 1.0
	return get_minimum_rally_speed(context) / current_speed


func get_junior_ball_speed_multiplier(context: Dictionary) -> float:
	return JUNIOR_BALL_SPEED_MULT if str(context.get("ai_mode", "champion")) == "junior" else 1.0


func get_junior_speed_increase_multiplier(context: Dictionary) -> float:
	return JUNIOR_SPEED_INCREASE_MULT if str(context.get("ai_mode", "champion")) == "junior" else 1.0


func get_rally_speed_increase_multiplier(context: Dictionary) -> float:
	if bool(context.get("arena_mode_enabled", false)):
		return ARENA_RALLY_SPEED_MULT
	var weather_type: String = str(context.get("weather_type", ""))
	if bool(context.get("weather_active", false)) and weather_type == "fire":
		return DEFAULT_RALLY_SPEED_MULT * FIRE_RALLY_SPEED_MULT
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


func cap_effective_speed(velocity: Vector2, impact_boost: float) -> Vector2:
	var boost: float = max(1.0, impact_boost)
	var effective_speed: float = velocity.length() * boost
	if effective_speed > SPEED_SCALE_THRESHOLD:
		return velocity.normalized() * (SPEED_SCALE_THRESHOLD / boost)
	return velocity


func _get_serve_stage_multiplier(context: Dictionary) -> float:
	var stage_multiplier: float = 1.0
	var current_stage: int = int(context.get("current_stage", 1))
	if current_stage != 50:
		stage_multiplier += min(float(max(0, current_stage - 1)) * SERVE_STAGE_SPEED_RATE, SERVE_STAGE_SPEED_CAP)
	return stage_multiplier
