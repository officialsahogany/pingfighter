extends RefCounted


func apply(
	ball_pos: Vector2,
	hit_pos: float,
	power_activated: bool,
	drive_activated: bool,
	special_gauge: float,
	context: Dictionary,
	deps: Dictionary,
	event_router: Object
) -> Dictionary:
	var next_ball_pos: Vector2 = _snap_player_hit_ball_pos(ball_pos, context)
	var player_speed: float = float(context.get("player_speed", 0.0))
	var boss_vel: float = float(context.get("boss_vel", 0.0))
	var power_state: Object = deps.get("power_state", null)
	if power_activated and power_state != null:
		power_state.lock_freeze_pose(next_ball_pos)
		next_ball_pos = power_state.get_freeze_ball_pos()
		player_speed = 0.0
		boss_vel = 0.0

	var updated_gauge: float = special_gauge
	if event_router != null:
		updated_gauge = event_router.register_player_hit(
			next_ball_pos,
			hit_pos,
			drive_activated,
			power_activated,
			special_gauge,
			context,
			deps
		)
	return {
		"ball_pos": next_ball_pos,
		"special_gauge": updated_gauge,
		"player_speed": player_speed,
		"boss_vel": boss_vel,
	}


func _snap_player_hit_ball_pos(ball_pos: Vector2, context: Dictionary) -> Vector2:
	ball_pos.y = float(context.get("player_y", ball_pos.y)) - float(context.get("ball_size", 0.0))
	return ball_pos
