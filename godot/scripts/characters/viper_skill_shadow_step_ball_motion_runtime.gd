extends RefCounted

const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")


static func apply_motion(runtime: Object, fps_scale: float, scene: Dictionary, context: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if not bool(context.get("ball_active", false)):
		return result
	var motion_context: Dictionary = context.duplicate()
	motion_context.merge(scene, true)
	var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	if runtime.shadow_wave_active:
		ball_vel = _apply_wave_motion(runtime, fps_scale, scene, motion_context, deps, constants, result, ball_vel)
	if result.is_empty() and runtime.shadow_hologram_active:
		ball_vel = _apply_hologram_motion(runtime, scene, motion_context, deps, constants, result, ball_vel)
	if runtime.shadow_curve_active and ball_vel.length() > 0.0:
		var curve_motion: Dictionary = ViperSkillGeometry.shadow_step_curve_motion(ball_vel, runtime.shadow_curve_timer, runtime.shadow_curve_total, runtime.shadow_curve_force, runtime.shadow_curve_dir, fps_scale)
		var curved_vel: Vector2 = _get_vector2(curve_motion.get("ball_vel", ball_vel), ball_vel)
		runtime.shadow_curve_timer = float(curve_motion.get("timer", 0.0))
		runtime.shadow_curve_active = bool(curve_motion.get("active", false))
		if curved_vel != ball_vel:
			result["ball_vel"] = curved_vel
	return result


static func _apply_wave_motion(runtime: Object, fps_scale: float, scene: Dictionary, motion_context: Dictionary, deps: Dictionary, constants: Dictionary, result: Dictionary, ball_vel: Vector2) -> Vector2:
	var wave_speed: float = float(constants.get("wave_speed", 25.0))
	var wave_motion: Dictionary = ViperSkillGeometry.shadow_step_wave_motion(runtime.shadow_wave_pos, runtime.shadow_wave_dir, wave_speed, fps_scale, runtime.shadow_wave_target_x)
	runtime.shadow_wave_pos = _get_vector2(wave_motion.get("pos", runtime.shadow_wave_pos), runtime.shadow_wave_pos)
	runtime.shadow_wave_trail.append(runtime.shadow_wave_pos)
	while runtime.shadow_wave_trail.size() > int(constants.get("wave_trail_max", 12)):
		runtime.shadow_wave_trail.pop_front()
	if bool(wave_motion.get("reached_target", false)):
		runtime.shadow_wave_active = false
		runtime.shadow_wave_trail.clear()
	if runtime.shadow_wave_active and not runtime.shadow_wave_hit_ball and not runtime.shadow_hit_consumed:
		var collision_size: Vector2 = _get_vector2(constants.get("wave_collision_size", Vector2(110.0, 90.0)), Vector2(110.0, 90.0))
		var wave_rect: Rect2 = ViperSkillGeometry.shadow_step_wave_rect(runtime.shadow_wave_pos, collision_size)
		if wave_rect.intersects(ViperSkillGeometry.ball_rect(scene, motion_context)):
			runtime.shadow_wave_hit_ball = true
			var gradient_size: Vector2 = _get_vector2(constants.get("wave_gradient_size", Vector2(280.0, 220.0)), Vector2(280.0, 220.0))
			result.merge(runtime._apply_shadow_step_hit(runtime.shadow_wave_pos, gradient_size, runtime.shadow_hologram_kick_dir, "wave", scene, motion_context, deps), true)
	return _get_vector2(result.get("ball_vel", ball_vel), ball_vel)


static func _apply_hologram_motion(runtime: Object, scene: Dictionary, motion_context: Dictionary, deps: Dictionary, constants: Dictionary, result: Dictionary, ball_vel: Vector2) -> Vector2:
	if not (runtime.shadow_hit_consumed or runtime.shadow_hologram_kick_hit):
		if ViperSkillGeometry.shadow_step_hologram_progress(runtime.shadow_hologram_frames, float(constants.get("hologram_frames", 30.0))) > 0.30:
			var hologram_collision_size: Vector2 = Vector2(runtime.shadow_paddle_size.x + 60.0, runtime.shadow_paddle_size.y + 50.0)
			var hologram_hit_rect: Rect2 = ViperSkillGeometry.shadow_step_hologram_hit_rect(runtime.shadow_hologram_target, runtime.shadow_paddle_size, Vector2(60.0, 50.0))
			if hologram_hit_rect.intersects(ViperSkillGeometry.ball_rect(scene, motion_context)):
				runtime.shadow_hologram_kick_hit = true
				result.merge(runtime._apply_shadow_step_hit(hologram_hit_rect.get_center(), hologram_collision_size + Vector2(120.0, 160.0), runtime.shadow_hologram_kick_dir, "hologram", scene, motion_context, deps), true)
	return _get_vector2(result.get("ball_vel", ball_vel), ball_vel)


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
