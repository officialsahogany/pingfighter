extends RefCounted


func build_deps(registry: Object) -> Dictionary:
	return {
		"score_state": registry.get_instance("match_score_state"),
		"round_state": registry.get_instance("round_flow_state"),
		"scoreboard_state": registry.get_instance("scoreboard_state"),
		"audio": registry.get_instance("game_audio"),
		"orb_hud_state": registry.get_instance("orb_hud_state"),
		"active_hud_state": registry.get_instance("active_item_hud_state"),
		"active_item_runtime": registry.get_instance("active_item_runtime"),
		"skill_state": registry.get_instance("smasher_skill_state"),
		"drive_input_state": registry.get_instance("smasher_drive_input_state"),
		"dash_state": registry.get_instance("smasher_dash_state"),
	}
