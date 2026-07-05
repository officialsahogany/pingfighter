extends RefCounted

const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")
const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")
const StageClearResultFallbackActorSceneContextBuilder := preload("res://scripts/ui/stage_clear_result_fallback_actor_scene_context_builder.gd")
const StageClearResultLive2DBossSceneContextBuilder := preload("res://scripts/ui/stage_clear_result_live2d_boss_scene_context_builder.gd")


static func build_actor_scene_context(scene: Object, dalji_dialogue: String) -> Dictionary:
	var context: Dictionary = {}
	context.merge(_get_dalji_scene_context(scene, dalji_dialogue), true)
	context.merge(_get_player_victory_scene_context(scene), true)
	context.merge(StageClearResultLive2DBossSceneContextBuilder.build_live2d_boss_defeat_scene_context(scene), true)
	context.merge(
		StageClearResultFallbackActorSceneContextBuilder.build_stage_result_fallback_scene_context(scene),
		true
	)
	return context


static func _get_dalji_scene_context(scene: Object, dalji_dialogue: String) -> Dictionary:
	var dalji_click_voice_player: Object = scene.get("_dalji_click_voice_player")
	return {
		"dalji_reaction_state": StageClearResultActorDrawHelper.get_dalji_reaction_state(
			float(scene.get("_dalji_base_timer")),
			float(scene.get("_dalji_click_reaction_timer")),
			int(scene.get("_dalji_click_transition_base_frame"))
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
	}


static func _get_player_victory_scene_context(scene: Object) -> Dictionary:
	var selected_character_type: String = str(scene.get("selected_character_type"))
	return {
		"selected_character_type": selected_character_type,
		"player_victory_reaction_state": StageClearResultActorDrawHelper.get_player_victory_reaction_state(
			float(scene.get("timer")),
			float(scene.get("_player_victory_click_reaction_timer")),
			int(scene.get("_player_victory_click_transition_base_frame"))
		),
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
	}
