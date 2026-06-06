extends RefCounted

const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")


static func get_character_asset_state(
	current_character_type: String,
	requested_character_type: String,
	player_victory_sheet: Texture2D,
	player_victory_click_reaction_sheet: Texture2D,
	player_victory_sheet_loaded_path: String,
	player_victory_click_reaction_sheet_loaded_path: String
) -> Dictionary:
	var normalized_character: String = StageClearResultAssetLoader.normalize_player_victory_character_type(requested_character_type)
	var changed: bool = normalized_character != current_character_type
	return {
		"changed": changed,
		"selected_character_type": normalized_character,
		"player_victory_sheet": null if changed else player_victory_sheet,
		"player_victory_click_reaction_sheet": null if changed else player_victory_click_reaction_sheet,
		"player_victory_sheet_loaded_path": "" if changed else player_victory_sheet_loaded_path,
		"player_victory_click_reaction_sheet_loaded_path": "" if changed else player_victory_click_reaction_sheet_loaded_path,
	}


static func get_character_asset_apply_result(
	character_asset_state: Dictionary,
	current_character_type: String,
	current_player_victory_sheet: Texture2D,
	current_player_victory_click_reaction_sheet: Texture2D,
	current_player_victory_sheet_loaded_path: String,
	current_player_victory_click_reaction_sheet_loaded_path: String
) -> Dictionary:
	return {
		"selected_character_type": str(character_asset_state.get("selected_character_type", current_character_type)),
		"player_victory_sheet": _texture_value(character_asset_state, "player_victory_sheet", current_player_victory_sheet),
		"player_victory_click_reaction_sheet": _texture_value(character_asset_state, "player_victory_click_reaction_sheet", current_player_victory_click_reaction_sheet),
		"player_victory_sheet_loaded_path": str(character_asset_state.get("player_victory_sheet_loaded_path", current_player_victory_sheet_loaded_path)),
		"player_victory_click_reaction_sheet_loaded_path": str(character_asset_state.get("player_victory_click_reaction_sheet_loaded_path", current_player_victory_click_reaction_sheet_loaded_path)),
	}


static func get_character_asset_scene_apply_result(
	character_asset_state: Dictionary,
	current_character_type: String,
	current_player_victory_sheet: Texture2D,
	current_player_victory_click_reaction_sheet: Texture2D,
	current_player_victory_sheet_loaded_path: String,
	current_player_victory_click_reaction_sheet_loaded_path: String
) -> Dictionary:
	var apply_result: Dictionary = get_character_asset_apply_result(
		character_asset_state,
		current_character_type,
		current_player_victory_sheet,
		current_player_victory_click_reaction_sheet,
		current_player_victory_sheet_loaded_path,
		current_player_victory_click_reaction_sheet_loaded_path
	)
	return {
		"field_payload": {
			"selected_character_type": str(apply_result.get("selected_character_type", current_character_type)),
			"_player_victory_sheet": apply_result.get("player_victory_sheet", current_player_victory_sheet),
			"_player_victory_click_reaction_sheet": apply_result.get("player_victory_click_reaction_sheet", current_player_victory_click_reaction_sheet),
			"_player_victory_sheet_loaded_path": str(apply_result.get("player_victory_sheet_loaded_path", current_player_victory_sheet_loaded_path)),
			"_player_victory_click_reaction_sheet_loaded_path": str(apply_result.get("player_victory_click_reaction_sheet_loaded_path", current_player_victory_click_reaction_sheet_loaded_path)),
		},
	}


static func _texture_value(character_asset_state: Dictionary, key: String, current_texture: Texture2D) -> Texture2D:
	if not character_asset_state.has(key):
		return current_texture
	var value: Variant = character_asset_state.get(key)
	if value == null:
		return null
	if value is Texture2D:
		return value
	return current_texture
