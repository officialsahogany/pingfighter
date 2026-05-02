extends RefCounted

const PaddleBounceVelocityResolver := preload("res://scripts/ball/paddle_bounce_velocity_resolver.gd")

var velocity_resolver: Object = PaddleBounceVelocityResolver.new()


func get_initial_speed(ball_velocity: Vector2) -> float:
	return velocity_resolver.get_initial_speed(ball_velocity)


func resolve_velocity(
	ball_velocity: Vector2,
	hit_pos: float,
	is_player: bool,
	incoming_dx: float,
	outgoing_direction: float,
	speed: float,
	angle_rad: float,
	drive_activated: bool,
	accel_scale: float,
	vertical_bounce_count: int,
	ball_physics: Object,
	drive_bounce_state: Object,
	current_drive_speed_increase: float,
	current_spin_strength: float,
	min_ball_speed: float,
	max_ball_speed: float
) -> Dictionary:
	return velocity_resolver.resolve_velocity(
		ball_velocity,
		hit_pos,
		is_player,
		incoming_dx,
		outgoing_direction,
		speed,
		angle_rad,
		drive_activated,
		accel_scale,
		vertical_bounce_count,
		ball_physics,
		drive_bounce_state,
		current_drive_speed_increase,
		current_spin_strength,
		min_ball_speed,
		max_ball_speed
	)
