extends RefCounted

const GrenadeExplosionDrawer := preload("res://scripts/effects/grenade_explosion_drawer.gd")
const CommandoFirearmHitGeometry := preload("res://scripts/characters/commando_firearm_hit_geometry.gd")
const CommandoFirearmProfileResolver := preload("res://scripts/characters/commando_firearm_profile_resolver.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func build_flash(
	projectile: Dictionary,
	profile: Dictionary,
	fire_support_duration_frames: float
) -> Dictionary:
	var weapon_id: String = str(projectile.get("weapon_id", "pistol"))
	var kind: String = str(projectile.get("kind", "bullet"))
	var impact_radius: float = float(projectile.get("impact_radius", 18.0))
	if kind in ["rocket", "support", "drone"]:
		impact_radius = CommandoFirearmHitGeometry.get_explosion_radius(projectile, profile)
	var flash_kind: String = "grenade_explosion" if weapon_id == "fire_support" else kind
	var flash_timer: float = fire_support_duration_frames if weapon_id == "fire_support" else (18.0 if kind != "bullet" else 10.0)
	var flash := {
		"weapon_id": weapon_id,
		"kind": flash_kind,
		"pos": CommandoFirearmValueUtils.get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO),
		"radius": impact_radius,
		"duration_frames": flash_timer,
		"timer_frames": flash_timer,
		"max_duration_frames": flash_timer,
		"max_timer_frames": flash_timer,
		"color": projectile.get("color", Color.WHITE),
		"secondary": projectile.get("secondary", Color(1.0, 0.5, 0.2)),
	}
	if weapon_id == "fire_support":
		flash["explosion_style"] = GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_STYLE
		flash["texture_layer_count"] = GrenadeExplosionDrawer.FIRE_SUPPORT_TEXTURE_LAYER_COUNT
		flash["smoke_puff_count"] = GrenadeExplosionDrawer.FIRE_SUPPORT_SMOKE_PUFFS
		flash["spark_count"] = GrenadeExplosionDrawer.FIRE_SUPPORT_SPARKS
	return flash


static func append_flash(
	impact_flashes: Array,
	projectile: Dictionary,
	weapon_profiles: Dictionary,
	weapon_profile_overrides: Dictionary,
	base_weapon_id: String,
	fire_support_duration_frames: float,
	flash_limit: int
) -> void:
	var weapon_id: String = CommandoFirearmValueUtils.get_projectile_weapon_id(
		projectile,
		base_weapon_id
	)
	CommandoFirearmValueUtils.append_limited(
		impact_flashes,
		build_flash(
			projectile,
			CommandoFirearmProfileResolver.get_weapon_profile(
				weapon_id,
				weapon_profiles,
				weapon_profile_overrides
			),
			fire_support_duration_frames
		),
		flash_limit
	)
