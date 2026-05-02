extends RefCounted


func handle_dash_input(
	down_pressed: bool,
	direction: float,
	player_speed: float,
	deps: Dictionary
) -> Dictionary:
	var next_speed: float = player_speed
	var handled_by_dash: bool = false
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state != null:
		dash_state.update_key_release(down_pressed)

	if dash_state != null and dash_state.is_active():
		if dash_state.can_chain_dash(down_pressed, direction):
			if _start_dash(direction, false, deps):
				next_speed = 0.0
		handled_by_dash = true
	elif dash_state != null and dash_state.is_recovering():
		next_speed = 0.0
		handled_by_dash = true
	elif dash_state != null and dash_state.can_start_from_input(down_pressed, direction):
		if dash_state.has_full_dash_token():
			if _start_dash(direction, false, deps):
				next_speed = 0.0
		else:
			if _start_dash(direction, true, deps):
				next_speed = 0.0
		handled_by_dash = true

	return {
		"player_speed": next_speed,
		"handled_by_dash": handled_by_dash,
	}


func update_dash_motion(
	delta: float,
	player_pos: Vector2,
	player_speed: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state == null:
		return {
			"player_pos": player_pos,
			"player_speed": player_speed,
		}

	var result: Dictionary = dash_state.update(
		delta,
		player_pos,
		float(config.get("play_left", 0.0)),
		float(config.get("play_right", 0.0)),
		float(config.get("paddle_width", 0.0))
	)
	var next_pos: Vector2 = player_pos
	var updated_pos: Variant = result.get("player_pos", player_pos)
	if updated_pos is Vector2:
		next_pos = updated_pos
	var next_speed: float = player_speed
	if bool(result.get("player_speed_zero", false)):
		next_speed = 0.0
	if bool(result.get("recharge_completed", false)):
		var feedback: Object = deps.get("feedback", null)
		if feedback != null:
			feedback.trigger_dash_flash()

	return {
		"player_pos": next_pos,
		"player_speed": next_speed,
	}


func _start_dash(direction: float, is_half: bool, deps: Dictionary) -> bool:
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state == null or not dash_state.start(direction, is_half):
		return false

	var combo_state: Object = deps.get("combo_state", null)
	if combo_state != null:
		combo_state.reset_combo()
		combo_state.clear_effects()

	var orb_hud_state: Object = deps.get("orb_hud_state", null)
	if orb_hud_state != null:
		orb_hud_state.trigger_dash_token_spin(Time.get_ticks_msec())

	var audio: Object = deps.get("audio", null)
	if audio != null:
		audio.play_dash_start(is_half)

	var feedback: Object = deps.get("feedback", null)
	if feedback != null:
		feedback.set_screen_shake(0.12, 4.0)
	return true
