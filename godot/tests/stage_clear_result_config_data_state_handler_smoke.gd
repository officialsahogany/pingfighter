extends SceneTree

const StageClearResultConfigDataStateHandler := preload("res://scripts/ui/stage_clear_result_config_data_state_handler.gd")
const StageClearResultConfigSceneHandler := preload("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
const StageClearResultFieldApplySceneHandler := preload("res://scripts/ui/stage_clear_result_field_apply_scene_handler.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_config_data_state_payload()
	_verify_config_data_apply_payload()
	_verify_config_data_scene_apply_payload()
	_verify_scene_applies_config_data_state()
	_verify_scene_delegates_config_data_state()

	if _failures.is_empty():
		print("stage_clear_result_config_data_state_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_config_data_state_payload() -> void:
	var reward_plan := {"items": [{"id": "magnet"}]}
	var reward_snapshot := {"gold": 12}
	var result: Dictionary = StageClearResultConfigDataStateHandler.get_config_data_state(
		{
			"player_score": 4,
			"boss_score": 2,
			"current_stage": 5,
			"selected_character_type": "commando",
			"reward_plan": reward_plan,
			"stage_reward_snapshot": reward_snapshot,
		},
		"smasher"
	)
	_expect(int(result.get("player_score", -1)) == 4, "config data should read player score")
	_expect(int(result.get("boss_score", -1)) == 2, "config data should read boss score")
	_expect(int(result.get("current_stage", -1)) == 5, "config data should read current stage")
	_expect(str(result.get("selected_character_type", "")) == "commando", "config data should read selected character")
	_expect(result.get("reward_plan", {}) == reward_plan, "config data should preserve dictionary reward plan")
	_expect(result.get("stage_reward_snapshot", {}) == reward_snapshot, "config data should preserve dictionary stage reward snapshot")

	var sanitized: Dictionary = StageClearResultConfigDataStateHandler.get_config_data_state(
		{
			"reward_plan": "invalid",
			"stage_reward_snapshot": ["invalid"],
		},
		"viper"
	)
	_expect(int(sanitized.get("player_score", -1)) == 0, "missing player score should default to zero")
	_expect(int(sanitized.get("boss_score", -1)) == 0, "missing boss score should default to zero")
	_expect(int(sanitized.get("current_stage", -1)) == 1, "missing current stage should default to one")
	_expect(str(sanitized.get("selected_character_type", "")) == "viper", "missing selected character should use current character")
	_expect((sanitized.get("reward_plan", null) as Dictionary).is_empty(), "non-dictionary reward plan should sanitize to empty dictionary")
	_expect((sanitized.get("stage_reward_snapshot", null) as Dictionary).is_empty(), "non-dictionary stage reward snapshot should sanitize to empty dictionary")


func _verify_config_data_apply_payload() -> void:
	var reward_plan := {"items": [{"id": "magnet"}]}
	var reward_snapshot := {"gold": 12}
	var apply_result: Dictionary = StageClearResultConfigDataStateHandler.get_config_data_scene_apply_result(
		{
			"player_score": 4,
			"boss_score": 2,
			"current_stage": 5,
			"reward_plan": reward_plan,
			"stage_reward_snapshot": reward_snapshot,
		},
		1,
		1,
		1,
		{"fallback": true},
		{"old": true}
	).get("field_payload", {}) as Dictionary
	_expect(int(apply_result.get("player_score", -1)) == 4, "config data apply should apply player score")
	_expect(int(apply_result.get("boss_score", -1)) == 2, "config data apply should apply boss score")
	_expect(int(apply_result.get("current_stage", -1)) == 5, "config data apply should apply current stage")
	_expect(apply_result.get("reward_plan", {}) == reward_plan, "config data apply should apply reward plan")
	_expect(apply_result.get("stage_reward_snapshot", {}) == reward_snapshot, "config data apply should apply stage reward snapshot")

	var fallback_result: Dictionary = StageClearResultConfigDataStateHandler.get_config_data_scene_apply_result(
		{
			"reward_plan": "invalid",
			"stage_reward_snapshot": ["invalid"],
		},
		6,
		5,
		4,
		{"fallback": true},
		{"old": true}
	).get("field_payload", {}) as Dictionary
	_expect(int(fallback_result.get("player_score", -1)) == 6, "config data apply should keep player score when missing")
	_expect(int(fallback_result.get("boss_score", -1)) == 5, "config data apply should keep boss score when missing")
	_expect(int(fallback_result.get("current_stage", -1)) == 4, "config data apply should keep current stage when missing")
	_expect(bool((fallback_result.get("reward_plan", {}) as Dictionary).get("fallback", false)), "config data apply should keep reward plan when invalid")
	_expect(bool((fallback_result.get("stage_reward_snapshot", {}) as Dictionary).get("old", false)), "config data apply should keep stage reward snapshot when invalid")


func _verify_config_data_scene_apply_payload() -> void:
	var reward_plan := {"items": [{"id": "magnet"}]}
	var reward_snapshot := {"gold": 12}
	var scene_apply: Dictionary = StageClearResultConfigDataStateHandler.get_config_data_scene_apply_result(
		{
			"player_score": 4,
			"boss_score": 2,
			"current_stage": 5,
			"reward_plan": reward_plan,
			"stage_reward_snapshot": reward_snapshot,
		},
		1,
		1,
		1,
		{"fallback": true},
		{"old": true}
	)
	var field_payload: Dictionary = scene_apply.get("field_payload", {}) as Dictionary
	_expect(int(field_payload.get("player_score", -1)) == 4, "config data scene apply should map player score")
	_expect(int(field_payload.get("boss_score", -1)) == 2, "config data scene apply should map boss score")
	_expect(int(field_payload.get("current_stage", -1)) == 5, "config data scene apply should map current stage")
	_expect(field_payload.get("reward_plan", {}) == reward_plan, "config data scene apply should map reward plan")
	_expect(field_payload.get("stage_reward_snapshot", {}) == reward_snapshot, "config data scene apply should map stage reward snapshot")

	var scene := StageClearResultScene.new()
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(scene, scene_apply)
	_expect(scene.player_score == 4, "scene field payload helper should apply config player score")
	_expect(scene.boss_score == 2, "scene field payload helper should apply config boss score")
	_expect(scene.current_stage == 5, "scene field payload helper should apply config stage")
	_expect(scene.reward_plan == reward_plan, "scene field payload helper should apply config reward plan")
	_expect(scene.stage_reward_snapshot == reward_snapshot, "scene field payload helper should apply config stage reward snapshot")
	scene.free()


func _verify_scene_applies_config_data_state() -> void:
	var scene := StageClearResultScene.new()
	var result: Dictionary = StageClearResultConfigDataStateHandler.get_config_data_state(
		{
			"player_score": 8,
			"boss_score": 3,
			"current_stage": 4,
			"reward_plan": {"starpoints": 1},
			"stage_reward_snapshot": {"items": 2},
		},
		"smasher"
	)
	StageClearResultConfigSceneHandler.apply_config_data_state(scene, result)
	_expect(scene.player_score == 8, "scene config data apply should write player score")
	_expect(scene.boss_score == 3, "scene config data apply should write boss score")
	_expect(scene.current_stage == 4, "scene config data apply should write current stage")
	_expect(int(scene.reward_plan.get("starpoints", 0)) == 1, "scene config data apply should write reward plan")
	_expect(int(scene.stage_reward_snapshot.get("items", 0)) == 2, "scene config data apply should write stage reward snapshot")
	scene.free()


func _verify_scene_delegates_config_data_state() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var config_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
	var configure_start: int = source.find("func configure(")
	var configure_end: int = source.find("func _process")
	var configure_source: String = source.substr(configure_start, configure_end - configure_start) if configure_start >= 0 and configure_end > configure_start else source
	var apply_source: String = _slice_function(config_scene_handler_source, "static func apply_config_data_state", "static func apply_character_asset_state")
	_expect(StageClearResultConfigSceneHandler != null, "config scene handler preload should resolve")
	_expect(source.find("func configure(") < 0, "result scene should not keep a configure facade")
	_expect(config_scene_handler_source.find("static func configure") >= 0, "config scene handler should own configure scene glue")
	_expect(source.find("StageClearResultConfigSceneHandler.exit_tree") >= 0, "result scene should delegate exit-tree scene glue")
	_expect(config_scene_handler_source.find("static func apply_config_data_state") >= 0, "config scene handler should own config data scene glue")
	_expect(source.find("StageClearResultConfigSceneHandler.apply_config_data_state") < 0, "result scene should not keep config data pass-through glue")
	_expect(source.find("StageClearResultConfigDataStateHandler.") < 0, "result scene should not call config data helper directly")
	_expect(config_scene_handler_source.find("StageClearResultConfigDataStateHandler.get_config_data_state") >= 0, "config scene handler should delegate configure data normalization")
	_expect(config_scene_handler_source.find("StageClearResultConfigDataStateHandler.get_config_data_scene_apply_result") >= 0, "config scene handler should delegate config data scene field apply payloads")
	_expect(config_scene_handler_source.find("static func exit_tree") >= 0, "config scene handler should own exit-tree teardown glue")
	_expect(config_scene_handler_source.find("clear_runtime_references(scene)") >= 0, "exit-tree teardown should reuse runtime-reference cleanup")
	_expect(source.find("_fx_host_pool.tear_down") < 0, "result scene should not tear down the FX host pool inline")
	_expect(source.find("_font_cache = null") < 0, "result scene should not null helper caches inline during exit")
	_expect(source.find("func _apply_scene_apply_result") < 0, "result scene should not keep scene apply-result pass-through wrappers")
	_expect(source.find("func _apply_scene_field_payload") < 0, "result scene should not keep the retired direct field-payload wrapper")
	_expect(source.find("func _get_field_payload_from_apply_result") < 0, "result scene should not keep the retired payload-unwrapping wrapper")
	_expect(source.find("func _apply_config_data_state") < 0, "result scene should not keep a focused config data applier")
	_expect(apply_source.find("player_score = int(result.get") < 0, "config data applier should not inspect player score directly")
	_expect(apply_source.find("boss_score = int(result.get") < 0, "config data applier should not inspect boss score directly")
	_expect(apply_source.find("current_stage = int(result.get") < 0, "config data applier should not inspect current stage directly")
	_expect(apply_source.find("reward_plan = result.get") < 0, "config data applier should not inspect reward plan directly")
	_expect(apply_source.find("stage_reward_snapshot = result.get") < 0, "config data applier should not inspect stage reward snapshot directly")
	_expect(apply_source.find("player_score = int(apply_result.get") < 0, "config data applier should not write player score directly")
	_expect(apply_source.find("boss_score = int(apply_result.get") < 0, "config data applier should not write boss score directly")
	_expect(apply_source.find("current_stage = int(apply_result.get") < 0, "config data applier should not write current stage directly")
	_expect(apply_source.find("reward_plan = apply_result.get") < 0, "config data applier should not write reward plan directly")
	_expect(apply_source.find("stage_reward_snapshot = apply_result.get") < 0, "config data applier should not write stage reward snapshot directly")
	_expect(configure_source.find("player_score = int(data.get(\"player_score\"") < 0, "configure should not parse player score inline")
	_expect(configure_source.find("boss_score = int(data.get(\"boss_score\"") < 0, "configure should not parse boss score inline")
	_expect(configure_source.find("current_stage = int(data.get(\"current_stage\"") < 0, "configure should not parse current stage inline")
	_expect(configure_source.find("var plan_value: Variant = data.get(\"reward_plan\"") < 0, "configure should not sanitize reward plan inline")
	_expect(configure_source.find("var stage_reward_value: Variant = data.get(\"stage_reward_snapshot\"") < 0, "configure should not sanitize stage reward snapshot inline")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _slice_function(source: String, start_pattern: String, end_pattern: String) -> String:
	var start_index: int = source.find(start_pattern)
	if start_index < 0:
		return ""
	var end_index: int = source.find(end_pattern, start_index + start_pattern.length())
	return source.substr(start_index) if end_index < 0 else source.substr(start_index, end_index - start_index)
