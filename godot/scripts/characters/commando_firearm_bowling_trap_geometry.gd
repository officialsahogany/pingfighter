extends RefCounted

const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func get_install_pos(
	config: Dictionary,
	field_width: float,
	field_height: float,
	trap_width: float,
	trap_height: float,
	min_field_y_ratio: float
) -> Vector2:
	var fallback_player_pos := Vector2(field_width * 0.5, field_height - 70.0)
	var player_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(config.get("player_pos", fallback_player_pos), fallback_player_pos)
	var paddle_width: float = max(1.0, float(config.get("paddle_width", 155.0)))
	var paddle_height: float = max(1.0, float(config.get("paddle_height", 50.0)))
	var trap_y: float = player_pos.y + paddle_height + 5.0
	var min_y: float = field_height * min_field_y_ratio
	return Vector2(
		clamp(player_pos.x + paddle_width * 0.5, trap_width * 0.5, field_width - trap_width * 0.5),
		clamp(max(trap_y, min_y), min_y, field_height - trap_height * 0.5)
	)


static func soften_guard_ball(ball_vel: Vector2, restore_speed: float) -> Vector2:
	var speed: float = max(1.0, restore_speed)
	if ball_vel.length() <= 0.001:
		return Vector2(0.0, speed)
	return ball_vel.normalized() * speed


static func get_guard_knockback_velocity(
	boss_center: Vector2,
	context: Dictionary,
	field_width: float,
	knockback_power: float
) -> float:
	var field_center_x: float = float(context.get("width", field_width)) * 0.5
	var direction: float = 1.0 if boss_center.x < field_center_x else -1.0
	if is_equal_approx(boss_center.x, field_center_x):
		direction = sign(float(context.get("boss_vel", 0.0)))
		if is_zero_approx(direction):
			direction = 1.0
	return direction * knockback_power


static func get_launch_direction(shot_id: int) -> int:
	var roll: int = shot_id % 5
	if roll == 0:
		return -1
	if roll == 4:
		return 1
	return 0


static func hits_ball(
	trap: Dictionary,
	context: Dictionary,
	trap_height: float,
	capture_height: float,
	default_trap_width: float
) -> bool:
	var ball_vel: Vector2 = CommandoFirearmValueUtils.get_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	if ball_vel.y <= 0.0:
		return false
	var ball_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var ball_size: float = max(1.0, float(context.get("ball_size", 28.6)))
	var trap_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(trap.get("pos", Vector2.ZERO), Vector2.ZERO)
	var trap_width: float = max(1.0, float(trap.get("width", default_trap_width)))
	var trap_rect := Rect2(
		trap_pos - Vector2(trap_width * 0.5, trap_height * 0.5),
		Vector2(trap_width, capture_height)
	)
	var ball_rect := Rect2(
		ball_pos - Vector2(ball_size, ball_size) * 0.5,
		Vector2(ball_size, ball_size)
	)
	return trap_rect.intersects(ball_rect)
