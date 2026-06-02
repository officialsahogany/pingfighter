extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ResultBoxOpenFxHost := preload("res://scripts/effects/result_box_open_fx_host.gd")

const PREWARM_ASSET_STEP_COUNT := 13
const TEXTURE_KEYS := [
	"background_texture",
	"dalji_defeat_sheet",
	"dalji_click_reaction_sheet",
	"stage2_boss_defeat_live2d_sheet",
	"stage2_boss_defeat_click_reaction_sheet",
	"player_victory_sheet",
	"player_victory_click_reaction_sheet",
	"scroll_texture",
	"result_box_sheet_common",
	"result_box_sheet_mythic",
	"result_box_sheet_guaranteed_mythic",
]

const IMPORT_PREFERRED_TEXTURE_KEYS := {
	"dalji_defeat_sheet": true,
	"dalji_click_reaction_sheet": true,
	"stage2_boss_defeat_live2d_sheet": true,
	"stage2_boss_defeat_click_reaction_sheet": true,
	"player_victory_sheet": true,
	"player_victory_click_reaction_sheet": true,
	"result_box_sheet_common": true,
	"result_box_sheet_mythic": true,
	"result_box_sheet_guaranteed_mythic": true,
}

const TEXTURE_MESSAGES := {
	"background_texture": ["Missing Stage 1 result background at %s", "Failed to load Stage 1 result background at %s"],
	"dalji_defeat_sheet": ["Missing Dalji result defeat sheet at %s", "Failed to load Dalji result defeat sheet at %s"],
	"dalji_click_reaction_sheet": ["Missing Dalji result click reaction sheet at %s", "Failed to load Dalji result click reaction sheet at %s"],
	"stage2_boss_defeat_live2d_sheet": ["Missing Stage 2 boss result defeat Live2D sheet at %s", "Failed to load Stage 2 boss result defeat Live2D sheet at %s"],
	"stage2_boss_defeat_click_reaction_sheet": ["Missing Stage 2 boss result click reaction Live2D sheet at %s", "Failed to load Stage 2 boss result click reaction Live2D sheet at %s"],
	"player_victory_sheet": ["Missing player victory sheet at %s", "Failed to load player victory sheet at %s"],
	"player_victory_click_reaction_sheet": ["Missing player victory click reaction sheet at %s", "Failed to load player victory click reaction sheet at %s"],
	"scroll_texture": ["Missing stage clear cyber scroll panel at %s", "Failed to load stage clear cyber scroll panel at %s"],
	"result_box_sheet_common": ["Missing result box common sheet at %s", "Failed to load result box common sheet at %s"],
	"result_box_sheet_mythic": ["Missing result box mythic sheet at %s", "Failed to load result box mythic sheet at %s"],
	"result_box_sheet_guaranteed_mythic": ["Missing guaranteed mythic result box sheet at %s", "Failed to load guaranteed mythic result box sheet at %s"],
}


static func load_textures(current: Dictionary, paths: Dictionary) -> Dictionary:
	var loaded: Dictionary = current.duplicate()
	for key_value in TEXTURE_KEYS:
		var key: String = str(key_value)
		if loaded.get(key, null) != null:
			continue
		var path: String = str(paths.get(key, ""))
		if path == "":
			loaded.erase(key)
			continue
		var messages: Array = TEXTURE_MESSAGES.get(key, ["", ""])
		loaded[key] = _load_texture_for_key(key, path, str(messages[0]), str(messages[1]))
	return loaded


static func load_dalji_click_voice(current: AudioStream, path: String) -> AudioStream:
	if current != null:
		return current
	return ProjectResourceLoader.load_audio_stream(
		path,
		"Missing Dalji result click cry voice at %s",
		"Failed to load Dalji result click cry voice at %s"
	)


static func prewarm_assets_step(
	step_index: int,
	status: Dictionary,
	paths: Dictionary,
	use_threaded_texture_loads: bool = false
) -> bool:
	if step_index >= 0 and step_index < TEXTURE_KEYS.size():
		var texture_key: String = str(TEXTURE_KEYS[step_index])
		var path: String = str(paths.get(texture_key, ""))
		if path == "":
			status.erase(texture_key)
			return true
		if use_threaded_texture_loads:
			var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(
				path,
				"",
				"",
				ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_MSEC,
				ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_POLLS,
				false,
				_prefers_imported_texture(texture_key)
			)
			if not bool(result.get("done", true)):
				return false
			status[texture_key] = result.get("texture", null) is Texture2D
		else:
			status[texture_key] = _load_texture_for_key(texture_key, path) != null
		return true
	if step_index == TEXTURE_KEYS.size():
		var voice_path: String = str(paths.get("dalji_click_voice", ""))
		if voice_path == "":
			status.erase("dalji_click_voice")
			return true
		status["dalji_click_voice"] = ProjectResourceLoader.load_audio_stream(voice_path) != null
		return true
	if step_index == TEXTURE_KEYS.size() + 1:
		ResultBoxOpenFxHost.prewarm_assets()
		status["result_box_fx"] = true
	return true


static func _load_texture_for_key(
	key: String,
	path: String,
	missing_warning: String = "",
	failed_warning: String = ""
) -> Texture2D:
	if _prefers_imported_texture(key):
		return ProjectResourceLoader.load_imported_texture(path, missing_warning, failed_warning)
	return ProjectResourceLoader.load_texture(path, missing_warning, failed_warning)


static func _prefers_imported_texture(key: String) -> bool:
	return bool(IMPORT_PREFERRED_TEXTURE_KEYS.get(key, false))
