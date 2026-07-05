extends SceneTree

const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")
const StageClearResultConfigSceneHandler := preload("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
const StageClearResultFieldApplySceneHandler := preload("res://scripts/ui/stage_clear_result_field_apply_scene_handler.gd")
const StageClearResultPreviewDefaultsHandler := preload("res://scripts/ui/stage_clear_result_preview_defaults_handler.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_preview_defaults_contract()
	_verify_preview_scene_apply_contract()
	_verify_preview_defaults_source()
	_verify_scene_delegates_preview_defaults()

	if _failures.is_empty():
		print("stage_clear_result_preview_defaults_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_preview_defaults_contract() -> void:
	_expect(StageClearResultPreviewDefaultsHandler != null, "preview defaults handler preload should resolve")
	var skipped: Dictionary = StageClearResultPreviewDefaultsHandler.get_standalone_preview_defaults(1, 0, {}, 5)
	_expect(not bool(skipped.get("apply", true)), "preview defaults should not apply when score data exists")
	skipped = StageClearResultPreviewDefaultsHandler.get_standalone_preview_defaults(0, 0, {"reward_count": 1}, 5)
	_expect(not bool(skipped.get("apply", true)), "preview defaults should not apply when reward plans exist")

	var defaults: Dictionary = StageClearResultPreviewDefaultsHandler.get_standalone_preview_defaults(0, 0, {}, 5)
	_expect(bool(defaults.get("apply", false)), "preview defaults should apply to empty standalone scenes")
	_expect(int(defaults.get("player_score", 0)) == 5, "preview defaults should mirror reward count as player score")
	_expect(int(defaults.get("boss_score", -1)) == 0, "preview defaults should keep boss score at zero")
	_expect(int(defaults.get("current_stage", 0)) == 1, "preview defaults should target Stage 1")
	var plan: Dictionary = defaults.get("reward_plan", {}) as Dictionary
	_expect(str(plan.get("summary", "")) != "", "preview defaults should include visible summary text")
	_expect(int(plan.get("reward_count", 0)) == 5, "preview defaults should expose reward count")


func _verify_preview_scene_apply_contract() -> void:
	var defaults: Dictionary = StageClearResultPreviewDefaultsHandler.get_standalone_preview_defaults(0, 0, {}, 5)
	var scene_apply: Dictionary = StageClearResultPreviewDefaultsHandler.get_standalone_preview_scene_apply_result(
		defaults,
		9,
		8,
		7,
		{"existing": true}
	)
	_expect(bool(scene_apply.get("apply", false)), "preview scene apply helper should preserve apply state")
	var field_payload: Dictionary = scene_apply.get("field_payload", {}) as Dictionary
	_expect(int(field_payload.get("player_score", 0)) == 5, "preview scene apply helper should map player score")
	_expect(int(field_payload.get("boss_score", -1)) == 0, "preview scene apply helper should map boss score")
	_expect(int(field_payload.get("current_stage", 0)) == 1, "preview scene apply helper should map current stage")
	var plan: Dictionary = field_payload.get("reward_plan", {}) as Dictionary
	_expect(int(plan.get("reward_count", 0)) == 5, "preview scene apply helper should map reward plan")

	var scene := StageClearResultScene.new()
	scene.player_score = 9
	scene.boss_score = 8
	scene.current_stage = 7
	scene.reward_plan = {"existing": true}
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(scene, scene_apply)
	_expect(scene.player_score == 5, "scene field payload helper should apply preview player score")
	_expect(scene.boss_score == 0, "scene field payload helper should apply preview boss score")
	_expect(scene.current_stage == 1, "scene field payload helper should apply preview stage")
	_expect(int(scene.reward_plan.get("reward_count", 0)) == 5, "scene field payload helper should apply preview reward plan")
	scene.free()

	var skipped: Dictionary = StageClearResultPreviewDefaultsHandler.get_standalone_preview_scene_apply_result(
		{"apply": false, "player_score": 5},
		9,
		8,
		7,
		{"existing": true}
	)
	var skipped_payload: Dictionary = skipped.get("field_payload", {}) as Dictionary
	_expect(not bool(skipped.get("apply", true)), "preview scene apply helper should preserve skipped state")
	_expect(int(skipped_payload.get("player_score", 0)) == 9, "skipped preview scene apply should keep player score")
	_expect(int(skipped_payload.get("boss_score", 0)) == 8, "skipped preview scene apply should keep boss score")
	_expect(int(skipped_payload.get("current_stage", 0)) == 7, "skipped preview scene apply should keep current stage")
	var skipped_plan: Dictionary = skipped_payload.get("reward_plan", {}) as Dictionary
	_expect(bool(skipped_plan.get("existing", false)), "skipped preview scene apply should keep reward plan")


func _verify_preview_defaults_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_preview_defaults_handler.gd")
	_expect(source.find("static func get_standalone_preview_defaults") >= 0, "preview defaults handler should expose standalone defaults")
	_expect(source.find("static func get_standalone_preview_apply_result") < 0, "preview defaults handler should fold the dead two-tier apply payload into scene_apply")
	_expect(source.find("static func get_standalone_preview_scene_apply_result") >= 0, "preview defaults handler should expose standalone scene field apply payloads")
	_expect(source.find("StageClearResultBoxData.build_standalone_preview_defaults") >= 0, "preview defaults handler should delegate default data assembly")
	_expect(source.find("\"apply\"") >= 0, "preview defaults handler should return an explicit apply flag")


func _verify_scene_delegates_preview_defaults() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var config_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
	var preview_source: String = _slice_function(config_scene_handler_source, "static func apply_standalone_preview_defaults", "static func load_textures")
	_expect(StageClearResultConfigSceneHandler != null, "config scene handler preload should resolve")
	_expect(config_scene_handler_source.find("static func apply_standalone_preview_defaults") >= 0, "config scene handler should own standalone preview scene glue")
	_expect(source.find("StageClearResultConfigSceneHandler.apply_standalone_preview_defaults") < 0, "result scene should not keep standalone preview pass-through glue")
	_expect(source.find("StageClearResultPreviewDefaultsHandler.") < 0, "result scene should not call preview defaults helper directly")
	_expect(config_scene_handler_source.find("StageClearResultPreviewDefaultsHandler.get_standalone_preview_defaults") >= 0, "config scene handler should delegate standalone preview defaults")
	_expect(config_scene_handler_source.find("StageClearResultPreviewDefaultsHandler.get_standalone_preview_scene_apply_result") >= 0, "config scene handler should delegate standalone preview scene field apply payloads")
	_expect(source.find("func _apply_scene_apply_result") < 0, "result scene should not keep scene apply-result pass-through wrappers")
	_expect(source.find("func _apply_scene_field_payload") < 0, "result scene should not keep the retired direct field-payload wrapper")
	_expect(source.find("func _get_field_payload_from_apply_result") < 0, "result scene should not keep the retired payload-unwrapping wrapper")
	_expect(preview_source.find("defaults.get(\"apply\"") < 0, "result scene should not inspect preview apply flags directly")
	_expect(preview_source.find("player_score = int(apply_result.get") < 0, "result scene should not write preview player score directly")
	_expect(preview_source.find("boss_score = int(apply_result.get") < 0, "result scene should not write preview boss score directly")
	_expect(preview_source.find("current_stage = int(apply_result.get") < 0, "result scene should not write preview stage directly")
	_expect(preview_source.find("reward_plan = apply_result.get") < 0, "result scene should not write preview reward plan directly")
	_expect(source.find("StageClearResultBoxData.build_standalone_preview_defaults") < 0, "result scene should not build standalone preview defaults directly")
	_expect(StageClearResultScene != null, "result scene preload should still resolve")
	_expect(StageClearResultBoxData != null, "box data preload should still resolve")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _slice_function(source: String, start_pattern: String, end_pattern: String) -> String:
	var start_index: int = source.find(start_pattern)
	if start_index < 0:
		return ""
	var end_index: int = source.find(end_pattern, start_index + start_pattern.length())
	return source.substr(start_index) if end_index < 0 else source.substr(start_index, end_index - start_index)
