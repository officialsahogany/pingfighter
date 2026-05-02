extends RefCounted

const WallBounceState := preload("res://scripts/ball/wall_bounce_state.gd")

var wall_bounce_state = WallBounceState.new()


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

	var impact_speed: float = float(bounce_result.get("impact_speed", 0.0))
	var audio = deps.get("audio", null)
	if audio != null:
		audio.play_wall_hit(impact_speed)

	var impact_effects = deps.get("impact_effects", null)
	if impact_effects != null:
		impact_effects.spawn_wall_impact(impact_pos, side, impact_speed)

	var stage_background = deps.get("stage_background", null)
	if stage_background != null:
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
