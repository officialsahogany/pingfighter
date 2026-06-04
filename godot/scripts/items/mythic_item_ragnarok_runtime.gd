extends RefCounted

const ITEM_RAGNAROK_HAMMER := "ragnarok_hammer"


func update_runtime(
	runtime: Object,
	owner: Object,
	registry: Object,
	delta: float,
	fps_scale: float,
	constants: Dictionary
) -> void:
	var had_stun: bool = runtime.ragnarok_boss_stun_timer_frames > 0.0
	if runtime.ragnarok_boss_stun_timer_frames > 0.0:
		runtime.ragnarok_boss_stun_timer_frames = max(
			0.0,
			runtime.ragnarok_boss_stun_timer_frames - fps_scale
		)
	if runtime.ragnarok_boss_knockback_timer_frames > 0.0:
		runtime.ragnarok_boss_knockback_timer_frames = max(
			0.0,
			runtime.ragnarok_boss_knockback_timer_frames - fps_scale
		)
		runtime.ragnarok_boss_knockback_vel *= pow(
			float(constants.get("boss_knockback_decay", 0.86)),
			fps_scale
		)
		if (
			runtime.ragnarok_boss_knockback_timer_frames <= 0.0
			or abs(runtime.ragnarok_boss_knockback_vel) <= 0.3
		):
			runtime.ragnarok_boss_knockback_timer_frames = 0.0
			runtime.ragnarok_boss_knockback_vel = 0.0
	elif abs(runtime.ragnarok_boss_knockback_vel) > 0.0:
		runtime.ragnarok_boss_knockback_vel = 0.0
	if runtime.ragnarok_boss_stun_timer_frames > 0.0:
		update_stun_target(runtime, owner)
	else:
		runtime.ragnarok_boss_electric_drift_vel = 0.0
	if runtime.stage_immunity.is_stage2_speed_defense_boss_immune(runtime, registry):
		clear_boss_disable_state(runtime, registry)
	update_sparks(runtime, delta)
	if had_stun and runtime.ragnarok_boss_stun_timer_frames <= 0.0:
		runtime.audio_router.stop_ragnarok_shock_audio(runtime, registry)
	elif runtime.ragnarok_boss_stun_timer_frames > 0.0:
		runtime.audio_router.play_ragnarok_shock_audio(runtime, registry)


func try_apply_player_hit(
	runtime: Object,
	ball_vel: Vector2,
	special_gauge: float,
	deps: Dictionary,
	constants: Dictionary
) -> Dictionary:
	if not runtime.is_equipped(ITEM_RAGNAROK_HAMMER):
		return {}
	if runtime.ragnarok_stun_ball_active or runtime.ragnarok_stun_attempted_this_rally:
		return {}
	runtime.ragnarok_stun_attempted_this_rally = true

	var gauge_cost: float = get_gauge_cost(runtime)
	if special_gauge < gauge_cost:
		return {"special_gauge": special_gauge}
	var trigger_chance: float = get_trigger_chance(runtime) / 100.0
	if randf() >= trigger_chance:
		return {"special_gauge": special_gauge}

	var next_ball_vel: Vector2 = ball_vel
	var original_speed: float = max(0.0, next_ball_vel.length())
	if original_speed > 0.01:
		next_ball_vel *= 1.0 + get_speed_boost(runtime) / 100.0
	runtime.ragnarok_stun_ball_active = true
	runtime.ragnarok_original_speed = original_speed
	runtime.ragnarok_first_shot_speed = max(original_speed, next_ball_vel.length())
	runtime.ragnarok_ball_started_msec = Time.get_ticks_msec()
	runtime.audio_router.play_ragnarok_shot_audio(runtime, runtime._get_dict(deps).get("registry", null))
	runtime.audio_router.apply_ragnarok_feedback(
		runtime,
		deps,
		float(constants.get("charge_shake_amount", 0.08)),
		float(constants.get("charge_shake_intensity", 2.4))
	)
	return {
		"ball_vel": next_ball_vel,
		"special_gauge": max(0.0, special_gauge - gauge_cost),
		"activated": true,
		"speed_limit_disabled": true,
		"ragnarok_hammer_speed_limit_disabled": true,
	}


func apply_boss_hit(
	runtime: Object,
	ball_vel: Vector2,
	context: Dictionary,
	deps: Dictionary,
	constants: Dictionary
) -> Dictionary:
	if not runtime.is_equipped(ITEM_RAGNAROK_HAMMER):
		clear_rally_state(runtime)
		return {}
	if not runtime.ragnarok_stun_ball_active:
		clear_rally_state(runtime)
		return {}

	runtime.ragnarok_stun_ball_active = false
	runtime.ragnarok_stun_attempted_this_rally = false
	var next_ball_vel: Vector2 = soften_counter_ball(runtime, ball_vel, context, constants)
	if runtime.stage_immunity.is_stage2_speed_defense_context_immune(runtime, context, deps):
		return {
			"ball_vel": next_ball_vel,
			"applied": false,
			"boss_status_immune": true,
			"speed_limit_disabled": false,
			"ragnarok_hammer_speed_limit_disabled": false,
		}
	var boss_pos: Vector2 = runtime._get_vector2(context.get("boss_pos", Vector2(330.0, 25.0)))
	var boss_size: Vector2 = runtime._get_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)))
	if boss_size == Vector2.ZERO:
		boss_size = Vector2(100.0, 40.0)
	runtime.ragnarok_stun_target_size = boss_size
	var boss_center := Vector2(boss_pos.x + boss_size.x * 0.5, boss_pos.y + boss_size.y * 0.5)
	var field_center_x: float = float(context.get("width", 760.0)) * 0.5
	var direction: float = 1.0 if boss_center.x < field_center_x else -1.0
	var previous_boss_vel: float = float(context.get("boss_vel", 0.0))
	var drift_direction: float = sign(previous_boss_vel)
	if is_zero_approx(drift_direction):
		drift_direction = direction
	runtime.ragnarok_boss_electric_drift_vel = (
		drift_direction * float(constants.get("electric_stun_drift_speed", 0.36))
	)
	var knockback_power: float = compute_knockback_power(
		max(ball_vel.length(), next_ball_vel.length()),
		constants
	)
	runtime.ragnarok_boss_knockback_vel = (
		direction * knockback_power * float(constants.get("boss_knockback_multiplier", 2.1))
	)
	runtime.ragnarok_boss_knockback_timer_frames = float(constants.get("boss_knockback_frames", 36.0))
	runtime.ragnarok_boss_stun_timer_frames = max(
		runtime.ragnarok_boss_stun_timer_frames,
		get_stun_duration(runtime) * 60.0
	)
	runtime.ragnarok_impact_center = boss_center
	runtime.ragnarok_impact_started_msec = Time.get_ticks_msec()
	build_sparks(runtime, constants)
	runtime.audio_router.play_ragnarok_boom_audio(runtime, runtime._get_dict(deps).get("registry", null))
	if runtime.ragnarok_boss_stun_timer_frames > 0.0:
		runtime.audio_router.play_ragnarok_shock_audio(runtime, runtime._get_dict(deps).get("registry", null))
	runtime.audio_router.apply_ragnarok_feedback(
		runtime,
		deps,
		float(constants.get("impact_shake_amount", 1.38)),
		float(constants.get("impact_shake_intensity", 22.0))
	)
	return {
		"ball_vel": next_ball_vel,
		"applied": true,
		"speed_limit_disabled": false,
		"ragnarok_hammer_speed_limit_disabled": false,
	}


func get_trigger_chance(runtime: Object) -> float:
	return clamp(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_RAGNAROK_HAMMER, "trigger_chance"), 0.0, 100.0)


func get_stun_duration(runtime: Object) -> float:
	return clamp(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_RAGNAROK_HAMMER, "stun_duration"), 0.8, 1.2)


func get_speed_boost(runtime: Object) -> float:
	return clamp(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_RAGNAROK_HAMMER, "speed_boost"), 0.0, 100.0)


func get_gauge_cost(runtime: Object) -> float:
	return clamp(runtime.roll_query.get_equipped_roll_value(runtime, ITEM_RAGNAROK_HAMMER, "gauge_cost"), 0.0, 100.0)


func get_ball_elapsed(runtime: Object) -> float:
	return float(Time.get_ticks_msec() - runtime.ragnarok_ball_started_msec) / 1000.0


func get_impact_elapsed(runtime: Object) -> float:
	return float(Time.get_ticks_msec() - runtime.ragnarok_impact_started_msec) / 1000.0


func clear_runtime(runtime: Object, registry: Object) -> void:
	runtime.ragnarok_stun_ball_active = false
	runtime.ragnarok_stun_attempted_this_rally = false
	runtime.ragnarok_original_speed = 0.0
	runtime.ragnarok_first_shot_speed = 0.0
	runtime.ragnarok_ball_started_msec = -1000000
	runtime.ragnarok_boss_stun_timer_frames = 0.0
	runtime.ragnarok_boss_knockback_timer_frames = 0.0
	runtime.ragnarok_boss_knockback_vel = 0.0
	runtime.ragnarok_boss_electric_drift_vel = 0.0
	runtime.ragnarok_impact_started_msec = -1000000
	runtime.ragnarok_impact_center = Vector2.ZERO
	runtime.ragnarok_stun_target_size = Vector2(100.0, 40.0)
	runtime.ragnarok_sparks.clear()
	runtime.audio_router.stop_ragnarok_shock_audio(runtime, registry)


func clear_boss_disable_state(runtime: Object, registry: Object = null) -> void:
	runtime.ragnarok_boss_stun_timer_frames = 0.0
	runtime.ragnarok_boss_knockback_timer_frames = 0.0
	runtime.ragnarok_boss_knockback_vel = 0.0
	runtime.ragnarok_boss_electric_drift_vel = 0.0
	runtime.audio_router.stop_ragnarok_shock_audio(runtime, registry)


func clear_rally_state(runtime: Object) -> void:
	runtime.ragnarok_stun_ball_active = false
	runtime.ragnarok_stun_attempted_this_rally = false
	runtime.ragnarok_original_speed = 0.0
	runtime.ragnarok_first_shot_speed = 0.0
	runtime.ragnarok_ball_started_msec = -1000000


func soften_counter_ball(
	runtime: Object,
	ball_vel: Vector2,
	context: Dictionary,
	constants: Dictionary
) -> Vector2:
	var speed: float = ball_vel.length()
	if speed <= 0.01:
		return ball_vel
	var reference_speed: float = max(runtime.ragnarok_original_speed, runtime.ragnarok_first_shot_speed)
	if reference_speed <= 0.01:
		reference_speed = speed
	var retention: float = clampf(float(constants.get("counter_speed_retention", 0.58)), 0.05, 1.0)
	var min_speed: float = max(0.0, float(constants.get("counter_min_speed", 7.0)))
	var max_speed: float = max(min_speed, float(constants.get("counter_max_speed", 20.0)))
	var target_speed: float = clampf(reference_speed * retention, min_speed, max_speed)
	target_speed = minf(speed, target_speed)
	var next_ball_vel: Vector2 = ball_vel.normalized() * target_speed
	next_ball_vel = shape_counter_ball_toward_player(runtime, next_ball_vel, context, constants)
	clear_rally_state(runtime)
	return next_ball_vel


func shape_counter_ball_toward_player(
	runtime: Object,
	ball_vel: Vector2,
	context: Dictionary,
	constants: Dictionary
) -> Vector2:
	var speed: float = ball_vel.length()
	if speed <= 0.01:
		return ball_vel
	var max_x_ratio: float = clampf(
		float(constants.get("counter_max_horizontal_ratio", 0.42)),
		0.0,
		0.95
	)
	var player_direction: Vector2 = get_counter_player_direction(runtime, context, max_x_ratio)
	if player_direction != Vector2.ZERO:
		return player_direction * speed
	var min_y_ratio: float = clampf(
		float(constants.get("counter_min_downward_ratio", 0.82)),
		0.05,
		1.0
	)
	var shaped_direction := Vector2(
		clampf(ball_vel.x / speed, -max_x_ratio, max_x_ratio),
		maxf(abs(ball_vel.y) / speed, min_y_ratio)
	)
	if shaped_direction.length() <= 0.01:
		shaped_direction = Vector2.DOWN
	return shaped_direction.normalized() * speed


func get_counter_player_direction(runtime: Object, context: Dictionary, max_x_ratio: float) -> Vector2:
	if not context.has("player_pos"):
		return Vector2.ZERO
	var player_pos: Vector2 = runtime._get_vector2(context.get("player_pos", Vector2.ZERO))
	var player_size: Vector2 = runtime._get_vector2(
		context.get(
			"player_paddle_size",
			Vector2(
				float(context.get("paddle_width", 155.0)),
				float(context.get("paddle_height", 50.0))
			)
		)
	)
	if player_size == Vector2.ZERO:
		player_size = Vector2(
			float(context.get("paddle_width", 155.0)),
			float(context.get("paddle_height", 50.0))
		)
	if player_size.x <= 0.0 or player_size.y <= 0.0:
		return Vector2.ZERO
	var source_pos: Vector2 = runtime._get_vector2(context.get("ball_pos", Vector2.ZERO))
	if source_pos == Vector2.ZERO:
		var boss_pos: Vector2 = runtime._get_vector2(context.get("boss_pos", Vector2.ZERO))
		var boss_size: Vector2 = runtime._get_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)))
		if boss_size == Vector2.ZERO:
			boss_size = Vector2(
				float(context.get("boss_paddle_width", 100.0)),
				float(context.get("boss_hitbox_height", 40.0))
			)
		source_pos = boss_pos + boss_size * 0.5
	var player_center: Vector2 = player_pos + player_size * 0.5
	var vertical_distance: float = maxf(1.0, player_center.y - source_pos.y)
	if vertical_distance <= 1.0:
		return Vector2.ZERO
	var x_ratio: float = clampf((player_center.x - source_pos.x) / vertical_distance, -max_x_ratio, max_x_ratio)
	return Vector2(x_ratio, 1.0).normalized()


func compute_knockback_power(ball_speed: float, constants: Dictionary) -> float:
	var base_power: float = (
		float(constants.get("base_knockback_power", 18.326))
		+ max(0.0, ball_speed) * float(constants.get("speed_weight", 0.0748))
	)
	base_power *= 1.0 + randf_range(0.02, 0.06)
	return clamp(base_power, 0.0, float(constants.get("max_knockback_power", 25.823)))


func update_stun_target(runtime: Object, owner: Object) -> void:
	var fallback_pos: Vector2 = runtime.ragnarok_impact_center - runtime.ragnarok_stun_target_size * 0.5
	var owner_size: Vector2 = runtime._get_vector2(
		runtime._safe_owner_get(owner, "boss_paddle_size", runtime.ragnarok_stun_target_size)
	)
	if owner_size != Vector2.ZERO:
		runtime.ragnarok_stun_target_size = owner_size
	var boss_pos: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "boss_pos", fallback_pos))
	runtime.ragnarok_impact_center = boss_pos + runtime.ragnarok_stun_target_size * 0.5


func build_sparks(runtime: Object, constants: Dictionary) -> void:
	runtime.ragnarok_sparks.clear()
	for _i in range(int(constants.get("spark_count", 12))):
		var life: float = randf_range(0.26, 0.78)
		runtime.ragnarok_sparks.append({
			"angle": randf_range(0.0, TAU),
			"radius": randf_range(18.0, 48.0),
			"speed": randf_range(58.0, 188.0),
			"life": life,
			"max_life": life,
			"width": randf_range(1.0, 2.7),
			"color": Color(130.0 / 255.0, 210.0 / 255.0, 1.0),
		})


func update_sparks(runtime: Object, delta: float) -> void:
	if runtime.ragnarok_sparks.is_empty():
		return
	var write_index := 0
	for read_index in range(runtime.ragnarok_sparks.size()):
		var spark: Dictionary = runtime._get_dict(runtime.ragnarok_sparks[read_index])
		var remaining: float = float(spark.get("life", 0.0)) - delta
		if remaining <= 0.0:
			continue
		spark["life"] = remaining
		spark["radius"] = float(spark.get("radius", 0.0)) + float(spark.get("speed", 0.0)) * delta
		runtime.ragnarok_sparks[write_index] = spark
		write_index += 1
	if write_index < runtime.ragnarok_sparks.size():
		runtime.ragnarok_sparks.resize(write_index)
