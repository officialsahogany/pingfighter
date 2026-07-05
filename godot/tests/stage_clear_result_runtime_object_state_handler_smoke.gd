extends SceneTree

const StageClearResultRuntimeObjectStateHandler := preload("res://scripts/ui/stage_clear_result_runtime_object_state_handler.gd")
const StageClearResultConfigSceneHandler := preload("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_runtime_object_state_contract()
	_verify_runtime_object_apply_contract()
	_verify_runtime_object_scene_apply_contract()
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


func _verify_runtime_object_scene_apply_contract() -> void:
	var valid_runtime := Node.new()
	var valid_audio := RefCounted.new()
	var result: Dictionary = StageClearResultRuntimeObjectStateHandler.get_runtime_object_scene_apply_result({
		"runtime_perk_state": valid_runtime,
		"runtime_perk_catalog": "not an object",
		"game_audio": valid_audio,
	})
	var payload_value: Variant = result.get("field_payload", {})
	_expect(payload_value is Dictionary, "runtime object scene apply should wrap fields in a field payload")
	var payload: Dictionary = payload_value if payload_value is Dictionary else {}
	_expect(payload.get("_runtime_perk_state", null) == valid_runtime, "runtime object scene apply should prefix valid runtime state property")
	_expect(payload.get("_game_audio", null) == valid_audio, "runtime object scene apply should prefix valid game audio property")
	_expect(payload.get("_runtime_perk_catalog", "sentinel") == null, "runtime object scene apply should reject non-object values")
	_expect(payload.get("_mythic_item_runtime", "sentinel") == null, "runtime object scene apply should include missing keys as null")
	valid_runtime.free()


func _verify_scene_applies_runtime_object_state() -> void:
	var scene := StageClearResultScene.new()
	var valid_runtime := RefCounted.new()
	var valid_audio := RefCounted.new()
	StageClearResultConfigSceneHandler.apply_runtime_object_state(scene, {
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
	_expect(source.find("static func get_runtime_object_scene_apply_result") >= 0, "runtime object state handler should expose scene field payload resolution")
	_expect(source.find("static func _valid_object_or_null") >= 0, "runtime object state handler should centralize object validation")
	_expect(source.find("typeof(value) == TYPE_OBJECT") >= 0, "runtime object state handler should guard non-object values")
	_expect(source.find("is_instance_valid(value)") >= 0, "runtime object state handler should guard invalid objects")


func _verify_scene_delegates_runtime_object_state() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var config_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
	var apply_source: String = _slice_function(config_scene_handler_source, "static func apply_runtime_object_state", "static func apply_config_reset_state")
	_expect(StageClearResultConfigSceneHandler != null, "config scene handler preload should resolve")
	_expect(config_scene_handler_source.find("static func apply_runtime_object_state") >= 0, "config scene handler should own runtime object scene glue")
	_expect(source.find("StageClearResultConfigSceneHandler.apply_runtime_object_state") < 0, "result scene should not keep runtime object pass-through glue")
	_expect(source.find("StageClearResultRuntimeObjectStateHandler.") < 0, "result scene should not call runtime object helper directly")
	_expect(config_scene_handler_source.find("StageClearResultRuntimeObjectStateHandler.get_runtime_object_state") >= 0, "config scene handler should delegate runtime object state resolution")
	_expect(config_scene_handler_source.find("StageClearResultRuntimeObjectStateHandler.get_runtime_object_scene_apply_result") >= 0, "config scene handler should delegate runtime object scene field payloads")
	_expect(source.find("func _apply_runtime_object_state") < 0, "result scene should not keep runtime object state pass-through glue")
	_expect(apply_source.find("RUNTIME_OBJECT_KEYS") < 0, "runtime object applier should not inspect the runtime object key list")
	_expect(apply_source.find("result.get(key") < 0, "runtime object applier should not inspect runtime object keys directly")
	_expect(apply_source.find("get_runtime_object_apply_result") < 0, "runtime object applier should not request raw runtime object apply payloads")
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
