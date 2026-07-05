extends RefCounted

const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")
const StageClearResultFallbackActorStatusBuilder := preload("res://scripts/ui/stage_clear_result_fallback_actor_status_builder.gd")
const StageClearResultLive2DBossStatusBuilder := preload("res://scripts/ui/stage_clear_result_live2d_boss_status_builder.gd")


static func build_actor_status(
	context: Dictionary,
	current_stage: int,
	view_size: Vector2,
	layout_scale: float
) -> Dictionary:
	var status: Dictionary = {}
	status.merge(_get_dalji_status(context, view_size, layout_scale), true)
	status.merge(_get_player_victory_status(context, view_size, layout_scale), true)
	status.merge(
		StageClearResultLive2DBossStatusBuilder.build_live2d_boss_defeat_status(
			context,
			current_stage,
			view_size,
			layout_scale
		),
		true
	)
	status.merge(
		StageClearResultFallbackActorStatusBuilder.build_stage_result_fallback_status(
			context,
			current_stage,
			view_size,
			layout_scale
		),
		true
	)
	return status


static func _get_dalji_status(context: Dictionary, view_size: Vector2, layout_scale: float) -> Dictionary:
	var reaction_state: Dictionary = _get_dictionary(context, "dalji_reaction_state")
	return {
		"dalji_click_reaction_active": bool(reaction_state.get("reaction_active", false)),
		"dalji_click_return_blend_active": bool(reaction_state.get("return_blend_active", false)),
		"dalji_click_reaction_timer": float(context.get("dalji_click_reaction_timer", 0.0)),
		"dalji_click_reaction_duration": float(context.get("dalji_click_reaction_duration", 0.0)),
		"dalji_click_total_duration": float(context.get("dalji_click_total_duration", 0.0)),
		"dalji_click_transition_base_frame": int(context.get("dalji_click_transition_base_frame", 0)),
		"dalji_base_frame": int(reaction_state.get("base_frame", 0)),
		"dalji_base_timer": float(context.get("dalji_base_timer", 0.0)),
		"dalji_reaction_alpha": float(reaction_state.get("reaction_alpha", 0.0)),
		"dalji_dialogue_timer": float(context.get("dalji_dialogue_timer", 0.0)),
		"dalji_click_rect": StageClearResultLayoutHelper.get_dalji_draw_rect(view_size, layout_scale),
		"dalji_dialogue": str(context.get("dalji_dialogue", "")),
		"dalji_click_voice_path": str(context.get("dalji_click_voice_path", "")),
		"dalji_click_voice_loaded": bool(context.get("dalji_click_voice_loaded", false)),
		"dalji_click_voice_player_ready": bool(context.get("dalji_click_voice_player_ready", false)),
		"dalji_click_voice_playing": bool(context.get("dalji_click_voice_playing", false)),
	}


static func _get_player_victory_status(context: Dictionary, view_size: Vector2, layout_scale: float) -> Dictionary:
	var reaction_state: Dictionary = _get_dictionary(context, "player_victory_reaction_state")
	var cell_size: Vector2 = context.get("player_victory_cell_size", Vector2.ZERO)
	return {
		"selected_character_type": str(context.get("selected_character_type", "")),
		"player_victory_sheet_path": str(context.get("player_victory_sheet_path", "")),
		"player_victory_click_reaction_sheet_path": str(context.get("player_victory_click_reaction_sheet_path", "")),
		"player_victory_sheet_loaded": bool(context.get("player_victory_sheet_loaded", false)),
		"player_victory_click_reaction_sheet_loaded": bool(context.get("player_victory_click_reaction_sheet_loaded", false)),
		"player_victory_frame_count": int(context.get("player_victory_frame_count", 0)),
		"player_victory_grid_cols": int(context.get("player_victory_grid_cols", 0)),
		"player_victory_cell_size": cell_size,
		"player_victory_base_frame": int(reaction_state.get("base_frame", 0)),
		"player_victory_click_reaction_active": bool(reaction_state.get("reaction_active", false)),
		"player_victory_click_return_blend_active": bool(reaction_state.get("return_blend_active", false)),
		"player_victory_click_reaction_timer": float(context.get("player_victory_click_reaction_timer", 0.0)),
		"player_victory_click_reaction_duration": float(context.get("player_victory_click_reaction_duration", 0.0)),
		"player_victory_click_total_duration": float(context.get("player_victory_click_total_duration", 0.0)),
		"player_victory_click_transition_base_frame": int(context.get("player_victory_click_transition_base_frame", 0)),
		"player_victory_reaction_alpha": float(reaction_state.get("reaction_alpha", 0.0)),
		"player_victory_draw_rect": StageClearResultLayoutHelper.get_player_victory_actor_rect(view_size, layout_scale),
		"player_victory_click_rect": StageClearResultLayoutHelper.get_player_victory_click_rect(
			view_size,
			layout_scale,
			cell_size
		),
	}


static func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}
