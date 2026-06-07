extends RefCounted

const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")


static func try_hold_activation(runtime: Object, up_pressed: bool, input_snapshot: Dictionary, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, now_msec: int, constants: Dictionary) -> Dictionary:
	var skill_name: String = str(constants.get("skill_name", "ignition_aura"))
	var can_hold: bool = up_pressed and not (runtime.ignition_active or runtime.dive_active or runtime.dive_hold_start_msec > 0 or runtime.dual_glitch_state != "idle" or runtime._has_viper_attack_motion_active() or runtime.chaos_state != "idle" or runtime.shadow_hologram_active or runtime.shadow_wave_active or runtime.shadow_marshal_delay_frames > 0.0 or runtime.phantom_strike_active or runtime.marshal_ready or runtime.double_marshal_ready or runtime.visibility_query.is_dash_motion_busy(deps) or runtime.visibility_query.is_control_locked(deps) or not bool(config.get("ball_active", true)) or bool(config.get("waiting_for_serve", false)) or runtime.visibility_query.is_round_waiting_for_serve(deps) or bool(input_snapshot.get("down_pressed", false)) or runtime._has_lateral_skill_input(input_snapshot) or runtime.runtime_action_router.get_viper_airborne_height(deps, config, player_pos) > 5.0)
	if can_hold:
		var hold_skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
		can_hold = runtime.visibility_query.is_skill_equipped(hold_skill_config, skill_name) and special_gauge >= runtime._get_skill_cost_with_fallback(hold_skill_config, skill_name, float(constants.get("gauge_cost", 230.0))) and runtime.visibility_query.is_configured_skill_ready(skill_name, deps, now_msec)
	if not can_hold:
		runtime._reset_ignition_aura_hold()
		return {}
	if runtime.ignition_hold_start_msec <= 0:
		runtime.ignition_hold_start_msec = now_msec
		runtime.ignition_charge_particles.clear()
	runtime.ignition_hold_player_pos = player_pos
	runtime.ignition_hold_paddle_size = ViperSkillGeometry.get_paddle_size(config)
	var elapsed_msec: int = max(0, now_msec - runtime.ignition_hold_start_msec)
	runtime.ignition_hold_ratio = clamp(float(elapsed_msec) / float(constants.get("hold_required_msec", 500)), 0.0, 1.0)
	runtime.particle_drawer.spawn_ignition_charge_particles(runtime.ignition_charge_particles, player_pos, runtime.ignition_hold_paddle_size, runtime.ignition_hold_ratio, int(constants.get("charge_particle_limit", 80)))
	if elapsed_msec < int(constants.get("hold_required_msec", 500)):
		return {"handled": false, "activated": false, "special_gauge": special_gauge}
	runtime._reset_ignition_aura_hold()
	var start_skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
	var next_gauge: float = max(0.0, special_gauge - runtime._get_skill_cost_with_fallback(start_skill_config, skill_name, float(constants.get("gauge_cost", 230.0))))
	var skill_state: Object = runtime.visibility_query.get_viper_skill_state(deps)
	if skill_state != null:
		if skill_state.has_method("trigger_configured_cooldown"):
			skill_state.trigger_configured_cooldown(skill_name, now_msec, start_skill_config)
		elif skill_state.has_method("trigger_cooldown"):
			skill_state.trigger_cooldown(skill_name, now_msec, runtime._get_skill_cooldown_seconds_with_fallback(start_skill_config, skill_name, float(constants.get("fallback_cooldown_seconds", 70.0))))
	runtime._trigger_orb_gauge_spin(deps, now_msec)
	runtime.audio_router.play_ignition_aura_sound(deps)
	runtime.runtime_action_router.trigger_feedback(deps, 0.14, 4.2)
	runtime.ignition_active = true
	runtime.ignition_total_frames = float(constants.get("duration_frames", 1500.0))
	runtime.ignition_remaining_frames = runtime.ignition_total_frames
	runtime.ignition_player_pos = player_pos
	runtime.ignition_paddle_size = ViperSkillGeometry.get_paddle_size(config)
	runtime.ignition_ember_timer = 0.0
	runtime.ignition_start_msec = now_msec
	runtime._set_runtime_ignition_aura_bonus(deps, true)
	runtime.particle_drawer.spawn_ignition_aura_burst(runtime.ignition_burst_particles, player_pos + ViperSkillGeometry.get_paddle_size(config) * 0.5, int(constants.get("particle_limit", 180)))
	return {"handled": true, "activated": true, "skill_name": skill_name, "player_pos": player_pos, "player_speed": 0.0, "special_gauge": next_gauge}


static func update_effects(runtime: Object, fps_scale: float, context: Dictionary, deps: Dictionary, constants: Dictionary) -> void:
	runtime.particle_drawer.update_ignition_particle_array(runtime.ignition_charge_particles, fps_scale)
	runtime.particle_drawer.update_ignition_particle_array(runtime.ignition_burst_particles, fps_scale)
	runtime.particle_drawer.update_ignition_particle_array(runtime.ignition_live_embers, fps_scale)
	if not runtime.ignition_active:
		return
	var character_type := ""
	if context.has("selected_character_type"):
		character_type = str(context.get("selected_character_type", "viper")).strip_edges().to_lower()
	if character_type != "" and character_type != "viper":
		_deactivate(runtime, deps)
		return
	runtime.ignition_player_pos = _get_vector2(context.get("player_pos", runtime.ignition_player_pos), runtime.ignition_player_pos)
	runtime.ignition_paddle_size = _get_vector2(context.get("player_paddle_size", runtime.ignition_paddle_size), runtime.ignition_paddle_size)
	runtime._set_runtime_ignition_aura_bonus(deps, true)
	if bool(context.get("waiting_for_serve", false)) or not bool(context.get("ball_active", true)):
		return
	runtime.ignition_remaining_frames = max(0.0, runtime.ignition_remaining_frames - fps_scale)
	runtime.ignition_ember_timer -= fps_scale
	if runtime.ignition_ember_timer <= 0.0:
		runtime.ignition_ember_timer = float(constants.get("ember_interval_frames", 8.4))
		runtime.particle_drawer.spawn_ignition_live_embers(runtime.ignition_live_embers, runtime.ignition_player_pos, runtime.ignition_paddle_size, int(constants.get("ember_limit", 54)))
	if runtime.ignition_remaining_frames <= 0.0:
		_deactivate(runtime, deps)


static func _deactivate(runtime: Object, deps: Dictionary) -> void:
	runtime.ignition_active = false; runtime.ignition_remaining_frames = 0.0; runtime.ignition_ember_timer = 0.0; runtime._set_runtime_ignition_aura_bonus(deps, false)


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
