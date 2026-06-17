extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")
const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")

const JUNIOR_POWER_SMASH_LAUNCH_SPEED_MULT := 1.30


func apply(
	ball_pos: Vector2,
	ball_vel: Vector2,
	paddle_w: float,
	power_activated: bool,
	power_state: Object,
	physics: Object,
	context: Dictionary
) -> Vector2:
	if not power_activated or power_state == null:
		return ball_vel
	var updated_vel: Vector2 = power_state.apply_hit_velocity(
		ball_vel,
		ball_pos,
		_get_vector2(context, "player_pos", Vector2.ZERO),
		float(context.get("paddle_width", paddle_w)),
		float(context.get("base_ball_speed", 6.0)),
		physics,
		int(context.get("combo_min_count", 2)),
		_get_power_smash_launch_speed_multiplier(context)
	)
	var ball_size: float = float(context.get("ball_size", 28.6))
	var combo_count: int = int(power_state.get_combo_consumed())
	power_state.spawn_trail(ball_pos, ball_size, combo_count)
	power_state.spawn_initial_burst(ball_pos)
	return updated_vel


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)


func _get_power_smash_launch_speed_multiplier(context: Dictionary) -> float:
	var ai_mode: String = BattleSceneConfig.normalize_league_mode(str(context.get("ai_mode", "champion")))
	return JUNIOR_POWER_SMASH_LAUNCH_SPEED_MULT if ai_mode == "junior" else 1.0
