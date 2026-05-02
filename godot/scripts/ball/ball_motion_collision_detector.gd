extends RefCounted

const EVENT_WALL := "wall"
const EVENT_PLAYER_PADDLE := "player_paddle"
const EVENT_BOSS_PADDLE := "boss_paddle"


func check_wall(ball_pos: Vector2, ball_size: float, width: float) -> Dictionary:
	if ball_pos.x - ball_size * 0.5 <= 0.0:
		ball_pos.x = ball_size * 0.5
		return {
			"event": EVENT_WALL,
			"side": "left",
			"impact_pos": Vector2(ball_pos.x - ball_size * 0.5, ball_pos.y),
			"ball_pos": ball_pos,
		}
	if ball_pos.x + ball_size * 0.5 >= width:
		ball_pos.x = width - ball_size * 0.5
		return {
			"event": EVENT_WALL,
			"side": "right",
			"impact_pos": Vector2(ball_pos.x + ball_size * 0.5, ball_pos.y),
			"ball_pos": ball_pos,
		}
	return {}


func check_paddles(ball_pos: Vector2, ball_vel: Vector2, ball_size: float, context: Dictionary) -> Dictionary:
	var hitbox_padding: float = float(context.get("hitbox_padding", 5.0))
	var ball_rect: Rect2 = Rect2(ball_pos.x - ball_size * 0.5, ball_pos.y - ball_size * 0.5, ball_size, ball_size)

	if ball_vel.y > 0.0:
		if float(context.get("player_collision_cooldown", 0.0)) > 0.0:
			return {}
		var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
		var player_paddle_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2.ZERO), Vector2.ZERO)
		var player_rect: Rect2 = Rect2(
			player_pos.x - hitbox_padding,
			player_pos.y - hitbox_padding,
			player_paddle_size.x + hitbox_padding * 2.0,
			player_paddle_size.y + hitbox_padding * 2.0
		)
		if player_rect.intersects(ball_rect):
			return {
				"event": EVENT_PLAYER_PADDLE,
				"paddle_x": player_pos.x,
				"paddle_w": player_paddle_size.x,
				"is_player": true,
			}

	if ball_vel.y < 0.0:
		if float(context.get("boss_collision_cooldown", 0.0)) > 0.0:
			return {}
		var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
		var boss_paddle_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2.ZERO), Vector2.ZERO)
		var boss_rect: Rect2 = Rect2(
			boss_pos.x - hitbox_padding,
			boss_pos.y - hitbox_padding,
			boss_paddle_size.x + hitbox_padding * 2.0,
			boss_paddle_size.y + hitbox_padding * 2.0
		)
		if boss_rect.intersects(ball_rect):
			return {
				"event": EVENT_BOSS_PADDLE,
				"paddle_x": boss_pos.x,
				"paddle_w": boss_paddle_size.x,
				"is_player": false,
			}

	return {}


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
