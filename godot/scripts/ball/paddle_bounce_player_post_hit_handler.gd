extends RefCounted


func apply(
	ball_pos: Vector2,
	hit_pos: float,
	power_activated: bool,
	drive_activated: bool,
	special_gauge: float,
	context: Dictionary,
	deps: Dictionary,
	event_router: Object
) -> Dictionary:
	var next_ball_pos: Vector2 = _snap_player_hit_ball_pos(ball_pos, context)
	var player_speed: float = float(context.get("player_speed", 0.0))
	var boss_vel: float = float(context.get("boss_vel", 0.0))
	var magnum_state: Object = deps.get("smasher_magnum_grip_state", null)
	var magnum_release_hit: bool = false
	if magnum_state != null and magnum_state.has_method("consume_release_hit_speed_cap"):
		magnum_release_hit = bool(magnum_state.consume_release_hit_speed_cap())
	if magnum_state != null and magnum_state.has_method("deactivate"):
		magnum_state.deactivate()

	var power_state: Object = deps.get("power_state", null)
	if power_activated and power_state != null:
		power_state.lock_freeze_pose(next_ball_pos)
		next_ball_pos = power_state.get_freeze_ball_pos()
		player_speed = 0.0
		boss_vel = 0.0

	var updated_gauge: float = special_gauge
	if event_router != null:
		updated_gauge = event_router.register_player_hit(
			next_ball_pos,
			hit_pos,
			drive_activated,
			power_activated,
			special_gauge,
			context,
			deps
		)
	var stage_background: Object = deps.get("stage_background", null)
	if (
		int(context.get("current_stage", 1)) == 2
		and stage_background != null
		and stage_background.has_method("force_end_quake_on_player_hit")
	):
		stage_background.force_end_quake_on_player_hit(deps)
	var result := {
		"ball_pos": next_ball_pos,
		"special_gauge": updated_gauge,
		"player_speed": player_speed,
		"boss_vel": boss_vel,
	}
	if magnum_release_hit:
		result["magnum_grip_release_hit"] = true
	return result


func _snap_player_hit_ball_pos(ball_pos: Vector2, context: Dictionary) -> Vector2:
	# Blacksmith Thor Shield: the shield hitbox sits lifted above the player paddle
	# (it tracks the raised, stretched shield art). Seat the ball just above the
	# shield's TOP surface where it was drawn, so it visibly bounces off the shield.
	# Without this the ball snapped down to the paddle baseline, which read as the
	# ball teleporting to the player and re-launching from there.
	if bool(context.get("blacksmith_thor_shield_hit", false)):
		var shield_rect_value: Variant = context.get("blacksmith_thor_shield_rect", null)
		if shield_rect_value is Rect2 and (shield_rect_value as Rect2).size.y > 0.0:
			var shield_rect: Rect2 = shield_rect_value
			ball_pos.y = shield_rect.position.y - float(context.get("ball_size", 0.0))
			return ball_pos
	ball_pos.y = float(context.get("player_y", ball_pos.y)) - float(context.get("ball_size", 0.0))
	return ball_pos
