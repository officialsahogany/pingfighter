extends RefCounted

const POWER_SMASH_MAX_TRAILS: int = 16
const POWER_SMASH_TRAIL_SPAWN_DISTANCE: float = 12.0
const POWER_SMASH_TRAIL_LIFE_DECAY: float = 20.0 / 255.0

var trails: Array[Dictionary] = []


func clear() -> void:
	trails.clear()


func spawn(pos: Vector2, ball_size: float, combo_count: int = 0) -> void:
	var combo: int = max(0, combo_count)
	trails.append({
		"pos": pos,
		"life": 1.0,
		"size": max(1.0, ball_size),
		"combo_count": combo,
	})
	while trails.size() > POWER_SMASH_MAX_TRAILS:
		trails.pop_front()


func maybe_spawn(ball_pos: Vector2, ball_size: float, combo_count: int = 0) -> void:
	var combo: int = max(0, combo_count)
	var needs_trail: bool = true
	if trails.size() > 0:
		var last_trail: Dictionary = trails[trails.size() - 1]
		var last_pos: Vector2 = last_trail["pos"]
		needs_trail = ball_pos.distance_squared_to(last_pos) > POWER_SMASH_TRAIL_SPAWN_DISTANCE * POWER_SMASH_TRAIL_SPAWN_DISTANCE
	if needs_trail:
		spawn(ball_pos, ball_size, combo)


func update(fps_scale: float) -> void:
	if trails.is_empty():
		return
	var write_idx: int = 0
	for i in range(trails.size()):
		var t: Dictionary = trails[i]
		var life: float = float(t["life"]) - POWER_SMASH_TRAIL_LIFE_DECAY * fps_scale
		if life > 0.0:
			t["life"] = life
			trails[write_idx] = t
			write_idx += 1
	trails.resize(write_idx)


func get_trails() -> Array[Dictionary]:
	return trails


func has_trails() -> bool:
	return not trails.is_empty()
