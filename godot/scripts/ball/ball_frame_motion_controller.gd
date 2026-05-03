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
			"ball_size": float(context.get("ball_size", 28.6)),
			"player_has_hit_sprite": bool(context.get("player_has_hit_sprite", false)),
			"player_hit_anim_duration": float(context.get("player_hit_anim_duration", 0.40)),
		},
		deps
	)
	scene.merge(result, true)


func cap_ball_speed(scene: Dictionary, deps: Dictionary) -> void:
	apply_ball_speed_limits(scene, deps)


func apply_ball_speed_limits(scene: Dictionary, deps: Dictionary) -> void:
	var ball_physics: Object = deps.get("ball_physics", null)
	if ball_physics == null:
		return
	var velocity: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	if ball_physics.has_method("enforce_minimum_rally_speed"):
		velocity = ball_physics.enforce_minimum_rally_speed(velocity)
	if ball_physics.has_method("cap_base_speed"):
		velocity = ball_physics.cap_base_speed(velocity)
	scene["ball_vel"] = velocity
	if ball_physics.has_method("get_minimum_effective_boost"):
		var minimum_effective_boost: float = float(ball_physics.get_minimum_effective_boost(velocity))
		scene["ball_impact_boost"] = max(
			float(scene.get("ball_impact_boost", 1.0)),
			minimum_effective_boost
		)


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


func apply_stage1_dalji_whip(scene: Dictionary, fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var whip_state: Object = deps.get("stage1_dalji_whip_skill_state", null)
	if whip_state == null or not whip_state.has_method("update_ball_motion"):
		return
	var power_state: Object = deps.get("power_state", null)
	var power_motion_locked: bool = false
	if power_state != null:
		power_motion_locked = bool(power_state.is_freeze_active()) or bool(power_state.is_parabola_active())
	var result: Dictionary = whip_state.update_ball_motion(
		fps_scale,
		_get_vector2(scene, "ball_vel", Vector2.ZERO),
		context,
		power_motion_locked
	)
	if result.has("ball_vel"):
		scene["ball_vel"] = _get_vector2(result, "ball_vel", _get_vector2(scene, "ball_vel", Vector2.ZERO))


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)
