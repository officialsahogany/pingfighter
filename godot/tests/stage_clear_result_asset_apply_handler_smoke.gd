extends SceneTree

const StageClearResultAssetApplyHandler := preload("res://scripts/ui/stage_clear_result_asset_apply_handler.gd")
const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")
const StageClearResultConfigSceneHandler := preload("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
const StageClearResultFieldApplySceneHandler := preload("res://scripts/ui/stage_clear_result_field_apply_scene_handler.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_apply_handler_contract()
	_verify_load_texture_fields_scene_apply()
	_verify_apply_handler_source()
	_verify_scene_delegates_asset_apply_handler()

	if _failures.is_empty():
		print("stage_clear_result_asset_apply_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_apply_handler_contract() -> void:
	_expect(StageClearResultAssetApplyHandler != null, "asset apply handler preload should resolve")
	var null_payload: Dictionary = StageClearResultAssetApplyHandler.load_texture_fields(null, "smasher", 1, "old", "old_click").get("field_payload", {}) as Dictionary
	_expect(str(null_payload.get("_player_victory_sheet_loaded_path", "")) == "old", "asset apply handler should preserve null-owner base path state")
	_expect(str(null_payload.get("_player_victory_click_reaction_sheet_loaded_path", "")) == "old_click", "asset apply handler should preserve null-owner click path state")

	var scene := StageClearResultScene.new()
	var payload: Dictionary = StageClearResultAssetApplyHandler.load_texture_fields(scene, "commando", 1, "", "").get("field_payload", {}) as Dictionary
	_expect(payload.get("_player_victory_sheet", null) is Texture2D, "asset apply handler should carry the loaded player victory texture in the payload")
	_expect(payload.get("_player_victory_click_reaction_sheet", null) is Texture2D, "asset apply handler should carry the loaded player click texture in the payload")
	_expect(str(payload.get("_player_victory_sheet_loaded_path", "")) == StageClearResultAssetLoader.COMMANDO_VICTORY_SHEET_PATH, "asset apply handler should return the applied player victory path")
	_expect(str(payload.get("_player_victory_click_reaction_sheet_loaded_path", "")) == StageClearResultAssetLoader.COMMANDO_CLICK_REACTION_SHEET_PATH, "asset apply handler should return the applied player click path")
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(scene, StageClearResultAssetApplyHandler.load_texture_fields(scene, "commando", 1, "", ""))
	_expect(scene._player_victory_sheet != null, "scene should apply player victory texture from the guarded payload")
	_expect(scene._player_victory_click_reaction_sheet != null, "scene should apply player click texture from the guarded payload")
	scene.free()


func _verify_load_texture_fields_scene_apply() -> void:
	# The handler must be data-only: building the payload must NOT mutate owner
	# textures. Only the scene's guarded apply step writes the fields.
	var scene := StageClearResultScene.new()
	var payload: Dictionary = StageClearResultAssetApplyHandler.load_texture_fields(scene, "smasher", 1, "", "").get("field_payload", {}) as Dictionary
	_expect(scene._player_victory_sheet == null, "load_texture_fields should not mutate owner textures before the scene applies the payload")
	for key_value in StageClearResultAssetLoader.TEXTURE_KEYS:
		_expect(payload.has("_" + str(key_value)), "texture payload should carry every texture field key: _%s" % str(key_value))
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(scene, StageClearResultAssetApplyHandler.load_texture_fields(scene, "smasher", 1, "", ""))
	_expect(scene._player_victory_sheet != null, "scene apply should set the smasher victory texture")
	_expect(str(scene._player_victory_sheet_loaded_path) == StageClearResultAssetLoader.SMASHER_VICTORY_SHEET_PATH, "scene apply should record the smasher victory loaded path")
	scene.free()


func _verify_apply_handler_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_asset_apply_handler.gd")
	_expect(source.find("static func load_texture_fields") >= 0, "asset apply handler should expose load_texture_fields")
	_expect(source.find("static func get_texture_path_apply_result") < 0, "asset apply handler should fold the dead two-tier texture path payload into load_texture_fields")
	_expect(source.find("static func get_texture_path_scene_apply_result") < 0, "asset apply handler should not keep a separate texture path scene apply wrapper")
	_expect(source.find("func _apply_texture_fields") < 0, "asset apply handler should not mutate the owner with a bespoke texture set loop")
	_expect(source.find("owner.set(") < 0, "asset apply handler should be data-only and not write owner fields directly")
	_expect(source.find("\"field_payload\"") >= 0, "asset apply handler should return a guarded scene field payload")
	_expect(source.find("StageClearResultAssetLoader.get_result_asset_paths") >= 0, "asset apply handler should resolve result asset paths")
	_expect(source.find("StageClearResultAssetLoader.load_textures") >= 0, "asset apply handler should delegate texture loading")
	_expect(source.find("StageClearResultAssetLoader.TEXTURE_KEYS") >= 0, "asset apply handler should use the canonical texture key list")
	_expect(source.find("_get_current_texture_fields") >= 0, "asset apply handler should collect current texture fields")


func _verify_scene_delegates_asset_apply_handler() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var config_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
	var load_textures_source: String = _slice_function(config_scene_handler_source, "static func load_textures", "static func load_audio")
	_expect(StageClearResultConfigSceneHandler != null, "config scene handler preload should resolve")
	_expect(config_scene_handler_source.find("static func load_textures") >= 0, "config scene handler should own texture scene glue")
	_expect(source.find("StageClearResultConfigSceneHandler.load_textures") < 0, "result scene should not keep texture loading pass-through glue")
	_expect(source.find("StageClearResultAssetApplyHandler.") < 0, "result scene should not call the asset apply handler directly")
	_expect(config_scene_handler_source.find("StageClearResultAssetApplyHandler.load_texture_fields") >= 0, "config scene handler should delegate texture field loading to the asset apply handler")
	_expect(source.find("StageClearResultAssetApplyHandler.get_texture_path_scene_apply_result") < 0, "result scene should not call the removed texture path scene apply wrapper")
	_expect(load_textures_source.find("StageClearResultAssetApplyHandler.load_texture_fields") >= 0, "config scene handler should route texture loading through the asset apply handler")
	_expect(config_scene_handler_source.find("StageClearResultAssetApplyHandler.load_texture_fields") >= 0, "config scene handler should apply texture payloads through the unified scene apply-result helper")
	_expect(source.find("func _apply_scene_apply_result") < 0, "result scene should not keep scene apply-result pass-through wrappers")
	_expect(source.find("func _apply_scene_field_payload") < 0, "result scene should not keep the retired direct field-payload wrapper")
	_expect(source.find("func _get_field_payload_from_apply_result") < 0, "result scene should not keep the retired payload-unwrapping wrapper")
	_expect(load_textures_source.find("_player_victory_sheet_loaded_path = str(result.get") < 0, "result scene should not inspect loaded player path state directly")
	_expect(load_textures_source.find("_player_victory_click_reaction_sheet_loaded_path = str(result.get") < 0, "result scene should not inspect loaded click path state directly")
	_expect(load_textures_source.find("_player_victory_sheet_loaded_path = str(apply_result.get") < 0, "result scene should not write loaded player path state directly")
	_expect(load_textures_source.find("_player_victory_click_reaction_sheet_loaded_path = str(apply_result.get") < 0, "result scene should not write loaded click path state directly")
	_expect(source.find("StageClearResultAssetLoader.load_textures") < 0, "result scene should not apply texture bundles directly")
	_expect(source.find("for key_value in StageClearResultAssetLoader.TEXTURE_KEYS") < 0, "result scene should not loop over texture keys directly")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _slice_function(source: String, start_pattern: String, end_pattern: String) -> String:
	var start_index: int = source.find(start_pattern)
	if start_index < 0:
		return ""
	var end_index: int = source.find(end_pattern, start_index + start_pattern.length())
	return source.substr(start_index) if end_index < 0 else source.substr(start_index, end_index - start_index)
