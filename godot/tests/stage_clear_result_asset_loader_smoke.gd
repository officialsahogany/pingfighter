extends SceneTree

const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_prewarm_steps()
	_verify_texture_bundle_load()
	_verify_audio_load()
	_verify_scene_delegates_asset_loading()
	_verify_threaded_prewarm_uses_short_default_guard()
	_verify_result_box_export_safe_texture_path()
	_verify_result_box_texture_region_draw()

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
	StageClearResultAssetLoader.reset_result_prewarm_assets_for_test()
	var calls := 0
	while not StageClearResultAssetLoader.prewarm_result_assets_step(_asset_paths(), "smasher", 1):
		calls += 1
		_expect(calls <= StageClearResultAssetLoader.PREWARM_ASSET_STEP_COUNT, "asset loader result prewarm should complete within the declared budget")
	var result_status: Dictionary = StageClearResultAssetLoader.get_result_prewarm_asset_status()
	_expect(str(result_status.get("selected_character_type", "")) == "smasher", "asset loader should own selected-character prewarm state")
	_expect(int(result_status.get("current_stage", 0)) == 1, "asset loader should own stage prewarm state")
	_expect(bool(result_status.get("background_texture", false)), "asset loader stateful prewarm should load the result background")


func _verify_texture_bundle_load() -> void:
	var textures: Dictionary = StageClearResultAssetLoader.load_textures({}, _asset_paths())
	for key in StageClearResultAssetLoader.TEXTURE_KEYS:
		_expect(textures.get(str(key), null) is Texture2D, "asset loader should load texture key %s" % str(key))
	var stage2_sheet := textures.get("stage2_boss_defeat_live2d_sheet") as Texture2D
	_expect(
		stage2_sheet != null and stage2_sheet.get_size() == Vector2(12544.0, 6272.0),
		"asset loader should load the Real-ESRGAN hq1152 Stage 2 boss result Live2D sheet"
	)
	var stage2_click_sheet := textures.get("stage2_boss_defeat_click_reaction_sheet") as Texture2D
	_expect(
		stage2_click_sheet != null and stage2_click_sheet.get_size() == Vector2(12544.0, 6272.0),
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
		commando_sheet != null and commando_sheet.get_size() == Vector2(9856.0, 8064.0),
		"asset loader should load the Commando result base Live2D hq1408 11x9 sheet"
	)
	var commando_click_sheet := commando_textures.get("player_victory_click_reaction_sheet") as Texture2D
	_expect(
		commando_click_sheet != null and commando_click_sheet.get_size() == Vector2(9856.0, 8064.0),
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
		and source.find("StageClearResultAssetLoader.prewarm_result_assets_step") >= 0,
		"result scene should delegate asset loading and staged prewarm to the asset loader"
	)
	_expect(
		source.find("ProjectResourceLoader.load_texture") < 0
		and source.find("ProjectResourceLoader.load_audio_stream") < 0,
		"result scene should not keep direct project resource loader calls"
	)
	_expect(
		source.find("static var _prewarm_asset") < 0
			and source.find("static func _prewarm_assets_step_impl") < 0,
		"result scene should not keep stateful prewarm implementation details"
	)


func _verify_threaded_prewarm_uses_short_default_guard() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/resources/project_resource_loader.gd").replace("\r\n", "\n")
	_expect(
		ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_MSEC <= 3000
			and ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_POLLS <= 600,
		"threaded texture prewarm default guard should stay short for loading-screen result sheets"
	)
	_expect(
		source.find("emit_timeout_warning: bool = false") >= 0
			and source.find("if emit_timeout_warning:") >= 0,
		"threaded texture prewarm should silently recover by default and keep warnings opt-in"
	)


func _verify_result_box_export_safe_texture_path() -> void:
	for key in [
		"result_box_sheet_common",
		"result_box_sheet_mythic",
		"result_box_sheet_guaranteed_mythic",
	]:
		_expect(
			StageClearResultAssetLoader._prefers_imported_texture(key),
			"%s should prefer imported texture loading so exported builds do not drop result box sheets" % key
		)


func _verify_result_box_texture_region_draw() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var box_helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_draw_helper.gd")
	_expect(
		source.find("draw_set_transform(draw_center, box_rotation, Vector2.ONE)") >= 0
		and source.find("draw_texture_rect_region(") >= 0
		and source.find("StageClearResultBoxDrawHelper.draw_result_box_fallback") >= 0
		and box_helper_source.find("static func draw_result_box_fallback") >= 0,
		"result box sheet draw should use texture-region drawing with an export-safe fallback"
	)


func _asset_paths() -> Dictionary:
	return {
		"background_texture": StageClearResultScene.STAGE1_BACKGROUND_PATH,
		"dalji_defeat_sheet": StageClearResultScene.DALJI_DEFEAT_SHEET_PATH,
		"dalji_click_reaction_sheet": StageClearResultScene.DALJI_CLICK_REACTION_SHEET_PATH,
		"stage2_boss_defeat_live2d_sheet": StageClearResultScene.STAGE2_BOSS_DEFEAT_LIVE2D_SHEET_PATH,
		"stage2_boss_defeat_click_reaction_sheet": StageClearResultScene.STAGE2_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH,
		"stage3_boss_defeat_live2d_sheet": StageClearResultScene.STAGE3_BOSS_DEFEAT_LIVE2D_SHEET_PATH,
		"stage3_boss_defeat_click_reaction_sheet": StageClearResultScene.STAGE3_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH,
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
