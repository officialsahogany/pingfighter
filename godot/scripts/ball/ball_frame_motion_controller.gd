extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")


func update_power_freeze(delta: float, scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var controller: Object = deps.get("power_motion_controller", null)
	if controller == null:
		return
	var result: Dictionary = controller.update_freeze(
		delta,
		_get_vector2(scene, "ball_pos", Vector2.ZERO),
		{
			"freeze_duration": float(context.get("power_smash_freeze_duration", 0.0)),
			"ball_size": float(context.get("ball_size", 22.0)),
		},
		deps
	)
	scene.merge(result, true)


func cap_ball_speed(scene: Dictionary, deps: Dictionary) -> void:
	var ball_physics: Object = deps.get("ball_physics", null)
	if ball_physics == null:
		return
	scene["ball_vel"] = ball_physics.cap_base_speed(_get_vector2(scene, "ball_vel", Vector2.ZERO))


func update_serve_collision_cooldowns(scene: Dictionary, fps_scale: float) -> void:
	scene["player_collision_cooldown"] = max(
		0.0,
		float(scene.get("player_collision_cooldown", 0.0)) - fps_scale
	)
	scene["boss_collision_cooldown"] = max(
		0.0,
		float(scene.get("boss_collision_cooldown", 0.0)) - fps_scale
	)


func apply_impact_decay(scene: Dictionary, fps_scale: float, deps: Dictionary) -> void:
	var ball_physics: Object = deps.get("ball_physics", null)
	if ball_physics == null:
		return
	scene["ball_impact_boost"] = ball_physics.apply_impact_decay(
		_get_vector2(scene, "ball_vel", Vector2.ZERO),
		float(scene.get("ball_impact_boost", 1.0)),
		float(scene.get("ball_min_boost", 0.70)),
		float(scene.get("ball_boost_decay_rate", 0.975)),
		fps_scale
	)


func apply_ball_spin(scene: Dictionary, fps_scale: float, deps: Dictionary) -> void:
	var ball_spin_state: Object = deps.get("ball_spin_state", null)
	if ball_spin_state == null:
		return
	var result: Dictionary = ball_spin_state.apply_spin(
		_get_vector2(scene, "ball_vel", Vector2.ZERO),
		float(scene.get("ball_spin_strength", 0.0)),
		int(scene.get("ball_spin_direction", 0)),
		fps_scale,
		bool(scene.get("drive_ball_active", false))
	)
	scene.merge(result, true)


func apply_power_motion(scene: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var controller: Object = deps.get("power_motion_controller", null)
	if controller == null:
		return
	var result: Dictionary = controller.apply_motion(
		_get_vector2(scene, "ball_vel", Vector2.ZERO),
		fps_scale,
		{
			"gravity_effect": float(context.get("power_smash_gravity_effect", 0.0)),
			"boost_duration": float(context.get("power_smash_boost_duration", 0.0)),
		},
		deps
	)
	scene.merge(result, true)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)
