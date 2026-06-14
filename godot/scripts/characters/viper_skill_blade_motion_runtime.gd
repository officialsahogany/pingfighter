extends RefCounted

const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")


static func try_phase2_followup_activation(runtime: Object, up_edge: bool, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, now_msec: int, constants: Dictionary) -> Dictionary:
	if not (up_edge and runtime.blade_motion_active and runtime.blade_motion_phase == 2):
		return {}
	var blade_rush: String = str(constants.get("blade_rush", "blade_rush"))
	var dark_blade: String = str(constants.get("dark_blade", "dark_blade"))
	var nerve_strike: String = str(constants.get("nerve_strike", "nerve_strike"))
	if not runtime.blade_dark_mode:
		var air_blade_combo_skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
		var air_blade_has_nerve_and_dark: bool = runtime.visibility_query.is_skill_equipped(air_blade_combo_skill_config, nerve_strike) and runtime.visibility_query.is_skill_equipped(air_blade_combo_skill_config, dark_blade)
		var air_blade_nerve_window_end_frame: float = float(constants.get("nerve_dark_blade_split_frames", 84.0)) if air_blade_has_nerve_and_dark else float(constants.get("nerve_window_end_frames", 102.0))
		var air_blade_nerve_combo_window_active: bool = not runtime.nerve_strike_combo_used and not runtime.nerve_strike_active and runtime.blade_motion_total_frames >= float(constants.get("nerve_window_start_frames", 66.0)) and runtime.blade_motion_total_frames < air_blade_nerve_window_end_frame
		var air_blade_skip_dark_combo := false
		if air_blade_nerve_combo_window_active:
			var air_blade_can_start_nerve_combo := false
			if not (runtime.visibility_query.is_control_locked(deps) or not bool(config.get("ball_active", true))):
				var air_blade_nerve_skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
				if runtime.visibility_query.is_skill_equipped(air_blade_nerve_skill_config, nerve_strike):
					if special_gauge >= runtime._get_skill_cost_with_fallback(air_blade_nerve_skill_config, nerve_strike, float(constants.get("nerve_fallback_cost", 90.0))):
						var air_blade_nerve_skill_state: Object = runtime.visibility_query.get_viper_skill_state(deps)
						if air_blade_nerve_skill_state == null:
							air_blade_can_start_nerve_combo = true
						elif air_blade_nerve_skill_state.has_method("get_cooldown_remaining"):
							air_blade_can_start_nerve_combo = air_blade_nerve_skill_state.get_cooldown_remaining(nerve_strike, now_msec, runtime._get_four_poisons_additive_cooldown_seconds(nerve_strike, air_blade_nerve_skill_config, deps, float(constants.get("nerve_cooldown_base", 35.0)))) <= 0.0
						else:
							air_blade_can_start_nerve_combo = runtime.visibility_query.is_configured_skill_ready(nerve_strike, deps, now_msec)
			if air_blade_can_start_nerve_combo:
				runtime._clear_blade_projectile()
				return runtime._start_nerve_strike(player_pos, special_gauge, config, deps, now_msec)
			if air_blade_has_nerve_and_dark and runtime.blade_motion_total_frames < float(constants.get("nerve_dark_blade_split_frames", 84.0)):
				air_blade_skip_dark_combo = true
		var air_blade_dark_split_combo_window_active: bool = air_blade_has_nerve_and_dark and runtime.blade_motion_total_frames >= float(constants.get("nerve_dark_blade_split_frames", 84.0)) and runtime.blade_motion_total_frames <= float(constants.get("nerve_window_end_frames", 102.0))
		if not air_blade_skip_dark_combo and (air_blade_dark_split_combo_window_active or runtime.blade_air_combo_window) and not runtime.visibility_query.is_control_locked(deps) and bool(config.get("ball_active", true)) and runtime.visibility_query.is_skill_equipped(air_blade_combo_skill_config, dark_blade) and special_gauge >= runtime._get_blade_skill_cost(air_blade_combo_skill_config, deps, dark_blade) and runtime.visibility_query.is_configured_skill_ready(dark_blade, deps, -1):
			runtime._clear_blade_projectile()
			return runtime._start_blade_motion(player_pos, special_gauge, config, deps, true, now_msec, true, true)
	elif runtime.blade_dark_combo_window and not (runtime.visibility_query.is_control_locked(deps) or not bool(config.get("ball_active", true))):
		var dark_blade_combo_skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
		if runtime.visibility_query.is_skill_equipped(dark_blade_combo_skill_config, blade_rush) and special_gauge >= runtime._get_blade_skill_cost(dark_blade_combo_skill_config, deps, blade_rush):
			runtime._clear_blade_projectile()
			return runtime._start_blade_motion(player_pos, special_gauge, config, deps, false, now_msec, false, true)
	return {}


static func start_motion(runtime: Object, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, dark_mode: bool, now_msec: int, trigger_cooldown: bool, pop_up_from_combo: bool, constants: Dictionary) -> Dictionary:
	var skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
	var skill_name: String = str(constants.get("dark_blade", "dark_blade")) if dark_mode else str(constants.get("blade_rush", "blade_rush"))
	var next_gauge: float = max(0.0, special_gauge - get_skill_cost(runtime, skill_config, deps, skill_name, constants))
	if trigger_cooldown:
		runtime._trigger_configured_skill_cooldown(skill_name, skill_config, deps, now_msec)
	runtime._trigger_orb_gauge_spin(deps, now_msec)
	runtime.runtime_action_router.trigger_feedback(deps, 0.10 if dark_mode else 0.08, 4.2 if dark_mode else 3.4)
	runtime.runtime_action_router.interrupt_viper_jetpack_thrust(deps)
	var blade_audio: Object = deps.get("audio", null)
	if blade_audio != null and blade_audio.has_method("play_viper_blade_spin"):
		blade_audio.play_viper_blade_spin()
		runtime.blade_spin_sound_active = true
		runtime.blade_spin_audio = blade_audio
	var start_pos: Vector2 = ViperSkillGeometry.blade_motion_start_position(player_pos, ViperSkillGeometry.player_floor_y(config), pop_up_from_combo, float(constants.get("combo_pop_min_offset", -40.0)), float(constants.get("combo_pop_extra", 80.0)))
	runtime.blade_motion_active = true
	enter_spin_phase(runtime)
	runtime.blade_dark_mode = dark_mode
	runtime.blade_motion_start_pos = start_pos
	runtime.blade_motion_pos = start_pos
	runtime.blade_phase2_base_y = start_pos.y
	runtime.blade_paddle_size = ViperSkillGeometry.get_paddle_size(config)
	reset_combo_windows(runtime)
	runtime.dark_blade_window = false
	runtime.dark_blade_window_frames = 0.0
	runtime.core_flip_dark_blade_handoff_frames = 0.0
	if dark_mode:
		clear_projectile(runtime, constants)
	return {"handled": true, "activated": true, "skill_name": skill_name, "player_pos": start_pos, "player_speed": float(config.get("player_speed", 0.0)), "special_gauge": next_gauge}


static func update_motion(runtime: Object, delta: float, player_pos: Vector2, special_gauge: float, config: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	var fps_scale: float = max(0.0, delta * 60.0)
	runtime.blade_motion_frames += fps_scale
	runtime.blade_motion_total_frames += fps_scale
	var next_pos: Vector2 = player_pos
	var next_speed: float = 0.0
	if not runtime.visibility_query.is_dash_motion_busy(deps):
		var movement_result: Dictionary = _get_horizontal_motion(runtime, player_pos, fps_scale, config, deps, constants)
		next_pos = _get_vector2(movement_result.get("player_pos", player_pos), player_pos)
		next_speed = float(movement_result.get("player_speed", config.get("player_speed", 0.0)))
	runtime.blade_motion_pos.x = next_pos.x
	var spin_frames: float = float(constants.get("spin_frames", 24.0)) * (float(constants.get("dark_spin_mult", 2.5)) if runtime.blade_dark_mode else 1.0)
	var decel_frames: float = float(constants.get("decel_frames", 12.0)) * (float(constants.get("dark_time_mult", 1.5)) if runtime.blade_dark_mode else 1.0)
	var rest_frames: float = float(constants.get("dark_rest_frames", 90.0)) if runtime.blade_dark_mode else float(constants.get("rest_frames", 66.0))
	var spin_turns: float = float(constants.get("dark_spin_turns", 3.0)) if runtime.blade_dark_mode else float(constants.get("normal_spin_turns", 2.0))
	if runtime.blade_motion_phase < 2:
		runtime.blade_motion_pos.y = ViperSkillGeometry.blade_prep_fall_y(player_pos.y, ViperSkillGeometry.player_floor_y(config), fps_scale, float(constants.get("prep_fall_speed", 3.0)))
		next_pos = runtime.blade_motion_pos
	if ViperSkillGeometry.blade_dark_should_auto_fire(runtime.blade_dark_mode, runtime.blade_motion_phase, runtime.blade_motion_total_frames, float(constants.get("dark_auto_fire_start_frames", 48.0)), float(constants.get("dark_auto_fire_end_frames", 84.0)), _get_vector2(config.get("ball_vel", Vector2.ZERO), Vector2.ZERO), _get_vector2(config.get("ball_pos", Vector2.ZERO), Vector2.ZERO), float(config.get("ball_size", constants.get("dark_default_ball_size", 28.6))), runtime.blade_motion_pos, ViperSkillGeometry.get_paddle_size(config), float(constants.get("dark_auto_fire_near_y", 150.0))):
		runtime.blade_motion_phase = 1
		runtime.blade_motion_frames = decel_frames
	match runtime.blade_motion_phase:
		0:
			var t0: float = ViperSkillGeometry.blade_motion_phase_progress(runtime.blade_motion_frames, spin_frames)
			runtime.blade_spin_angle = ViperSkillGeometry.blade_motion_spin_angle(0, t0, spin_turns)
			if t0 >= 1.0:
				runtime.blade_motion_phase = 1
				runtime.blade_motion_frames = 0.0
			next_pos = runtime.blade_motion_pos
		1:
			var t1: float = ViperSkillGeometry.blade_motion_phase_progress(runtime.blade_motion_frames, decel_frames)
			runtime.blade_spin_angle = ViperSkillGeometry.blade_motion_spin_angle(1, t1, spin_turns)
			if t1 >= 1.0:
				runtime.blade_motion_phase = 2
				runtime.blade_motion_frames = 0.0
				runtime.blade_spin_angle = 0.0
				runtime.blade_phase2_base_y = min(runtime.blade_motion_pos.y, ViperSkillGeometry.player_floor_y(config))
				runtime.audio_router.stop_blade_spin_sound(runtime, deps)
				launch_projectile(runtime, runtime.blade_motion_pos, config, deps, constants)
			next_pos = runtime.blade_motion_pos
		2:
			var floor_y: float = ViperSkillGeometry.player_floor_y(config)
			var jump_up_frames: float = float(constants.get("dark_rise_frames", 27.0)) if runtime.blade_dark_mode else float(constants.get("air_rise_frames", 18.0))
			var jump_peak: float = float(constants.get("dark_jump_peak", 320.0)) if runtime.blade_dark_mode else float(constants.get("air_jump_peak", 80.0))
			next_pos = ViperSkillGeometry.blade_motion_rest_position(runtime.blade_motion_pos.x, runtime.blade_phase2_base_y, floor_y, runtime.blade_motion_frames, jump_up_frames, rest_frames, jump_peak)
			runtime.blade_motion_pos = next_pos
			if runtime.blade_motion_frames >= rest_frames:
				next_pos = Vector2(runtime.blade_motion_pos.x, floor_y)
				reset_motion_only(runtime, deps)
				runtime.runtime_action_router.force_viper_jetpack_land(deps)
	runtime.blade_motion_pos = next_pos
	return {"handled": true, "activated": false, "skill_name": str(constants.get("dark_blade", "dark_blade")) if runtime.blade_dark_mode else str(constants.get("blade_rush", "blade_rush")), "player_pos": next_pos, "player_speed": next_speed, "special_gauge": special_gauge}


static func launch_projectile(runtime: Object, player_pos: Vector2, config: Dictionary, deps: Dictionary, constants: Dictionary) -> void:
	runtime.audio_router.play_blade_fire_sound(deps)
	var spec: Dictionary = ViperSkillGeometry.blade_projectile_launch_spec(player_pos, ViperSkillGeometry.get_paddle_size(config), runtime.visibility_query.get_runtime_skill_level(deps, "blade_amp"), runtime.blade_dark_mode, float(constants.get("base_width", 350.0)), float(constants.get("base_range", 250.0)), -20.0)
	var size_mult: float = float(spec.get("size_mult", 1.0))
	var range_mult: float = float(spec.get("range_mult", 1.0))
	var launch_pos: Vector2 = _get_vector2(spec.get("pos", Vector2.ZERO), Vector2.ZERO)
	var start_y: float = float(spec.get("start_y", launch_pos.y))
	runtime.blade_projectile_active = true
	runtime.blade_projectile_pos = launch_pos
	runtime.blade_projectile_start_y = start_y
	runtime.blade_projectile_target_y = float(spec.get("target_y", start_y))
	runtime.blade_projectile_width = float(spec.get("width", constants.get("base_width", 350.0)))
	reset_primary_projectile_runtime_state(runtime)
	if runtime.blade_dark_mode:
		runtime.blade_dark_fire_frames = 0.0
		runtime.blade_dark_combo_window = false
	else:
		runtime.blade_air_fire_frames = 0.0
		runtime.blade_air_combo_window = false
		runtime.nerve_strike_combo_used = false
	var impact_effects: Object = deps.get("impact_effects", null)
	if impact_effects != null and impact_effects.has_method("create_energy_explosion"):
		impact_effects.create_energy_explosion(runtime.blade_projectile_pos, 0.72 if runtime.blade_dark_mode else 0.58, 0.88 if runtime.blade_dark_mode else 0.72)
	if runtime._is_dual_glitch_clone_replication_active(deps):
		_spawn_dual_glitch_replicas(runtime, size_mult, range_mult, constants)


static func reset_primary_projectile_runtime_state(runtime: Object) -> void:
	runtime.blade_projectile_hit_ball = false
	runtime.blade_projectile_trail.clear()
	runtime.blade_projectile_fadeout = false
	runtime.blade_projectile_fadeout_frames = 0.0


static func apply_hit(runtime: Object, scene: Dictionary, context: Dictionary, deps: Dictionary, dark_mode: bool, allow_gold: bool, allow_followup: bool, allow_combo: bool, hit_speed_scale: float, constants: Dictionary) -> Dictionary:
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", context.get("ball_pos", Vector2.ZERO)), Vector2.ZERO)
	var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", context.get("ball_vel", Vector2.ZERO)), Vector2.ZERO)
	var impact_boost: float = max(1.0, float(scene.get("ball_impact_boost", 1.0)))
	var speed_cap: float = float(constants.get("dark_max_ball_speed", 50.0)) if dark_mode else float(constants.get("air_max_ball_speed", 40.0))
	var next_vel: Vector2 = ViperSkillGeometry.blade_hit_velocity(ball_vel, impact_boost, speed_cap, runtime.visibility_query.get_runtime_skill_level(deps, "blade_amp"), dark_mode, hit_speed_scale, float(constants.get("air_hit_speed_mult", 2.1)), float(constants.get("dark_hit_speed_mult", 2.4)))
	runtime.blade_hit_speed_cap_active = speed_cap
	var released_chaos: bool = runtime._release_chaos_blackhole_from_hit_result(deps, context)
	if dark_mode and allow_combo:
		var skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
		var marshal_kick: String = str(constants.get("marshal_kick", "marshal_kick"))
		var phantom_kick: String = str(constants.get("phantom_kick", "phantom_kick"))
		if runtime.visibility_query.is_skill_equipped(skill_config, marshal_kick) and runtime.visibility_query.context_has_enough_gauge(context, runtime.visibility_query.get_marshal_skill_cost(skill_config, marshal_kick, phantom_kick)) and runtime.visibility_query.is_configured_skill_ready(marshal_kick, deps, -1):
			runtime.marshal_ready = true
			runtime.marshal_ready_frames = float(constants.get("marshal_ready_frames", 90.0))
			runtime.marshal_phantom_allowed = false
			runtime._clear_double_marshal_ready_window()
			runtime._clear_marshal_first_hit_pending()
	runtime.runtime_action_router.trigger_feedback(deps, float(constants.get("dark_hit_shake_amount", 0.20)) if dark_mode else float(constants.get("air_hit_shake_amount", 0.15)), float(constants.get("dark_hit_shake_intensity", 6.0)) if dark_mode else float(constants.get("air_hit_shake_intensity", 4.8)))
	var pulse_kind: String = str(constants.get("dark_hit_pulse_kind", "viper_dark_blade")) if dark_mode else str(constants.get("air_hit_pulse_kind", "viper_blade"))
	var pulse_intensity: float = float(constants.get("dark_hit_pulse_intensity", 1.0)) if dark_mode else float(constants.get("air_hit_pulse_intensity", 0.86))
	if not runtime._register_ball_hit_pulse(ball_pos, next_vel, deps, pulse_intensity, pulse_kind):
		var hit_color: Color = constants.get("dark_fallback_hit_color", Color(1.0, 0.16, 0.24, 1.0)) if dark_mode else constants.get("air_fallback_hit_color", Color(1.0, 0.38, 1.0, 1.0))
		runtime._spawn_fallback_hit_impact(ball_pos, next_vel, deps, hit_color, float(constants.get("dark_fallback_particle_intensity", 1.6)) if dark_mode else float(constants.get("air_fallback_particle_intensity", 1.25)), float(constants.get("dark_fallback_explosion_scale", 1.05)) if dark_mode else float(constants.get("air_fallback_explosion_scale", 0.82)), float(constants.get("dark_fallback_explosion_intensity", 1.15)) if dark_mode else float(constants.get("air_fallback_explosion_intensity", 0.95)))
	if allow_followup:
		_try_append_followup_from_hit(runtime, context, dark_mode, deps, constants)
	var result: Dictionary = {"ball_vel": next_vel, "ball_impact_boost": impact_boost, "player_collision_cooldown": max(float(constants.get("player_collision_cooldown", 6.0)), float(scene.get("player_collision_cooldown", 0.0)))}
	if allow_gold:
		result.merge(runtime.runtime_action_router.award_skill_gold(deps, int(constants.get("hit_gold", 30)), context), true)
	return runtime._mark_result_released_chaos_hit(result, released_chaos)


static func append_followup_projectile(runtime: Object, pos: Vector2, start_y: float, target_y: float, width: float, dark_mode: bool, hit_speed_scale: float, extra_fields: Dictionary) -> void:
	var projectile: Dictionary = {"pos": pos, "start_y": start_y, "target_y": target_y, "width": width, "dark_mode": dark_mode, "trail": [], "fadeout": false, "fadeout_frames": 0.0, "hit_ball": false, "allow_gold": false, "allow_followup": false, "allow_combo": false, "hit_speed_scale": hit_speed_scale}
	for key in extra_fields.keys():
		projectile[key] = extra_fields[key]
	runtime.blade_followup_projectiles.append(projectile)


static func destroy_stage2_rocks(blade_rect: Rect2, deps: Dictionary, context: Dictionary) -> int:
	if int(context.get("current_stage", 1)) != 2:
		return 0
	var hit_count := 0
	var seen_instance_ids: Dictionary = {}
	for key in ["stage_background", "stage2_pillar_background"]:
		var target: Object = deps.get(key, null)
		if target == null or not target.has_method("resolve_blade_projectile_collision"):
			continue
		var instance_id: int = target.get_instance_id()
		if seen_instance_ids.has(instance_id):
			continue
		seen_instance_ids[instance_id] = true
		hit_count += max(0, int(target.resolve_blade_projectile_collision(blade_rect, deps, context)))
	return hit_count


static func get_skill_cost(runtime: Object, skill_config: Object, deps: Dictionary, skill_name: String, constants: Dictionary) -> float:
	return runtime.skill_scaling.get_blade_skill_cost(runtime.visibility_query.get_skill_cost(skill_config, skill_name), runtime.visibility_query.get_runtime_skill_level(deps, "blade_amp"), skill_name, str(constants.get("blade_rush", "blade_rush")), str(constants.get("dark_blade", "dark_blade")))


static func enter_spin_phase(runtime: Object) -> void:
	runtime.blade_motion_phase = 0
	runtime.blade_motion_frames = 0.0
	runtime.blade_motion_total_frames = 0.0
	runtime.blade_spin_angle = 0.0


static func reset_combo_windows(runtime: Object) -> void:
	runtime.blade_air_fire_frames = 0.0
	runtime.blade_air_combo_window = false
	runtime.blade_dark_fire_frames = 0.0
	runtime.blade_dark_combo_window = false


static func open_dark_blade_start_window(runtime: Object, constants: Dictionary) -> void:
	runtime.dark_blade_window = true
	runtime.dark_blade_window_frames = float(constants.get("dark_window_frames", 180.0))


static func reset_motion_only(runtime: Object, deps: Dictionary, _constants: Dictionary = {}) -> void:
	runtime.audio_router.stop_blade_spin_sound(runtime, deps)
	runtime.blade_motion_active = false
	enter_spin_phase(runtime)
	runtime.blade_dark_mode = false
	runtime.blade_motion_start_pos = Vector2.ZERO
	runtime.blade_motion_pos = Vector2.ZERO
	runtime.blade_phase2_base_y = 0.0
	runtime.blade_paddle_size = Vector2(155.0, 50.0)
	reset_combo_windows(runtime)


static func clear_projectile(runtime: Object, constants: Dictionary) -> void:
	runtime.blade_projectile_active = false
	runtime.blade_projectile_pos = Vector2.ZERO
	runtime.blade_projectile_start_y = 0.0
	runtime.blade_projectile_target_y = 0.0
	runtime.blade_projectile_width = float(constants.get("base_width", 350.0))
	reset_primary_projectile_runtime_state(runtime)


static func _get_horizontal_motion(runtime: Object, player_pos: Vector2, fps_scale: float, config: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	var input_snapshot: Dictionary = {}
	var input_reader: Object = deps.get("input_reader", null)
	if input_reader != null and input_reader.has_method("get_snapshot"):
		var raw_input_snapshot: Variant = input_reader.get_snapshot()
		if raw_input_snapshot is Dictionary:
			input_snapshot = raw_input_snapshot
	var direction: float = float(input_snapshot.get("direction", 0.0))
	if abs(direction) > 0.01:
		direction = -1.0 if direction < 0.0 else 1.0
	else:
		var left_pressed: bool = bool(input_snapshot.get("left_pressed", false))
		var right_pressed: bool = bool(input_snapshot.get("right_pressed", false))
		direction = 0.0 if left_pressed == right_pressed else (-1.0 if left_pressed else 1.0)
	return ViperSkillGeometry.blade_horizontal_control_motion(player_pos, float(config.get("player_speed", 0.0)), direction, fps_scale, config, ViperSkillGeometry.player_floor_y(config), ViperSkillGeometry.get_paddle_size(config).x, float(constants.get("jetpack_max_height", 200.0)), float(constants.get("airborne_move_bonus_max", 2.15)), runtime.blade_dark_mode)


static func _spawn_dual_glitch_replicas(runtime: Object, size_mult: float, range_mult: float, constants: Dictionary) -> void:
	var replica_origins: Array = runtime.visibility_query.get_dual_glitch_replication_origins(runtime._get_dual_glitch_clone_rect_entries(true, false))
	if replica_origins.is_empty():
		return
	var replica_width: float = float(constants.get("base_width", 350.0)) * max(float(constants.get("dual_glitch_replica_min_scale", 0.1)), size_mult)
	var replica_travel: float = float(constants.get("base_range", 250.0)) * max(float(constants.get("dual_glitch_replica_min_scale", 0.1)), range_mult)
	for origin_value in replica_origins:
		if not (origin_value is Dictionary):
			continue
		var origin: Dictionary = origin_value
		var replica_start_y: float = float(origin.get("y", runtime.dual_glitch_base_pos.y)) + float(constants.get("followup_start_y_offset", -20.0))
		append_followup_projectile(runtime, Vector2(float(origin.get("x", runtime.dual_glitch_base_pos.x)), replica_start_y), replica_start_y, replica_start_y - replica_travel, replica_width, runtime.blade_dark_mode, float(constants.get("dual_glitch_replica_hit_speed_scale", 1.0)), {"dual_glitch_replica": true, "side": int(origin.get("side", 0))})


static func _try_append_followup_from_hit(runtime: Object, context: Dictionary, dark_mode: bool, deps: Dictionary, constants: Dictionary) -> void:
	var blade_amp_level: int = max(0, runtime.visibility_query.get_runtime_skill_level(deps, "blade_amp"))
	var chance_pct: int = runtime.skill_scaling.get_blade_amp_followup_chance_pct(blade_amp_level)
	if chance_pct <= 0 or randf() >= float(chance_pct) / 100.0:
		return
	var player_pos: Vector2 = _get_vector2(context.get("player_pos", runtime.blade_motion_pos), runtime.blade_motion_pos)
	var player_size: Vector2 = _get_vector2(context.get("player_paddle_size", runtime.blade_paddle_size), runtime.blade_paddle_size)
	var spec: Dictionary = ViperSkillGeometry.blade_projectile_launch_spec(player_pos, player_size, blade_amp_level, dark_mode, float(constants.get("base_width", 350.0)), float(constants.get("base_range", 250.0)), float(constants.get("followup_start_y_offset", -20.0)), float(constants.get("amp_followup_width_scale", 0.72)), float(constants.get("amp_followup_min_width", 80.0)))
	var followup_pos: Vector2 = _get_vector2(spec.get("pos", Vector2.ZERO), Vector2.ZERO)
	var start_y: float = float(spec.get("start_y", followup_pos.y))
	append_followup_projectile(runtime, followup_pos, start_y, float(spec.get("target_y", start_y)), float(spec.get("width", constants.get("base_width", 350.0))), dark_mode, float(constants.get("amp_followup_hit_speed_scale", 0.55)), {})


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
