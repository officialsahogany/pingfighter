extends RefCounted

const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func get_collision_rect(
	call_data: Dictionary,
	fallback_pos: Vector2,
	collision_size: Vector2
) -> Rect2:
	var aircraft_pos := fallback_pos
	var pos_value: Variant = call_data.get("aircraft_pos", fallback_pos)
	if pos_value is Vector2:
		aircraft_pos = pos_value
	return Rect2(aircraft_pos - collision_size * 0.5, collision_size)


static func has_active_aircraft_audio(calls: Array) -> bool:
	for value in calls:
		var call_data: Dictionary = CommandoFirearmValueUtils.get_dict(value)
		if bool(call_data.get("aircraft_audio_active", false)):
			return true
	return false


static func get_active_collision_rect(
	calls: Array,
	call_id: int,
	fallback_pos: Vector2,
	collision_size: Vector2
) -> Rect2:
	for value in calls:
		var call_data: Dictionary = CommandoFirearmValueUtils.get_dict(value)
		if not bool(call_data.get("aircraft_active", false)):
			continue
		if call_id != 0 and int(call_data.get("id", 0)) != call_id:
			continue
		return get_collision_rect(call_data, fallback_pos, collision_size)
	return Rect2()


static func any_ball_path_hits(
	calls: Array,
	from_pos: Vector2,
	to_pos: Vector2,
	ball_radius: float,
	fallback_pos: Vector2,
	collision_size: Vector2
) -> bool:
	for value in calls:
		var call_data: Dictionary = CommandoFirearmValueUtils.get_dict(value)
		if ball_path_hits(call_data, from_pos, to_pos, ball_radius, fallback_pos, collision_size):
			return true
	return false


static func ball_path_hits(
	call_data: Dictionary,
	from_pos: Vector2,
	to_pos: Vector2,
	ball_radius: float,
	fallback_pos: Vector2,
	collision_size: Vector2
) -> bool:
	if not bool(call_data.get("aircraft_active", false)):
		return false
	var aircraft_rect: Rect2 = get_collision_rect(call_data, fallback_pos, collision_size).grow(ball_radius)
	if aircraft_rect.has_point(from_pos) or aircraft_rect.has_point(to_pos):
		return true
	var movement: Vector2 = to_pos - from_pos
	if movement.length_squared() <= 0.001:
		return false
	var top_left := aircraft_rect.position
	var top_right := Vector2(aircraft_rect.end.x, aircraft_rect.position.y)
	var bottom_right := aircraft_rect.end
	var bottom_left := Vector2(aircraft_rect.position.x, aircraft_rect.end.y)
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
