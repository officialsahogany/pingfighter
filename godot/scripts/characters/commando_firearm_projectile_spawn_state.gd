extends RefCounted

const CommandoFirearmShellCasingState := preload("res://scripts/characters/commando_firearm_shell_casing_state.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func claim_next_shot_id(target: Object) -> int:
	if target == null:
		return 0
	var next_id: int = int(target.get("shot_serial")) + 1
	target.set("shot_serial", next_id)
	return next_id


static func get_fire_direction(
	target: Vector2,
	aim_origin: Vector2,
	vertical_launch: bool,
	angle_offset: float
) -> Vector2:
	var direction: Vector2 = Vector2.UP if vertical_launch else target - aim_origin
	if not vertical_launch:
		if direction.length() <= 0.001:
			direction = Vector2.UP
		else:
			direction = direction.normalized()
	if abs(angle_offset) > 0.0001:
		direction = direction.rotated(angle_offset).normalized()
	return direction


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
	default_doping_pistol_speed_multiplier: float,
	base_pistol_knockback_mult: float = 1.0
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
	elif weapon_id == "pistol":
		projectile["pistol_enhance_knockback_mult"] = max(0.0, base_pistol_knockback_mult)
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


static func append_runtime_projectile(
	projectiles: Array,
	shell_casings: Array,
	runtime_owner: Object,
	weapon_id: String,
	kind: String,
	origin: Vector2,
	target: Vector2,
	direction: Vector2,
	angle_offset: float,
	aim_origin: Vector2,
	profile: Dictionary,
	doping_context: Dictionary,
	config: Dictionary,
	default_speed: float,
	default_smoke_trail_limit: int,
	default_rope_trail_limit: int,
	default_doping_head_leg_multiplier: float,
	default_doping_pistol_speed_multiplier: float,
	base_pistol_knockback_mult: float,
	projectile_limit: int,
	field_height: float,
	ak47_shell_lifetime_frames: float,
	pistol_shell_lifetime_frames: float,
	shell_limit: int
) -> Dictionary:
	var speed: float = float(profile.get("speed", default_speed))
	var shot_id: int = claim_next_shot_id(runtime_owner)
	var projectile: Dictionary = build_projectile(
		weapon_id,
		kind,
		shot_id,
		origin,
		target,
		direction,
		speed,
		angle_offset,
		aim_origin,
		profile,
		doping_context,
		default_smoke_trail_limit,
		default_rope_trail_limit,
		default_doping_head_leg_multiplier,
		default_doping_pistol_speed_multiplier,
		base_pistol_knockback_mult
	)
	CommandoFirearmValueUtils.append_limited(projectiles, projectile, projectile_limit)
	var shell_appended: bool = CommandoFirearmShellCasingState.append_runtime_shell(
		shell_casings,
		weapon_id,
		origin,
		direction,
		config,
		shot_id,
		field_height,
		ak47_shell_lifetime_frames,
		pistol_shell_lifetime_frames,
		shell_limit
	)
	return {
		"shot_id": shot_id,
		"projectile": projectile,
		"shell_appended": shell_appended,
	}
