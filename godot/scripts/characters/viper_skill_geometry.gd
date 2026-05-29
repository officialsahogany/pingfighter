extends RefCounted


static func segment_intersects_rect(start_pos: Vector2, end_pos: Vector2, rect: Rect2) -> bool:
	if rect.has_point(start_pos) or rect.has_point(end_pos):
		return true
	var top_left: Vector2 = rect.position
	var top_right := Vector2(rect.position.x + rect.size.x, rect.position.y)
	var bottom_right := rect.position + rect.size
	var bottom_left := Vector2(rect.position.x, rect.position.y + rect.size.y)
	return (
		_segments_intersect(start_pos, end_pos, top_left, top_right)
		or _segments_intersect(start_pos, end_pos, top_right, bottom_right)
		or _segments_intersect(start_pos, end_pos, bottom_right, bottom_left)
		or _segments_intersect(start_pos, end_pos, bottom_left, top_left)
	)


static func blade_rect(pos: Vector2, width: float, dark_mode: bool, normal_height: float, dark_height: float) -> Rect2:
	var hit_height: float = dark_height if dark_mode else normal_height
	return Rect2(Vector2(pos.x - width * 0.5, pos.y - hit_height), Vector2(width, hit_height))


static func ball_rect(scene: Dictionary, context: Dictionary) -> Rect2:
	var resolved_ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", context.get("ball_pos", Vector2.ZERO)), Vector2.ZERO)
	var ball_size: float = max(1.0, float(context.get("ball_size", scene.get("ball_size", 28.6))))
	return Rect2(resolved_ball_pos - Vector2(ball_size, ball_size) * 0.5, Vector2(ball_size, ball_size))


static func center_to_player_pos(center: Vector2, config: Dictionary, player_paddle_size: Vector2) -> Vector2:
	var play_left: float = float(config.get("play_left", 0.0))
	var play_right: float = float(config.get("play_right", config.get("width", 760.0)))
	var height: float = float(config.get("height", 750.0))
	return Vector2(
		clamp(center.x - player_paddle_size.x * 0.5, play_left, max(play_left, play_right - player_paddle_size.x)),
		clamp(center.y - player_paddle_size.y * 0.5, 0.0, max(0.0, height - player_paddle_size.y))
	)


static func player_center(player_pos: Vector2, config: Dictionary) -> Vector2:
	return player_pos + get_paddle_size(config) * 0.5


static func get_paddle_size(config: Dictionary) -> Vector2:
	return Vector2(
		max(1.0, float(config.get("paddle_width", 155.0))),
		max(1.0, float(config.get("paddle_height", 50.0)))
	)


static func get_ball_pos(config: Dictionary) -> Vector2:
	return _get_vector2(config.get("ball_pos", Vector2.ZERO), Vector2.ZERO)


static func nerve_strike_target_pos(config: Dictionary, target_y_offset: float) -> Vector2:
	var target_center: Vector2 = nerve_strike_target_center(config, target_y_offset)
	var player_paddle_size: Vector2 = get_paddle_size(config)
	# Python parity: Venom Edge snaps PLAYER.centerx to BOSS.centerx even near
	# the walls. Do not clamp here, or edge-position bosses leave Viper beside
	# the boss instead of directly behind it.
	return target_center - player_paddle_size * 0.5


static func nerve_strike_target_center(config: Dictionary, target_y_offset: float) -> Vector2:
	var boss_center: Vector2 = nerve_strike_boss_center(config)
	var visual_offset_y: float = float(config.get("boss_visual_center_y_offset", 0.0))
	return Vector2(boss_center.x, boss_center.y + visual_offset_y + target_y_offset)


static func nerve_strike_boss_center(config: Dictionary) -> Vector2:
	var boss_pos: Vector2 = _get_vector2(config.get("boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
	var boss_width: float = max(1.0, float(config.get("boss_paddle_width", config.get("boss_width", 100.0))))
	var boss_height: float = max(1.0, float(config.get("boss_hitbox_height", config.get("boss_paddle_height", 50.0))))
	return boss_pos + Vector2(boss_width * 0.5, boss_height * 0.5)


static func nerve_strike_return_target_pos(config: Dictionary) -> Vector2:
	var player_paddle_size: Vector2 = get_paddle_size(config)
	var fallback_ball_pos := Vector2(float(config.get("width", 760.0)) * 0.5, 0.0)
	var current_ball_pos: Vector2 = _get_vector2(config.get("ball_pos", fallback_ball_pos), fallback_ball_pos)
	var target := Vector2(current_ball_pos.x - player_paddle_size.x * 0.5, player_floor_y(config))
	return clamp_player_pos(target, float(config.get("play_left", 0.0)), float(config.get("play_right", config.get("width", 760.0))), player_paddle_size.x)


static func player_floor_y(config: Dictionary) -> float:
	return float(config.get("player_floor_y", float(config.get("height", 750.0)) - get_paddle_size(config).y))


static func clamp_player_pos(pos: Vector2, play_left: float, play_right: float, paddle_width: float) -> Vector2:
	var min_x: float = play_left
	var max_x: float = play_right - max(1.0, paddle_width)
	if max_x < min_x:
		return Vector2(play_left, pos.y)
	return Vector2(clamp(pos.x, min_x, max_x), pos.y)


static func core_flip_velocity_to_target(
	speed: float,
	kick_dir: int,
	ball_pos: Vector2,
	width: float,
	target_x: float,
	target_y: float
) -> Vector2:
	var mirrored_target_x: float = (2.0 * width) - target_x if kick_dir > 0 else -target_x
	var delta := Vector2(mirrored_target_x - ball_pos.x, target_y - ball_pos.y)
	if delta.length() <= 0.000001:
		return Vector2.ZERO
	return delta.normalized() * speed


static func aimed_kick_launch_angle(
	kick_dir: int,
	ball_pos: Vector2,
	boss_pos: Vector2,
	aim_level: int,
	base_bias: float,
	min_angle: float
) -> float:
	var bias: float = base_bias + (1.0 - base_bias) * min(float(aim_level) * 0.09, 0.90)
	var boss_dx: float = boss_pos.x - ball_pos.x
	var away_dir: int = -1 if boss_dx > 0.0 else (1 if boss_dx < 0.0 else kick_dir)
	var raw_angle: float = randf_range(-55.0, 55.0)
	var avoidance: float = float(away_dir) * randf_range(25.0, 50.0)
	var final_angle: float = raw_angle * (1.0 - bias) + avoidance * bias
	if kick_dir > 0 and final_angle < 0.0:
		final_angle = max(final_angle, -min_angle * 0.5)
	elif kick_dir < 0 and final_angle > 0.0:
		final_angle = min(final_angle, min_angle * 0.5)
	if abs(final_angle) < min_angle:
		final_angle = min_angle * (1.0 if final_angle >= 0.0 else -1.0)
	return clamp(final_angle, -60.0, 60.0)


static func limit_effective_velocity(velocity: Vector2, impact_boost: float, max_effective_speed: float) -> Vector2:
	if max_effective_speed <= 0.0:
		return velocity
	var speed: float = velocity.length()
	if speed <= 0.0:
		return velocity
	var safe_boost: float = max(0.001, impact_boost)
	var effective_speed: float = speed * safe_boost
	if effective_speed <= max_effective_speed:
		return velocity
	return velocity.normalized() * (max_effective_speed / safe_boost)


static func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var r: Vector2 = b - a
	var s: Vector2 = d - c
	var denom: float = r.cross(s)
	var cma: Vector2 = c - a
	if abs(denom) <= 0.000001:
		if abs(cma.cross(r)) > 0.000001:
			return false
		var rr: float = r.dot(r)
		if rr <= 0.000001:
			return a.distance_to(c) <= 0.000001
		var t0: float = cma.dot(r) / rr
		var t1: float = t0 + s.dot(r) / rr
		return max(min(t0, t1), 0.0) <= min(max(t0, t1), 1.0)
	var t: float = cma.cross(s) / denom
	var u: float = cma.cross(r) / denom
	return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
