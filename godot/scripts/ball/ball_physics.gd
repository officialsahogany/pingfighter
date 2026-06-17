extends RefCounted

const BallImpactBoostPolicy := preload("res://scripts/ball/ball_impact_boost_policy.gd")
const BallSpeedPolicy := preload("res://scripts/ball/ball_speed_policy.gd")
const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")

const BALL_BASE_SPEED := 7.65
const COMPANION_GUARD_CENTER_HIT_ACCEL_MULT := 0.03

var speed_policy: Object = BallSpeedPolicy.new()
var impact_boost_policy: Object = BallImpactBoostPolicy.new()
var current_stage := 1
var ai_mode := "champion"
var arena_mode_enabled := false
var weather_type := ""
var weather_active := false


func configure_context(
	stage: int,
	league_mode: String = "champion",
	arena_enabled: bool = false,
	active_weather_type: String = ""
) -> void:
	current_stage = max(1, stage)
	ai_mode = normalize_league_mode(league_mode)
	arena_mode_enabled = arena_enabled
	weather_type = active_weather_type
	weather_active = active_weather_type != ""


func normalize_league_mode(league_mode: String) -> String:
	return BattleSceneConfig.normalize_league_mode(league_mode)


func build_serve_velocity(player_serves: bool) -> Vector2:
	return speed_policy.build_serve_velocity(player_serves, _build_context())


func get_junior_ball_speed_multiplier() -> float:
	return speed_policy.get_junior_ball_speed_multiplier(_build_context())


func get_minimum_rally_speed() -> float:
	return speed_policy.get_minimum_rally_speed(_build_context())


func enforce_minimum_rally_speed(velocity: Vector2) -> Vector2:
	return speed_policy.enforce_minimum_rally_speed(velocity, _build_context())


func get_minimum_effective_boost(velocity: Vector2) -> float:
	return speed_policy.get_minimum_effective_boost(velocity, _build_context())


func get_junior_speed_increase_multiplier() -> float:
	return speed_policy.get_junior_speed_increase_multiplier(_build_context())


func get_rally_speed_increase_multiplier() -> float:
	return speed_policy.get_rally_speed_increase_multiplier(_build_context())


func get_speed_dampen_factor(current_speed: float) -> float:
	return speed_policy.get_speed_dampen_factor(current_speed)


func apply_dampened_multiplier(current_speed: float, raw_multiplier: float) -> float:
	return speed_policy.apply_dampened_multiplier(current_speed, raw_multiplier)


func apply_companion_guard_bounce_speed(velocity: Vector2, rally_speed_cap_bonus: float = 0.0) -> Vector2:
	if velocity.length() <= 0.0:
		return velocity
	var adjusted_velocity: Vector2 = enforce_minimum_rally_speed(velocity)
	var speed: float = adjusted_velocity.length()
	var accel_scale: float = get_rally_speed_increase_multiplier() * get_junior_speed_increase_multiplier()
	var raw_multiplier: float = 1.0 + COMPANION_GUARD_CENTER_HIT_ACCEL_MULT * accel_scale
	speed *= apply_dampened_multiplier(speed, raw_multiplier)
	speed = minf(speed, _get_companion_guard_speed_cap(rally_speed_cap_bonus))
	return adjusted_velocity.normalized() * speed


func get_scaled_random_multiplier(raw_min: float, raw_max: float, scale: float) -> float:
	return speed_policy.get_scaled_random_multiplier(raw_min, raw_max, scale)


func get_stage_impact_boost_cap() -> float:
	return impact_boost_policy.get_stage_impact_boost_cap(current_stage)


func compute_dynamic_impact_boost(
	velocity: Vector2,
	current_speed: float,
	launch_angle_rad: float = 0.0
) -> Dictionary:
	return impact_boost_policy.compute_dynamic_impact_boost(
		velocity,
		current_speed,
		launch_angle_rad,
		_build_context()
	)


func compute_serve_launch_impact_boost(velocity: Vector2) -> Dictionary:
	return impact_boost_policy.compute_serve_launch_impact_boost(velocity, _build_context())


func apply_impact_decay(
	velocity: Vector2,
	impact_boost: float,
	min_boost: float,
	decay_rate: float,
	fps_scale: float
) -> float:
	return impact_boost_policy.apply_impact_decay(
		velocity,
		impact_boost,
		min_boost,
		decay_rate,
		fps_scale
	)


func ensure_min_vertical_component(vector: Vector2, direction_sign: float) -> Vector2:
	return speed_policy.ensure_min_vertical_component(vector, direction_sign)


func cap_base_speed(velocity: Vector2) -> Vector2:
	return speed_policy.cap_base_speed(velocity)


func cap_effective_speed(velocity: Vector2, impact_boost: float) -> Vector2:
	return speed_policy.cap_effective_speed(velocity, impact_boost)


func _build_context() -> Dictionary:
	return {
		"current_stage": current_stage,
		"ai_mode": ai_mode,
		"arena_mode_enabled": arena_mode_enabled,
		"weather_type": weather_type,
		"weather_active": weather_active,
	}


func _get_companion_guard_speed_cap(rally_speed_cap_bonus: float) -> float:
	var cap: float = BallSpeedPolicy.DEFAULT_MAX_BALL_SPEED
	if ai_mode == "mythic":
		cap = BallSpeedPolicy.MYTHIC_MAX_BALL_SPEED
	if weather_active and weather_type == "fire":
		cap = BallSpeedPolicy.FIRE_WEATHER_MAX_BALL_SPEED
	return cap + maxf(0.0, rally_speed_cap_bonus)
