extends RefCounted

const POWER_SMASH_MAX_TRAILS: int = 28
const POWER_SMASH_TRAIL_SPAWN_DISTANCE: float = 8.0
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
		needs_trail = ball_pos.distance_to(last_pos) > POWER_SMASH_TRAIL_SPAWN_DISTANCE
	if needs_trail:
		spawn(ball_pos, ball_size, combo)


func update(fps_scale: float) -> void:
	var updated_trails: Array[Dictionary] = []
	for trail in trails:
		var t: Dictionary = trail
		var life: float = float(t["life"]) - POWER_SMASH_TRAIL_LIFE_DECAY * fps_scale
		if life > 0.0:
			t["life"] = life
			updated_trails.append(t)
	trails = updated_trails


func get_trails() -> Array[Dictionary]:
	return trails
