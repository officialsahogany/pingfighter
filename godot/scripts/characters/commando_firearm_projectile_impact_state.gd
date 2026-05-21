extends RefCounted


static func build_hit_event(
	projectile: Dictionary,
	weapon_id: String,
	projectile_kind: String,
	pos: Vector2,
	velocity: Vector2,
	intensity: float,
	combat_result: Dictionary
) -> Dictionary:
	return {
		"id": int(projectile.get("id", 0)),
		"weapon_id": weapon_id,
		"kind": projectile_kind,
		"target": "boss",
		"pos": pos,
		"velocity": velocity,
		"intensity": intensity,
		"result": combat_result,
	}


static func build_environment_impact_result(weapon_id: String, reason: String, pos: Vector2) -> Dictionary:
	return {
		"commando_firearm_environment_impact": true,
		"commando_firearm_environment_impact_reason": reason,
		"commando_firearm_environment_impact_weapon_id": weapon_id,
		"commando_firearm_environment_impact_pos": pos,
	}
