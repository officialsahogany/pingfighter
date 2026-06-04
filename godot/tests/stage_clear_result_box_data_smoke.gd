extends SceneTree

const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_resolved_rewards()
	_verify_scene_delegates_box_data()

	if _failures.is_empty():
		print("stage_clear_result_box_data_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_resolved_rewards() -> void:
	var boxes: Array = [
		{"kind": "normal", "state": "opened", "reward": {"type": "active", "id": "drive"}},
		{"kind": "advanced", "state": "opening", "reward": {}},
		{"kind": "guaranteed_mythic", "state": "opened", "reward": {"type": "mythic", "id": "star"}},
	]
	var rewards: Array = StageClearResultBoxData.get_resolved_rewards(boxes)
	_expect(rewards.size() == 2, "box data should collect only non-empty resolved rewards")
	_expect(str((rewards[0] as Dictionary).get("box_kind", "")) == "normal", "resolved reward should include source box kind")
	_expect(str((rewards[0] as Dictionary).get("box_state", "")) == "opened", "resolved reward should include source box state")
	_expect(str((rewards[1] as Dictionary).get("box_kind", "")) == "guaranteed_mythic", "resolved reward should preserve guaranteed mythic kind")
	(rewards[0] as Dictionary)["id"] = "mutated"
	_expect(str(((boxes[0] as Dictionary).get("reward", {}) as Dictionary).get("id", "")) == "drive", "resolved reward copies should not mutate source rewards")


func _verify_scene_delegates_box_data() -> void:
	var box_data_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_data.gd")
	var scene_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(box_data_source.find("static func get_resolved_rewards") >= 0, "box data should own resolved reward extraction")
	_expect(scene_source.find("StageClearResultBoxData.get_resolved_rewards") >= 0, "result scene should delegate resolved reward extraction")
	_expect(scene_source.find("reward_copy[\"box_kind\"]") < 0, "result scene should not keep resolved reward copy assembly")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
