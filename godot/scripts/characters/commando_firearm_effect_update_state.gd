extends RefCounted

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const CommandoFirearmBowlingTrapGeometry := preload("res://scripts/characters/commando_firearm_bowling_trap_geometry.gd")
const CommandoFirearmLingeringEffectState := preload("res://scripts/characters/commando_firearm_lingering_effect_state.gd")
const CommandoFirearmPendingResultState := preload("res://scripts/characters/commando_firearm_pending_result_state.gd")
const CommandoFirearmPistolFeedbackState := preload("res://scripts/characters/commando_firearm_pistol_feedback_state.gd")
const CommandoFirearmProjectileMotionState := preload("res://scripts/characters/commando_firearm_projectile_motion_state.gd")
const CommandoFirearmShellCasingState := preload("res://scripts/characters/commando_firearm_shell_casing_state.gd")
const CommandoFirearmSupportProjectileResolver := preload("res://scripts/characters/commando_firearm_support_projectile_resolver.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")


static func advance_runtime_effects(
	runtime_owner: Object,
	fps_scale: float,
	context: Dictionary,
	deps: Dictionary,
	options: Dictionary
) -> Dictionary:
	if runtime_owner == null:
		return {}
	var field_size := Vector2(float(options.get("field_width", 760.0)), float(options.get("field_height", 750.0)))
	var muzzle_flashes: Array = CommandoFirearmValueUtils.advance_timed_effects(
		CommandoFirearmValueUtils.get_array(runtime_owner.get("muzzle_flashes")),
		fps_scale
	)
	runtime_owner.set("muzzle_flashes", muzzle_flashes)

	var support_calls: Array = CommandoFirearmValueUtils.get_array(runtime_owner.get("support_calls"))
	var projectiles: Array = CommandoFirearmValueUtils.get_array(runtime_owner.get("projectiles"))
	CommandoFirearmSupportProjectileResolver.advance_runtime_support_calls(
		support_calls,
		projectiles,
		runtime_owner,
		context,
		deps,
		fps_scale,
		CommandoFirearmValueUtils.get_dict(options.get("weapon_profiles", {})),
		CommandoFirearmValueUtils.get_dict(options.get("weapon_profile_overrides", {})),
		field_size,
		float(options.get("support_aircraft_start_x", -360.0)),
		float(options.get("support_aircraft_y", 320.0)),
		float(options.get("support_aircraft_speed", 10.8)),
		float(options.get("support_bomb_interval_frames", 18.0)),
		float(options.get("support_aircraft_finish_margin", 360.0)),
		float(options.get("support_aircraft_curve_amplitude", 44.0)),
		float(options.get("support_aircraft_curve_frequency", 0.055)),
		float(options.get("support_aircraft_curve_secondary_ratio", 0.35)),
		float(options.get("support_bomb_initial_vy", 0.0)),
		float(options.get("support_bomb_gravity", 0.0)),
		float(options.get("support_bomb_horizontal_jitter", 0.0)),
		float(options.get("support_opponent_wall_y", 22.0)),
		float(options.get("support_missile_flight_frames", 90.0)),
		float(options.get("support_missile_life_frames", 150.0)),
		float(options.get("support_bomb_random_x_range", 300.0)),
		int(options.get("projectile_limit", 36))
	)
	runtime_owner.set("support_calls", support_calls)
	runtime_owner.set("projectiles", projectiles)

	var bowling_traps: Array = CommandoFirearmValueUtils.get_array(runtime_owner.get("bowling_traps"))
	var impact_flashes: Array = CommandoFirearmValueUtils.get_array(runtime_owner.get("impact_flashes"))
	var ball_motion_result: Dictionary = CommandoFirearmBowlingTrapGeometry.advance_runtime_bowling_traps(
		bowling_traps,
		impact_flashes,
		runtime_owner,
		context,
		deps,
		fps_scale,
		CommandoFirearmValueUtils.get_dict(options.get("weapon_profiles", {})),
		CommandoFirearmValueUtils.get_dict(options.get("weapon_profile_overrides", {})),
		CommandoFirearmValueUtils.get_dict(options.get("weapon_hit_feedback", {})),
		CommandoFirearmValueUtils.get_dict(options.get("hit_feedback_profile_overrides", {})),
		str(options.get("base_weapon_id", "pistol")),
		float(options.get("grenade_explosion_duration_frames", 0.0)),
		int(options.get("flash_limit", 24)),
		float(options.get("bowling_trap_install_frames", 48.0)),
		float(options.get("bowling_trap_capture_frames", 90.0)),
		CommandoFirearmValueUtils.get_vector2(options.get("bowling_trap_capture_ball_offset", Vector2.ZERO), Vector2.ZERO),
		float(options.get("bowling_trap_height", 20.0)),
		float(options.get("bowling_trap_capture_height", 40.0)),
		float(options.get("bowling_trap_width", 60.0)),
		float(options.get("trap_launch_speed_multiplier", 4.0)),
		float(options.get("trap_launch_fan_half_angle", 0.0)),
		float(options.get("bowling_trap_guard_speed_reduction", 0.7)),
		float(options.get("bowling_trap_guard_knockback_power", ActiveItemThrowController.DYNAMITE_BOSS_KNOCKBACK_POWER)),
		float(options.get("bowling_trap_guard_stun_frames", 150.0))
	)
	runtime_owner.set("bowling_traps", bowling_traps)
	runtime_owner.set("impact_flashes", impact_flashes)
	if not ball_motion_result.is_empty():
		context.merge(ball_motion_result, true)

	var projectile_result: Dictionary = CommandoFirearmProjectileMotionState.advance_runtime_projectiles(
		projectiles,
		impact_flashes,
		runtime_owner,
		fps_scale,
		context,
		deps,
		options
	)
	runtime_owner.set("projectiles", projectiles)
	runtime_owner.set("impact_flashes", impact_flashes)
	if not projectile_result.is_empty():
		context.merge(projectile_result, true)

	runtime_owner.set("shell_casings", CommandoFirearmShellCasingState.advance_shells(
		CommandoFirearmValueUtils.get_array(runtime_owner.get("shell_casings")),
		fps_scale,
		field_size.x,
		field_size.y,
		float(options.get("ak47_shell_gravity", 0.45)),
		float(options.get("ak47_shell_bounce_decay", 0.42)),
		int(options.get("ak47_shell_max_bounces", 2))
	))
	runtime_owner.set("pistol_feedbacks", CommandoFirearmPistolFeedbackState.advance_feedbacks(
		CommandoFirearmValueUtils.get_array(runtime_owner.get("pistol_feedbacks")),
		fps_scale
	))
	impact_flashes = CommandoFirearmValueUtils.advance_timed_effects(impact_flashes, fps_scale)
	runtime_owner.set("impact_flashes", impact_flashes)

	var lingering_result: Dictionary = CommandoFirearmLingeringEffectState.advance_runtime_effects(
		runtime_owner,
		context,
		deps,
		fps_scale,
		float(options.get("net_gun_dash_break_frames", 24.0)),
		float(options.get("lingering_effect_phase_step", 0.12)),
		field_size,
		CommandoFirearmValueUtils.get_vector2(options.get("net_gun_muzzle_source", Vector2.ZERO), Vector2.ZERO),
		CommandoFirearmValueUtils.get_vector2(options.get("fire_sheet_source_cell_size", Vector2.ZERO), Vector2.ZERO),
		float(options.get("fire_sheet_player_foot_y_offset", 0.0)),
		float(options.get("net_gun_width", 280.0)),
		float(options.get("net_gun_min_height", 90.0)),
		str(options.get("lingering_status_target", "boss")),
		str(options.get("lingering_status_id_slow", "slow")),
		float(options.get("lingering_status_duration_frames", 18.0)),
		float(options.get("lingering_status_interval_frames", 12.0)),
		float(options.get("lingering_status_slow_multiplier", 1.0)),
		float(options.get("lingering_status_min_slow_multiplier", 0.0)),
		float(options.get("lingering_status_max_slow_multiplier", 1.0)),
		str(options.get("lingering_status_source", "commando_firearm_lingering"))
	)
	if not lingering_result.is_empty():
		context.merge(lingering_result, true)

	var result: Dictionary = ball_motion_result.duplicate(true)
	if not projectile_result.is_empty():
		result.merge(projectile_result, true)
	if not lingering_result.is_empty():
		result.merge(lingering_result, true)
	var pending_result: Dictionary = CommandoFirearmPendingResultState.consume_runtime_pending_results(runtime_owner)
	if not pending_result.is_empty():
		result.merge(pending_result, true)
	return result
