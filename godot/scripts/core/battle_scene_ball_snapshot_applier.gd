extends RefCounted


func apply_reset_result(owner: Object, result: Dictionary) -> void:
	if owner == null:
		return

	var updated_player_pos: Variant = result.get("player_pos", _get_owner_vector2(owner, "player_pos", Vector2.ZERO))
	if updated_player_pos is Vector2:
		owner.set("player_pos", updated_player_pos)

	var updated_boss_pos: Variant = result.get("boss_pos", _get_owner_vector2(owner, "boss_pos", Vector2.ZERO))
	if updated_boss_pos is Vector2:
		owner.set("boss_pos", updated_boss_pos)

	owner.set("boss_vel", float(result.get("boss_vel", _get_owner_value(owner, "boss_vel", 0.0))))
	owner.set("player_speed", float(result.get("player_speed", _get_owner_value(owner, "player_speed", 0.0))))


func apply_snapshot(owner: Object, snapshot: Dictionary) -> void:
	if owner == null:
		return
	for key in snapshot.keys():
		owner.set(str(key), snapshot[key])


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return value


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, key, fallback)
	if value is Vector2:
		return value
	return fallback
