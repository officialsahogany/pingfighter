extends SceneTree

const StageClearResultBoxUpdateHandler := preload("res://scripts/ui/stage_clear_result_box_update_handler.gd")
const StageClearResultBoxSceneHandler := preload("res://scripts/ui/stage_clear_result_box_scene_handler.gd")
const StageClearResultFieldApplySceneHandler := preload("res://scripts/ui/stage_clear_result_field_apply_scene_handler.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_update_handler_contract()
	_verify_update_apply_contract()
	_verify_scene_apply_contract()
	_verify_update_handler_source()
	_verify_scene_delegates_box_update_handler()

	if _failures.is_empty():
		print("stage_clear_result_box_update_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_update_handler_contract() -> void:
	_expect(StageClearResultBoxUpdateHandler != null, "box update handler preload should resolve")
	_expect(StageClearResultBoxSceneHandler != null, "box scene handler preload should resolve")
	var boxes: Array = [
		{
			"kind": "advanced",
			"state": "opening",
			"open_progress": 0.98,
			"base_pos": Vector2(420.0, 320.0),
			"reward": {"type": "mythic", "id": "meteor"},
		},
	]
	var result: Dictionary = StageClearResultBoxUpdateHandler.update_boxes(
		boxes,
		1.0,
		0,
		Callable(self, "_grant_callback"),
		Vector2(1920.0, 1080.0),
		1.0,
		0.0
	)
	_expect(int(result.get("lid_open_counter", 0)) == 1, "box update handler should preserve lid-open counter updates")
	var opened_indices: Array = result.get("opened_indices", [])
	_expect(opened_indices == [0], "box update handler should report boxes that just opened")
	var updated_boxes: Array = result.get("boxes", [])
	var updated_box: Dictionary = updated_boxes[0] if updated_boxes[0] is Dictionary else {}
	var reward: Dictionary = updated_box.get("reward", {}) if updated_box.get("reward", {}) is Dictionary else {}
	_expect(str(updated_box.get("state", "")) == "opened", "box update handler should advance opening boxes")
	_expect(bool(updated_box.get("reward_immediate_granted", false)), "box update handler should grant just-opened immediate rewards")
	_expect(bool(reward.get("immediate_granted", false)), "box update handler should store immediate grant state in reward payloads")
	_expect(not bool((boxes[0] as Dictionary).get("reward_immediate_granted", false)), "box update handler should not mutate source boxes")


func _verify_update_apply_contract() -> void:
	var current_boxes: Array = [{"state": "idle"}]
	var updated_boxes: Array = [{"state": "opened"}]
	var apply_result: Dictionary = StageClearResultBoxUpdateHandler.get_box_update_apply_result(
		{
			"boxes": updated_boxes,
			"lid_open_counter": 7,
		},
		current_boxes,
		2
	)
	_expect(apply_result.get("boxes", []) == updated_boxes, "box update apply helper should apply updated boxes")
	_expect(int(apply_result.get("lid_open_counter", 0)) == 7, "box update apply helper should apply lid counter")

	var fallback_result: Dictionary = StageClearResultBoxUpdateHandler.get_box_update_apply_result(
		{},
		current_boxes,
		3
	)
	_expect(fallback_result.get("boxes", []) == current_boxes, "box update apply helper should keep current boxes when missing")
	_expect(int(fallback_result.get("lid_open_counter", 0)) == 3, "box update apply helper should keep current lid counter when missing")

	var invalid_boxes_result: Dictionary = StageClearResultBoxUpdateHandler.get_box_update_apply_result(
		{
			"boxes": "invalid",
			"lid_open_counter": 4,
		},
		current_boxes,
		3
	)
	_expect(invalid_boxes_result.get("boxes", []) == current_boxes, "box update apply helper should keep current boxes when boxes payload is invalid")
	_expect(int(invalid_boxes_result.get("lid_open_counter", 0)) == 4, "box update apply helper should still apply valid lid counter with invalid boxes")


func _verify_scene_apply_contract() -> void:
	var current_boxes: Array = [{"state": "idle"}]
	var updated_boxes: Array = [{"state": "opened"}]
	var scene_apply: Dictionary = StageClearResultBoxUpdateHandler.get_box_update_scene_apply_result(
		{
			"boxes": updated_boxes,
			"lid_open_counter": 8,
		},
		current_boxes,
		2
	)
	var field_payload: Dictionary = scene_apply.get("field_payload", {}) as Dictionary
	_expect(field_payload.get("_boxes", []) == updated_boxes, "box update scene apply helper should map boxes to scene field")
	_expect(int(field_payload.get("_lid_open_counter", 0)) == 8, "box update scene apply helper should map lid counter to scene field")

	var scene := StageClearResultScene.new()
	scene.set("_boxes", current_boxes)
	scene.set("_lid_open_counter", 2)
	StageClearResultFieldApplySceneHandler.apply_scene_apply_result(scene, scene_apply)
	_expect(scene.get("_boxes") == updated_boxes, "scene field payload helper should apply box arrays")
	_expect(int(scene.get("_lid_open_counter")) == 8, "scene field payload helper should apply lid counter")
	scene.free()


func _verify_update_handler_source() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_update_handler.gd")
	_expect(source.find("static func update_boxes") >= 0, "box update handler should expose update_boxes")
	_expect(source.find("static func get_box_update_apply_result") >= 0, "box update handler should expose update apply payloads")
	_expect(source.find("static func get_box_update_scene_apply_result") >= 0, "box update handler should expose scene field apply payloads")
	_expect(source.find("StageClearResultBoxData.update_box_opening_state") >= 0, "box update handler should delegate opening animation state")
	_expect(source.find("StageClearResultImmediateRewardHelper.try_grant_opened_indices") >= 0, "box update handler should delegate just-opened immediate grants")


func _verify_scene_delegates_box_update_handler() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_scene_handler.gd")
	var update_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_update_scene_handler.gd")
	_expect(update_scene_handler_source.find("StageClearResultBoxSceneHandler.update_boxes") >= 0, "update scene handler should delegate box updates through the box scene handler")
	_expect(source.find("func _update_boxes") < 0, "result scene should not keep box update fanout wrappers")
	_expect(source.find("StageClearResultBoxUpdateHandler.") < 0, "result scene should not call the box update handler directly")
	_expect(scene_handler_source.find("StageClearResultBoxUpdateHandler.update_boxes") >= 0, "box scene handler should delegate box updates through the update handler")
	_expect(scene_handler_source.find("StageClearResultBoxUpdateHandler.get_box_update_scene_apply_result") >= 0, "box scene handler should delegate box update scene field payloads")
	_expect(source.find("func _apply_scene_apply_result") < 0, "result scene should not keep scene apply-result pass-through wrappers")
	_expect(source.find("func _apply_scene_field_payload") < 0, "result scene should not keep the retired direct field-payload wrapper")
	_expect(source.find("_boxes = apply_result.get") < 0, "result scene should not write box arrays directly during box updates")
	_expect(source.find("_lid_open_counter = int(apply_result.get") < 0, "result scene should not write lid counters directly during box updates")
	_expect(source.find("_lid_open_counter = int(result.get") < 0, "result scene should not inspect box update lid counters directly")
	_expect(source.find("StageClearResultBoxData.update_box_opening_state") < 0, "result scene should not update box opening state directly")
	_expect(source.find("StageClearResultImmediateRewardHelper.try_grant_opened_indices") < 0, "result scene should not grant just-opened rewards directly")


func _grant_callback(reward: Dictionary, _index: int) -> bool:
	reward["grant_seen_id"] = str(reward.get("id", ""))
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _slice_function(source: String, start_pattern: String, end_pattern: String) -> String:
	var start_index: int = source.find(start_pattern)
	if start_index < 0:
		return ""
	var end_index: int = source.find(end_pattern, start_index + start_pattern.length())
	return source.substr(start_index) if end_index < 0 else source.substr(start_index, end_index - start_index)
