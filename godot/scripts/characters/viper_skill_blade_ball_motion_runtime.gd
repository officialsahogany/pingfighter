extends RefCounted

const ViperSkillGeometry := preload("res://scripts/characters/viper_skill_geometry.gd")


static func apply_motion(runtime: Object, fps_scale: float, scene: Dictionary, context: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if not (runtime.blade_projectile_active or not runtime.blade_followup_projectiles.is_empty()):
		return result
	var motion_context: Dictionary = context.duplicate()
	motion_context.merge(scene, true)
	if runtime.blade_projectile_active:
		result = _apply_primary_projectile(runtime, fps_scale, scene, motion_context, deps, constants)
		if not result.is_empty():
			scene.merge(result, true)
			motion_context.merge(result, true)
	if not runtime.blade_followup_projectiles.is_empty():
		var follow_result: Dictionary = _apply_followup_projectiles(runtime, fps_scale, scene, motion_context, deps, constants)
		if not follow_result.is_empty():
			result.merge(follow_result, true)
	return result


static func _apply_primary_projectile(runtime: Object, fps_scale: float, scene: Dictionary, motion_context: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var blade_amp_level: int = max(0, runtime.visibility_query.get_runtime_skill_level(deps, "blade_amp"))
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", motion_context.get("ball_pos", Vector2.ZERO)), Vector2.ZERO)
	var projectile_speed: float = float(constants.get("projectile_speed", 12.0))
	runtime.blade_projectile_pos = ViperSkillGeometry.blade_projectile_motion(runtime.blade_projectile_pos, ball_pos, fps_scale, projectile_speed, blade_amp_level, runtime.blade_dark_mode, ViperSkillGeometry.blade_projectile_allows_homing(runtime.blade_projectile_hit_ball, runtime.blade_projectile_fadeout))
	runtime.blade_projectile_trail = ViperSkillGeometry.blade_projectile_trail_next(runtime.blade_projectile_trail, runtime.blade_projectile_pos, int(constants.get("trail_max", 20)))
	var blade_rect: Rect2 = ViperSkillGeometry.blade_rect(runtime.blade_projectile_pos, runtime.blade_projectile_width, runtime.blade_dark_mode, float(constants.get("hitbox_height", 55.0)), float(constants.get("dark_hitbox_height", 83.0)))
	runtime._destroy_blade_stage2_rocks(blade_rect, deps, motion_context)
	if ViperSkillGeometry.blade_projectile_hits_ball(blade_rect, ViperSkillGeometry.ball_rect(scene, motion_context), bool(motion_context.get("ball_active", false)), runtime.blade_projectile_hit_ball, runtime.blade_projectile_fadeout):
		runtime.blade_projectile_hit_ball = true
		result = runtime._apply_blade_hit(scene, motion_context, deps, runtime.blade_dark_mode, true, true, true, 1.0)
	if ViperSkillGeometry.blade_projectile_should_start_fadeout(runtime.blade_projectile_pos.y, runtime.blade_projectile_target_y, runtime.blade_projectile_fadeout):
		runtime.blade_projectile_fadeout = true
		runtime.blade_projectile_fadeout_frames = float(constants.get("fadeout_frames", 30.0))
	var fadeout_tick: Dictionary = ViperSkillGeometry.blade_projectile_fadeout_tick(runtime.blade_projectile_fadeout, runtime.blade_projectile_fadeout_frames, fps_scale)
	runtime.blade_projectile_fadeout_frames = float(fadeout_tick.get("frames", runtime.blade_projectile_fadeout_frames))
	if bool(fadeout_tick.get("expired", false)):
		runtime._clear_blade_projectile()
	return result


static func _apply_followup_projectiles(runtime: Object, fps_scale: float, scene: Dictionary, motion_context: Dictionary, deps: Dictionary, constants: Dictionary) -> Dictionary:
	var follow_result: Dictionary = {}
	var updated_projectiles: Array = []
	var blade_amp_level: int = max(0, runtime.visibility_query.get_runtime_skill_level(deps, "blade_amp"))
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", motion_context.get("ball_pos", Vector2.ZERO)), Vector2.ZERO)
	var projectile_speed: float = float(constants.get("projectile_speed", 12.0))
	for projectile_value in runtime.blade_followup_projectiles:
		if not (projectile_value is Dictionary):
			continue
		var projectile: Dictionary = projectile_value
		var dark_mode: bool = bool(projectile.get("dark_mode", false))
		var projectile_pos: Vector2 = _get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
		projectile_pos = ViperSkillGeometry.blade_projectile_motion(projectile_pos, ball_pos, fps_scale, projectile_speed, blade_amp_level, dark_mode, ViperSkillGeometry.blade_projectile_allows_homing(bool(projectile.get("hit_ball", false)), bool(projectile.get("fadeout", false))))
		projectile["pos"] = projectile_pos
		var trail: Array = projectile.get("trail", [])
		projectile["trail"] = ViperSkillGeometry.blade_projectile_trail_next(trail, projectile_pos, int(constants.get("followup_trail_max", 16)))
		var blade_rect := ViperSkillGeometry.blade_rect(projectile_pos, float(projectile.get("width", constants.get("base_width", 350.0))), dark_mode, float(constants.get("hitbox_height", 55.0)), float(constants.get("dark_hitbox_height", 83.0)))
		runtime._destroy_blade_stage2_rocks(blade_rect, deps, motion_context)
		if ViperSkillGeometry.blade_projectile_hits_ball(blade_rect, ViperSkillGeometry.ball_rect(scene, motion_context), bool(motion_context.get("ball_active", false)), bool(projectile.get("hit_ball", false)), bool(projectile.get("fadeout", false))):
			projectile["hit_ball"] = true
			follow_result = runtime._apply_blade_hit(scene, motion_context, deps, dark_mode, bool(projectile.get("allow_gold", false)), bool(projectile.get("allow_followup", false)), bool(projectile.get("allow_combo", false)), float(projectile.get("hit_speed_scale", 1.0)))
			projectile["fadeout"] = true
			projectile["fadeout_frames"] = float(constants.get("fadeout_frames", 30.0))
		if ViperSkillGeometry.blade_projectile_should_start_fadeout(projectile_pos.y, float(projectile.get("target_y", projectile_pos.y)), bool(projectile.get("fadeout", false))):
			projectile["fadeout"] = true
			projectile["fadeout_frames"] = float(constants.get("fadeout_frames", 30.0))
		var fadeout_frames: float = float(projectile.get("fadeout_frames", 0.0))
		var fadeout_tick: Dictionary = ViperSkillGeometry.blade_projectile_fadeout_tick(bool(projectile.get("fadeout", false)), fadeout_frames, fps_scale)
		projectile["fadeout_frames"] = float(fadeout_tick.get("frames", fadeout_frames))
		if bool(fadeout_tick.get("expired", false)):
			continue
		updated_projectiles.append(projectile)
	runtime.blade_followup_projectiles = updated_projectiles
	return follow_result


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
