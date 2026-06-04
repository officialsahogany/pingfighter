extends RefCounted

const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")
const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")


static func build_interaction_status(context: Dictionary) -> Dictionary:
	var view_size: Vector2 = context.get("view_size", Vector2.ZERO)
	var layout_scale: float = float(context.get("layout_scale", 1.0))
	var boxes: Array = _get_array(context, "boxes")
	var box_counts: Dictionary = _get_dictionary(context, "box_counts")
	var reward_summary_state: Dictionary = _get_dictionary(context, "reward_summary_state")
	var dalji_reaction_state: Dictionary = _get_dictionary(context, "dalji_reaction_state")
	var player_victory_reaction_state: Dictionary = _get_dictionary(context, "player_victory_reaction_state")
	var stage2_boss_reaction_state: Dictionary = _get_dictionary(context, "stage2_boss_reaction_state")
	var stage3_boss_reaction_state: Dictionary = _get_dictionary(context, "stage3_boss_reaction_state")
	var opened_count: int = int(box_counts.get("opened_count", 0))
	var opening_count: int = int(box_counts.get("opening_count", 0))
	var scroll_phase: String = str(context.get("scroll_phase", "hidden"))
	var current_stage: int = int(context.get("current_stage", 1))
	var player_victory_cell_size: Vector2 = context.get("player_victory_cell_size", Vector2.ZERO)

	return {
		"dalji_click_reaction_active": bool(dalji_reaction_state.get("reaction_active", false)),
		"dalji_click_return_blend_active": bool(dalji_reaction_state.get("return_blend_active", false)),
		"dalji_click_reaction_timer": float(context.get("dalji_click_reaction_timer", 0.0)),
		"dalji_click_reaction_duration": float(context.get("dalji_click_reaction_duration", 0.0)),
		"dalji_click_total_duration": float(context.get("dalji_click_total_duration", 0.0)),
		"dalji_click_transition_base_frame": int(context.get("dalji_click_transition_base_frame", 0)),
		"dalji_base_frame": int(dalji_reaction_state.get("base_frame", 0)),
		"dalji_base_timer": float(context.get("dalji_base_timer", 0.0)),
		"dalji_reaction_alpha": float(dalji_reaction_state.get("reaction_alpha", 0.0)),
		"dalji_dialogue_timer": float(context.get("dalji_dialogue_timer", 0.0)),
		"dalji_click_rect": StageClearResultLayoutHelper.get_dalji_draw_rect(view_size, layout_scale),
		"dalji_dialogue": str(context.get("dalji_dialogue", "")),
		"dalji_click_voice_path": str(context.get("dalji_click_voice_path", "")),
		"dalji_click_voice_loaded": bool(context.get("dalji_click_voice_loaded", false)),
		"dalji_click_voice_player_ready": bool(context.get("dalji_click_voice_player_ready", false)),
		"dalji_click_voice_playing": bool(context.get("dalji_click_voice_playing", false)),
		"selected_character_type": str(context.get("selected_character_type", "")),
		"player_victory_sheet_path": str(context.get("player_victory_sheet_path", "")),
		"player_victory_click_reaction_sheet_path": str(context.get("player_victory_click_reaction_sheet_path", "")),
		"stage2_boss_defeat_live2d_sheet_path": str(context.get("stage2_boss_defeat_live2d_sheet_path", "")),
		"stage2_boss_defeat_live2d_sheet_loaded": bool(context.get("stage2_boss_defeat_live2d_sheet_loaded", false)),
		"stage2_boss_defeat_click_reaction_sheet_path": str(context.get("stage2_boss_defeat_click_reaction_sheet_path", "")),
		"stage2_boss_defeat_click_reaction_sheet_loaded": bool(context.get("stage2_boss_defeat_click_reaction_sheet_loaded", false)),
		"stage2_boss_defeat_live2d_active": current_stage == 2,
		"stage2_boss_defeat_live2d_frame_count": int(context.get("stage2_boss_defeat_live2d_frame_count", 0)),
		"stage2_boss_defeat_live2d_grid_cols": int(context.get("stage2_boss_defeat_live2d_grid_cols", 0)),
		"stage2_boss_defeat_live2d_cell_size": context.get("stage2_boss_defeat_live2d_cell_size", Vector2.ZERO),
		"stage2_boss_defeat_live2d_base_frame": int(stage2_boss_reaction_state.get("base_frame", 0)),
		"stage2_boss_defeat_live2d_draw_rect": StageClearResultLayoutHelper.get_stage2_boss_result_draw_rect(view_size, layout_scale),
		"stage2_boss_defeat_click_rect": StageClearResultLayoutHelper.get_stage2_boss_result_draw_rect(view_size, layout_scale),
		"stage2_boss_defeat_click_reaction_active": bool(stage2_boss_reaction_state.get("reaction_active", false)),
		"stage2_boss_defeat_click_return_blend_active": bool(stage2_boss_reaction_state.get("return_blend_active", false)),
		"stage2_boss_defeat_click_reaction_timer": float(context.get("stage2_boss_defeat_click_reaction_timer", 0.0)),
		"stage2_boss_defeat_click_reaction_duration": float(context.get("stage2_boss_defeat_click_reaction_duration", 0.0)),
		"stage2_boss_defeat_click_total_duration": float(context.get("stage2_boss_defeat_click_total_duration", 0.0)),
		"stage2_boss_defeat_click_transition_base_frame": int(context.get("stage2_boss_defeat_click_transition_base_frame", 0)),
		"stage2_boss_defeat_reaction_alpha": float(stage2_boss_reaction_state.get("reaction_alpha", 0.0)),
		"stage3_boss_defeat_live2d_sheet_path": str(context.get("stage3_boss_defeat_live2d_sheet_path", "")),
		"stage3_boss_defeat_live2d_sheet_loaded": bool(context.get("stage3_boss_defeat_live2d_sheet_loaded", false)),
		"stage3_boss_defeat_click_reaction_sheet_path": str(context.get("stage3_boss_defeat_click_reaction_sheet_path", "")),
		"stage3_boss_defeat_click_reaction_sheet_loaded": bool(context.get("stage3_boss_defeat_click_reaction_sheet_loaded", false)),
		"stage3_boss_defeat_live2d_active": current_stage == 3,
		"stage3_boss_defeat_live2d_frame_count": int(context.get("stage3_boss_defeat_live2d_frame_count", 0)),
		"stage3_boss_defeat_live2d_grid_cols": int(context.get("stage3_boss_defeat_live2d_grid_cols", 0)),
		"stage3_boss_defeat_live2d_cell_size": context.get("stage3_boss_defeat_live2d_cell_size", Vector2.ZERO),
		"stage3_boss_defeat_live2d_base_frame": int(stage3_boss_reaction_state.get("base_frame", 0)),
		"stage3_boss_defeat_live2d_draw_rect": StageClearResultLayoutHelper.get_stage3_boss_result_draw_rect(view_size, layout_scale),
		"stage3_boss_defeat_click_rect": StageClearResultLayoutHelper.get_stage3_boss_result_draw_rect(view_size, layout_scale),
		"stage3_boss_defeat_click_reaction_active": bool(stage3_boss_reaction_state.get("reaction_active", false)),
		"stage3_boss_defeat_click_return_blend_active": bool(stage3_boss_reaction_state.get("return_blend_active", false)),
		"stage3_boss_defeat_click_reaction_timer": float(context.get("stage3_boss_defeat_click_reaction_timer", 0.0)),
		"stage3_boss_defeat_click_reaction_duration": float(context.get("stage3_boss_defeat_click_reaction_duration", 0.0)),
		"stage3_boss_defeat_click_total_duration": float(context.get("stage3_boss_defeat_click_total_duration", 0.0)),
		"stage3_boss_defeat_click_transition_base_frame": int(context.get("stage3_boss_defeat_click_transition_base_frame", 0)),
		"stage3_boss_defeat_reaction_alpha": float(stage3_boss_reaction_state.get("reaction_alpha", 0.0)),
		"player_victory_sheet_loaded": bool(context.get("player_victory_sheet_loaded", false)),
		"player_victory_click_reaction_sheet_loaded": bool(context.get("player_victory_click_reaction_sheet_loaded", false)),
		"player_victory_frame_count": int(context.get("player_victory_frame_count", 0)),
		"player_victory_grid_cols": int(context.get("player_victory_grid_cols", 0)),
		"player_victory_cell_size": player_victory_cell_size,
		"player_victory_base_frame": int(player_victory_reaction_state.get("base_frame", 0)),
		"player_victory_click_reaction_active": bool(player_victory_reaction_state.get("reaction_active", false)),
		"player_victory_click_return_blend_active": bool(player_victory_reaction_state.get("return_blend_active", false)),
		"player_victory_click_reaction_timer": float(context.get("player_victory_click_reaction_timer", 0.0)),
		"player_victory_click_reaction_duration": float(context.get("player_victory_click_reaction_duration", 0.0)),
		"player_victory_click_total_duration": float(context.get("player_victory_click_total_duration", 0.0)),
		"player_victory_click_transition_base_frame": int(context.get("player_victory_click_transition_base_frame", 0)),
		"player_victory_reaction_alpha": float(player_victory_reaction_state.get("reaction_alpha", 0.0)),
		"player_victory_draw_rect": StageClearResultLayoutHelper.get_player_victory_actor_rect(view_size, layout_scale),
		"player_victory_click_rect": StageClearResultLayoutHelper.get_player_victory_click_rect(
			view_size,
			layout_scale,
			player_victory_cell_size
		),
		"box_count": boxes.size(),
		"opened_count": opened_count,
		"opening_count": opening_count,
		"item_reward_count": int(reward_summary_state.get("item_reward_count", 0)),
		"perk_reward_count": int(reward_summary_state.get("perk_reward_count", 0)),
		"stage_active_item_count": int(reward_summary_state.get("stage_active_item_count", 0)),
		"stage_passive_item_count": int(reward_summary_state.get("stage_passive_item_count", 0)),
		"stage_perk_count": int(reward_summary_state.get("stage_perk_count", 0)),
		"item_reward_source_counts": reward_summary_state.get("item_reward_source_counts", {}),
		"perk_reward_source_counts": reward_summary_state.get("perk_reward_source_counts", {}),
		"visible_reward_source_counts": reward_summary_state.get("visible_reward_source_counts", {}),
		"box_display_labels": StageClearResultBoxData.get_box_display_labels(boxes),
		"perk_info": context.get("perk_info", {}),
		"starpoint_total": int(reward_summary_state.get("starpoint_total", 0)),
		"hovered_box_index": int(context.get("hovered_box_index", -1)),
		"all_boxes_opened": boxes.size() > 0 and opened_count == boxes.size(),
		"scroll_phase": scroll_phase,
		"scroll_unfurl_progress": StageClearResultScrollState.get_unfurl_progress(
			scroll_phase,
			float(context.get("scroll_timer", 0.0)),
			float(context.get("scroll_unfurl_duration", 0.0))
		),
		"scroll_visible": scroll_phase == "unfurling" or scroll_phase == "visible",
		"scroll_texture_loaded": bool(context.get("scroll_texture_loaded", false)),
		"scroll_rect": context.get("scroll_rect", Rect2()),
		"scroll_position_offset": context.get("scroll_position_offset", Vector2.ZERO),
		"scroll_dragging": bool(context.get("scroll_dragging", false)),
		"next_stage_button_rect": context.get("next_stage_button_rect", Rect2()),
		"exit_button_rect": context.get("exit_button_rect", Rect2()),
		"buttons_clickable": scroll_phase == "visible",
		"hovered_button": str(context.get("hovered_button", "")),
		"scene_timer": float(context.get("scene_timer", 0.0)),
		"exit_callback_bound": bool(context.get("exit_callback_bound", false)),
		"starpoint_choice_gate_active": bool(context.get("starpoint_choice_gate_active", false)),
		"starpoint_choice_gate_box_index": int(context.get("starpoint_choice_gate_box_index", -1)),
		"runtime_perk_choice_active": bool(context.get("runtime_perk_choice_active", false)),
		"treasure_hunt_effect_active": bool(context.get("treasure_hunt_effect_active", false)),
		"box_open_audio_ready": bool(context.get("box_open_audio_ready", false)),
	}


static func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


static func _get_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	if value is Array:
		return value
	return []
