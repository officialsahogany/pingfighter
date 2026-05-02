extends RefCounted


func step_motion(
	scene: Dictionary,
	fps_scale: float,
	context: Dictionary,
	deps: Dictionary,
	callbacks: Dictionary
) -> String:
	var motion_stepper = deps.get("motion_stepper", null)
	if motion_stepper == null:
		return ""

	var step_result: Dictionary = motion_stepper.step(
		_get_vector2(scene, "ball_pos", Vector2.ZERO),
		_get_vector2(scene, "ball_vel", Vector2.ZERO) * float(scene.get("ball_impact_boost", 1.0)) * fps_scale,
		_get_vector2(scene, "ball_vel", Vector2.ZERO),
		_build_step_context(context, scene)
	)
	scene["ball_pos"] = _get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))

	var event: String = str(step_result.get("event", "none"))
	if event == "wall":
		_process_wall(step_result, scene, context, deps)
	elif event == "player_paddle" or event == "boss_paddle":
		_process_paddle(step_result, scene, context, deps, callbacks)
	elif event == "player_scored":
		return "player"
	elif event == "boss_scored":
		return "boss"
	return ""


func _build_step_context(context: Dictionary, scene: Dictionary) -> Dictionary:
	return {
		"ball_size": float(context.get("ball_size", 22.0)),
		"width": float(context.get("width", 760.0)),
		"height": float(context.get("height", 750.0)),
		"max_step_distance": float(context.get("max_step_distance", 12.0)),
		"player_pos": _get_vector2(context, "player_pos", Vector2.ZERO),
		"player_paddle_size": _get_vector2(context, "player_paddle_size", Vector2.ZERO),
		"boss_pos": _get_vector2(context, "boss_pos", Vector2.ZERO),
		"boss_paddle_size": _get_vector2(context, "boss_paddle_size", Vector2.ZERO),
		"hitbox_padding": float(context.get("hitbox_padding", 5.0)),
		"player_collision_cooldown": float(scene.get("player_collision_cooldown", 0.0)),
		"boss_collision_cooldown": float(scene.get("boss_collision_cooldown", 0.0)),
	}


func _process_wall(step_result: Dictionary, scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var controller = deps.get("wall_bounce_controller", null)
	if controller == null:
		return
	var impact_pos: Vector2 = _get_vector2(step_result, "impact_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))
	var result: Dictionary = controller.process(
		_get_vector2(scene, "ball_vel", Vector2.ZERO),
		float(scene.get("ball_impact_boost", 1.0)),
		str(step_result.get("side", "")),
		impact_pos,
		float(context.get("height", 750.0)),
		{
			"audio": deps.get("audio", null),
			"impact_effects": deps.get("impact_effects", null),
			"stage_background": deps.get("stage_background", null),
			"feedback": deps.get("feedback", null),
		}
	)
	scene.merge(result, true)


func _process_paddle(
	step_result: Dictionary,
	scene: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	callbacks: Dictionary
) -> void:
	var controller = deps.get("paddle_bounce_controller", null)
	if controller == null:
		return
	var paddle_context: Dictionary = context.duplicate()
	paddle_context.merge(scene, true)
	var result: Dictionary = controller.bounce(
		float(step_result.get("paddle_x", 0.0)),
		float(step_result.get("paddle_w", context.get("paddle_width", 155.0))),
		bool(step_result.get("is_player", false)),
		paddle_context,
		deps,
		callbacks
	)
	scene.merge(result, true)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
