extends RefCounted

const StageClearResultConfigSceneHandler := preload("res://scripts/ui/stage_clear_result_config_scene_handler.gd")

var _prewarm_assets_step_index: int = 0
var _prewarm_assets_status: Dictionary = {}


func get_prewarm_status() -> Dictionary:
	return _prewarm_assets_status.duplicate()


func prewarm_scene_shell(result_scene_packed_ready: bool) -> bool:
	_prewarm_assets_status["result_scene_packed"] = result_scene_packed_ready
	return bool(_prewarm_assets_status["result_scene_packed"])


func prewarm_assets_step(
	selected_character_type: String,
	stage_id: int,
	use_threaded_texture_loads: bool,
	result_scene_packed_ready: bool
) -> bool:
	if (
		str(_prewarm_assets_status.get("selected_character_type", "")) != selected_character_type
		or int(_prewarm_assets_status.get("current_stage", stage_id)) != stage_id
	):
		_prewarm_assets_step_index = 0
		_prewarm_assets_status.clear()
	if _prewarm_assets_step_index == 0:
		_prewarm_assets_status["selected_character_type"] = selected_character_type
		_prewarm_assets_status["current_stage"] = stage_id
		_prewarm_assets_status["result_scene_packed"] = result_scene_packed_ready
		_prewarm_assets_step_index = 1
		return false

	var scene_step_done := false
	if use_threaded_texture_loads:
		scene_step_done = bool(StageClearResultConfigSceneHandler.prewarm_assets_threaded_step(selected_character_type, stage_id))
	else:
		scene_step_done = bool(StageClearResultConfigSceneHandler.prewarm_assets_step(selected_character_type, stage_id))
	if not scene_step_done:
		return false
	var scene_status: Dictionary = StageClearResultConfigSceneHandler.get_prewarm_asset_status()
	for key in scene_status.keys():
		_prewarm_assets_status[key] = scene_status[key]
	_prewarm_assets_step_index = 0
	return true


func are_assets_ready_for_spawn(selected_character_type: String, stage_id: int) -> bool:
	var scene_status: Dictionary = StageClearResultConfigSceneHandler.get_prewarm_asset_status()
	if str(scene_status.get("selected_character_type", "")) != selected_character_type:
		return false
	if int(scene_status.get("current_stage", 0)) != stage_id:
		return false
	for key in get_required_scene_asset_keys(stage_id):
		if not bool(scene_status.get(key, false)):
			return false
	return true


func get_required_scene_asset_keys(stage_id: int) -> Array[String]:
	var keys: Array[String] = [
		"background_texture",
		"player_victory_sheet",
		"player_victory_click_reaction_sheet",
		"scroll_texture",
		"result_box_sheet_common",
		"result_box_sheet_mythic",
		"result_box_sheet_guaranteed_mythic",
		"result_box_fx",
	]
	match stage_id:
		7:
			# 스테이지 7: 전용 배경/시트가 선택적 — 제네릭 배경과 코드
			# 네이티브 액터로 스폰을 허용한다(에셋 도착 시 자동 승격).
			keys.erase("background_texture")
		1:
			keys.append("dalji_defeat_sheet")
			keys.append("dalji_click_reaction_sheet")
			keys.append("dalji_click_voice")
		2:
			keys.append("stage2_boss_defeat_live2d_sheet")
			keys.append("stage2_boss_defeat_click_reaction_sheet")
		3:
			keys.append("stage3_boss_defeat_live2d_sheet")
			keys.append("stage3_boss_defeat_click_reaction_sheet")
		4:
			keys.append("stage4_ponk_boss_defeat_live2d_sheet")
			keys.append("stage4_ponk_boss_defeat_click_reaction_sheet")
		5:
			keys.append("stage5_hongryun_result_sheet")
		6:
			keys.append("stage6_boss_defeat_sheet")
	return keys
