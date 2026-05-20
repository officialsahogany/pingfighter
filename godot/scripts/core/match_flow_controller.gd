extends RefCounted


func handle_score_event(scoring_side: String, deps: Dictionary, callbacks: Dictionary) -> void:
	var score_state = deps.get("score_state", null)
	if score_state == null:
		return

	var score_result: Dictionary = score_state.score_for(scoring_side)
	_queue_adversity_armor_after_loss(scoring_side, score_result, deps)
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
		if audio.has_method("stop_dash_delay"):
			audio.stop_dash_delay()
		audio.play_round_set()


func _queue_adversity_armor_after_loss(scoring_side: String, score_result: Dictionary, deps: Dictionary) -> void:
	if scoring_side != "boss":
		return
	if bool(score_result.get("match_finished", false)):
		return
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("try_queue_adversity_armor_after_loss"):
		return
	mythic_item_runtime.try_queue_adversity_armor_after_loss(deps)

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

	var active_item_runtime = deps.get("active_item_runtime", null)
	var active_item_slots: Array = []
	if active_item_runtime != null:
		if active_item_runtime.has_method("reset"):
			active_item_runtime.reset()
		if active_item_runtime.has_method("build_starting_slots"):
			active_item_slots = active_item_runtime.build_starting_slots()

	var skill_states_value: Variant = deps.get("skill_states", [])
	if skill_states_value is Array:
		for skill_state in skill_states_value:
			if skill_state != null and skill_state.has_method("reset"):
				skill_state.reset()
	else:
		var skill_state = deps.get("skill_state", null)
		if skill_state != null:
			skill_state.reset()

	var drive_input_state = deps.get("drive_input_state", null)
	if drive_input_state != null:
		drive_input_state.reset_cooldowns()

	var runtime_perk_state = deps.get("runtime_perk_state", null)
	if runtime_perk_state != null and runtime_perk_state.has_method("reset"):
		runtime_perk_state.reset()

	var skill_configs_value: Variant = deps.get("skill_configs", [])
	if skill_configs_value is Array:
		for skill_config in skill_configs_value:
			if skill_config != null and skill_config.has_method("reset_runtime_skills"):
				skill_config.reset_runtime_skills()

	var skill_runtimes_value: Variant = deps.get("skill_runtimes", [])
	if skill_runtimes_value is Array:
		for skill_runtime in skill_runtimes_value:
			if skill_runtime != null and skill_runtime.has_method("reset"):
				skill_runtime.reset()

	var reset_drive_input_callback: Callable = callbacks.get("reset_drive_input", Callable())
	if reset_drive_input_callback.is_valid():
		reset_drive_input_callback.call()

	var dash_state = deps.get("dash_state", null)
	if dash_state != null:
		dash_state.reset_full(1)
		if orb_hud_state != null:
			var dash_snapshot: Dictionary = dash_state.get_snapshot()
			orb_hud_state.reset_dash_tokens(int(dash_snapshot.get("tokens", 0)))

	var audio = deps.get("audio", null)
	if audio != null and audio.has_method("stop_dash_delay"):
		audio.stop_dash_delay()

	var whip_state = deps.get("stage1_dalji_whip_skill_state", null)
	if whip_state != null and whip_state.has_method("reset"):
		whip_state.reset()

	var reset_ball_callback: Callable = callbacks.get("reset_ball", Callable())
	if reset_ball_callback.is_valid():
		reset_ball_callback.call()

	return {
		"special_gauge": 0.0,
		"drive_text_timer_frames": 0.0,
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"player_paddle_scale": 1.0,
		"runtime_perk_levels": {},
		"runtime_perk_pending_choices": 0,
		"runtime_perk_starpoints": 0,
		"runtime_perk_gold": 0,
		"runtime_perk_choice_active": false,
		"active_item_slots": active_item_slots,
	}
