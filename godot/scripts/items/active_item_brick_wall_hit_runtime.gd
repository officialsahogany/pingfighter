extends RefCounted

const ActiveItemBrickWallHitResolver := preload("res://scripts/items/active_item_brick_wall_hit_resolver.gd")
const ActiveItemBrickWallParticles := preload("res://scripts/items/active_item_brick_wall_particles.gd")

const BRICK_WALL_DESTROY_HITS := 2
const BRICK_HIT_DUST_COUNT := 12

var _hit_resolver: Object = ActiveItemBrickWallHitResolver.new()
var _particles: Object = ActiveItemBrickWallParticles.new()


func apply_hit(
	walls: Array[Dictionary],
	particles: Array[Dictionary],
	wall_index: int,
	impact_pos: Vector2,
	destroy_hits: int = BRICK_WALL_DESTROY_HITS
) -> Dictionary:
	var result: Dictionary = _hit_resolver.resolve_hit(walls, wall_index, destroy_hits)
	if not bool(result.get("valid", false)):
		return {"destroyed": false}

	var wall_rect: Rect2 = _get_rect2(result, "wall_rect", Rect2())
	var destroyed: bool = bool(result.get("destroyed", false))
	if destroyed:
		walls.remove_at(wall_index)
		_particles.spawn_destruction_effect(particles, wall_rect, impact_pos)
	else:
		walls[wall_index] = _get_dictionary(result, "updated_wall")
		_particles.spawn_hit_dust(particles, impact_pos, BRICK_HIT_DUST_COUNT)

	return {
		"destroyed": destroyed,
		"hit_count": int(result.get("hit_count", 0)),
	}


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_rect2(source: Dictionary, key: String, fallback: Rect2) -> Rect2:
	var value: Variant = source.get(key, fallback)
	if value is Rect2:
		return value
	return fallback
