extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")


func apply(
	post_hit_handler: Object,
	frame_state: Object,
	is_player: bool,
	ball_pos: Vector2,
	ball_vel: Vector2,
	hit_pos: float,
	paddle_w: float,
	power_activated: bool,
	was_power_smashing: bool,
	drive_activated: bool,
	frame: Dictionary,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	if post_hit_handler == null:
		return _build_result(ball_pos, ball_vel, context)

	var post_hit_result: Dictionary = post_hit_handler.apply(
		is_player,
		ball_pos,
		ball_vel,
		hit_pos,
		paddle_w,
		power_activated,
		was_power_smashing,
		drive_activated,
		float(frame["ball_spin_strength"]),
		float(frame["drive_speed_increase"]),
		bool(frame["drive_ball_active"]),
		bool(frame["drive_hit_boss"]),
		float(frame["special_gauge"]),
		context,
		deps
	)
	if frame_state != null:
		frame_state.apply_post_hit_result(frame, post_hit_result)

	var next_ball_pos: Vector2 = _get_vector2(post_hit_result, "ball_pos", ball_pos)
	var next_ball_vel: Vector2 = _get_vector2(post_hit_result, "ball_vel", ball_vel)
	var player_speed: float = float(post_hit_result.get("player_speed", context.get("player_speed", 0.0)))
	var boss_vel: float = float(post_hit_result.get("boss_vel", context.get("boss_vel", 0.0)))
	return {
		"ball_pos": next_ball_pos,
		"ball_vel": next_ball_vel,
		"player_speed": player_speed,
		"boss_vel": boss_vel,
	}


func _build_result(ball_pos: Vector2, ball_vel: Vector2, context: Dictionary) -> Dictionary:
	return {
		"ball_pos": ball_pos,
		"ball_vel": ball_vel,
		"player_speed": float(context.get("player_speed", 0.0)),
		"boss_vel": float(context.get("boss_vel", 0.0)),
	}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)
