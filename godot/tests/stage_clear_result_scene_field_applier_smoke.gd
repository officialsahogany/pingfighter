extends SceneTree

const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")
const StageClearResultFieldApplySceneHandler := preload("res://scripts/ui/stage_clear_result_field_apply_scene_handler.gd")
const StageClearResultSceneFieldApplier := preload("res://scripts/ui/stage_clear_result_scene_field_applier.gd")

var _failures: Array[String] = []


class FakeTarget:
	extends RefCounted

	var player_score: int = 0
	var reward_plan: Dictionary = {}


func _init() -> void:
	_verify_direct_field_payload_application()
	_verify_nested_apply_result_unwrap()
	_verify_scene_delegates_field_application()

	if _failures.is_empty():
		print("stage_clear_result_scene_field_applier_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_field_payload_application() -> void:
	var target := FakeTarget.new()
	var lookup: Dictionary = {}
	StageClearResultSceneFieldApplier.apply_field_payload(
		target,
		{
			"player_score": 5,
			"reward_plan": {"boxes": 3},
		},
		lookup,
		"FakeTarget"
	)
	_expect(target.player_score == 5, "field applier should write integer scene fields")
	_expect(int(target.reward_plan.get("boxes", 0)) == 3, "field applier should write dictionary scene fields")
	_expect(lookup.has("player_score") and lookup.has("reward_plan"), "field applier should cache valid target field names")
	_expect(not StageClearResultSceneFieldApplier.is_valid_field(target, lookup, "missing_field"), "field applier should reject unknown field names")


func _verify_nested_apply_result_unwrap() -> void:
	var payload: Dictionary = StageClearResultSceneFieldApplier.get_field_payload_from_apply_result({
		"field_payload": {"player_score": 2},
	})
	_expect(int(payload.get("player_score", 0)) == 2, "field applier should unwrap nested field payloads")
	_expect(StageClearResultSceneFieldApplier.get_field_payload_from_apply_result({"field_payload": []}).is_empty(), "field applier should ignore malformed field payloads")

	var target := FakeTarget.new()
	var lookup: Dictionary = {}
	StageClearResultSceneFieldApplier.apply_from_result(
		target,
		{"field_payload": {"player_score": 4}},
		lookup,
		"FakeTarget"
	)
	_expect(target.player_score == 4, "field applier should apply nested field payloads")


func _verify_scene_delegates_field_application() -> void:
	var scene := StageClearResultScene.new()
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(scene, {"field_payload": {"player_score": 7}})
	_expect(scene.player_score == 7, "field-apply scene handler should preserve direct payload behavior")
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(scene, {"field_payload": {"boss_score": 3}})
	_expect(scene.boss_score == 3, "field-apply scene handler should preserve nested payload behavior")
	scene.free()

	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_field_apply_scene_handler.gd")
	var helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene_field_applier.gd")
	var field_apply_scene_handler_paths: Array[String] = [
		"res://scripts/ui/stage_clear_result_actor_click_scene_handler.gd",
		"res://scripts/ui/stage_clear_result_actor_draw_scene_handler.gd",
		"res://scripts/ui/stage_clear_result_box_scene_handler.gd",
		"res://scripts/ui/stage_clear_result_config_scene_handler.gd",
		"res://scripts/ui/stage_clear_result_scroll_scene_handler.gd",
		"res://scripts/ui/stage_clear_result_update_scene_handler.gd",
	]
	_expect(source.find("StageClearResultFieldApplySceneHandler.apply_scene_apply_result") < 0, "result scene should not keep scene apply-result pass-through glue")
	_expect(source.find("StageClearResultSceneFieldApplier.") < 0, "result scene should not call the field applier directly")
	_expect(scene_handler_source.find("StageClearResultSceneFieldApplier.apply_from_result") >= 0, "field-apply scene handler should delegate nested apply-results to the field applier")
	for field_apply_scene_handler_path in field_apply_scene_handler_paths:
		var field_apply_scene_handler_source: String = FileAccess.get_file_as_string(field_apply_scene_handler_path)
		_expect(
			field_apply_scene_handler_source.find("StageClearResultFieldApplySceneHandler.apply_scene_apply_result") >= 0,
			"%s should route scene-field apply payloads through the field-apply scene handler" % field_apply_scene_handler_path
		)
		_expect(
			field_apply_scene_handler_source.find("scene.call(\"_apply_scene_apply_result\"") < 0,
			"%s should not bounce scene-field apply payloads through the result scene wrapper" % field_apply_scene_handler_path
		)
	_expect(source.find("func _apply_scene_field_payload") < 0, "result scene should not keep direct field-payload application ownership")
	_expect(source.find("func _get_field_payload_from_apply_result") < 0, "result scene should not keep payload unwrapping ownership")
	_expect(source.find("func _is_valid_scene_field") < 0, "result scene should not keep field validation ownership")
	_expect(helper_source.find("func apply_field_payload") >= 0 and helper_source.find("func apply_from_result") >= 0 and helper_source.find("func is_valid_field") >= 0, "field applier should own payload write, unwrap, and validation helpers")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
