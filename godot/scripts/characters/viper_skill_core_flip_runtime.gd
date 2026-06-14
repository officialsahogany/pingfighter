extends RefCounted

const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")


static func build_motion_result(skill_name: String, player_pos: Vector2, special_gauge: float, activated: bool, config: Dictionary) -> Dictionary:
	return {"handled": true, "activated": activated, "skill_name": skill_name, "player_pos": player_pos, "player_speed": 0.0, "special_gauge": special_gauge, "player_collision_cooldown": max(6.0, float(config.get("player_collision_cooldown", 0.0)))}


static func try_ready_activation(runtime: Object, input_snapshot: Dictionary, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, now_msec: int, constants: Dictionary) -> Dictionary:
	if not runtime._is_core_flip_ready_window_active(now_msec):
		return {}
	var core_flip_left_press_age: int = runtime.input_sequence_frame - runtime.core_flip_left_press_frame
	var core_flip_right_press_age: int = runtime.input_sequence_frame - runtime.core_flip_right_press_frame
	var input_max_age_frames: int = int(constants.get("input_max_age_frames", 16))
	var input_frame_gap: int = int(constants.get("input_frame_gap", 4))
	if (bool(input_snapshot.get("left_pressed", false)) and bool(input_snapshot.get("right_pressed", false))) or (core_flip_left_press_age >= 0 and core_flip_left_press_age <= input_max_age_frames and core_flip_right_press_age >= 0 and core_flip_right_press_age <= input_max_age_frames and abs(runtime.core_flip_left_press_frame - runtime.core_flip_right_press_frame) <= input_frame_gap):
		runtime.core_flip_buffered_until_msec = runtime.core_flip_ready_msec + int(constants.get("ready_window_msec", 700))
	if runtime.core_flip_buffered_until_msec < now_msec or runtime._has_viper_attack_motion_active(true) or runtime.shadow_hologram_active or runtime.chaos_state != "idle":
		return {}
	var core_flip_dash_snapshot: Dictionary = runtime.visibility_query.get_dash_snapshot(deps.get("dash_state", null))
	if bool(core_flip_dash_snapshot.get("active", false)) or runtime.visibility_query.is_control_locked(deps) or not bool(config.get("ball_active", true)) or runtime.visibility_query.is_round_waiting_for_serve(deps):
		return {}
	var skill_name: String = str(constants.get("skill_name", "core_flip"))
	var core_flip_skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
	var fallback_cost: float = float(constants.get("fallback_cost", 120.0))
	var core_flip_cost: float = runtime._get_skill_cost_with_fallback(core_flip_skill_config, skill_name, fallback_cost)
	if not (runtime.visibility_query.is_skill_equipped(core_flip_skill_config, skill_name) and special_gauge >= core_flip_cost and runtime.visibility_query.is_configured_skill_ready(skill_name, deps, now_msec)):
		return {}
	var core_flip_start_skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
	var core_flip_next_gauge: float = max(0.0, special_gauge - runtime._get_skill_cost_with_fallback(core_flip_start_skill_config, skill_name, fallback_cost))
	runtime._trigger_configured_skill_cooldown(skill_name, core_flip_start_skill_config, deps, now_msec)
	runtime._trigger_orb_gauge_spin(deps, now_msec)
	runtime._cancel_dash_until_key_release(deps.get("dash_state", null))
	runtime.runtime_action_router.trigger_feedback(deps, float(constants.get("start_shake_amount", 0.14)), float(constants.get("start_shake_intensity", 4.5)))
	runtime.core_flip_consumed = true
	runtime.core_flip_ready_msec = 0
	runtime.core_flip_buffered_until_msec = 0
	runtime.core_flip_attack_active = true
	runtime.core_flip_attack_phase = 0
	runtime.core_flip_phase_frames = 0.0
	runtime.core_flip_paddle_size = ViperSkillGeometry.get_paddle_size(config)
	runtime.core_flip_origin_center = player_pos + runtime.core_flip_paddle_size * 0.5
	runtime.core_flip_target_center = ViperSkillGeometry.get_ball_pos(config)
	var core_flip_start_motion: Dictionary = ViperSkillGeometry.core_flip_start_motion(runtime.core_flip_origin_center, runtime.core_flip_target_center, float(constants.get("apex_offset_y", -30.0)))
	runtime.core_flip_apex_center = _get_vector2(core_flip_start_motion.get("apex_center", runtime.core_flip_target_center), runtime.core_flip_target_center)
	runtime.core_flip_visual_pos = player_pos
	runtime.core_flip_return_start_center = runtime.core_flip_origin_center
	runtime.core_flip_kick_dir = int(core_flip_start_motion.get("kick_dir", runtime.core_flip_kick_dir))
	runtime.core_flip_ball_hit = false
	runtime.core_flip_spin_angle_degrees = 0.0
	runtime.core_flip_spin_sound_started = true
	runtime.core_flip_kick_sound_played = false
	runtime.core_flip_web_lines.clear()
	runtime._clear_marshal_ready_window()
	runtime._clear_double_marshal_ready_window()
	runtime._clear_marshal_first_hit_pending()
	runtime.shadow_marshal_delay_frames = 0.0
	runtime.shadow_marshal_delay_from_shadow_step = false
	runtime.audio_router.play_core_flip_spin_sound(deps)
	return build_motion_result(skill_name, player_pos, core_flip_next_gauge, true, config)


static func update_motion(runtime: Object, delta: float, special_gauge: float, config: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	var fps_scale: float = delta * 60.0
	runtime.core_flip_phase_frames += fps_scale
	var skill_name: String = str(constants.get("core_flip", "core_flip"))
	var next_pos: Vector2 = runtime.core_flip_visual_pos
	var result: Dictionary = build_motion_result(skill_name, runtime.core_flip_visual_pos, special_gauge, false, config)
	match runtime.core_flip_attack_phase:
		0:
			_update_startup_phase(runtime, deps, constants)
			next_pos = ViperSkillGeometry.center_to_player_pos(runtime.core_flip_origin_center, config, runtime.core_flip_paddle_size)
		1:
			next_pos = _update_wall_climb_phase(runtime, config, deps, constants)
		2:
			var kick_update: Dictionary = _update_kick_phase(runtime, result, config, deps, constants)
			next_pos = _get_vector2(kick_update.get("player_pos", next_pos), next_pos)
		3:
			next_pos = _update_return_phase(runtime, config, deps, constants)
	runtime.core_flip_visual_pos = next_pos
	result["player_pos"] = next_pos
	return result


static func _update_startup_phase(runtime: Object, deps: Dictionary, constants: Dictionary) -> void:
	runtime.core_flip_web_lines.clear()
	var t0: float = ViperSkillGeometry.core_flip_phase_progress(runtime.core_flip_phase_frames, float(constants.get("phase0_frames", 24.0)))
	runtime.core_flip_spin_angle_degrees = ViperSkillGeometry.core_flip_spin_degrees(0, t0)
	if t0 >= 1.0:
		runtime.core_flip_attack_phase = 1
		runtime.core_flip_phase_frames = 0.0
		runtime.audio_router.play_marshal_backstep_sound(deps)


static func _update_wall_climb_phase(runtime: Object, config: Dictionary, deps: Dictionary, constants: Dictionary) -> Vector2:
	var kick_level: int = runtime.visibility_query.get_runtime_skill_level(deps, "kick_enhance")
	var phase1_cap: float = runtime.skill_scaling.get_core_flip_wall_prep_duration_frames(float(constants.get("phase1_frames", 105.3)), kick_level, config)
	var t1: float = ViperSkillGeometry.core_flip_phase_progress(runtime.core_flip_phase_frames, phase1_cap)
	runtime.core_flip_target_center = ViperSkillGeometry.get_ball_pos(config)
	runtime.core_flip_spin_angle_degrees = ViperSkillGeometry.core_flip_spin_degrees(1, t1)
	var leg_frames: float = runtime.skill_scaling.get_core_flip_wall_prep_duration_frames(float(constants.get("zigzag_leg_frames", 28.08)), kick_level, config)
	var cling_frames: float = runtime.skill_scaling.get_core_flip_wall_prep_duration_frames(float(constants.get("zigzag_cling_frames", 11.7)), kick_level, config)
	var center1: Vector2 = ViperSkillGeometry.core_flip_wall_climb_center(t1, config, runtime.core_flip_paddle_size, runtime.core_flip_origin_center, runtime.core_flip_target_center, runtime.core_flip_kick_dir, runtime.core_flip_phase_frames, leg_frames, cling_frames, float(constants.get("kick_trigger_y", 200.0)))
	var wall_contact: Dictionary = ViperSkillGeometry.core_flip_wall_contact_state(center1, float(config.get("width", 760.0)), runtime.core_flip_phase_frames, leg_frames, cling_frames)
	var web_line_to: Vector2 = _get_vector2(wall_contact.get("line_to", center1), center1)
	runtime.core_flip_web_lines.clear()
	runtime.core_flip_web_lines.append({"from": center1, "to": web_line_to})
	var wall_touch_count: int = int(wall_contact.get("touch_count", 0))
	if ViperSkillGeometry.core_flip_should_enter_kick_phase(wall_touch_count, t1):
		runtime.core_flip_apex_center = center1
		runtime.core_flip_target_center = ViperSkillGeometry.get_ball_pos(config)
		runtime.core_flip_kick_dir = ViperSkillGeometry.core_flip_kick_direction(runtime.core_flip_apex_center, runtime.core_flip_target_center)
		runtime.core_flip_attack_phase = 2
		runtime.core_flip_phase_frames = 0.0
	return ViperSkillGeometry.center_to_player_pos(center1, config, runtime.core_flip_paddle_size)


static func _update_kick_phase(runtime: Object, result: Dictionary, config: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	runtime.core_flip_web_lines.clear()
	var kick_level: int = runtime.visibility_query.get_runtime_skill_level(deps, "kick_enhance")
	var p2_duration: float = runtime.skill_scaling.get_core_flip_duration_frames(float(constants.get("phase2_frames", 23.4)), kick_level)
	var t2: float = ViperSkillGeometry.core_flip_phase_progress(runtime.core_flip_phase_frames, p2_duration)
	if not runtime.core_flip_ball_hit:
		runtime.core_flip_target_center = ViperSkillGeometry.get_ball_pos(config)
	var kick_motion: Dictionary = ViperSkillGeometry.core_flip_kick_motion(runtime.core_flip_apex_center, runtime.core_flip_target_center, t2)
	var kick_center: Vector2 = _get_vector2(kick_motion.get("center", runtime.core_flip_apex_center), runtime.core_flip_apex_center)
	runtime.core_flip_kick_dir = int(kick_motion.get("dir", runtime.core_flip_kick_dir))
	runtime.core_flip_spin_angle_degrees = ViperSkillGeometry.core_flip_spin_degrees(2, t2)
	if not runtime.core_flip_ball_hit and ViperSkillGeometry.core_flip_kick_hits_ball(kick_center, ViperSkillGeometry.get_ball_pos(config), float(constants.get("hit_radius", 60.0))):
		_apply_kick_hit(runtime, result, kick_center, config, deps, constants)
	if t2 >= 1.0:
		if not runtime.core_flip_ball_hit:
			runtime.core_flip_miss_text_timer = float(constants.get("miss_text_frames", 50.0))
			runtime.core_flip_miss_text_pos = ViperSkillGeometry.core_flip_miss_text_pos(runtime.core_flip_origin_center, float(constants.get("apex_offset_y", -30.0)))
		runtime.core_flip_return_start_center = kick_center
		runtime.core_flip_attack_phase = 3
		runtime.core_flip_phase_frames = 0.0
	return {"player_pos": ViperSkillGeometry.center_to_player_pos(kick_center, config, runtime.core_flip_paddle_size)}


static func _apply_kick_hit(runtime: Object, result: Dictionary, kick_center: Vector2, config: Dictionary, deps: Dictionary, constants: Dictionary) -> void:
	runtime.core_flip_ball_hit = true
	runtime.core_flip_target_center = kick_center
	if not runtime.core_flip_kick_sound_played:
		runtime.audio_router.play_core_flip_kick_sound(deps)
		runtime.core_flip_kick_sound_played = true
	var kick_level: int = runtime.visibility_query.get_runtime_skill_level(deps, "kick_enhance")
	var current_vel: Vector2 = _get_vector2(config.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var current_speed: float = current_vel.length()
	var next_speed: float = runtime.skill_scaling.get_core_flip_hit_speed(current_speed, kick_level, float(constants.get("speed_mult", 2.2)), float(constants.get("min_speed", 11.0)))
	var next_vel: Vector2 = ViperSkillGeometry.core_flip_bank_velocity(next_speed, runtime.core_flip_kick_dir, config, kick_level)
	var ball_pos: Vector2 = ViperSkillGeometry.get_ball_pos(config)
	var released_chaos: bool = runtime._release_chaos_blackhole_from_hit_result(deps, config)
	runtime._set_shadow_curve(float(constants.get("marshal_curve_frames", 50.0)), float(constants.get("marshal_curve_force", 2.0)), 1 if next_vel.x > 0.0 else -1)
	runtime.shadow_was_airborne = true
	runtime.shadow_marshal_delay_frames = float(constants.get("marshal_delay_frames", 6.0))
	runtime.shadow_marshal_delay_from_shadow_step = false
	runtime.shadow_marshal_delay_from_core_flip = true
	runtime.marshal_phantom_allowed = true
	var dark_blade_name: String = str(constants.get("dark_blade", "dark_blade"))
	if runtime.visibility_query.is_skill_equipped(runtime.visibility_query.get_viper_skill_config(deps), dark_blade_name):
		runtime._open_dark_blade_start_window()
	else:
		runtime.dark_blade_window = false
	runtime.shadow_starburst_active = true
	runtime.shadow_starburst_pos = ball_pos
	runtime.shadow_starburst_frame = 0
	runtime.shadow_starburst_timer = 0.0
	runtime.shadow_starburst_is_double = false
	runtime.runtime_action_router.trigger_feedback(deps, float(constants.get("hit_shake_amount", 0.15)), float(constants.get("hit_shake_intensity", 6.0)))
	var pulse_registered: bool = runtime._register_ball_hit_pulse(ball_pos, next_vel, deps, float(constants.get("hit_pulse_intensity", 0.92)), str(constants.get("hit_pulse_kind", "viper_core_flip")))
	for _i in range(int(constants.get("hit_motion_count", 18))):
		var spread: float = float(constants.get("hit_motion_spread", 12.0))
		runtime._spawn_marshal_motion_particle(ball_pos + Vector2(randf_range(-spread, spread), randf_range(-spread, spread)), str(constants.get("hit_motion_kind", "impact")), float(constants.get("hit_motion_chance", 1.0)), randf_range(float(constants.get("hit_motion_life_min", 20.0)), float(constants.get("hit_motion_life_max", 38.0))))
	if not pulse_registered:
		runtime._spawn_fallback_hit_impact(ball_pos, next_vel, deps, Color(1.0, 0.43, 0.78, 1.0), 1.15, 0.74, 0.92)
	runtime._destroy_marshal_impact_objects(ball_pos, deps)
	runtime._mark_kick_skill_knockback_pending(deps)
	_apply_core_flip_mythic_hit(runtime, deps)
	var core_flip_hit_result: Dictionary = {"ball_vel": next_vel, "ball_impact_boost": max(1.0, float(config.get("ball_impact_boost", 1.0))), "player_collision_cooldown": max(6.0, float(config.get("player_collision_cooldown", 0.0)))}
	core_flip_hit_result.merge(runtime.runtime_action_router.award_skill_gold(deps, int(constants.get("hit_gold", 30)), config), true)
	result.merge(runtime._mark_result_released_chaos_hit(core_flip_hit_result, released_chaos), true)
	if runtime.visibility_query.is_skill_equipped(runtime.visibility_query.get_viper_skill_config(deps), dark_blade_name):
		runtime._open_dark_blade_start_window()


static func _update_return_phase(runtime: Object, config: Dictionary, deps: Dictionary, constants: Dictionary) -> Vector2:
	runtime.core_flip_web_lines.clear()
	var t3: float = ViperSkillGeometry.core_flip_phase_progress(runtime.core_flip_phase_frames, float(constants.get("phase3_frames", 9.0)))
	var return_motion: Dictionary = ViperSkillGeometry.core_flip_return_motion(runtime.core_flip_return_start_center, runtime.core_flip_origin_center, t3)
	runtime.core_flip_spin_angle_degrees = float(return_motion.get("spin_degrees", runtime.core_flip_spin_angle_degrees))
	var return_center: Vector2 = _get_vector2(return_motion.get("center", runtime.core_flip_origin_center), runtime.core_flip_origin_center)
	var next_pos: Vector2 = ViperSkillGeometry.center_to_player_pos(return_center, config, runtime.core_flip_paddle_size)
	if t3 >= 1.0:
		next_pos = ViperSkillGeometry.center_to_player_pos(runtime.core_flip_origin_center, config, runtime.core_flip_paddle_size)
		var dark_blade_name: String = str(constants.get("dark_blade", "dark_blade"))
		if runtime.dark_blade_window and runtime.visibility_query.is_skill_equipped(runtime.visibility_query.get_viper_skill_config(deps), dark_blade_name):
			runtime.core_flip_dark_blade_handoff_frames = float(constants.get("dark_blade_handoff_frames", 30.0))
		else:
			runtime.core_flip_dark_blade_handoff_frames = 0.0
		runtime._reset_core_flip_runtime(false)
	return next_pos


static func _apply_core_flip_mythic_hit(runtime: Object, deps: Dictionary) -> void:
	var mythic_item_runtime: Object = runtime.visibility_query.get_mythic_item_runtime(deps)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("try_venom_mist_poison_ball"):
		mythic_item_runtime.try_venom_mist_poison_ball(deps)


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
