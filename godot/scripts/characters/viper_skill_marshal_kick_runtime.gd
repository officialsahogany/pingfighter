extends RefCounted

const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")


static func start_kick(runtime: Object, skill_name: String, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	var now_msec: int = Time.get_ticks_msec()
	var skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
	var is_double_start: bool = skill_name == str(constants.get("phantom_kick", "phantom_kick"))
	var shadow_chain_start: bool = runtime.marshal_from_shadow_step_chain if is_double_start else runtime.marshal_ready_from_shadow_step_chain
	var next_gauge: float = max(0.0, special_gauge - runtime.visibility_query.get_marshal_skill_cost(skill_config, skill_name, str(constants.get("phantom_kick", "phantom_kick"))))
	runtime._trigger_configured_skill_cooldown(skill_name, skill_config, deps, now_msec)
	runtime._trigger_orb_gauge_spin(deps, now_msec)
	runtime.runtime_action_router.trigger_feedback(deps, 0.12, 4.0)
	cancel_dash_until_key_release(deps.get("dash_state", null))
	runtime.audio_router.play_marshal_backstep_sound(deps)
	runtime._clear_marshal_ready_window()
	runtime._clear_double_marshal_ready_window()
	runtime._clear_marshal_first_hit_pending()
	runtime.marshal_is_double = is_double_start
	runtime.marshal_from_shadow_step_chain = shadow_chain_start
	runtime.phantom_aura_active = is_double_start
	runtime.phantom_kick_knockback_pending = false
	runtime._clear_dmk_presentation_state()
	runtime.marshal_active = true
	runtime.marshal_phase = 0
	runtime.marshal_phase_frames = 0.0
	runtime.marshal_paddle_size = ViperSkillGeometry.get_paddle_size(config)
	runtime.marshal_start_pos = player_pos
	runtime.marshal_visual_pos = player_pos
	var field_width: float = float(config.get("width", config.get("play_right", 760.0)))
	var player_center: Vector2 = ViperSkillGeometry.player_center(player_pos, config)
	var ball_pos: Vector2 = ViperSkillGeometry.get_ball_pos(config)
	var wall_target: Dictionary = ViperSkillGeometry.marshal_initial_wall_target(player_pos, player_center, ball_pos, runtime.marshal_paddle_size, field_width, float(config.get("player_floor_y", 700.0)), float(constants.get("wall_inset", 15.0)), 200.0, 650.0, 50.0, 200.0)
	runtime.marshal_wall_pos = _get_vector2(wall_target.get("pos", player_pos), player_pos)
	runtime.marshal_wall_side = int(wall_target.get("side", 0))
	runtime.marshal_reclimb_start_pos = Vector2.ZERO
	runtime.marshal_charge_start_pos = Vector2.ZERO
	runtime.marshal_return_start_pos = Vector2.ZERO
	runtime.marshal_ball_hit = false
	runtime.marshal_activation_msec = now_msec
	runtime.marshal_hit_msec = -100000
	runtime.marshal_last_hit_pos = Vector2.ZERO
	runtime.marshal_charge_target_pos = Vector2.ZERO
	runtime.marshal_web_lines.clear()
	runtime.marshal_particles.clear()
	set_web_line_to_wall(runtime, runtime.marshal_start_pos, config)
	return {"handled": true, "activated": true, "skill_name": skill_name, "player_pos": player_pos, "player_speed": 0.0, "special_gauge": next_gauge}


static func update_kick(runtime: Object, delta: float, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	var fps_scale: float = delta * 60.0
	runtime.marshal_phase_frames += fps_scale
	var result: Dictionary = {"handled": true, "activated": false, "skill_name": str(constants.get("phantom_kick", "phantom_kick")) if runtime.marshal_is_double else str(constants.get("marshal_kick", "marshal_kick")), "player_pos": player_pos, "player_speed": 0.0, "special_gauge": special_gauge}
	var next_pos: Vector2 = player_pos
	match runtime.marshal_phase:
		0:
			var jump_progress: float = ViperSkillGeometry.marshal_phase_progress(runtime.marshal_phase_frames, get_prep_duration_frames(runtime, float(constants.get("jump_frames", 24.72)), deps, true, constants))
			next_pos = ViperSkillGeometry.marshal_jump_position(runtime.marshal_start_pos, runtime.marshal_wall_pos, jump_progress)
			set_web_line_to_wall(runtime, next_pos, config)
			spawn_motion_particle(runtime, ViperSkillGeometry.player_center(next_pos, config), "trail", 0.65, -1.0, constants)
			if jump_progress >= 1.0:
				runtime.marshal_phase = 1
				runtime.marshal_phase_frames = 0.0
				runtime.marshal_web_lines.clear()
				runtime.runtime_action_router.trigger_feedback(deps, 0.08, 3.0)
		1:
			var cling_progress: float = ViperSkillGeometry.marshal_phase_progress(runtime.marshal_phase_frames, get_prep_duration_frames(runtime, float(constants.get("cling_frames", 15.0)), deps, false, constants))
			if cling_progress >= 1.0:
				var cling_ball_pos: Vector2 = ViperSkillGeometry.get_ball_pos(config)
				var wall_center: Vector2 = ViperSkillGeometry.player_center(runtime.marshal_wall_pos, config)
				if ViperSkillGeometry.marshal_should_reclimb(cling_ball_pos, wall_center, float(constants.get("reclimb_threshold", 120.0))):
					runtime.marshal_reclimb_start_pos = runtime.marshal_wall_pos
					runtime.marshal_wall_pos = ViperSkillGeometry.marshal_reclimb_wall_target(wall_center, cling_ball_pos, ViperSkillGeometry.get_paddle_size(config), float(config.get("width", config.get("play_right", 760.0))), float(constants.get("wall_inset", 15.0)), -50.0, 120.0, 650.0)
					runtime.marshal_phase = 3
					runtime.marshal_phase_frames = 0.0
					set_web_line_to_wall(runtime, runtime.marshal_reclimb_start_pos, config)
					runtime.audio_router.play_marshal_backstep_sound(deps)
				elif runtime.marshal_is_double:
					enter_freeze_phase(runtime, 6, deps, constants)
				else:
					enter_charge(runtime, config, deps)
			next_pos = runtime.marshal_wall_pos
		3:
			var reclimb_progress: float = ViperSkillGeometry.marshal_phase_progress(runtime.marshal_phase_frames, get_prep_duration_frames(runtime, float(constants.get("reclimb_frames", 10.8)), deps, false, constants))
			next_pos = ViperSkillGeometry.marshal_reclimb_position(runtime.marshal_reclimb_start_pos, runtime.marshal_wall_pos, reclimb_progress)
			set_web_line_to_wall(runtime, next_pos, config)
			spawn_motion_particle(runtime, ViperSkillGeometry.player_center(next_pos, config), "trail", 0.8, -1.0, constants)
			if reclimb_progress >= 1.0:
				runtime.runtime_action_router.trigger_feedback(deps, 0.06, 2.0)
				runtime.marshal_web_lines.clear()
				if runtime.marshal_is_double:
					enter_freeze_phase(runtime, 6, deps, constants)
				else:
					enter_charge(runtime, config, deps)
		6:
			if not runtime.dmk_freeze_active:
				enter_charge(runtime, config, deps)
			next_pos = runtime.marshal_wall_pos
		2:
			next_pos = _update_charge_phase(runtime, config, deps, result, constants)
		5:
			if not runtime.dmk_freeze_active:
				enter_return(runtime, runtime.marshal_return_start_pos)
			next_pos = runtime.marshal_return_start_pos
		4:
			var return_progress: float = ViperSkillGeometry.marshal_phase_progress(runtime.marshal_phase_frames, float(constants.get("return_frames", 21.0)))
			var return_paddle_size: Vector2 = ViperSkillGeometry.get_paddle_size(config)
			var return_play_left: float = float(config.get("play_left", 0.0))
			var return_play_right: float = float(config.get("play_right", config.get("width", 760.0)))
			var return_target_y: float = float(config.get("player_floor_y", float(config.get("height", 750.0)) - return_paddle_size.y))
			var return_target: Vector2 = ViperSkillGeometry.marshal_return_target(runtime.marshal_return_start_pos, return_paddle_size, return_play_left, return_play_right, return_target_y)
			next_pos = ViperSkillGeometry.marshal_return_position(runtime.marshal_return_start_pos, return_target, return_progress)
			spawn_motion_particle(runtime, ViperSkillGeometry.player_center(next_pos, config), "trail", 0.4, -1.0, constants)
			if return_progress >= 1.0:
				next_pos = return_target
				reset_runtime(runtime)
	runtime.marshal_visual_pos = next_pos
	result["player_pos"] = next_pos
	return result


static func enter_charge(runtime: Object, config: Dictionary, deps: Dictionary) -> void:
	runtime.marshal_phase = 2
	runtime.marshal_phase_frames = 0.0
	runtime.marshal_charge_start_pos = runtime.marshal_wall_pos
	runtime.marshal_charge_target_pos = ViperSkillGeometry.get_ball_pos(config)
	runtime.marshal_web_lines.clear()
	runtime.audio_router.play_marshal_charge_sound(deps)


static func enter_return(runtime: Object, return_start_pos: Vector2) -> void:
	runtime.marshal_phase = 4
	runtime.marshal_phase_frames = 0.0
	runtime.marshal_return_start_pos = return_start_pos
	runtime.marshal_web_lines.clear()


static func enter_freeze_phase(runtime: Object, next_phase: int, deps: Dictionary, constants: Dictionary) -> void:
	runtime.marshal_phase = next_phase
	runtime.marshal_phase_frames = 0.0
	runtime.dmk_freeze_active = true
	runtime.dmk_freeze_frames = float(constants.get("dmk_freeze_frames", 60.0))
	runtime.dmk_text_active = true
	runtime.dmk_text_frames = float(constants.get("dmk_text_frames", 80.0)) + float(constants.get("dmk_freeze_frames", 60.0))
	if runtime.has_method("begin_phantom_kick_cutin"):
		runtime.begin_phantom_kick_cutin(runtime.dmk_freeze_frames / 60.0)
	runtime.audio_router.play_phantom_show_sound(deps)


static func reset_runtime(runtime: Object) -> void:
	runtime.marshal_active = false
	runtime.marshal_phase = 0
	runtime.marshal_wall_side = 0
	runtime.marshal_phase_frames = 0.0
	runtime.marshal_is_double = false
	runtime.phantom_aura_active = false
	runtime.marshal_paddle_size = Vector2(155.0, 50.0)
	runtime.marshal_start_pos = Vector2.ZERO
	runtime.marshal_visual_pos = Vector2.ZERO
	runtime.marshal_wall_pos = Vector2.ZERO
	runtime.marshal_reclimb_start_pos = Vector2.ZERO
	runtime.marshal_charge_start_pos = Vector2.ZERO
	runtime.marshal_return_start_pos = Vector2.ZERO
	runtime.marshal_ball_hit = false
	runtime.marshal_activation_msec = -100000
	runtime.marshal_hit_msec = -100000
	runtime.marshal_last_hit_pos = Vector2.ZERO
	runtime.marshal_charge_target_pos = Vector2.ZERO
	runtime.marshal_web_lines.clear()
	if not (runtime.marshal_first_hit_pending or runtime.double_marshal_ready):
		runtime.marshal_from_shadow_step_chain = false


static func spawn_motion_particle(runtime: Object, pos: Vector2, kind: String, chance: float = 1.0, life_override: float = -1.0, constants: Dictionary = {}) -> void:
	runtime.particle_drawer.spawn_marshal_motion_particle(runtime.marshal_particles, pos, kind, chance, life_override, int(constants.get("trail_max", 60)))


static func destroy_impact_objects(center: Vector2, deps: Dictionary, constants: Dictionary) -> void:
	var seen_instance_ids: Dictionary = {}
	for key in ["stage1_balloon_event", "stage_background", "stage2_pillar_background"]:
		var target: Object = deps.get(key, null)
		if target == null or not target.has_method("absorb_chaos_spear_objects"):
			continue
		var instance_id: int = target.get_instance_id()
		if seen_instance_ids.has(instance_id):
			continue
		seen_instance_ids[instance_id] = true
		target.absorb_chaos_spear_objects(center, float(constants.get("impact_object_radius", 150.0)), deps)


static func set_web_line_to_wall(runtime: Object, from_pos: Vector2, config: Dictionary) -> void:
	runtime.marshal_web_lines.clear()
	runtime.marshal_web_lines.append({"from": ViperSkillGeometry.player_center(from_pos, config), "to": ViperSkillGeometry.player_center(runtime.marshal_wall_pos, config)})


static func cancel_dash_until_key_release(dash_state: Object) -> void:
	if dash_state == null:
		return
	if dash_state.has_method("cancel_until_key_release"):
		dash_state.cancel_until_key_release()
	elif dash_state.has_method("reset_round"):
		dash_state.reset_round()


static func get_duration_frames(runtime: Object, base_frames: float, deps: Dictionary, double_fast: bool, constants: Dictionary) -> float:
	return runtime.skill_scaling.get_marshal_duration_frames(base_frames, runtime.visibility_query.get_runtime_skill_level(deps, "kick_enhance"), runtime.marshal_is_double, double_fast, float(constants.get("double_fast_mult", 1.3)))


static func get_prep_duration_frames(runtime: Object, base_frames: float, deps: Dictionary, double_fast: bool, constants: Dictionary) -> float:
	var chain_mult := 1.0
	if runtime.marshal_from_shadow_step_chain:
		chain_mult *= float(constants.get("shadow_chain_prep_mult", 0.8))
	if runtime.marshal_is_double:
		chain_mult *= float(constants.get("phantom_chain_prep_mult", 0.8))
	return max(1.0, get_duration_frames(runtime, base_frames, deps, double_fast, constants) * chain_mult)


static func get_prep_duration_mult(runtime: Object, deps: Dictionary, constants: Dictionary) -> float:
	var prep_mult: float = runtime.skill_scaling.get_marshal_prep_duration_mult(runtime.visibility_query.get_runtime_skill_level(deps, "kick_enhance"))
	return max(0.1, prep_mult * (float(constants.get("shadow_chain_prep_mult", 0.8)) if runtime.marshal_from_shadow_step_chain else 1.0))


static func mark_kick_skill_knockback_pending(runtime: Object, deps: Dictionary, constants: Dictionary) -> void:
	runtime.kick_skill_knockback_pending_pct = 0
	var level: int = runtime.visibility_query.get_runtime_skill_level(deps, "kick_enhance")
	var chance_pct: int = 0 if level < 3 else min(int(constants.get("knockback_chance_cap", 100)), (level - 2) * 10)
	runtime.kick_skill_knockback_pending_pct = int(constants.get("knockback_fixed_pct", 150)) if chance_pct > 0 and randf() * 100.0 < float(chance_pct) else 0


static func mark_kick_guard_speed_reduction_pending(runtime: Object, constants: Dictionary) -> void:
	runtime.kick_guard_speed_reduction_pending_pct = max(0, int(constants.get("kick_guard_speed_reduction_pct", 20)))


static func update_charge_phase(runtime: Object, config: Dictionary, deps: Dictionary, result: Dictionary, constants: Dictionary) -> Vector2:
	return _update_charge_phase(runtime, config, deps, result, constants)


static func _update_charge_phase(runtime: Object, config: Dictionary, deps: Dictionary, result: Dictionary, constants: Dictionary) -> Vector2:
	var charge_progress: float = ViperSkillGeometry.marshal_phase_progress(runtime.marshal_phase_frames, get_duration_frames(runtime, float(constants.get("charge_frames", 23.4)), deps, true, constants))
	var charge_ball_pos: Vector2 = ViperSkillGeometry.get_ball_pos(config)
	runtime.marshal_charge_target_pos = charge_ball_pos
	var next_pos: Vector2 = ViperSkillGeometry.marshal_charge_position(runtime.marshal_charge_start_pos, charge_ball_pos, ViperSkillGeometry.get_paddle_size(config), charge_progress)
	spawn_motion_particle(runtime, ViperSkillGeometry.player_center(next_pos, config), "charge", 0.75, -1.0, constants)
	if not runtime.marshal_ball_hit:
		var ball_pos: Vector2 = ViperSkillGeometry.get_ball_pos(config)
		var player_center: Vector2 = ViperSkillGeometry.player_center(next_pos, config)
		if ViperSkillGeometry.marshal_charge_hits_ball(player_center, ball_pos, float(constants.get("hit_radius", 90.0))):
			_apply_charge_hit(runtime, next_pos, ball_pos, config, deps, result, constants)
	if charge_progress >= 1.0 and runtime.marshal_phase == 2:
		enter_return(runtime, next_pos)
	return next_pos


static func _apply_charge_hit(runtime: Object, next_pos: Vector2, ball_pos: Vector2, config: Dictionary, deps: Dictionary, result: Dictionary, constants: Dictionary) -> void:
	runtime.marshal_ball_hit = true
	runtime.marshal_hit_msec = Time.get_ticks_msec()
	runtime.marshal_last_hit_pos = ball_pos
	var current_vel: Vector2 = _get_vector2(config.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var current_speed: float = current_vel.length()
	var next_speed: float = runtime.skill_scaling.get_marshal_hit_speed(current_speed, runtime.visibility_query.get_runtime_skill_level(deps, "kick_enhance"), runtime.marshal_is_double, float(constants.get("speed_mult", 2.2)), float(constants.get("min_speed", 11.0)), float(constants.get("double_speed_mult", 2.8)), float(constants.get("double_min_speed", 14.0)))
	var width: float = float(config.get("width", config.get("play_right", 760.0)))
	var kick_dir: int = ViperSkillGeometry.marshal_wall_kick_dir(ViperSkillGeometry.player_center(runtime.marshal_wall_pos, config), width)
	var aim_level: int = runtime.visibility_query.get_runtime_skill_level(deps, "kick_enhance")
	var boss_pos: Vector2 = _get_vector2(config.get("boss_pos", Vector2(float(config.get("width", 760.0)) * 0.5, 25.0)), Vector2.ZERO)
	var angle: float = ViperSkillGeometry.marshal_launch_angle(kick_dir, ball_pos, boss_pos, aim_level, runtime.marshal_is_double)
	var next_vel: Vector2 = ViperSkillGeometry.aimed_kick_launch_velocity(next_speed, angle)
	var released_chaos: bool = runtime._release_chaos_blackhole_from_hit_result(deps, config)
	var curve_frames: float = float(constants.get("curve_frames", 50.0)) * (float(constants.get("double_hit_curve_frames_mult", 2.5)) if runtime.marshal_is_double else 1.0)
	var curve_dir: int = 1 if next_vel.x > 0.0 else -1
	runtime._set_shadow_curve(curve_frames, float(constants.get("curve_force", 2.0)), curve_dir)
	runtime.shadow_starburst_active = true
	runtime.shadow_starburst_pos = ball_pos
	runtime.shadow_starburst_frame = 0
	runtime.shadow_starburst_timer = 0.0
	runtime.shadow_starburst_is_double = runtime.marshal_is_double
	if runtime.visibility_query.is_skill_equipped(runtime.visibility_query.get_viper_skill_config(deps), str(constants.get("dark_blade", "dark_blade"))):
		runtime._open_dark_blade_start_window()
	runtime.runtime_action_router.trigger_feedback(deps, float(constants.get("double_hit_shake_amount", 0.20)) if runtime.marshal_is_double else float(constants.get("hit_shake_amount", 0.13)), float(constants.get("double_hit_shake_intensity", 5.0)) if runtime.marshal_is_double else float(constants.get("hit_shake_intensity", 3.6)))
	var pulse_kind: String = str(constants.get("double_hit_pulse_kind", "viper_double_marshal")) if runtime.marshal_is_double else str(constants.get("hit_pulse_kind", "viper_marshal"))
	var pulse_intensity: float = float(constants.get("double_hit_energy_intensity", 0.96)) if runtime.marshal_is_double else float(constants.get("hit_energy_intensity", 0.72))
	var pulse_registered: bool = runtime._register_ball_hit_pulse(ball_pos, next_vel, deps, pulse_intensity, pulse_kind)
	if not pulse_registered:
		runtime._spawn_fallback_hit_impact(ball_pos, next_vel, deps, constants.get("fallback_hit_color", Color(0.72, 0.0, 1.0, 1.0)), float(constants.get("double_hit_particle_intensity", 1.30)) if runtime.marshal_is_double else float(constants.get("hit_particle_intensity", 0.86)), float(constants.get("double_hit_energy_scale", 0.82)) if runtime.marshal_is_double else float(constants.get("hit_energy_scale", 0.58)), float(constants.get("double_hit_energy_intensity", 0.96)) if runtime.marshal_is_double else float(constants.get("hit_energy_intensity", 0.72)))
	for _i in range(int(constants.get("double_hit_motion_particle_count", 22)) if runtime.marshal_is_double else int(constants.get("hit_motion_particle_count", 14))):
		var spread: float = float(constants.get("hit_motion_spread", 10.0))
		spawn_motion_particle(runtime, ball_pos + Vector2(randf_range(-spread, spread), randf_range(-spread, spread)), str(constants.get("hit_motion_kind", "impact")), float(constants.get("hit_motion_chance", 1.0)), randf_range(float(constants.get("hit_motion_life_min", 18.0)), float(constants.get("hit_motion_life_max", 34.0))), constants)
	destroy_impact_objects(ball_pos, deps, constants)
	if runtime.marshal_is_double:
		runtime.kick_guard_speed_reduction_pending_pct = 0
		runtime.phantom_kick_knockback_pending = true
		runtime.phantom_kick_speed_limit_disabled = true
		runtime.particle_drawer.spawn_phantom_hit_particles(runtime.phantom_hit_particles, ball_pos, int(constants.get("phantom_hit_particle_count", 85)), int(constants.get("phantom_hit_particle_max_count", 90)))
		runtime.audio_router.play_phantom_hit_sound(deps)
		runtime._clear_phantom_kick_chain_window()
	else:
		mark_kick_guard_speed_reduction_pending(runtime, constants)
		var skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
		if runtime.shadow_was_airborne and runtime.marshal_phantom_allowed and runtime.visibility_query.get_runtime_skill_level(deps, str(constants.get("double_marshal_kick", "double_marshal_kick"))) > 0 and runtime.visibility_query.is_skill_equipped(skill_config, str(constants.get("phantom_kick", "phantom_kick"))):
			runtime.marshal_first_hit_pending = true
			runtime.marshal_first_hit_delay_frames = float(constants.get("phantom_delay_frames", 12.0))
		else:
			runtime._clear_phantom_kick_chain_window()
	mark_kick_skill_knockback_pending(runtime, deps, constants)
	var hit_result: Dictionary = {"ball_vel": next_vel, "ball_impact_boost": max(1.0, float(config.get("ball_impact_boost", 1.0))), "player_collision_cooldown": max(float(constants.get("player_collision_cooldown", 6.0)), float(config.get("player_collision_cooldown", 0.0))), "viper_phantom_kick_knockback_pending": runtime.phantom_kick_knockback_pending}
	var gold_award: int = int(constants.get("double_hit_gold", 50)) if runtime.marshal_is_double else int(constants.get("hit_gold", 30))
	if runtime.shadow_was_airborne:
		gold_award = int(float(gold_award) * float(constants.get("shadow_airborne_gold_mult", 1.5)))
	hit_result.merge(runtime.runtime_action_router.award_skill_gold(deps, gold_award), true)
	result.merge(runtime._mark_result_released_chaos_hit(hit_result, released_chaos), true)
	if runtime.marshal_is_double:
		runtime.marshal_phase = 5
		runtime.marshal_phase_frames = 0.0
		runtime.marshal_return_start_pos = next_pos
	else:
		enter_return(runtime, next_pos)


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
