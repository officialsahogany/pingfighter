extends RefCounted


func build_deps(registry: Object) -> Dictionary:
	return {
		"feedback": _get_instance(registry, "battle_feedback_state"),
		"audio": _get_instance(registry, "game_audio"),
		"score_state": _get_instance(registry, "match_score_state"),
		"scoreboard_state": _get_instance(registry, "scoreboard_state"),
		"orb_hud_state": _get_instance(registry, "orb_hud_state"),
		"animation_state": _get_instance(registry, "actor_animation_state"),
		"impact_effects": _get_instance(registry, "impact_effects"),
		"ball_effects": _get_instance(registry, "ball_effects"),
		"movement_state": _get_instance(registry, "player_movement_state"),
		"status_effect_state": _get_instance(registry, "status_effect_state"),
		"active_item_runtime": _get_instance(registry, "active_item_runtime"),
		"mythic_item_runtime": _get_instance(registry, "mythic_item_runtime"),
		"runtime_perk_state": _get_instance(registry, "runtime_perk_state"),
		"runtime_perk_catalog": _get_instance(registry, "runtime_perk_catalog"),
	}


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
