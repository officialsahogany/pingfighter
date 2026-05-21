extends RefCounted


static func build_projectile(
	weapon_id: String,
	kind: String,
	projectile_id: int,
	origin: Vector2,
	target: Vector2,
	direction: Vector2,
	speed: float,
	angle_offset: float,
	aim_origin: Vector2,
	profile: Dictionary,
	doping_context: Dictionary,
	default_smoke_trail_limit: int,
	default_rope_trail_limit: int,
	default_doping_head_leg_multiplier: float,
	default_doping_pistol_speed_multiplier: float
) -> Dictionary:
	var projectile := {
		"id": projectile_id,
		"weapon_id": weapon_id,
		"kind": kind,
		"pos": origin,
		"prev_pos": origin,
		"target": target,
		"velocity": direction * speed,
		"speed": speed,
		"angle_offset": angle_offset,
		"radius": float(profile.get("radius", 5.0)),
		"trail": float(profile.get("trail", 24.0)),
		"life_frames": float(profile.get("life_frames", 45.0)),
		"max_life_frames": float(profile.get("life_frames", 45.0)),
		"impact_radius": float(profile.get("impact_radius", 18.0)),
		"color": profile.get("color", Color.WHITE),
		"secondary": profile.get("secondary", Color(1.0, 0.5, 0.2)),
	}
	if weapon_id == "commando_pistol" and bool(doping_context.get("active", false)):
		projectile["active_item_doping_potion_active"] = true
		projectile["active_item_doping_potion_head_leg_multiplier"] = float(doping_context.get("head_leg_multiplier", default_doping_head_leg_multiplier))
		projectile["active_item_doping_potion_pistol_speed_multiplier"] = float(doping_context.get("pistol_speed_multiplier", default_doping_pistol_speed_multiplier))
	if bool(profile.get("slingshot", false)):
		var charge_level: int = clampi(int(profile.get("charge_level", 1)), 1, 3)
		var stone_variant: int = abs(projectile_id - 1) % 4
		projectile["slingshot"] = true
		projectile["charge_level"] = charge_level
		projectile["slingshot_stone_variant"] = stone_variant
		projectile["slingshot_stone_frame"] = (charge_level - 1) * 4 + stone_variant
	if profile.has("explosion_radius"):
		projectile["explosion_radius"] = float(profile.get("explosion_radius", float(profile.get("impact_radius", 18.0))))
	if profile.has("acceleration"):
		projectile["acceleration"] = float(profile.get("acceleration", 0.0))
	if profile.has("max_speed"):
		projectile["max_speed"] = float(profile.get("max_speed", speed))
	if profile.has("smoke_trail_limit"):
		projectile["smoke_trail_limit"] = int(profile.get("smoke_trail_limit", default_smoke_trail_limit))
		projectile["smoke_trail"] = []
	if weapon_id == "net_gun":
		projectile["origin"] = aim_origin
		projectile["rope_points"] = []
		projectile["rope_trail_limit"] = int(profile.get("rope_trail_limit", default_rope_trail_limit))
	return projectile
