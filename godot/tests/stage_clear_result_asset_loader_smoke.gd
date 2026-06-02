extends SceneTree

const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_prewarm_steps()
	_verify_texture_bundle_load()
	_verify_audio_load()
	_verify_scene_delegates_asset_loading()
	_verify_threaded_prewarm_keeps_stale_loads_off_main_thread()
	_verify_result_box_polygon_colors()

	if _failures.is_empty():
		print("stage_clear_result_asset_loader_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_prewarm_steps() -> void:
	_expect(StageClearResultAssetLoader.PREWARM_ASSET_STEP_COUNT == StageClearResultScene.PREWARM_ASSET_STEP_COUNT, "asset loader step count should match the result scene budget")
	var status: Dictionary = {}
	for i in range(StageClearResultAssetLoader.PREWARM_ASSET_STEP_COUNT):
		StageClearResultAssetLoader.prewarm_assets_step(i, status, _asset_paths())
	_expect(bool(status.get("background_texture", false)), "asset loader prewarm should load the result background")
	_expect(bool(status.get("scroll_texture", false)), "asset loader prewarm should load the result scroll texture")
	_expect(bool(status.get("dalji_click_voice", false)), "asset loader prewarm should load the Dalji click voice")
	_expect(bool(status.get("result_box_fx", false)), "asset loader prewarm should cover result box FX")


func _verify_texture_bundle_load() -> void:
	var textures: Dictionary = StageClearResultAssetLoader.load_textures({}, _asset_paths())
	for key in StageClearResultAssetLoader.TEXTURE_KEYS:
		_expect(textures.get(str(key), null) is Texture2D, "asset loader should load texture key %s" % str(key))
	var stage2_sheet := textures.get("stage2_boss_defeat_live2d_sheet") as Texture2D
	_expect(
		stage2_sheet != null and stage2_sheet.get_size() == Vector2(16128.0, 8064.0),
		"asset loader should load the Real-ESRGAN hq1152 Stage 2 boss result Live2D sheet"
	)
	var stage2_click_sheet := textures.get("stage2_boss_defeat_click_reaction_sheet") as Texture2D
	_expect(
		stage2_click_sheet != null and stage2_click_sheet.get_size() == Vector2(16128.0, 8064.0),
		"asset loader should load the Real-ESRGAN hq1152 Stage 2 boss result click Live2D sheet"
	)
	var commando_paths: Dictionary = StageClearResultScene._result_asset_paths("soldier")
	_expect(
		str(commando_paths.get("player_victory_sheet", "")) == StageClearResultScene.COMMANDO_VICTORY_SHEET_PATH,
		"result asset paths should route Commando player victories to the Commando result Live2D base sheet"
	)
	_expect(
		str(commando_paths.get("player_victory_click_reaction_sheet", "")) == StageClearResultScene.COMMANDO_CLICK_REACTION_SHEET_PATH,
		"result asset paths should route Commando player victory clicks to the Commando result Live2D reaction sheet"
	)
	var commando_textures: Dictionary = StageClearResultAssetLoader.load_textures({}, commando_paths)
	var commando_sheet := commando_textures.get("player_victory_sheet") as Texture2D
	_expect(
		commando_sheet != null and commando_sheet.get_size() == Vector2(15488.0, 12672.0),
		"asset loader should load the Commando result base Live2D hq1408 11x9 sheet"
	)
	var commando_click_sheet := commando_textures.get("player_victory_click_reaction_sheet") as Texture2D
	_expect(
		commando_click_sheet != null and commando_click_sheet.get_size() == Vector2(15488.0, 12672.0),
		"asset loader should load the Commando result click Live2D hq1408 11x9 sheet"
	)


func _verify_audio_load() -> void:
	var stream: AudioStream = StageClearResultAssetLoader.load_dalji_click_voice(null, StageClearResultScene.DALJI_CLICK_VOICE_PATH)
	_expect(stream != null, "asset loader should load Dalji click voice stream")
	_expect(StageClearResultAssetLoader.load_dalji_click_voice(stream, StageClearResultScene.DALJI_CLICK_VOICE_PATH) == stream, "asset loader should preserve an existing voice stream")


func _verify_scene_delegates_asset_loading() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(
		source.find("StageClearResultAssetLoader.load_textures") >= 0
		and source.find("StageClearResultAssetLoader.load_dalji_click_voice") >= 0
		and source.find("StageClearResultAssetLoader.prewarm_assets_step") >= 0,
		"result scene should delegate asset loading and staged prewarm to the asset loader"
	)
	_expect(
		source.find("ProjectResourceLoader.load_texture") < 0
		and source.find("ProjectResourceLoader.load_audio_stream") < 0,
		"result scene should not keep direct project resource loader calls"
	)


func _verify_threaded_prewarm_keeps_stale_loads_off_main_thread() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/resources/project_resource_loader.gd").replace("\r\n", "\n")
	_expect(
		source.find("_push_threaded_texture_prewarm_stale_warning()") >= 0
		and source.find("keeping it off the main thread") >= 0,
		"threaded texture prewarm should keep slow result sheets on the threaded path"
	)
	_expect(
		source.find("_is_threaded_texture_prewarm_stale():\n\t\t_clear_threaded_texture_prewarm()") < 0,
		"slow threaded result texture prewarm should not clear into a synchronous load fallback"
	)


func _verify_result_box_polygon_colors() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(
		source.find("PackedColorArray([tint, tint, tint, tint])") >= 0
		and source.find("draw_polygon(quad, colors, uv_array, texture)") >= 0,
		"result box sheet draw should tint all four polygon vertices so the textured box renders in export builds"
	)


func _asset_paths() -> Dictionary:
	return {
		"background_texture": StageClearResultScene.STAGE1_BACKGROUND_PATH,
		"dalji_defeat_sheet": StageClearResultScene.DALJI_DEFEAT_SHEET_PATH,
		"dalji_click_reaction_sheet": StageClearResultScene.DALJI_CLICK_REACTION_SHEET_PATH,
		"stage2_boss_defeat_live2d_sheet": StageClearResultScene.STAGE2_BOSS_DEFEAT_LIVE2D_SHEET_PATH,
		"stage2_boss_defeat_click_reaction_sheet": StageClearResultScene.STAGE2_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH,
		"player_victory_sheet": StageClearResultScene.SMASHER_VICTORY_SHEET_PATH,
		"player_victory_click_reaction_sheet": StageClearResultScene.SMASHER_CLICK_REACTION_SHEET_PATH,
		"scroll_texture": StageClearResultScene.RESULT_SCROLL_PANEL_PATH,
		"result_box_sheet_common": StageClearResultScene.RESULT_BOX_SHEET_COMMON_PATH,
		"result_box_sheet_mythic": StageClearResultScene.RESULT_BOX_SHEET_MYTHIC_PATH,
		"result_box_sheet_guaranteed_mythic": StageClearResultScene.RESULT_BOX_SHEET_GUARANTEED_MYTHIC_PATH,
		"dalji_click_voice": StageClearResultScene.DALJI_CLICK_VOICE_PATH,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
