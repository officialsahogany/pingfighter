extends RefCounted


func get_boss_cannon_start_from_context(context: Dictionary) -> Vector2:
	var boss_pos: Vector2 = _get_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_width: float = float(context.get("boss_paddle_width", 100.0))
	var boss_height: float = float(context.get("boss_hitbox_height", 40.0))
	return get_boss_cannon_start(boss_pos, boss_width, boss_height)


func get_boss_cannon_start(boss_pos: Vector2, boss_width: float, boss_height: float) -> Vector2:
	return boss_pos + Vector2(boss_width * 0.5, boss_height + 30.0)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
