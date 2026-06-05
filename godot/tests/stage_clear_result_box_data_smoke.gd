extends SceneTree

const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_standalone_preview_defaults()
	_verify_resolved_rewards()
	_verify_box_opening_state()
	_verify_resolved_perk_append()
	_verify_scene_delegates_box_data()

	if _failures.is_empty():
		print("stage_clear_result_box_data_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_standalone_preview_defaults() -> void:
	var defaults: Dictionary = StageClearResultBoxData.build_standalone_preview_defaults(5)
	_expect(int(defaults.get("player_score", 0)) == 5, "box data preview defaults should mirror reward count as player score")
	_expect(int(defaults.get("boss_score", -1)) == 0, "box data preview defaults should start boss score at zero")
	_expect(int(defaults.get("current_stage", 0)) == 1, "box data preview defaults should target Stage 1")
	var plan: Dictionary = defaults.get("reward_plan", {}) as Dictionary
	var boxes: Array = plan.get("boxes", []) as Array
	_expect(str(plan.get("summary", "")) != "", "box data preview defaults should build a visible summary text")
	_expect(int(plan.get("reward_count", 0)) == 5, "box data preview defaults should expose reward count")
	_expect(boxes.size() == 5, "box data preview defaults should create one normal box per reward")
	_expect(str((boxes[0] as Dictionary).get("kind", "")) == StageClearResultBoxData.BOX_KIND_NORMAL, "box data preview defaults should use normal boxes")


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


func _verify_box_opening_state() -> void:
	var callback_reward := {"type": "perk", "id": "callback_reward"}
	var reward: Dictionary = StageClearResultBoxData.roll_reward(
		"normal",
		Callable(self, "_roll_callback").bind(callback_reward),
		1.0,
		2,
		3
	)
	_expect(str(reward.get("id", "")) == "callback_reward", "box data should prefer reward callback results")
	var mythic_reward: Dictionary = StageClearResultBoxData.roll_reward(
		"guaranteed_mythic",
		Callable(),
		1.0,
		2,
		3
	)
	_expect(str(mythic_reward.get("type", "")) == "mythic", "guaranteed mythic boxes should fall back to mythic rewards")

	var boxes: Array = [
		{"kind": "normal", "roll_kind": "normal", "state": "idle", "reward": {}},
		{"kind": "advanced", "state": "opened", "reward": {"type": "active"}, "reward_emerge": 0.2},
	]
	var start_result: Dictionary = StageClearResultBoxData.start_opening_box(boxes, 0, {"type": "active", "id": "drive"})
	_expect(bool(start_result.get("started", false)), "box data should start idle boxes")
	var started_boxes: Array = start_result.get("boxes", [])
	var opening_box: Dictionary = started_boxes[0] if started_boxes[0] is Dictionary else {}
	_expect(str(opening_box.get("state", "")) == "opening", "started box should enter opening state")
	_expect(str((opening_box.get("reward", {}) as Dictionary).get("id", "")) == "drive", "started box should store the rolled reward")

	var update_result: Dictionary = StageClearResultBoxData.update_box_opening_state(
		started_boxes,
		0.6,
		0.6,
		0.45,
		0.55,
		0
	)
	var updated_boxes: Array = update_result.get("boxes", [])
	var opened_box: Dictionary = updated_boxes[0] if updated_boxes[0] is Dictionary else {}
	var emerged_box: Dictionary = updated_boxes[1] if updated_boxes[1] is Dictionary else {}
	var opened_indices: Array = update_result.get("opened_indices", [])
	_expect(str(opened_box.get("state", "")) == "opened", "box data should transition completed opening boxes to opened")
	_expect(bool(opened_box.get("lid_open_fired", false)), "box data should fire lid-open state when threshold is crossed")
	_expect(int(opened_box.get("lid_open_id", 0)) == 1, "box data should assign lid-open ids")
	_expect(int(update_result.get("lid_open_counter", 0)) == 1, "box data should return updated lid-open counter")
	_expect(opened_indices == [0], "box data should report boxes that just opened")
	_expect(float(emerged_box.get("reward_emerge", 0.0)) > 0.2, "opened boxes should advance reward emerge progress")


func _roll_callback(_kind: String, reward: Dictionary) -> Dictionary:
	return reward


func _verify_resolved_perk_append() -> void:
	var boxes: Array = [
		{"kind": "normal", "state": "opened", "reward": {"type": "starpoint", "amount": 2}},
		{"kind": "normal", "state": "opened", "reward": {"type": "active", "id": "drive"}},
	]
	var result: Dictionary = StageClearResultBoxData.append_resolved_perk_reward(boxes, 0, {"perk_id": "dash"})
	_expect(bool(result.get("updated", false)), "box data should append resolved perk rewards to starpoint boxes")
	var updated_boxes: Array = result.get("boxes", [])
	var reward: Dictionary = (updated_boxes[0] as Dictionary).get("reward", {}) as Dictionary
	var resolved: Array = reward.get("resolved_perk_rewards", []) as Array
	_expect(resolved.size() == 1, "box data should add one resolved perk reward")
	_expect(str((resolved[0] as Dictionary).get("source", "")) == "box_starpoint_choice", "box data should tag box starpoint choices")
	_expect(int(reward.get("resolved_perk_count", 0)) == 1, "box data should maintain resolved perk count")
	_expect(not bool(StageClearResultBoxData.append_resolved_perk_reward(boxes, 1, {"perk_id": "dash"}).get("updated", true)), "box data should ignore non-starpoint rewards")
	_expect(not bool(StageClearResultBoxData.append_resolved_perk_reward(boxes, 0, {}).get("updated", true)), "box data should ignore empty resolved perk rewards")


func _verify_scene_delegates_box_data() -> void:
	var box_data_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_box_data.gd")
	var scene_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(box_data_source.find("static func get_resolved_rewards") >= 0, "box data should own resolved reward extraction")
	_expect(scene_source.find("StageClearResultBoxData.get_resolved_rewards") >= 0, "result scene should delegate resolved reward extraction")
	_expect(scene_source.find("StageClearResultBoxData.start_opening_box") >= 0, "result scene should delegate opening box setup")
	_expect(scene_source.find("StageClearResultBoxData.update_box_opening_state") >= 0, "result scene should delegate box opening animation state")
	_expect(scene_source.find("StageClearResultBoxData.append_resolved_perk_reward") >= 0, "result scene should delegate box resolved perk appends")
	_expect(scene_source.find("StageClearResultBoxData.build_standalone_preview_defaults") >= 0, "result scene should delegate standalone preview reward plan defaults")
	_expect(scene_source.find("func _roll_reward") < 0, "result scene should not keep local reward rolling")
	_expect(scene_source.find("reward_copy[\"box_kind\"]") < 0, "result scene should not keep resolved reward copy assembly")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
