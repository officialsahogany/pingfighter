extends RefCounted

const PLAYER_COLLISION_SIZE := Vector2(38.0, 32.0)
const PLAYER_SPEED_PER_FRAME_60 := 4.0


static func get_collision_rect(player_pos: Vector2) -> Rect2:
	return Rect2(player_pos - PLAYER_COLLISION_SIZE * 0.5, PLAYER_COLLISION_SIZE)


static func move_player(
	player_pos: Vector2,
	input_dir: Vector2,
	delta: float,
	collision_rects: Array,
	map_size: Vector2
) -> Dictionary:
	var direction := input_dir
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	var fps_scale: float = max(0.0, delta) * 60.0
	var movement: Vector2 = direction * PLAYER_SPEED_PER_FRAME_60 * fps_scale
	var next_pos := player_pos
	next_pos.x = _move_axis(next_pos, Vector2(movement.x, 0.0), collision_rects, map_size).x
	next_pos.y = _move_axis(next_pos, Vector2(0.0, movement.y), collision_rects, map_size).y
	var blocked := not next_pos.is_equal_approx(player_pos + movement)
	return {
		"player_pos": next_pos,
		"blocked": blocked,
		"fps_scale": fps_scale,
	}


static func _move_axis(
	player_pos: Vector2,
	axis_delta: Vector2,
	collision_rects: Array,
	map_size: Vector2
) -> Vector2:
	if axis_delta == Vector2.ZERO:
		return player_pos
	var next_pos := player_pos + axis_delta
	next_pos.x = clampf(next_pos.x, PLAYER_COLLISION_SIZE.x * 0.5, map_size.x - PLAYER_COLLISION_SIZE.x * 0.5)
	next_pos.y = clampf(next_pos.y, PLAYER_COLLISION_SIZE.y * 0.5, map_size.y - PLAYER_COLLISION_SIZE.y * 0.5)
	var next_rect := get_collision_rect(next_pos)
	for rect_value in collision_rects:
		if rect_value is Rect2 and next_rect.intersects(rect_value as Rect2):
			return player_pos
	return next_pos
