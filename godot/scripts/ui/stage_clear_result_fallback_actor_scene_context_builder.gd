extends RefCounted

const StageClearResultActorDrawHelper := preload("res://scripts/ui/stage_clear_result_actor_draw_helper.gd")
const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")


static func build_stage_result_fallback_scene_context(scene: Object) -> Dictionary:
	var context: Dictionary = {}
	for config: Dictionary in _get_stage_result_fallback_scene_context_configs():
		context.merge(_get_single_stage_result_fallback_scene_context(scene, config), true)
	return context


static func _get_stage_result_fallback_scene_context_configs() -> Array[Dictionary]:
	return [
		{
			"prefix": "stage5_hongryun_result",
			"reaction_state_key": "stage5_hongryun_reaction_state",
			"reaction_kind": "stage5_hongryun",
			"sheet_path": StageClearResultAssetLoader.STAGE5_HONGRYUN_RESULT_SHEET_PATH,
			"sheet_property": "_stage5_hongryun_result_sheet",
			"click_rect_property": "_stage5_hongryun_result_click_rect",
			"reaction_timer_property": "_stage5_hongryun_result_click_reaction_timer",
			"transition_base_frame_property": "_stage5_hongryun_result_click_transition_base_frame",
			"frame_count": StageClearResultActorDrawHelper.STAGE5_HONGRYUN_RESULT_FRAME_COUNT,
			"grid_cols": StageClearResultActorDrawHelper.STAGE5_HONGRYUN_RESULT_GRID_COLS,
			"cell_size": StageClearResultActorDrawHelper.STAGE5_HONGRYUN_RESULT_CELL_SIZE,
			"click_reaction_duration": StageClearResultActorDrawHelper.STAGE5_HONGRYUN_CLICK_REACTION_DURATION,
			"click_total_duration": StageClearResultActorDrawHelper.STAGE5_HONGRYUN_CLICK_TOTAL_DURATION,
		},
		{
			"prefix": "stage6_boss_defeat",
			"reaction_state_key": "stage6_boss_reaction_state",
			"reaction_kind": "stage6_tetriser",
			"sheet_path": StageClearResultAssetLoader.STAGE6_BOSS_DEFEAT_SHEET_PATH,
			"sheet_property": "_stage6_boss_defeat_sheet",
			"click_rect_property": "_stage6_boss_defeat_click_rect",
			"reaction_timer_property": "_stage6_boss_defeat_click_reaction_timer",
			"transition_base_frame_property": "_stage6_boss_defeat_click_transition_base_frame",
			"frame_count": StageClearResultActorDrawHelper.STAGE6_TETRISER_DEFEAT_FRAME_COUNT,
			"grid_cols": StageClearResultActorDrawHelper.STAGE6_TETRISER_DEFEAT_GRID_COLS,
			"cell_size": StageClearResultActorDrawHelper.STAGE6_TETRISER_DEFEAT_CELL_SIZE,
			"click_reaction_duration": StageClearResultActorDrawHelper.STAGE6_TETRISER_CLICK_REACTION_DURATION,
			"click_total_duration": StageClearResultActorDrawHelper.STAGE6_TETRISER_CLICK_TOTAL_DURATION,
		},
		{
			"prefix": "stage7_boss_defeat",
			"reaction_state_key": "stage7_boss_reaction_state",
			"reaction_kind": "stage7_akamu",
			"sheet_path": StageClearResultAssetLoader.STAGE7_BOSS_DEFEAT_SHEET_PATH,
			"sheet_property": "_stage7_boss_defeat_sheet",
			"click_rect_property": "_stage7_boss_defeat_click_rect",
			"reaction_timer_property": "_stage7_boss_defeat_click_reaction_timer",
			"transition_base_frame_property": "_stage7_boss_defeat_click_transition_base_frame",
			"frame_count": StageClearResultActorDrawHelper.STAGE7_AKAMU_DEFEAT_FRAME_COUNT,
			"grid_cols": StageClearResultActorDrawHelper.STAGE7_AKAMU_DEFEAT_GRID_COLS,
			"cell_size": StageClearResultActorDrawHelper.STAGE7_AKAMU_DEFEAT_CELL_SIZE,
			"click_reaction_duration": StageClearResultActorDrawHelper.STAGE7_AKAMU_CLICK_REACTION_DURATION,
			"click_total_duration": StageClearResultActorDrawHelper.STAGE7_AKAMU_CLICK_TOTAL_DURATION,
		},
	]


static func _get_single_stage_result_fallback_scene_context(scene: Object, config: Dictionary) -> Dictionary:
	var prefix: String = str(config.get("prefix", ""))
	var reaction_timer_property: String = str(config.get("reaction_timer_property", ""))
	var transition_base_frame_property: String = str(config.get("transition_base_frame_property", ""))
	var context: Dictionary = {}
	context[str(config.get("reaction_state_key", ""))] = _get_stage_result_fallback_scene_reaction_state(
		scene,
		str(config.get("reaction_kind", "")),
		reaction_timer_property,
		transition_base_frame_property
	)
	context["%s_sheet_path" % prefix] = str(config.get("sheet_path", ""))
	context["%s_sheet_loaded" % prefix] = scene.get(str(config.get("sheet_property", ""))) != null
	context["%s_frame_count" % prefix] = int(config.get("frame_count", 0))
	context["%s_grid_cols" % prefix] = int(config.get("grid_cols", 0))
	context["%s_cell_size" % prefix] = config.get("cell_size", Vector2.ZERO)
	context["%s_click_rect" % prefix] = _get_object_rect2(scene, str(config.get("click_rect_property", "")))
	context["%s_click_reaction_timer" % prefix] = scene.get(reaction_timer_property)
	context["%s_click_reaction_duration" % prefix] = float(config.get("click_reaction_duration", 0.0))
	context["%s_click_total_duration" % prefix] = float(config.get("click_total_duration", 0.0))
	context["%s_click_transition_base_frame" % prefix] = scene.get(transition_base_frame_property)
	return context


static func _get_stage_result_fallback_scene_reaction_state(
	scene: Object,
	reaction_kind: String,
	reaction_timer_property: String,
	transition_base_frame_property: String
) -> Dictionary:
	var timer: float = float(scene.get("timer"))
	var reaction_timer: float = float(scene.get(reaction_timer_property))
	var transition_base_frame: int = int(scene.get(transition_base_frame_property))
	match reaction_kind:
		"stage5_hongryun":
			return StageClearResultActorDrawHelper.get_stage5_hongryun_reaction_state(
				timer,
				reaction_timer,
				transition_base_frame
			)
		"stage6_tetriser":
			return StageClearResultActorDrawHelper.get_stage6_tetriser_reaction_state(
				timer,
				reaction_timer,
				transition_base_frame
			)
		"stage7_akamu":
			return StageClearResultActorDrawHelper.get_stage7_akamu_reaction_state(
				timer,
				reaction_timer,
				transition_base_frame
			)
	return {}


static func _get_object_rect2(source: Object, key: String) -> Rect2:
	var value: Variant = source.get(key)
	if value is Rect2:
		return value
	return Rect2()
