extends RefCounted


func apply(
	ball_pos: Vector2,
	ball_vel: Vector2,
	ball_spin_strength: float,
	drive_speed_increase: float,
	drive_ball_active: bool,
	drive_hit_boss: bool,
	was_power_smashing: bool,
	context: Dictionary,
	deps: Dictionary,
	event_router: Object
) -> Dictionary:
	var next_ball_pos: Vector2 = _snap_boss_hit_ball_pos(ball_pos, context)
	var next_ball_vel: Vector2 = ball_vel
	var next_spin_strength: float = ball_spin_strength
	var next_drive_speed_increase: float = drive_speed_increase
	var next_drive_hit_boss: bool = drive_hit_boss
	var power_state: Object = deps.get("power_state", null)

	if event_router != null:
		var counter_result: Dictionary = event_router.apply_drive_boss_counter(
			next_ball_vel,
			next_spin_strength,
			next_drive_speed_increase,
			drive_ball_active,
			next_drive_hit_boss,
			deps
		)
		next_ball_vel = _get_vector2(counter_result, "ball_vel", next_ball_vel)
		next_spin_strength = float(counter_result.get("ball_spin_strength", next_spin_strength))
		next_drive_speed_increase = float(counter_result.get("drive_speed_increase", next_drive_speed_increase))
		next_drive_hit_boss = bool(counter_result.get("drive_hit_boss", next_drive_hit_boss))
		if was_power_smashing:
			next_ball_vel = event_router.end_power_smashing_on_boss_counter(next_ball_vel, power_state, deps)
		event_router.trigger_boss_hit_anim(float(context.get("boss_vel", 0.0)), context, deps)

	return {
		"ball_pos": next_ball_pos,
		"ball_vel": next_ball_vel,
		"ball_spin_strength": next_spin_strength,
		"drive_speed_increase": next_drive_speed_increase,
		"drive_hit_boss": next_drive_hit_boss,
	}


func _snap_boss_hit_ball_pos(ball_pos: Vector2, context: Dictionary) -> Vector2:
	ball_pos.y = (
		float(context.get("boss_y", ball_pos.y))
		+ float(context.get("boss_hitbox_height", 0.0))
		+ float(context.get("ball_size", 0.0))
	)
	return ball_pos


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
