extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")


func apply(
	paddle_bounce_state: Object,
	frame_state: Object,
	ball_vel: Vector2,
	hit_pos: float,
	is_player: bool,
	incoming_dx: float,
	outgoing_direction: float,
	speed: float,
	angle_rad: float,
	drive_activated: bool,
	frame: Dictionary,
	physics: Object,
	deps: Dictionary,
	context: Dictionary
) -> Dictionary:
	if paddle_bounce_state == null:
		return {"ball_vel": ball_vel}

	var bounce_result: Dictionary = paddle_bounce_state.resolve_velocity(
		ball_vel,
		hit_pos,
		is_player,
		incoming_dx,
		outgoing_direction,
		speed,
		angle_rad,
		drive_activated,
		float(frame["accel_scale"]),
		int(frame["vertical_bounce_count"]),
		physics,
		deps.get("drive_bounce_state", null),
		float(frame["drive_speed_increase"]),
		float(frame["ball_spin_strength"]),
		float(context.get("min_ball_speed", 3.0)),
		float(context.get("max_ball_speed", 60.0))
	)
	if frame_state != null:
		frame_state.apply_bounce_result(frame, bounce_result)
	return {
		"ball_vel": _get_vector2(bounce_result, "ball_vel", ball_vel),
	}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)
