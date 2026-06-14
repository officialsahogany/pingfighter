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

	var minimum_speed: float = float(context.get("min_ball_speed", 3.0))
	if physics != null and physics.has_method("get_minimum_rally_speed"):
		minimum_speed = max(minimum_speed, float(physics.get_minimum_rally_speed()))

	var weather: Object = deps.get("weather_event_state", null)
	var max_ball_speed: float = float(context.get("max_ball_speed", 20.0))
	var fire_weather_active: bool = _is_fire_weather_active(weather)
	if fire_weather_active:
		max_ball_speed = float(context.get("fire_weather_max_ball_speed", 35.0))
	if is_player:
		max_ball_speed = max(max_ball_speed, _get_magnum_grip_pending_speed_cap(deps))
	if fire_weather_active:
		max_ball_speed = min(max_ball_speed, float(context.get("fire_weather_max_ball_speed", 35.0)))
	if _is_speed_limit_disabled(context) and not fire_weather_active:
		max_ball_speed = INF

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
		minimum_speed,
		max_ball_speed
	)
	if frame_state != null:
		frame_state.apply_bounce_result(frame, bounce_result)
	var next_ball_vel: Vector2 = _get_vector2(bounce_result, "ball_vel", ball_vel)
	if weather != null and weather.has_method("apply_fire_hit_speed"):
		next_ball_vel = weather.apply_fire_hit_speed(next_ball_vel)
	if fire_weather_active:
		next_ball_vel = _cap_velocity(next_ball_vel, max_ball_speed)
	return {
		"ball_vel": next_ball_vel,
	}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)


func _get_magnum_grip_pending_speed_cap(deps: Dictionary) -> float:
	var magnum_state: Object = deps.get("smasher_magnum_grip_state", null)
	if magnum_state == null or not magnum_state.has_method("get_pending_release_hit_speed_cap"):
		return 0.0
	return float(magnum_state.get_pending_release_hit_speed_cap())


func _cap_velocity(velocity: Vector2, max_speed: float) -> Vector2:
	if max_speed <= 0.0 or velocity.length() <= max_speed:
		return velocity
	return velocity.normalized() * max_speed


func _is_fire_weather_active(weather: Object) -> bool:
	return weather != null and weather.has_method("is_fire_active") and bool(weather.is_fire_active())


func _is_speed_limit_disabled(context: Dictionary) -> bool:
	return (
		bool(context.get("speed_limit_disabled", false))
		or bool(context.get("commando_suicide_drone_ball_boost_active", false))
		or bool(context.get("lingpet_wild_roar_ball_boost_active", false))
	)
