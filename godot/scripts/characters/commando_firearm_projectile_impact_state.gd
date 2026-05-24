extends RefCounted

const CommandoFirearmHitGeometry := preload("res://scripts/characters/commando_firearm_hit_geometry.gd")
const CommandoFirearmOriginGeometry := preload("res://scripts/characters/commando_firearm_origin_geometry.gd")
const CommandoFirearmProfileResolver := preload("res://scripts/characters/commando_firearm_profile_resolver.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


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


static func get_impact_reason(
	projectile: Dictionary,
	context: Dictionary,
	weapon_profiles: Dictionary,
	weapon_profile_overrides: Dictionary,
	base_weapon_id: String,
	field_size: Vector2,
	field_width: float
) -> String:
	var target: Vector2 = CommandoFirearmValueUtils.get_projectile_target(
		projectile,
		CommandoFirearmOriginGeometry.get_boss_target_pos(context, field_width)
	)
	var weapon_id: String = CommandoFirearmValueUtils.get_projectile_weapon_id(
		projectile,
		base_weapon_id
	)
	var profile: Dictionary = CommandoFirearmProfileResolver.get_weapon_profile(
		weapon_id,
		weapon_profiles,
		weapon_profile_overrides
	)
	return CommandoFirearmHitGeometry.get_projectile_impact_reason(
		projectile,
		target,
		weapon_id,
		profile,
		CommandoFirearmHitGeometry.get_boss_rect(context, field_width),
		field_size,
		field_width
	)
