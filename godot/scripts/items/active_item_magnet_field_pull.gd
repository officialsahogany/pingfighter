extends RefCounted

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const MAGNET_PULL_RADIUS := 400.0
const MAGNET_PULL_STRENGTH := 0.125


func apply_ball_pull(active: bool, fps_scale: float, context: Dictionary) -> Dictionary:
	if not active or str(context.get("last_hit_by", "")) != "boss":
		return {}

	var ball_vel: Vector2 = _get_vector2(context, "ball_vel", Vector2.ZERO)
	var current_speed: float = ball_vel.length()
	if current_speed < 0.5:
		return {}

	var ball_center: Vector2 = _get_vector2(context, "ball_pos", Vector2.ZERO)
	var player_center: Vector2 = _get_player_center_from_context(context)
	var delta_to_player: Vector2 = player_center - ball_center
	var distance: float = delta_to_player.length()
	if distance > MAGNET_PULL_RADIUS or distance < 5.0:
		return {}

	var pull_ratio: float = pow(1.0 - distance / MAGNET_PULL_RADIUS, 0.7)
	var pull_dir: Vector2 = delta_to_player / distance
	var blend: float = clamp(MAGNET_PULL_STRENGTH * pull_ratio * max(0.0, fps_scale), 0.0, 0.95)
	var next_vel: Vector2 = ball_vel + pull_dir * current_speed * blend
	var next_speed: float = next_vel.length()
	if next_speed <= 0.1:
		return {}

	return {
		"ball_vel": next_vel / next_speed * current_speed,
		"magnet_field_pull_applied": true,
	}


func _get_player_center_from_context(context: Dictionary) -> Vector2:
	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT))
	var player_size: Vector2 = _get_vector2(context, "player_paddle_size", Vector2(PLAYER_BASE_PADDLE_WIDTH, PLAYER_BASE_PADDLE_HEIGHT))
	if player_size.length() <= 0.01:
		player_size = Vector2(PLAYER_BASE_PADDLE_WIDTH, PLAYER_BASE_PADDLE_HEIGHT)
	return player_pos + player_size * 0.5


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
