extends RefCounted

const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")
const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")


static func build_live2d_boss_defeat_scene_context(scene: Object) -> Dictionary:
	var context: Dictionary = {}
	for config: Dictionary in _get_live2d_boss_defeat_scene_context_configs():
		context.merge(_get_single_live2d_boss_defeat_scene_context(scene, config), true)
	return context


static func _get_live2d_boss_defeat_scene_context_configs() -> Array[Dictionary]:
	return [
		{
			"prefix": "stage2_boss_defeat",
			"reaction_state_key": "stage2_boss_reaction_state",
			"live2d_sheet_path": StageClearResultAssetLoader.STAGE2_BOSS_DEFEAT_LIVE2D_SHEET_PATH,
			"live2d_sheet_property": "_stage2_boss_defeat_live2d_sheet",
			"click_reaction_sheet_path": StageClearResultAssetLoader.STAGE2_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH,
			"click_reaction_sheet_property": "_stage2_boss_defeat_click_reaction_sheet",
			"reaction_timer_property": "_stage2_boss_defeat_click_reaction_timer",
			"transition_base_frame_property": "_stage2_boss_defeat_click_transition_base_frame",
		},
		{
			"prefix": "stage3_boss_defeat",
			"reaction_state_key": "stage3_boss_reaction_state",
			"live2d_sheet_path": StageClearResultAssetLoader.STAGE3_BOSS_DEFEAT_LIVE2D_SHEET_PATH,
			"live2d_sheet_property": "_stage3_boss_defeat_live2d_sheet",
			"click_reaction_sheet_path": StageClearResultAssetLoader.STAGE3_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH,
			"click_reaction_sheet_property": "_stage3_boss_defeat_click_reaction_sheet",
			"reaction_timer_property": "_stage3_boss_defeat_click_reaction_timer",
			"transition_base_frame_property": "_stage3_boss_defeat_click_transition_base_frame",
		},
		{
			"prefix": "stage4_ponk_boss_defeat",
			"reaction_state_key": "stage4_ponk_boss_reaction_state",
			"live2d_sheet_path": StageClearResultAssetLoader.STAGE4_PONK_BOSS_DEFEAT_LIVE2D_SHEET_PATH,
			"live2d_sheet_property": "_stage4_ponk_boss_defeat_live2d_sheet",
			"click_reaction_sheet_path": StageClearResultAssetLoader.STAGE4_PONK_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH,
			"click_reaction_sheet_property": "_stage4_ponk_boss_defeat_click_reaction_sheet",
			"reaction_timer_property": "_stage4_ponk_boss_defeat_click_reaction_timer",
			"transition_base_frame_property": "_stage4_ponk_boss_defeat_click_transition_base_frame",
		},
	]


static func _get_single_live2d_boss_defeat_scene_context(scene: Object, config: Dictionary) -> Dictionary:
	var prefix: String = str(config.get("prefix", ""))
	var reaction_timer_property: String = str(config.get("reaction_timer_property", ""))
	var transition_base_frame_property: String = str(config.get("transition_base_frame_property", ""))
	return {
		str(config.get("reaction_state_key", "")): StageClearResultActorDrawHelper.get_boss_defeat_reaction_state(
			float(scene.get("timer")),
			float(scene.get(reaction_timer_property)),
			int(scene.get(transition_base_frame_property))
		),
		"%s_live2d_sheet_path" % prefix: str(config.get("live2d_sheet_path", "")),
		"%s_live2d_sheet_loaded" % prefix: scene.get(str(config.get("live2d_sheet_property", ""))) != null,
		"%s_click_reaction_sheet_path" % prefix: str(config.get("click_reaction_sheet_path", "")),
		"%s_click_reaction_sheet_loaded" % prefix: scene.get(str(config.get("click_reaction_sheet_property", ""))) != null,
		"%s_live2d_frame_count" % prefix: StageClearResultActorDrawHelper.BOSS_DEFEAT_LIVE2D_FRAME_COUNT,
		"%s_live2d_grid_cols" % prefix: StageClearResultActorDrawHelper.BOSS_DEFEAT_LIVE2D_GRID_COLS,
		"%s_live2d_cell_size" % prefix: StageClearResultActorDrawHelper.BOSS_DEFEAT_LIVE2D_CELL_SIZE,
		"%s_click_reaction_timer" % prefix: scene.get(reaction_timer_property),
		"%s_click_reaction_duration" % prefix: StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_REACTION_DURATION,
		"%s_click_total_duration" % prefix: StageClearResultActorDrawHelper.BOSS_DEFEAT_CLICK_TOTAL_DURATION,
		"%s_click_transition_base_frame" % prefix: scene.get(transition_base_frame_property),
	}
