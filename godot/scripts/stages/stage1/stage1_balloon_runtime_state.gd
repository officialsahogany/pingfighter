extends RefCounted

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PADDLE_BOUNCE_MIN_SPEED := 5.0
const PADDLE_BOUNCE_MAX_SPEED := 7.4
const PADDLE_BOUNCE_DRAG := 0.965
const PADDLE_BOUNCE_SLOW_FRAMES := 42.0
const PADDLE_BOUNCE_COOLDOWN_FRAMES := 14.0

# Retains the live Stage 1 balloon collection and owns allocation-free frame
# motion plus the geometry/response math shared by all interaction routes.
# Its rare center-contact direction and ball-deflection choices intentionally
# use the global RNG to preserve the legacy event's consumption order.
var balloons: Array[Dictionary] = []
var play_left := 0.0
var play_right := FIELD_WIDTH
var play_height := FIELD_HEIGHT


func configure_bounds(left: float, right: float, height: float) -> void:
	play_left = left
	play_right = right
	play_height = height


func clear() -> void:
	balloons.clear()


func append_balloon(balloon: Dictionary) -> void:
	balloons.append(balloon)


func get_count() -> int:
	return balloons.size()


func is_empty() -> bool:
	return balloons.is_empty()


func get_balloon(index: int) -> Dictionary:
	return balloons[index]


func set_balloon(index: int, balloon: Dictionary) -> void:
	balloons[index] = balloon


func remove_balloon(index: int) -> Dictionary:
	var balloon: Dictionary = balloons[index]
	balloons.remove_at(index)
	return balloon


func get_snapshot() -> Array[Dictionary]:
	return balloons.duplicate(true)


func update_motion(fps_scale: float) -> void:
	for index in range(balloons.size()):
		var balloon: Dictionary = balloons[index]
		var pos: Vector2 = _get_vector2(balloon.get("pos", Vector2.ZERO), Vector2.ZERO)
		var vel: Vector2 = _get_vector2(balloon.get("vel", Vector2.ZERO), Vector2.ZERO)
		var radius: float = float(balloon.get("radius", 30.0))

		pos += vel * fps_scale
		var cooldown: float = max(0.0, float(balloon.get("paddle_bounce_cooldown", 0.0)) - fps_scale)
		var slow_timer: float = max(0.0, float(balloon.get("paddle_bounce_slow_timer", 0.0)) - fps_scale)
		if slow_timer > 0.0:
			vel *= pow(PADDLE_BOUNCE_DRAG, fps_scale)

		var bounce: float = float(balloon.get("bounce", 0.0)) + 0.2 * fps_scale
		pos.y += sin(bounce) * fps_scale
		var move_speed: float = vel.length()
		var spin_scale: float = clamp(move_speed / 3.2, 0.45, 1.45)
		var rotation: float = fposmod(
			float(balloon.get("rotation", 0.0)) + float(balloon.get("rotation_speed", 1.8)) * spin_scale * fps_scale,
			360.0
		)

		if pos.x - radius <= play_left:
			pos.x = play_left + radius
			vel.x = abs(vel.x)
		elif pos.x + radius >= play_right:
			pos.x = play_right - radius
			vel.x = -abs(vel.x)
		if pos.y - radius <= 0.0:
			pos.y = radius
			vel.y = abs(vel.y)
		elif pos.y + radius >= play_height:
			pos.y = play_height - radius
			vel.y = -abs(vel.y)

		balloon["pos"] = pos
		balloon["vel"] = vel
		balloon["bounce"] = bounce
		balloon["rotation"] = rotation
		balloon["paddle_bounce_cooldown"] = cooldown
		balloon["paddle_bounce_slow_timer"] = slow_timer
		balloon["lifetime"] = float(balloon.get("lifetime", 0.0)) + fps_scale
		balloons[index] = balloon


func ball_path_hits(from_pos: Vector2, to_pos: Vector2, balloon_pos: Vector2, collision_distance: float) -> bool:
	if collision_distance <= 0.0:
		return false
	var movement: Vector2 = to_pos - from_pos
	var movement_len_sq: float = movement.length_squared()
	if movement_len_sq <= 0.001:
		return to_pos.distance_to(balloon_pos) <= collision_distance
	var progress: float = clamp((balloon_pos - from_pos).dot(movement) / movement_len_sq, 0.0, 1.0)
	var closest: Vector2 = from_pos + movement * progress
	return closest.distance_to(balloon_pos) <= collision_distance


func circle_rect_overlap(balloon: Dictionary, rect: Rect2) -> bool:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	var pos: Vector2 = _get_vector2(balloon.get("pos", Vector2.ZERO), Vector2.ZERO)
	var radius: float = float(balloon.get("radius", 30.0))
	var nearest := Vector2(
		clamp(pos.x, rect.position.x, rect.position.x + rect.size.x),
		clamp(pos.y, rect.position.y, rect.position.y + rect.size.y)
	)
	return pos.distance_to(nearest) <= radius


func get_first_overlapping_rect(balloon: Dictionary, rects: Array[Rect2]) -> Rect2:
	for rect in rects:
		if circle_rect_overlap(balloon, rect):
			return rect
	return Rect2()


func bounce_from_paddle(balloon: Dictionary, rect: Rect2) -> float:
	var pos: Vector2 = _get_vector2(balloon.get("pos", Vector2.ZERO), Vector2.ZERO)
	var vel: Vector2 = _get_vector2(balloon.get("vel", Vector2.ZERO), Vector2.ZERO)
	var rect_center: Vector2 = rect.position + rect.size * 0.5
	var normal: Vector2 = pos - rect_center
	if normal.length() <= 0.001:
		normal = vel if vel.length() > 0.001 else Vector2((-1.0 if randf() < 0.5 else 1.0), -1.0)
	normal = normal.normalized()
	var bounce_speed: float = clamp(
		max(PADDLE_BOUNCE_MIN_SPEED, vel.length() * 1.18 + 0.8),
		PADDLE_BOUNCE_MIN_SPEED,
		PADDLE_BOUNCE_MAX_SPEED
	)
	balloon["vel"] = normal * bounce_speed
	balloon["pos"] = pos + normal * 3.0
	balloon["paddle_bounce_slow_timer"] = PADDLE_BOUNCE_SLOW_FRAMES
	balloon["paddle_bounce_cooldown"] = PADDLE_BOUNCE_COOLDOWN_FRAMES
	if abs(rect_center.x - pos.x) <= 1.0:
		return 1.0 if normal.x <= 0.0 else -1.0
	return 1.0 if rect_center.x >= pos.x else -1.0


func deflect_ball_velocity(ball_velocity: Vector2) -> Vector2:
	var speed: float = ball_velocity.length()
	if speed <= 0.001:
		return ball_velocity
	var current_angle: float = atan2(ball_velocity.y, ball_velocity.x)
	var horizontal_angle: float = abs(cos(current_angle))
	var angle_change: float
	if horizontal_angle > 0.7:
		angle_change = randf_range(-0.611, -0.436) if ball_velocity.y >= 0.0 else randf_range(0.436, 0.611)
	else:
		angle_change = randf_range(-0.349, 0.349)
		if abs(ball_velocity.y) < abs(ball_velocity.x) * 0.5:
			angle_change = -0.524 if randf() < 0.5 else 0.524
	var next_velocity := Vector2(cos(current_angle + angle_change), sin(current_angle + angle_change)) * speed
	var min_vertical: float = speed * 0.3
	if abs(next_velocity.y) < min_vertical:
		next_velocity.y = min_vertical if next_velocity.y >= 0.0 else -min_vertical
		next_velocity.x = sqrt(max(0.0, speed * speed - next_velocity.y * next_velocity.y)) * (1.0 if next_velocity.x >= 0.0 else -1.0)
	return next_velocity


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
