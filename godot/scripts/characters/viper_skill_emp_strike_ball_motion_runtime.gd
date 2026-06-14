extends RefCounted

const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")


static func apply_motion(runtime: Object, scene: Dictionary, context: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	if not bool(context.get("ball_active", false)):
		return {}
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", context.get("ball_pos", Vector2.ZERO)), Vector2.ZERO)
	if runtime.dive_active and runtime.dive_phase == 2 and not runtime.dive_ball_boosted:
		var primary_result: Dictionary = _try_primary_dive_hit(runtime, ball_pos, scene, context, deps, constants)
		if not primary_result.is_empty():
			return primary_result
	if runtime.dual_glitch_clone_dive_entries.is_empty():
		return {}
	return _try_clone_dive_hit(runtime, ball_pos, scene, context, deps, constants)


static func _try_primary_dive_hit(runtime: Object, ball_pos: Vector2, scene: Dictionary, context: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	var vertical_gap: float = runtime.dive_shockwave_pos.y - ball_pos.y
	if vertical_gap < 0.0 or vertical_gap > float(constants.get("shockwave_height", 120.0)):
		return {}
	runtime.dive_ball_boosted = true
	var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", context.get("ball_vel", Vector2.ZERO)), Vector2.ZERO)
	var next_vel: Vector2 = ViperSkillGeometry.emp_strike_hit_velocity(ball_vel)
	var released_chaos: bool = runtime._release_chaos_blackhole_from_hit_result(deps, context)
	runtime._start_dive_slip_for_height(ball_pos, context, deps, runtime.dive_height_snapshot, false)
	runtime.dive_hit_text_timer = float(constants.get("hit_text_frames", 50.0))
	runtime.dive_hit_text_pos = ball_pos
	runtime.dive_hit_text_height_ratio = clamp(runtime.dive_height_snapshot / float(constants.get("jetpack_max_height", 200.0)), 0.0, 1.0)
	runtime.dive_hit_feedback_msec = Time.get_ticks_msec()
	runtime.runtime_action_router.trigger_feedback(deps, 0.20, 5.5)
	if not runtime._register_ball_hit_pulse(ball_pos, next_vel, deps, 0.92, "viper_emp_strike"):
		runtime._spawn_fallback_hit_impact(ball_pos, next_vel, deps, Color(0.40, 0.90, 1.0, 1.0), 1.25, 0.86, 1.0)
	var result := {"ball_vel": next_vel, "ball_impact_boost": max(1.0, float(scene.get("ball_impact_boost", 1.0))), "player_collision_cooldown": max(float(constants.get("player_collision_cooldown", 6.0)), float(scene.get("player_collision_cooldown", 0.0)))}
	result.merge(runtime.runtime_action_router.award_skill_gold(deps, int(constants.get("hit_gold", 20)), context), true)
	return runtime._mark_result_released_chaos_hit(result, released_chaos)


static func _try_clone_dive_hit(runtime: Object, ball_pos: Vector2, scene: Dictionary, context: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	for index in range(runtime.dual_glitch_clone_dive_entries.size()):
		var entry_value: Variant = runtime.dual_glitch_clone_dive_entries[index]
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if not bool(entry.get("activated", false)) or bool(entry.get("ball_boosted", false)):
			continue
		var vertical_gap: float = float(entry.get("y", runtime.dive_shockwave_pos.y)) - ball_pos.y
		if vertical_gap < 0.0 or vertical_gap > float(constants.get("shockwave_height", 120.0)):
			continue
		entry["ball_boosted"] = true
		runtime.dual_glitch_clone_dive_entries[index] = entry
		var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", context.get("ball_vel", Vector2.ZERO)), Vector2.ZERO)
		var next_vel: Vector2 = ViperSkillGeometry.emp_strike_hit_velocity(ball_vel)
		var released_chaos: bool = runtime._release_chaos_blackhole_from_hit_result(deps, context)
		runtime._start_dive_slip_for_height(ball_pos, context, deps, float(entry.get("height_snapshot", runtime.dive_height_snapshot)), true)
		runtime.runtime_action_router.trigger_feedback(deps, 0.13, 3.6)
		runtime._register_ball_hit_pulse(ball_pos, next_vel, deps, 0.58, "viper_dual_glitch_emp")
		var result: Dictionary = {"ball_vel": next_vel, "ball_impact_boost": max(1.0, float(scene.get("ball_impact_boost", 1.0))), "player_collision_cooldown": max(float(constants.get("player_collision_cooldown", 6.0)), float(scene.get("player_collision_cooldown", 0.0))), "viper_dual_glitch_clone_emp_hit": true}
		return runtime._mark_result_released_chaos_hit(result, released_chaos)
	return {}


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
