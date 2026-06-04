extends RefCounted

const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")


static func try_hold_activation(runtime: Object, down_pressed: bool, input_snapshot: Dictionary, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, now_msec: int, constants: Dictionary) -> Dictionary:
	var can_hold_dive: bool = not (not down_pressed or runtime._has_viper_attack_motion_active(true) or runtime.marshal_ready or runtime.double_marshal_ready or runtime.shadow_hologram_active or runtime.shadow_wave_active or runtime.shadow_marshal_delay_frames > 0.0 or runtime.chaos_state != "idle" or runtime.visibility_query.is_dash_motion_busy(deps) or runtime.visibility_query.is_control_locked(deps) or not bool(config.get("ball_active", true)) or runtime.visibility_query.is_round_waiting_for_serve(deps) or runtime._has_lateral_skill_input(input_snapshot) or runtime.runtime_action_router.get_viper_airborne_height(deps, config, player_pos) <= float(constants.get("min_airborne_height", 20.0)))
	if can_hold_dive:
		var skill_name: String = str(constants.get("skill_name", "dive_strike"))
		var dive_hold_skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
		var dive_hold_cost: float = runtime._get_skill_cost_with_fallback(dive_hold_skill_config, skill_name, float(constants.get("gauge_cost", 150.0)))
		can_hold_dive = runtime.visibility_query.is_skill_equipped(dive_hold_skill_config, skill_name) and special_gauge >= dive_hold_cost and runtime.visibility_query.is_configured_skill_ready(skill_name, deps, now_msec)
	if not can_hold_dive:
		runtime._reset_dive_hold()
		return {}
	if runtime.dive_hold_start_msec <= 0:
		runtime.dive_hold_start_msec = now_msec
		runtime.dive_charge_particles.clear()
	runtime.dive_hold_player_pos = player_pos
	runtime.dive_hold_paddle_size = ViperSkillGeometry.get_paddle_size(config)
	var dive_elapsed_msec: int = max(0, now_msec - runtime.dive_hold_start_msec)
	runtime.dive_hold_ratio = clamp(float(dive_elapsed_msec) / float(constants.get("hold_required_msec", 300)), 0.0, 1.0)
	runtime.particle_drawer.spawn_dive_charge_particles(runtime.dive_charge_particles, player_pos, runtime.dive_hold_paddle_size, runtime.dive_hold_ratio, int(constants.get("charge_particle_limit", 80)))
	if dive_elapsed_msec >= int(constants.get("hold_required_msec", 300)):
		runtime._reset_dive_hold()
		return runtime._start_dive_strike(player_pos, special_gauge, config, deps, now_msec)
	return {"handled": false, "activated": false, "special_gauge": special_gauge}


static func start_strike(runtime: Object, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, now_msec: int, constants: Dictionary) -> Dictionary:
	var skill_name: String = str(constants.get("skill_name", "dive_strike"))
	var skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
	var next_gauge: float = max(0.0, special_gauge - runtime._get_skill_cost_with_fallback(skill_config, skill_name, float(constants.get("gauge_cost", 150.0))))
	var cooldown_seconds: float = runtime._get_skill_cooldown_seconds_with_fallback(skill_config, skill_name, float(constants.get("cooldown_seconds", 70.0)), false)
	runtime.runtime_action_router.trigger_viper_runtime_cooldown(skill_name, now_msec, skill_config, deps, runtime._get_four_poisons_additive_cooldown_seconds(skill_name, skill_config, deps, cooldown_seconds), runtime.visibility_query)
	runtime._trigger_orb_gauge_spin(deps, now_msec)
	runtime.runtime_action_router.interrupt_viper_jetpack_thrust(deps)
	runtime.audio_router.play_dive_prep_sound(deps)
	runtime.runtime_action_router.trigger_feedback(deps, 0.08, 3.2)
	runtime.dive_active = true
	runtime.dive_phase = 0
	runtime.dive_phase_frames = 0.0
	runtime.dive_paddle_size = ViperSkillGeometry.get_paddle_size(config)
	runtime.dive_floor_y = ViperSkillGeometry.player_floor_y(config)
	runtime.dive_player_pos = player_pos
	runtime.dive_height_snapshot = max(0.0, runtime.runtime_action_router.get_viper_airborne_height(deps, config, player_pos))
	var prep_reduction_values: Array = constants.get("prep_reduction_values", [])
	var prep_reduction_pct: float = float(runtime._get_four_poisons_scaled_pct(deps, prep_reduction_values, int(constants.get("prep_reduction_cap", 70)), int(constants.get("prep_reduction_per_extra", 4))))
	runtime.dive_prep_frames_snapshot = max(1.0, float(constants.get("prep_frames", 24.0)) * max(0.0, 1.0 - prep_reduction_pct / 100.0))
	runtime.dive_effect_start_msec = now_msec
	runtime.dive_shockwave_spawn_msec = 0
	runtime.dive_hit_feedback_msec = 0
	if runtime.dive_height_snapshot > 0.0:
		runtime.dive_player_pos.y = runtime.dive_floor_y - runtime.dive_height_snapshot
	runtime.dive_shockwave_timer = 0.0
	runtime.dive_shockwave_pos = ViperSkillGeometry.emp_strike_shockwave_pos(runtime.dive_player_pos, runtime.dive_paddle_size, runtime.dive_floor_y)
	runtime.dive_ball_boosted = false
	runtime.dive_particles.clear()
	runtime.runtime_action_router.set_viper_jetpack_offset_y(deps, runtime.dive_player_pos.y - runtime.dive_floor_y)
	return {"handled": true, "activated": true, "skill_name": skill_name, "player_pos": runtime.dive_player_pos, "player_speed": 0.0, "special_gauge": next_gauge, "player_collision_cooldown": float(constants.get("player_collision_cooldown", 6.0))}


static func update_strike(runtime: Object, delta: float, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	var fps_scale: float = max(0.0, delta * 60.0)
	if runtime.dive_phase == 2:
		return _update_shockwave_phase(runtime, fps_scale, special_gauge, config, deps, constants)
	runtime.dive_phase_frames += fps_scale
	if runtime.dive_paddle_size == Vector2.ZERO:
		runtime.dive_paddle_size = ViperSkillGeometry.get_paddle_size(config)
	runtime.dive_floor_y = ViperSkillGeometry.player_floor_y(config)
	match runtime.dive_phase:
		0:
			_update_prep_phase(runtime, player_pos, fps_scale, config, deps, constants)
		1:
			_update_fall_phase(runtime, player_pos, fps_scale, config, deps, constants)
	return {"handled": true, "activated": false, "skill_name": str(constants.get("skill_name", "dive_strike")), "player_pos": runtime.dive_player_pos, "player_speed": 0.0, "special_gauge": special_gauge, "player_collision_cooldown": float(constants.get("player_collision_cooldown", 6.0))}


static func start_slip_for_height(runtime: Object, ball_pos: Vector2, context: Dictionary, deps: Dictionary, height_snapshot: float, max_refresh: bool, constants: Dictionary) -> void:
	var sleep_pct_values: Array = constants.get("sleep_pct_values", [])
	var sleep_pct: int = runtime._get_four_poisons_scaled_pct(deps, sleep_pct_values, int(constants.get("sleep_pct_cap", 50)), int(constants.get("sleep_pct_per_extra", 5)))
	var start_state: Dictionary = ViperSkillGeometry.emp_slip_start_state(ball_pos, context, height_snapshot, float(constants.get("jetpack_max_height", 200.0)), float(constants.get("slip_duration_min", 54.0)), float(constants.get("slip_duration_max", 90.0)), sleep_pct, float(constants.get("slip_speed", 4.0)))
	var duration: float = float(start_state.get("duration", 1.0))
	if max_refresh:
		runtime.dive_slip_duration = max(runtime.dive_slip_duration, duration)
		runtime.dive_slip_timer = max(runtime.dive_slip_timer, duration)
	else:
		runtime.dive_slip_duration = duration
		runtime.dive_slip_timer = duration
	runtime.dive_slip_vel = float(start_state.get("slip_vel", 0.0))


static func apply_slip_boss_motion(runtime: Object, boss_pos: Vector2, context: Dictionary, fps_scale: float) -> Dictionary:
	var motion: Dictionary = ViperSkillGeometry.emp_slip_boss_motion(boss_pos, context, fps_scale, runtime.dive_slip_timer, runtime.dive_slip_duration, runtime.dive_slip_vel)
	runtime.dive_slip_timer = float(motion.get("slip_timer", 0.0))
	runtime.dive_slip_vel = float(motion.get("slip_vel", 0.0))
	return {"boss_pos": _get_vector2(motion.get("boss_pos", boss_pos), boss_pos), "boss_vel": float(motion.get("boss_vel", 0.0))}


static func reset_runtime(runtime: Object, clear_hold: bool, constants: Dictionary) -> void:
	if clear_hold:
		reset_hold(runtime)
	runtime.dive_active = false
	runtime.dive_phase = 0
	runtime.dive_phase_frames = 0.0
	runtime.dive_player_pos = Vector2.ZERO
	runtime.dive_paddle_size = Vector2(155.0, 50.0)
	runtime.dive_floor_y = 700.0
	runtime.dive_height_snapshot = 0.0
	runtime.dive_prep_frames_snapshot = float(constants.get("prep_frames", 24.0))
	runtime.dive_shockwave_timer = 0.0
	runtime.dive_shockwave_pos = Vector2.ZERO
	runtime.dive_shockwave_max_radius = float(constants.get("shockwave_base_max_radius", 300.0))
	runtime.dive_shockwave_boss_effect_applied = false
	runtime.dive_ball_boosted = false
	runtime.dive_particles.clear()
	runtime.dive_slip_timer = 0.0
	runtime.dive_slip_duration = 0.0
	runtime.dive_slip_vel = 0.0
	runtime.dive_hit_text_timer = 0.0
	runtime.dive_hit_text_pos = Vector2.ZERO
	runtime.dive_hit_text_height_ratio = 0.0
	runtime.dive_effect_start_msec = 0
	runtime.dive_shockwave_spawn_msec = 0
	runtime.dive_hit_feedback_msec = 0
	runtime.fx_host_controller.hide_fx_host(runtime.emp_fx_host)


static func reset_hold(runtime: Object) -> void:
	runtime.dive_hold_start_msec = 0
	runtime.dive_hold_ratio = 0.0
	runtime.dive_hold_player_pos = Vector2.ZERO
	runtime.dive_hold_paddle_size = Vector2(155.0, 50.0)
	runtime.dive_charge_particles.clear()
	if not runtime.dive_active:
		runtime.fx_host_controller.hide_fx_host(runtime.emp_fx_host)


static func _update_shockwave_phase(runtime: Object, fps_scale: float, special_gauge: float, config: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	var previous_radius: float = runtime.get_emp_shockwave_radius()
	runtime.dive_shockwave_timer = max(0.0, runtime.dive_shockwave_timer - fps_scale)
	if not runtime.dive_shockwave_boss_effect_applied and ViperSkillGeometry.dive_shockwave_ring_touches_boss(previous_radius, runtime.get_emp_shockwave_radius(), config, runtime.dive_shockwave_pos, float(constants.get("shockwave_ring_half_thickness", 24.0))):
		var slip_reference_pos: Vector2 = runtime.dive_shockwave_pos
		var ring_ball_pos: Variant = config.get("ball_pos", null)
		if ring_ball_pos is Vector2:
			slip_reference_pos = ring_ball_pos
		start_slip_for_height(runtime, slip_reference_pos, config, deps, runtime.dive_height_snapshot, true, constants)
		runtime.dive_shockwave_boss_effect_applied = true
	if runtime.dive_shockwave_timer <= 0.0:
		runtime.dive_active = false
		runtime.dive_phase = 0
		runtime.dive_phase_frames = 0.0
		runtime.dive_ball_boosted = false
		runtime.dive_shockwave_timer = 0.0
	return {"handled": false, "activated": false, "special_gauge": special_gauge}


static func _update_prep_phase(runtime: Object, player_pos: Vector2, fps_scale: float, config: Dictionary, deps: Dictionary, constants: Dictionary) -> void:
	runtime.dive_player_pos.x = player_pos.x
	var prep_center: Vector2 = runtime.dive_player_pos + ViperSkillGeometry.get_paddle_size(config) * 0.5
	var prep_progress: float = clamp(runtime.dive_phase_frames / max(1.0, runtime.dive_prep_frames_snapshot), 0.0, 1.0)
	runtime.particle_drawer.spawn_dive_prep_particles(runtime.dive_particles, prep_center, prep_progress, fps_scale, int(constants.get("particle_limit", 150)))
	runtime.runtime_action_router.set_viper_jetpack_offset_y(deps, runtime.dive_player_pos.y - runtime.dive_floor_y)
	if runtime.dive_phase_frames >= runtime.dive_prep_frames_snapshot:
		runtime.dive_phase = 1
		runtime.dive_phase_frames = 0.0


static func _update_fall_phase(runtime: Object, player_pos: Vector2, fps_scale: float, config: Dictionary, deps: Dictionary, constants: Dictionary) -> void:
	runtime.dive_player_pos.x = player_pos.x
	runtime.dive_player_pos.y = min(runtime.dive_floor_y, runtime.dive_player_pos.y + float(constants.get("speed", 15.0)) * fps_scale)
	runtime.runtime_action_router.set_viper_jetpack_offset_y(deps, runtime.dive_player_pos.y - runtime.dive_floor_y)
	var paddle_size: Vector2 = ViperSkillGeometry.get_paddle_size(config)
	var trail_anchor := Vector2(runtime.dive_player_pos.x + paddle_size.x * 0.5, runtime.dive_player_pos.y + paddle_size.y)
	runtime.particle_drawer.spawn_dive_trail_particles(runtime.dive_particles, trail_anchor.x, trail_anchor.y, fps_scale, int(constants.get("particle_limit", 150)))
	if runtime.dive_player_pos.y >= runtime.dive_floor_y:
		_enter_shockwave_phase(runtime, config, deps, constants)


static func _enter_shockwave_phase(runtime: Object, config: Dictionary, deps: Dictionary, constants: Dictionary) -> void:
	runtime.dive_phase = 2
	runtime.dive_phase_frames = 0.0
	runtime.dive_floor_y = ViperSkillGeometry.player_floor_y(config)
	runtime.dive_player_pos.y = runtime.dive_floor_y
	runtime.dive_shockwave_timer = float(constants.get("shockwave_frames", 60.0))
	runtime.dive_shockwave_pos = ViperSkillGeometry.emp_strike_shockwave_pos(runtime.dive_player_pos, runtime.dive_paddle_size, runtime.dive_floor_y)
	runtime.dive_shockwave_spawn_msec = Time.get_ticks_msec()
	runtime.dive_shockwave_max_radius = ViperSkillGeometry.dive_shockwave_boss_reach_radius(config, runtime.dive_shockwave_pos, float(constants.get("shockwave_base_max_radius", 300.0)), float(constants.get("shockwave_ring_half_thickness", 24.0)))
	runtime.dive_shockwave_boss_effect_applied = false
	runtime.dive_ball_boosted = false
	runtime.runtime_action_router.set_viper_jetpack_offset_y(deps, 0.0)
	runtime.runtime_action_router.trigger_feedback(deps, 0.18, 5.0)
	runtime.audio_router.play_dive_strike_sound(deps)
	runtime.particle_drawer.spawn_dive_landing_particles(runtime.dive_particles, runtime.dive_shockwave_pos, int(constants.get("particle_limit", 150)), float(constants.get("jetpack_max_height", 200.0)))
	if runtime._is_dual_glitch_clone_replication_active(deps):
		_spawn_dual_glitch_emp_replicas(runtime, constants)


static func _spawn_dual_glitch_emp_replicas(runtime: Object, constants: Dictionary) -> void:
	var dive_replica_origins: Array = runtime.visibility_query.get_dual_glitch_replication_origins(runtime._get_dual_glitch_clone_rect_entries(true, false))
	if dive_replica_origins.is_empty():
		return
	var dive_replica_floor_y: float = runtime.dive_shockwave_pos.y
	for dive_origin_value in dive_replica_origins:
		if not (dive_origin_value is Dictionary):
			continue
		var dive_origin: Dictionary = dive_origin_value
		var dive_replica_side: int = int(dive_origin.get("side", 0))
		if dive_replica_side == 0:
			continue
		var dive_replica_delay_mult: float = 1.0 if dive_replica_side < 0 else 2.0
		runtime.dual_glitch_clone_dive_entries.append({"side": dive_replica_side, "x": float(dive_origin.get("x", runtime.dive_shockwave_pos.x)), "y": dive_replica_floor_y, "start_y": float(dive_origin.get("y", dive_replica_floor_y)), "delay_frames": float(constants.get("dual_glitch_dive_stagger_frames", 12.0)) * dive_replica_delay_mult, "timer": 0.0, "activated": false, "ball_boosted": false, "height_snapshot": runtime.dive_height_snapshot, "telegraph": false})


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
