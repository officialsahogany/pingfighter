extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ResultBoxOpenFxHost := preload("res://scripts/effects/result_box_open_fx_host.gd")

const STAGE1_BACKGROUND_PATH := "res://assets/sprites/stage1/result/stage1_result_background_imagegen_v1.png"
const DALJI_DEFEAT_SHEET_PATH := "res://assets/sprites/stage1/dalji/dalji_result_defeat_cutscene_live2d_clean_anchor_pingpong_98f_autosprite_v6_realesrgan_animev3_hq1152_safe.png"
const DALJI_CLICK_REACTION_SHEET_PATH := "res://assets/sprites/stage1/dalji/dalji_result_click_cry_dont_talk_live2d_remake_pingpong_98f_autosprite_v6_realesrgan_animev3_hq1152_safe.png"
const DALJI_CLICK_VOICE_PATH := "res://voice/dalzidefeat.mp3"
const STAGE2_BOSS_DEFEAT_LIVE2D_SHEET_PATH := "res://assets/sprites/stage2/stage2_alligator_general_result_defeat_live2d_pingpong_98f_autosprite_v2_realesrgan_animev3_hq1152.png"
const STAGE2_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH := "res://assets/sprites/stage2/stage2_alligator_general_result_defeat_click_reaction_98f_autosprite_v1_realesrgan_animev3_hq1152.png"
const STAGE3_BOSS_DEFEAT_LIVE2D_SHEET_PATH := "res://assets/sprites/stage3/menhera_result_defeat_live2d_pingpong_98f_autosprite_v1_realesrgan_animev3_hq1152.png"
const STAGE3_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH := "res://assets/sprites/stage3/menhera_result_defeat_click_reaction_98f_autosprite_v1_realesrgan_animev3_hq1152.png"
const SMASHER_VICTORY_SHEET_PATH := "res://assets/sprites/smasher/smasher_result_victory_base_loop_98f_autosprite_v18_magenta_v2_no_pet_realesrgan_animev3_hq1408.png"
const SMASHER_CLICK_REACTION_SHEET_PATH := "res://assets/sprites/smasher/smasher_result_victory_click_reaction_98f_autosprite_v18_magenta_v2_no_pet_realesrgan_animev3_hq1408.png"
const COMMANDO_VICTORY_SHEET_PATH := "res://assets/sprites/characters/commando/commando_result_victory_base_loop_98f_autosprite_v1_realesrgan_animev3_hq1408.png"
const COMMANDO_CLICK_REACTION_SHEET_PATH := "res://assets/sprites/characters/commando/commando_result_victory_click_reaction_98f_autosprite_v1_realesrgan_animev3_hq1408.png"
const OPTIMUS_VICTORY_SHEET_PATH := "res://assets/sprites/characters/optimus/optimus_io_result_victory_base_loop_98f_magenta_onebounce_autosprite_v5_realesrgan_animev3_hq896_safe.png"
const OPTIMUS_CLICK_REACTION_SHEET_PATH := "res://assets/sprites/characters/optimus/optimus_io_result_victory_click_talk_nozoom_98f_magenta_autosprite_v6_realesrgan_animev3_hq896_safe.png"
const RESULT_SCROLL_PANEL_PATH := "res://assets/sprites/result_scroll/stage_clear_cyber_scroll_imagegen_v1_alpha.png"
const RESULT_BOX_SHEET_COMMON_PATH := "res://assets/sprites/result_boxes/result_box_common_open_16f.png"
const RESULT_BOX_SHEET_MYTHIC_PATH := "res://assets/sprites/result_boxes/result_box_mythic_open_16f.png"
const RESULT_BOX_SHEET_GUARANTEED_MYTHIC_PATH := "res://assets/sprites/result_boxes/result_box_guaranteed_mythic_open_16f.png"

const PREWARM_ASSET_STEP_COUNT := 15
const TEXTURE_KEYS := [
	"background_texture",
	"dalji_defeat_sheet",
	"dalji_click_reaction_sheet",
	"stage2_boss_defeat_live2d_sheet",
	"stage2_boss_defeat_click_reaction_sheet",
	"stage3_boss_defeat_live2d_sheet",
	"stage3_boss_defeat_click_reaction_sheet",
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
	"stage3_boss_defeat_live2d_sheet": true,
	"stage3_boss_defeat_click_reaction_sheet": true,
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
	"stage3_boss_defeat_live2d_sheet": ["Missing Stage 3 boss result defeat Live2D sheet at %s", "Failed to load Stage 3 boss result defeat Live2D sheet at %s"],
	"stage3_boss_defeat_click_reaction_sheet": ["Missing Stage 3 boss result click reaction Live2D sheet at %s", "Failed to load Stage 3 boss result click reaction Live2D sheet at %s"],
	"player_victory_sheet": ["Missing player victory sheet at %s", "Failed to load player victory sheet at %s"],
	"player_victory_click_reaction_sheet": ["Missing player victory click reaction sheet at %s", "Failed to load player victory click reaction sheet at %s"],
	"scroll_texture": ["Missing stage clear cyber scroll panel at %s", "Failed to load stage clear cyber scroll panel at %s"],
	"result_box_sheet_common": ["Missing result box common sheet at %s", "Failed to load result box common sheet at %s"],
	"result_box_sheet_mythic": ["Missing result box mythic sheet at %s", "Failed to load result box mythic sheet at %s"],
	"result_box_sheet_guaranteed_mythic": ["Missing guaranteed mythic result box sheet at %s", "Failed to load guaranteed mythic result box sheet at %s"],
}

static var _prewarm_result_asset_step_index: int = 0
static var _prewarm_result_asset_status: Dictionary = {}
static var _prewarm_result_asset_character_type: String = "smasher"
static var _prewarm_result_asset_stage_id: int = 1


static func get_default_result_asset_path_config() -> Dictionary:
	return {
		"background_texture": STAGE1_BACKGROUND_PATH,
		"smasher_victory_sheet": SMASHER_VICTORY_SHEET_PATH,
		"smasher_click_reaction_sheet": SMASHER_CLICK_REACTION_SHEET_PATH,
		"commando_victory_sheet": COMMANDO_VICTORY_SHEET_PATH,
		"commando_click_reaction_sheet": COMMANDO_CLICK_REACTION_SHEET_PATH,
		"optimus_victory_sheet": OPTIMUS_VICTORY_SHEET_PATH,
		"optimus_click_reaction_sheet": OPTIMUS_CLICK_REACTION_SHEET_PATH,
		"scroll_texture": RESULT_SCROLL_PANEL_PATH,
		"result_box_sheet_common": RESULT_BOX_SHEET_COMMON_PATH,
		"result_box_sheet_mythic": RESULT_BOX_SHEET_MYTHIC_PATH,
		"result_box_sheet_guaranteed_mythic": RESULT_BOX_SHEET_GUARANTEED_MYTHIC_PATH,
		"stage2_boss_defeat_live2d_sheet": STAGE2_BOSS_DEFEAT_LIVE2D_SHEET_PATH,
		"stage2_boss_defeat_click_reaction_sheet": STAGE2_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH,
		"stage3_boss_defeat_live2d_sheet": STAGE3_BOSS_DEFEAT_LIVE2D_SHEET_PATH,
		"stage3_boss_defeat_click_reaction_sheet": STAGE3_BOSS_DEFEAT_CLICK_REACTION_SHEET_PATH,
		"dalji_defeat_sheet": DALJI_DEFEAT_SHEET_PATH,
		"dalji_click_reaction_sheet": DALJI_CLICK_REACTION_SHEET_PATH,
		"dalji_click_voice": DALJI_CLICK_VOICE_PATH,
	}


static func get_result_asset_paths(character_type: String, stage_id: int, path_config: Dictionary = {}) -> Dictionary:
	if path_config.is_empty():
		path_config = get_default_result_asset_path_config()
	var normalized_character: String = normalize_player_victory_character_type(character_type)
	var normalized_stage_id: int = max(1, stage_id)
	var paths := {
		"background_texture": str(path_config.get("background_texture", "")),
		"player_victory_sheet": get_player_victory_sheet_path_for_character(normalized_character, path_config),
		"player_victory_click_reaction_sheet": get_player_victory_click_reaction_sheet_path_for_character(normalized_character, path_config),
		"scroll_texture": str(path_config.get("scroll_texture", "")),
		"result_box_sheet_common": str(path_config.get("result_box_sheet_common", "")),
		"result_box_sheet_mythic": str(path_config.get("result_box_sheet_mythic", "")),
		"result_box_sheet_guaranteed_mythic": str(path_config.get("result_box_sheet_guaranteed_mythic", "")),
	}
	if normalized_stage_id == 2:
		paths["stage2_boss_defeat_live2d_sheet"] = str(path_config.get("stage2_boss_defeat_live2d_sheet", ""))
		paths["stage2_boss_defeat_click_reaction_sheet"] = str(path_config.get("stage2_boss_defeat_click_reaction_sheet", ""))
	elif normalized_stage_id == 3:
		paths["stage3_boss_defeat_live2d_sheet"] = str(path_config.get("stage3_boss_defeat_live2d_sheet", ""))
		paths["stage3_boss_defeat_click_reaction_sheet"] = str(path_config.get("stage3_boss_defeat_click_reaction_sheet", ""))
	else:
		paths["dalji_defeat_sheet"] = str(path_config.get("dalji_defeat_sheet", ""))
		paths["dalji_click_reaction_sheet"] = str(path_config.get("dalji_click_reaction_sheet", ""))
		paths["dalji_click_voice"] = str(path_config.get("dalji_click_voice", ""))
	return paths


static func normalize_player_victory_character_type(character_type: String) -> String:
	var normalized: String = str(character_type).strip_edges().to_lower()
	if normalized == "soldier" or normalized == "commando":
		return "soldier"
	if normalized == "optimus" or normalized == "io":
		return "optimus"
	return "smasher"


static func get_player_victory_sheet_path_for_character(character_type: String, path_config: Dictionary = {}) -> String:
	if path_config.is_empty():
		path_config = get_default_result_asset_path_config()
	var normalized_character: String = normalize_player_victory_character_type(character_type)
	if normalized_character == "soldier":
		return str(path_config.get("commando_victory_sheet", ""))
	if normalized_character == "optimus":
		return str(path_config.get("optimus_victory_sheet", ""))
	return str(path_config.get("smasher_victory_sheet", ""))


static func get_player_victory_click_reaction_sheet_path_for_character(character_type: String, path_config: Dictionary = {}) -> String:
	if path_config.is_empty():
		path_config = get_default_result_asset_path_config()
	var normalized_character: String = normalize_player_victory_character_type(character_type)
	if normalized_character == "soldier":
		return str(path_config.get("commando_click_reaction_sheet", ""))
	if normalized_character == "optimus":
		return str(path_config.get("optimus_click_reaction_sheet", ""))
	return str(path_config.get("smasher_click_reaction_sheet", ""))


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


static func prewarm_result_assets(paths: Dictionary, character_type: String, stage_id: int) -> Dictionary:
	while not prewarm_result_assets_step(paths, character_type, stage_id):
		pass
	return _prewarm_result_asset_status.duplicate()


static func prewarm_result_assets_step(
	paths: Dictionary,
	character_type: String,
	stage_id: int,
	use_threaded_texture_loads: bool = false
) -> bool:
	var normalized_stage_id: int = max(1, stage_id)
	if (
		_prewarm_result_asset_character_type != character_type
		or _prewarm_result_asset_stage_id != normalized_stage_id
	):
		_prewarm_result_asset_step_index = 0
		_prewarm_result_asset_status.clear()
		_prewarm_result_asset_character_type = character_type
		_prewarm_result_asset_stage_id = normalized_stage_id
	_prewarm_result_asset_status["selected_character_type"] = character_type
	_prewarm_result_asset_status["current_stage"] = normalized_stage_id
	if not prewarm_assets_step(
		_prewarm_result_asset_step_index,
		_prewarm_result_asset_status,
		paths,
		use_threaded_texture_loads
	):
		return false
	_prewarm_result_asset_step_index += 1
	if _prewarm_result_asset_step_index >= PREWARM_ASSET_STEP_COUNT:
		_prewarm_result_asset_step_index = 0
		return true
	return false


static func reset_result_prewarm_assets_for_test() -> void:
	_prewarm_result_asset_step_index = 0
	_prewarm_result_asset_status.clear()
	_prewarm_result_asset_character_type = "smasher"
	_prewarm_result_asset_stage_id = 1


static func get_result_prewarm_asset_status() -> Dictionary:
	return _prewarm_result_asset_status.duplicate()


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
