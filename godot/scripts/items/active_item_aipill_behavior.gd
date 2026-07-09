extends RefCounted

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const AIPILL_GUARD_GAUGE_DRAIN := 90.0
const AIPILL_SPEED_BOOST := 4.0
const AIPILL_BALL_HIT_SPEED_BOOST := 1.25


func apply_player_control(active: bool, player_pos: Vector2, config: Dictionary, delta: float) -> Dictionary:
	if not active:
		return {"handled": false}

	var fps_scale: float = max(0.001, delta * 60.0)
	var paddle_width: float = max(1.0, float(config.get("paddle_width", PLAYER_BASE_PADDLE_WIDTH)))
	var play_left: float = float(config.get("play_left", 0.0))
	var play_right: float = float(config.get("play_right", FIELD_WIDTH))
	var ball_pos: Vector2 = _get_vector2(config, "ball_pos", Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5))
	var target_x: float = clamp(ball_pos.x - paddle_width * 0.5, play_left, max(play_left, play_right - paddle_width))
	var max_speed: float = max(
		1.0,
		max(float(config.get("paddle_speed", 6.0)), float(config.get("paddle_max_speed", 6.0))) * AIPILL_SPEED_BOOST
	)
	var next_x: float = move_toward(player_pos.x, target_x, max_speed * fps_scale)
	return {
		"handled": true,
		"player_pos": Vector2(next_x, player_pos.y),
		"player_speed": (next_x - player_pos.x) / fps_scale,
	}


func build_guard_drain_result(
	active: bool,
	special_gauge: float,
	context: Dictionary,
	gauge_reduction: float = 0.0
) -> Dictionary:
	if not active:
		return {
			"special_gauge": special_gauge,
			"clear_aipill": false,
			"flash": false,
			"feedback": false,
		}

	var character_type: String = str(context.get("selected_character_type", "smasher"))
	if character_type == "optimus":
		return {
			"special_gauge": max(0.0, special_gauge),
			"clear_aipill": special_gauge <= 0.0,
			"flash": false,
			"feedback": false,
		}

	var effective_drain: float = max(0.0, AIPILL_GUARD_GAUGE_DRAIN - max(0.0, gauge_reduction))
	var updated_gauge: float = max(0.0, special_gauge - effective_drain)
	return {
		"special_gauge": updated_gauge,
		"clear_aipill": updated_gauge <= 0.0,
		"flash": true,
		"feedback": true,
	}


func build_ball_hit_speed_boost_result(active: bool, ball_vel: Vector2) -> Dictionary:
	if not active or ball_vel.length_squared() <= 0.0:
		return {"boosted": false, "ball_vel": ball_vel}
	return {"boosted": true, "ball_vel": ball_vel * AIPILL_BALL_HIT_SPEED_BOOST}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
