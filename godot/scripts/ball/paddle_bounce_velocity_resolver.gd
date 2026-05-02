extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")
const PaddleBounceContactShapeResolver := preload("res://scripts/ball/paddle_bounce_contact_shape_resolver.gd")
const PaddleBounceSpeedMultiplierResolver := preload("res://scripts/ball/paddle_bounce_speed_multiplier_resolver.gd")
const PaddleBounceVerticalStallGuard := preload("res://scripts/ball/paddle_bounce_vertical_stall_guard.gd")
const PaddleBounceVelocityRules := preload("res://scripts/ball/paddle_bounce_velocity_rules.gd")

const PADDLE_HIT_BOOST: float = 1.0
const CENTER_HIT_THRESHOLD: float = 0.05
const MID_HIT_THRESHOLD: float = 0.15
const NORMAL_CURVE_CHANCE: float = 0.30

var contact_shape_resolver: Object = PaddleBounceContactShapeResolver.new()
var speed_multiplier_resolver: Object = PaddleBounceSpeedMultiplierResolver.new()
var vertical_stall_guard: Object = PaddleBounceVerticalStallGuard.new()
var velocity_rules: Object = PaddleBounceVelocityRules.new()


func get_initial_speed(ball_velocity: Vector2) -> float:
	return ball_velocity.length() * PADDLE_HIT_BOOST


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
	var drive_speed_increase: float = current_drive_speed_increase
	var spin_strength: float = current_spin_strength

	speed = speed_multiplier_resolver.apply(speed, hit_pos, is_player, drive_activated, accel_scale, ball_physics)
	var bounce_vector: Vector2 = Vector2(0.0, outgoing_direction).rotated(angle_rad)

	var contact_shape_result: Dictionary = contact_shape_resolver.apply(
		speed,
		bounce_vector,
		hit_pos,
		incoming_dx,
		is_player,
		drive_activated,
		accel_scale,
		ball_physics,
		drive_bounce_state,
		drive_speed_increase,
		spin_strength
	)
	speed = float(contact_shape_result.get("speed", speed))
	bounce_vector = _get_vector2(contact_shape_result, "bounce_vector", bounce_vector)
	drive_speed_increase = float(contact_shape_result.get("drive_speed_increase", drive_speed_increase))
	spin_strength = float(contact_shape_result.get("ball_spin_strength", spin_strength))

	if abs(hit_pos) >= CENTER_HIT_THRESHOLD and abs(hit_pos) < MID_HIT_THRESHOLD:
		bounce_vector = bounce_vector.rotated(deg_to_rad(randf_range(-35.0, 35.0)))
	elif not drive_activated and randf() < NORMAL_CURVE_CHANCE:
		bounce_vector = bounce_vector.rotated(deg_to_rad(randf_range(-20.0, 20.0)))

	bounce_vector = velocity_rules.ensure_min_vertical_component(ball_physics, bounce_vector, outgoing_direction)
	speed = clamp(speed, min_ball_speed, max_ball_speed)
	ball_velocity = bounce_vector.normalized() * speed

	var stall_result: Dictionary = vertical_stall_guard.apply(ball_velocity, bounce_vector, speed, vertical_bounce_count)
	var guarded_ball_velocity: Variant = stall_result.get("ball_vel", ball_velocity)
	if guarded_ball_velocity is Vector2:
		ball_velocity = guarded_ball_velocity
	vertical_bounce_count = int(stall_result.get("vertical_bounce_count", vertical_bounce_count))

	return {
		"ball_vel": ball_velocity,
		"vertical_bounce_count": vertical_bounce_count,
		"drive_speed_increase": drive_speed_increase,
		"ball_spin_strength": spin_strength,
	}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)
