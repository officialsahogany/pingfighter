extends RefCounted

const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")


# Data-only contract: reads the owner's current textures (read, not mutate),
# loads any missing sheets for the current stage, and returns a guarded scene
# field payload carrying every texture field plus the two loaded-path caches.
# The scene applies it through _apply_scene_field_payload, so the texture writes
# share the same field-name guard as every other payload (no bespoke owner.set).
static func load_texture_fields(
	owner: Object,
	selected_character_type: String,
	current_stage: int,
	player_victory_sheet_loaded_path: String,
	player_victory_click_reaction_sheet_loaded_path: String
) -> Dictionary:
	if owner == null:
		return {
			"field_payload": {
				"_player_victory_sheet_loaded_path": player_victory_sheet_loaded_path,
				"_player_victory_click_reaction_sheet_loaded_path": player_victory_click_reaction_sheet_loaded_path,
			},
		}
	var paths: Dictionary = StageClearResultAssetLoader.get_result_asset_paths(selected_character_type, current_stage)
	var current: Dictionary = _get_current_texture_fields(owner)
	var player_victory_path: String = str(paths.get("player_victory_sheet", ""))
	var player_victory_click_path: String = str(paths.get("player_victory_click_reaction_sheet", ""))
	if player_victory_sheet_loaded_path != player_victory_path:
		current["player_victory_sheet"] = null
	if player_victory_click_reaction_sheet_loaded_path != player_victory_click_path:
		current["player_victory_click_reaction_sheet"] = null
	var loaded: Dictionary = StageClearResultAssetLoader.load_textures(current, paths)
	var field_payload: Dictionary = {}
	for key_value in StageClearResultAssetLoader.TEXTURE_KEYS:
		var key: String = str(key_value)
		field_payload["_" + key] = loaded.get(key) as Texture2D
	field_payload["_player_victory_sheet_loaded_path"] = player_victory_path if loaded.get("player_victory_sheet") != null else ""
	field_payload["_player_victory_click_reaction_sheet_loaded_path"] = player_victory_click_path if loaded.get("player_victory_click_reaction_sheet") != null else ""
	return {"field_payload": field_payload}


static func _get_current_texture_fields(owner: Object) -> Dictionary:
	var current: Dictionary = {}
	for key_value in StageClearResultAssetLoader.TEXTURE_KEYS:
		var key: String = str(key_value)
		current[key] = owner.get(StringName("_" + key))
	return current
