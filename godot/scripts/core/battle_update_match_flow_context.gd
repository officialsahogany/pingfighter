extends RefCounted


func build_deps(registry: Object) -> Dictionary:
	var smasher_skill_state: Object = registry.get_instance("smasher_skill_state")
	var viper_skill_state: Object = registry.get_instance("viper_skill_state")
	var deps := {}
	deps["score_state"] = registry.get_instance("match_score_state")
	deps["round_state"] = registry.get_instance("round_flow_state")
	deps["scoreboard_state"] = registry.get_instance("scoreboard_state")
	deps["audio"] = registry.get_instance("game_audio")
	deps["orb_hud_state"] = registry.get_instance("orb_hud_state")
	deps["active_hud_state"] = registry.get_instance("active_item_hud_state")
	deps["active_item_runtime"] = registry.get_instance("active_item_runtime")
	deps["skill_state"] = smasher_skill_state
	deps["skill_states"] = [smasher_skill_state, viper_skill_state]
	deps["skill_configs"] = [
		registry.get_instance("smasher_skill_config"),
		registry.get_instance("viper_skill_config"),
	]
	deps["runtime_perk_state"] = registry.get_instance("runtime_perk_state")
	deps["drive_input_state"] = registry.get_instance("smasher_drive_input_state")
	deps["dash_state"] = registry.get_instance("smasher_dash_state")
	deps["stage1_dalji_whip_skill_state"] = registry.get_instance("stage1_dalji_whip_skill_state")
	return deps
