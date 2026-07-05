extends RefCounted

const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")


static func build_live2d_boss_defeat_status(
	context: Dictionary,
	current_stage: int,
	view_size: Vector2,
	layout_scale: float
) -> Dictionary:
	var status: Dictionary = {}
	for config: Dictionary in _get_live2d_boss_defeat_status_configs(view_size, layout_scale):
		status.merge(_get_single_live2d_boss_defeat_status(context, current_stage, config), true)
	return status


static func _get_live2d_boss_defeat_status_configs(view_size: Vector2, layout_scale: float) -> Array[Dictionary]:
	return [
		{
			"stage_id": 2,
			"prefix": "stage2_boss_defeat",
			"reaction_state_key": "stage2_boss_reaction_state",
			"draw_rect": StageClearResultLayoutHelper.get_stage2_boss_result_draw_rect(view_size, layout_scale),
		},
		{
			"stage_id": 3,
			"prefix": "stage3_boss_defeat",
			"reaction_state_key": "stage3_boss_reaction_state",
			"draw_rect": StageClearResultLayoutHelper.get_stage3_boss_result_draw_rect(view_size, layout_scale),
		},
		{
			"stage_id": 4,
			"prefix": "stage4_ponk_boss_defeat",
			"reaction_state_key": "stage4_ponk_boss_reaction_state",
			"draw_rect": StageClearResultLayoutHelper.get_stage4_boss_result_draw_rect(view_size, layout_scale),
		},
	]


static func _get_single_live2d_boss_defeat_status(
	context: Dictionary,
	current_stage: int,
	config: Dictionary
) -> Dictionary:
	var prefix: String = str(config.get("prefix", ""))
	var reaction_state: Dictionary = _get_dictionary(context, str(config.get("reaction_state_key", "")))
	var draw_rect: Rect2 = config.get("draw_rect", Rect2())
	return {
		"%s_live2d_sheet_path" % prefix: str(context.get("%s_live2d_sheet_path" % prefix, "")),
		"%s_live2d_sheet_loaded" % prefix: bool(context.get("%s_live2d_sheet_loaded" % prefix, false)),
		"%s_click_reaction_sheet_path" % prefix: str(context.get("%s_click_reaction_sheet_path" % prefix, "")),
		"%s_click_reaction_sheet_loaded" % prefix: bool(context.get("%s_click_reaction_sheet_loaded" % prefix, false)),
		"%s_live2d_active" % prefix: current_stage == int(config.get("stage_id", 0)),
		"%s_live2d_frame_count" % prefix: int(context.get("%s_live2d_frame_count" % prefix, 0)),
		"%s_live2d_grid_cols" % prefix: int(context.get("%s_live2d_grid_cols" % prefix, 0)),
		"%s_live2d_cell_size" % prefix: context.get("%s_live2d_cell_size" % prefix, Vector2.ZERO),
		"%s_live2d_base_frame" % prefix: int(reaction_state.get("base_frame", 0)),
		"%s_live2d_draw_rect" % prefix: draw_rect,
		"%s_click_rect" % prefix: draw_rect,
		"%s_click_reaction_active" % prefix: bool(reaction_state.get("reaction_active", false)),
		"%s_click_return_blend_active" % prefix: bool(reaction_state.get("return_blend_active", false)),
		"%s_click_reaction_timer" % prefix: float(context.get("%s_click_reaction_timer" % prefix, 0.0)),
		"%s_click_reaction_duration" % prefix: float(context.get("%s_click_reaction_duration" % prefix, 0.0)),
		"%s_click_total_duration" % prefix: float(context.get("%s_click_total_duration" % prefix, 0.0)),
		"%s_click_transition_base_frame" % prefix: int(context.get("%s_click_transition_base_frame" % prefix, 0)),
		"%s_reaction_alpha" % prefix: float(reaction_state.get("reaction_alpha", 0.0)),
	}


static func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}
