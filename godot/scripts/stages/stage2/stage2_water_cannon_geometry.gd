extends RefCounted


func get_boss_cannon_start(boss_pos: Vector2, boss_width: float, boss_height: float) -> Vector2:
	return boss_pos + Vector2(boss_width * 0.5, boss_height + 30.0)
