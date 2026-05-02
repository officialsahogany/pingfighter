extends RefCounted


func handle_score_event(scoring_side: String, deps: Dictionary, callbacks: Dictionary) -> void:
	var score_state = deps.get("score_state", null)
	if score_state == null:
		return

	var score_result: Dictionary = score_state.score_for(scoring_side)
	var round_state = deps.get("round_state", null)
	if round_state != null:
		round_state.set_player_serves(bool(score_result.get("next_player_serves", scoring_side == "boss")))

	var scoreboard_state = deps.get("scoreboard_state", null)
	if scoreboard_state != null:
		scoreboard_state.trigger_top_mini_sparkle()

	var reset_ball_callback: Callable = callbacks.get("reset_ball", Callable())
	if reset_ball_callback.is_valid():
		reset_ball_callback.call()

	if scoreboard_state != null:
		scoreboard_state.start(
			int(score_result.get("player_score", 0)),
			int(score_result.get("boss_score", 0)),
			bool(score_result.get("match_finished", false))
		)
	if round_state != null:
		round_state.start_scoreboard_wait()

	var audio = deps.get("audio", null)
	if audio != null:
		audio.play_round_set()


func update_scoreboard(delta: float, deps: Dictionary, callbacks: Dictionary, config: Dictionary) -> void:
	var scoreboard_state = deps.get("scoreboard_state", null)
	if scoreboard_state == null:
		return

	var update_result: int = scoreboard_state.update_scoreboard(delta)
	if update_result == int(config.get("update_reset_game", -1)):
		var reset_game_callback: Callable = callbacks.get("reset_game", Callable())
		if reset_game_callback.is_valid():
			reset_game_callback.call()
	elif update_result == int(config.get("update_start_serve", -1)):
		var round_state = deps.get("round_state", null)
		if round_state != null:
			round_state.prepare_serve_after_scoreboard()


func reset_game(deps: Dictionary, callbacks: Dictionary) -> Dictionary:
	var scoreboard_state = deps.get("scoreboard_state", null)
	if scoreboard_state != null:
		scoreboard_state.reset()

	var score_state = deps.get("score_state", null)
	if score_state != null:
		score_state.reset()

	var round_state = deps.get("round_state", null)
	if round_state != null:
		round_state.reset_game()

	var orb_hud_state = deps.get("orb_hud_state", null)
	if orb_hud_state != null:
		orb_hud_state.reset_gauge(0)

	var active_hud_state = deps.get("active_hud_state", null)
	if active_hud_state != null:
		active_hud_state.reset()

	var skill_state = deps.get("skill_state", null)
	if skill_state != null:
		skill_state.reset()

	var drive_input_state = deps.get("drive_input_state", null)
	if drive_input_state != null:
		drive_input_state.reset_cooldowns()

	var reset_drive_input_callback: Callable = callbacks.get("reset_drive_input", Callable())
	if reset_drive_input_callback.is_valid():
		reset_drive_input_callback.call()

	var dash_state = deps.get("dash_state", null)
	if dash_state != null:
		dash_state.reset_full(1)
		if orb_hud_state != null:
			var dash_snapshot: Dictionary = dash_state.get_snapshot()
			orb_hud_state.reset_dash_tokens(int(dash_snapshot.get("tokens", 0)))

	var reset_ball_callback: Callable = callbacks.get("reset_ball", Callable())
	if reset_ball_callback.is_valid():
		reset_ball_callback.call()

	return {
		"special_gauge": 0.0,
		"drive_text_timer_frames": 0.0,
	}
