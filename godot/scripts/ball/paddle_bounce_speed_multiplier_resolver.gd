extends RefCounted

const PaddleBounceVelocityRules := preload("res://scripts/ball/paddle_bounce_velocity_rules.gd")

const EDGE_HIT_BOOST: float = 1.2
const BASE_HIT_SPEED_MULT_MIN: float = 1.024
const BASE_HIT_SPEED_MULT_MAX: float = 1.084
const BOSS_HIT_SPEED_MULT_MIN: float = 1.012
const BOSS_HIT_SPEED_MULT_MAX: float = 1.054

var velocity_rules: Object = PaddleBounceVelocityRules.new()


func apply(
	speed: float,
	hit_pos: float,
	is_player: bool,
	drive_activated: bool,
	accel_scale: float,
	ball_physics: Object
) -> float:
	if not drive_activated:
		speed = _apply_base_hit_multiplier(speed, hit_pos, accel_scale, ball_physics)

	if not is_player:
		speed = _apply_boss_hit_multiplier(speed, hit_pos, accel_scale, ball_physics)

	return speed


func _apply_base_hit_multiplier(
	speed: float,
	hit_pos: float,
	accel_scale: float,
	ball_physics: Object
) -> float:
	speed *= velocity_rules.apply_dampened_multiplier(
		ball_physics,
		speed,
		velocity_rules.get_scaled_random_multiplier(ball_physics, BASE_HIT_SPEED_MULT_MIN, BASE_HIT_SPEED_MULT_MAX, accel_scale)
	)
	return _apply_edge_hit_multiplier(speed, hit_pos, ball_physics)


func _apply_boss_hit_multiplier(
	speed: float,
	hit_pos: float,
	accel_scale: float,
	ball_physics: Object
) -> float:
	speed *= velocity_rules.apply_dampened_multiplier(
		ball_physics,
		speed,
		velocity_rules.get_scaled_random_multiplier(ball_physics, BOSS_HIT_SPEED_MULT_MIN, BOSS_HIT_SPEED_MULT_MAX, accel_scale)
	)
	return _apply_edge_hit_multiplier(speed, hit_pos, ball_physics)


func _apply_edge_hit_multiplier(speed: float, hit_pos: float, ball_physics: Object) -> float:
	if abs(hit_pos) <= 0.8:
		return speed
	return speed * velocity_rules.apply_dampened_multiplier(ball_physics, speed, EDGE_HIT_BOOST)
