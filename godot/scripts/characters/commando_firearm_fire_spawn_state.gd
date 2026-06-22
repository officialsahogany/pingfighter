extends RefCounted

const CommandoFirearmAudioDispatcher := preload("res://scripts/characters/commando_firearm_audio_dispatcher.gd")
const CommandoFirearmBowlingTrapGeometry := preload("res://scripts/characters/commando_firearm_bowling_trap_geometry.gd")
const CommandoFirearmFireSheetResolver := preload("res://scripts/characters/commando_firearm_fire_sheet_resolver.gd")
const CommandoFirearmMuzzleFlashResolver := preload("res://scripts/characters/commando_firearm_muzzle_flash_resolver.gd")
const CommandoFirearmOriginGeometry := preload("res://scripts/characters/commando_firearm_origin_geometry.gd")
const CommandoFirearmProfileResolver := preload("res://scripts/characters/commando_firearm_profile_resolver.gd")
const CommandoFirearmProjectileSpawnState := preload("res://scripts/characters/commando_firearm_projectile_spawn_state.gd")
const CommandoFirearmSupportCallResolver := preload("res://scripts/characters/commando_firearm_support_call_resolver.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func spawn_runtime_firearm_effect(
	runtime_owner: Object,
	weapon_id: String,
	config: Dictionary,
	deps: Dictionary,
	profile_override: Dictionary,
	options: Dictionary
) -> Dictionary:
	if runtime_owner == null:
		return {}

	CommandoFirearmFireSheetResolver.apply_runtime_animation_state(
		runtime_owner,
		weapon_id,
		float(options.get("fire_sheet_default_frames", 0.0)),
		float(options.get("fire_sheet_long_frames", 0.0)),
		int(options.get("fire_sheet_frame_count", 1))
	)
	var spawn_profile_state: Dictionary = CommandoFirearmProfileResolver.build_spawn_profile_state(
		weapon_id,
		profile_override,
		CommandoFirearmValueUtils.get_dict(options.get("weapon_profiles", {})),
		CommandoFirearmValueUtils.get_dict(options.get("weapon_profile_overrides", {})),
		config,
		CommandoFirearmValueUtils.get_dict(options.get("doping_potion_defaults", {})),
		str(options.get("base_weapon_id", "pistol")),
		float(options.get("pistol_bullet_speed", 25.0)),
		float(options.get("doping_potion_pistol_speed_multiplier", 1.0)),
		float(options.get("pistol_spread_radians", 0.0)),
		float(options.get("beretta_spread_radians", 0.0)),
		float(options.get("base_pistol_speed_mult", 1.0))
	)
	var profile: Dictionary = CommandoFirearmValueUtils.get_dict(spawn_profile_state.get("profile", {}))
	var doping_context: Dictionary = CommandoFirearmValueUtils.get_dict(spawn_profile_state.get("doping_context", {}))
	var kind: String = str(profile.get("kind", "bullet"))
	var spawn_geometry_state: Dictionary = CommandoFirearmOriginGeometry.build_firearm_spawn_geometry_state(
		weapon_id,
		config,
		profile,
		Vector2(float(options.get("field_width", 760.0)), float(options.get("field_height", 750.0))),
		CommandoFirearmValueUtils.get_vector2(options.get("fire_sheet_source_cell_size", Vector2.ZERO), Vector2.ZERO),
		float(options.get("fire_sheet_player_foot_y_offset", 0.0)),
		CommandoFirearmValueUtils.get_vector2(options.get("pistol_muzzle_source", Vector2.ZERO), Vector2.ZERO),
		CommandoFirearmValueUtils.get_vector2(options.get("bazooka_muzzle_source", Vector2.ZERO), Vector2.ZERO),
		CommandoFirearmValueUtils.get_vector2(options.get("net_gun_muzzle_source", Vector2.ZERO), Vector2.ZERO),
		str(options.get("base_weapon_id", "pistol"))
	)
	var origin: Vector2 = CommandoFirearmValueUtils.get_vector2(spawn_geometry_state.get("origin", Vector2.ZERO), Vector2.ZERO)
	var target: Vector2 = CommandoFirearmValueUtils.get_vector2(spawn_geometry_state.get("target", Vector2.ZERO), Vector2.ZERO)
	var aim_origin: Vector2 = CommandoFirearmValueUtils.get_vector2(spawn_geometry_state.get("aim_origin", origin), origin)
	var angle_offset: float = float(spawn_geometry_state.get("angle_offset", 0.0))
	var direction: Vector2 = CommandoFirearmValueUtils.get_vector2(spawn_geometry_state.get("direction", Vector2.UP), Vector2.UP)

	var muzzle_flashes: Array = CommandoFirearmValueUtils.get_array(runtime_owner.get("muzzle_flashes"))
	var support_calls: Array = CommandoFirearmValueUtils.get_array(runtime_owner.get("support_calls"))
	var impact_flashes: Array = CommandoFirearmValueUtils.get_array(runtime_owner.get("impact_flashes"))
	var bowling_traps: Array = CommandoFirearmValueUtils.get_array(runtime_owner.get("bowling_traps"))
	var projectiles: Array = CommandoFirearmValueUtils.get_array(runtime_owner.get("projectiles"))
	var shell_casings: Array = CommandoFirearmValueUtils.get_array(runtime_owner.get("shell_casings"))

	CommandoFirearmMuzzleFlashResolver.append_runtime_flash(
		muzzle_flashes,
		origin,
		direction,
		profile,
		weapon_id,
		int(options.get("flash_limit", 24))
	)
	if kind == "support":
		var support_start: Dictionary = CommandoFirearmSupportCallResolver.append_runtime_start_effects(
			support_calls,
			impact_flashes,
			runtime_owner,
			origin,
			target,
			profile,
			weapon_id,
			int(options.get("support_call_limit", 4)),
			int(options.get("flash_limit", 24)),
			float(options.get("support_call_delay_min_frames", 120.0)),
			float(options.get("support_call_delay_max_frames", 180.0)),
			int(options.get("support_bomb_min_count", 2)),
			int(options.get("support_bomb_max_count", 2)),
			float(options.get("support_call_lock_frames", 42.0)),
			float(options.get("support_aircraft_drop_arm_frames", 42.0)),
			float(options.get("support_aircraft_y", 320.0)),
			float(options.get("support_aircraft_speed", 10.8)),
			float(options.get("support_aircraft_curve_amplitude", 44.0)),
			float(options.get("support_aircraft_curve_frequency", 0.055)),
			float(options.get("support_aircraft_curve_secondary_ratio", 0.35)),
			float(options.get("support_aircraft_start_x", -360.0))
		)
		_write_spawn_arrays(runtime_owner, muzzle_flashes, support_calls, impact_flashes, bowling_traps, projectiles, shell_casings)
		CommandoFirearmAudioDispatcher.dispatch_support_call_start_audio(support_start, deps)
		support_start["spawn_kind"] = "support"
		return support_start

	if kind == "trap" or weapon_id == "bowling_trap":
		CommandoFirearmBowlingTrapGeometry.append_runtime_install_effects(
			bowling_traps,
			impact_flashes,
			runtime_owner,
			config,
			profile,
			weapon_id,
			float(options.get("field_width", 760.0)),
			float(options.get("field_height", 750.0)),
			float(options.get("bowling_trap_width", 60.0)),
			float(options.get("bowling_trap_height", 20.0)),
			float(options.get("bowling_trap_min_field_y_ratio", 0.6)),
			float(options.get("bowling_trap_install_frames", 48.0)),
			CommandoFirearmValueUtils.get_vector2(options.get("bowling_trap_capture_ball_offset", Vector2.ZERO), Vector2.ZERO),
			int(options.get("bowling_trap_limit", 6)),
			int(options.get("flash_limit", 24))
		)
		_write_spawn_arrays(runtime_owner, muzzle_flashes, support_calls, impact_flashes, bowling_traps, projectiles, shell_casings)
		return {"spawn_kind": "trap"}

	var projectile_result: Dictionary = CommandoFirearmProjectileSpawnState.append_runtime_projectile(
		projectiles,
		shell_casings,
		runtime_owner,
		weapon_id,
		kind,
		origin,
		target,
		direction,
		angle_offset,
		aim_origin,
		profile,
		doping_context,
		config,
		float(options.get("default_projectile_speed", 16.0)),
		int(options.get("bazooka_smoke_trail_limit", 0)),
		int(options.get("net_gun_rope_trail_limit", 0)),
		float(options.get("doping_potion_head_leg_multiplier", 1.0)),
		float(options.get("doping_potion_pistol_speed_multiplier", 1.0)),
		float(options.get("base_pistol_knockback_mult", 1.0)),
		int(options.get("projectile_limit", 36)),
		float(options.get("field_height", 750.0)),
		float(options.get("ak47_shell_lifetime_frames", 180.0)),
		float(options.get("pistol_shell_lifetime_frames", 150.0)),
		int(options.get("shell_casing_limit", 36))
	)
	_write_spawn_arrays(runtime_owner, muzzle_flashes, support_calls, impact_flashes, bowling_traps, projectiles, shell_casings)
	projectile_result["spawn_kind"] = "projectile"
	return projectile_result


static func _write_spawn_arrays(
	runtime_owner: Object,
	muzzle_flashes: Array,
	support_calls: Array,
	impact_flashes: Array,
	bowling_traps: Array,
	projectiles: Array,
	shell_casings: Array
) -> void:
	runtime_owner.set("muzzle_flashes", muzzle_flashes)
	runtime_owner.set("support_calls", support_calls)
	runtime_owner.set("impact_flashes", impact_flashes)
	runtime_owner.set("bowling_traps", bowling_traps)
	runtime_owner.set("projectiles", projectiles)
	runtime_owner.set("shell_casings", shell_casings)
