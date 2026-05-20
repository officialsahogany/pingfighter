extends RefCounted

const CommandoFirearmSupportCallResolver := preload("res://scripts/characters/commando_firearm_support_call_resolver.gd")


static func build_projectile(
	target: Vector2,
	profile: Dictionary,
	weapon_id: String,
	projectile_id: int,
	call_id: int,
	spawn_index: int,
	field_width: float,
	field_height: float,
	support_aircraft_y: float,
	default_initial_vy: float,
	default_gravity: float,
	default_horizontal_jitter: float
) -> Dictionary:
	var radius: float = float(profile.get("radius", 7.0))
	@warning_ignore("shadowed_global_identifier")
	var seed: int = CommandoFirearmSupportCallResolver.support_call_seed(call_id + spawn_index * 19, target)
	var start_y: float = max(24.0, support_aircraft_y + 12.0 + float(seed % 17 - 8))
	var target_y: float = clamp(max(target.y, start_y + 24.0), 42.0, field_height - 64.0)
	var start: Vector2 = Vector2(
		clamp(target.x, radius + 8.0, field_width - radius - 8.0),
		start_y
	)
	@warning_ignore("integer_division")
	var jitter_bucket: int = int(seed / 17) % 2001
	var jitter_unit: float = (float(jitter_bucket) / 1000.0) - 1.0
	var velocity := Vector2(
		jitter_unit * float(profile.get("horizontal_jitter", default_horizontal_jitter)),
		float(profile.get("initial_vy", default_initial_vy))
	)
	return {
		"id": projectile_id,
		"weapon_id": weapon_id,
		"kind": "support",
		"support_call_id": call_id,
		"support_spawn_index": spawn_index,
		"pos": start,
		"prev_pos": start,
		"target": Vector2(start.x, target_y),
		"target_y": target_y,
		"velocity": velocity,
		"speed": velocity.length(),
		"gravity": float(profile.get("gravity", default_gravity)),
		"radius": radius,
		"trail": float(profile.get("trail", 52.0)),
		"life_frames": float(profile.get("life_frames", 44.0)),
		"max_life_frames": float(profile.get("life_frames", 44.0)),
		"impact_radius": float(profile.get("impact_radius", 54.0)),
		"explosion_radius": float(profile.get("explosion_radius", 152.0)),
		"color": profile.get("color", Color(1.0, 0.34, 0.16)),
		"secondary": profile.get("secondary", Color(1.0, 0.82, 0.25)),
	}
