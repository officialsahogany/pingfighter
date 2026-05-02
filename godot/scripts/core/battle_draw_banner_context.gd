extends RefCounted

const BattleContextReader := preload("res://scripts/core/battle_context_reader.gd")


func build(context: Dictionary, deps: Dictionary) -> Dictionary:
	var dash_context: Dictionary = _get_dict(context.get("dash_snapshot", {}))
	var power_state = deps.get("power_state", null)
	var round_state = deps.get("round_state", null)
	var skill_costs: Dictionary = _get_skill_costs(deps.get("skill_config", null))
	return {
		"shake_offset": _get_vector2(context, "shake_offset", Vector2.ZERO),
		"ball_active": bool(context.get("ball_active", false)),
		"ball_pos": _get_vector2(context, "ball_pos", Vector2.ZERO),
		"ball_vel": _get_vector2(context, "ball_vel", Vector2.ZERO),
		"ball_render_radius": float(context.get("ball_render_radius", 16.9)),
		"player_pos": _get_vector2(context, "player_pos", Vector2.ZERO),
		"player_paddle_width": float(context.get("player_paddle_width", 155.0)),
		"special_gauge": float(context.get("special_gauge", 0.0)),
		"drive_gauge_cost": float(skill_costs.get("drive", 150.0)),
		"power_smash_gauge_cost": float(skill_costs.get("power_smashing", 300.0)),
		"waiting_for_serve": round_state == null or round_state.is_waiting_for_serve(),
		"dash_active": dash_context.get("active", false),
		"dash_is_half": dash_context.get("is_half", false),
		"drive_text_timer_frames": float(context.get("drive_text_timer_frames", 0.0)),
		"drive_text_duration_frames": float(context.get("drive_text_duration_frames", 0.0)),
		"power_smashing_text_timer_frames": power_state.get_text_timer_frames() if power_state != null else 0.0,
		"power_smash_text_duration_frames": float(context.get("power_smash_text_duration_frames", 0.0)),
	}


func _get_dict(value: Variant) -> Dictionary:
	return BattleContextReader.get_dictionary(value)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BattleContextReader.get_vector2(source, key, fallback)


func _get_skill_costs(skill_config: Object) -> Dictionary:
	if skill_config != null and skill_config.has_method("get_snapshot"):
		var snapshot: Variant = skill_config.get_snapshot()
		if snapshot is Dictionary:
			var costs: Variant = snapshot.get("skill_costs", {})
			if costs is Dictionary:
				return costs
	return {}
