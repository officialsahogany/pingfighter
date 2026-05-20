extends RefCounted

const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func get_spawn_pos(
	config: Dictionary,
	field_width: float,
	field_height: float,
	drone_size: Vector2
) -> Vector2:
	var fallback_player_pos := Vector2(field_width * 0.5, field_height - 70.0)
	var player_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(config.get("player_pos", fallback_player_pos), fallback_player_pos)
	var paddle_width: float = max(1.0, float(config.get("paddle_width", 155.0)))
	return Vector2(
		player_pos.x + paddle_width * 0.5,
		player_pos.y - drone_size.y * 0.5 - 6.0
	)


static func get_player_lock_pos(
	config: Dictionary,
	field_width: float,
	field_height: float
) -> Vector2:
	var fallback_player_pos := Vector2(field_width * 0.5, field_height - 70.0)
	var player_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(config.get("player_pos", fallback_player_pos), fallback_player_pos)
	var paddle_width: float = max(1.0, float(config.get("paddle_width", 155.0)))
	var paddle_height: float = max(1.0, float(config.get("paddle_height", 50.0)))
	return player_pos + Vector2(paddle_width * 0.5, paddle_height * 0.5)


static func get_rect(projectile: Dictionary, default_size: Vector2) -> Rect2:
	var pos: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var size: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("size", default_size), default_size)
	return Rect2(pos - size * 0.5, size)


static func hits_ball(projectile: Dictionary, context: Dictionary, default_size: Vector2) -> bool:
	if not bool(context.get("ball_active", true)):
		return false
	var ball_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var ball_size: float = max(1.0, float(context.get("ball_size", 28.6)))
	var ball_rect := Rect2(ball_pos - Vector2(ball_size, ball_size) * 0.5, Vector2(ball_size, ball_size))
	return get_rect(projectile, default_size).intersects(ball_rect)


static func hits_boss_rect(projectile: Dictionary, boss_rect: Rect2, default_size: Vector2) -> bool:
	return get_rect(projectile, default_size).intersects(boss_rect)


static func hits_top_wall(projectile: Dictionary, default_size: Vector2) -> bool:
	return get_rect(projectile, default_size).position.y <= 0.0
