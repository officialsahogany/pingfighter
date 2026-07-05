extends SceneTree

const StageClearResultImmediateRewardHelper := preload("res://scripts/ui/stage_clear_result_immediate_reward_helper.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_immediate_reward_helper()
	_verify_scene_delegates_immediate_reward_helper()

	if _failures.is_empty():
		print("stage_clear_result_immediate_reward_helper_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_immediate_reward_helper() -> void:
	var boxes: Array = [
		{
			"kind": "advanced",
			"state": "opened",
			"base_pos": Vector2(420.0, 320.0),
			"amplitude": 0.0,
			"speed": 0.0,
			"reward": {"type": "mythic", "id": "meteor"},
		},
	]
	var result: Dictionary = StageClearResultImmediateRewardHelper.try_grant_immediate_reward(
		boxes,
		0,
		Callable(self, "_grant_callback"),
		Vector2(1920.0, 1080.0),
		1.0,
		0.0
	)
	_expect(bool(result.get("granted", false)), "immediate reward helper should report successful grants")
	var updated_boxes: Array = result.get("boxes", [])
	var updated_box: Dictionary = updated_boxes[0] if updated_boxes[0] is Dictionary else {}
	var reward: Dictionary = result.get("reward", {}) as Dictionary
	_expect(bool(updated_box.get("reward_immediate_granted", false)), "immediate reward helper should mark boxes after grants")
	_expect(reward.get("pickup_position", null) is Vector2, "immediate reward helper should add pickup positions")
	_expect(reward.get("target_player_center", null) is Vector2, "immediate reward helper should add target positions")
	_expect(str(reward.get("grant_seen_id", "")) == "meteor", "immediate reward helper should pass the reward payload to callbacks")
	_expect(not bool((boxes[0] as Dictionary).get("reward_immediate_granted", false)), "immediate reward helper should not mutate source boxes")

	var multi_result: Dictionary = StageClearResultImmediateRewardHelper.try_grant_opened_indices(
		boxes,
		[0, 99],
		Callable(self, "_grant_callback"),
		Vector2(1920.0, 1080.0),
		1.0,
		0.0
	)
	var multi_boxes: Array = multi_result.get("boxes", [])
	var multi_box: Dictionary = multi_boxes[0] if multi_boxes[0] is Dictionary else {}
	_expect(bool(multi_box.get("reward_immediate_granted", false)), "immediate reward helper should grant valid opened indices")


func _verify_scene_delegates_immediate_reward_helper() -> void:
	var scene_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var update_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_update_scene_handler.gd")
	var box_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_scene_handler.gd")
	var helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_immediate_reward_helper.gd")
	var box_update_helper_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_update_handler.gd")
	_expect(
		update_scene_handler_source.find("StageClearResultBoxSceneHandler.update_boxes") >= 0
			and box_scene_handler_source.find("StageClearResultBoxUpdateHandler.update_boxes") >= 0,
		"update scene handler should delegate box update sequencing through the box scene handler"
	)
	_expect(scene_source.find("func _update_boxes") < 0, "result scene should not keep box update fanout wrappers")
	_expect(
		box_update_helper_source.find("StageClearResultImmediateRewardHelper.try_grant_opened_indices") >= 0,
		"box update handler should delegate opened-index immediate grants"
	)
	_expect(
		scene_source.find("StageClearResultCinematicPositionHelper") < 0,
		"result scene should not compose immediate reward cinematic positions directly"
	)
	_expect(
		helper_source.find("StageClearResultCinematicPositionHelper.get_reward_cinematic_positions") >= 0
			and helper_source.find("StageClearResultBoxData.try_grant_immediate_reward") >= 0,
		"immediate reward helper should compose cinematic positions and box data grants"
	)


func _grant_callback(reward: Dictionary, _index: int) -> bool:
	reward["grant_seen_id"] = str(reward.get("id", ""))
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
