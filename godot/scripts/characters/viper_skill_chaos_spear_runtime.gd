extends RefCounted

const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")


static func try_command_activation(runtime: Object, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, now_msec: int, constants: Dictionary) -> Dictionary:
	var skill_name: String = str(constants.get("skill_name", "chaos_spear"))
	if runtime.chaos_state == "startup":
		var chaos_startup_pos: Vector2 = ViperSkillGeometry.locked_startup_player_pos(player_pos, runtime.chaos_locked_player_x_valid, runtime.chaos_locked_player_x, config)
		return {"handled": true, "activated": false, "skill_name": skill_name, "player_pos": chaos_startup_pos, "player_speed": 0.0, "special_gauge": special_gauge, "allow_jetpack_overlay": true, "locked_player_x": chaos_startup_pos.x}
	var chaos_command_ready: bool = runtime.command_tracker.consume_chaos_command_ready(runtime, now_msec, int(constants.get("command_window_msec", 600)))
	if chaos_command_ready and can_start(runtime, special_gauge, config, deps, now_msec, constants):
		return start(runtime, player_pos, special_gauge, config, deps, now_msec, constants)
	return {}


static func can_start(runtime: Object, special_gauge: float, config: Dictionary, deps: Dictionary, now_msec: int, constants: Dictionary) -> bool:
	if runtime.chaos_state != "idle" or runtime.visibility_query.is_control_locked(deps) or not bool(config.get("ball_active", false)):
		return false
	var jetpack_state: Object = deps.get("viper_jetpack_state", null)
	if (jetpack_state != null and jetpack_state.has_method("is_airborne") and bool(jetpack_state.is_airborne(2.0))) or runtime.visibility_query.is_round_waiting_for_serve(deps):
		return false
	var skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
	return runtime._can_activate_configured_skill(skill_config, special_gauge, deps, str(constants.get("skill_name", "chaos_spear")), now_msec)


static func start(runtime: Object, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, now_msec: int, constants: Dictionary) -> Dictionary:
	var skill_name: String = str(constants.get("skill_name", "chaos_spear"))
	var skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
	var next_gauge: float = max(0.0, special_gauge - runtime.visibility_query.get_skill_cost(skill_config, skill_name))
	var player_center: Vector2 = ViperSkillGeometry.player_center(player_pos, config)
	var ball_pos: Vector2 = ViperSkillGeometry.get_ball_pos(config)
	runtime.chaos_target = Vector2(float(config.get("width", 760.0)) * 0.5, float(config.get("height", 750.0)) * 0.5 + 60.0)
	runtime.chaos_origin = Vector2(player_center.x, player_pos.y - 6.0)
	runtime.chaos_current = runtime.chaos_origin
	runtime.chaos_phase_frames = 0.0
	runtime.chaos_prev_ball_valid = false
	runtime.chaos_blackhole_origin_valid = false
	runtime.chaos_base_radius = clamp(ball_pos.distance_to(runtime.chaos_target), 84.0, 264.0)
	runtime.chaos_orbit_seed = randf_range(0.0, TAU)
	runtime.chaos_flight_angle = (runtime.chaos_target - runtime.chaos_origin).angle()
	runtime.chaos_impact_seed = randf_range(0.0, TAU)
	runtime.chaos_locked_player_x = player_pos.x
	runtime.chaos_locked_player_x_valid = true
	runtime.chaos_absorb_poll_frames = 0.0
	runtime.chaos_gold_ticks_paid = 0
	runtime.chaos_explosion_shaken = false
	runtime.chaos_release_pending = false
	runtime.chaos_release_velocity = Vector2.ZERO
	runtime.chaos_state = "startup"
	var cooldown_seconds: float = runtime._get_skill_cooldown_seconds_with_fallback(skill_config, skill_name, float(constants.get("cooldown_seconds", 30.0)))
	cooldown_seconds = runtime._get_four_poisons_additive_cooldown_seconds(skill_name, skill_config, deps, cooldown_seconds)
	runtime.runtime_action_router.trigger_viper_runtime_cooldown(skill_name, now_msec, skill_config, deps, cooldown_seconds, runtime.visibility_query)
	runtime._trigger_orb_gauge_spin(deps, now_msec)
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(0.08, 3.5)
	runtime.audio_router.play_chaos_windup_sound(deps)
	return {"handled": true, "activated": true, "skill_name": skill_name, "player_pos": Vector2(runtime.chaos_locked_player_x, player_pos.y), "player_speed": 0.0, "special_gauge": next_gauge, "allow_jetpack_overlay": true, "locked_player_x": runtime.chaos_locked_player_x}


static func update_effects(runtime: Object, fps_scale: float, context: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	runtime.chaos_spear_effect_renderer.update_chaos_absorb_pulses(runtime.chaos_absorb_pulses, runtime.chaos_target, fps_scale)
	if runtime.chaos_cancel_flash_frames > 0.0:
		runtime.chaos_cancel_flash_frames = max(0.0, runtime.chaos_cancel_flash_frames - fps_scale)
	if runtime.chaos_state != "idle" and (runtime.visibility_query.should_stop_viper_context_effect(context) or runtime.visibility_query.is_round_waiting_for_serve(deps)):
		runtime._reset_chaos_spear_runtime(true, deps)
		return {}
	if runtime.chaos_state == "idle":
		return {}
	runtime.chaos_phase_frames += fps_scale
	match runtime.chaos_state:
		"startup":
			_update_startup(runtime, fps_scale, context, deps, constants)
		"flying":
			_update_flying(runtime, deps, constants)
		"impact":
			_update_impact(runtime, context, deps, constants)
		"blackhole":
			if runtime.chaos_phase_frames >= float(constants.get("blackhole_frames", 180.0)):
				runtime._release_chaos_blackhole(false, context, deps)
		"fade":
			if runtime.chaos_phase_frames >= float(constants.get("fade_frames", 25.2)):
				runtime.audio_router.stop_chaos_blackhole_sound(deps)
				runtime._reset_chaos_spear_runtime(false)
	return {}


static func _update_startup(runtime: Object, _fps_scale: float, context: Dictionary, deps: Dictionary, constants: Dictionary) -> void:
	var player_pos: Vector2 = _get_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	runtime.chaos_current = Vector2(player_pos.x + player_size.x * 0.5, player_pos.y - 6.0)
	var prep_values: Array = constants.get("prep_reduction_values", [])
	var prep_reduction_pct: float = float(runtime._get_four_poisons_scaled_pct(deps, prep_values, int(constants.get("prep_reduction_cap", 70)), int(constants.get("prep_reduction_per_extra", 4))))
	var chaos_startup_frames: float = max(1.0, float(constants.get("startup_frames", 45.0)) * max(0.0, 1.0 - prep_reduction_pct / 100.0))
	if runtime.chaos_phase_frames >= chaos_startup_frames:
		runtime.audio_router.stop_chaos_windup_sound(deps)
		runtime.chaos_state = "flying"; runtime.chaos_phase_frames = 0.0; runtime.chaos_origin = runtime.chaos_current; runtime.chaos_flight_angle = (runtime.chaos_target - runtime.chaos_origin).angle(); runtime.chaos_locked_player_x_valid = false
		runtime.audio_router.play_chaos_flying_sound(deps)


static func _update_flying(runtime: Object, deps: Dictionary, constants: Dictionary) -> void:
	var travel_t: float = clamp(runtime.chaos_phase_frames / max(1.0, float(constants.get("travel_frames", 16.8))), 0.0, 1.0)
	var ease_t: float = 1.0 - pow(1.0 - travel_t, 3.0)
	runtime.chaos_current = runtime.chaos_origin.lerp(runtime.chaos_target, ease_t)
	if travel_t >= 1.0:
		runtime.audio_router.stop_chaos_flying_sound(deps)
		runtime.chaos_state = "impact"; runtime.chaos_phase_frames = 0.0; runtime.chaos_current = runtime.chaos_target; runtime.chaos_impact_seed = randf_range(0.0, TAU); runtime.chaos_explosion_shaken = false
		runtime.runtime_action_router.trigger_feedback(deps, 0.23, 5.5)
		runtime.audio_router.play_chaos_impact_sound(deps)
		runtime.audio_router.play_chaos_blackhole_sound(deps)


static func _update_impact(runtime: Object, context: Dictionary, deps: Dictionary, constants: Dictionary) -> void:
	var impact_frames: float = float(constants.get("impact_frames", 21.6))
	if runtime.chaos_phase_frames >= impact_frames * 0.45 and not runtime.chaos_explosion_shaken:
		runtime.chaos_explosion_shaken = true
		runtime.runtime_action_router.trigger_feedback(deps, 0.40, 8.0)
	if runtime.chaos_phase_frames >= impact_frames:
		runtime.chaos_state = "blackhole"; runtime.chaos_phase_frames = 0.0; runtime.chaos_current = runtime.chaos_target
		var ball_pos: Vector2 = _get_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
		runtime.chaos_prev_ball_center = ball_pos; runtime.chaos_prev_ball_valid = true; runtime.chaos_blackhole_ball_origin = runtime.chaos_prev_ball_center; runtime.chaos_blackhole_origin_valid = true; runtime.chaos_absorb_poll_frames = 0.0; runtime.chaos_gold_ticks_paid = 0; runtime.chaos_fx_spawn_msec_seed = Time.get_ticks_msec()


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
