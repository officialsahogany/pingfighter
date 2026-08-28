extends RefCounted

const PowerSmashHitVelocityResolver := preload("res://scripts/characters/smasher_power_smash_hit_velocity_resolver.gd")
const PowerSmashMotionResolver := preload("res://scripts/characters/smasher_power_smash_motion_resolver.gd")

var hit_velocity_resolver: Object = PowerSmashHitVelocityResolver.new()
var motion_resolver: Object = PowerSmashMotionResolver.new()


func apply_hit_velocity(
	runtime_state: Object,
	ball_velocity: Vector2,
	ball_position: Vector2,
	player_position: Vector2,
	paddle_width: float,
	base_speed: float,
	ball_physics: Object,
	combo_min_count: int,
	launch_speed_multiplier: float = 1.0,
	smash_speed_amp: float = 0.0
) -> Vector2:
	return hit_velocity_resolver.apply(
		runtime_state,
		ball_velocity,
		ball_position,
		player_position,
		paddle_width,
		base_speed,
		ball_physics,
		combo_min_count,
		launch_speed_multiplier,
		smash_speed_amp
	)


func apply_motion(
	runtime_state: Object,
	ball_velocity: Vector2,
	fps_scale: float,
	gravity_effect: float,
	boost_duration: float,
	initial_boost_decay_reduction: float = 0.0
) -> Vector2:
	return motion_resolver.apply(
		runtime_state,
		ball_velocity,
		fps_scale,
		gravity_effect,
		boost_duration,
		initial_boost_decay_reduction
	)
