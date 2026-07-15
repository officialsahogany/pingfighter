extends RefCounted

const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")


static func build_stage_result_fallback_status(
	context: Dictionary,
	current_stage: int,
	view_size: Vector2,
	layout_scale: float
) -> Dictionary:
	var status: Dictionary = {}
	for config: Dictionary in _get_stage_result_fallback_status_configs(view_size, layout_scale):
		status.merge(_get_single_stage_result_fallback_status(context, current_stage, config), true)
	return status


static func _get_stage_result_fallback_status_configs(view_size: Vector2, layout_scale: float) -> Array[Dictionary]:
	return [
		{
			"stage_id": 5,
			"prefix": "stage5_hongryun_result",
			"reaction_state_key": "stage5_hongryun_reaction_state",
			"draw_rect": StageClearResultLayoutHelper.get_stage5_hongryun_result_draw_rect(view_size, layout_scale),
		},
		{
			"stage_id": 6,
			"prefix": "stage6_boss_defeat",
			"reaction_state_key": "stage6_boss_reaction_state",
			"draw_rect": StageClearResultLayoutHelper.get_stage6_tetriser_result_draw_rect(view_size, layout_scale),
		},
		{
			"stage_id": 7,
			"prefix": "stage7_boss_defeat",
			"reaction_state_key": "stage7_boss_reaction_state",
			"draw_rect": StageClearResultLayoutHelper.get_stage7_result_draw_rect(view_size, layout_scale),
			# 시트 부재(코드 네이티브 폴백)에서는 클릭 계약이 없으므로 status가
			# 빈 scene rect를 draw_rect로 '되살리지' 않는다 — 실입력의
			# sheet != null 게이트와 정합.
			"clickless_without_sheet": true,
		},
	]


static func _get_single_stage_result_fallback_status(
	context: Dictionary,
	current_stage: int,
	config: Dictionary
) -> Dictionary:
	var prefix: String = str(config.get("prefix", ""))
	var reaction_state: Dictionary = _get_dictionary(context, str(config.get("reaction_state_key", "")))
	var draw_rect: Rect2 = config.get("draw_rect", Rect2())
	var sheet_loaded: bool = bool(context.get("%s_sheet_loaded" % prefix, false))
	var click_rect: Rect2 = _get_valid_rect_or_default(context.get("%s_click_rect" % prefix, draw_rect), draw_rect)
	if bool(config.get("clickless_without_sheet", false)) and not sheet_loaded:
		click_rect = Rect2()
	return {
		"%s_sheet_path" % prefix: str(context.get("%s_sheet_path" % prefix, "")),
		"%s_sheet_loaded" % prefix: sheet_loaded,
		"%s_active" % prefix: current_stage == int(config.get("stage_id", 0)),
		"%s_frame_count" % prefix: int(context.get("%s_frame_count" % prefix, 0)),
		"%s_grid_cols" % prefix: int(context.get("%s_grid_cols" % prefix, 0)),
		"%s_cell_size" % prefix: context.get("%s_cell_size" % prefix, Vector2.ZERO),
		"%s_base_frame" % prefix: int(reaction_state.get("base_frame", 0)),
		"%s_draw_rect" % prefix: draw_rect,
		"%s_click_rect" % prefix: click_rect,
		"%s_click_reaction_active" % prefix: bool(reaction_state.get("reaction_active", false)),
		"%s_click_return_blend_active" % prefix: bool(reaction_state.get("return_blend_active", false)),
		"%s_click_reaction_timer" % prefix: float(context.get("%s_click_reaction_timer" % prefix, 0.0)),
		"%s_click_reaction_duration" % prefix: float(context.get("%s_click_reaction_duration" % prefix, 0.0)),
		"%s_click_total_duration" % prefix: float(context.get("%s_click_total_duration" % prefix, 0.0)),
		"%s_click_transition_base_frame" % prefix: int(context.get("%s_click_transition_base_frame" % prefix, 0)),
		"%s_reaction_alpha" % prefix: float(reaction_state.get("reaction_alpha", 0.0)),
	}


static func _get_valid_rect_or_default(value: Variant, default_rect: Rect2) -> Rect2:
	if value is Rect2:
		var candidate: Rect2 = value
		if candidate.size.x > 0.0 and candidate.size.y > 0.0:
			return candidate
	return default_rect


static func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}
