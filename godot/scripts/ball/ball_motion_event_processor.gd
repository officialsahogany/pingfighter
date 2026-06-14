extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")


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
		_build_step_context(context, scene, deps)
	)
	scene["ball_pos"] = _get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))

	var event: String = str(step_result.get("event", "none"))
	if event == "wall":
		if _process_wall(step_result, scene, context, deps):
			return "rematch"
	elif event == "sand_terrain":
		_process_sand_terrain(step_result, scene, deps)
	elif event == "brick_wall":
		_process_brick_wall(step_result, scene, context, deps)
	elif event == "trampoline":
		_process_trampoline(step_result, scene, context, deps)
	elif event == "horn_strawberry_field":
		_process_horn_strawberry_field(step_result, scene, deps)
	elif event == "holy_barrier":
		_process_holy_barrier(step_result, scene, context, deps)
	elif event == "adversity_armor":
		_process_adversity_armor(step_result, scene, deps)
	elif event == "player_paddle" or event == "boss_paddle":
		_process_paddle(step_result, scene, context, deps, callbacks)
	elif event == "player_scored":
		if _process_stage2_quake_boss_backstop(scene, context, deps):
			return ""
		return "player"
	elif event == "boss_scored":
		return "boss"
	return ""


func _process_sand_terrain(step_result: Dictionary, scene: Dictionary, deps: Dictionary) -> void:
	scene["ball_pos"] = _get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))
	scene["ball_vel"] = _get_vector2(step_result, "ball_vel", _get_vector2(scene, "ball_vel", Vector2.ZERO))
	var impact_speed: float = float(step_result.get("impact_speed", scene["ball_vel"].length()))
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_wall_hit"):
		audio.play_wall_hit(impact_speed)
	var ball_effects: Object = deps.get("ball_effects", null)
	if ball_effects != null and ball_effects.has_method("register_hit_pulse"):
		ball_effects.register_hit_pulse(
			_get_vector2(step_result, "impact_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO)),
			_get_vector2(scene, "ball_vel", Vector2.ZERO),
			0.42,
			"sand_terrain"
		)


func _build_step_context(context: Dictionary, scene: Dictionary, deps: Dictionary) -> Dictionary:
	var step_context: Dictionary = {
		"ball_size": float(context.get("ball_size", 28.6)),
		"width": float(context.get("width", 760.0)),
		"height": float(context.get("height", 750.0)),
		"max_step_distance": float(context.get("max_step_distance", 12.0)),
		"player_pos": _get_vector2(context, "player_pos", Vector2.ZERO),
		"player_paddle_size": _get_vector2(context, "player_paddle_size", Vector2.ZERO),
		"boss_pos": _get_vector2(context, "boss_pos", Vector2.ZERO),
		"boss_paddle_size": _get_vector2(context, "boss_paddle_size", Vector2.ZERO),
		"hitbox_padding": float(context.get("hitbox_padding", 5.0)),
		"viper_dark_blade_rising_contact_active": bool(context.get("viper_dark_blade_rising_contact_active", false)),
		"warp_gate_active": bool(context.get("warp_gate_active", false)),
		"player_paddle_mirror_offset_x": float(context.get("player_paddle_mirror_offset_x", 0.0)),
		"player_collision_cooldown": float(scene.get("player_collision_cooldown", 0.0)),
		"boss_collision_cooldown": float(scene.get("boss_collision_cooldown", 0.0)),
		"stopwatch_score_blocking": bool(context.get("stopwatch_score_blocking", false)),
		"stopwatch_recovery_active": bool(context.get("stopwatch_recovery_active", false)),
		"perk_resume_score_blocking": bool(context.get("perk_resume_score_blocking", false)),
		"weather_event_state": deps.get("weather_event_state", null),
	}
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("get_ball_collision_context"):
		step_context.merge(active_item_runtime.get_ball_collision_context(), true)
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_ball_collision_context"):
		step_context.merge(mythic_item_runtime.get_ball_collision_context(), true)
	if context.has("viper_dual_glitch_state"):
		step_context["viper_dual_glitch_state"] = str(context.get("viper_dual_glitch_state", "idle"))
	if context.has("viper_dual_glitch_clone_rects"):
		step_context["viper_dual_glitch_clone_rects"] = context.get("viper_dual_glitch_clone_rects", [])
	var viper_skill_runtime: Object = deps.get("viper_skill_runtime", null)
	if (
		not step_context.has("viper_dual_glitch_clone_rects")
		and str(context.get("selected_character_type", "smasher")) == "viper"
		and viper_skill_runtime != null
		and viper_skill_runtime.has_method("get_ball_collision_context")
	):
		var viper_collision_context: Dictionary = viper_skill_runtime.get_ball_collision_context()
		if viper_collision_context.has("viper_dual_glitch_state"):
			step_context["viper_dual_glitch_state"] = str(viper_collision_context.get("viper_dual_glitch_state", "idle"))
		if viper_collision_context.has("viper_dual_glitch_clone_rects"):
			step_context["viper_dual_glitch_clone_rects"] = viper_collision_context.get("viper_dual_glitch_clone_rects", [])
	if str(context.get("selected_character_type", "smasher")).strip_edges().to_lower() == "blacksmith":
		var blacksmith_shield_state: Object = deps.get("blacksmith_thor_shield_state", null)
		if blacksmith_shield_state != null and blacksmith_shield_state.has_method("get_ball_collision_context"):
			step_context.merge(blacksmith_shield_state.get_ball_collision_context(step_context), true)
	return step_context


func _process_wall(step_result: Dictionary, scene: Dictionary, context: Dictionary, deps: Dictionary) -> bool:
	var controller = deps.get("wall_bounce_controller", null)
	if controller == null:
		return false
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
			"ball_effects": deps.get("ball_effects", null),
			"stage_background": deps.get("stage_background", null),
			"feedback": deps.get("feedback", null),
		}
	)
	scene.merge(result, true)
	if not bool(result.get("rematch_requested", false)):
		_notify_power_smash_wall_bounce(step_result, deps)
		_apply_chargebag_wall_gauge(scene, context, deps)
	return bool(result.get("rematch_requested", false))


func _process_holy_barrier(step_result: Dictionary, scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var ball_vel: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	var reflected_vel := Vector2(ball_vel.x, -abs(ball_vel.y))
	var whip_state: Object = deps.get("stage1_dalji_whip_skill_state", null)
	if whip_state != null and whip_state.has_method("register_player_hit"):
		var whip_result: Dictionary = whip_state.register_player_hit(reflected_vel, context)
		if not whip_result.is_empty():
			reflected_vel = _get_vector2(whip_result, "ball_vel", reflected_vel)
			scene["ball_impact_boost"] = float(whip_result.get("ball_impact_boost", scene.get("ball_impact_boost", 1.0)))
			scene["ball_boost_decay_rate"] = float(whip_result.get("ball_boost_decay_rate", scene.get("ball_boost_decay_rate", 0.975)))
			scene["ball_min_boost"] = float(whip_result.get("ball_min_boost", scene.get("ball_min_boost", 0.70)))
			if bool(whip_result.get("whip_deactivated", false)):
				scene["stage1_dalji_whip_controls_speed"] = false
	scene["ball_vel"] = reflected_vel
	scene["ball_pos"] = _get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))

	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_wall_hit"):
		audio.play_wall_hit(abs(ball_vel.y))

	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("notify_holy_barrier_hit"):
		active_item_runtime.notify_holy_barrier_hit(_get_vector2(step_result, "impact_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO)))
	_register_ball_hit_pulse(step_result, scene, deps, "holy_barrier", 0.72)


func _process_horn_strawberry_field(step_result: Dictionary, scene: Dictionary, deps: Dictionary) -> void:
	var ball_vel: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	var reflect_speed_mult: float = max(1.0, float(step_result.get("reflect_speed_mult", 1.05)))
	scene["ball_vel"] = Vector2(ball_vel.x, -abs(ball_vel.y) * reflect_speed_mult)
	scene["ball_pos"] = _get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))

	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("notify_horn_strawberry_field_hit"):
		mythic_item_runtime.notify_horn_strawberry_field_hit(
			int(step_result.get("barrier_id", 0)),
			_get_vector2(step_result, "impact_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO)),
			deps
		)
	_register_ball_hit_pulse(step_result, scene, deps, "horn_strawberry_field", 0.72)


func _process_adversity_armor(step_result: Dictionary, scene: Dictionary, deps: Dictionary) -> void:
	var ball_vel: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	var reflected_y: float = -max(abs(ball_vel.y), 8.0)
	scene["ball_vel"] = Vector2(ball_vel.x, reflected_y)
	scene["ball_pos"] = _get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("notify_adversity_armor_barrier_hit"):
		mythic_item_runtime.notify_adversity_armor_barrier_hit(
			_get_vector2(step_result, "impact_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO)),
			ball_vel,
			deps
		)
	_register_ball_hit_pulse(step_result, scene, deps, "adversity_armor", 0.78)


func _process_brick_wall(step_result: Dictionary, scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var ball_vel: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	scene["ball_vel"] = Vector2(ball_vel.x * 0.8, -abs(ball_vel.y))
	scene["ball_pos"] = _get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))

	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	var hit_result: Dictionary = {}
	if active_item_runtime != null and active_item_runtime.has_method("notify_brick_wall_hit"):
		hit_result = active_item_runtime.notify_brick_wall_hit(
			int(step_result.get("wall_index", -1)),
			_get_vector2(step_result, "impact_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))
		)

	var audio: Object = deps.get("audio", null)
	if audio != null:
		if bool(hit_result.get("destroyed", false)) and audio.has_method("play_brick_wall_destroy"):
			audio.play_brick_wall_destroy()
		elif audio.has_method("play_wall_hit"):
			audio.play_wall_hit(abs(ball_vel.y))

	if bool(hit_result.get("destroyed", false)):
		var feedback: Object = deps.get("feedback", null)
		if feedback != null and feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(0.035, 1.1)
	_apply_chargebag_wall_gauge(scene, context, deps)
	_register_ball_hit_pulse(step_result, scene, deps, "brick_wall", 0.58)


func _process_trampoline(step_result: Dictionary, scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var ball_vel: Vector2 = _get_vector2(scene, "ball_vel", Vector2.ZERO)
	var ball_pos: Vector2 = _get_vector2(step_result, "ball_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO))
	# Any trampoline contact is a successful player-side floor save: release
	# the Dalji whip like the holy barrier / lingpet guard precedents, or the
	# still-active whip flips the launch back down every frame (launch-nullify
	# recapture loop that defers the floor loss until the mat expires). Keep
	# the trampoline's own velocities — the whip guard-counter clamp would
	# swallow the slingshot launch overspeed.
	var whip_state: Object = deps.get("stage1_dalji_whip_skill_state", null)
	if whip_state != null and whip_state.has_method("register_player_hit"):
		var whip_result: Dictionary = whip_state.register_player_hit(ball_vel, context)
		if bool(whip_result.get("whip_deactivated", false)):
			scene["stage1_dalji_whip_controls_speed"] = false
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	var hit_result: Dictionary = {}
	if active_item_runtime != null and active_item_runtime.has_method("notify_trampoline_hit"):
		hit_result = active_item_runtime.notify_trampoline_hit(
			int(step_result.get("trampoline_index", -1)),
			ball_pos,
			ball_vel
		)
	scene["ball_pos"] = ball_pos

	var audio: Object = deps.get("audio", null)
	var phase: String = str(hit_result.get("phase", ""))
	if phase == "catch" or phase == "sinking" or phase == "hold":
		scene["ball_vel"] = _get_vector2(hit_result, "ball_vel", ball_vel)
		if phase == "catch" and audio != null and audio.has_method("play_trampoline_catch"):
			audio.play_trampoline_catch()
		return

	# "launch" — and the defensive fallback when the runtime is missing.
	var launch_velocity: Vector2 = _get_vector2(hit_result, "bounce_velocity", Vector2(ball_vel.x, -max(abs(ball_vel.y), 9.0)))
	scene["ball_vel"] = launch_velocity
	# The slingshot launch may exceed the global ball speed cap by up to 30%;
	# raise the cap key consumed by ball_frame_motion_controller so the
	# per-frame clamp does not silently swallow the overspeed. The frames TTL
	# keeps the opened cap alive across the frame boundary (schema + snapshot
	# whitelist) until ball_frame_motion_controller ticks it out.
	scene["trampoline_launch_speed_cap"] = max(
		float(scene.get("trampoline_launch_speed_cap", 0.0)),
		launch_velocity.length()
	)
	scene["trampoline_launch_speed_cap_frames"] = max(
		float(scene.get("trampoline_launch_speed_cap_frames", 0.0)),
		float(hit_result.get("launch_speed_cap_frames", 0.0))
	)
	if audio != null:
		if audio.has_method("play_trampoline_bounce"):
			audio.play_trampoline_bounce(abs(_get_vector2(scene, "ball_vel", Vector2.ZERO).y))
		elif audio.has_method("play_wall_hit"):
			audio.play_wall_hit(abs(ball_vel.y))
	_register_ball_hit_pulse(step_result, scene, deps, "trampoline", 0.66)


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
	var wall_controller = deps.get("wall_bounce_controller", null)
	if wall_controller != null and wall_controller.has_method("register_paddle_hit"):
		wall_controller.register_paddle_hit()
	var paddle_context: Dictionary = context.duplicate()
	paddle_context.merge(scene, true)
	for key in [
		"viper_dual_glitch_clone_hit",
		"viper_dual_glitch_clone_index",
		"viper_dual_glitch_clone_side",
		"blacksmith_thor_shield_hit",
		"blacksmith_thor_shield_rect",
		"blacksmith_thor_shield_gauge_gain",
		"blacksmith_umbrella_open",
		"blacksmith_umbrella_gauge_gain",
	]:
		if step_result.has(key):
			paddle_context[key] = step_result[key]
	var result: Dictionary = controller.bounce(
		float(step_result.get("paddle_x", 0.0)),
		float(step_result.get("paddle_w", context.get("paddle_width", 155.0))),
		bool(step_result.get("is_player", false)),
		paddle_context,
		deps,
		callbacks
	)
	scene.merge(result, true)


func _process_stage2_quake_boss_backstop(scene: Dictionary, context: Dictionary, deps: Dictionary) -> bool:
	var stage_background: Object = deps.get("stage_background", null)
	if stage_background == null or not stage_background.has_method("resolve_quake_boss_backstop"):
		return false
	return bool(stage_background.resolve_quake_boss_backstop(scene, context, deps))


func _apply_chargebag_wall_gauge(scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("apply_chargebag_wall_bounce_gauge"):
		return
	var current_gauge: float = float(scene.get("special_gauge", context.get("special_gauge", 0.0)))
	var wall_context: Dictionary = context.duplicate()
	wall_context.merge(scene, true)
	if not wall_context.has("gauge_max"):
		wall_context["gauge_max"] = float(context.get("gauge_max", context.get("special_gauge_max", 500.0)))
	if not wall_context.has("gauge_charge_per_hit"):
		wall_context["gauge_charge_per_hit"] = float(context.get("gauge_charge_per_hit", 50.0))
	if not wall_context.has("selected_character_type"):
		wall_context["selected_character_type"] = str(context.get("selected_character_type", "smasher"))
	var next_gauge: float = float(mythic_item_runtime.apply_chargebag_wall_bounce_gauge(current_gauge, wall_context, deps))
	if not is_equal_approx(next_gauge, current_gauge):
		scene["special_gauge"] = next_gauge


func _notify_power_smash_wall_bounce(step_result: Dictionary, deps: Dictionary) -> void:
	var power_state: Object = deps.get("power_state", null)
	if power_state == null or not power_state.has_method("notify_wall_bounce"):
		return
	power_state.notify_wall_bounce(str(step_result.get("side", "")))


func _register_ball_hit_pulse(
	step_result: Dictionary,
	scene: Dictionary,
	deps: Dictionary,
	kind: String,
	intensity: float
) -> void:
	var ball_effects: Object = deps.get("ball_effects", null)
	if ball_effects == null or not ball_effects.has_method("register_hit_pulse"):
		return
	ball_effects.register_hit_pulse(
		_get_vector2(step_result, "impact_pos", _get_vector2(scene, "ball_pos", Vector2.ZERO)),
		_get_vector2(scene, "ball_vel", Vector2.ZERO),
		intensity,
		kind
	)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)
