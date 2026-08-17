extends RefCounted

const Stage4PonkMagneticProjectileState := preload("res://scripts/stages/stage4/stage4_ponk_magnetic_projectile_state.gd")
const Stage4PonkMeditationState := preload("res://scripts/stages/stage4/stage4_ponk_meditation_state.gd")

const STAGE_ID := 4
const BALL_BASE_SPEED_FALLBACK := 7.65

# Coordinates Ponk's order-sensitive ball handoffs and magnetic-projectile
# contact side effects. Mutable skill state remains in the focused state owners;
# this object owns only cross-owner sequencing, scene annotations, and runtime
# context/dependency policy.


func apply_ball_motion(
	scene: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	fps_scale: float,
	meditation_state: Object,
	magnetic_field_state: Object
) -> bool:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		return false
	if bool(meditation_state.get("meditation_active")):
		var controlled_pos: Vector2 = meditation_state.get_controlled_ball_pos(get_boss_center(context))
		scene["ball_pos"] = controlled_pos
		scene["ball_vel"] = Vector2.ZERO
		scene["skip_ball_motion_step"] = false
		scene["stage4_meditation_ball_control"] = true
		return true

	var handled := false
	var meditation_release: Dictionary = meditation_state.consume_release()
	if not meditation_release.is_empty():
		var release_velocity: Vector2 = _as_vector2(
			meditation_release.get("velocity", Vector2.ZERO),
			Vector2.ZERO
		)
		scene["ball_vel"] = release_velocity
		scene["stage4_meditation_release_speed_cap"] = Stage4PonkMeditationState.RELEASE_MAX_BALL_SPEED
		scene["ball_spin_strength"] = 0.30
		scene["ball_spin_direction"] = 1 if release_velocity.x >= 0.0 else -1
		scene["skip_ball_motion_step"] = false
		scene["stage4_meditation_ball_control"] = false
		scene["stage4_meditation_released_ball"] = true
		handled = true

	if bool(magnetic_field_state.get("magnetic_release_pending")):
		var release_vel: Vector2 = _get_vector2(
			scene,
			"ball_vel",
			_get_vector2(context, "ball_vel", Vector2.ZERO)
		)
		var base_speed := 0.0
		if release_vel.length() > 0.001:
			base_speed = get_base_ball_speed(context, deps)
		var magnetic_release: Dictionary = magnetic_field_state.consume_release(
			release_vel,
			base_speed
		)
		if bool(magnetic_release.get("velocity_changed", false)):
			scene["ball_vel"] = _as_vector2(
				magnetic_release.get("velocity", release_vel),
				release_vel
			)
		scene["stage4_magnetic_released_ball"] = true
		handled = true

	var ball_pos: Vector2 = _get_vector2(
		scene,
		"ball_pos",
		_get_vector2(context, "ball_pos", Vector2.ZERO)
	)
	var ball_vel: Vector2 = _get_vector2(
		scene,
		"ball_vel",
		_get_vector2(context, "ball_vel", Vector2.ZERO)
	)
	var boss_center: Vector2 = get_boss_center(context)
	var curve_result: Dictionary = magnetic_field_state.curve_ball(
		ball_pos,
		ball_vel,
		boss_center,
		get_player_center(context),
		fps_scale,
		is_timing_frozen(context)
	)
	if curve_result.is_empty():
		return handled
	var next_vel: Vector2 = magnetic_field_state.apply_speed_cap(
		_as_vector2(curve_result.get("velocity", ball_vel), ball_vel),
		get_base_ball_speed(context, deps)
	)
	scene["ball_vel"] = next_vel
	scene["stage4_magnetic_ball_curved"] = true
	scene["stage4_magnetic_curve_angle"] = float(curve_result.get(
		"angle",
		magnetic_field_state.get("magnet_curve_angle_degrees")
	))
	return true


func resolve_ball_collision(
	scene: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	magnetic_projectile_state: Object
) -> bool:
	if (
		not bool(magnetic_projectile_state.get("active"))
		or int(context.get("current_stage", STAGE_ID)) != STAGE_ID
	):
		return false
	if not magnetic_projectile_state.overlaps_player(get_player_rect(context)):
		return false

	if is_player_status_immune(deps):
		scene["stage4_magnetic_projectile_blocked"] = true
		magnetic_projectile_state.finish_visual()
		stop_magnetic_audio(deps)
		return true

	var status_state: Object = deps.get("status_effect_state", null)
	if status_state != null and status_state.has_method("apply_status"):
		status_state.apply_status(
			"player",
			"slow",
			Stage4PonkMagneticProjectileState.PROJECTILE_SLOW_FRAMES,
			{
				"multiplier": Stage4PonkMagneticProjectileState.PROJECTILE_SLOW_MULTIPLIER,
				"cleansable": true,
				"visual": "stage4_magnetic_projectile",
			},
			"stage4_magnetic_projectile"
		)
	var y_speed_multiplier: float = magnetic_projectile_state.apply_player_contact()
	scene["stage4_magnetic_projectile_player_hit"] = true
	scene["stage4_magnetic_projectile_slow_multiplier"] = Stage4PonkMagneticProjectileState.PROJECTILE_SLOW_MULTIPLIER
	scene["stage4_magnetic_projectile_y_speed_multiplier"] = y_speed_multiplier
	scene["stage4_magnetic_projectile_hit_count"] = int(
		scene.get("stage4_magnetic_projectile_hit_count", 0)
	) + 1
	return true


func get_base_ball_speed(context: Dictionary, deps: Dictionary = {}) -> float:
	var physics: Object = deps.get("ball_physics", null)
	if physics != null and physics.has_method("get_minimum_rally_speed"):
		return maxf(1.0, float(physics.get_minimum_rally_speed()))
	if physics != null and physics.get("BALL_BASE_SPEED") != null:
		return maxf(1.0, float(physics.get("BALL_BASE_SPEED")))
	return maxf(1.0, float(context.get("ball_base_speed", BALL_BASE_SPEED_FALLBACK)))


func get_boss_center(context: Dictionary) -> Vector2:
	var boss_pos: Vector2 = _get_vector2(context, "boss_pos", Vector2(330.0, 55.0))
	var boss_size: Vector2 = _get_vector2(context, "boss_paddle_size", Vector2.ZERO)
	if boss_size == Vector2.ZERO:
		boss_size = Vector2(
			float(context.get("boss_paddle_width", 100.0)),
			float(context.get("boss_hitbox_height", 40.0))
		)
	return boss_pos + boss_size * 0.5


func get_player_center(context: Dictionary) -> Vector2:
	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2(302.5, 690.0))
	var player_size: Vector2 = _get_vector2(
		context,
		"player_paddle_size",
		Vector2(float(context.get("paddle_width", 155.0)), float(context.get("paddle_height", 50.0)))
	)
	return player_pos + player_size * 0.5


func get_player_rect(context: Dictionary) -> Rect2:
	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(
		context,
		"player_paddle_size",
		Vector2(float(context.get("paddle_width", 155.0)), float(context.get("paddle_height", 50.0)))
	)
	return Rect2(player_pos, player_size)


func is_timing_frozen(context: Dictionary) -> bool:
	return (
		bool(context.get("stopwatch_freeze_active", false))
		or bool(context.get("perk_resume_freeze_active", false))
	)


func is_player_status_immune(deps: Dictionary) -> bool:
	var cleanse_state: Object = deps.get("smasher_cleanse_state", null)
	return (
		cleanse_state != null
		and cleanse_state.has_method("is_immune")
		and bool(cleanse_state.is_immune())
	)


func stop_magnetic_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("stop_stage4_magnetic_loop"):
		audio.stop_stage4_magnetic_loop()


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return _as_vector2(source.get(key, fallback), fallback)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	return fallback
