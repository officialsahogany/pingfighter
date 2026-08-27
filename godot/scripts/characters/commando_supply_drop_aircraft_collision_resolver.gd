extends RefCounted


func get_player_paddle_rect(context: Dictionary, default_hitbox_padding: float) -> Rect2:
	if context.has("player_paddle_rect"):
		return _get_rect2(context.get("player_paddle_rect", Rect2()), Rect2())
	var player_pos: Vector2 = _get_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(
		context.get("player_paddle_size", Vector2.ZERO),
		Vector2(
			float(context.get("paddle_width", 0.0)),
			float(context.get("paddle_height", 0.0))
		)
	)
	if player_size.x <= 0.0 or player_size.y <= 0.0:
		return Rect2()
	var hitbox_padding: float = float(context.get("hitbox_padding", default_hitbox_padding))
	var player_rect := Rect2(
		player_pos.x - hitbox_padding,
		player_pos.y - hitbox_padding,
		player_size.x + hitbox_padding * 2.0,
		player_size.y + hitbox_padding * 2.0
	)
	if bool(context.get("dash_acceleration_active", false)):
		var width_bonus: float = max(0.0, float(context.get("dash_acceleration_width_bonus", 0.0)))
		var height_bonus: float = max(0.0, float(context.get("dash_acceleration_height_bonus", 0.0)))
		player_rect.position.x -= width_bonus * 0.5
		player_rect.size.x += width_bonus
		player_rect.position.y -= height_bonus * 0.5
		player_rect.size.y += height_bonus
	return player_rect


func resolve_obstacle(
	aircraft_rect: Rect2,
	context: Dictionary,
	default_hitbox_padding: float
) -> Dictionary:
	var player_rect: Rect2 = get_player_paddle_rect(context, default_hitbox_padding)
	if player_rect.size.x > 0.0 and player_rect.size.y > 0.0 and aircraft_rect.intersects(player_rect):
		return {
			"source": "player_paddle",
			"impact_pos": aircraft_rect.get_center().lerp(player_rect.get_center(), 0.5),
		}
	var walls_value: Variant = context.get("brick_walls", [])
	if not (walls_value is Array):
		return {}
	var walls: Array = walls_value
	for i in range(walls.size()):
		var wall_value: Variant = walls[i]
		var wall_rect := Rect2()
		if wall_value is Dictionary:
			wall_rect = _get_rect2((wall_value as Dictionary).get("rect", Rect2()), Rect2())
		elif wall_value is Rect2:
			wall_rect = wall_value
		if wall_rect.size.x <= 0.0 or wall_rect.size.y <= 0.0:
			continue
		if not wall_rect.intersects(aircraft_rect):
			continue
		return {
			"source": "brick_wall",
			"wall_index": i,
			"impact_pos": aircraft_rect.get_center().lerp(wall_rect.get_center(), 0.5),
		}
	return {}


func ball_path_hits(
	aircraft_rect: Rect2,
	from_pos: Vector2,
	to_pos: Vector2,
	ball_radius: float
) -> bool:
	var grown_rect: Rect2 = aircraft_rect.grow(max(0.0, ball_radius))
	if grown_rect.has_point(from_pos) or grown_rect.has_point(to_pos):
		return true
	var movement: Vector2 = to_pos - from_pos
	if movement.length_squared() <= 0.001:
		return false
	var top_left := grown_rect.position
	var top_right := Vector2(grown_rect.end.x, grown_rect.position.y)
	var bottom_right := grown_rect.end
	var bottom_left := Vector2(grown_rect.position.x, grown_rect.end.y)
	var edges := [
		[top_left, top_right],
		[top_right, bottom_right],
		[bottom_right, bottom_left],
		[bottom_left, top_left],
	]
	for edge in edges:
		var intersection: Variant = Geometry2D.segment_intersects_segment(from_pos, to_pos, edge[0], edge[1])
		if intersection != null:
			return true
	return false


func reflect_aircraft_hit_velocity(ball_vel: Vector2, vertical_damping: float) -> Vector2:
	var reflected := ball_vel
	if absf(reflected.y) <= 0.001:
		reflected.y = 4.0
	else:
		reflected.y *= -max(0.0, vertical_damping)
	return reflected


func resolve_crash_ball_impulse(
	ball_pos: Vector2,
	ball_vel: Vector2,
	center: Vector2,
	radius: float,
	power: float,
	speed_ceiling: float,
	minimum_up_bias: float
) -> Dictionary:
	var safe_radius: float = max(1.0, radius)
	var to_ball: Vector2 = ball_pos - center
	var distance: float = to_ball.length()
	if distance > safe_radius:
		return {}
	var falloff: float = 1.0 - distance / safe_radius
	var direction: Vector2 = to_ball / distance if distance > 0.001 else Vector2(0.0, -1.0)
	var safe_up_bias: float = max(0.0, minimum_up_bias)
	if direction.y > -safe_up_bias:
		direction.y = -safe_up_bias
		direction = direction.normalized()
	var new_velocity: Vector2 = ball_vel + direction * (max(0.0, power) * falloff)
	var ceiling: float = max(ball_vel.length(), max(0.0, speed_ceiling))
	if new_velocity.length() > ceiling:
		new_velocity = new_velocity.normalized() * ceiling
	return {
		"affected": true,
		"ball_vel": new_velocity,
		"distance": distance,
		"falloff": falloff,
	}


func resolve_player_blast_knockback(
	player_rect: Rect2,
	center: Vector2,
	radius: float,
	fallback_direction: float,
	velocity: float
) -> Dictionary:
	if player_rect.size.x <= 0.0 or player_rect.size.y <= 0.0:
		return {}
	var closest := Vector2(
		clamp(center.x, player_rect.position.x, player_rect.end.x),
		clamp(center.y, player_rect.position.y, player_rect.end.y)
	)
	var distance: float = closest.distance_to(center)
	if distance > max(0.0, radius):
		return {}
	var dx: float = player_rect.get_center().x - center.x
	var direction: float = signf(dx)
	if absf(dx) < 1.0:
		direction = signf(fallback_direction)
		if is_zero_approx(direction):
			direction = 1.0
	return {
		"affected": true,
		"velocity": direction * max(0.0, velocity),
		"direction": direction,
		"distance": distance,
	}


func _get_rect2(value: Variant, fallback: Rect2) -> Rect2:
	return value if value is Rect2 else fallback


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
