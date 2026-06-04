extends RefCounted

const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")


static func try_dash_activation(runtime: Object, pressed_edge: bool, input_snapshot: Dictionary, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, now_msec: int, constants: Dictionary) -> Dictionary:
	var skill_name: String = str(constants.get("skill_name", "shadow_step"))
	if not (pressed_edge and runtime.dash_origin_valid and runtime.dash_grace_frames > 0.0 and not runtime._has_lateral_skill_input(input_snapshot) and not (runtime.shadow_hologram_active or runtime.shadow_wave_active or runtime.shadow_marshal_delay_frames > 0.0) and not runtime.marshal_ready and not runtime.marshal_active and not runtime.core_flip_attack_active and not runtime.visibility_query.is_control_locked(deps)):
		return {}
	var shadow_skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
	if not runtime._can_activate_configured_skill(shadow_skill_config, special_gauge, deps, skill_name):
		return {}
	var shadow_start_skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
	var shadow_player_size: Vector2 = ViperSkillGeometry.get_paddle_size(config)
	var shadow_target_pos: Vector2 = ViperSkillGeometry.clamp_player_pos(runtime.dash_origin_pos, float(config.get("play_left", 0.0)), float(config.get("play_right", 760.0)), shadow_player_size.x)
	var shadow_origin_center: Vector2 = player_pos + shadow_player_size * 0.5
	var shadow_target_center: Vector2 = shadow_target_pos + shadow_player_size * 0.5
	var shadow_reverse_dir: int = 1 if shadow_target_center.x > shadow_origin_center.x else -1
	var shadow_next_gauge: float = max(0.0, special_gauge - runtime.visibility_query.get_skill_cost(shadow_start_skill_config, skill_name))
	runtime._trigger_configured_skill_cooldown(skill_name, shadow_start_skill_config, deps, now_msec)
	runtime._trigger_orb_gauge_spin(deps, now_msec)
	runtime._cancel_dash_until_key_release(deps.get("dash_state", null))
	runtime.audio_router.play_shadow_step_sound(deps)
	runtime.runtime_action_router.trigger_feedback(deps, 0.10, 5.0)
	runtime.particle_drawer.spawn_shadow_activation_feedback(shadow_origin_center, deps.get("impact_effects", null), 1.0)
	runtime.dash_origin_valid = false
	runtime.dash_grace_frames = 0.0
	runtime.previous_dash_active = false
	runtime.previous_dash_recovering = false
	runtime.shadow_step_ready_frames = float(constants.get("ready_frames", 60.0))
	runtime.shadow_step_activation_msec = now_msec
	runtime.shadow_paddle_size = shadow_player_size
	runtime.shadow_hologram_active = true
	runtime.shadow_hologram_frames = 0.0
	runtime.shadow_hologram_origin = shadow_origin_center
	runtime.shadow_hologram_target = shadow_target_center
	runtime.shadow_hologram_kick_dir = shadow_reverse_dir
	runtime.shadow_hologram_kick_hit = false
	runtime.shadow_hologram_dest_shock_spawned = false
	runtime.shadow_wave_active = true
	runtime.shadow_wave_pos = shadow_origin_center
	runtime.shadow_wave_target_x = shadow_target_center.x
	runtime.shadow_wave_dir = shadow_reverse_dir
	runtime.shadow_wave_hit_ball = false
	runtime.shadow_wave_trail.clear()
	runtime.shadow_kick_ready = true
	runtime.shadow_kick_ready_frames = float(constants.get("kick_ready_frames", 300.0))
	runtime.shadow_hit_consumed = false
	runtime.shadow_was_airborne = runtime.visibility_query.is_viper_airborne(deps)
	runtime.shadow_marshal_delay_frames = 0.0
	runtime.shadow_curve_active = false
	runtime.phantom_strike_active = true
	runtime.phantom_strike_frames = float(constants.get("phantom_frames", 18.0))
	runtime.phantom_strike_curve_dir = shadow_reverse_dir
	return {"handled": true, "activated": true, "player_pos": shadow_target_pos, "player_speed": 0.0, "special_gauge": shadow_next_gauge, "skill_name": skill_name}


static func apply_hit(runtime: Object, hit_center: Vector2, hit_size: Vector2, curve_dir: int, _source: String, scene: Dictionary, context: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	if runtime.shadow_hit_consumed:
		return {}
	runtime.shadow_hit_consumed = true
	runtime._clear_shadow_kick_ready()
	runtime.shadow_hologram_kick_hit = true
	runtime.shadow_wave_hit_ball = true
	runtime.phantom_strike_active = false
	runtime.phantom_strike_frames = 0.0
	runtime.shadow_marshal_delay_frames = float(constants.get("marshal_delay_frames", 18.0))
	runtime.shadow_marshal_delay_from_shadow_step = true
	if not runtime.core_flip_consumed and runtime.core_flip_last_dash_start_msec > int(constants.get("core_flip_dash_start_valid_after_msec", -99999)):
		runtime.core_flip_ready_msec = Time.get_ticks_msec()
		runtime.core_flip_buffered_until_msec = 0
	var skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
	if runtime.shadow_was_airborne and runtime.visibility_query.is_skill_equipped(skill_config, str(constants.get("dark_blade", "dark_blade"))):
		runtime._open_dark_blade_start_window()
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", context.get("ball_pos", Vector2.ZERO)), Vector2.ZERO)
	var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", context.get("ball_vel", Vector2.ZERO)), Vector2.ZERO)
	var hit_profile: Dictionary = ViperSkillGeometry.shadow_step_hit_profile(ball_pos, hit_center, hit_size, float(constants.get("hit_speed_min", 1.48)), float(constants.get("hit_speed_max", 1.96)), float(constants.get("hit_curve_min", 10.0)), float(constants.get("hit_curve_max", 50.0)), float(constants.get("hit_force_min", 0.4)), float(constants.get("hit_force_max", 2.0)))
	var center_t: float = float(hit_profile.get("center_t", 0.0))
	var speed_mult: float = float(hit_profile.get("speed_mult", constants.get("hit_speed_min", 1.48)))
	var curve_frames: float = float(hit_profile.get("curve_frames", constants.get("hit_curve_min", 10.0)))
	var curve_force: float = float(hit_profile.get("curve_force", constants.get("hit_force_min", 0.4)))
	var safe_dir: int = 1 if curve_dir >= 0 else -1
	var current_speed: float = ball_vel.length()
	var speed_bonus: float = 1.0 + float(runtime.visibility_query.get_runtime_skill_level(deps, "kick_enhance")) * 0.04
	var raw_multiplier: float = speed_mult * speed_bonus
	var multiplier: float = raw_multiplier
	var ball_physics: Object = deps.get("ball_physics", null)
	if ball_physics != null and ball_physics.has_method("apply_dampened_multiplier"):
		multiplier = float(ball_physics.apply_dampened_multiplier(current_speed, raw_multiplier))
	var next_speed: float = max(current_speed * multiplier, float(constants.get("min_hit_speed", 10.0)))
	var aim_level: int = runtime.visibility_query.get_runtime_skill_level(deps, "kick_enhance")
	var aim_ball_pos: Vector2 = ViperSkillGeometry.get_ball_pos(context)
	var boss_pos: Vector2 = _get_vector2(context.get("boss_pos", Vector2(float(context.get("width", 760.0)) * 0.5, 25.0)), Vector2(float(context.get("width", 760.0)) * 0.5, 25.0))
	var launch_angle: float = ViperSkillGeometry.aimed_kick_launch_angle(safe_dir, aim_ball_pos, boss_pos, aim_level, 0.24, 15.0)
	var next_vel: Vector2 = ViperSkillGeometry.aimed_kick_launch_velocity(next_speed, launch_angle)
	var released_chaos: bool = runtime._release_chaos_blackhole_from_hit_result(deps, context)
	runtime._set_shadow_curve(curve_frames, curve_force, safe_dir)
	runtime.audio_router.play_shadow_kick_sound(deps)
	var shake_amount: float = float(constants.get("shake_amount_base", 0.09)) + center_t * float(constants.get("shake_amount_center_bonus", 0.07))
	var shake_intensity: float = float(constants.get("shake_intensity_base", 3.2)) + center_t * float(constants.get("shake_intensity_center_bonus", 1.8))
	runtime.runtime_action_router.trigger_feedback(deps, shake_amount, shake_intensity)
	var energy_intensity: float = float(constants.get("energy_intensity_base", 0.62)) + center_t * float(constants.get("energy_intensity_center_bonus", 0.30))
	if not runtime._register_ball_hit_pulse(ball_pos, next_vel, deps, energy_intensity, "viper_shadow_step"):
		var particle_intensity: float = float(constants.get("particle_intensity_base", 0.72)) + center_t * float(constants.get("particle_intensity_center_bonus", 0.36))
		var energy_scale: float = float(constants.get("energy_scale_base", 0.48)) + center_t * float(constants.get("energy_scale_center_bonus", 0.22))
		runtime._spawn_fallback_hit_impact(ball_pos, next_vel, deps, Color(0.72, 0.0, 1.0, 1.0), particle_intensity, energy_scale, energy_intensity)
	runtime._mark_kick_skill_knockback_pending(deps)
	runtime.shadow_starburst_active = true
	runtime.shadow_starburst_pos = ball_pos
	runtime.shadow_starburst_frame = 0
	runtime.shadow_starburst_timer = 0.0
	runtime.shadow_starburst_is_double = false
	var result := {
		"ball_vel": next_vel,
		"ball_impact_boost": max(1.0, float(scene.get("ball_impact_boost", 1.0))),
		"player_collision_cooldown": max(6.0, float(scene.get("player_collision_cooldown", 0.0))),
	}
	var gold_award: int = int(constants.get("hit_gold", 16))
	if runtime.shadow_was_airborne:
		gold_award = int(float(gold_award) * float(constants.get("airborne_gold_mult", 1.5)))
	result.merge(runtime.runtime_action_router.award_skill_gold(deps, gold_award), true)
	return runtime._mark_result_released_chaos_hit(result, released_chaos)


static func update_effects(runtime: Object, fps_scale: float, context: Dictionary, deps: Dictionary, constants: Dictionary) -> void:
	_update_shadow_kick_ready(runtime, fps_scale)
	_update_hologram(runtime, fps_scale, deps, float(constants.get("hologram_frames", 30.0)))
	_update_phantom_strike(runtime, fps_scale)
	_update_marshal_delay(runtime, fps_scale, context, deps, constants)
	_update_starburst(runtime, fps_scale, int(constants.get("starburst_frames", 5)), float(constants.get("starburst_frame_duration", 3.0)))


static func _update_shadow_kick_ready(runtime: Object, fps_scale: float) -> void:
	if not runtime.shadow_kick_ready:
		return
	runtime.shadow_kick_ready_frames = max(0.0, runtime.shadow_kick_ready_frames - fps_scale)
	if runtime.shadow_kick_ready_frames <= 0.0:
		runtime._clear_shadow_kick_ready()


static func _update_hologram(runtime: Object, fps_scale: float, deps: Dictionary, hologram_frames: float) -> void:
	if not runtime.shadow_hologram_active:
		return
	runtime.shadow_hologram_frames += fps_scale
	var progress: float = ViperSkillGeometry.shadow_step_hologram_progress(runtime.shadow_hologram_frames, hologram_frames)
	if progress >= 0.95 and not runtime.shadow_hologram_dest_shock_spawned:
		runtime.shadow_hologram_dest_shock_spawned = true
		runtime.particle_drawer.spawn_shadow_activation_feedback(runtime.shadow_hologram_target, deps.get("impact_effects", null), 0.75)
	if progress >= 1.0:
		runtime.shadow_hologram_active = false


static func _update_phantom_strike(runtime: Object, fps_scale: float) -> void:
	if not runtime.phantom_strike_active:
		return
	runtime.phantom_strike_frames = max(0.0, runtime.phantom_strike_frames - fps_scale)
	if runtime.phantom_strike_frames <= 0.0:
		runtime.phantom_strike_active = false


static func _update_marshal_delay(runtime: Object, fps_scale: float, context: Dictionary, deps: Dictionary, constants: Dictionary) -> void:
	if runtime.shadow_marshal_delay_frames <= 0.0:
		return
	runtime.shadow_marshal_delay_frames = max(0.0, runtime.shadow_marshal_delay_frames - fps_scale)
	if runtime.shadow_marshal_delay_frames > 0.0:
		return
	if runtime.core_flip_attack_active:
		runtime.shadow_marshal_delay_frames = 1.0
	elif not runtime.marshal_active:
		var skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
		var marshal_kick: String = str(constants.get("marshal_kick", "marshal_kick"))
		var phantom_kick: String = str(constants.get("phantom_kick", "phantom_kick"))
		if runtime.visibility_query.is_skill_equipped(skill_config, marshal_kick) and runtime.visibility_query.context_has_enough_gauge(context, runtime.visibility_query.get_marshal_skill_cost(skill_config, marshal_kick, phantom_kick)) and runtime.visibility_query.is_configured_skill_ready(marshal_kick, deps, -1):
			runtime.open_marshal_kick_window(runtime.shadow_marshal_delay_from_shadow_step)
	runtime.shadow_marshal_delay_from_shadow_step = false


static func _update_starburst(runtime: Object, fps_scale: float, starburst_frames: int, frame_duration: float) -> void:
	if not runtime.shadow_starburst_active:
		return
	runtime.shadow_starburst_timer += fps_scale
	while runtime.shadow_starburst_timer >= frame_duration and runtime.shadow_starburst_active:
		runtime.shadow_starburst_timer -= frame_duration
		runtime.shadow_starburst_frame += 1
		if runtime.shadow_starburst_frame >= starburst_frames:
			runtime.shadow_starburst_active = false


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
