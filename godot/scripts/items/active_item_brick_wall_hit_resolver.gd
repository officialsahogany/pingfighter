extends RefCounted

const BRICK_WALL_DESTROY_HITS := 2


func resolve_hit(walls: Array[Dictionary], wall_index: int, destroy_hits: int = BRICK_WALL_DESTROY_HITS) -> Dictionary:
	if wall_index < 0 or wall_index >= walls.size():
		return {
			"valid": false,
			"destroyed": false,
			"hit_count": 0,
		}

	var wall: Dictionary = walls[wall_index].duplicate(true)
	var wall_rect: Rect2 = _get_rect2(wall, "rect", Rect2())
	var hit_count: int = int(wall.get("hit_count", 0)) + 1
	wall["hit_count"] = hit_count
	wall["crack_level"] = min(2, hit_count)

	return {
		"valid": true,
		"destroyed": hit_count >= max(1, destroy_hits),
		"hit_count": hit_count,
		"wall_rect": wall_rect,
		"updated_wall": wall,
	}


func _get_rect2(source: Dictionary, key: String, fallback: Rect2) -> Rect2:
	var value: Variant = source.get(key, fallback)
	if value is Rect2:
		return value
	return fallback
