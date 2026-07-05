extends SceneTree

const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_prewarm_steps()
	_verify_texture_bundle_load()
	_verify_asset_path_resolution()
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
	var commando_paths: Dictionary = StageClearResultAssetLoader.get_result_asset_paths("soldier", 1)
	_expect(
		str(commando_paths.get("player_victory_sheet", "")) == StageClearResultAssetLoader.COMMANDO_VICTORY_SHEET_PATH,
		"result asset paths should route Commando player victories to the Commando result Live2D base sheet"
	)
	_expect(
		str(commando_paths.get("player_victory_click_reaction_sheet", "")) == StageClearResultAssetLoader.COMMANDO_CLICK_REACTION_SHEET_PATH,
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
	var optimus_paths: Dictionary = StageClearResultAssetLoader.get_result_asset_paths("optimus", 1)
	_expect(
		str(optimus_paths.get("player_victory_sheet", "")) == StageClearResultAssetLoader.OPTIMUS_VICTORY_SHEET_PATH,
		"result asset paths should route Optimus player victories to the Optimus result Live2D base sheet"
	)
	_expect(
		str(optimus_paths.get("player_victory_click_reaction_sheet", "")) == StageClearResultAssetLoader.OPTIMUS_CLICK_REACTION_SHEET_PATH,
		"result asset paths should route Optimus player victory clicks to the Optimus result Live2D reaction sheet"
	)
	var optimus_textures: Dictionary = StageClearResultAssetLoader.load_textures({}, optimus_paths)
	var optimus_sheet := optimus_textures.get("player_victory_sheet") as Texture2D
	_expect(
		optimus_sheet != null and optimus_sheet.get_size() == Vector2(9856.0, 8064.0),
		"asset loader should load the Optimus result base Live2D xfit67 11x9 sheet"
	)
	var optimus_click_sheet := optimus_textures.get("player_victory_click_reaction_sheet") as Texture2D
	_expect(
		optimus_click_sheet != null and optimus_click_sheet.get_size() == Vector2(9856.0, 8064.0),
		"asset loader should load the Optimus result click Live2D xfit67 11x9 sheet"
	)


func _verify_asset_path_resolution() -> void:
	var path_config: Dictionary = StageClearResultAssetLoader.get_default_result_asset_path_config()
	_expect(str(path_config.get("background_texture", "")) == StageClearResultAssetLoader.STAGE1_BACKGROUND_PATH, "asset loader should own the default result background path config")
	_expect(str(path_config.get("stage2_background_texture", "")) == StageClearResultAssetLoader.STAGE2_BACKGROUND_PATH, "asset loader should own the Stage 2 result background path config")
	_expect(str(path_config.get("stage3_background_texture", "")) == StageClearResultAssetLoader.STAGE3_BACKGROUND_PATH, "asset loader should own the Stage 3 result background path config")
	_expect(str(path_config.get("stage4_background_texture", "")) == StageClearResultAssetLoader.STAGE4_BACKGROUND_PATH, "asset loader should own the Stage 4 Ponk result background path config")
	_expect(str(path_config.get("stage4_ponk_boss_defeat_live2d_sheet", "")) == StageClearResultAssetLoader.STAGE4_PONK_BOSS_DEFEAT_LIVE2D_SHEET_PATH, "asset loader should own the Stage 4 Ponk result defeat Live2D sheet path config")
	_expect(str(path_config.get("stage4_ponk_boss_defeat_click_reaction_sheet", "")) == StageClearResultAssetLoader.STAGE4_PONK_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH, "asset loader should own the Stage 4 Ponk result click Live2D sheet path config")
	_expect(str(path_config.get("stage5_background_texture", "")) == StageClearResultAssetLoader.STAGE5_BACKGROUND_PATH, "asset loader should own the Stage 5 Hongryun result background path config")
	_expect(str(path_config.get("stage5_hongryun_result_sheet", "")) == StageClearResultAssetLoader.STAGE5_HONGRYUN_RESULT_SHEET_PATH, "asset loader should own the Stage 5 Hongryun result fallback sheet path config")
	_expect(str(path_config.get("stage6_background_texture", "")) == StageClearResultAssetLoader.STAGE6_BACKGROUND_PATH, "asset loader should own the Stage 6 Tetriser result background path config")
	_expect(str(path_config.get("stage6_boss_defeat_sheet", "")) == StageClearResultAssetLoader.STAGE6_BOSS_DEFEAT_SHEET_PATH, "asset loader should own the Stage 6 Tetriser result defeat sheet path config")
	_expect(StageClearResultAssetLoader.normalize_player_victory_character_type(" Commando ") == "soldier", "asset loader should normalize Commando result character ids")
	_expect(StageClearResultAssetLoader.normalize_player_victory_character_type("io") == "optimus", "asset loader should normalize Optimus result character aliases")
	_expect(StageClearResultAssetLoader.normalize_player_victory_character_type("kohaku") == "smasher", "asset loader should default unsupported dedicated result characters to Smasher")
	_expect(StageClearResultAssetLoader.normalize_player_victory_character_type("unknown") == "smasher", "asset loader should default unknown result character ids to Smasher")
	var commando_paths: Dictionary = StageClearResultAssetLoader.get_result_asset_paths("commando", 1)
	_expect(
		str(commando_paths.get("player_victory_sheet", "")) == StageClearResultAssetLoader.COMMANDO_VICTORY_SHEET_PATH,
		"asset loader should route Commando player victories to the Commando result Live2D base sheet"
	)
	_expect(
		str(commando_paths.get("player_victory_click_reaction_sheet", "")) == StageClearResultAssetLoader.COMMANDO_CLICK_REACTION_SHEET_PATH,
		"asset loader should route Commando player victory clicks to the Commando result Live2D reaction sheet"
	)
	var optimus_paths: Dictionary = StageClearResultAssetLoader.get_result_asset_paths("io", 1)
	_expect(
		str(optimus_paths.get("player_victory_sheet", "")) == StageClearResultAssetLoader.OPTIMUS_VICTORY_SHEET_PATH,
		"asset loader should route Io aliases to the Optimus result Live2D base sheet"
	)
	_expect(
		str(optimus_paths.get("player_victory_click_reaction_sheet", "")) == StageClearResultAssetLoader.OPTIMUS_CLICK_REACTION_SHEET_PATH,
		"asset loader should route Io aliases to the Optimus result click Live2D reaction sheet"
	)
	var stage2_paths: Dictionary = StageClearResultAssetLoader.get_result_asset_paths("smasher", 2)
	_expect(str(stage2_paths.get("background_texture", "")) == StageClearResultAssetLoader.STAGE2_BACKGROUND_PATH, "Stage 2 result paths should use the jungle relic result background")
	_expect(stage2_paths.has("stage2_boss_defeat_live2d_sheet"), "asset loader should include Stage 2 defeated boss sheets for Stage 2")
	_expect(not stage2_paths.has("dalji_defeat_sheet"), "asset loader should omit Dalji sheets outside Stage 1 result paths")
	var stage2_textures: Dictionary = StageClearResultAssetLoader.load_textures({}, stage2_paths)
	var stage2_background := stage2_textures.get("background_texture") as Texture2D
	_expect(
		stage2_background != null and stage2_background.get_size() == Vector2(1672.0, 941.0),
		"Stage 2 result background should load the jungle relic result texture"
	)
	var stage3_paths: Dictionary = StageClearResultAssetLoader.get_result_asset_paths("smasher", 3)
	_expect(str(stage3_paths.get("background_texture", "")) == StageClearResultAssetLoader.STAGE3_BACKGROUND_PATH, "Stage 3 result paths should use the neon arcade result background")
	_expect(stage3_paths.has("stage3_boss_defeat_live2d_sheet"), "asset loader should include Stage 3 defeated boss sheets for Stage 3")
	_expect(not stage3_paths.has("dalji_defeat_sheet"), "Stage 3 result paths should not fall back to the Dalji defeated boss sheet")
	var stage3_textures: Dictionary = StageClearResultAssetLoader.load_textures({}, stage3_paths)
	var stage3_background := stage3_textures.get("background_texture") as Texture2D
	_expect(
		stage3_background != null and stage3_background.get_size() == Vector2(1672.0, 941.0),
		"Stage 3 result background should load the neon arcade result texture"
	)
	var stage4_paths: Dictionary = StageClearResultAssetLoader.get_result_asset_paths("smasher", 4)
	_expect(str(stage4_paths.get("background_texture", "")) == StageClearResultAssetLoader.STAGE4_BACKGROUND_PATH, "Stage 4 result paths should use the Ponk result background")
	_expect(str(stage4_paths.get("stage4_ponk_boss_defeat_live2d_sheet", "")) == StageClearResultAssetLoader.STAGE4_PONK_BOSS_DEFEAT_LIVE2D_SHEET_PATH, "Stage 4 result paths should use the masked Ponk Live2D defeat sheet")
	_expect(str(stage4_paths.get("stage4_ponk_boss_defeat_click_reaction_sheet", "")) == StageClearResultAssetLoader.STAGE4_PONK_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH, "Stage 4 result paths should use the masked Ponk click reaction sheet")
	_expect(not stage4_paths.has("dalji_defeat_sheet"), "Stage 4 result paths should not fall back to the Dalji defeated boss sheet")
	_expect(not stage4_paths.has("stage4_ponk_result_sheet"), "Stage 4 result paths should not route through the old Ponk fallback sheet")
	_expect(not stage4_paths.has("stage6_boss_defeat_sheet"), "Stage 4 result paths should not include the Stage 6 Tetriser boss sheet")
	var stage4_textures: Dictionary = StageClearResultAssetLoader.load_textures({}, stage4_paths)
	var stage4_background := stage4_textures.get("background_texture") as Texture2D
	_expect(
		stage4_background != null and stage4_background.get_size() == Vector2(1672.0, 941.0),
		"Stage 4 result background should load the moonlit prism temple result texture"
	)
	var stage4_ponk_sheet := stage4_textures.get("stage4_ponk_boss_defeat_live2d_sheet") as Texture2D
	_expect(
		stage4_ponk_sheet != null and stage4_ponk_sheet.get_size() == Vector2(12544.0, 6272.0),
		"Stage 4 Ponk result Live2D sheet should load the hq1152 14x7 sheet capped to 896px cells"
	)
	var stage4_ponk_click_sheet := stage4_textures.get("stage4_ponk_boss_defeat_click_reaction_sheet") as Texture2D
	_expect(
		stage4_ponk_click_sheet != null and stage4_ponk_click_sheet.get_size() == Vector2(12544.0, 6272.0),
		"Stage 4 Ponk result click Live2D sheet should load the hq1152 14x7 sheet capped to 896px cells"
	)
	var stage5_paths: Dictionary = StageClearResultAssetLoader.get_result_asset_paths("smasher", 5)
	_expect(str(stage5_paths.get("background_texture", "")) == StageClearResultAssetLoader.STAGE5_BACKGROUND_PATH, "Stage 5 result paths should use the Hongryun result background")
	_expect(str(stage5_paths.get("stage5_hongryun_result_sheet", "")) == StageClearResultAssetLoader.STAGE5_HONGRYUN_RESULT_SHEET_PATH, "Stage 5 result paths should use the Hongryun fallback result sheet")
	_expect(not stage5_paths.has("dalji_defeat_sheet"), "Stage 5 result paths should not fall back to the Dalji defeated boss sheet")
	_expect(not stage5_paths.has("stage6_boss_defeat_sheet"), "Stage 5 result paths should not include the Stage 6 Tetriser boss sheet")
	var stage5_textures: Dictionary = StageClearResultAssetLoader.load_textures({}, stage5_paths)
	var stage5_background := stage5_textures.get("background_texture") as Texture2D
	_expect(
		stage5_background != null and stage5_background.get_size() == Vector2(1672.0, 941.0),
		"Stage 5 result background should load the Hongryun crimson palace result texture"
	)
	var stage5_hongryun_sheet := stage5_textures.get("stage5_hongryun_result_sheet") as Texture2D
	_expect(
		stage5_hongryun_sheet != null and stage5_hongryun_sheet.get_size() == Vector2(1536.0, 768.0),
		"Stage 5 Hongryun result fallback sheet should load the 4x2 victory sheet"
	)
	var stage6_paths: Dictionary = StageClearResultAssetLoader.get_result_asset_paths("smasher", 6)
	_expect(str(stage6_paths.get("background_texture", "")) == StageClearResultAssetLoader.STAGE6_BACKGROUND_PATH, "Stage 6 result paths should use the Tetriser result background")
	_expect(str(stage6_paths.get("stage6_boss_defeat_sheet", "")) == StageClearResultAssetLoader.STAGE6_BOSS_DEFEAT_SHEET_PATH, "Stage 6 result paths should use the Tetriser boss defeat sheet")
	_expect(not stage6_paths.has("dalji_defeat_sheet"), "Stage 6 result paths should not fall back to the Dalji defeated boss sheet")
	_expect(not stage6_paths.has("dalji_click_reaction_sheet"), "Stage 6 result paths should not fall back to the Dalji click reaction sheet")
	var stage6_textures: Dictionary = StageClearResultAssetLoader.load_textures({}, stage6_paths)
	var stage6_background := stage6_textures.get("background_texture") as Texture2D
	_expect(stage6_background != null, "Stage 6 result background should load as a Texture2D")
	var stage6_defeat_sheet := stage6_textures.get("stage6_boss_defeat_sheet") as Texture2D
	_expect(
		stage6_defeat_sheet != null and stage6_defeat_sheet.get_size() == Vector2(768.0, 768.0),
		"Stage 6 result defeat sheet should load the 3x3 Tetriser boss sheet"
	)


func _verify_audio_load() -> void:
	var stream: AudioStream = StageClearResultAssetLoader.load_dalji_click_voice(null, StageClearResultAssetLoader.DALJI_CLICK_VOICE_PATH)
	_expect(stream != null, "asset loader should load Dalji click voice stream")
	_expect(StageClearResultAssetLoader.load_dalji_click_voice(stream, StageClearResultAssetLoader.DALJI_CLICK_VOICE_PATH) == stream, "asset loader should preserve an existing voice stream")


func _verify_scene_delegates_asset_loading() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var config_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
	var apply_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_asset_apply_handler.gd")
	var audio_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_audio_scene_handler.gd")
	var audio_apply_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_audio_apply_handler.gd")
	var character_asset_state_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_character_asset_state_handler.gd")
	_expect(
		source.find("func configure(") < 0
		and config_scene_handler_source.find("static func configure") >= 0
		and config_scene_handler_source.find("static func load_textures") >= 0
		and config_scene_handler_source.find("StageClearResultAssetApplyHandler.load_texture_fields") >= 0
		and apply_handler_source.find("StageClearResultAssetLoader.load_textures") >= 0
		and apply_handler_source.find("StageClearResultAssetLoader.get_result_asset_paths") >= 0
		and config_scene_handler_source.find("StageClearResultCharacterAssetStateHandler.get_character_asset_state") >= 0
		and character_asset_state_source.find("StageClearResultAssetLoader.normalize_player_victory_character_type") >= 0
		and config_scene_handler_source.find("StageClearResultAudioSceneHandler.load_audio") >= 0
		and audio_scene_handler_source.find("StageClearResultAudioApplyHandler.load_dalji_click_voice_stream") >= 0
		and audio_apply_handler_source.find("StageClearResultAssetLoader.load_dalji_click_voice") >= 0
		and source.find("static func prewarm_assets_step") < 0
		and config_scene_handler_source.find("static func prewarm_assets_step") >= 0
		and config_scene_handler_source.find("StageClearResultAssetLoader.prewarm_result_assets_step") >= 0
		and config_scene_handler_source.find("StageClearResultAssetLoader.get_result_asset_paths") >= 0,
		"config scene handler should own configure, staged prewarm, and audio while the result scene stays free of config wrappers"
	)
	_expect(
		source.find("static func _result_asset_path_config") < 0,
		"result scene should not keep result asset path config assembly"
	)
	_expect(
		source.find("const PREWARM_ASSET_STEP_COUNT") < 0,
		"result scene should not mirror the asset loader prewarm step budget"
	)
	_expect(
		source.find("ProjectResourceLoader.load_texture") < 0
		and source.find("ProjectResourceLoader.load_audio_stream") < 0,
		"result scene should not keep direct project resource loader calls"
	)
	_expect(
		source.find("for key_value in StageClearResultAssetLoader.TEXTURE_KEYS") < 0,
		"result scene should not keep texture-key field application loops"
	)
	_expect(
		source.find("StageClearResultAssetLoader.load_dalji_click_voice") < 0,
		"result scene should not load Dalji click voice streams directly"
	)
	_expect(
		source.find("StageClearResultAssetLoader.prewarm_result_assets_step") < 0
			and source.find("StageClearResultAssetLoader.get_result_asset_paths") < 0,
		"result scene should route staged prewarm through config scene glue"
	)
	_expect(
		source.find("static var _prewarm_asset") < 0
			and source.find("static func _prewarm_assets_step_impl") < 0,
		"result scene should not keep stateful prewarm implementation details"
	)
	_expect(
		source.find("static func _normalize_player_victory_character_type") < 0
			and source.find("static func _get_player_victory_sheet_path_for_character") < 0
			and source.find("static func _get_player_victory_click_reaction_sheet_path_for_character") < 0,
		"result scene should not keep asset path resolution helpers"
	)
	_expect(
		source.find("var previous_character_type") < 0,
		"result scene should not keep configure-time character cache invalidation inline"
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
	var draw_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_draw_scene_handler.gd")
	var box_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_scene_handler.gd")
	var box_presenter_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_presenter.gd")
	var box_helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_draw_helper.gd")
	_expect(
		source.find("StageClearResultDrawSceneHandler.draw_result_scene") >= 0
		and draw_scene_handler_source.find("StageClearResultBoxSceneHandler.draw_floating_boxes") >= 0
		and box_scene_handler_source.find("StageClearResultBoxPresenter.draw_floating_boxes") >= 0
		and box_presenter_source.find("StageClearResultBoxDrawHelper.draw_floating_result_box") >= 0
		and box_helper_source.find("draw_result_box_sheet_frame") >= 0
		and box_helper_source.find("draw_set_transform(draw_center, box_rotation, Vector2.ONE)") >= 0
		and box_helper_source.find("draw_texture_rect_region(") >= 0
		and box_helper_source.find("static func draw_result_box_fallback") >= 0,
		"result box sheet draw should use texture-region drawing with an export-safe fallback"
	)


func _asset_paths() -> Dictionary:
	return {
		"background_texture": StageClearResultAssetLoader.STAGE1_BACKGROUND_PATH,
		"dalji_defeat_sheet": StageClearResultAssetLoader.DALJI_DEFEAT_SHEET_PATH,
		"dalji_click_reaction_sheet": StageClearResultAssetLoader.DALJI_CLICK_REACTION_SHEET_PATH,
		"stage2_boss_defeat_live2d_sheet": StageClearResultAssetLoader.STAGE2_BOSS_DEFEAT_LIVE2D_SHEET_PATH,
		"stage2_boss_defeat_click_reaction_sheet": StageClearResultAssetLoader.STAGE2_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH,
		"stage3_boss_defeat_live2d_sheet": StageClearResultAssetLoader.STAGE3_BOSS_DEFEAT_LIVE2D_SHEET_PATH,
		"stage3_boss_defeat_click_reaction_sheet": StageClearResultAssetLoader.STAGE3_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH,
		"stage4_ponk_boss_defeat_live2d_sheet": StageClearResultAssetLoader.STAGE4_PONK_BOSS_DEFEAT_LIVE2D_SHEET_PATH,
		"stage4_ponk_boss_defeat_click_reaction_sheet": StageClearResultAssetLoader.STAGE4_PONK_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH,
		"stage5_hongryun_result_sheet": StageClearResultAssetLoader.STAGE5_HONGRYUN_RESULT_SHEET_PATH,
		"stage6_boss_defeat_sheet": StageClearResultAssetLoader.STAGE6_BOSS_DEFEAT_SHEET_PATH,
		"player_victory_sheet": StageClearResultAssetLoader.SMASHER_VICTORY_SHEET_PATH,
		"player_victory_click_reaction_sheet": StageClearResultAssetLoader.SMASHER_CLICK_REACTION_SHEET_PATH,
		"scroll_texture": StageClearResultAssetLoader.RESULT_SCROLL_PANEL_PATH,
		"result_box_sheet_common": StageClearResultAssetLoader.RESULT_BOX_SHEET_COMMON_PATH,
		"result_box_sheet_mythic": StageClearResultAssetLoader.RESULT_BOX_SHEET_MYTHIC_PATH,
		"result_box_sheet_guaranteed_mythic": StageClearResultAssetLoader.RESULT_BOX_SHEET_GUARANTEED_MYTHIC_PATH,
		"dalji_click_voice": StageClearResultAssetLoader.DALJI_CLICK_VOICE_PATH,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
