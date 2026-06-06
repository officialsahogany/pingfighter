extends SceneTree

const StageClearResultRuntimeObjectStateHandler := preload("res://scripts/ui/stage_clear_result_runtime_object_state_handler.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_runtime_object_state_contract()
	_verify_runtime_object_apply_contract()
	_verify_scene_applies_runtime_object_state()
	_verify_runtime_object_state_source()
	_verify_scene_delegates_runtime_object_state()

	if _failures.is_empty():
		print("stage_clear_result_runtime_object_state_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_runtime_object_state_contract() -> void:
	_expect(StageClearResultRuntimeObjectStateHandler != null, "runtime object state handler preload should resolve")
	var valid_runtime := Node.new()
	var valid_audio := RefCounted.new()
	var result: Dictionary = StageClearResultRuntimeObjectStateHandler.get_runtime_object_state({
		"runtime_perk_state": valid_runtime,
		"runtime_perk_catalog": "not an object",
		"game_audio": valid_audio,
	})
	_expect(result.get("runtime_perk_state", null) == valid_runtime, "runtime object state should preserve valid node objects")
	_expect(result.get("game_audio", null) == valid_audio, "runtime object state should preserve valid ref-counted objects")
	_expect(result.get("runtime_perk_catalog", "sentinel") == null, "runtime object state should reject non-object values")
	_expect(result.get("mythic_item_runtime", "sentinel") == null, "runtime object state should include missing keys as null")
	valid_runtime.free()


func _verify_runtime_object_apply_contract() -> void:
	var valid_runtime := Node.new()
	var valid_audio := RefCounted.new()
	var result: Dictionary = StageClearResultRuntimeObjectStateHandler.get_runtime_object_apply_result({
		"runtime_perk_state": valid_runtime,
		"runtime_perk_catalog": "not an object",
		"game_audio": valid_audio,
	})
	_expect(result.get("_runtime_perk_state", null) == valid_runtime, "runtime object apply should prefix valid runtime state property")
	_expect(result.get("_game_audio", null) == valid_audio, "runtime object apply should prefix valid game audio property")
	_expect(result.get("_runtime_perk_catalog", "sentinel") == null, "runtime object apply should reject non-object values")
	_expect(result.get("_mythic_item_runtime", "sentinel") == null, "runtime object apply should include missing keys as null")
	_expect(result.has("_runtime_perk_state"), "runtime object apply should return scene property names")
	valid_runtime.free()


func _verify_scene_applies_runtime_object_state() -> void:
	var scene := StageClearResultScene.new()
	var valid_runtime := RefCounted.new()
	var valid_audio := RefCounted.new()
	scene._apply_runtime_object_state({
		"runtime_perk_state": valid_runtime,
		"runtime_perk_catalog": "not an object",
		"game_audio": valid_audio,
	})
	_expect(scene.get("_runtime_perk_state") == valid_runtime, "scene runtime object apply should write valid runtime state")
	_expect(scene.get("_game_audio") == valid_audio, "scene runtime object apply should write valid game audio")
	_expect(scene.get("_runtime_perk_catalog") == null, "scene runtime object apply should clear invalid runtime catalog")
	_expect(scene.get("_mythic_item_runtime") == null, "scene runtime object apply should clear missing mythic runtime")
	scene.free()


func _verify_runtime_object_state_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_runtime_object_state_handler.gd")
	_expect(source.find("const RUNTIME_OBJECT_KEYS") >= 0, "runtime object state handler should own the runtime object key list")
	_expect(source.find("static func get_runtime_object_state") >= 0, "runtime object state handler should expose state resolution")
	_expect(source.find("static func get_runtime_object_apply_result") >= 0, "runtime object state handler should expose apply resolution")
	_expect(source.find("static func _valid_object_or_null") >= 0, "runtime object state handler should centralize object validation")
	_expect(source.find("typeof(value) == TYPE_OBJECT") >= 0, "runtime object state handler should guard non-object values")
	_expect(source.find("is_instance_valid(value)") >= 0, "runtime object state handler should guard invalid objects")


func _verify_scene_delegates_runtime_object_state() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var apply_source: String = _slice_function(source, "func _apply_runtime_object_state", "func _apply_config_reset_state")
	_expect(source.find("StageClearResultRuntimeObjectStateHandler.get_runtime_object_state") >= 0, "result scene should delegate runtime object state resolution")
	_expect(source.find("StageClearResultRuntimeObjectStateHandler.get_runtime_object_apply_result") >= 0, "result scene should delegate runtime object apply payloads")
	_expect(source.find("func _apply_runtime_object_state") >= 0, "result scene should apply runtime object state results")
	_expect(apply_source.find("RUNTIME_OBJECT_KEYS") < 0, "runtime object applier should not inspect the runtime object key list")
	_expect(apply_source.find("result.get(key") < 0, "runtime object applier should not inspect runtime object keys directly")
	_expect(source.find("for object_key in [\"runtime_perk_state\"") < 0, "result scene should not keep the runtime object key list inline")
	_expect(source.find("typeof(object_value) == TYPE_OBJECT") < 0, "result scene should not validate runtime object values inline")
	_expect(StageClearResultScene != null, "result scene preload should still resolve")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _slice_function(source: String, start_pattern: String, end_pattern: String) -> String:
	var start_index: int = source.find(start_pattern)
	if start_index < 0:
		return ""
	var end_index: int = source.find(end_pattern, start_index + start_pattern.length())
	return source.substr(start_index) if end_index < 0 else source.substr(start_index, end_index - start_index)
