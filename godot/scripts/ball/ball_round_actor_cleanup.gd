extends RefCounted


func reset_round_wait(deps: Dictionary) -> void:
	var round_state = deps.get("round_state", null)
	if round_state != null:
		round_state.reset_round_wait()


func reset_actor_round_state(deps: Dictionary) -> void:
	var ai_state = deps.get("ai_state", null)
	if ai_state != null:
		ai_state.reset()

	var animation_state = deps.get("animation_state", null)
	if animation_state != null:
		animation_state.reset()

	var movement_state = deps.get("movement_state", null)
	if movement_state != null and movement_state.has_method("reset"):
		movement_state.reset()

	var dash_state = deps.get("dash_state", null)
	if dash_state != null:
		dash_state.reset_round()

	var feedback = deps.get("feedback", null)
	if feedback != null:
		var dash_token_max: int = _get_dash_token_max(dash_state)
		feedback.reset_round(dash_token_max)

	var whip_state = deps.get("stage1_dalji_whip_skill_state", null)
	if whip_state != null and whip_state.has_method("reset_round"):
		whip_state.reset_round()


func _get_dash_token_max(dash_state) -> int:
	if dash_state == null:
		return 1
	var dash_snapshot: Dictionary = dash_state.get_snapshot()
	return int(dash_snapshot.get("max_tokens", 1))
