extends RefCounted

var player_center := Vector2.ZERO
var player_size := Vector2.ZERO
var last_player_pos := Vector2.ZERO
var last_move_delta_x := 0.0
var phase := 0.0
var trails: Array = []


func clear_runtime(default_player_size: Vector2 = Vector2.ZERO) -> void:
	player_center = Vector2.ZERO
	player_size = default_player_size
	last_player_pos = Vector2.ZERO
	last_move_delta_x = 0.0
	phase = 0.0
	trails.clear()


func clear_round_state(default_player_size: Vector2 = Vector2.ZERO) -> void:
	clear_runtime(default_player_size)


func update(
	equipped: bool,
	next_player_pos: Vector2,
	next_player_size: Vector2,
	fps_scale: float,
	trail_life_frames: float,
	trail_max: int,
	move_trail_threshold: float,
	wing_flap_speed: float
) -> void:
	var step: float = max(0.0, fps_scale)
	if not equipped:
		if not trails.is_empty():
			_update_trails(step)
		last_move_delta_x = 0.0
		return
	phase = fmod(phase + step * wing_flap_speed, TAU * 1024.0)
	player_size = next_player_size
	player_center = next_player_pos + player_size * 0.5
	if last_player_pos != Vector2.ZERO:
		last_move_delta_x = next_player_pos.x - last_player_pos.x
		if abs(last_move_delta_x) >= move_trail_threshold:
			_add_trail(player_center, player_size, sign(last_move_delta_x), trail_life_frames, trail_max)
	else:
		last_move_delta_x = 0.0
	last_player_pos = next_player_pos
	_update_trails(step)


func is_visible(active: bool) -> bool:
	return active or not trails.is_empty()


func get_context(equipped: bool, active: bool, speed_bonus_pct: float, speed_multiplier: float) -> Dictionary:
	return {
		"equipped": equipped,
		"active": active,
		"speed_bonus_pct": speed_bonus_pct,
		"speed_multiplier": speed_multiplier,
		"trail_count": trails.size(),
		"player_center": player_center,
		"player_size": player_size,
	}


func _add_trail(center: Vector2, size: Vector2, direction: float, trail_life_frames: float, trail_max: int) -> void:
	trails.append({
		"center": center,
		"size": size,
		"direction": direction,
		"life": trail_life_frames,
		"max_life": trail_life_frames,
	})
	while trails.size() > trail_max:
		trails.pop_front()


func _update_trails(fps_scale: float) -> void:
	var step: float = max(0.0, fps_scale)
	for i in range(trails.size() - 1, -1, -1):
		var trail: Dictionary = _get_dict(trails[i])
		var life: float = float(trail.get("life", 0.0)) - step
		if life <= 0.0:
			trails.remove_at(i)
			continue
		var direction: float = sign(float(trail.get("direction", 0.0)))
		trail["center"] = _get_vector2(trail.get("center", Vector2.ZERO)) - Vector2(direction * 0.85 * step, 0.0)
		trail["life"] = life
		trails[i] = trail


func _get_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _get_vector2(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2.ZERO
