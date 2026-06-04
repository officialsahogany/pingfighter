extends RefCounted


static func reset_round(runtime: Object, deps: Dictionary, constants: Dictionary) -> void:
	var preserve_ignition_aura: bool = bool(deps.get("preserve_ignition_aura", true)) and bool(runtime.ignition_active) and float(runtime.ignition_remaining_frames) > 0.0
	var preserve_dual_glitch: bool = bool(deps.get("preserve_dual_glitch", true)) and runtime.dual_glitch_state in ["spawn", "active"] and runtime.visibility_query.has_living_dual_glitch_clone(runtime.dual_glitch_clones)
	runtime.previous_down_pressed = false; runtime.previous_left_pressed = false; runtime.previous_up_pressed = false; runtime.previous_right_pressed = false; runtime.input_sequence_frame = 0; runtime.core_flip_left_press_frame = int(constants.get("core_flip_input_frame_unset", -100000)); runtime.core_flip_right_press_frame = int(constants.get("core_flip_input_frame_unset", -100000))
	runtime.previous_dash_active = false; runtime.previous_dash_recovering = false; runtime.dash_origin_pos = Vector2.ZERO; runtime.dash_origin_valid = false; runtime.dash_grace_frames = 0.0; runtime.shadow_step_ready_frames = 0.0; runtime.shadow_step_activation_msec = int(constants.get("shadow_step_activation_unset_msec", -100000))
	runtime.shadow_hologram_active = false; runtime.shadow_hologram_frames = 0.0; runtime.shadow_hologram_origin = Vector2.ZERO; runtime.shadow_hologram_target = Vector2.ZERO; runtime.shadow_hologram_kick_dir = 1; runtime.shadow_hologram_kick_hit = false; runtime.shadow_hologram_dest_shock_spawned = false; runtime.shadow_paddle_size = Vector2(155.0, 50.0); runtime.shadow_wave_active = false; runtime.shadow_wave_pos = Vector2.ZERO; runtime.shadow_wave_target_x = 0.0; runtime.shadow_wave_dir = 1; runtime.shadow_wave_hit_ball = false
	runtime.shadow_wave_trail.clear()
	runtime._clear_shadow_kick_ready()
	runtime.shadow_hit_consumed = false; runtime.shadow_was_airborne = false; runtime.shadow_marshal_delay_frames = 0.0; runtime.shadow_marshal_delay_from_shadow_step = false; runtime.shadow_curve_active = false; runtime.shadow_curve_timer = 0.0; runtime.shadow_curve_total = 0.0; runtime.shadow_curve_force = 0.0; runtime.shadow_curve_dir = 1; runtime.shadow_starburst_active = false; runtime.shadow_starburst_pos = Vector2.ZERO; runtime.shadow_starburst_frame = 0; runtime.shadow_starburst_timer = 0.0; runtime.shadow_starburst_is_double = false; runtime.phantom_strike_active = false; runtime.phantom_strike_frames = 0.0; runtime.phantom_strike_curve_dir = 1
	runtime._clear_marshal_ready_window()
	runtime.marshal_phantom_allowed = false
	runtime._clear_double_marshal_ready_window()
	runtime._clear_marshal_first_hit_pending()
	runtime.marshal_from_shadow_step_chain = false; runtime.phantom_kick_knockback_pending = false; runtime.phantom_kick_speed_limit_disabled = false; runtime.kick_skill_knockback_pending_pct = 0
	if runtime.cutin_state != null and runtime.cutin_state.has_method("reset"):
		runtime.cutin_state.reset()
	runtime._clear_dmk_presentation_state()
	runtime.venom_edge_strike_active = false; runtime.venom_edge_strike_elapsed_frames = 0.0; runtime.venom_edge_stationary_active = false
	runtime._reset_core_flip_runtime(true)
	runtime._reset_chaos_spear_runtime(true, deps)
	if preserve_dual_glitch:
		runtime.dual_glitch_cmd_buffer.clear(); runtime.dual_glitch_locked_player_x_valid = false; runtime.dual_glitch_clone_dive_entries.clear()
	else:
		runtime._reset_dual_glitch_runtime(true)
	if preserve_ignition_aura:
		runtime._reset_ignition_aura_hold(); runtime.ignition_burst_particles.clear(); runtime.ignition_charge_particles.clear(); runtime.ignition_live_embers.clear(); runtime.ignition_ember_timer = 0.0; runtime._set_runtime_ignition_aura_bonus(deps, true)
	else:
		runtime._set_runtime_ignition_aura_bonus(deps, false); runtime._reset_ignition_aura_hold()
		runtime.ignition_active = false; runtime.ignition_remaining_frames = 0.0; runtime.ignition_total_frames = float(constants.get("ignition_duration_frames", 0.0)); runtime.ignition_player_pos = Vector2.ZERO; runtime.ignition_paddle_size = Vector2(155.0, 50.0)
		runtime.ignition_burst_particles.clear(); runtime.ignition_charge_particles.clear(); runtime.ignition_live_embers.clear(); runtime.ignition_ember_timer = 0.0; runtime.ignition_start_msec = 0
	runtime._reset_nerve_strike_runtime(true)
	runtime._reset_blade_motion_only()
	runtime._clear_blade_projectile()
	runtime.clear_blade_hit_speed_cap()
	runtime.dark_blade_window = false; runtime.dark_blade_window_frames = 0.0; runtime.nerve_strike_combo_used = false; runtime.blade_followup_projectiles.clear()
	runtime._reset_dive_runtime(true)
	runtime._reset_marshal_runtime_fields()
	runtime.marshal_particles.clear(); runtime.phantom_hit_particles.clear()
