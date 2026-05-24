extends RefCounted

const CommandoFirearmLingeringNetFieldState := preload("res://scripts/characters/commando_firearm_lingering_net_field_state.gd")
const CommandoFirearmLingeringStatusState := preload("res://scripts/characters/commando_firearm_lingering_status_state.gd")
const CommandoFirearmOriginGeometry := preload("res://scripts/characters/commando_firearm_origin_geometry.gd")


static func get_duration(
	profile: Dictionary,
	is_net: bool,
	dissolve: bool,
	default_net_dissolve_frames: float
) -> float:
	if is_net and dissolve:
		return max(1.0, float(profile.get("dissolve_frames", default_net_dissolve_frames)))
	return max(1.0, float(profile.get("duration_frames", 1.0)))


static func get_size(
	profile: Dictionary,
	projectile: Dictionary,
	is_net: bool,
	net_width: float,
	net_height: float
) -> Vector2:
	if is_net:
		return Vector2(net_width, net_height)
	var impact_radius: float = float(projectile.get("impact_radius", 24.0))
	return Vector2(
		float(profile.get("width", impact_radius * 2.0)),
		float(profile.get("height", impact_radius * 1.2))
	)


static func build_effect(
	weapon_id: String,
	profile: Dictionary,
	projectile: Dictionary,
	pos: Vector2,
	effect_id: int,
	effect_size: Vector2,
	duration: float
) -> Dictionary:
	return {
		"id": effect_id,
		"weapon_id": weapon_id,
		"kind": str(profile.get("kind", "field")),
		"pos": pos,
		"width": effect_size.x,
		"height": effect_size.y,
		"timer_frames": duration,
		"max_timer_frames": duration,
		"phase": 0.0,
		"color": profile.get("color", projectile.get("color", Color.WHITE)),
		"secondary": profile.get("secondary", projectile.get("secondary", Color(1.0, 0.5, 0.2))),
		"source": "commando_firearm_%s_lingering_%d" % [weapon_id, effect_id],
	}


static func build_spawn_result(effect: Dictionary, duration: float) -> Dictionary:
	return {
		"kind": str(effect.get("kind", "")),
		"duration_frames": duration,
		"source": str(effect.get("source", "")),
	}


static func build_net_dissolve_projectile(projectile: Dictionary) -> Dictionary:
	var net_projectile: Dictionary = projectile.duplicate(true)
	net_projectile["net_dissolve"] = true
	return net_projectile


static func advance_timers(effect: Dictionary, fps_scale: float, phase_step: float) -> void:
	var step: float = get_timer_step(fps_scale)
	effect["timer_frames"] = get_next_timer(effect, step)
	effect["phase"] = get_next_phase(effect, step, phase_step)
	if should_advance_rope_snap_timer(effect):
		effect["rope_snap_timer"] = get_next_rope_snap_timer(effect, step)


static func get_timer_step(fps_scale: float) -> float:
	return max(0.0, fps_scale)


static func get_next_timer(effect: Dictionary, step: float) -> float:
	return max(0.0, get_timer(effect) - step)


static func get_next_phase(effect: Dictionary, step: float, phase_step: float) -> float:
	return get_phase(effect) + get_phase_step(step, phase_step)


static func get_timer(effect: Dictionary) -> float:
	return float(effect.get("timer_frames", 0.0))


static func get_phase(effect: Dictionary) -> float:
	return float(effect.get("phase", 0.0))


static func get_phase_step(step: float, phase_step: float) -> float:
	return phase_step * step


static func should_advance_rope_snap_timer(effect: Dictionary) -> bool:
	return bool(effect.get("rope_broken", false))


static func get_next_rope_snap_timer(effect: Dictionary, step: float) -> float:
	return max(0.0, get_rope_snap_timer(effect) - step)


static func get_rope_snap_timer(effect: Dictionary) -> float:
	return float(effect.get("rope_snap_timer", 0.0))


static func is_fire_zone(effect: Dictionary) -> bool:
	return str(effect.get("kind", "")) == "fire_zone"


static func is_active(effect: Dictionary) -> bool:
	return has_timer(get_timer(effect))


static func has_timer(timer_frames: float) -> bool:
	return timer_frames > 0.0


static func merge_clamp_result(result: Dictionary, context: Dictionary, clamp_result: Dictionary) -> void:
	if not has_clamp_result(clamp_result):
		return
	apply_clamp_payload(result, clamp_result)
	apply_clamp_payload(context, clamp_result)


static func apply_active_effect(
	effect: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	timer_step: float,
	field_size: Vector2,
	net_gun_muzzle_source: Vector2,
	fire_sheet_source_cell_size: Vector2,
	fire_sheet_player_foot_y_offset: float,
	net_gun_width: float,
	net_gun_min_height: float,
	status_target: String,
	status_id_slow: String,
	status_duration_frames: float,
	status_interval_frames: float,
	status_slow_multiplier: float,
	status_min_slow_multiplier: float,
	status_max_slow_multiplier: float,
	status_source: String
) -> Dictionary:
	if CommandoFirearmLingeringNetFieldState.should_sync_rope_origin(effect):
		effect["origin"] = CommandoFirearmOriginGeometry.get_commando_fire_sheet_world_pos(
			context,
			net_gun_muzzle_source,
			field_size,
			fire_sheet_source_cell_size,
			fire_sheet_player_foot_y_offset
		)
	CommandoFirearmLingeringStatusState.apply_status_if_ready(
		effect,
		context,
		deps,
		timer_step,
		status_target,
		status_id_slow,
		status_duration_frames,
		status_interval_frames,
		status_slow_multiplier,
		status_min_slow_multiplier,
		status_max_slow_multiplier,
		status_source
	)
	return CommandoFirearmLingeringNetFieldState.apply_net_field_boss_clamp(
		effect,
		context,
		net_gun_width,
		net_gun_min_height
	)


static func has_clamp_result(clamp_result: Dictionary) -> bool:
	return not clamp_result.is_empty()


static func apply_clamp_payload(target: Dictionary, clamp_result: Dictionary) -> void:
	target.merge(clamp_result, true)
