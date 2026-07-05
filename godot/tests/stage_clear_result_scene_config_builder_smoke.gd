extends SceneTree

const StageClearResultSceneConfigBuilder := preload("res://scripts/core/stage_clear_result_scene_config_builder.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted


class FakeRuntimeModule:
	extends RefCounted


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var requested_keys: Array[String] = []

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		var instance: Variant = instances.get(key, null)
		return instance if instance is Object else null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_build_config_maps_result_scene_runtime_refs()
	_verify_source_boundary()

	if _failures.is_empty():
		print("stage_clear_result_scene_config_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_build_config_maps_result_scene_runtime_refs() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	for key in [
		"runtime_perk_state",
		"runtime_perk_catalog",
		"runtime_perk_icon_renderer",
		"mythic_item_runtime",
		"treasure_hunt_runtime",
		"game_audio",
	]:
		registry.instances[key] = FakeRuntimeModule.new()
	var reward_plan := {"reward_count": 2, "boxes": [{"kind": "normal"}]}
	var reward_snapshot := {"active_items": [{"name": "banana"}]}

	var config: Dictionary = StageClearResultSceneConfigBuilder.new().build_config(
		5,
		1,
		6,
		"blacksmith",
		reward_plan,
		reward_snapshot,
		owner,
		registry
	)
	_expect(int(config.get("player_score", 0)) == 5, "config should copy player score")
	_expect(int(config.get("boss_score", 0)) == 1, "config should copy boss score")
	_expect(int(config.get("current_stage", 0)) == 6, "config should copy current stage")
	_expect(str(config.get("selected_character_type", "")) == "blacksmith", "config should copy selected character type")
	_expect(config.get("runtime_perk_owner", null) == owner, "config should pass the runtime owner")
	_expect(config.get("runtime_perk_registry", null) == registry, "config should pass the runtime registry")
	for key in registry.instances.keys():
		_expect(config.get(key, null) == registry.instances[key], "config should map %s from the registry" % key)
		_expect(registry.requested_keys.has(key), "builder should request %s from the registry" % key)

	var copied_plan: Dictionary = config.get("reward_plan", {})
	var copied_snapshot: Dictionary = config.get("stage_reward_snapshot", {})
	(copied_plan.get("boxes", []) as Array).append({"kind": "mutated"})
	(copied_snapshot.get("active_items", []) as Array).append({"name": "mutated"})
	_expect((reward_plan.get("boxes", []) as Array).size() == 1, "config should deep-copy reward plan")
	_expect((reward_snapshot.get("active_items", []) as Array).size() == 1, "config should deep-copy reward snapshot")


func _verify_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var registry_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_handler_registry.gd")
	var builder_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_scene_config_builder.gd")
	_expect(registry_source.find("StageClearResultSceneConfigBuilder.new()") >= 0, "handler registry should own scene config builder assembly")
	_expect(screen_source.find("\"runtime_perk_icon_renderer\"") < 0, "result screen should not collect result-scene icon renderer directly")
	_expect(screen_source.find("\"treasure_hunt_runtime\"") < 0, "result screen should not collect treasure hunt runtime for result config directly")
	_expect(builder_source.find("\"runtime_perk_icon_renderer\"") >= 0, "scene config builder should own result-scene icon renderer lookup")
	_expect(builder_source.find("\"treasure_hunt_runtime\"") >= 0, "scene config builder should own treasure hunt runtime lookup")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
