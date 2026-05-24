extends RefCounted

const CommandoFirearmLingeringNetFieldState := preload("res://scripts/characters/commando_firearm_lingering_net_field_state.gd")
const CommandoFirearmLingeringFireFlameState := preload("res://scripts/characters/commando_firearm_lingering_fire_flame_state.gd")
const CommandoFirearmLingeringStatusState := preload("res://scripts/characters/commando_firearm_lingering_status_state.gd")
const CommandoFirearmOriginGeometry := preload("res://scripts/characters/commando_firearm_origin_geometry.gd")
const CommandoFirearmProfileResolver := preload("res://scripts/characters/commando_firearm_profile_resolver.gd")
const CommandoFirearmProjectileSpawnState := preload("res://scripts/characters/commando_firearm_projectile_spawn_state.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


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


static func build_spawn_payload(
	weapon_id: String,
	profile: Dictionary,
	projectile: Dictionary,
	context: Dictionary,
	effect_id: int,
	field_size: Vector2,
	net_gun_width: float,
	net_gun_height: float,
	net_gun_min_height: float,
	net_gun_dissolve_frames: float,
	net_gun_dash_break_frames: float,
	net_gun_player_slow_multiplier: float,
	net_gun_muzzle_source: Vector2,
	fire_sheet_source_cell_size: Vector2,
	fire_sheet_player_foot_y_offset: float,
	status_duration_frames: float,
	status_interval_frames: float,
	status_initial_cooldown_frames: float,
	status_slow_multiplier: float
) -> Dictionary:
	if profile.is_empty():
		return {}
	var is_net: bool = weapon_id == "net_gun"
	var dissolve: bool = bool(projectile.get("net_dissolve", false))
	var duration: float = get_duration(
		profile,
		is_net,
		dissolve,
		net_gun_dissolve_frames
	)
	var projectile_pos: Vector2 = CommandoFirearmValueUtils.get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var pos: Vector2 = CommandoFirearmLingeringNetFieldState.get_lingering_effect_pos(
		profile,
		projectile,
		context,
		projectile_pos,
		CommandoFirearmOriginGeometry.get_boss_target_pos(context, field_size.x),
		field_size.x,
		field_size.y,
		net_gun_width,
		net_gun_min_height,
		net_gun_height
	)
	var net_effect_height: float = CommandoFirearmLingeringNetFieldState.get_net_effect_height(
		profile,
		context,
		net_gun_min_height,
		net_gun_height
	)
	var effect_size: Vector2 = get_size(
		profile,
		projectile,
		is_net,
		net_gun_width,
		net_effect_height
	)
	var effect: Dictionary = build_effect(
		weapon_id,
		profile,
		projectile,
		pos,
		effect_id,
		effect_size,
		duration
	)
	if is_net:
		CommandoFirearmLingeringNetFieldState.apply_net_fields(
			effect,
			profile,
			projectile,
			CommandoFirearmOriginGeometry.get_commando_fire_sheet_world_pos(
				context,
				net_gun_muzzle_source,
				field_size,
				fire_sheet_source_cell_size,
				fire_sheet_player_foot_y_offset
			),
			pos,
			effect_size,
			effect_id,
			dissolve,
			net_gun_dash_break_frames,
			net_gun_player_slow_multiplier
		)
	CommandoFirearmLingeringStatusState.apply_effect_status_fields(
		effect,
		profile,
		dissolve,
		status_duration_frames,
		status_interval_frames,
		status_initial_cooldown_frames,
		status_slow_multiplier
	)
	CommandoFirearmLingeringFireFlameState.seed_effect_flames(effect)
	return {
		"effect": effect,
		"duration": duration,
		"spawn_result": build_spawn_result(effect, duration),
	}


static func build_net_dissolve_projectile(projectile: Dictionary) -> Dictionary:
	var net_projectile: Dictionary = projectile.duplicate(true)
	net_projectile["net_dissolve"] = true
	return net_projectile


static func append_runtime_spawn_effect(
	lingering_effects: Array,
	runtime_owner: Object,
	weapon_id: String,
	profile: Dictionary,
	projectile: Dictionary,
	context: Dictionary,
	field_size: Vector2,
	net_gun_width: float,
	net_gun_height: float,
	net_gun_min_height: float,
	net_gun_dissolve_frames: float,
	net_gun_dash_break_frames: float,
	net_gun_player_slow_multiplier: float,
	net_gun_muzzle_source: Vector2,
	fire_sheet_source_cell_size: Vector2,
	fire_sheet_player_foot_y_offset: float,
	status_duration_frames: float,
	status_interval_frames: float,
	status_initial_cooldown_frames: float,
	status_slow_multiplier: float,
	effect_limit: int
) -> Dictionary:
	if profile.is_empty():
		return {}
	var effect_id: int = int(projectile.get("id", 0))
	if effect_id == 0:
		effect_id = CommandoFirearmProjectileSpawnState.claim_next_shot_id(runtime_owner)
	var spawn_payload: Dictionary = build_spawn_payload(
		weapon_id,
		profile,
		projectile,
		context,
		effect_id,
		field_size,
		net_gun_width,
		net_gun_height,
		net_gun_min_height,
		net_gun_dissolve_frames,
		net_gun_dash_break_frames,
		net_gun_player_slow_multiplier,
		net_gun_muzzle_source,
		fire_sheet_source_cell_size,
		fire_sheet_player_foot_y_offset,
		status_duration_frames,
		status_interval_frames,
		status_initial_cooldown_frames,
		status_slow_multiplier
	)
	var effect: Dictionary = CommandoFirearmValueUtils.get_dict(spawn_payload.get("effect", {}))
	if effect.is_empty():
		return {}
	CommandoFirearmValueUtils.append_limited(lingering_effects, effect, effect_limit)
	return CommandoFirearmValueUtils.get_dict(spawn_payload.get("spawn_result", {}))


static func spawn_runtime_lingering_effect(
	runtime_owner: Object,
	weapon_id: String,
	projectile: Dictionary,
	context: Dictionary,
	options: Dictionary
) -> Dictionary:
	if runtime_owner == null:
		return {}
	var profile: Dictionary = CommandoFirearmProfileResolver.get_lingering_effect_profile(
		weapon_id,
		CommandoFirearmValueUtils.get_dict(options.get("weapon_lingering_effects", {}))
	)
	if profile.is_empty():
		return {}
	var lingering_effects: Array = CommandoFirearmValueUtils.get_array(runtime_owner.get("lingering_effects"))
	var result: Dictionary = append_runtime_spawn_effect(
		lingering_effects,
		runtime_owner,
		weapon_id,
		profile,
		projectile,
		context,
		Vector2(float(options.get("field_width", 760.0)), float(options.get("field_height", 750.0))),
		float(options.get("net_gun_width", 280.0)),
		float(options.get("net_gun_height", 140.0)),
		float(options.get("net_gun_min_height", 90.0)),
		float(options.get("net_gun_dissolve_frames", 21.0)),
		float(options.get("net_gun_dash_break_frames", 24.0)),
		float(options.get("net_gun_player_slow_multiplier", 1.0)),
		CommandoFirearmValueUtils.get_vector2(options.get("net_gun_muzzle_source", Vector2.ZERO), Vector2.ZERO),
		CommandoFirearmValueUtils.get_vector2(options.get("fire_sheet_source_cell_size", Vector2.ZERO), Vector2.ZERO),
		float(options.get("fire_sheet_player_foot_y_offset", 0.0)),
		float(options.get("status_duration_frames", 18.0)),
		float(options.get("status_interval_frames", 12.0)),
		float(options.get("status_initial_cooldown_frames", 0.0)),
		float(options.get("status_slow_multiplier", 1.0)),
		int(options.get("effect_limit", 18))
	)
	runtime_owner.set("lingering_effects", lingering_effects)
	return result


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


static func apply_runtime_active_effect_at_index(
	lingering_effects: Array,
	index: int,
	effect: Dictionary,
	timer_step: float,
	context: Dictionary,
	deps: Dictionary,
	result: Dictionary,
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
) -> void:
	var clamp_result: Dictionary = apply_active_effect(
		effect,
		context,
		deps,
		timer_step,
		field_size,
		net_gun_muzzle_source,
		fire_sheet_source_cell_size,
		fire_sheet_player_foot_y_offset,
		net_gun_width,
		net_gun_min_height,
		status_target,
		status_id_slow,
		status_duration_frames,
		status_interval_frames,
		status_slow_multiplier,
		status_min_slow_multiplier,
		status_max_slow_multiplier,
		status_source
	)
	merge_clamp_result(result, context, clamp_result)
	if index >= 0 and index < lingering_effects.size():
		lingering_effects[index] = effect


static func advance_runtime_effects(
	runtime_owner: Object,
	context: Dictionary,
	deps: Dictionary,
	fps_scale: float,
	dash_break_frames: float,
	phase_step: float,
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
	if runtime_owner == null:
		return {}
	var lingering_effects: Array = CommandoFirearmValueUtils.get_array(runtime_owner.get("lingering_effects"))
	var step: float = get_timer_step(fps_scale)
	var result: Dictionary = {}
	var dash_trigger_result: Dictionary = CommandoFirearmLingeringNetFieldState.apply_dash_break_if_triggered(
		lingering_effects,
		context,
		deps,
		bool(runtime_owner.get("net_gun_last_dash_active")),
		dash_break_frames
	)
	runtime_owner.set("net_gun_last_dash_active", bool(dash_trigger_result.get("dash_active", false)))
	for index in range(lingering_effects.size() - 1, -1, -1):
		var effect: Dictionary = CommandoFirearmValueUtils.get_dict(lingering_effects[index])
		advance_timers(effect, step, phase_step)
		CommandoFirearmLingeringFireFlameState.update_effect_flames(effect, step)
		if is_active(effect):
			apply_runtime_active_effect_at_index(
				lingering_effects,
				index,
				effect,
				step,
				context,
				deps,
				result,
				field_size,
				net_gun_muzzle_source,
				fire_sheet_source_cell_size,
				fire_sheet_player_foot_y_offset,
				net_gun_width,
				net_gun_min_height,
				status_target,
				status_id_slow,
				status_duration_frames,
				status_interval_frames,
				status_slow_multiplier,
				status_min_slow_multiplier,
				status_max_slow_multiplier,
				status_source
			)
		else:
			lingering_effects.remove_at(index)
	runtime_owner.set("lingering_effects", lingering_effects)
	return result


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
