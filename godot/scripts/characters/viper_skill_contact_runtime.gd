extends RefCounted

const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")


static func register_player_ball_contact(runtime: Object, deps: Dictionary, constants: Dictionary) -> void:
	var dash_snapshot: Dictionary = runtime.visibility_query.get_dash_snapshot(deps.get("dash_state", null))
	if not bool(dash_snapshot.get("is_half", false)) and not bool(runtime.core_flip_consumed) and int(runtime.core_flip_last_dash_start_msec) > int(constants.get("core_flip_dash_start_valid_after_msec", -99999)):
		var now_msec: int = Time.get_ticks_msec(); var dash_active: bool = bool(dash_snapshot.get("active", false)); var dash_elapsed_msec: int = now_msec - int(runtime.core_flip_last_dash_start_msec)
		if dash_elapsed_msec >= 0 and (dash_active or dash_elapsed_msec <= int(constants.get("core_flip_dash_success_window_msec", 400))):
			var skill_config: Object = runtime.visibility_query.get_viper_skill_config(deps)
			if runtime.visibility_query.is_skill_equipped(skill_config, str(constants.get("core_flip", "core_flip"))):
				runtime.core_flip_ready_msec = now_msec; runtime.core_flip_buffered_until_msec = 0
	var four_poisons_level: int = runtime.visibility_query.get_runtime_skill_level(deps, "four_poisons")
	if runtime.dive_active and runtime.dive_phase == 0 and four_poisons_level < 3:
		runtime._reset_dive_runtime(false)
	if runtime.dual_glitch_state == "startup" and four_poisons_level < 3:
		runtime._reset_dual_glitch_runtime(false)
	if runtime.chaos_state == "startup":
		if four_poisons_level < 3:
			runtime._reset_chaos_spear_runtime(false)
	elif runtime.chaos_state == "blackhole":
		runtime._release_chaos_blackhole(true, {}, deps)


static func consume_phantom_kick_knockback(runtime: Object, ball_pos: Vector2, boss_pos: Vector2, boss_width: float, deps: Dictionary, constants: Dictionary) -> Dictionary:
	runtime.phantom_kick_speed_limit_disabled = false
	if not bool(runtime.phantom_kick_knockback_pending):
		return {}
	runtime.phantom_kick_knockback_pending = false
	if runtime._is_stage2_speed_defense_boss_immune({}, deps):
		return {}
	var knockback_vel: float = ViperSkillGeometry.phantom_kick_knockback_velocity(ball_pos, boss_pos, boss_width, float(constants.get("phantom_kick_knockback_distance", 18.0))); var ai_state: Object = deps.get("ai_state", null)
	if ai_state != null and ai_state.has_method("start_paddle_hit_knockback"):
		ai_state.start_paddle_hit_knockback(knockback_vel, float(constants.get("phantom_kick_knockback_frames", 36.0)), float(constants.get("phantom_kick_knockback_decay", 0.88)), true)
	return {"boss_vel": knockback_vel}


static func consume_kick_skill_knockback(runtime: Object, ball_pos: Vector2, boss_pos: Vector2, boss_width: float, context: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	var bonus_pct: int = max(0, int(runtime.kick_skill_knockback_pending_pct))
	runtime.kick_skill_knockback_pending_pct = 0
	if bonus_pct <= 0:
		return {}
	if runtime._is_stage2_speed_defense_boss_immune(context, deps):
		return {"viper_knockback_overlay_active": false}
	var knockback_vel: float = ViperSkillGeometry.kick_guard_knockback_velocity(boss_pos, boss_width, context, bonus_pct, float(constants.get("kick_guard_knockback_fire_base", 22.0)), float(constants.get("kick_guard_distance_multiplier", 1.56)))
	if abs(knockback_vel) <= 0.01:
		return {"viper_knockback_overlay_active": false}
	runtime.runtime_action_router.trigger_feedback(deps, 0.10, 4.0)
	runtime.audio_router.play_kick_guard_knockback_sound(deps)
	var intensity: float = clamp(float(bonus_pct) / 150.0, 0.7, 1.4)
	runtime._spawn_fallback_hit_impact(ball_pos, Vector2(0.0, 22.0), deps, Color(1.0, 0.23, 0.08, 1.0), 1.15 * intensity, 0.72 * intensity, 0.92)
	var ai_state: Object = deps.get("ai_state", null)
	if ai_state != null and ai_state.has_method("start_paddle_hit_knockback"):
		ai_state.start_paddle_hit_knockback(knockback_vel, float(constants.get("kick_guard_knockback_frames", 18.0)), float(constants.get("kick_guard_knockback_decay", 0.85)), true)
	return {"boss_vel": knockback_vel, "viper_knockback_overlay_active": false, "kick_skill_knockback_consumed": true}


static func consume_kick_guard_speed_reduction(runtime: Object, ball_vel: Vector2, context: Dictionary, deps: Dictionary, _constants: Dictionary) -> Dictionary:
	var reduction_pct: int = clampi(int(runtime.kick_guard_speed_reduction_pending_pct), 0, 95)
	runtime.kick_guard_speed_reduction_pending_pct = 0
	if reduction_pct <= 0 or _normalize_league_mode(str(context.get("ai_mode", "champion"))) == "junior":
		return {}
	var speed: float = ball_vel.length()
	if speed <= 0.01:
		return {}
	var next_vel: Vector2 = ball_vel.normalized() * (speed * (1.0 - float(reduction_pct) / 100.0))
	var ball_physics: Object = deps.get("ball_physics", null)
	if ball_physics != null and ball_physics.has_method("enforce_minimum_rally_speed"):
		next_vel = ball_physics.enforce_minimum_rally_speed(next_vel)
	return {
		"ball_vel": next_vel,
		"viper_guard_speed_reduction_consumed": true,
		"viper_guard_speed_reduction_pct": reduction_pct,
	}


static func apply_shadow_step_paddle_hit(runtime: Object, ball_vel: Vector2, context: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	if not bool(runtime.shadow_kick_ready) or bool(runtime.shadow_hit_consumed):
		return {}
	if int(runtime.shadow_step_activation_msec) > int(constants.get("shadow_step_activation_valid_after_msec", -99999)):
		var elapsed_msec: int = Time.get_ticks_msec() - int(runtime.shadow_step_activation_msec)
		if elapsed_msec > int(constants.get("shadow_step_paddle_hit_window_msec", 5000)):
			runtime._clear_shadow_kick_ready()
			return {}
	var fallback_size: Vector2 = ViperSkillGeometry.get_paddle_size(context)
	var player_pos: Vector2 = _get_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO); var player_size: Vector2 = _get_vector2(context.get("player_paddle_size", fallback_size), fallback_size)
	var hit_center: Vector2 = player_pos + player_size * 0.5; var hit_size: Vector2 = Vector2(player_size.x + float(constants.get("shadow_step_paddle_hit_padding", 40.0)), player_size.y + float(constants.get("shadow_step_paddle_hit_padding", 40.0)))
	var scene: Dictionary = {"ball_pos": ViperSkillGeometry.get_ball_pos(context), "ball_vel": ball_vel, "ball_impact_boost": float(context.get("ball_impact_boost", 1.0))}; var result: Dictionary = runtime._apply_shadow_step_hit(hit_center, hit_size, int(runtime.shadow_hologram_kick_dir), str(constants.get("shadow_step_paddle_hit_source", "paddle")), scene, context, deps)
	if not result.is_empty():
		result["hit"] = true; result["suppress_base_gauge"] = true
	return result


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback


static func _normalize_league_mode(ai_mode: String) -> String:
	var normalized: String = ai_mode.strip_edges().to_lower().replace(" ", "").replace("_", "").replace("-", "")
	if normalized == "junior" or normalized == "juniorleague":
		return "junior"
	if normalized == "mythic" or normalized == "mythicleague":
		return "mythic"
	return "champion"
