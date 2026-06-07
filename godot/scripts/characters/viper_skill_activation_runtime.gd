extends RefCounted

const ViperSkillBladeMotionRuntime := preload("res://scripts/characters/viper_skill_blade_motion_runtime.gd")
const ViperSkillChaosSpearRuntime := preload("res://scripts/characters/viper_skill_chaos_spear_runtime.gd")
const ViperSkillCoreFlipRuntime := preload("res://scripts/characters/viper_skill_core_flip_runtime.gd")
const ViperSkillDualGlitchCloneRuntime := preload("res://scripts/characters/viper_skill_dual_glitch_clone_runtime.gd")
const ViperSkillEmpStrikeRuntime := preload("res://scripts/characters/viper_skill_emp_strike_runtime.gd")
const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")
const ViperSkillIgnitionAuraRuntime := preload("res://scripts/characters/viper_skill_ignition_aura_runtime.gd")
const ViperSkillShadowStepRuntime := preload("res://scripts/characters/viper_skill_shadow_step_runtime.gd")


static func try_activate_before_movement(runtime: Object, delta: float, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	var input_reader: Object = deps.get("input_reader", null)
	var input_snapshot: Dictionary = input_reader.get_snapshot() if input_reader != null else {}
	var now_msec: int = Time.get_ticks_msec()
	var command_skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
	var input_state: Dictionary = runtime.command_tracker.update_before_movement(runtime, input_snapshot, command_skill_config, deps, now_msec, _command_tracker_constants(constants))
	var down_pressed: bool = bool(input_state.get("down_pressed", false))
	var pressed_edge: bool = bool(input_state.get("pressed_edge", false))
	var up_pressed: bool = bool(input_state.get("up_pressed", false))
	var up_edge: bool = bool(input_state.get("up_edge", false))
	if runtime.nerve_strike_active:
		return runtime._update_nerve_strike(delta, player_pos, special_gauge, config, deps)
	if runtime.dual_glitch_state == "startup":
		var dual_startup_pos: Vector2 = ViperSkillGeometry.locked_startup_player_pos(player_pos, runtime.dual_glitch_locked_player_x_valid, runtime.dual_glitch_locked_player_x, config)
		runtime.dual_glitch_base_pos = dual_startup_pos
		return {"handled": true, "activated": false, "skill_name": str(constants.get("dual_glitch", "dual_glitch")), "player_pos": dual_startup_pos, "player_speed": 0.0, "special_gauge": special_gauge, "locked_player_x": dual_startup_pos.x}
	if runtime.dive_active:
		return runtime._update_dive_strike(delta, player_pos, special_gauge, config, deps)
	if runtime.core_flip_attack_active:
		if up_edge and runtime._can_start_dark_blade_from_window(special_gauge, config, deps):
			var core_flip_blade_handoff_pos: Vector2 = runtime.core_flip_visual_pos
			runtime._reset_core_flip_runtime(false)
			return runtime._start_blade_motion(core_flip_blade_handoff_pos, special_gauge, config, deps, true, now_msec)
		return runtime._update_core_flip(delta, player_pos, special_gauge, config, deps)
	var core_flip_activation_result: Dictionary = ViperSkillCoreFlipRuntime.try_ready_activation(runtime, input_snapshot, player_pos, special_gauge, config, deps, now_msec, _core_flip_constants(constants))
	if not core_flip_activation_result.is_empty():
		return core_flip_activation_result
	var dual_glitch_activation_result: Dictionary = ViperSkillDualGlitchCloneRuntime.try_command_activation(runtime, player_pos, special_gauge, config, deps, now_msec, _dual_glitch_constants(constants))
	if not dual_glitch_activation_result.is_empty():
		return dual_glitch_activation_result
	var blade_followup_activation_result: Dictionary = ViperSkillBladeMotionRuntime.try_phase2_followup_activation(runtime, up_edge, player_pos, special_gauge, config, deps, now_msec, _blade_followup_constants(constants))
	if not blade_followup_activation_result.is_empty():
		return blade_followup_activation_result
	var chaos_activation_result: Dictionary = ViperSkillChaosSpearRuntime.try_command_activation(runtime, player_pos, special_gauge, config, deps, now_msec, _chaos_constants(constants))
	if not chaos_activation_result.is_empty():
		return chaos_activation_result
	var ignition_hold_result: Dictionary = ViperSkillIgnitionAuraRuntime.try_hold_activation(runtime, up_pressed, input_snapshot, player_pos, special_gauge, config, deps, now_msec, _ignition_constants(constants))
	if not ignition_hold_result.is_empty():
		return ignition_hold_result
	runtime.shadow_step_ready_frames = max(0.0, runtime.shadow_step_ready_frames - delta * 60.0)
	if runtime.blade_motion_active:
		return runtime._update_blade_motion(delta, player_pos, special_gauge, config, deps)
	if runtime.marshal_active:
		if up_edge and runtime._can_start_dark_blade_from_window(special_gauge, config, deps):
			var marshal_blade_handoff_pos: Vector2 = runtime.marshal_visual_pos
			runtime._reset_marshal_runtime_fields()
			runtime._clear_dmk_presentation_state()
			runtime.marshal_particles.clear()
			return runtime._start_blade_motion(marshal_blade_handoff_pos, special_gauge, config, deps, true, now_msec)
		return runtime._update_marshal_kick(delta, player_pos, special_gauge, config, deps)
	var dive_hold_result: Dictionary = ViperSkillEmpStrikeRuntime.try_hold_activation(runtime, down_pressed, input_snapshot, player_pos, special_gauge, config, deps, now_msec, _dive_constants(constants))
	if not dive_hold_result.is_empty():
		return dive_hold_result
	if pressed_edge:
		var marshal_skill_name: String = runtime.visibility_query.get_marshal_skill_to_fire(runtime, str(constants.get("marshal_kick", "marshal_kick")), str(constants.get("phantom_kick", "phantom_kick")))
		if marshal_skill_name != "" and not runtime.visibility_query.is_control_locked(deps) and not runtime._has_lateral_skill_input(input_snapshot):
			var marshal_skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
			if runtime.visibility_query.is_skill_equipped(marshal_skill_config, marshal_skill_name) and special_gauge >= runtime.visibility_query.get_marshal_skill_cost(marshal_skill_config, marshal_skill_name, str(constants.get("phantom_kick", "phantom_kick"))) and runtime.visibility_query.is_configured_skill_ready(marshal_skill_name, deps, -1):
				return runtime._start_marshal_kick(marshal_skill_name, player_pos, special_gauge, config, deps)
	if up_edge:
		if runtime._can_start_dark_blade_from_window(special_gauge, config, deps):
			return runtime._start_blade_motion(player_pos, special_gauge, config, deps, true, now_msec)
		var can_start_air_blade: bool = not runtime._has_viper_attack_motion_active() and runtime.chaos_state != "startup" and not runtime.dark_blade_window and bool(config.get("ball_active", true)) and runtime.visibility_query.is_viper_airborne(deps) and not runtime.visibility_query.is_control_locked(deps)
		if can_start_air_blade:
			var air_blade_skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
			var blade_rush: String = str(constants.get("blade_rush", "blade_rush"))
			if runtime.visibility_query.is_skill_equipped(air_blade_skill_config, blade_rush) and special_gauge >= runtime._get_blade_skill_cost(air_blade_skill_config, deps, blade_rush) and runtime.visibility_query.is_configured_skill_ready(blade_rush, deps, -1):
				return runtime._start_blade_motion(player_pos, special_gauge, config, deps, false, now_msec)
	var shadow_step_activation_result: Dictionary = ViperSkillShadowStepRuntime.try_dash_activation(runtime, pressed_edge, input_snapshot, player_pos, special_gauge, config, deps, now_msec, _shadow_step_constants(constants))
	if not shadow_step_activation_result.is_empty():
		return shadow_step_activation_result
	return {"handled": false, "activated": false, "special_gauge": special_gauge}


static func _command_tracker_constants(constants: Dictionary) -> Dictionary:
	return {"dual_glitch": str(constants.get("dual_glitch", "dual_glitch")), "dual_glitch_window_msec": int(constants.get("dual_glitch_window_msec", 1200)), "chaos_spear": str(constants.get("chaos_spear", "chaos_spear")), "chaos_cmd_buffer_max": int(constants.get("chaos_cmd_buffer_max", 6))}


static func _core_flip_constants(constants: Dictionary) -> Dictionary:
	return {"skill_name": str(constants.get("core_flip", "core_flip")), "ready_window_msec": int(constants.get("core_flip_ready_window_msec", 700)), "input_frame_gap": int(constants.get("core_flip_input_frame_gap", 4)), "input_max_age_frames": int(constants.get("core_flip_input_max_age_frames", 16)), "fallback_cost": float(constants.get("core_flip_fallback_cost", 120.0)), "start_shake_amount": float(constants.get("core_flip_start_shake_amount", 0.14)), "start_shake_intensity": float(constants.get("core_flip_start_shake_intensity", 4.5)), "apex_offset_y": float(constants.get("core_flip_apex_offset_y", -30.0))}


static func _dual_glitch_constants(constants: Dictionary) -> Dictionary:
	return {"skill_name": str(constants.get("dual_glitch", "dual_glitch")), "command_window_msec": int(constants.get("dual_glitch_window_msec", 1200)), "active_frames": float(constants.get("dual_glitch_active_frames", 900.0)), "duration_pct_values": constants.get("dual_glitch_duration_pct_values", []), "duration_pct_cap": int(constants.get("dual_glitch_duration_pct_cap", 45)), "duration_pct_per_extra": int(constants.get("dual_glitch_duration_pct_per_extra", 5)), "clone_hp_values": constants.get("dual_glitch_clone_hp_values", []), "clone_hp_cap": int(constants.get("dual_glitch_clone_hp_cap", 6)), "cooldown_seconds": float(constants.get("dual_glitch_cooldown_seconds", 40.0))}


static func _blade_followup_constants(constants: Dictionary) -> Dictionary:
	return {"blade_rush": str(constants.get("blade_rush", "blade_rush")), "dark_blade": str(constants.get("dark_blade", "dark_blade")), "nerve_strike": str(constants.get("nerve_strike", "nerve_strike")), "nerve_window_start_frames": float(constants.get("nerve_window_start_frames", 66.0)), "nerve_window_end_frames": float(constants.get("nerve_window_end_frames", 102.0)), "nerve_dark_blade_split_frames": float(constants.get("nerve_dark_blade_split_frames", 84.0)), "nerve_fallback_cost": float(constants.get("nerve_fallback_cost", 90.0)), "nerve_cooldown_base": float(constants.get("nerve_cooldown_base", 35.0))}


static func _chaos_constants(constants: Dictionary) -> Dictionary:
	return {"skill_name": str(constants.get("chaos_spear", "chaos_spear")), "command_window_msec": int(constants.get("chaos_cmd_window_msec", 600))}


static func _ignition_constants(constants: Dictionary) -> Dictionary:
	return {"skill_name": str(constants.get("ignition_aura", "ignition_aura")), "hold_required_msec": int(constants.get("ignition_hold_required_msec", 500)), "duration_frames": float(constants.get("ignition_duration_frames", 1500.0)), "gauge_cost": float(constants.get("ignition_gauge_cost", 230.0)), "particle_limit": int(constants.get("ignition_particle_limit", 180)), "charge_particle_limit": int(constants.get("ignition_charge_particle_limit", 80)), "fallback_cooldown_seconds": float(constants.get("ignition_fallback_cooldown_seconds", 70.0))}


static func _dive_constants(constants: Dictionary) -> Dictionary:
	return {"skill_name": str(constants.get("dive_strike", "dive_strike")), "gauge_cost": float(constants.get("dive_gauge_cost", 150.0)), "hold_required_msec": int(constants.get("dive_hold_required_msec", 300)), "charge_particle_limit": int(constants.get("dive_charge_particle_limit", 80)), "min_airborne_height": float(constants.get("dive_min_airborne_height", 20.0))}


static func _shadow_step_constants(constants: Dictionary) -> Dictionary:
	return {"skill_name": str(constants.get("shadow_step", "shadow_step")), "ready_frames": float(constants.get("shadow_step_ready_frames", 60.0)), "kick_ready_frames": float(constants.get("shadow_step_kick_ready_frames", 300.0)), "phantom_frames": float(constants.get("shadow_step_phantom_frames", 18.0))}
