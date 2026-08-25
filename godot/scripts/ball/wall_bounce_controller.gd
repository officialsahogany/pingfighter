extends RefCounted

const WallBounceState := preload("res://scripts/ball/wall_bounce_state.gd")

var wall_bounce_state = WallBounceState.new()


func reset_round() -> void:
	if wall_bounce_state != null and wall_bounce_state.has_method("reset_round"):
		wall_bounce_state.reset_round()


func register_paddle_hit() -> void:
	if wall_bounce_state != null and wall_bounce_state.has_method("register_paddle_hit"):
		wall_bounce_state.register_paddle_hit()


func process(
	ball_velocity: Vector2,
	impact_boost: float,
	side: String,
	impact_pos: Vector2,
	field_height: float,
	deps: Dictionary
) -> Dictionary:
	var response: Dictionary = {"ball_vel": ball_velocity}
	if wall_bounce_state == null:
		return response

	var bounce_result: Dictionary = wall_bounce_state.resolve(ball_velocity, impact_boost, side)
	var updated_ball_vel: Variant = bounce_result.get("ball_vel", ball_velocity)
	if updated_ball_vel is Vector2:
		response["ball_vel"] = updated_ball_vel
	var dalji_vision_state: Object = deps.get("dalji_vision_chosik_state", null)
	if (
		not bool(bounce_result.get("rematch_requested", false))
		and dalji_vision_state != null
		and dalji_vision_state.has_method("consume_wall_rebound_speed_boost")
	):
		# The normal wall resolver damps first. Linked Tops instead derives its
		# one-shot +30% exit from the pre-wall speed and remembers the effective
		# pre-top speed for the eventual boss-guard restore.
		var linked_top_result: Variant = dalji_vision_state.call(
			"consume_wall_rebound_speed_boost",
			_get_vector2(response, "ball_vel", ball_velocity),
			side,
			ball_velocity.length(),
			impact_boost
		)
		if linked_top_result is Dictionary:
			response.merge(linked_top_result as Dictionary, true)
	if bool(bounce_result.get("rematch_requested", false)):
		response["rematch_requested"] = true

	var impact_speed: float = float(bounce_result.get("impact_speed", 0.0))
	var audio = deps.get("audio", null)
	if audio != null:
		audio.play_wall_hit(impact_speed, impact_pos.x)

	var impact_effects = deps.get("impact_effects", null)
	if impact_effects != null:
		impact_effects.spawn_wall_impact(impact_pos, side, impact_speed)

	var ball_effects = deps.get("ball_effects", null)
	if ball_effects != null and ball_effects.has_method("register_hit_pulse"):
		ball_effects.register_hit_pulse(
			impact_pos,
			_get_vector2(response, "ball_vel", ball_velocity),
			clamp(impact_speed / 35.0, 0.0, 1.0),
			"wall"
		)

	var stage_background = deps.get("stage_background", null)
	if stage_background != null and stage_background.has_method("trigger_tree_shake"):
		stage_background.trigger_tree_shake(
			side,
			impact_pos.y,
			impact_speed,
			field_height
		)

	var feedback = deps.get("feedback", null)
	if feedback != null:
		feedback.max_screen_shake(
			float(bounce_result.get("screen_shake", 0.0)),
			float(bounce_result.get("screen_shake_intensity", 0.0))
		)

	return response


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
