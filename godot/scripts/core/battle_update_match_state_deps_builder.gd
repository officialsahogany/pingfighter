extends RefCounted


func build_deps(registry: Object) -> Dictionary:
	return {
		"score_state": _get_instance(registry, "match_score_state"),
		"round_state": _get_instance(registry, "round_flow_state"),
		"scoreboard_state": _get_instance(registry, "scoreboard_state"),
		"ball_intensity": _get_instance(registry, "ball_intensity"),
		"victory_highlight_playback_state": _get_instance(registry, "victory_highlight_playback_state"),
		"victory_highlight_recorder": _get_instance(registry, "victory_highlight_recorder"),
		"victory_loot_phase_state": _get_instance(registry, "victory_loot_phase_state"),
		"audio": _get_instance(registry, "game_audio"),
		"match_score_event_controller": _get_instance(registry, "match_score_event_controller"),
		"match_scoreboard_flow_controller": _get_instance(registry, "match_scoreboard_flow_controller"),
		"match_round_restart_controller": _get_instance(registry, "match_round_restart_controller"),
		"match_reset_controller": _get_instance(registry, "match_reset_controller"),
	}


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
