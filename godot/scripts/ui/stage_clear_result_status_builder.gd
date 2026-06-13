extends RefCounted

const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")
const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")
const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")
const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")
const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")
const StageClearResultSummaryBuilder := preload("res://scripts/ui/stage_clear_result_summary_builder.gd")


static func build_scene_interaction_status(scene: Object, dalji_dialogue: String) -> Dictionary:
	var view_size: Vector2 = _get_vector2(scene.call("_get_current_view_size"))
	var layout_scale: float = float(scene.call("_get_layout_scale", view_size))
	var boxes: Array = _get_object_array(scene, "_boxes")
	var scroll_position_offset: Vector2 = _get_object_vector2(scene, "_scroll_position_offset")
	var reward_summary_state: Dictionary = StageClearResultSummaryBuilder.build_result_summary_state(
		_get_object_dictionary(scene, "stage_reward_snapshot"),
		boxes
	)
	var selected_character_type: String = str(scene.get("selected_character_type"))
	var dalji_click_voice_player: Object = scene.get("_dalji_click_voice_player")
	var exit_callback: Callable = scene.get("exit_to_menu_callback")
	var game_audio: Object = scene.get("_game_audio")

	return build_interaction_status({
		"view_size": view_size,
		"layout_scale": layout_scale,
		"boxes": boxes,
		"box_counts": StageClearResultInteractionState.get_box_state_counts(boxes),
		"reward_summary_state": reward_summary_state,
		"perk_info": StageClearResultSummaryBuilder.build_perk_info_summary_from_reward_state(
			reward_summary_state,
			scene.get("_perk_catalog")
		),
		"dalji_reaction_state": StageClearResultActorDrawHelper.get_dalji_reaction_state(
			float(scene.get("_dalji_base_timer")),
			float(scene.get("_dalji_click_reaction_timer")),
			int(scene.get("_dalji_click_transition_base_frame"))
		),
		"player_victory_reaction_state": StageClearResultActorDrawHelper.get_player_victory_reaction_state(
			float(scene.get("timer")),
			float(scene.get("_player_victory_click_reaction_timer")),
			int(scene.get("_player_victory_click_transition_base_frame"))
		),
		"stage2_boss_reaction_state": StageClearResultActorDrawHelper.get_boss_defeat_reaction_state(
			float(scene.get("timer")),
			float(scene.get("_stage2_boss_defeat_click_reaction_timer")),
			int(scene.get("_stage2_boss_defeat_click_transition_base_frame"))
		),
		"stage3_boss_reaction_state": StageClearResultActorDrawHelper.get_boss_defeat_reaction_state(
			float(scene.get("timer")),
			float(scene.get("_stage3_boss_defeat_click_reaction_timer")),
			int(scene.get("_stage3_boss_defeat_click_transition_base_frame"))
		),
		"dalji_click_reaction_timer": scene.get("_dalji_click_reaction_timer"),
		"dalji_click_reaction_duration": StageClearResultActorDrawHelper.DALJI_CLICK_REACTION_DURATION,
		"dalji_click_total_duration": StageClearResultActorDrawHelper.DALJI_CLICK_TOTAL_DURATION,
		"dalji_click_transition_base_frame": scene.get("_dalji_click_transition_base_frame"),
		"dalji_base_timer": scene.get("_dalji_base_timer"),
		"dalji_dialogue_timer": scene.get("_dalji_dialogue_timer"),
		"dalji_dialogue": dalji_dialogue,
		"dalji_click_voice_path": StageClearResultAssetLoader.DALJI_CLICK_VOICE_PATH,
		"dalji_click_voice_loaded": scene.get("_dalji_click_voice_stream") != null,
		"dalji_click_voice_player_ready": dalji_click_voice_player != null,
		"dalji_click_voice_playing": dalji_click_voice_player != null and bool(dalji_click_voice_player.get("playing")),
		"selected_character_type": selected_character_type,
		"player_victory_sheet_path": StageClearResultAssetLoader.get_player_victory_sheet_path_for_character(selected_character_type),
		"player_victory_click_reaction_sheet_path": StageClearResultAssetLoader.get_player_victory_click_reaction_sheet_path_for_character(selected_character_type),
		"player_victory_sheet_loaded": scene.get("_player_victory_sheet") != null,
		"player_victory_click_reaction_sheet_loaded": scene.get("_player_victory_click_reaction_sheet") != null,
		"player_victory_frame_count": StageClearResultActorDrawHelper.PLAYER_VICTORY_FRAME_COUNT,
		"player_victory_grid_cols": StageClearResultActorDrawHelper.PLAYER_VICTORY_GRID_COLS,
		"player_victory_cell_size": StageClearResultActorDrawHelper.PLAYER_VICTORY_CELL_SIZE,
		"player_victory_click_reaction_timer": scene.get("_player_victory_click_reaction_timer"),
		"player_victory_click_reaction_duration": StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_REACTION_DURATION,
		"player_victory_click_total_duration": StageClearResultActorDrawHelper.PLAYER_VICTORY_CLICK_TOTAL_DURATION,
		"player_victory_click_transition_base_frame": scene.get("_player_victory_click_transition_base_frame"),
		"stage2_boss_defeat_live2d_sheet_path": StageClearResultAssetLoader.STAGE2_BOSS_DEFEAT_LIVE2D_SHEET_PATH,
		"stage2_boss_defeat_live2d_sheet_loaded": scene.get("_stage2_boss_defeat_live2d_sheet") != null,
		"stage2_boss_defeat_click_reaction_sheet_path": StageClearResultAssetLoader.STAGE2_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH,
		"stage2_boss_defeat_click_reaction_sheet_loaded": scene.get("_stage2_boss_defeat_click_reaction_sheet") != null,
		"stage2_boss_defeat_live2d_frame_count": StageClearResultActorDrawHelper.BOSS_DEFEAT_LIVE2D_FRAME_COUNT,
		"stage2_boss_defeat_live2d_grid_cols": StageClearResultActorDrawHelper.BOSS_DEFEAT_LIVE2D_GRID_COLS,
		"stage2_boss_defeat_live2d_cell_size": StageClearResultActorDrawHelper.BOSS_DEFEAT_LIVE2D_CELL_SIZE,
		"stage2_boss_defeat_click_reaction_timer": scene.get("_stage2_boss_defeat_click_reaction_timer"),
		"stage2_boss_defeat_click_reaction_duration": StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_REACTION_DURATION,
		"stage2_boss_defeat_click_total_duration": StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		"stage2_boss_defeat_click_transition_base_frame": scene.get("_stage2_boss_defeat_click_transition_base_frame"),
		"stage3_boss_defeat_live2d_sheet_path": StageClearResultAssetLoader.STAGE3_BOSS_DEFEAT_LIVE2D_SHEET_PATH,
		"stage3_boss_defeat_live2d_sheet_loaded": scene.get("_stage3_boss_defeat_live2d_sheet") != null,
		"stage3_boss_defeat_click_reaction_sheet_path": StageClearResultAssetLoader.STAGE3_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH,
		"stage3_boss_defeat_click_reaction_sheet_loaded": scene.get("_stage3_boss_defeat_click_reaction_sheet") != null,
		"stage3_boss_defeat_live2d_frame_count": StageClearResultActorDrawHelper.BOSS_DEFEAT_LIVE2D_FRAME_COUNT,
		"stage3_boss_defeat_live2d_grid_cols": StageClearResultActorDrawHelper.BOSS_DEFEAT_LIVE2D_GRID_COLS,
		"stage3_boss_defeat_live2d_cell_size": StageClearResultActorDrawHelper.BOSS_DEFEAT_LIVE2D_CELL_SIZE,
		"stage3_boss_defeat_click_reaction_timer": scene.get("_stage3_boss_defeat_click_reaction_timer"),
		"stage3_boss_defeat_click_reaction_duration": StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_REACTION_DURATION,
		"stage3_boss_defeat_click_total_duration": StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		"stage3_boss_defeat_click_transition_base_frame": scene.get("_stage3_boss_defeat_click_transition_base_frame"),
		"current_stage": scene.get("current_stage"),
		"hovered_box_index": scene.get("_hovered_box_index"),
		"scroll_phase": scene.get("_scroll_phase"),
		"scroll_timer": scene.get("_scroll_timer"),
		"scroll_unfurl_duration": StageClearResultScrollState.SCROLL_UNFURL_DURATION,
		"scroll_texture_loaded": scene.get("_scroll_texture") != null,
		"scroll_rect": StageClearResultScrollState.get_region_full_rect(layout_scale, scroll_position_offset),
		"scroll_position_offset": scroll_position_offset,
		"scroll_dragging": scene.get("_scroll_dragging"),
		"next_stage_button_rect": _get_object_rect2(scene, "_next_stage_button_rect"),
		"plaza_button_rect": _get_object_rect2(scene, "_plaza_button_rect"),
		"exit_button_rect": _get_object_rect2(scene, "_exit_button_rect"),
		"hovered_button": scene.get("_hovered_button"),
		"scene_timer": scene.get("timer"),
		"exit_callback_bound": exit_callback.is_valid(),
		"starpoint_choice_gate_active": scene.get("_starpoint_choice_gate_active"),
		"starpoint_choice_gate_box_index": scene.get("_starpoint_choice_gate_box_index"),
		"runtime_perk_choice_active": bool(scene.call("_is_runtime_perk_choice_active")),
		"treasure_hunt_effect_active": bool(scene.call("_is_treasure_hunt_effect_active")),
		"box_open_audio_ready": game_audio != null and game_audio.has_method("play_result_box_open"),
	})


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
		"plaza_button_rect": context.get("plaza_button_rect", Rect2()),
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


static func _get_object_array(source: Object, key: String) -> Array:
	var value: Variant = source.get(key)
	if value is Array:
		return value
	return []


static func _get_object_dictionary(source: Object, key: String) -> Dictionary:
	var value: Variant = source.get(key)
	if value is Dictionary:
		return value
	return {}


static func _get_object_rect2(source: Object, key: String) -> Rect2:
	var value: Variant = source.get(key)
	if value is Rect2:
		return value
	return Rect2()


static func _get_object_vector2(source: Object, key: String) -> Vector2:
	return _get_vector2(source.get(key))


static func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO
