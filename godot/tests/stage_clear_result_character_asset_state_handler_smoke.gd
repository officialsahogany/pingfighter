extends SceneTree

const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")
const StageClearResultCharacterAssetStateHandler := preload("res://scripts/ui/stage_clear_result_character_asset_state_handler.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_character_asset_state_contract()
	_verify_character_asset_apply_contract()
	_verify_character_asset_scene_apply_contract()
	_verify_scene_applies_character_asset_state()
	_verify_character_asset_state_source()
	_verify_scene_delegates_character_asset_state()

	if _failures.is_empty():
		print("stage_clear_result_character_asset_state_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_character_asset_state_contract() -> void:
	_expect(StageClearResultCharacterAssetStateHandler != null, "character asset state handler preload should resolve")
	var base_sheet := ImageTexture.new()
	var click_sheet := ImageTexture.new()
	var unchanged: Dictionary = StageClearResultCharacterAssetStateHandler.get_character_asset_state(
		"smasher",
		"unknown",
		base_sheet,
		click_sheet,
		"base_path",
		"click_path"
	)
	_expect(not bool(unchanged.get("changed", true)), "unsupported result characters should normalize to Smasher without clearing Smasher caches")
	_expect(unchanged.get("player_victory_sheet", null) == base_sheet, "unchanged character state should preserve the base sheet")
	_expect(str(unchanged.get("player_victory_sheet_loaded_path", "")) == "base_path", "unchanged character state should preserve the base path")

	var changed: Dictionary = StageClearResultCharacterAssetStateHandler.get_character_asset_state(
		"smasher",
		"commando",
		base_sheet,
		click_sheet,
		"base_path",
		"click_path"
	)
	_expect(bool(changed.get("changed", false)), "changed character state should report cache invalidation")
	_expect(str(changed.get("selected_character_type", "")) == "soldier", "changed character state should normalize Commando aliases")
	_expect(changed.get("player_victory_sheet", base_sheet) == null, "changed character state should clear the base sheet")
	_expect(changed.get("player_victory_click_reaction_sheet", click_sheet) == null, "changed character state should clear the click sheet")
	_expect(str(changed.get("player_victory_sheet_loaded_path", "old")) == "", "changed character state should clear the base path")
	_expect(str(changed.get("player_victory_click_reaction_sheet_loaded_path", "old")) == "", "changed character state should clear the click path")
	_expect(StageClearResultAssetLoader.normalize_player_victory_character_type("commando") == "soldier", "asset loader should keep canonical character normalization")


func _verify_character_asset_apply_contract() -> void:
	var base_sheet := ImageTexture.new()
	var click_sheet := ImageTexture.new()
	var next_sheet := ImageTexture.new()
	var apply_result: Dictionary = StageClearResultCharacterAssetStateHandler.get_character_asset_apply_result(
		{
			"selected_character_type": "dash",
			"player_victory_sheet": next_sheet,
			"player_victory_click_reaction_sheet": null,
			"player_victory_sheet_loaded_path": "next_path",
			"player_victory_click_reaction_sheet_loaded_path": "",
		},
		"smasher",
		base_sheet,
		click_sheet,
		"base_path",
		"click_path"
	)
	_expect(str(apply_result.get("selected_character_type", "")) == "dash", "character asset apply should apply selected character")
	_expect(apply_result.get("player_victory_sheet", null) == next_sheet, "character asset apply should apply provided base sheet")
	_expect(apply_result.get("player_victory_click_reaction_sheet", click_sheet) == null, "character asset apply should allow clearing click sheet")
	_expect(str(apply_result.get("player_victory_sheet_loaded_path", "")) == "next_path", "character asset apply should apply base path")
	_expect(str(apply_result.get("player_victory_click_reaction_sheet_loaded_path", "old")) == "", "character asset apply should allow clearing click path")

	var fallback_result: Dictionary = StageClearResultCharacterAssetStateHandler.get_character_asset_apply_result(
		{
			"player_victory_sheet": "invalid",
			"player_victory_click_reaction_sheet": "invalid",
		},
		"smasher",
		base_sheet,
		click_sheet,
		"base_path",
		"click_path"
	)
	_expect(str(fallback_result.get("selected_character_type", "")) == "smasher", "character asset apply should keep selected character when missing")
	_expect(fallback_result.get("player_victory_sheet", null) == base_sheet, "invalid base sheet should keep current sheet")
	_expect(fallback_result.get("player_victory_click_reaction_sheet", null) == click_sheet, "invalid click sheet should keep current sheet")
	_expect(str(fallback_result.get("player_victory_sheet_loaded_path", "")) == "base_path", "missing base path should keep current path")
	_expect(str(fallback_result.get("player_victory_click_reaction_sheet_loaded_path", "")) == "click_path", "missing click path should keep current path")


func _verify_character_asset_scene_apply_contract() -> void:
	var base_sheet := ImageTexture.new()
	var click_sheet := ImageTexture.new()
	var next_sheet := ImageTexture.new()
	var scene_apply: Dictionary = StageClearResultCharacterAssetStateHandler.get_character_asset_scene_apply_result(
		{
			"selected_character_type": "dash",
			"player_victory_sheet": next_sheet,
			"player_victory_click_reaction_sheet": null,
			"player_victory_sheet_loaded_path": "next_path",
			"player_victory_click_reaction_sheet_loaded_path": "",
		},
		"smasher",
		base_sheet,
		click_sheet,
		"base_path",
		"click_path"
	)
	var field_payload: Dictionary = scene_apply.get("field_payload", {}) as Dictionary
	_expect(str(field_payload.get("selected_character_type", "")) == "dash", "character asset scene apply should map selected character")
	_expect(field_payload.get("_player_victory_sheet", null) == next_sheet, "character asset scene apply should map base sheet")
	_expect(field_payload.get("_player_victory_click_reaction_sheet", click_sheet) == null, "character asset scene apply should map click sheet clears")
	_expect(str(field_payload.get("_player_victory_sheet_loaded_path", "")) == "next_path", "character asset scene apply should map base path")
	_expect(str(field_payload.get("_player_victory_click_reaction_sheet_loaded_path", "old")) == "", "character asset scene apply should map click path")

	var scene := StageClearResultScene.new()
	scene._apply_scene_field_payload(field_payload)
	_expect(scene.selected_character_type == "dash", "scene field payload helper should apply selected character")
	_expect(scene.get("_player_victory_sheet") == next_sheet, "scene field payload helper should apply base sheet")
	_expect(scene.get("_player_victory_click_reaction_sheet") == null, "scene field payload helper should clear click sheet")
	_expect(str(scene.get("_player_victory_sheet_loaded_path")) == "next_path", "scene field payload helper should apply base path")
	_expect(str(scene.get("_player_victory_click_reaction_sheet_loaded_path")) == "", "scene field payload helper should apply click path")
	scene.free()


func _verify_scene_applies_character_asset_state() -> void:
	var scene := StageClearResultScene.new()
	var base_sheet := ImageTexture.new()
	var click_sheet := ImageTexture.new()
	scene.set("selected_character_type", "smasher")
	scene.set("_player_victory_sheet", base_sheet)
	scene.set("_player_victory_click_reaction_sheet", click_sheet)
	scene.set("_player_victory_sheet_loaded_path", "base_path")
	scene.set("_player_victory_click_reaction_sheet_loaded_path", "click_path")
	scene._apply_character_asset_state({
		"selected_character_type": "soldier",
		"player_victory_sheet": null,
		"player_victory_click_reaction_sheet": null,
		"player_victory_sheet_loaded_path": "",
		"player_victory_click_reaction_sheet_loaded_path": "",
	})
	_expect(scene.selected_character_type == "soldier", "scene character asset apply should write selected character")
	_expect(scene.get("_player_victory_sheet") == null, "scene character asset apply should clear base sheet")
	_expect(scene.get("_player_victory_click_reaction_sheet") == null, "scene character asset apply should clear click sheet")
	_expect(str(scene.get("_player_victory_sheet_loaded_path")) == "", "scene character asset apply should clear base path")
	_expect(str(scene.get("_player_victory_click_reaction_sheet_loaded_path")) == "", "scene character asset apply should clear click path")
	scene.free()


func _verify_character_asset_state_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_character_asset_state_handler.gd")
	_expect(source.find("static func get_character_asset_state") >= 0, "character asset state handler should expose state resolution")
	_expect(source.find("static func get_character_asset_apply_result") >= 0, "character asset state handler should expose apply resolution")
	_expect(source.find("static func get_character_asset_scene_apply_result") >= 0, "character asset state handler should expose scene field apply resolution")
	_expect(source.find("StageClearResultAssetLoader.normalize_player_victory_character_type") >= 0, "character asset state handler should delegate character normalization")
	_expect(source.find("\"player_victory_sheet_loaded_path\": \"\" if changed") >= 0, "character asset state handler should clear cached base paths on change")
	_expect(source.find("\"player_victory_click_reaction_sheet_loaded_path\": \"\" if changed") >= 0, "character asset state handler should clear cached click paths on change")


func _verify_scene_delegates_character_asset_state() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var apply_source: String = _slice_function(source, "func _apply_character_asset_state", "func _apply_runtime_object_state")
	_expect(source.find("StageClearResultCharacterAssetStateHandler.get_character_asset_state") >= 0, "result scene should delegate configure-time character asset state")
	_expect(source.find("StageClearResultCharacterAssetStateHandler.get_character_asset_scene_apply_result") >= 0, "result scene should delegate character asset scene field apply payloads")
	_expect(source.find("func _apply_scene_field_payload") >= 0, "result scene should centralize scene field payload application")
	_expect(source.find("func _get_field_payload_from_apply_result") >= 0, "result scene should unwrap nested scene field payloads in one helper")
	_expect(source.find("func _apply_character_asset_state") >= 0, "result scene should apply resolved character asset state")
	_expect(apply_source.find("selected_character_type = str(result.get") < 0, "character asset applier should not inspect selected character directly")
	_expect(apply_source.find("_player_victory_sheet = result.get") < 0, "character asset applier should not inspect base sheet directly")
	_expect(apply_source.find("_player_victory_click_reaction_sheet = result.get") < 0, "character asset applier should not inspect click sheet directly")
	_expect(apply_source.find("_player_victory_sheet_loaded_path = str(result.get") < 0, "character asset applier should not inspect base path directly")
	_expect(apply_source.find("_player_victory_click_reaction_sheet_loaded_path = str(result.get") < 0, "character asset applier should not inspect click path directly")
	_expect(apply_source.find("selected_character_type = str(apply_result.get") < 0, "character asset applier should not write selected character directly")
	_expect(apply_source.find("_player_victory_sheet = apply_result.get") < 0, "character asset applier should not write base sheet directly")
	_expect(apply_source.find("_player_victory_click_reaction_sheet = apply_result.get") < 0, "character asset applier should not write click sheet directly")
	_expect(apply_source.find("_player_victory_sheet_loaded_path = str(apply_result.get") < 0, "character asset applier should not write base path directly")
	_expect(apply_source.find("_player_victory_click_reaction_sheet_loaded_path = str(apply_result.get") < 0, "character asset applier should not write click path directly")
	_expect(source.find("var previous_character_type") < 0, "result scene should not keep local previous-character checks")
	_expect(source.find("_player_victory_sheet = null") < 0, "result scene should not clear victory sheets directly in configure")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _slice_function(source: String, start_pattern: String, end_pattern: String) -> String:
	var start_index: int = source.find(start_pattern)
	if start_index < 0:
		return ""
	var end_index: int = source.find(end_pattern, start_index + start_pattern.length())
	return source.substr(start_index) if end_index < 0 else source.substr(start_index, end_index - start_index)
