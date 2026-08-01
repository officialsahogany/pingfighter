extends RefCounted

const ViperSkillVisibilityQuery := preload("res://scripts/characters/viper_skill_visibility_query.gd")

var _visibility_query := ViperSkillVisibilityQuery.new()


func build_actor_draw_context(runtime: Object) -> Dictionary:
	var rotation_degrees: float = 0.0
	var marshal_in_kick_phase: bool = runtime.marshal_active and runtime.marshal_phase == 2
	var core_flip_in_kick_phase: bool = runtime.core_flip_attack_active and runtime.core_flip_attack_phase == 2
	var flying_kick_active: bool = marshal_in_kick_phase or core_flip_in_kick_phase
	var blade_in_spin_phase: bool = runtime.blade_motion_active and runtime.blade_motion_phase < 2
	var core_flip_in_spin_phase: bool = runtime.core_flip_attack_active and runtime.core_flip_attack_phase == 0
	var tumble_active: bool = blade_in_spin_phase or core_flip_in_spin_phase
	var blade_fire_active: bool = runtime.blade_motion_active and runtime.blade_motion_phase == 2
	var chaos_throw_active: bool = runtime.chaos_state == "startup"
	var flying_kick_dir: int = 0
	if marshal_in_kick_phase:
		flying_kick_dir = -runtime.marshal_wall_side
	elif core_flip_in_kick_phase:
		flying_kick_dir = runtime.core_flip_kick_dir
	var context := {
		"viper_blade_motion_active": runtime.blade_motion_active,
		"viper_blade_motion_phase": runtime.blade_motion_phase,
		"viper_blade_spin_angle_degrees": rotation_degrees,
		"viper_dive_active": runtime.dive_active,
		"viper_dive_phase": runtime.dive_phase,
		"viper_core_flip_attack_active": runtime.core_flip_attack_active,
		"viper_core_flip_attack_phase": runtime.core_flip_attack_phase,
		"viper_core_flip_spin_angle_degrees": runtime.core_flip_spin_angle_degrees,
		"viper_ignition_aura_active": runtime.ignition_active,
		"viper_ignition_aura_ratio": _visibility_query.get_ignition_aura_ratio(runtime),
		# Wall-cling visual must persist through both phase 1 (initial cling)
		# AND phase 6 (DMK / phantom-kick pre-kick freeze where the player is
		# held at marshal_wall_pos waiting for the freeze timer to expire).
		# Without phase 6, the freeze frames render as walk/idle and the
		# "PHANTOM KICK" text overlay shows over the wrong pose.
		# Wall-flight likewise covers phase 0 (initial flight to wall) and
		# phase 3 (reclimb to a new wall position before a double kick).
		"viper_marshal_wall_cling_active": runtime.marshal_active and (runtime.marshal_phase == 1 or runtime.marshal_phase == 6),
		"viper_marshal_wall_flight_active": runtime.marshal_active and (runtime.marshal_phase == 0 or runtime.marshal_phase == 3),
		"viper_marshal_flying_kick_active": marshal_in_kick_phase,
		"viper_flying_kick_active": flying_kick_active,
		"viper_flying_kick_dir": flying_kick_dir,
		"viper_tumble_active": tumble_active,
		"viper_blade_fire_active": blade_fire_active,
		"viper_chaos_throw_active": chaos_throw_active,
		"viper_marshal_wall_side": runtime.marshal_wall_side,
		"viper_venom_edge_strike_active": runtime.venom_edge_strike_active,
		"viper_venom_edge_strike_frame": _visibility_query.get_venom_edge_strike_frame(runtime, runtime.VENOM_EDGE_STRIKE_TOTAL_FRAMES),
		"viper_venom_edge_stationary_active": runtime.venom_edge_stationary_active,
		"viper_dual_glitch_state": runtime.dual_glitch_state,
		"viper_dual_glitch_phase_frames": runtime.dual_glitch_phase_frames,
		"viper_dual_glitch_fade_reason": runtime.dual_glitch_fade_reason,
		"viper_dual_glitch_clone_rects": runtime._get_dual_glitch_clone_rect_entries(false, true),
		"viper_dark_blade_chain_glow_ratio": clamp(runtime.dark_blade_window_frames / runtime.DARK_BLADE_WINDOW_FRAMES, 0.0, 1.0) if runtime.dark_blade_window else 0.0,
	}
	if runtime.dive_slip_timer > 0.0:
		var slip_ratio: float = clamp(runtime.dive_slip_timer / max(1.0, runtime.dive_slip_duration), 0.0, 1.0)
		context["viper_emp_slip_active"] = true
		context["viper_emp_slip_timer"] = runtime.dive_slip_timer
		context["viper_emp_slip_duration"] = runtime.dive_slip_duration
		context["viper_emp_slip_ratio"] = slip_ratio
		context["viper_emp_slip_vel"] = runtime.dive_slip_vel
	if runtime.dive_active:
		context["player_pos"] = runtime.dive_player_pos
		context["viper_jetpack_active"] = false
		context["viper_jetpack_airborne"] = runtime.dive_phase < 2
		context["viper_jetpack_offset_y"] = min(0.0, runtime.dive_player_pos.y - runtime.dive_floor_y)
		context["viper_jetpack_floor_y"] = runtime.dive_floor_y
	if runtime.nerve_strike_active:
		context["player_pos"] = runtime.nerve_strike_pos
		context["viper_jetpack_active"] = false
		context["viper_jetpack_airborne"] = runtime.nerve_strike_phase < 2
		context["viper_jetpack_offset_y"] = min(0.0, runtime.nerve_strike_pos.y - runtime.nerve_strike_floor_y)
		context["viper_jetpack_floor_y"] = runtime.nerve_strike_floor_y
		context["viper_nerve_strike_active"] = true
		context["viper_nerve_strike_phase"] = runtime.nerve_strike_phase
		context["viper_nerve_strike_hit_confirmed"] = runtime.nerve_strike_hit_confirmed
	if runtime.core_flip_attack_active:
		if not core_flip_in_kick_phase:
			rotation_degrees = fposmod(runtime.core_flip_spin_angle_degrees, 360.0)
			context["player_sprite_rotation_degrees"] = rotation_degrees
		context["player_walk_direction"] = runtime.core_flip_kick_dir
		return context
	if runtime.blade_motion_active and runtime.blade_motion_phase < 2:
		rotation_degrees = fposmod(rad_to_deg(runtime.blade_spin_angle), 360.0)
		context["viper_blade_spin_angle_degrees"] = rotation_degrees
		context["player_sprite_rotation_degrees"] = rotation_degrees
	return context


func build_ball_collision_context(runtime: Object) -> Dictionary:
	var context := {
		"viper_dmk_freeze_active": runtime.dmk_freeze_active,
		"viper_dmk_freeze_frames": runtime.dmk_freeze_frames,
		"viper_nerve_strike_freeze_active": runtime.nerve_strike_freeze_active,
		"viper_nerve_strike_freeze_frames": _visibility_query.get_nerve_strike_freeze_frames(runtime, runtime.NERVE_STRIKE_SLASH_HIT_FRAMES),
		"viper_core_flip_attack_active": runtime.core_flip_attack_active,
		"viper_knockback_overlay_active": runtime.is_kick_skill_knockback_ball_active(),
		"viper_dual_glitch_state": runtime.dual_glitch_state,
		"viper_dual_glitch_clone_rects": runtime._get_dual_glitch_clone_rect_entries(true, false),
	}
	if runtime.is_phantom_kick_speed_limit_disabled():
		context["speed_limit_disabled"] = true
		context["viper_phantom_kick_speed_limit_disabled"] = true
	if runtime.dive_active and runtime.dive_phase < 2:
		context["player_pos"] = runtime.dive_player_pos
		context["player_y"] = runtime.dive_player_pos.y
		context["viper_jetpack_active"] = false
		context["viper_jetpack_airborne"] = true
		context["viper_jetpack_offset_y"] = min(0.0, runtime.dive_player_pos.y - runtime.dive_floor_y)
		context["viper_jetpack_floor_y"] = runtime.dive_floor_y
	if runtime.blade_motion_active:
		# The blade-motion arc owns the player's vertical position through the spin/prep fall
		# AND the phase-2 jump-and-settle (air blade `blade_rush` and dark blade alike). The
		# jetpack is NOT ticked during blade motion — viper_player_controller.update returns on
		# the skill path before _apply_jetpack_update — so viper_jetpack_state.offset_y goes stale
		# and its get_ball_collision_context() injects that frozen floor_y+offset_y into the merged
		# ball-collision context (merged BEFORE this skill context in ball_update_controller). Without
		# re-anchoring, the paddle hit-point freezes at the stale jetpack height while the drawn
		# character rides the live arc, so the ball bounces off empty air above (entered-from-air) or
		# below the character during the come-down. Re-anchor the collision band to the live drawn
		# blade_motion_pos for every blade phase so the hit-point tracks the visible character.
		context["player_pos"] = runtime.blade_motion_pos
		context["player_y"] = runtime.blade_motion_pos.y
		context["player_paddle_size"] = runtime.blade_paddle_size
		# Upward-ball (ball_vel.y < 0) body contact stays gated to the dark-blade rise window only;
		# air blade keeps normal downward-only paddle semantics.
		if runtime.has_method("is_dark_blade_rising_contact_active") and bool(runtime.is_dark_blade_rising_contact_active()):
			context["viper_dark_blade_rising_contact_active"] = true
	return context


func build_boss_ai_context(runtime: Object) -> Dictionary:
	return {
		"viper_dmk_freeze_active": runtime.dmk_freeze_active,
		"viper_dmk_freeze_frames": runtime.dmk_freeze_frames,
		"viper_nerve_strike_freeze_active": runtime.nerve_strike_freeze_active,
		"viper_nerve_strike_freeze_frames": _visibility_query.get_nerve_strike_freeze_frames(runtime, runtime.NERVE_STRIKE_SLASH_HIT_FRAMES),
		"viper_emp_slip_active": runtime.dive_slip_timer > 0.0,
		"viper_emp_slip_runtime": runtime,
		"viper_emp_slip_vel": runtime.dive_slip_vel,
		"viper_kick_read_event_id": runtime.kick_read_event_id,
		"viper_kick_read_chained_event_id": runtime.kick_read_chained_event_id,
	}
