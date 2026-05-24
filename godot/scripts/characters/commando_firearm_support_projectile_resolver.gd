extends RefCounted

const CommandoFirearmSupportCallResolver := preload("res://scripts/characters/commando_firearm_support_call_resolver.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func append_projectile(
	projectiles: Array,
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
	default_horizontal_jitter: float,
	support_aircraft_pos: Vector2,
	opponent_wall_y: float,
	default_flight_frames: float,
	default_life_frames: float,
	impact_mode: String,
	projectile_limit: int
) -> void:
	CommandoFirearmValueUtils.append_limited(
		projectiles,
		build_projectile(
			target,
			profile,
			weapon_id,
			projectile_id,
			call_id,
			spawn_index,
			field_width,
			field_height,
			support_aircraft_y,
			default_initial_vy,
			default_gravity,
			default_horizontal_jitter,
			support_aircraft_pos,
			opponent_wall_y,
			default_flight_frames,
			default_life_frames,
			impact_mode
		),
		projectile_limit
	)


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
	default_horizontal_jitter: float,
	support_aircraft_pos: Vector2 = Vector2.INF,
	opponent_wall_y: float = 22.0,
	default_flight_frames: float = 90.0,
	default_life_frames: float = 150.0,
	impact_mode: String = "drop"
) -> Dictionary:
	var radius: float = float(profile.get("radius", 7.0))
	if impact_mode == "opponent_wall":
		return _build_opponent_wall_projectile(
			target,
			profile,
			weapon_id,
			projectile_id,
			call_id,
			spawn_index,
			field_width,
			field_height,
			support_aircraft_pos,
			support_aircraft_y,
			opponent_wall_y,
			default_flight_frames,
			default_life_frames,
			radius
		)
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


static func _build_opponent_wall_projectile(
	target: Vector2,
	profile: Dictionary,
	weapon_id: String,
	projectile_id: int,
	call_id: int,
	spawn_index: int,
	field_width: float,
	field_height: float,
	support_aircraft_pos: Vector2,
	support_aircraft_y: float,
	opponent_wall_y: float,
	default_flight_frames: float,
	default_life_frames: float,
	radius: float
) -> Dictionary:
	var aircraft_pos: Vector2 = support_aircraft_pos
	if not is_finite(aircraft_pos.x) or not is_finite(aircraft_pos.y):
		aircraft_pos = Vector2(target.x, support_aircraft_y)
	var wall_target := Vector2(
		clamp(target.x, radius + 8.0, field_width - radius - 8.0),
		clamp(opponent_wall_y, 12.0, field_height - 64.0)
	)
	var launch_offset := Vector2(0.0, 34.0)
	var start := Vector2(
		clamp(aircraft_pos.x + launch_offset.x, -field_width * 0.5, field_width * 1.5),
		clamp(aircraft_pos.y + launch_offset.y, 24.0, field_height - 42.0)
	)
	var flight_frames: float = max(1.0, float(profile.get("flight_frames", default_flight_frames)))
	var velocity: Vector2 = (wall_target - start) / flight_frames
	var life_frames: float = max(flight_frames + 12.0, float(profile.get("life_frames", default_life_frames)))
	return {
		"id": projectile_id,
		"weapon_id": weapon_id,
		"kind": "support",
		"support_call_id": call_id,
		"support_spawn_index": spawn_index,
		"support_impact_mode": "opponent_wall",
		"support_wall_y": wall_target.y,
		"support_flight_frames": flight_frames,
		"pos": start,
		"prev_pos": start,
		"target": wall_target,
		"target_y": wall_target.y,
		"velocity": velocity,
		"speed": velocity.length(),
		"gravity": 0.0,
		"radius": radius,
		"trail": float(profile.get("trail", 52.0)),
		"life_frames": life_frames,
		"max_life_frames": life_frames,
		"impact_radius": float(profile.get("impact_radius", 54.0)),
		"explosion_radius": float(profile.get("explosion_radius", 152.0)),
		"color": profile.get("color", Color(1.0, 0.34, 0.16)),
		"secondary": profile.get("secondary", Color(1.0, 0.82, 0.25)),
	}
