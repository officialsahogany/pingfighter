extends RefCounted


static func get_impulse_scale(progress: float) -> float:
	if progress < 0.18:
		return 1.0
	if progress < 0.72:
		var middle_progress: float = (progress - 0.18) / 0.54
		return 1.0 - middle_progress * 0.22
	var fade_progress: float = (progress - 0.72) / 0.28
	return 0.78 * (1.0 - clampf(fade_progress, 0.0, 1.0))


static func apply_player_pull(ball_vel: Vector2, ball_pos: Vector2, context: Dictionary) -> Vector2:
	var player_pos: Vector2 = _get_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	var player_center: Vector2 = player_pos + player_size * 0.5
	var delta: Vector2 = player_center - ball_pos
	var distance: float = delta.length()
	if distance > 10.0:
		var influence: float = 0.08 / distance
		ball_vel += delta * influence * 0.01
	return ball_vel


static func apply_original_speed_cap(scene: Dictionary, ball_vel: Vector2, effective_speed_cap: float) -> Vector2:
	var impact_boost: float = max(1.0, float(scene.get("ball_impact_boost", 1.0)))
	var effective_speed: float = ball_vel.length() * impact_boost
	if effective_speed > effective_speed_cap and effective_speed > 0.001:
		ball_vel = ball_vel.normalized() * (effective_speed_cap / impact_boost)

	var max_speed: float = float(scene.get("max_ball_speed", effective_speed_cap))
	scene["max_ball_speed"] = min(max_speed, effective_speed_cap) if max_speed > 0.0 else effective_speed_cap

	var impact_cap: float = float(scene.get("impact_boost_max_ball_speed", effective_speed_cap))
	scene["impact_boost_max_ball_speed"] = min(impact_cap, effective_speed_cap) if impact_cap > 0.0 else effective_speed_cap

	return ball_vel


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
