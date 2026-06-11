extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")


func apply(
	post_hit_handler: Object,
	frame_state: Object,
	is_player: bool,
	ball_pos: Vector2,
	ball_vel: Vector2,
	hit_pos: float,
	paddle_w: float,
	power_activated: bool,
	was_power_smashing: bool,
	drive_activated: bool,
	frame: Dictionary,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	if post_hit_handler == null:
		return _build_result(ball_pos, ball_vel, context)

	var post_hit_result: Dictionary = post_hit_handler.apply(
		is_player,
		ball_pos,
		ball_vel,
		hit_pos,
		paddle_w,
		power_activated,
		was_power_smashing,
		drive_activated,
		float(frame["ball_spin_strength"]),
		float(frame["drive_speed_increase"]),
		bool(frame["drive_ball_active"]),
		bool(frame["drive_hit_boss"]),
		float(frame["special_gauge"]),
		context,
		deps
	)
	if frame_state != null:
		frame_state.apply_post_hit_result(frame, post_hit_result)

	var next_ball_pos: Vector2 = _get_vector2(post_hit_result, "ball_pos", ball_pos)
	var next_ball_vel: Vector2 = _get_vector2(post_hit_result, "ball_vel", ball_vel)
	var player_speed: float = float(post_hit_result.get("player_speed", context.get("player_speed", 0.0)))
	var boss_vel: float = float(post_hit_result.get("boss_vel", context.get("boss_vel", 0.0)))
	var result := {
		"ball_pos": next_ball_pos,
		"ball_vel": next_ball_vel,
		"player_speed": player_speed,
		"boss_vel": boss_vel,
	}
	if post_hit_result.has("runtime_perk_gold"):
		result["runtime_perk_gold"] = int(post_hit_result.get("runtime_perk_gold", 0))
	for key in [
		"player_collision_cooldown",
		"boss_collision_cooldown",
		"smasher_wheel_speed_cap",
		"smasher_wheel_hit",
		"rainbow_fur_glove_activated",
		"rainbow_fur_glove_cooldown_reduction_pct",
		"shrapnel_armor_activated",
		"shrapnel_armor_shard_count",
		"shrapnel_armor_gauge_cost",
		"blacksmith_thor_shield_hit",
		"blacksmith_thor_shield_hit_pos",
		"blacksmith_umbrella_open",
		"blacksmith_umbrella_anim_timer",
		"blacksmith_umbrella_retracting",
		"blacksmith_umbrella_anim_direction",
		"blacksmith_umbrella_open_ratio",
		"blacksmith_thor_shield_open_ratio",
		"blacksmith_umbrella_raise_amount",
		"blacksmith_umbrella_shield_open_amount",
		"blacksmith_umbrella_visual_state",
		"blacksmith_umbrella_folded",
		"blacksmith_umbrella_deployed",
		"blacksmith_umbrella_swing_active",
		"blacksmith_umbrella_swing_direction",
		"blacksmith_umbrella_swing_timer",
		"blacksmith_umbrella_gauge",
		"blacksmith_umbrella_gauge_max",
		"blacksmith_umbrella_gauge_gain",
		"blacksmith_umbrella_damage_flash_timer",
		"blacksmith_umbrella_hit_pulse_timer",
		"suppress_paddle_hit_knockback",
		"paddle_hit_pulse_kind",
		"paddle_hit_pulse_intensity",
	]:
		if post_hit_result.has(key):
			result[key] = post_hit_result[key]
	if post_hit_result.has("viper_knockback_overlay_active"):
		result["viper_knockback_overlay_active"] = bool(post_hit_result.get("viper_knockback_overlay_active", false))
	if post_hit_result.has("speed_limit_disabled"):
		result["speed_limit_disabled"] = bool(post_hit_result.get("speed_limit_disabled", false))
	for key in [
		"commando_bowling_trap_guard_consumed",
		"commando_bowling_trap_guarded",
		"commando_bowling_trap_guard_hit",
		"commando_bowling_trap_guard_armed",
		"commando_bowling_trap_guard_source",
		"commando_bowling_trap_guard_status_source",
		"commando_bowling_trap_guard_knockback_power",
		"commando_bowling_trap_guard_knockback_vel",
		"commando_bowling_trap_guard_stun_frames",
		"commando_bowling_trap_guard_restore_speed",
		"commando_bowling_trap_guard_consumed_restore_speed",
		"commando_suicide_drone_ball_boost_active",
		"commando_suicide_drone_ball_restore_speed",
		"commando_suicide_drone_ball_boosted_speed",
		"commando_suicide_drone_ball_boost_consumed",
		"commando_suicide_drone_ball_restored_speed",
		"boss_status_immune",
	]:
		if post_hit_result.has(key):
			result[key] = post_hit_result[key]
	return result


func _build_result(ball_pos: Vector2, ball_vel: Vector2, context: Dictionary) -> Dictionary:
	return {
		"ball_pos": ball_pos,
		"ball_vel": ball_vel,
		"player_speed": float(context.get("player_speed", 0.0)),
		"boss_vel": float(context.get("boss_vel", 0.0)),
	}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)
