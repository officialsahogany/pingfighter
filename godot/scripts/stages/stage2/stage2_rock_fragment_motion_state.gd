extends RefCounted


static func update_fragments(rock_fragments: Array, delta: float, floor_y: float = 700.0) -> void:
	var write_index := 0
	var fragment_count := rock_fragments.size()
	for index in range(fragment_count):
		var fragment: Dictionary = rock_fragments[index]
		if not update_fragment(fragment, delta, floor_y):
			continue
		rock_fragments[write_index] = fragment
		write_index += 1
	if write_index < fragment_count:
		rock_fragments.resize(write_index)


static func update_fragment(fragment: Dictionary, delta: float, floor_y: float = 700.0) -> bool:
	var life: float = float(fragment.get("life", 0.0)) - delta
	if life <= 0.0:
		return false
	var pos: Vector2 = _get_vector2(fragment.get("pos", Vector2.ZERO), Vector2.ZERO)
	var vel: Vector2 = _get_vector2(fragment.get("vel", Vector2.ZERO), Vector2.ZERO)
	vel.y += float(fragment.get("gravity", 1800.0)) * delta
	pos += vel * delta
	if pos.y > floor_y:
		pos.y = floor_y
		vel.y *= -float(fragment.get("bounce", 0.6))
		vel.x *= 0.8
	fragment["pos"] = pos
	fragment["vel"] = vel
	fragment["life"] = life
	fragment["rotation"] = float(fragment.get("rotation", 0.0)) + float(fragment.get("spin", 0.0)) * delta
	return true


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
